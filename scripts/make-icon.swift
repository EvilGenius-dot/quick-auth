import AppKit
import Foundation

let destination = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let transform = AffineTransform(scale: CGFloat(pixels) / 1024)
        (transform as NSAffineTransform).concat()
        let rect = NSRect(x: 92, y: 92, width: 840, height: 840)
        let background = NSBezierPath(roundedRect: rect, xRadius: 190, yRadius: 190)
        let gradient = NSGradient(starting: NSColor(red: 0.035, green: 0.040, blue: 0.055, alpha: 1),
                                  ending: NSColor(red: 0.23, green: 0.25, blue: 0.30, alpha: 1))!
        gradient.draw(in: background, angle: 65)
        NSColor.white.withAlphaComponent(0.23).setStroke()
        background.lineWidth = 2.5
        background.stroke()
        let shield = NSBezierPath()
        shield.move(to: NSPoint(x: 512, y: 772))
        shield.curve(to: NSPoint(x: 728, y: 692), controlPoint1: NSPoint(x: 593, y: 720), controlPoint2: NSPoint(x: 671, y: 702))
        shield.line(to: NSPoint(x: 728, y: 530))
        shield.curve(to: NSPoint(x: 512, y: 279), controlPoint1: NSPoint(x: 728, y: 398), controlPoint2: NSPoint(x: 619, y: 316))
        shield.curve(to: NSPoint(x: 296, y: 530), controlPoint1: NSPoint(x: 405, y: 316), controlPoint2: NSPoint(x: 296, y: 398))
        shield.line(to: NSPoint(x: 296, y: 692))
        shield.curve(to: NSPoint(x: 512, y: 772), controlPoint1: NSPoint(x: 353, y: 702), controlPoint2: NSPoint(x: 431, y: 720))
        shield.close()
        NSColor.white.withAlphaComponent(0.96).setStroke()
        shield.lineWidth = 26; shield.lineJoinStyle = .round; shield.stroke()
        NSColor.white.setFill()
        for x in [420, 512, 604] { NSBezierPath(ovalIn: NSRect(x: x - 23, y: 508, width: 46, height: 46)).fill() }
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(destination)/icon_\(size)x\(size)\(suffix).png"))
    }
}
