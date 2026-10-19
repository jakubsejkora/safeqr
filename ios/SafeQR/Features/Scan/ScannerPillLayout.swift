import Foundation

enum ScannerPillLayout {
    static func centers(for rectangles: [CGRect], viewport: CGSize) -> [CGPoint] {
        let halfWidth = min(340, viewport.width - 32) / 2
        let top: CGFloat = 150
        let bottom = max(top, viewport.height - 150)
        var positions: [CGPoint] = []
        for rect in rectangles {
            var y = rect.maxY > bottom - 48 ? rect.minY - 48 : rect.maxY + 48
            y = min(bottom, max(top, y))
            let candidates = [y, y + 86, y - 86, y + 172, y - 172, top, bottom]
            y = candidates.first { candidate in
                candidate >= top && candidate <= bottom && positions.allSatisfy { abs($0.y - candidate) >= 80 }
            } ?? y
            positions.append(CGPoint(x: min(viewport.width - halfWidth - 16, max(halfWidth + 16, rect.midX)), y: y))
        }
        return positions
    }
}
