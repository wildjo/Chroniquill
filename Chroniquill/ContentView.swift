//
//  ContentView.swift
//  ChroniQuill
//
//   Created by Johanna Wilder and ChatGPT on 3/19/25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedFolder: URL?

    var body: some View {
        if let folder = selectedFolder {
            EditorView(folder: folder)
        } else {
            WelcomeView(onFolderSelected: { folder in
                self.selectedFolder = folder
            })
        }
    }
}

#Preview {
    ContentView()
}
