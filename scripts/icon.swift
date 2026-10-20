import AppKit

// Renders the 1024×1024 app icon master: swift scripts/icon.swift out.png
let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
    let rect = NSRect(x: 100, y: 100, width: 824, height: 824)
    let path = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)
    NSGradient(starting: NSColor(red: 1.0, green: 0.55, blue: 0.2, alpha: 1),
               ending: NSColor(red: 0.93, green: 0.2, blue: 0.45, alpha: 1))!.draw(in: path, angle: -60)

    let white = NSColor.white
    let cell = NSSize(width: 250, height: 160)
    let gap: CGFloat = 36
    let originX = rect.midX - cell.width - gap / 2
    let originY = rect.midY - (cell.height * 3 + gap * 2) / 2
    for row in 0..<3 {
        for col in 0..<2 {
            let r = NSRect(x: originX + CGFloat(col) * (cell.width + gap),
                           y: originY + CGFloat(row) * (cell.height + gap),
                           width: cell.width, height: cell.height)
            white.withAlphaComponent(row == 1 && col == 1 ? 1 : 0.82).setFill()
            NSBezierPath(roundedRect: r, xRadius: 26, yRadius: 26).fill()
        }
    }
    return true
}

let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
