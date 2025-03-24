//
//  SettingsModel.swift
//  ChroniQuill
//
//  Created by Johanna Wilder and ChatGPT on 3/23/25.
//

import Foundation
import SwiftUI

struct ChroniquillSettings: Codable, Equatable {
    var homeDirectory: String
    var siteURL: String
    var shortFormEnabled: Bool
    var longFormEnabled: Bool
    
    static let defaultFilename = "settings.json"

    static let `default` = ChroniquillSettings(
        homeDirectory: "",
        siteURL: "",
        shortFormEnabled: true,
        longFormEnabled: true
    )
}

@MainActor
final class SettingsModel: ObservableObject {
    @Published var settings: ChroniquillSettings = .default
    @Published var isLoaded = false
    
    private var settingsFileURL: URL?

    // Singleton-ish (for now)
    static let shared = SettingsModel()
    
    private init() {}

    func load(from homeDirectory: URL) async {
        let fileURL = homeDirectory.appendingPathComponent(ChroniquillSettings.defaultFilename)
        settingsFileURL = fileURL
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(ChroniquillSettings.self, from: data)
            self.settings = decoded
            isLoaded = true
        } catch {
            print("⚠️ Failed to load settings: \(error.localizedDescription). Using defaults.")
            self.settings = .default
        }
    }

    func save() async {
        if settingsFileURL == nil {
            // Create a default path based on the current settings
            settingsFileURL = URL(fileURLWithPath: settings.homeDirectory)
                .appendingPathComponent(ChroniquillSettings.defaultFilename)
        }

        guard let fileURL = settingsFileURL else {
            print("⚠️ Cannot save settings: settingsFileURL is nil")
            return
        }

        do {
            let data = try JSONEncoder().encode(settings)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("⚠️ Failed to save settings: \(error.localizedDescription)")
        }
    }
    
    func setHomeDirectory(_ url: URL) async {
        await load(from: url)
    }
}
