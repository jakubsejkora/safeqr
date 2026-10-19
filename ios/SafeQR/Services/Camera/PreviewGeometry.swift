import Foundation

/// Maps top-left, normalised bounds from an already oriented frame into an aspect-fill preview.
enum PreviewGeometry {
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
