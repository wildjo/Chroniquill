//
//  WelcomeView.swift
//  Chroniquill
//

import SwiftUI
import UniformTypeIdentifiers

struct WelcomeView: View {
    var onFolderSelected: (URL) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Chroniquill")
                .font(.largeTitle)
                .bold()

            Text("The static site generator for long-form and short-form writing in the cloud.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom, 100)
    
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
        }
        Spacer ()
        Text ("Chroniquill does not sync files with your web server, but we suggest [FileZilla Free](https://filezilla-project.org/).")
            .font (.footnote)
            .multilineTextAlignment(.center)
            .foregroundColor (.gray)
            .padding (.bottom, 20)
            .padding()
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose a Home Directory for Chroniquill"
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
    WelcomeView(onFolderSelected: { _ in })
}
