import Foundation
import Testing
@testable import SafeQR

struct ScannerControlTests {
    @Test func hintWaitsFiveSecondsAndEverySeenCodeRestartsTheWait() {
        let start = ContinuousClock.now
        var hint = ScannerHintTiming()
        for (milliseconds, hasCode, expected) in [
            (0, false, false), (4_999, false, false), (5_000, false, true),
            (6_000, true, false), (20_000, true, false), (21_000, false, false),
            (25_999, false, false), (26_000, false, true)
        ] {
            let visible = hint.update(hasCode: hasCode, at: start.advanced(by: .milliseconds(milliseconds)))
            #expect(visible == expected)
        }
    }

    @Test func cameraLevelsReflectTheAvailableLensesAndMainCameraLimit() {
        #expect(CameraZoom.available(ultraWide: true, maximumMainZoom: 2) == [.ultraWide, .main, .double])
        #expect(CameraZoom.available(ultraWide: false, maximumMainZoom: 10) == [.main, .double])
        #expect(CameraZoom.available(ultraWide: true, maximumMainZoom: 1.9) == [.ultraWide, .main])
        #expect(CameraZoom.available(ultraWide: false, maximumMainZoom: 1) == [.main])
        #expect(CameraZoom.ultraWide.mainFactor == 1)
        #expect(CameraZoom.main.mainFactor == 1)
        #expect(CameraZoom.double.mainFactor == 2)
    }

    @Test func hardwareZoomedBoundsAreNotMagnifiedAgainByThePreview() {
        let bounds = CodeBounds(rect: CGRect(x: 0.4, y: 0.3, width: 0.2, height: 0.4))
        let rect = PreviewGeometry.rect(bounds, frame: CGSize(width: 1080, height: 1920),
                                        viewport: CGSize(width: 360, height: 640))
        #expect(abs(rect.minX - 144) < 0.001)
        #expect(abs(rect.minY - 192) < 0.001)
        #expect(abs(rect.width - 72) < 0.001)
        #expect(abs(rect.height - 256) < 0.001)
    }

    @Test func mainZoomKeepsTheSameCodeAtTheSamePlaceInTheUltraWideScene() throws {
        let frame = CGSize(width: 1080, height: 1920)
        let normal = CodeBounds(rect: CGRect(x: 0.45, y: 0.4, width: 0.1, height: 0.2))
        let zoomed = CodeBounds(rect: CGRect(x: 0.4, y: 0.3, width: 0.2, height: 0.4))
        let first = try #require(PreviewGeometry.ultraWideBounds(normal, wideSize: frame, ultraSize: frame,
            wideFieldOfView: 65, ultraFieldOfView: 110, mainZoom: 1))
        let second = try #require(PreviewGeometry.ultraWideBounds(zoomed, wideSize: frame, ultraSize: frame,
            wideFieldOfView: 65, ultraFieldOfView: 110, mainZoom: 2))
        #expect(abs(first.x - second.x) < 0.000001)
        #expect(abs(first.y - second.y) < 0.000001)
        #expect(abs(first.width - second.width) < 0.000001)
        #expect(abs(first.height - second.height) < 0.000001)
    }

    @Test func sceneMappingAccountsForDifferentRotatedFrameAspectRatios() throws {
        let bounds = CodeBounds(rect: CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4))
        let mapped = try #require(PreviewGeometry.ultraWideBounds(bounds, wideSize: CGSize(width: 1080, height: 1920),
            ultraSize: CGSize(width: 1440, height: 1920), wideFieldOfView: 65, ultraFieldOfView: 110, mainZoom: 2))
        #expect(abs(mapped.width / mapped.height - 0.75) < 0.000001)
        #expect(abs(mapped.x + mapped.width / 2 - 0.5) < 0.000001)
        #expect(abs(mapped.y + mapped.height / 2 - 0.5) < 0.000001)
        #expect(PreviewGeometry.ultraWideBounds(bounds, wideSize: .zero, ultraSize: .zero,
            wideFieldOfView: 65, ultraFieldOfView: 110, mainZoom: 2) == nil)
    }

    #if DEBUG
    @MainActor @Test func screenshotZoomChangesTheFrameBoundsButKeepsTheScene() throws {
        let fixture = ScannerFixture(mode: .locked)
        let original = try #require(fixture.codes.first)
        fixture.selectZoom(.double)
        let zoomed = try #require(fixture.codes.first)
        #expect(fixture.zoom == .double)
        #expect(abs(zoomed.bounds.width - original.bounds.width * 2) < 0.000001)
        #expect(zoomed.observation.scene?.jpeg == original.observation.scene?.jpeg)
        #expect(zoomed.ultraBounds == original.ultraBounds)
        fixture.selectZoom(.ultraWide)
        #expect(fixture.showsUltraWide)
        #expect(fixture.codes.first?.bounds == original.bounds)
        #expect(DebugLaunch(arguments: ["--screen", "scannerLocked", "--zoom", "2"]).zoom == .double)
    }
    #endif
}
