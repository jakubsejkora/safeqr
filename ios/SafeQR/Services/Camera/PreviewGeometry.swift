import Foundation

/// Maps top-left, normalised bounds from an already oriented frame into an aspect-fill preview.
enum PreviewGeometry {
    static func ultraWideBounds(_ bounds: CodeBounds, wideSize: CGSize, ultraSize: CGSize,
                                wideFieldOfView: Double, ultraFieldOfView: Double, mainZoom: Double) -> CodeBounds? {
        guard wideSize.width > 0, wideSize.height > 0, ultraSize.width > 0, ultraSize.height > 0,
              mainZoom.isFinite, mainZoom >= 1,
              (0..<180).contains(wideFieldOfView), (0..<180).contains(ultraFieldOfView) else { return nil }
        // The capture connections rotate both frames 90°, so the format's horizontal FOV is the portrait height.
        let vertical = tan(wideFieldOfView * .pi / 360) / tan(ultraFieldOfView * .pi / 360) / mainZoom
        let horizontal = vertical * (wideSize.width / wideSize.height) / (ultraSize.width / ultraSize.height)
        guard vertical.isFinite, horizontal.isFinite, vertical > 0, horizontal > 0,
              vertical <= 1, horizontal <= 1 else { return nil }
        return CodeBounds(rect: CGRect(x: 0.5 + (bounds.x - 0.5) * horizontal,
                                      y: 0.5 + (bounds.y - 0.5) * vertical,
                                      width: bounds.width * horizontal, height: bounds.height * vertical))
    }

    static func rect(_ bounds: CodeBounds, frame: CGSize, viewport: CGSize) -> CGRect {
        guard frame.width > 0, frame.height > 0, viewport.width > 0, viewport.height > 0 else { return .zero }
        let scale = max(viewport.width / frame.width, viewport.height / frame.height)
        let size = CGSize(width: frame.width * scale, height: frame.height * scale)
        return CGRect(x: (viewport.width - size.width) / 2 + bounds.x * size.width,
                      y: (viewport.height - size.height) / 2 + bounds.y * size.height,
                      width: bounds.width * size.width, height: bounds.height * size.height)
    }

    static func smooth(_ next: CodeBounds, from previous: CodeBounds) -> CodeBounds {
        let weight = 0.55
        return CodeBounds(rect: CGRect(x: previous.x + (next.x - previous.x) * weight,
                                      y: previous.y + (next.y - previous.y) * weight,
                                      width: previous.width + (next.width - previous.width) * weight,
                                      height: previous.height + (next.height - previous.height) * weight))
    }
}
