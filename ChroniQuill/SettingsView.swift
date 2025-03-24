//
//  SettingsView.swift
//  ChroniQuill
//
//  Created by Johanna Wilder and ChatGPT on 3/23/25.
//

//
//  SettingsModel.swift
//  ChroniQuill
//
//  Created by Johanna Wilder and ChatGPT on 3/23/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsModel: SettingsModel
    @Environment(\.dismiss) private var dismiss

    @State private var draftSettings: ChroniquillSettings
    @State private var showFileImporter = false

    init(settingsModel: SettingsModel) {
        self.settingsModel = settingsModel
        _draftSettings = State(initialValue: settingsModel.settings)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Settings")
                    .font(.largeTitle)
                    .bold()
                Spacer()
                decorationImage
            }

            Toggle(isOn: $draftSettings.shortFormEnabled) {
                VStack(alignment: .leading) {
                    Text("Short Form")
                        .font(.headline)
                    Text("For social-media–style posts that go in a sidebar or frame.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: $draftSettings.longFormEnabled) {
                VStack(alignment: .leading) {
                    Text("Long Form")
                        .font(.headline)
                    Text("For longer blog-style posts that will have excerpts on the main page, and web pages of their own to display the full content.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("Home:")
                    .bold()
                TextField("Choose folder", text: $draftSettings.homeDirectory)
                    .textFieldStyle(.roundedBorder)
                Button("Change") {
                    showFileImporter = true
                }
                .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.folder]) { result in
                    if case .success(let url) = result {
                        draftSettings.homeDirectory = url.path
                    }
                }
                Button("Verify") {}
                    .disabled(true)
            }

            HStack {
                Text("URL:")
                    .bold()
                TextField("https://www.example.com", text: $draftSettings.siteURL)
                    .textFieldStyle(.roundedBorder)
                Button("Launch") {
                    if let url = URL(string: draftSettings.siteURL) {
                        NSWorkspace.shared.open(url)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Save") {
                    settingsModel.settings = draftSettings
                    Task {
                        await settingsModel.save()
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .background(
            decorationImage
                .opacity(0.3)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        )
        .frame(minWidth: 600, minHeight: 400)
    }

    private var decorationImage: some View {
        Group {
            if let image = NSImage(named: decorationImageName) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
            }
        }
    }

    private var decorationImageName: String {
        let scheme = NSApp.effectiveAppearance.name
        return scheme == .darkAqua ? "decoration-large-light" : "decoration-large-dark"
        
    }
}

#Preview {
    SettingsView(settingsModel: .shared)
}
