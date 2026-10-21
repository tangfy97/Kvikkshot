import AppKit

// Renders the app icon — a contact sheet with the chosen frame circled in red grease pencil —
// straight into the asset catalog at every size. Sizes up to 64 px use a simplified single strip
// so the icon still reads in Finder lists and small Dock sizes.
// usage: swift scripts/icon.swift Kvikkshot/Assets.xcassets/AppIcon.appiconset
let out = URL(fileURLWithPath: CommandLine.arguments[1])
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)

func hex(_ v: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xff) / 255, green: CGFloat((v >> 8) & 0xff) / 255, blue: CGFloat(v & 0xff) / 255, alpha: 1)
}

let paper = hex(0xF2EDE3), film = hex(0x26231F), frame = hex(0x5C5750), chosen = hex(0x8FA3A8), pencil = hex(0xD2382E)

/// A hand-drawn loop: an ellipse whose ends overshoot, with a slight wobble and tilt.
func loop(around centre: NSPoint, rx: CGFloat, ry: CGFloat, width: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    for i in 0...110 {
        let t = CGFloat(i) / 100 * 2 * .pi + 0.6
        let wobble = 1 + 0.035 * sin(t * 3.1) + 0.02 * cos(t * 5.3)
        let p = NSPoint(x: centre.x + (rx * wobble + CGFloat(i) * rx / 670) * cos(t),
                        y: centre.y + (ry * wobble + CGFloat(i) * ry / 980) * sin(t) - CGFloat(i) * 0.1)
        i == 0 ? path.move(to: p) : path.line(to: p)
    }
    var tilt = AffineTransform(translationByX: centre.x, byY: centre.y)
    tilt.rotate(byDegrees: -8)
    tilt.translate(x: -centre.x, y: -centre.y)
    path.transform(using: tilt)
    path.lineWidth = width
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    return path
}

/// Draws rows of film strips (frames on a dark rebate), highlighting the centre frame.
func strips(rows: Int, frameSize: NSSize, gap: NSSize, rebate: CGFloat) {
    let cols = 3
    let gridW = CGFloat(cols) * frameSize.width + CGFloat(cols - 1) * gap.width
    let gridH = CGFloat(rows) * frameSize.height + CGFloat(rows - 1) * gap.height
    let x0 = tile.midX - gridW / 2, y0 = tile.midY - gridH / 2
    for r in 0..<rows {
        let y = y0 + CGFloat(r) * (frameSize.height + gap.height)
        film.setFill()
        NSRect(x: tile.minX - 10, y: y - rebate, width: tile.width + 20, height: frameSize.height + rebate * 2).fill()
        for c in 0..<cols {
            let f = NSRect(x: x0 + CGFloat(c) * (frameSize.width + gap.width), y: y, width: frameSize.width, height: frameSize.height)
            (r == rows / 2 && c == 1 ? chosen : frame).setFill()
            NSBezierPath(roundedRect: f, xRadius: 6, yRadius: 6).fill()
        }
    }
}

func drawIcon(simplified: Bool) {
    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = .black.withAlphaComponent(0.28)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    let squircle = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
    paper.setFill()
    squircle.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    NSGraphicsContext.current?.saveGraphicsState()
    squircle.addClip()
    let centre = NSPoint(x: tile.midX + 4, y: tile.midY + 2)
    if simplified {
        strips(rows: 1, frameSize: NSSize(width: 230, height: 170), gap: NSSize(width: 34, height: 0), rebate: 36)
        pencil.setStroke()
        loop(around: centre, rx: 195, ry: 150, width: 46).stroke()
    } else {
        strips(rows: 3, frameSize: NSSize(width: 196, height: 132), gap: NSSize(width: 26, height: 54), rebate: 14)
        pencil.setStroke()
        loop(around: centre, rx: 168, ry: 118, width: 20).stroke()
    }
    NSGraphicsContext.current?.restoreGraphicsState()
}

func write(pixels: Int, simplified: Bool, name: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    let k = CGFloat(pixels) / 1024
    NSGraphicsContext.current?.cgContext.scaleBy(x: k, y: k)
    drawIcon(simplified: simplified)
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent(name))
}

for px in [16, 32, 64, 128, 256, 512, 1024] {
    write(pixels: px, simplified: px <= 64, name: "icon_\(px).png")
}
