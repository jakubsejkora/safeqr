import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let destination = CommandLine.arguments.dropFirst().first ?? "ios/SafeQR/Resources/Assets.xcassets/AppIcon.appiconset"

func color(_ hex: UInt32) -> CGColor {
    CGColor(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255,
            blue: Double(hex & 255) / 255, alpha: 1)
}

for (name, background, ink, shield) in [
    ("Light", UInt32(0xEEF6F1), UInt32(0x174C47), UInt32(0x246E61)),
    ("Dark", UInt32(0x092B2D), UInt32(0xCCEEE0), UInt32(0x9EDBC5)),
    ("Tinted", UInt32(0x202020), UInt32(0xE8E8E8), UInt32(0xD6D6D6))
] {
    let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    func rounded(_ rect: CGRect, radius: CGFloat, fill: UInt32) {
        context.setFillColor(color(fill))
        context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.fillPath()
    }
    context.setFillColor(color(background))
    context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    for (x, y) in [(180.0, 576.0), (576.0, 576.0), (180.0, 180.0)] {
        rounded(CGRect(x: x, y: y, width: 268, height: 268), radius: 64, fill: ink)
        rounded(CGRect(x: x + 44, y: y + 44, width: 180, height: 180), radius: 29, fill: background)
        rounded(CGRect(x: x + 88, y: y + 88, width: 92, height: 92), radius: 14, fill: ink)
    }
    for (x, y, w, h) in [(180.0, 488.0, 92.0, 44.0), (316, 488, 132, 44), (488, 708, 44, 136), (488, 576, 44, 88), (488, 488, 92, 44)] {
        rounded(CGRect(x: x, y: y, width: w, height: h), radius: 12, fill: ink)
    }
    let shape = CGMutablePath()
    shape.move(to: CGPoint(x: 700, y: 502))
    shape.addCurve(to: CGPoint(x: 850, y: 454), control1: CGPoint(x: 750, y: 476), control2: CGPoint(x: 796, y: 458))
    shape.addLine(to: CGPoint(x: 850, y: 331))
    shape.addCurve(to: CGPoint(x: 700, y: 156), control1: CGPoint(x: 850, y: 247), control2: CGPoint(x: 770, y: 180))
    shape.addCurve(to: CGPoint(x: 550, y: 331), control1: CGPoint(x: 630, y: 180), control2: CGPoint(x: 550, y: 247))
    shape.addLine(to: CGPoint(x: 550, y: 454))
    shape.addCurve(to: CGPoint(x: 700, y: 502), control1: CGPoint(x: 604, y: 458), control2: CGPoint(x: 650, y: 476))
    shape.closeSubpath()
    context.setFillColor(color(shield))
    context.addPath(shape)
    context.fillPath()
    context.setStrokeColor(color(background))
    context.setLineWidth(29)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.move(to: CGPoint(x: 624, y: 342))
    context.addLine(to: CGPoint(x: 678, y: 288))
    context.addLine(to: CGPoint(x: 780, y: 396))
    context.strokePath()
    let url = URL(fileURLWithPath: destination).appendingPathComponent("Icon-\(name).png")
    let output = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(output, context.makeImage()!, nil)
    precondition(CGImageDestinationFinalize(output))
}
