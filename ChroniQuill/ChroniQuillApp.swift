//
//  ChroniQuillApp.swift
//  ChroniQuill
//
//  Created by Johanna Wilder and ChatGPT on 3/19/25.
//

import SwiftUI

@main
struct ChroniQuillApp: App {
    @State private var showingSettings = false

    var body: some Scene {
        WindowGroup {
            WelcomeView(settings: SettingsModel.shared) { selectedURL in
                Task {
                    await SettingsModel.shared.setHomeDirectory(selectedURL)
                }
            }
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
                Button("About ChroniQuill…") {
                    // TODO: Hook this to WelcomeView or an AboutView
                }
            }
        }
    }
}
