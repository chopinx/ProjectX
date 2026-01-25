//
//  ContentView.swift
//  ProjectX
//
//  Created by Qinbang Xiao on 24.01.26.
//

import SwiftUI

struct ContentView: View {
    @Bindable var settings: AppSettings
    @Environment(\.importManager) private var importManager
    @State private var selectedTab = 0
    @State private var pendingOCRText: String?
    @State private var showReviewFromImport = false
    @State private var showNutritionFromImport = false
    @State private var isProcessingImport = false
    @State private var importError: String?

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            ScanView(settings: settings)
                .tabItem { Label("Scan", systemImage: "camera.viewfinder") }
                .tag(1)

            FoodBankView(settings: settings)
                .tabItem { Label("Food Bank", systemImage: "fork.knife") }
                .tag(2)

            AnalysisView()
                .tabItem { Label("Analysis", systemImage: "chart.bar.fill") }
                .tag(3)

            SettingsView(settings: settings)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(4)
        }
        .sheet(isPresented: Binding(
            get: { importManager.showingImportTypeSelection },
            set: { importManager.showingImportTypeSelection = $0 }
        )) {
            ScanTypeSelectionSheet(
                onSelect: { type in
                    importManager.showingImportTypeSelection = false
                    Task { await processImportedContent(type: type) }
                },
                onCancel: {
                    importManager.showingImportTypeSelection = false
                    importManager.pendingImport = nil
                }
            )
            .presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: $showReviewFromImport) {
            NavigationStack {
                if let text = pendingOCRText { ReceiptReviewView(text: text, settings: settings) }
            }
        }
        .fullScreenCover(isPresented: $showNutritionFromImport) {
            NavigationStack {
                if let text = pendingOCRText { NutritionLabelResultView(text: text, settings: settings) }
            }
        }
        .overlay {
            if isProcessingImport {
                ZStack {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView().scaleEffect(1.5).tint(.white)
                        Text("Processing...").font(.headline).foregroundStyle(.white)
                    }
                    .padding(32).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .alert("Error", isPresented: .constant(importError != nil)) {
            Button("OK") { importError = nil }
        } message: { Text(importError ?? "") }
    }

    private func processImportedContent(type: ScanView.ScanType) async {
        guard let source = importManager.pendingImport else { return }
        isProcessingImport = true
        defer {
            isProcessingImport = false
            importManager.pendingImport = nil
        }

        do {
            pendingOCRText = try await importManager.processImport(source)
            selectedTab = 1 // Switch to Scan tab for navigation context
            if type == .receipt { showReviewFromImport = true }
            else { showNutritionFromImport = true }
        } catch {
            importError = "Failed to process: \(error.localizedDescription)"
        }
    }
}

