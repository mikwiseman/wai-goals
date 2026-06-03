import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation

// Renders the 1024×1024 app icon: an indigo→violet gradient with a bold,
// upward-rising white checkmark. Usage: swift MakeIcon.swift <output.png>

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

// Bold rising checkmark (CG origin is bottom-left)
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.setLineWidth(112)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.beginPath()
ctx.move(to: CGPoint(x: 300, y: 545))
ctx.addLine(to: CGPoint(x: 455, y: 395))
ctx.addLine(to: CGPoint(x: 740, y: 700))
ctx.strokePath()

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
