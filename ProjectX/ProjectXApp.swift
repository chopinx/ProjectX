//
//  ProjectXApp.swift
//  ProjectX
//
//  Created by Qinbang Xiao on 24.01.26.
//

import SwiftUI
import SwiftData

@main
struct ProjectXApp: App {
    @State private var settings = AppSettings()
    @State private var importManager = ImportManager()
    @State private var scanFlowManager = ScanFlowManager()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Food.self,
            NutritionInfo.self,
            GroceryTrip.self,
            PurchasedItem.self,
            Tag.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(settings: settings)
                .environment(\.importManager, importManager)
                .environment(\.scanFlowManager, scanFlowManager)
                .onAppear {
                    setupDefaultData()
                }
                .onOpenURL { url in
                    handleOpenURL(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func setupDefaultData() {
        let context = sharedModelContainer.mainContext
        let manager = DefaultDataManager(modelContext: context)
        manager.setupDefaultData()
    }

    private func handleOpenURL(_ url: URL) {
        // Handle file URLs shared to the app
        if url.isFileURL {
            importManager.handleSharedContent(url: url)
        }
    }
}

// MARK: - Environment Key for Import Manager

private struct ImportManagerKey: EnvironmentKey {
    static let defaultValue = ImportManager()
}

extension EnvironmentValues {
    var importManager: ImportManager {
        get { self[ImportManagerKey.self] }
        set { self[ImportManagerKey.self] = newValue }
    }
}
