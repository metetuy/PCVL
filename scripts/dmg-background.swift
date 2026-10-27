// Draws the DMG window background: just an arrow from the app to the Applications
// shortcut, at 1x and 2x (release.sh combines them into one Retina-aware TIFF).
// release.sh passes the window size and the arrow's position, so they always
// match its icon layout.
//
// The slate background keeps Finder's icon labels readable in both appearances:
// Finder draws them black in Light Mode and white in Dark Mode.
//
//   swift scripts/dmg-background.swift <output folder> <width> <height> <arrow from x> <arrow to x> <arrow y>

import AppKit

let arguments = CommandLine.arguments
let numbers = arguments.dropFirst(2).compactMap(Double.init)
guard arguments.count == 7, numbers.count == 5 else {
    FileHandle.standardError.write(Data("Usage: dmg-background.swift <output folder> <width> <height> <arrow from x> <arrow to x> <arrow y>\n".utf8))
    exit(1)
}
let output = URL(fileURLWithPath: arguments[1])
let size = NSSize(width: numbers[0], height: numbers[1])
// Measured from the top, like Finder's icon positions; AppKit's y runs from the bottom.
let (arrowFrom, arrowTo, arrowY) = (numbers[2], numbers[3], numbers[1] - numbers[4])

func render(scale: CGFloat) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Lighter at the top.
    NSGradient(
        starting: NSColor(srgbRed: 0.48, green: 0.53, blue: 0.60, alpha: 1),
        ending: NSColor(srgbRed: 0.40, green: 0.45, blue: 0.53, alpha: 1)
    )!.draw(in: NSRect(origin: .zero, size: size), angle: -90)

    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: arrowFrom, y: arrowY))
    arrow.line(to: NSPoint(x: arrowTo, y: arrowY))
    arrow.move(to: NSPoint(x: arrowTo - 16, y: arrowY + 14))
    arrow.line(to: NSPoint(x: arrowTo, y: arrowY))
    arrow.line(to: NSPoint(x: arrowTo - 16, y: arrowY - 14))
    arrow.lineWidth = 4
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    NSColor.white.withAlphaComponent(0.85).setStroke()
    arrow.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
try render(scale: 1).write(to: output.appendingPathComponent("background.png"))
try render(scale: 2).write(to: output.appendingPathComponent("background@2x.png"))
