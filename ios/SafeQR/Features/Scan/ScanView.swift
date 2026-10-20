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
    @State private var hintVisible = false
    @State private var presentationGate = ScanPresentationGate()
    @State private var liveSelection: LiveCodeSelection?
    @State private var pendingCameraCode: (code: TrackedCode, privateScene: Bool)?
    @State private var presentingCameraSheet = false
    @State private var choosingPhoto = false

    var body: some View {
        @Bindable var navigation = services.navigation
        ZStack {
            if services.camera.state == .ready {
                services.camera.preview
                    .ignoresSafeArea().accessibilityHidden(true)
                ScannerOverlay(codes: services.camera.codes, ultraWide: services.camera.showsUltraWide,
                               checks: services.checks.models)
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
                ToolbarItem(placement: .topBarLeading) {
                    CameraZoomControl(selection: Binding(get: { services.camera.zoom }, set: services.camera.selectZoom),
                                      levels: services.camera.availableZooms)
                }.sharedBackgroundVisibility(.hidden)
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: choosePhoto) {
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
        .sheet(item: $navigation.result, onDismiss: resumeScanning) { result in
            resultContent(result, navigation.resultDetent == .medium && !typeSize.isAccessibilitySize)
                .presentationDetents([.medium, .large], selection: $navigation.resultDetent)
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $liveSelection, onDismiss: finishCameraSelection) { selection in
            LiveCodePickerView(selection: selection) { code in
                pendingCameraCode = (code, selection.privateScene)
                liveSelection = nil
            }
            .presentationDetents([.medium, .large])
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
        .photosPicker(isPresented: $choosingPhoto, selection: $selectedPhoto, matching: .images)
        .onChange(of: choosingPhoto) { _, showing in
            if !showing {
                Task {
                    await Task.yield()
                    if selectedPhoto == nil && !importing { resumeScanning() }
                }
            }
        }
        .alert(L10n.text("Couldn't read this picture"), isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button(L10n.text("OK"), role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .onChange(of: selectedPhoto) { _, photo in
            guard let photo else { return }
            Task {
                importing = true
                defer { importing = false; selectedPhoto = nil }
                await services.camera.freeze()
                do {
                    guard let data = try await photo.loadTransferable(type: Data.self) else { throw ScanError.invalidImage }
                    let scan = try await PhotoScanner.scan(data)
                    if scan.codes.count == 1, let code = scan.codes.first {
                        await show(raw: code.raw, symbology: code.symbology, scene: ScenePhoto(jpeg: scan.jpeg, source: .photo, bounds: code.bounds))
                    } else { imported = scan }
                } catch {
                    errorMessage = (error as? ScanError)?.message ?? ScanError.invalidImage.message
                    await services.camera.start()
                }
            }
        }
        .task(id: observingCamera) {
            hintVisible = false
            guard observingCamera else { return }
            var hint = ScannerHintTiming()
            while !Task.isCancelled {
                if !services.camera.isFrozen {
                    let codes = services.camera.codes
                    hintVisible = hint.update(hasCode: !codes.isEmpty)
                    services.checks.observe(codes, sceneContainsPrivateCodes: services.camera.sceneContainsPrivateCodes,
                                            using: services.checker, consent: services.preferences.consent)
                    if let decision = presentationGate.decision(for: codes) {
                        presentFromCamera(decision, codes: codes)
                    }
                }
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
            if isSelected && phase == .active && services.navigation.result == nil && imported == nil &&
                liveSelection == nil && !choosingPhoto && !importing && !presentingCameraSheet &&
                services.preferences.finishedOnboarding {
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
            Button(action: choosePhoto) {
                Label(L10n.text("Import photo"), systemImage: "photo")
            }
            .buttonStyle(.glass).controlSize(.large).disabled(importing)
        }
    }

    private var cameraControls: some View {
        VStack(spacing: 14) {
            Spacer()
            if observingCamera && services.camera.codes.isEmpty && hintVisible {
                Text(L10n.text("Point at a QR code"))
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .glassEffect(in: Capsule())
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 16)
        .foregroundStyle(.white)
        .symbolEffectsRemoved(reduceMotion)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2),
                   value: hintVisible && services.camera.codes.isEmpty && observingCamera)
    }

    private var cameraVisible: Bool { services.camera.state == .ready }
    private var observingCamera: Bool {
        isSelected && scenePhase == .active && services.navigation.result == nil && imported == nil &&
            liveSelection == nil && !choosingPhoto && !presentingCameraSheet && !importing && cameraVisible
    }

    private func choosePhoto() {
        guard !presentingCameraSheet else { return }
        presentingCameraSheet = true
        Task {
            await services.camera.freeze()
            choosingPhoto = true
            presentingCameraSheet = false
        }
    }

    private func presentFromCamera(_ decision: ScanPresentationGate.Decision, codes: [TrackedCode]) {
        guard !presentingCameraSheet else { return }
        presentingCameraSheet = true
        let privateScene = services.camera.sceneContainsPrivateCodes
        Task {
            defer { presentingCameraSheet = false }
            await services.camera.freeze()
            guard isSelected, scenePhase == .active else { return }
            presentationGate.presented(codes)
            UISelectionFeedbackGenerator().selectionChanged()
            switch decision {
            case .single(let id):
                if let code = codes.first(where: { $0.id == id }) { await select(code, privateScene: privateScene) }
            case .chooser:
                for code in codes where code.analysis.hasWebDestination {
                    _ = services.checks.result(for: code.analysis, scene: privateScene ? nil : code.observation.scene,
                                                using: services.checker, consent: services.preferences.consent)
                }
                liveSelection = LiveCodeSelection(codes: codes, privateScene: privateScene)
            }
        }
    }

    private func select(_ code: TrackedCode, privateScene: Bool) async {
        services.navigation.resultDetent = typeSize.isAccessibilitySize ? .large : .medium
        await services.present(code.analysis, scene: privateScene ? nil : code.observation.scene,
                               limitations: privateScene ? [L10n.text("The surroundings photo stayed on this iPhone because it contains a private code.")] : [])
    }

    private func resumeScanning() {
        guard isSelected, scenePhase == .active, services.navigation.result == nil,
              liveSelection == nil, imported == nil, !choosingPhoto, !importing, !presentingCameraSheet else { return }
        presentationGate.resumed()
        Task { await services.camera.start() }
    }

    private func finishCameraSelection() {
        guard let pending = pendingCameraCode else { resumeScanning(); return }
        pendingCameraCode = nil
        Task { await select(pending.code, privateScene: pending.privateScene) }
    }

    private func finishImportSelection() {
        guard let pending = pendingImport else {
            resumeScanning()
            return
        }
        pendingImport = nil
        let privateScene = ScenePrivacy.containsPrivateCodes(pending.scan.codes)
        var limitations: [String] = []
        if privateScene { limitations.append(L10n.text("The surroundings photo stayed on this iPhone because it contains a private code.")) }
        let limitation = L10n.format("This picture contains %lld codes. A sticker may be covering the original.", pending.scan.codes.count)
        limitations.append(limitation)
        Task {
            await show(raw: pending.code.raw, symbology: pending.code.symbology,
                       scene: privateScene ? nil : ScenePhoto(jpeg: pending.scan.jpeg, source: .photo, bounds: pending.code.bounds),
                       limitations: limitations)
        }
    }

    private func show(raw: String, symbology: Symbology, scene: ScenePhoto?, limitations: [String] = []) async {
        guard services.navigation.result == nil else { return }
        if typeSize.isAccessibilitySize { services.navigation.resultDetent = .large }
        let analysis = CodeInspector(locale: L10n.locale).inspect(raw, symbology: symbology)
        presentationGate.presented(raw)
        await services.present(analysis, scene: scene, limitations: limitations)
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
