import AppKit
import AVFoundation
import Observation
import UniformTypeIdentifiers

let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("QuickShots", isDirectory: true)

enum ExtractMode: String { case interval, count }

enum ShotFormat: String {
    case jpg, png
    var type: UTType { self == .png ? .png : .jpeg }
}

struct VideoInfo {
    let id = UUID()
    let url: URL
    let duration: Double
    let size: CGSize
    let fps: Float
    let fileSize: Int64

    var name: String { url.deletingPathExtension().lastPathComponent }

    var summary: String {
        var parts = [formatTime(duration), "\(Int(size.width))×\(Int(size.height))"]
        if fps > 0 { parts.append("\(Double(fps).formatted(.number.precision(.fractionLength(0...2)))) fps") }
        if fileSize > 0 { parts.append(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)) }
        return parts.joined(separator: " · ")
    }
}

struct Shot: Identifiable {
    let id: Int
    let time: Double
    let thumb: NSImage
    let file: URL
}

struct AppAlert {
    let title: String
    let message: String
}

func formatTime(_ t: Double, alwaysHours: Bool = false, separator: String = ":") -> String {
    let s = max(0, Int(t.rounded(.down)))
    let h = s / 3600, m = s / 60 % 60, sec = s % 60
    if h > 0 || alwaysHours {
        return String(format: "%02d%@%02d%@%02d", h, separator, m, separator, sec)
    }
    return String(format: "%02d%@%02d", m, separator, sec)
}

func shotCount(_ n: Int) -> String {
    String(localized: "\(n) shots")
}

@MainActor @Observable
final class AppModel {
    var video: VideoInfo?
    var shots: [Shot] = []
    var deselected: Set<Int> = []
    var total = 0
    var isExtracting = false
    var elapsed: Double?
    var failed = 0
    var alert: AppAlert?
    var showShareImage = false

    private var asset: AVURLAsset?
    private var task: Task<Void, Never>?
    private var workDir: URL?
    private var generation = 0

    var selectedShots: [Shot] { shots.filter { !deselected.contains($0.id) } }
    var canExport: Bool { !isExtracting && shots.count > deselected.count }

    func chooseVideo() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video, .audiovisualContent]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await open(url) }
    }

    func open(_ url: URL) async {
        let asset = AVURLAsset(url: url)
        do {
            let (duration, readable) = try await asset.load(.duration, .isReadable)
            guard readable, let track = try await asset.loadTracks(withMediaType: .video).first else {
                throw CocoaError(.fileReadUnsupportedScheme)
            }
            let (natural, transform, fps) = try await track.load(.naturalSize, .preferredTransform, .nominalFrameRate)
            let size = natural.applying(transform)
            let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            close()
            self.asset = asset
            video = VideoInfo(url: url, duration: duration.seconds,
                              size: CGSize(width: abs(size.width), height: abs(size.height)),
                              fps: fps, fileSize: Int64(bytes))
        } catch {
            let name = url.lastPathComponent
            alert = AppAlert(
                title: String(localized: "Can't Open Video"),
                message: String(localized: "“\(name)” can't be read. QuickShots supports formats macOS can play, such as MP4, MOV and M4V. MKV, AVI and WebM need to be converted first."))
        }
    }

    func close() {
        cancel()
        generation += 1
        video = nil
        asset = nil
        shots = []
        deselected = []
        elapsed = nil
        showShareImage = false
        // Drops every cached screenshot and share image for this video, not just the current batch
        try? FileManager.default.removeItem(at: tempRoot)
        workDir = nil
    }

    static func times(mode: ExtractMode, interval: Double, count: Int, duration: Double) -> [Double] {
        let cap = 2000
        switch mode {
        case .count:
            let n = min(max(count, 1), cap)
            return (0..<n).map { (Double($0) + 0.5) * duration / Double(n) }
        case .interval:
            let step = max(interval, 0.1)
            var times: [Double] = []
            var t = step
            while t < duration - 0.05 && times.count < cap {
                times.append(t)
                t += step
            }
            return times.isEmpty ? [duration / 2] : times
        }
    }

    func extract(mode: ExtractMode, interval: Double, count: Int, precise: Bool, format: ShotFormat) {
        guard let video, let asset else { return }
        cancel()
        generation += 1
        let gen = generation

        let times = Self.times(mode: mode, interval: interval, count: count, duration: video.duration)
        shots = []
        deselected = []
        total = times.count
        failed = 0
        isExtracting = true
        elapsed = nil

        let dir = tempRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let workDir { try? FileManager.default.removeItem(at: workDir) }
        workDir = dir

        // Fast mode: accept the nearest keyframe within 40% of the gap between shots, which avoids most decoding
        let step = times.count > 1 ? times[1] - times[0] : video.duration
        let tolerance = precise ? CMTime.zero : CMTime(seconds: step * 0.4, preferredTimescale: 600)
        let url = video.url
        let makeGenerator = { (asset: AVAsset) -> AVAssetImageGenerator in
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = tolerance
            generator.requestedTimeToleranceAfter = tolerance
            return generator
        }

        let cmTimes = times.map { CMTime(seconds: $0, preferredTimescale: 600) }
        let start = Date()
        let watch = StallWatch()

        task = Task.detached(priority: .userInitiated) { [weak self] in
            let watchdog = Task.detached {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(2))
                    watch.kickIfStalled(after: 15)
                }
            }
            defer { watchdog.cancel() }

            var missing: [Int] = []
            var stillFailed = 0

            await withTaskCancellationHandler {
                await withTaskGroup(of: Void.self) { group in
                    // Decoded full-size frames wait here for JPEG/PNG encoding; capping them keeps memory flat
                    // no matter how long or high-resolution the video is.
                    var inFlight = 0
                    let maxInFlight = max(4, ProcessInfo.processInfo.activeProcessorCount)
                    func enqueue(_ image: CGImage, id: Int, time: CMTime) async {
                        while inFlight >= maxInFlight {
                            _ = await group.next()
                            inFlight -= 1
                        }
                        inFlight += 1
                        group.addTask {
                            let shot = Self.save(image, id: id, time: time.seconds, dir: dir, format: format)
                            await self?.add(shot, generation: gen)
                        }
                    }

                    // Small batches: a decoder that stalls or dies only costs one batch, which is retried below
                    var generator = makeGenerator(asset)
                    for batchStart in stride(from: 0, to: cmTimes.count, by: Self.batchSize) {
                        if Task.isCancelled { break }
                        let ids = Array(batchStart..<min(batchStart + Self.batchSize, cmTimes.count))
                        var done = Set<Int>()
                        watch.watch(generator)
                        for await result in generator.images(for: ids.map { cmTimes[$0] }) {
                            watch.tick()
                            if Task.isCancelled { break }
                            guard case let .success(requested, image, actual) = result,
                                  let id = ids.first(where: { cmTimes[$0] == requested }) else { continue }
                            done.insert(id)
                            await enqueue(image, id: id, time: actual)
                        }
                        let lost = ids.filter { !done.contains($0) }
                        if !lost.isEmpty {
                            missing += lost
                            generator = makeGenerator(AVURLAsset(url: url))
                        }
                    }

                    // Retry each missing frame on its own, with a fresh decoder after every failure
                    var retry = makeGenerator(AVURLAsset(url: url))
                    for id in missing {
                        if Task.isCancelled { break }
                        watch.watch(retry)
                        do {
                            let (image, actual) = try await retry.image(at: cmTimes[id])
                            await enqueue(image, id: id, time: actual)
                        } catch {
                            stillFailed += 1
                            retry = makeGenerator(AVURLAsset(url: url))
                        }
                    }
                }
            } onCancel: {
                watch.cancelCurrent()
            }

            await self?.finish(generation: gen, start: start, failed: stillFailed)
        }
    }

    nonisolated private static let batchSize = 16

    nonisolated private static func save(_ image: CGImage, id: Int, time: Double, dir: URL, format: ShotFormat) -> Shot {
        let file = dir.appendingPathComponent(String(format: "%04d.%@", id, format.rawValue))
        ImageFiles.write(image, to: file, type: format.type)
        let thumb = NSImage(cgImage: ImageFiles.scaled(image, maxSide: 480), size: .zero)
        return Shot(id: id, time: time, thumb: thumb, file: file)
    }

    func cancel() {
        task?.cancel()
        isExtracting = false
    }

    private func add(_ shot: Shot, generation gen: Int) {
        guard gen == generation else { return }
        let i = shots.firstIndex { $0.id > shot.id } ?? shots.endIndex
        shots.insert(shot, at: i)
    }

    private func finish(generation gen: Int, start: Date, failed: Int) {
        guard gen == generation else { return }
        isExtracting = false
        self.failed = failed
        elapsed = Date().timeIntervalSince(start)
    }

    func toggle(_ id: Int) {
        if deselected.contains(id) { deselected.remove(id) } else { deselected.insert(id) }
    }

    func toggleAll() {
        deselected = deselected.isEmpty ? Set(shots.map(\.id)) : []
    }

    // The sandbox only grants write access to folders the user picks, so export always asks;
    // the panel opens on the last export folder (or the video's folder), so Return is enough.
    func export() {
        guard let video, canExport else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = String(localized: "Export Here")
        panel.message = String(localized: "Choose a folder. A “\(video.name) Screenshots” folder will be created inside it.")
        let last = UserDefaults.standard.string(forKey: "lastExportFolder").map { URL(fileURLWithPath: $0) }
        panel.directoryURL = last ?? video.url.deletingLastPathComponent()
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        do {
            let dest = try export(to: folder, video: video)
            UserDefaults.standard.set(folder.path, forKey: "lastExportFolder")
            NSWorkspace.shared.activateFileViewerSelecting([dest])
        } catch {
            alert = AppAlert(title: String(localized: "Export Failed"), message: error.localizedDescription)
        }
    }

    private func export(to parent: URL, video: VideoInfo) throws -> URL {
        let fm = FileManager.default
        let base = String(localized: "\(video.name) Screenshots")
        var dest = parent.appendingPathComponent(base, isDirectory: true)
        var n = 2
        while fm.fileExists(atPath: dest.path) {
            dest = parent.appendingPathComponent("\(base) \(n)", isDirectory: true)
            n += 1
        }
        try fm.createDirectory(at: dest, withIntermediateDirectories: false)
        for (i, shot) in selectedShots.enumerated() {
            let name = String(format: "%@_%03d_%@.%@", video.name, i + 1,
                              formatTime(shot.time, alwaysHours: true, separator: "-"), shot.file.pathExtension)
            try fm.copyItem(at: shot.file, to: dest.appendingPathComponent(name))
        }
        return dest
    }
}

/// Tracks the generator currently in use so a stalled decoder can be cancelled from outside the loop.
private final class StallWatch: @unchecked Sendable {
    private let lock = NSLock()
    private var last = Date()
    private var generator: AVAssetImageGenerator?

    func watch(_ generator: AVAssetImageGenerator) {
        lock.withLock {
            self.generator = generator
            last = Date()
        }
    }

    func tick() {
        lock.withLock { last = Date() }
    }

    func kickIfStalled(after seconds: Double) {
        lock.withLock {
            guard Date().timeIntervalSince(last) > seconds else { return }
            generator?.cancelAllCGImageGeneration()
            last = Date()
        }
    }

    func cancelCurrent() {
        lock.withLock { generator?.cancelAllCGImageGeneration() }
    }
}

enum ImageFiles {
    @discardableResult
    static func write(_ image: CGImage, to url: URL, type: UTType, quality: Double = 0.9) -> Bool {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else { return false }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        return CGImageDestinationFinalize(dest)
    }

    static func thumbnail(_ url: URL, maxPixel: CGFloat) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxPixel.rounded(.up)),
        ]
        return CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
    }

    static func scaled(_ image: CGImage, maxSide: CGFloat) -> CGImage {
        let w = CGFloat(image.width), h = CGFloat(image.height)
        let k = min(1, maxSide / max(w, h))
        let tw = max(1, Int(w * k)), th = max(1, Int(h * k))
        guard let ctx = CGContext(data: nil, width: tw, height: th, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return image }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: tw, height: th))
        return ctx.makeImage() ?? image
    }
}
