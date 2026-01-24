//
//  ContentView.swift
//  ProjectX
//
//  Created by Qinbang Xiao on 24.01.26.
//

import SwiftUI

struct ContentView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            ScanView(settings: settings)
                .tabItem {
                    Label("Scan", systemImage: "camera.viewfinder")
                }

            FoodBankView(settings: settings)
                .tabItem {
                    Label("Food Bank", systemImage: "fork.knife")
                }

            AnalysisView()
                .tabItem {
                    Label("Analysis", systemImage: "chart.bar.fill")
                }

            SettingsView(settings: settings)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}

