import SwiftUI
import PhotosUI
import SafeQRKit

struct ScanView: View {
    var isSelected = true
    @Environment(AppServices.self) private var services
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imported: ImportedScan?
    @State private var pendingImport: (code: ScannedCode, scan: ImportedScan)?
    @State private var result: ResultModel?
    @State private var errorMessage: String?
    @State private var importing = false
    @State private var detent = PresentationDetent.medium
    #if DEBUG
    @State private var launchedSample = false
    @State private var fixtureCodes = ScannerFixture.codes
    #endif

    var body: some View {
        NavigationStack {
            ZStack {
                if services.camera.state == .ready, let capture = services.camera.capture {
                    CameraPreview(capture: capture, ultraWide: services.camera.showsUltraWide)
                        .ignoresSafeArea().accessibilityHidden(true)
                    ScannerOverlay(codes: services.camera.codes, ultraWide: services.camera.showsUltraWide, onSelect: select)
                        .ignoresSafeArea()
                    cameraControls
                } else {
                    placeholder
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
                #if DEBUG
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(DebugSample.training.title) { show(raw: DebugSample.training.raw, symbology: .qr, scene: nil) }
                        ForEach(DebugSample.Category.allCases) { category in
                            Menu(category.title) {
                                ForEach(DebugSample.allCases.filter { $0.category == category && $0 != .training }) { sample in
                                    Button(sample.title) { show(raw: sample.raw, symbology: .qr, scene: nil) }
                                }
                            }
                        }
                    } label: { Label(L10n.text("Sample codes"), systemImage: "ellipsis.circle") }
                    .accessibilityIdentifier("sample-codes")
                }
                #endif
            }
        }
        .sheet(item: $result, onDismiss: { Task { await services.camera.start() } }) { result in
            ResultView(model: result, compact: detent == .medium && !typeSize.isAccessibilitySize)
                .presentationDetents([.medium, .large], selection: $detent)
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
        .task {
            if services.preferences.finishedOnboarding { await services.camera.start() }
            #if DEBUG
            if !launchedSample, let screen = DebugLaunch.screen,
               let sample = DebugSample(rawValue: screen) {
                launchedSample = true
                detent = ProcessInfo.processInfo.arguments.contains("--medium") ? .medium : .large
                let scene = sample == .training && ProcessInfo.processInfo.arguments.contains("--live-scene") ? ScannerFixture.scene : nil
                show(raw: sample.raw, symbology: .qr, scene: scene)
            }
            #endif
        }
        .onChange(of: services.preferences.finishedOnboarding) { _, finished in
            if finished && isSelected { Task { await services.camera.start() } }
        }
        .onChange(of: scenePhase) { _, phase in
            if isSelected && phase == .active && result == nil && imported == nil && services.preferences.finishedOnboarding {
                Task { await services.camera.start() }
            }
        }
        .onDisappear { services.camera.stop() }
    }

    @ViewBuilder private var placeholder: some View {
        #if DEBUG
        if ScannerFixture.enabled, let image = ScannerFixture.image {
            GeometryReader { geometry in
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                ScannerOverlay(codes: fixtureCodes, onSelect: select)
            }
            .ignoresSafeArea()
            cameraControls
        } else { unavailable }
        #else
        unavailable
        #endif
    }

    private var unavailable: some View {
        ContentUnavailableView {
            Label(L10n.text(services.camera.state == .denied ? "Camera access is off" : "Camera unavailable"), systemImage: "camera")
        } description: {
            Text(placeholderMessage)
        } actions: {
            if services.camera.state == .denied {
                Button(L10n.text("Open Settings")) { openSettings() }.buttonStyle(.glassProminent).foregroundStyle(AppStyle.onAccent)
            } else if services.camera.state == .idle {
                Button(L10n.text("Allow camera")) { Task { await services.camera.start(requestPermission: true) } }
                    .buttonStyle(.glassProminent).foregroundStyle(AppStyle.onAccent)
            }
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label(L10n.text("Import photo"), systemImage: "photo")
            }
            .buttonStyle(.glass).controlSize(.large).disabled(importing)
        }
    }

    private var placeholderMessage: String {
        if services.camera.state == .denied {
            return L10n.text("Camera access is off. Allow it in Settings, or choose a picture to check.")
        }
        #if targetEnvironment(simulator)
        return L10n.text("Import a picture to check a code in the Simulator.")
        #else
        return L10n.text("Allow camera access or import a picture to check a code.")
        #endif
    }

    private var cameraControls: some View {
        VStack {
            HStack(alignment: .top, spacing: 12) {
                if !typeSize.isAccessibilitySize || (services.camera.codes.isEmpty && !isFixtureLocked) {
                Text(L10n.text("Point at a QR code"))
                    .font(.subheadline.weight(.medium)).padding(.horizontal, 16).padding(.vertical, 12)
                    .glassEffect(in: RoundedRectangle(cornerRadius: typeSize.isAccessibilitySize ? 24 : 30))
                }
                Spacer(minLength: 0)
                if !typeSize.isAccessibilitySize, let thumbnail = surroundingsThumbnail {
                    SurroundingsThumbnail(image: thumbnail, captureCount: services.camera.codes.count)
                }
            }
            Spacer()
            GlassEffectContainer(spacing: 16) {
                HStack(spacing: 20) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(L10n.text("Import photo"), systemImage: "photo")
                            .labelStyle(.iconOnly).frame(width: 56, height: 56)
                    }.buttonStyle(.glass)
                    if services.camera.hasUltraWide || isFixture {
                        Button { services.camera.showsUltraWide.toggle() } label: {
                            Text(services.camera.showsUltraWide ? "0.5×" : "1×")
                                .font(.system(.headline, design: .rounded)).monospacedDigit().frame(width: 74, height: 56)
                                .contentTransition(.numericText())
                        }
                        .buttonStyle(.glass)
                        .accessibilityLabel(services.camera.showsUltraWide ? L10n.text("Show the main camera") : L10n.text("Show the surroundings camera"))
                    }
                    if services.camera.hasTorch || isFixture {
                        Button { services.camera.toggleTorch() } label: {
                            Label(services.camera.torchEnabled ? L10n.text("Turn light off") : L10n.text("Turn light on"),
                                  systemImage: services.camera.torchEnabled ? "flashlight.on.fill" : "flashlight.off.fill")
                                .labelStyle(.iconOnly).frame(width: 56, height: 56)
                                .symbolEffect(.bounce, value: services.camera.torchEnabled)
                        }.buttonStyle(.glass)
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 20).padding(.top, 8)
        .symbolEffectsRemoved(reduceMotion)
    }

    private var isFixtureLocked: Bool {
        #if DEBUG
        ScannerFixture.enabled && !fixtureCodes.isEmpty
        #else
        false
        #endif
    }

    private var isFixture: Bool {
        #if DEBUG
        ScannerFixture.enabled
        #else
        false
        #endif
    }

    private var surroundingsThumbnail: UIImage? {
        #if DEBUG
        if isFixture { return ScannerFixture.image }
        #endif
        return services.camera.thumbnail
    }

    private func select(_ code: TrackedCode) {
        let privateScene = services.camera.sceneContainsSecrets
        show(raw: code.observation.code.raw, symbology: code.observation.code.symbology,
             scene: privateScene ? nil : code.observation.scene,
             limitations: privateScene ? [L10n.text("The surroundings photo stayed on this iPhone because it contains a private code.")] : [])
    }

    private func finishImportSelection() {
        guard let pending = pendingImport else {
            Task { await services.camera.start() }
            return
        }
        pendingImport = nil
        let privateScene = ScenePrivacy.containsSecrets(pending.scan.codes)
        var limitations: [String] = []
        if privateScene { limitations.append(L10n.text("The surroundings photo stayed on this iPhone because it contains a private code.")) }
        let limitation = L10n.format("This picture contains %lld codes. A sticker may be covering the original.", pending.scan.codes.count)
        limitations.append(limitation)
        show(raw: pending.code.raw, symbology: pending.code.symbology,
             scene: privateScene ? nil : ScenePhoto(jpeg: pending.scan.jpeg, source: .photo, bounds: pending.code.bounds),
             limitations: limitations)
    }

    private func show(raw: String, symbology: Symbology, scene: ScenePhoto?, limitations: [String] = []) {
        guard result == nil else { return }
        if typeSize.isAccessibilitySize { detent = .large }
        services.camera.stop()
        let analysis = CodeInspector(locale: L10n.locale).inspect(raw, symbology: symbology)
        result = ResultModel(analysis: analysis, scene: scene, extraLimitations: limitations)
        services.history?.record(analysis, assessment: analysis.assessment, enabled: services.preferences.historyEnabled)
    }
}

@MainActor func openSettings() {
    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
}
