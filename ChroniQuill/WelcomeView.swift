//
//  WelcomeView.swift
//  ChroniQuill
//

import SwiftUI
import UniformTypeIdentifiers

struct WelcomeView: View {
    @ObservedObject var settings: SettingsModel
    var onFolderSelected: (URL) -> Void

    var body: some View {
        if settings.hasUsableHomeDirectory, let dir = settings.resolvedHomeDirectory {
            EditorView(folder: dir)
        } else {
            VStack(spacing: 20) {
                Spacer(minLength: 40)

                GeometryReader { geo in
                    Image("chroniquill-logos")
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width * 0.8)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(height: 160)

                Text("The static site generator for long-form and short-form writing in the cloud.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 60)

                Button(action: selectFolder) {
                    Text("Create Home")
                        .bold()
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.horizontal)

                Text("You do not have a folder selected in settings.\nTo begin, click \"Create Home\" and choose (or create) a folder where your files will be stored.\nThis can be a cloud-based folder accessible to your file system, or locally hosted.")
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal)

                Spacer()
                Text("ChroniQuill does not sync files with your web server, but we suggest [FileZilla Free](https://filezilla-project.org/).")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .padding(.bottom, 20)
                    .padding()
            }
            .onChange(of: settings.isLoaded) {
                // Trigger re-evaluation (side-effect-free, just encourages SwiftUI to re-render)
            }
        }
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose a Home Directory for ChroniQuill"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.urls.first {
            onFolderSelected(url)
        }
    }
}

#Preview {
    WelcomeView(settings: SettingsModel(), onFolderSelected: { _ in })
}
