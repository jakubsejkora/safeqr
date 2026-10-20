import SwiftUI
import SafeQRKit

struct ScannerOverlay: View {
    let codes: [TrackedCode]
    var ultraWide = false
    var checks: [String: ResultModel] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var breathing = false
    @Namespace private var glass

    var body: some View {
        GeometryReader { geometry in
            let rectangles = codes.map { code in
                PreviewGeometry.rect(ultraWide ? code.ultraBounds ?? code.bounds : code.bounds,
                                     frame: ultraWide ? code.observation.ultraSize : code.observation.frameSize,
                                     viewport: geometry.size)
            }
            let centers = ScannerPillLayout.centers(for: rectangles, viewport: geometry.size)
            ZStack {
                if !rectangles.isEmpty {
                    ScannerCutout(rectangles: rectangles)
                        .fill(.black.opacity(0.25), style: FillStyle(eoFill: true))
                        .allowsHitTesting(false)
                }
                if codes.isEmpty {
                    brackets
                        .frame(width: min(240, geometry.size.width * 0.6), height: min(240, geometry.size.width * 0.6))
                        .scaleEffect(breathing && !reduceMotion ? 1.035 : 1)
                        .position(x: geometry.size.width / 2, y: geometry.size.height * 0.45)
                }
                ForEach(Array(codes.enumerated()), id: \.element.id) { index, code in
                    let rect = rectangles[index]
                    brackets.frame(width: max(32, rect.width + 14), height: max(32, rect.height + 14))
                        .position(x: rect.midX, y: rect.midY)
                        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.86), value: rect)
                    if codes.count > 1 {
                        Text("\(index + 1)").font(.headline.bold()).monospacedDigit()
                            .foregroundStyle(.black).padding(8).background(.white, in: Circle())
                            .position(x: max(24, rect.minX), y: max(100, rect.minY))
                            .accessibilityHidden(true)
                    }
                    if codes.count == 1 && !typeSize.isAccessibilitySize {
                        ScannerVerdictPill(code: code, model: checks[code.analysis.raw])
                            .glassEffectID(code.id, in: glass)
                            .frame(maxWidth: min(340, geometry.size.width - 32))
                            .fixedSize(horizontal: false, vertical: true)
                            .position(centers[index])
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if typeSize.isAccessibilitySize && codes.count == 1 {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(codes) { code in ScannerVerdictPill(code: code, model: checks[code.analysis.raw]) }
                        }.padding(.horizontal, 16)
                    }.frame(maxHeight: geometry.size.height * 0.5)
                }
            }
        }
        .task {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { breathing = true }
        }
    }

    private var brackets: some View {
        CornerBrackets()
            .stroke(.black.opacity(0.45), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
            .overlay { CornerBrackets().stroke(.white, style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round)) }
            .accessibilityHidden(true).allowsHitTesting(false)
    }
}

struct CornerBrackets: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let length = min(30, min(rect.width, rect.height) * 0.25)
        let radius = min(12, length / 2)
        for corner in 0..<4 {
            var segment = Path()
            segment.move(to: CGPoint(x: 0, y: length))
            segment.addLine(to: CGPoint(x: 0, y: radius))
            segment.addQuadCurve(to: CGPoint(x: radius, y: 0), control: .zero)
            segment.addLine(to: CGPoint(x: length, y: 0))
            let sx: CGFloat = corner % 2 == 0 ? 1 : -1
            let sy: CGFloat = corner < 2 ? 1 : -1
            path.addPath(segment, transform: CGAffineTransform(a: sx, b: 0, c: 0, d: sy,
                                                               tx: sx == 1 ? rect.minX : rect.maxX,
                                                               ty: sy == 1 ? rect.minY : rect.maxY))
        }
        return path
    }
}

private struct ScannerCutout: Shape {
    let rectangles: [CGRect]
    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        for bounds in rectangles { path.addRoundedRect(in: bounds.insetBy(dx: -7, dy: -7), cornerSize: CGSize(width: 12, height: 12)) }
        return path
    }
}

