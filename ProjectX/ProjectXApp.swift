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
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Food.self,
            NutritionInfo.self,
            GroceryTrip.self,
            PurchasedItem.self
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
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
