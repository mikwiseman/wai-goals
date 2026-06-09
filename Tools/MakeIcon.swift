import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation

// Renders the 1024×1024 app icon: an indigo→violet gradient with two bold
// white checkmarks that meet at the centre and together read as a rising "W"
// — a nod to goals (✓✓) and to Wai (W). Usage: swift MakeIcon.swift <output.png>

let size = 1024
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                          bytesPerRow: 0, space: colorSpace,
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("Could not create context")
}

let s = CGFloat(size)

// Background gradient (indigo top-left → violet bottom-right)
let bgColors = [
    CGColor(red: 0.40, green: 0.36, blue: 0.96, alpha: 1),
    CGColor(red: 0.67, green: 0.39, blue: 0.93, alpha: 1)
] as CFArray
let bg = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])

// Soft central glow
let glowColors = [
    CGColor(red: 1, green: 1, blue: 1, alpha: 0.20),
    CGColor(red: 1, green: 1, blue: 1, alpha: 0)
] as CFArray
let glow = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: CGPoint(x: s/2, y: s/2), startRadius: 0,
                       endCenter: CGPoint(x: s/2, y: s/2), endRadius: s * 0.52, options: [])

// Two bold checkmarks meeting at the centre → a rising "W" (CG origin is
// bottom-left). The left tick's long arm and the right tick's short arm kiss
// in the middle, so the mark reads as both ✓✓ and W.
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.setLineWidth(94)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)

func tick(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) {
    ctx.beginPath()
    ctx.move(to: a)
    ctx.addLine(to: b)
    ctx.addLine(to: c)
    ctx.strokePath()
}

// Left checkmark: short arm down to the valley, long arm up to the centre.
tick(CGPoint(x: 202, y: 522), CGPoint(x: 322, y: 397), CGPoint(x: 517, y: 627))
// Right checkmark: congruent, shifted right so it starts where the first peaks.
tick(CGPoint(x: 507, y: 522), CGPoint(x: 627, y: 397), CGPoint(x: 822, y: 627))

guard let image = ctx.makeImage() else { fatalError("Could not render image") }
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
let url = URL(fileURLWithPath: outPath) as CFURL
guard let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("Could not create destination")
}
CGImageDestinationAddImage(dest, image, nil)
if CGImageDestinationFinalize(dest) {
    print("Wrote icon to \(outPath)")
} else {
    fatalError("Could not write PNG")
}
