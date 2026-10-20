import SwiftUI
import UniformTypeIdentifiers

struct SheetView: View {
    let shots: [Shot]
    let video: VideoInfo

    @Environment(\.dismiss) private var dismiss
    @AppStorage("sheet.columns") private var columns = 4
    @AppStorage("sheet.width") private var width = 2400
    @AppStorage("sheet.dark") private var dark = true
    @AppStorage("sheet.time") private var showTime = true
    @AppStorage("sheet.header") private var showHeader = true
    @State private var image: CGImage?
    @State private var file: URL?
    @State private var copied = false

    private var options: SheetOptions {
        SheetOptions(columns: columns, width: width, dark: dark, showTime: showTime, showHeader: showHeader)
    }

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                Color(nsColor: .underPageBackgroundColor)
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFit()
                        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
                        .padding(28)
                } else {
                    ProgressView()
                }
            }
            .frame(minWidth: 520, idealWidth: 680, maxWidth: .infinity, minHeight: 520, idealHeight: 560, maxHeight: .infinity)

            Divider()

            VStack(alignment: .leading, spacing: 18) {
                Text("Share Image").font(.title3.bold())

                Form {
                    Stepper("Columns: \(columns)", value: $columns, in: 1...10)
                    Picker("Width", selection: $width) {
                        Text(verbatim: "1600 px").tag(1600)
                        Text(verbatim: "2400 px").tag(2400)
                        Text(verbatim: "3600 px").tag(3600)
                    }
                    Picker("Background", selection: $dark) {
                        Text("Dark").tag(true)
                        Text("Light").tag(false)
                    }
                    .pickerStyle(.segmented)
                    Toggle("Timestamps", isOn: $showTime)
                    Toggle("Video Info", isOn: $showHeader)
                }

                if let image {
                    Text(verbatim: "\(image.width) × \(image.height) · \(shotCount(shots.count))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(spacing: 8) {
                    Button(action: copy) {
                        Group {
                            if copied {
                                Label("Copied", systemImage: "checkmark")
                            } else {
                                Label("Copy Image", systemImage: "doc.on.doc")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("c")

                    Button(action: save) {
                        Label("Save…", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity)
                    }
                    .keyboardShortcut("s")

                    if let file {
                        ShareLink(item: file) {
                            Label("Share…", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                        }
                    }

                    Button("Close") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .disabled(image == nil)
            }
            .frame(width: 250)
            .padding(20)
        }
        .fixedSize(horizontal: false, vertical: false)
        .task(id: options) {
            let options = options, shots = shots, video = video
            let result = await Task.detached(priority: .userInitiated) { () -> (CGImage, URL)? in
                guard let image = SheetRenderer.render(shots: shots, video: video, options: options) else { return nil }
                let url = tempRoot.appendingPathComponent(String(localized: "\(video.name) Share Image") + ".jpg")
                ImageFiles.write(image, to: url, type: .jpeg, quality: 0.9)
                return (image, url)
            }.value
            guard !Task.isCancelled, let result else { return }
            image = result.0
            file = result.1
            copied = false
        }
    }

    private func copy() {
        guard let image else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([NSImage(cgImage: image, size: .zero)])
        copied = true
    }

    private func save() {
        guard let image else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.jpeg, .png]
        panel.nameFieldStringValue = String(localized: "\(video.name) Share Image") + ".jpg"
        panel.directoryURL = video.url.deletingLastPathComponent()
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let type: UTType = url.pathExtension.lowercased() == "png" ? .png : .jpeg
        ImageFiles.write(image, to: url, type: type, quality: 0.92)
    }
}

struct SheetOptions: Hashable {
    var columns: Int
    var width: Int
    var dark: Bool
    var showTime: Bool
    var showHeader: Bool
}

enum SheetRenderer {
    static func render(shots: [Shot], video: VideoInfo, options o: SheetOptions) -> CGImage? {
        guard !shots.isEmpty else { return nil }

        let W = CGFloat(o.width)
        let s = W / 2400
        let pad = (56 * s).rounded()
        let gap = (14 * s).rounded()
        let cols = max(1, min(o.columns, shots.count))
        let rows = (shots.count + cols - 1) / cols
        let cellW = ((W - pad * 2 - gap * CGFloat(cols - 1)) / CGFloat(cols)).rounded(.down)
        let aspect = video.size.width > 0 ? video.size.height / video.size.width : 9.0 / 16.0
        let cellH = (cellW * aspect).rounded()
        let headerH = o.showHeader ? (132 * s).rounded() : 0
        let H = pad * 2 + headerH + CGFloat(rows) * cellH + CGFloat(rows - 1) * gap

        // Decode in parallel, straight from the full-size files at the size each cell needs
        var images = [CGImage?](repeating: nil, count: shots.count)
        let maxPixel = max(cellW, cellH)
        images.withUnsafeMutableBufferPointer { buffer in
            let buffer = buffer
            DispatchQueue.concurrentPerform(iterations: shots.count) { i in
                buffer[i] = ImageFiles.thumbnail(shots[i].file, maxPixel: maxPixel)
            }
        }

        guard let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return nil }
        ctx.translateBy(x: 0, y: H)
        ctx.scaleBy(x: 1, y: -1)
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)

        let background = o.dark ? NSColor(white: 0.07, alpha: 1) : NSColor(white: 0.97, alpha: 1)
        let foreground = o.dark ? NSColor.white : NSColor(white: 0.1, alpha: 1)
        background.setFill()
        CGRect(x: 0, y: 0, width: W, height: H).fill()

        var y = pad
        if o.showHeader {
            let truncating = NSMutableParagraphStyle()
            truncating.lineBreakMode = .byTruncatingTail
            NSAttributedString(string: video.name, attributes: [
                .font: NSFont.systemFont(ofSize: 46 * s, weight: .bold),
                .foregroundColor: foreground,
                .paragraphStyle: truncating,
            ]).draw(in: CGRect(x: pad, y: y, width: W - pad * 2, height: 60 * s))
            NSAttributedString(string: "\(video.summary) · \(shotCount(shots.count))", attributes: [
                .font: NSFont.systemFont(ofSize: 26 * s, weight: .regular),
                .foregroundColor: foreground.withAlphaComponent(0.55),
                .paragraphStyle: truncating,
            ]).draw(in: CGRect(x: pad, y: y + 66 * s, width: W - pad * 2, height: 40 * s))
            y += headerH
        }

        let gridW = CGFloat(cols) * cellW + CGFloat(cols - 1) * gap
        let x0 = ((W - gridW) / 2).rounded()
        let radius = 10 * s
        let timeAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 22 * s, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let hints: [NSImageRep.HintKey: Any] = [.interpolation: NSNumber(value: NSImageInterpolation.high.rawValue)]

        for (i, shot) in shots.enumerated() {
            let r = CGRect(x: x0 + CGFloat(i % cols) * (cellW + gap),
                           y: y + CGFloat(i / cols) * (cellH + gap),
                           width: cellW, height: cellH)
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius).addClip()
            if let img = images[i] {
                NSImage(cgImage: img, size: .zero).draw(in: aspectFill(img, in: r), from: .zero, operation: .sourceOver,
                                                         fraction: 1, respectFlipped: true, hints: hints)
            } else {
                foreground.withAlphaComponent(0.08).setFill()
                r.fill()
            }
            NSGraphicsContext.restoreGraphicsState()

            if o.showTime {
                let text = NSAttributedString(string: formatTime(shot.time), attributes: timeAttrs)
                let size = text.size()
                let hp = 9 * s, vp = 4 * s, inset = 10 * s
                let badge = CGRect(x: r.maxX - size.width - hp * 2 - inset,
                                   y: r.maxY - size.height - vp * 2 - inset,
                                   width: size.width + hp * 2, height: size.height + vp * 2)
                NSColor.black.withAlphaComponent(0.6).setFill()
                NSBezierPath(roundedRect: badge, xRadius: 6 * s, yRadius: 6 * s).fill()
                text.draw(at: CGPoint(x: badge.minX + hp, y: badge.minY + vp))
            }
        }

        return ctx.makeImage()
    }

    private static func aspectFill(_ image: CGImage, in rect: CGRect) -> CGRect {
        let k = max(rect.width / CGFloat(image.width), rect.height / CGFloat(image.height))
        let w = CGFloat(image.width) * k, h = CGFloat(image.height) * k
        return CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h)
    }
}
