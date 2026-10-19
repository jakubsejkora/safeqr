import SwiftUI
import SafeQRKit

struct HoldProgress: Equatable {
    static let duration = 1.5
    private(set) var fraction = 0.0
    mutating func update(elapsed: TimeInterval) { fraction = min(1, max(0, elapsed / Self.duration)) }
    mutating func cancel() { fraction = 0 }
}

struct HoldToContinueButton: View {
    let action: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var progress = HoldProgress()
    @State private var timer: Task<Void, Never>?
    @State private var assistiveConfirmation = false
    @State private var completed = false
    @State private var tick = 0

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(.quaternary, lineWidth: 3)
                Circle().trim(from: 0, to: progress.fraction)
                    .stroke(RiskLevel.danger.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "arrow.right").font(.system(size: 12, weight: .semibold))
            }.frame(width: 28, height: 28).accessibilityHidden(true)
            Text(L10n.text("Hold to continue anyway")).font(.body.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(RiskLevel.danger.color)
        .frame(maxWidth: .infinity, minHeight: 56).contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: HoldProgress.duration, maximumDistance: 24) {
            complete()
        } onPressingChanged: { pressing in
            if pressing { begin() } else { cancel() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(L10n.text("Hold for one and a half seconds. Release to cancel."))
        .accessibilityAction { assistiveConfirmation = true }
        .accessibilityIdentifier("confirm-danger")
        .sensoryFeedback(.impact(weight: .light), trigger: tick)
        .alert(L10n.text("Really continue?"), isPresented: $assistiveConfirmation) {
            Button(L10n.text("Go back"), role: .cancel) { cancel() }
            Button(L10n.text("Continue anyway"), role: .destructive) { complete() }
        } message: {
            Text(L10n.text("We recommend going back. Continue only if you understand the risk and trust the destination."))
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { cancel() } }
        .onDisappear { cancel() }
    }

    private func begin() {
        guard !completed else { return }
        cancel()
        tick += 1
        timer = Task { @MainActor in
            let start = ContinuousClock.now
            var previousTick = 0
            while !Task.isCancelled {
                let duration = start.duration(to: .now).components
                let elapsed = Double(duration.seconds) + Double(duration.attoseconds) / 1e18
                progress.update(elapsed: elapsed)
                let currentTick = Int(elapsed / 0.5)
                if currentTick > previousTick { tick += 1; previousTick = currentTick }
                do { try await Task.sleep(for: .milliseconds(30)) } catch { return }
            }
        }
    }

    private func cancel() {
        timer?.cancel()
        timer = nil
        progress.cancel()
    }

    private func complete() {
        guard !completed, scenePhase == .active else { return }
        completed = true
        cancel()
        action()
    }
}
