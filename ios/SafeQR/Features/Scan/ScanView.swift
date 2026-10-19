import SwiftUI
import PhotosUI
import SafeQRKit

struct ScanView: View {
    var isSelected = true
    @Environment(AppServices.self) private var services
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imported: ImportedScan?
    @State private var pendingImport: (code: ScannedCode, scan: ImportedScan)?
    @State private var result: ResultModel?
    @State private var errorMessage: String?
    @State private var importing = false
    @State private var detent = PresentationDetent.medium
    #if DEBUG
    @State private var launchedSample = false
    #endif

    var body: some View {
        NavigationStack {
            ZStack {
                if services.camera.state == .ready, let capture = services.camera.capture {
                    CameraPreview(capture: capture, ultraWide: services.camera.showsUltraWide)
                        .ignoresSafeArea().accessibilityHidden(true)
                    cameraOverlay
                } else {
                    placeholder
                }
                if importing {
                    ProgressView(L10n.text("Reading the picture…"))
                        .padding(24).glassEffect(in: RoundedRectangle(cornerRadius: 24))
                }
            }
            .background(AppStyle.canvas)
            .navigationTitle("Safe QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                #if DEBUG
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(DebugSample.Category.allCases) { category in
                            Menu(category.title) {
                                ForEach(DebugSample.allCases.filter { $0.category == category }) { sample in
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
            ResultView(model: result)
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
            services.camera.onDetection = { code, scene in show(raw: code.raw, symbology: code.symbology, scene: scene) }
            if services.preferences.finishedOnboarding { await services.camera.start() }
            #if DEBUG
            if !launchedSample, let screen = DebugLaunch.screen,
               let sample = DebugSample(rawValue: screen) {
                launchedSample = true
                detent = .large
                show(raw: sample.raw, symbology: .qr, scene: nil)
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

    private var placeholder: some View {
        ScrollView {
            VStack(spacing: 24) {
                ShieldMark(size: 116).padding(.top, 44)
                Text(services.camera.state == .denied ? L10n.text("Let’s give the camera a hand") : L10n.text("A little check.\nMore peace of mind."))
                    .font(.largeTitle.bold()).multilineTextAlignment(.center)
                Text(placeholderMessage).font(.title3).foregroundStyle(.secondary).multilineTextAlignment(.center)
                if services.camera.state == .denied {
                    Button(L10n.text("Open Settings")) { openSettings() }.buttonStyle(.glassProminent)
                        .foregroundStyle(AppStyle.onAccent).controlSize(.large)
                } else if services.camera.state == .idle {
                    Button(L10n.text("Allow camera")) { Task { await services.camera.start(requestPermission: true) } }
                        .buttonStyle(.glassProminent)
                        .foregroundStyle(AppStyle.onAccent).controlSize(.large)
                }
                PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                    Label(L10n.text("Import photo"), systemImage: "photo.on.rectangle")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 38)
                }
                .buttonStyle(.glassProminent)
                .foregroundStyle(AppStyle.onAccent)
                .disabled(importing)
                Label(L10n.text("Nothing opens without your say-so."), systemImage: "hand.raised")
                    .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                #if DEBUG
                VStack(spacing: 12) {
                    Text(L10n.text("Try a sample code")).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) { sampleButtons }
                        VStack(spacing: 10) { sampleButtons }
                    }
                }
                .padding(.top, 20)
                #endif
            }
            .padding(28)
            .frame(maxWidth: 540).frame(maxWidth: .infinity)
        }
    }

    private var placeholderMessage: String {
        if services.camera.state == .denied {
            return L10n.text("Camera access is off. Allow it in Settings, or choose a picture to check.")
        }
        #if targetEnvironment(simulator)
        return L10n.text("The Simulator has no camera. Import a picture or try a sample code below.")
        #else
        return services.camera.state == .unavailable ? ScanError.unavailable.message : L10n.text("Point the camera at a code. We’ll explain it before you decide what to do.")
        #endif
    }

    private var cameraOverlay: some View {
        VStack(spacing: 24) {
            Text(services.camera.showsUltraWide ? L10n.text("Wide view · scanning with the main camera") : L10n.text("Place the code inside the frame"))
                .font(.headline).padding(16).glassEffect(in: Capsule()).padding(.top, 20)
            Spacer()
            Image(systemName: "viewfinder").font(.system(size: 220, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.8)).accessibilityHidden(true)
            Spacer()
            GlassEffectContainer(spacing: 16) {
                HStack(spacing: 16) {
                    if services.camera.hasTorch {
                        Button { services.camera.toggleTorch() } label: {
                            Label(services.camera.torchEnabled ? L10n.text("Turn light off") : L10n.text("Turn light on"),
                                  systemImage: services.camera.torchEnabled ? "flashlight.on.fill" : "flashlight.off.fill")
                                .labelStyle(.iconOnly).frame(width: 50, height: 50)
                        }
                        .buttonStyle(.glass)
                    }
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(L10n.text("Import photo"), systemImage: "photo").labelStyle(.iconOnly).frame(width: 50, height: 50)
                    }
                    .buttonStyle(.glass)
                    if services.camera.hasUltraWide {
                        Button { services.camera.showsUltraWide.toggle() } label: {
                            Text(services.camera.showsUltraWide ? "0.5×" : "1×").font(.headline).frame(width: 64, height: 50)
                        }
                        .buttonStyle(.glass)
                        .accessibilityLabel(services.camera.showsUltraWide ? L10n.text("Show the main camera") : L10n.text("Show the surroundings camera"))
                    }
                }
            }
            .padding(.bottom, 30)
        }
        .padding(.horizontal, 20)
    }

    #if DEBUG
    private var sampleButtons: some View {
        ForEach([DebugSample.link, .payment, .wifi]) { sample in
            Button(sample.title) { show(raw: sample.raw, symbology: .qr, scene: nil) }
                .buttonStyle(.glass).controlSize(.large)
                .accessibilityIdentifier("sample-\(sample.rawValue)")
        }
    }
    #endif

    private func finishImportSelection() {
        guard let pending = pendingImport else {
            Task { await services.camera.start() }
            return
        }
        pendingImport = nil
        let limitation = L10n.format("This picture contains %lld codes. A sticker may be covering the original.", pending.scan.codes.count)
        show(raw: pending.code.raw, symbology: pending.code.symbology,
             scene: ScenePhoto(jpeg: pending.scan.jpeg, source: .photo, bounds: pending.code.bounds),
             limitations: [limitation])
    }

    private func show(raw: String, symbology: Symbology, scene: ScenePhoto?, limitations: [String] = []) {
        guard result == nil else { return }
        services.camera.stop()
        let analysis = CodeInspector(locale: L10n.locale).inspect(raw, symbology: symbology)
        result = ResultModel(analysis: analysis, scene: scene, extraLimitations: limitations)
        services.history?.record(analysis, assessment: analysis.assessment, enabled: services.preferences.historyEnabled)
    }
}

@MainActor func openSettings() {
    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
}
