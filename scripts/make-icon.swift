// Renders the reMarkable Share logo.
//   swift scripts/make-icon.swift <output-dir>
// Produces <output-dir>/AppIcon.iconset (for iconutil) and <output-dir>/logo.png (1024 px).
//
// Design: a reMarkable-style paper tablet (wide grip bezel on the left, handwriting on
// the page, stylus resting on it) beaming its screen out through orange
// broadcast arcs, on a dark charcoal tile so it stands apart from the official white icon.
import AppKit

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let iconset = outDir.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let orange = NSColor(srgbRed: 0.965, green: 0.510, blue: 0.122, alpha: 1)   // #F6821F
let orangeLight = NSColor(srgbRed: 0.984, green: 0.678, blue: 0.255, alpha: 1)
let paper = NSColor(srgbRed: 0.965, green: 0.957, blue: 0.937, alpha: 1)
let bezel = NSColor(srgbRed: 0.86, green: 0.85, blue: 0.83, alpha: 1)
let ink = NSColor(srgbRed: 0.13, green: 0.13, blue: 0.14, alpha: 1)

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    ctx.imageInterpolation = .high
    func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x * s, y: y * s) }

    // Tile (macOS grid: ~80% body), dark charcoal gradient with a subtle top highlight.
    let tile = NSRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: tile.width * 0.225, yRadius: tile.width * 0.225)
    NSGradient(starting: NSColor(srgbRed: 0.20, green: 0.20, blue: 0.22, alpha: 1),
               ending: NSColor(srgbRed: 0.07, green: 0.07, blue: 0.08, alpha: 1))!.draw(in: tilePath, angle: -90)
    NSGraphicsContext.saveGraphicsState()
    tilePath.addClip()
    NSGradient(starting: NSColor(white: 1, alpha: 0.10), ending: NSColor(white: 1, alpha: 0))!
        .draw(in: NSRect(x: tile.minX, y: tile.midY, width: tile.width, height: tile.height / 2), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // Everything below is clipped to the tile and nudged left/down to balance the arcs.
    NSGraphicsContext.saveGraphicsState()
    tilePath.addClip()
    let nudge = NSAffineTransform(); nudge.translateX(by: -s * 0.03, yBy: -s * 0.02); nudge.concat()

    // Broadcast arcs from the tablet's top-right corner.
    let origin = p(0.605, 0.685)
    for (i, r) in [0.075, 0.13, 0.185].enumerated() {
        let arc = NSBezierPath()
        arc.appendArc(withCenter: origin, radius: s * r, startAngle: 8, endAngle: 82)
        arc.lineWidth = s * 0.03
        arc.lineCapStyle = .round
        (i == 0 ? orangeLight : orange).withAlphaComponent(1 - CGFloat(i) * 0.18).setStroke()
        arc.stroke()
    }

    // Tablet with soft shadow.
    let tablet = NSRect(x: s * 0.24, y: s * 0.19, width: s * 0.36, height: s * 0.49)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(white: 0, alpha: 0.45)
    shadow.shadowBlurRadius = s * 0.03
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.012)
    shadow.set()
    bezel.setFill()
    NSBezierPath(roundedRect: tablet, xRadius: s * 0.035, yRadius: s * 0.035).fill()
    NSGraphicsContext.restoreGraphicsState()

    // Page (wider bezel on the left, like the reMarkable 2 grip).
    let page = NSRect(x: tablet.minX + s * 0.055, y: tablet.minY + s * 0.025,
                      width: tablet.width - s * 0.08, height: tablet.height - s * 0.05)
    paper.setFill()
    NSBezierPath(roundedRect: page, xRadius: s * 0.012, yRadius: s * 0.012).fill()

    // Ruled lines + handwriting.
    ink.withAlphaComponent(0.10).setStroke()
    for k in 0..<5 {
        let y = page.maxY - s * 0.07 - CGFloat(k) * s * 0.07
        let line = NSBezierPath(); line.move(to: NSPoint(x: page.minX + s * 0.025, y: y))
        line.line(to: NSPoint(x: page.maxX - s * 0.025, y: y)); line.lineWidth = max(1, s * 0.004); line.stroke()
    }
    let scribble = NSBezierPath()
    scribble.move(to: p(0.33, 0.50))
    scribble.curve(to: p(0.39, 0.555), controlPoint1: p(0.34, 0.56), controlPoint2: p(0.375, 0.57))
    scribble.curve(to: p(0.425, 0.47), controlPoint1: p(0.40, 0.54), controlPoint2: p(0.39, 0.46))
    scribble.curve(to: p(0.47, 0.545), controlPoint1: p(0.45, 0.48), controlPoint2: p(0.455, 0.55))
    scribble.curve(to: p(0.53, 0.47), controlPoint1: p(0.49, 0.54), controlPoint2: p(0.50, 0.46))
    scribble.lineWidth = s * 0.022
    scribble.lineCapStyle = .round
    scribble.lineJoinStyle = .round
    ink.setStroke()
    scribble.stroke()
    let underline = NSBezierPath()
    underline.move(to: p(0.33, 0.40)); underline.curve(to: p(0.50, 0.405), controlPoint1: p(0.38, 0.39), controlPoint2: p(0.45, 0.415))
    underline.lineWidth = s * 0.012; underline.lineCapStyle = .round
    orange.setStroke(); underline.stroke()

    // Stylus resting diagonally across the lower-right corner.
    NSGraphicsContext.saveGraphicsState()
    let t = NSAffineTransform()
    t.translateX(by: s * 0.515, yBy: s * 0.30); t.rotate(byDegrees: 40); t.concat()
    let len = s * 0.29, w = s * 0.03
    let body = NSBezierPath(roundedRect: NSRect(x: 0, y: -w / 2, width: len, height: w), xRadius: w / 2, yRadius: w / 2)
    NSGradient(starting: NSColor(white: 0.96, alpha: 1), ending: NSColor(white: 0.72, alpha: 1))!.draw(in: body, angle: 90)
    let tip = NSBezierPath()
    tip.move(to: NSPoint(x: 0, y: -w / 2 + w * 0.08)); tip.line(to: NSPoint(x: -w * 0.9, y: 0))
    tip.line(to: NSPoint(x: 0, y: w / 2 - w * 0.08)); tip.close()
    NSColor(white: 0.30, alpha: 1).setFill(); tip.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState() // clip + nudge
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try render(base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
try render(1024).write(to: outDir.appendingPathComponent("logo.png"))
print(iconset.path)
