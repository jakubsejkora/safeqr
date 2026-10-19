import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(spacing: 8) {
                        ForEach(0..<3) { index in
                            Capsule().fill(index == page ? AppStyle.accent : AppStyle.accent.opacity(0.15))
                                .frame(width: index == page ? 36 : 12, height: 6)
                        }
                        Spacer()
                        Text(L10n.format("%lld of 3", page + 1)).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(L10n.format("Page %lld of 3", page + 1))
                    Spacer(minLength: 20)
                    illustration
                        .frame(maxWidth: .infinity).padding(.vertical, 24)
                    Text(title).font(.largeTitle.bold()).fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(description).font(.title3).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if page == 1 {
                        Label(L10n.text("Optional. You can change this in Settings."), systemImage: "slider.horizontal.3")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 20)
                    buttons
                }
                .padding(28)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .background(AppStyle.canvas)
            .navigationTitle("Safe QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if page > 0 {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.text("Back"), systemImage: "chevron.left") { advance(to: page - 1) }
                    }
                }
            }
        }
        .interactiveDismissDisabled()
    }

    @ViewBuilder private var illustration: some View {
        if page == 0 { ShieldMark(size: 140) }
        else {
            Image(systemName: page == 1 ? "sparkle.magnifyingglass" : "camera.viewfinder")
                .font(.system(size: 86, weight: .light)).foregroundStyle(AppStyle.accent)
                .frame(height: 148).accessibilityHidden(true)
        }
    }

    private var title: String {
        switch page {
        case 0: L10n.text("Know before you go.")
        case 1: L10n.text("A closer look. Your choice.")
        default: L10n.text("Point. Check. Decide.")
        }
    }

    private var description: String {
        switch page {
        case 0: L10n.text("See what a code contains, what looks risky and what will happen next. Nothing opens or sends without your decision.")
        case 1: L10n.text("Deep checks send the link and a photo of its surroundings to Safe QR servers in the EU. A photo check may also send payment details from the code. Photos are never stored. Results use AI and can be wrong.")
        default: L10n.text("Allow the camera to read codes. Safe QR can use a wider view to spot a sticker or something out of place. You can also choose a photo.")
        }
    }

    private var buttons: some View {
        VStack(spacing: 14) {
            Button {
                if page == 0 { advance(to: 1) }
                else if page == 1 {
                    services.preferences.deepChecksEnabled = true
                    services.preferences.sceneChecksEnabled = true
                    advance(to: 2)
                } else {
                    Task {
                        _ = await AVCaptureDevice.requestAccess(for: .video)
                        services.preferences.finishedOnboarding = true
                    }
                }
            } label: {
                Text(page == 0 ? L10n.text("Get started") : page == 1 ? L10n.text("Turn on deep checks") : L10n.text("Allow camera"))
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 38)
            }
            .buttonStyle(.glassProminent)
            if page > 0 {
                Button {
                    if page == 1 {
                        services.preferences.deepChecksEnabled = false
                        services.preferences.sceneChecksEnabled = false
                        advance(to: 2)
                    } else { services.preferences.finishedOnboarding = true }
                } label: {
                    Text(page == 1 ? L10n.text("Check only on this iPhone") : L10n.text("Use photos for now"))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glass)
            }
        }
    }

    private func advance(to page: Int) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { self.page = page }
    }
}
