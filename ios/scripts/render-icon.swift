import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Palette {
    let background: UInt32
    let ink: UInt32
    let shield: UInt32
}

struct Theme {
    let name: String
    let light: UInt32
    let dark: UInt32

    var variants: [(String, Palette)] {
        [
            ("Light", Palette(background: blend(light, with: 0xFFFFFF, fraction: 0.96),
                              ink: light, shield: blend(light, with: 0xFFFFFF, fraction: 0.13))),
            ("Dark", Palette(background: blend(light, with: 0x111214, fraction: 0.86),
                             ink: dark, shield: blend(dark, with: 0, fraction: 0.14))),
            ("Tinted", Palette(background: 0x2B2B2B, ink: 0xEDEDED, shield: 0xDEDEDE))
        ]
    }
}

enum RenderError: Error {
    case invalidPalettes, cannotCreateBitmap, cannotWritePNG(URL)
}

func channel(_ hex: UInt32, _ shift: UInt32) -> CGFloat {
    CGFloat((hex >> shift) & 255) / 255
}

func blend(_ first: UInt32, with second: UInt32, fraction: Double) -> UInt32 {
    [UInt32(16), 8, 0].reduce(0) { result, shift in
        let value = Double((first >> shift) & 255) * (1 - fraction) + Double((second >> shift) & 255) * fraction
        return result | (UInt32(value.rounded()) << shift)
    }
}

func themes(from source: URL) throws -> [Theme] {
    let text = try String(contentsOf: source, encoding: .utf8)
    // Read the app's palette declarations so regenerated artwork cannot silently drift from its theme.
    let pattern = #"case \.(\w+): pair = \(0x([A-Fa-f0-9]{6}), 0x([A-Fa-f0-9]{6})\)"#
    let expression = try NSRegularExpression(pattern: pattern)
    let matches = expression.matches(in: text, range: NSRange(text.startIndex..., in: text))
    let result = matches.compactMap { match -> Theme? in
        guard let nameRange = Range(match.range(at: 1), in: text),
              let lightRange = Range(match.range(at: 2), in: text),
              let darkRange = Range(match.range(at: 3), in: text),
              let light = UInt32(text[lightRange], radix: 16),
              let dark = UInt32(text[darkRange], radix: 16) else { return nil }
        return Theme(name: String(text[nameRange]).capitalized, light: light, dark: dark)
    }
    guard Set(result.map(\.name)) == Set(["Graphite", "Blue", "Indigo", "Plum", "Cocoa", "Forest"]),
          result.count == 6 else { throw RenderError.invalidPalettes }
    return result
}

func render(_ palette: Palette, size: Int, to url: URL) throws {
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
        throw RenderError.cannotCreateBitmap
    }
    context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    func setFill(_ hex: UInt32) {
        context.setFillColor(red: channel(hex, 16), green: channel(hex, 8), blue: channel(hex, 0), alpha: 1)
    }
    func rounded(_ rect: CGRect, radius: CGFloat, fill: UInt32) {
        setFill(fill)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.fillPath()
    }
    setFill(palette.background)
    context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    for (x, y) in [(180.0, 576.0), (576.0, 576.0), (180.0, 180.0)] {
        rounded(CGRect(x: x, y: y, width: 268, height: 268), radius: 64, fill: palette.ink)
        rounded(CGRect(x: x + 44, y: y + 44, width: 180, height: 180), radius: 29, fill: palette.background)
        rounded(CGRect(x: x + 88, y: y + 88, width: 92, height: 92), radius: 14, fill: palette.ink)
    }
    for (x, y, w, h) in [(180.0, 488.0, 92.0, 44.0), (316, 488, 132, 44), (488, 708, 44, 136), (488, 576, 44, 88), (488, 488, 92, 44)] {
        rounded(CGRect(x: x, y: y, width: w, height: h), radius: 12, fill: palette.ink)
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
    setFill(palette.shield)
    context.addPath(shape)
    context.fillPath()
    context.setStrokeColor(red: channel(palette.background, 16), green: channel(palette.background, 8),
                           blue: channel(palette.background, 0), alpha: 1)
    context.setLineWidth(29)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.move(to: CGPoint(x: 624, y: 342))
    context.addLine(to: CGPoint(x: 678, y: 288))
    context.addLine(to: CGPoint(x: 780, y: 396))
    context.strokePath()
    guard let image = context.makeImage(),
          let output = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw RenderError.cannotWritePNG(url)
    }
    CGImageDestinationAddImage(output, image, nil)
    guard CGImageDestinationFinalize(output) else { throw RenderError.cannotWritePNG(url) }
}

let ios = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let destination = CommandLine.arguments.dropFirst().first.map { URL(fileURLWithPath: $0) }
    ?? ios.appendingPathComponent("SafeQR/Resources/Assets.xcassets")
for theme in try themes(from: ios.appendingPathComponent("SafeQR/DesignSystem/AppTheme.swift")) {
    let iconName = theme.name == "Graphite" ? "AppIcon" : "AppIcon" + theme.name
    let iconSet = destination.appendingPathComponent(iconName + ".appiconset")
    let previewSet = destination.appendingPathComponent("Theme" + theme.name + ".imageset")
    try FileManager.default.createDirectory(at: iconSet, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: previewSet, withIntermediateDirectories: true)
    for (name, palette) in theme.variants {
        try render(palette, size: 1024, to: iconSet.appendingPathComponent("Icon-\(name).png"))
        if name != "Tinted" {
            try render(palette, size: 256, to: previewSet.appendingPathComponent("\(name).png"))
        }
    }
}
print("Rendered all six themes: 18 app icons and 12 Settings previews.")
