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
                .onAppear {
                    setupDefaultData()
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func setupDefaultData() {
        let context = sharedModelContainer.mainContext
        let manager = DefaultDataManager(modelContext: context)
        manager.setupDefaultData()
    }
}
