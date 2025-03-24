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

    @State private var draftSettings: ChroniQuillSettings
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
                // Removed opaque decorationImage from here
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
                        #if DEBUG
                        // Debug: Folder successfully selected via fileImporter
                        print("📁 Folder selected via fileImporter: \(url.path)")
                        #endif
                        draftSettings.homeDirectory = url.path  // ✅ Update the UI binding
                        Task {
                            await SettingsModel.shared.setHomeDirectory(url)
                            #if DEBUG
                            // Debug: setHomeDirectory completed successfully
                            print("✅ setHomeDirectory completed via fileImporter")
                            #endif
                        }
                    } else {
                        #if DEBUG
                        // Debug: fileImporter folder selection was cancelled or failed
                        print("❌ fileImporter folder selection failed")
                        #endif
                    }
                }
                Button("Verify") {}
                    .disabled(true)
            }

            HStack {
                Text("URL:")
                    .bold()
                TextField("https://www.yoursitehere.net/chroniquill", text: $draftSettings.siteURL)
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
            .onChange(of: settingsModel.settings) { oldValue, newValue in
                draftSettings = newValue
            }
        }
        .padding()
        .background(
            decorationImage
                .opacity(0.3)
                .padding([.top, .trailing], 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        )
        .frame(minWidth: 600, minHeight: 400)
    }

    @Environment(\.colorScheme) private var colorScheme

    private var decorationImage: some View {
        Image("chroniquill-decorations") // Let SwiftUI handle light/dark
            .resizable()
            .scaledToFit()
            .frame(width: 200, height: 150)
    }
}

#Preview {
    PreviewSettingsWrapper()
}

#if DEBUG
@MainActor
private struct PreviewSettingsWrapper: View {
    @StateObject private var model = SettingsModel.shared

    var body: some View {
        SettingsView(settingsModel: model)
    }
}
#endif

