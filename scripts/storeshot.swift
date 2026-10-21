import AppKit

// Composes a 2880×1800 App Store screenshot: a window capture on the icon's paper colour,
// under a headline and a subline.
//
//   swift scripts/storeshot.swift <window.png> <out.jpg> <headline> <subline>
//
// Window captures come from `screencapture -o -l <window id>` (no shadow; one is added here).
let args = CommandLine.arguments
let window = NSImage(contentsOf: URL(fileURLWithPath: args[1]))!
let out = URL(fileURLWithPath: args[2])
let headline = args[3], subline = args[4]

let W: CGFloat = 2880, H: CGFloat = 1800
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: W, height: H)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

NSColor(srgbRed: 0xF2 / 255, green: 0xED / 255, blue: 0xE3 / 255, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: W, height: H).fill()

let centred = NSMutableParagraphStyle()
centred.alignment = .center
NSAttributedString(string: headline, attributes: [
    .font: NSFont.systemFont(ofSize: 104, weight: .bold),
    .foregroundColor: NSColor(srgbRed: 0.13, green: 0.12, blue: 0.11, alpha: 1),
    .paragraphStyle: centred,
]).draw(in: NSRect(x: 120, y: H - 250, width: W - 240, height: 140))
NSAttributedString(string: subline, attributes: [
    .font: NSFont.systemFont(ofSize: 46, weight: .regular),
    .foregroundColor: NSColor(srgbRed: 0.13, green: 0.12, blue: 0.11, alpha: 0.6),
    .paragraphStyle: centred,
]).draw(in: NSRect(x: 120, y: H - 340, width: W - 240, height: 70))

// The window, as large as fits below the text, bottom edge running off the canvas a little
let maxH: CGFloat = H - 400
let scale = min((W - 320) / window.size.width, maxH / window.size.height)
let size = NSSize(width: window.size.width * scale, height: window.size.height * scale)
let frame = NSRect(x: (W - size.width) / 2, y: H - 400 - size.height + 30, width: size.width, height: size.height)
NSGraphicsContext.current?.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = .black.withAlphaComponent(0.35)
shadow.shadowBlurRadius = 60
shadow.shadowOffset = NSSize(width: 0, height: -24)
shadow.set()
window.draw(in: frame, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
            hints: [.interpolation: NSNumber(value: NSImageInterpolation.high.rawValue)])
NSGraphicsContext.current?.restoreGraphicsState()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])!.write(to: out)
