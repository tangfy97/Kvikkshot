import AppKit
import AVFoundation
import Observation
import UniformTypeIdentifiers

let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("Kvikkshot", isDirectory: true)

enum ExtractMode: String { case interval, count }

enum ShotFormat: String {
    case jpg, png
    var type: UTType { self == .png ? .png : .jpeg }
}

struct ExtractSettings: Equatable {
    var mode: ExtractMode
    var interval: Double
    var count: Int
    var precise: Bool
    var format: ShotFormat
    var quality: Double
}

struct VideoInfo {
    let url: URL
    let duration: Double
    let size: CGSize
    let fps: Float
    let fileSize: Int64

    var name: String { url.deletingPathExtension().lastPathComponent }
    var aspect: CGFloat { size.width > 0 && size.height > 0 ? size.width / size.height : 16.0 / 9.0 }

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
    let file: URL
    let thumbFile: URL
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
final class VideoItem: Identifiable {
    enum Status { case pending, extracting, done }

    let id = UUID()
    let info: VideoInfo
    let asset: AVURLAsset
    var shots: [Shot] = []
    var deselected: Set<Int> = []
    var status = Status.pending
    var total = 0
    var failed = 0
    var elapsed: Double?
    fileprivate var generation = 0
    fileprivate var workDir: URL?

    init(info: VideoInfo, asset: AVURLAsset) {
        self.info = info
        self.asset = asset
    }

    var selectedShots: [Shot] { shots.filter { !deselected.contains($0.id) } }
    var selectedCount: Int { shots.count - deselected.count }

    func toggle(_ id: Int) {
        if deselected.contains(id) { deselected.remove(id) } else { deselected.insert(id) }
    }

    func toggleAll() {
        deselected = deselected.isEmpty ? Set(shots.map(\.id)) : []
    }

    fileprivate func reset() {
        generation += 1
        shots = []
        deselected = []
        status = .pending
        total = 0
        failed = 0
        elapsed = nil
        if let workDir { try? FileManager.default.removeItem(at: workDir) }
        workDir = nil
    }

    fileprivate func insert(_ shot: Shot) {
        let i = shots.firstIndex { $0.id > shot.id } ?? shots.endIndex
        shots.insert(shot, at: i)
    }
}

/// Holds every open video and runs extraction for them one at a time, the selected video first.
@MainActor @Observable
final class AppModel {
    var videos: [VideoItem] = []
    var selectedID: VideoItem.ID?
    var alert: AppAlert?
    var showShareImage = false

    private var settings: ExtractSettings?
    private var runner: Task<Void, Never>?
    private var runnerToken = 0

    var selected: VideoItem? { videos.first { $0.id == selectedID } ?? videos.first }
    var isBusy: Bool { videos.contains { $0.status != .done } }
    var canExport: Bool { selected.map { $0.status == .done && $0.selectedCount > 0 } ?? false }
    var canExportAll: Bool { videos.count > 1 && !isBusy && videos.contains { $0.selectedCount > 0 } }

    // MARK: Videos

    func chooseVideos() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video, .audiovisualContent]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls
        Task { await add(urls) }
    }

    func add(_ urls: [URL]) async {
        var unreadable: [String] = []
        for url in urls {
            if let existing = videos.first(where: { $0.info.url == url }) {
                selectedID = existing.id
                continue
            }
            if let item = await Self.load(url) {
                videos.append(item)
                selectedID = item.id
            } else {
                unreadable.append(url.lastPathComponent)
            }
        }
        if !unreadable.isEmpty {
            let names = ListFormatter.localizedString(byJoining: unreadable)
            alert = AppAlert(
                title: String(localized: "Can't Open Video"),
                message: String(localized: "“\(names)” can't be read. Kvikkshot supports formats macOS can play, such as MP4, MOV and M4V. MKV, AVI and WebM need to be converted first."))
        }
        startRunner()
    }

    private static func load(_ url: URL) async -> VideoItem? {
        let asset = AVURLAsset(url: url)
        do {
            let (duration, readable) = try await asset.load(.duration, .isReadable)
            guard readable, let track = try await asset.loadTracks(withMediaType: .video).first else { return nil }
            let (natural, transform, fps) = try await track.load(.naturalSize, .preferredTransform, .nominalFrameRate)
            let size = natural.applying(transform)
            let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let info = VideoInfo(url: url, duration: duration.seconds,
                                 size: CGSize(width: abs(size.width), height: abs(size.height)),
                                 fps: fps, fileSize: Int64(bytes))
            return VideoItem(info: info, asset: asset)
        } catch {
            return nil
        }
    }

    func remove(_ item: VideoItem) {
        guard let index = videos.firstIndex(where: { $0.id == item.id }) else { return }
        let wasRunning = item.status == .extracting
        if wasRunning { stopRunner() }
        item.reset()
        videos.remove(at: index)
        if selectedID == item.id {
            selectedID = videos.isEmpty ? nil : videos[min(index, videos.count - 1)].id
            showShareImage = false
        }
        if videos.isEmpty { closeAll() } else if wasRunning { startRunner() }
    }

    /// Back to the start screen. Every cached screenshot and share image is deleted.
    func closeAll() {
        stopRunner()
        for item in videos { item.reset() }
        videos = []
        selectedID = nil
        showShareImage = false
        Thumbnails.clear()
        try? FileManager.default.removeItem(at: tempRoot)
    }

    // MARK: Extraction

    func apply(_ settings: ExtractSettings) {
        guard settings != self.settings else { return }
        self.settings = settings
        stopRunner()
        for item in videos { item.reset() }
        startRunner()
    }

    private func startRunner() {
        guard runner == nil, let settings else { return }
        runnerToken += 1
        let token = runnerToken
        runner = Task { [weak self] in
            while !Task.isCancelled, let self, let next = self.nextPending() {
                await self.extract(next, settings: settings)
            }
            if let self, self.runnerToken == token { self.runner = nil }
        }
    }

    private func stopRunner() {
        runner?.cancel()
        runner = nil
        for item in videos where item.status == .extracting { item.reset() }
    }

    private func nextPending() -> VideoItem? {
        if let selected, selected.status == .pending { return selected }
        return videos.first { $0.status == .pending }
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

    private func extract(_ item: VideoItem, settings: ExtractSettings) async {
        item.reset()
        let gen = item.generation
        let times = Self.times(mode: settings.mode, interval: settings.interval, count: settings.count, duration: item.info.duration)
        item.total = times.count
        item.status = .extracting

        let dir = tempRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        item.workDir = dir

        let start = Date()
        let failed = await Extractor.run(asset: item.asset, url: item.info.url, times: times, settings: settings, dir: dir) { shot in
            await MainActor.run {
                if item.generation == gen { item.insert(shot) }
            }
        }
        guard item.generation == gen else { return }
        if Task.isCancelled {
            item.reset()
            return
        }
        item.failed = failed
        item.elapsed = Date().timeIntervalSince(start)
        item.status = .done
    }

    // MARK: Export

    func exportSelected() {
        guard let item = selected, canExport else { return }
        export([item], message: String(localized: "Choose a folder. A “\(item.info.name) Screenshots” folder will be created inside it."))
    }

    func exportAll() {
        guard canExportAll else { return }
        export(videos.filter { $0.selectedCount > 0 },
               message: String(localized: "Choose a folder. Each video gets its own screenshots folder inside it."))
    }

    private func export(_ items: [VideoItem], message: String) {
        guard let first = items.first, let parent = exportFolder(message: message, near: first.info.url) else { return }
        let scoped = parent.startAccessingSecurityScopedResource()
        defer { if scoped { parent.stopAccessingSecurityScopedResource() } }
        do {
            let created = try items.map { try export($0, to: parent) }
            NSWorkspace.shared.activateFileViewerSelecting(created)
        } catch {
            alert = AppAlert(title: String(localized: "Export Failed"), message: error.localizedDescription)
        }
    }

    /// The default folder from Settings when one is set; otherwise asks, starting from the last folder used.
    private func exportFolder(message: String, near video: URL) -> URL? {
        if let folder = ExportFolder.resolve() { return folder }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = String(localized: "Export Here")
        panel.message = message
        let last = UserDefaults.standard.string(forKey: "lastExportFolder").map { URL(fileURLWithPath: $0) }
        panel.directoryURL = last ?? video.deletingLastPathComponent()
        guard panel.runModal() == .OK, let folder = panel.url else { return nil }
        UserDefaults.standard.set(folder.path, forKey: "lastExportFolder")
        return folder
    }

    private func export(_ item: VideoItem, to parent: URL) throws -> URL {
        let fm = FileManager.default
        let base = String(localized: "\(item.info.name) Screenshots")
        var dest = parent.appendingPathComponent(base, isDirectory: true)
        var n = 2
        while fm.fileExists(atPath: dest.path) {
            dest = parent.appendingPathComponent("\(base) \(n)", isDirectory: true)
            n += 1
        }
        try fm.createDirectory(at: dest, withIntermediateDirectories: false)
        for (i, shot) in item.selectedShots.enumerated() {
            let name = String(format: "%@_%03d_%@.%@", item.info.name, i + 1,
                              formatTime(shot.time, alwaysHours: true, separator: "-"), shot.file.pathExtension)
            try fm.copyItem(at: shot.file, to: dest.appendingPathComponent(name))
        }
        return dest
    }
}

/// Decodes frames off the main actor. Batched so a stalled or crashed decoder only costs one batch,
/// which is then retried frame by frame with a fresh decoder.
enum Extractor {
    private static let batchSize = 16

    /// Returns how many frames could not be read even after retrying.
    static func run(asset: AVURLAsset, url: URL, times: [Double], settings: ExtractSettings, dir: URL,
                    onShot: @escaping @Sendable (Shot) async -> Void) async -> Int {
        // Fast mode: accept the nearest keyframe within 40% of the gap between shots, which avoids most decoding
        let step = times.count > 1 ? times[1] - times[0] : (times.first ?? 1) * 2
        let tolerance = settings.precise ? CMTime.zero : CMTime(seconds: step * 0.4, preferredTimescale: 600)
        func makeGenerator(_ asset: AVAsset) -> AVAssetImageGenerator {
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = tolerance
            generator.requestedTimeToleranceAfter = tolerance
            return generator
        }

        let cmTimes = times.map { CMTime(seconds: $0, preferredTimescale: 600) }
        let watch = StallWatch()
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
                // Decoded full-size frames wait here for encoding; capping them keeps memory flat
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
                        await onShot(save(image, id: id, time: time.seconds, dir: dir, settings: settings))
                    }
                }

                var generator = makeGenerator(asset)
                for batchStart in stride(from: 0, to: cmTimes.count, by: batchSize) {
                    if Task.isCancelled { break }
                    let ids = Array(batchStart..<min(batchStart + batchSize, cmTimes.count))
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
        return stillFailed
    }

    private static func save(_ image: CGImage, id: Int, time: Double, dir: URL, settings: ExtractSettings) -> Shot {
        let file = dir.appendingPathComponent(String(format: "%04d.%@", id, settings.format.rawValue))
        let thumbFile = dir.appendingPathComponent(String(format: "%04d_thumb.jpg", id))
        ImageFiles.write(image, to: file, type: settings.format.type, quality: settings.quality)
        ImageFiles.write(ImageFiles.scaled(image, maxSide: 480), to: thumbFile, type: .jpeg, quality: 0.8)
        return Shot(id: id, time: time, file: file, thumbFile: thumbFile)
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

/// Thumbnails are read from disk on demand, so memory stays flat however many videos are open.
enum Thumbnails {
    private static let cache: NSCache<NSURL, NSImage> = {
        let cache = NSCache<NSURL, NSImage>()
        cache.countLimit = 600
        return cache
    }()

    static func image(for url: URL) async -> NSImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        let image = await Task.detached(priority: .userInitiated) {
            ImageFiles.thumbnail(url, maxPixel: 480).map { NSImage(cgImage: $0, size: .zero) }
        }.value
        if let image { cache.setObject(image, forKey: url as NSURL) }
        return image
    }

    static func clear() {
        cache.removeAllObjects()
    }
}

/// The optional default export folder from Settings, kept as a security-scoped bookmark.
enum ExportFolder {
    static let key = "defaultExportFolder"

    /// Returns nil when no folder is set or it no longer exists, so export falls back to asking.
    static func resolve(_ data: Data? = UserDefaults.standard.data(forKey: key)) -> URL? {
        guard let data else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, bookmarkDataIsStale: &stale) else {
            return nil
        }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard (try? url.checkResourceIsReachable()) == true else { return nil }
        // A moved or renamed folder still resolves; refresh the bookmark so it keeps doing so.
        if stale, let fresh = bookmark(for: url) { UserDefaults.standard.set(fresh, forKey: key) }
        return url
    }

    static func bookmark(for url: URL) -> Data? {
        try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
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
            kCGImageSourceShouldCacheImmediately: true,
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
