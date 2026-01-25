import SwiftUI

struct ContentView: View {
    @Bindable var settings: AppSettings
    @Environment(\.importManager) private var importManager
    @Environment(\.scanFlowManager) private var scanFlowManager
    @AppStorage("selectedTab") private var selectedTab = 0
    @State private var showingScan = false
    @State private var pendingOCRText: String?
    @State private var showReviewFromImport = false
    @State private var showNutritionFromImport = false
    @State private var isProcessingImport = false
    @State private var importError: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView().tabItem { Label("Trips", systemImage: "cart.fill") }.tag(0)
                FoodBankView(settings: settings).tabItem { Label("Foods", systemImage: "fork.knife") }.tag(1)
                AnalysisView().tabItem { Label("Analysis", systemImage: "chart.bar.fill") }.tag(2)
                SettingsView(settings: settings).tabItem { Label("Settings", systemImage: "gearshape.fill") }.tag(3)
            }
            scanButton
        }
        .fullScreenCover(isPresented: $showingScan) {
            ScanView(settings: settings, onDismiss: { showingScan = false })
        }
        .sheet(isPresented: .init(get: { importManager.showingImportTypeSelection }, set: { importManager.showingImportTypeSelection = $0 })) {
            importTypeSheet
        }
        .fullScreenCover(isPresented: $showReviewFromImport) {
            if let text = pendingOCRText { NavigationStack { ReceiptReviewView(text: text, settings: settings) } }
        }
        .fullScreenCover(isPresented: $showNutritionFromImport) {
            if let text = pendingOCRText { NavigationStack { NutritionLabelResultView(text: text, settings: settings) } }
        }
        .overlay { if isProcessingImport { processingOverlay } }
        .alert("Error", isPresented: .constant(importError != nil)) { Button("OK") { importError = nil } } message: { Text(importError ?? "") }
        .onChange(of: scanFlowManager.requestScanTab) { _, request in
            if request { showingScan = true; scanFlowManager.requestScanTab = false }
        }
    }

    private var scanButton: some View {
        Button { showingScan = true } label: {
            Circle().fill(Color.themePrimary).frame(width: 56, height: 56)
                .shadow(color: Color.themePrimary.opacity(0.4), radius: 8, y: 4)
                .overlay { Image(systemName: "camera.viewfinder").font(.system(size: 24, weight: .semibold)).foregroundStyle(.white) }
        }
        .offset(y: -28)
    }

    private var importTypeSheet: some View {
        ScanTypeSelectionSheet(
            onSelect: { type in importManager.showingImportTypeSelection = false; Task { await processImportedContent(type: type) } },
            onCancel: { importManager.showingImportTypeSelection = false; importManager.pendingImport = nil }
        ).presentationDetents([.medium])
    }

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.5).tint(.white)
                Text("Processing...").font(.headline).foregroundStyle(.white)
            }.padding(32).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func processImportedContent(type: ScanView.ScanType) async {
        guard let source = importManager.pendingImport else { return }
        isProcessingImport = true
        defer { isProcessingImport = false; importManager.pendingImport = nil }
        do {
            pendingOCRText = try await importManager.processImport(source)
            selectedTab = 1
            if type == .receipt { showReviewFromImport = true } else { showNutritionFromImport = true }
        } catch { importError = "Failed to process: \(error.localizedDescription)" }
    }
}
