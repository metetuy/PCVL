// Draws the DMG window background: just an arrow from the app to the Applications
// shortcut, at 1x and 2x (release.sh combines them into one Retina-aware TIFF).
// Positions match the icon positions in release.sh.
//
// The slate background keeps Finder's icon labels readable in both appearances:
// Finder draws them black in Light Mode and white in Dark Mode.
//
//   swift scripts/dmg-background.swift <output folder>

import AppKit

// The window shows 560x300; the extra height covers title bar differences.
let size = NSSize(width: 560, height: 320)
let output = URL(fileURLWithPath: CommandLine.arguments[1])

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

    // Arrow between the icons, centered at x 150 and 410, y 140 from the top (Finder's
    // coordinates; AppKit's run from the bottom).
    let y = size.height - 140
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 236, y: y))
    arrow.line(to: NSPoint(x: 322, y: y))
    arrow.move(to: NSPoint(x: 306, y: y + 14))
    arrow.line(to: NSPoint(x: 322, y: y))
    arrow.line(to: NSPoint(x: 306, y: y - 14))
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
