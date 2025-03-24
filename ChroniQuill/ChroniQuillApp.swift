//
//  ChroniquillApp.swift
//  ChroniQuill
//
//  Created by Johanna Wilder and ChatGPT on 3/19/25.
//

import SwiftUI

@main
struct ChroniquillApp: App {
    @State private var showingSettings = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .sheet(isPresented: $showingSettings) {
                    SettingsView(settingsModel: .shared)
                }
        }

        // App Menu commands
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    showingSettings = true
                }
                .keyboardShortcut(",", modifiers: [.command])
            }

            CommandGroup(replacing: .appInfo) {
                Button("About Chroniquill…") {
                    // TODO: Hook this to WelcomeView or an AboutView
                }
            }
        }
    }
}
