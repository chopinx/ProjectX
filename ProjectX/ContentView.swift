//
//  ContentView.swift
//  ProjectX
//
//  Created by Qinbang Xiao on 24.01.26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            ScanView()
                .tabItem {
                    Label("Scan", systemImage: "camera.viewfinder")
                }

            FoodBankView()
                .tabItem {
                    Label("Food Bank", systemImage: "fork.knife")
                }

            AnalysisView()
                .tabItem {
                    Label("Analysis", systemImage: "chart.bar.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}

