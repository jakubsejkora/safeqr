import SwiftUI
import PhotosUI
import SafeQRKit

struct ScanView<ResultContent: View>: View {
    var isSelected: Bool
    @ViewBuilder var resultContent: (ResultPresentation, Bool) -> ResultContent
    @Environment(\.appTheme) private var theme
    @Environment(AppServices.self) private var services
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.colorScheme) private var systemAppearance
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imported: ImportedScan?
    @State private var pendingImport: (code: ScannedCode, scan: ImportedScan)?
    @State private var errorMessage: String?
    @State private var importing = false

    var body: some View {
        @Bindable var navigation = services.navigation
        ZStack {
            if services.camera.state == .ready {
                services.camera.preview
                    .ignoresSafeArea().accessibilityHidden(true)
                ScannerOverlay(codes: services.camera.codes, ultraWide: services.camera.showsUltraWide,
                               checks: services.checks.models, consentGiven: services.preferences.consent.links, onSelect: select)
                    .ignoresSafeArea()
                cameraControls
            } else {
                unavailable
            }
            if importing {
                ProgressView(L10n.text("Reading the picture…"))
                    .padding(24).glassEffect(in: RoundedRectangle(cornerRadius: 24))
            }
        }
        .background(AppStyle.canvas)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if observingCamera {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(L10n.text("Import photo"), systemImage: "photo").foregroundStyle(.white)
                    }
                    .disabled(importing)
                    if services.camera.hasTorch {
                        Button { services.camera.toggleTorch() } label: {
                            Label(services.camera.torchEnabled ? L10n.text("Turn light off") : L10n.text("Turn light on"),
                                  systemImage: services.camera.torchEnabled ? "flashlight.on.fill" : "flashlight.off.fill")
                                .foregroundStyle(services.camera.torchEnabled ? .yellow : .white)
                                .symbolEffect(.bounce, value: services.camera.torchEnabled)
                                .symbolEffectsRemoved(reduceMotion)
                        }
                    }
                }
            }
        }
        .environment(\.colorScheme, cameraVisible ? .dark : systemAppearance)
        .toolbarColorScheme(cameraVisible ? .dark : nil, for: .navigationBar, .tabBar)
        .sheet(item: $navigation.result, onDismiss: { Task { await services.camera.start() } }) { result in
            resultContent(result, navigation.resultDetent == .medium && !typeSize.isAccessibilitySize)
                .presentationDetents([.medium, .large], selection: $navigation.resultDetent)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: Binding(get: { imported != nil }, set: { if !$0 { imported = nil } }), onDismiss: finishImportSelection) {
            if let imported {
                CodePickerView(scan: imported) { code in
                    pendingImport = (code, imported)
                    self.imported = nil
                }
            }
        }
        .alert(L10n.text("Couldn't read this picture"), isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button(L10n.text("OK"), role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .onChange(of: selectedPhoto) { _, photo in
            guard let photo else { return }
            services.camera.stop()
            Task {
                importing = true
                defer { importing = false; selectedPhoto = nil }
                do {
                    guard let data = try await photo.loadTransferable(type: Data.self) else { throw ScanError.invalidImage }
                    let scan = try await PhotoScanner.scan(data)
                    if scan.codes.count == 1, let code = scan.codes.first {
                        show(raw: code.raw, symbology: code.symbology, scene: ScenePhoto(jpeg: scan.jpeg, source: .photo, bounds: code.bounds))
                    } else { imported = scan }
                } catch {
                    errorMessage = (error as? ScanError)?.message ?? ScanError.invalidImage.message
                    await services.camera.start()
                }
            }
        }
        .task(id: observingCamera) {
            guard observingCamera else { return }
            while !Task.isCancelled {
                services.checks.observe(services.camera.codes, sceneContainsPrivateCodes: services.camera.sceneContainsPrivateCodes,
                                        using: services.checker, consent: services.preferences.consent)
                do { try await Task.sleep(for: .milliseconds(200)) }
                catch { return }
            }
        }
        .task {
            if services.preferences.finishedOnboarding { await services.camera.start() }
        }
        .onChange(of: services.preferences.finishedOnboarding) { _, finished in
            if finished && isSelected { Task { await services.camera.start() } }
        }
        .onChange(of: scenePhase) { _, phase in
            if isSelected && phase == .active && services.navigation.result == nil && imported == nil && services.preferences.finishedOnboarding {
                Task { await services.camera.start() }
            }
        }
        .onDisappear { services.camera.stop() }
    }

    private var unavailable: some View {
        ContentUnavailableView {
            Label(L10n.text(services.camera.state == .denied ? "Camera access is off" : "Camera unavailable"), systemImage: "camera")
        } description: {
            Text(services.camera.unavailableMessage)
        } actions: {
            if services.camera.state == .denied {
                Button(L10n.text("Open Settings")) { openSettings() }.buttonStyle(.glassProminent).foregroundStyle(theme.onAccent)
            } else if services.camera.state == .idle {
                Button(L10n.text("Allow camera")) { Task { await services.camera.start(requestPermission: true) } }
                    .buttonStyle(.glassProminent).foregroundStyle(theme.onAccent)
            }
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label(L10n.text("Import photo"), systemImage: "photo")
            }
            .buttonStyle(.glass).controlSize(.large).disabled(importing)
        }
    }

    private var cameraControls: some View {
        VStack(spacing: 14) {
            Spacer()
            if services.camera.codes.isEmpty {
                Text(L10n.text("Point at a QR code"))
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .glassEffect(in: Capsule())
            }
            if services.camera.hasUltraWide {
                CameraZoomControl(ultraWide: Binding(get: { services.camera.showsUltraWide },
                                                    set: { services.camera.showsUltraWide = $0 }))
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 16)
        .foregroundStyle(.white)
        .symbolEffectsRemoved(reduceMotion)
    }

    private var cameraVisible: Bool { services.camera.state == .ready }
    private var observingCamera: Bool {
        isSelected && scenePhase == .active && services.navigation.result == nil && imported == nil && !importing && cameraVisible
    }

    private func select(_ code: TrackedCode) {
        guard services.navigation.result == nil else { return }
        let privateScene = services.camera.sceneContainsPrivateCodes
        if typeSize.isAccessibilitySize { services.navigation.resultDetent = .large }
        services.present(code.analysis, scene: privateScene ? nil : code.observation.scene,
                         limitations: privateScene ? [L10n.text("The surroundings photo stayed on this iPhone because it contains a private code.")] : [])
    }

    private func finishImportSelection() {
        guard let pending = pendingImport else {
            Task { await services.camera.start() }
            return
        }
        pendingImport = nil
        let privateScene = ScenePrivacy.containsPrivateCodes(pending.scan.codes)
        var limitations: [String] = []
        if privateScene { limitations.append(L10n.text("The surroundings photo stayed on this iPhone because it contains a private code.")) }
        let limitation = L10n.format("This picture contains %lld codes. A sticker may be covering the original.", pending.scan.codes.count)
        limitations.append(limitation)
        show(raw: pending.code.raw, symbology: pending.code.symbology,
             scene: privateScene ? nil : ScenePhoto(jpeg: pending.scan.jpeg, source: .photo, bounds: pending.code.bounds),
             limitations: limitations)
    }

    private func show(raw: String, symbology: Symbology, scene: ScenePhoto?, limitations: [String] = []) {
        guard services.navigation.result == nil else { return }
        if typeSize.isAccessibilitySize { services.navigation.resultDetent = .large }
        let analysis = CodeInspector(locale: L10n.locale).inspect(raw, symbology: symbology)
        services.present(analysis, scene: scene, limitations: limitations)
    }
}

extension ScanView where ResultContent == ResultView {
    init(isSelected: Bool = true) {
        self.init(isSelected: isSelected) { ResultView(presentation: $0, compact: $1) }
    }
}

@MainActor func openSettings() {
    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
}
