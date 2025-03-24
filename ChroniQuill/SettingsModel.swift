//
//  SettingsModel.swift
//  ChroniQuill
//
//  Created by Johanna Wilder and ChatGPT on 3/23/25.
//

import Foundation
import SwiftUI

struct ChroniQuillSettings: Codable, Equatable {
    var homeDirectory: String
    var siteURL: String
    var shortFormEnabled: Bool
    var longFormEnabled: Bool
    
    static let defaultFilename = "settings.json"

    static let `default` = ChroniQuillSettings(
        homeDirectory: "",
        siteURL: "",
        shortFormEnabled: true,
        longFormEnabled: true
    )
}

@MainActor
final class SettingsModel: ObservableObject {
    @Published var settings: ChroniQuillSettings = .default
    @Published var isLoaded = false

    private var settingsFileURL: URL?
    private var homeDirectoryURL: URL?
    private let bookmarkKey = "ChroniQuillHomeDirectoryBookmark"

    // Singleton-ish (for now)
    static let shared = SettingsModel()

    #if DEBUG
    init() {
        restoreHomeDirectory()
    }
    #else
    private init() {
        restoreHomeDirectory()
    }
    #endif
    
    /// The resolved URL of the home directory from the security bookmark, if available.
    var resolvedHomeDirectory: URL? {
        homeDirectoryURL
    }

    func restoreHomeDirectory() {
        guard let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) else {
            #if DEBUG
            // Debug: No bookmark was found in UserDefaults at app launch
            print("ℹ️ No bookmark found in UserDefaults.")
            #endif
            return
        }

        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: bookmarkData, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale)
            if url.startAccessingSecurityScopedResource() {
                homeDirectoryURL = url
                Task {
                    await load(from: url)
                }
            } else {
                #if DEBUG
                // Debug: Failed to access security scoped resource
                print("⚠️ Failed to access security-scoped resource.")
                #endif
            }
        } catch {
            #if DEBUG
            // Debug: Failed to resolve the bookmark data
            print("⚠️ Failed to resolve bookmark: \(error.localizedDescription)")
            #endif
        }
    }

    func setHomeDirectory(_ url: URL) async {
        do {
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
            homeDirectoryURL = url
            await load(from: url)
            settings.homeDirectory = url.path
            _ = url.startAccessingSecurityScopedResource()
            await save()
            isLoaded = true

            #if DEBUG
            if let path = self.settingsFileURL?.path {
                print("✅ setHomeDirectory completed: settings.json written to \(path)")
            } else {
                print("❌ setHomeDirectory: settingsFileURL was nil")
            }
            #endif
        } catch {
            #if DEBUG
            // Debug: Failed to create a new bookmark for selected folder
            print("⚠️ Failed to create bookmark: \(error.localizedDescription)")
            #endif
        }
    }

    func load(from homeDirectory: URL) async {
        let fileURL = homeDirectory.appendingPathComponent(ChroniQuillSettings.defaultFilename)
        settingsFileURL = fileURL

        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(ChroniQuillSettings.self, from: data)
            self.settings = decoded
            isLoaded = true
            #if DEBUG
            // Debug: Successfully loaded settings from file
            print("✅ Loaded settings from file: \(decoded)")
            #endif
        } catch {
            #if DEBUG
            // Debug: Failed to load settings file — using defaults instead
            print("⚠️ Failed to load settings: \(error.localizedDescription). Using defaults.")
            #endif
            self.settings = .default
        }
    }

    func save() async {
        guard let directory = homeDirectoryURL else {
            #if DEBUG
            // Debug: No home directory URL set — cannot save
            print("⚠️ Cannot save settings: homeDirectoryURL is nil")
            #endif
            return
        }

        if settingsFileURL == nil {
            settingsFileURL = directory.appendingPathComponent(ChroniQuillSettings.defaultFilename)
        }

        guard let fileURL = settingsFileURL else {
            #if DEBUG
            // Debug: Failed to derive file URL from directory — cannot save
            print("⚠️ Cannot save settings: settingsFileURL is nil")
            #endif
            return
        }

        do {
            let data = try JSONEncoder().encode(settings)
            try data.write(to: fileURL, options: [.atomic])
                #if DEBUG
                // Debug: Successfully saved data to settings file
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("✅ Saved settings to file:\n\(jsonString)")
                } else {
                    print("✅ Saved settings to file, but couldn't convert to string.")
                }
                #endif
       } catch {
            #if DEBUG
            // Debug: Error occurred while saving settings to disk
            print("⚠️ Failed to save settings: \(error.localizedDescription)")
            #endif
        }
    }

    /// Whether the app has a usable home directory saved locally (via security bookmark).
    var hasUsableHomeDirectory: Bool {
        resolvedHomeDirectory != nil && isLoaded
    }
}
