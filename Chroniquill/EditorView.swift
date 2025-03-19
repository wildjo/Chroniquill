//
//  EditorView.swift
//  Chroniquill
//
//  Created by Johanna Wilder on 3/19/25.
//

import SwiftUI

struct EditorView: View {
    let folder: URL
    @State private var markdownFiles: [URL] = []
    @State private var selectedFile: URL?
    @State private var fileContents: String = ""

    var body: some View {
        HStack {
            // File List
            List(markdownFiles, id: \.self, selection: $selectedFile) { file in
                Text(file.deletingPathExtension().lastPathComponent)
                    .onTapGesture {
                        loadFile(file)
                    }
            }
            .frame(width: 200)
            .onAppear(perform: loadMarkdownFiles)

            // Editor
            VStack {
                if selectedFile != nil {
                    TextEditor(text: $fileContents)
                        .padding()
                        .border(Color.gray, width: 1)
                    
                    Button(action: saveFile) {
                        Text("Save")
                            .bold()
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding(.top, 10)
                } else {
                    Text("Select a file to edit")
                        .foregroundColor(.gray)
                }
            }
            .padding()
        }
    }

    private func loadMarkdownFiles() {
        let fileManager = FileManager.default
        do {
            let files = try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            markdownFiles = files.filter { $0.pathExtension == "md" }
        } catch {
            print("Error loading files: \(error.localizedDescription)")
        }
    }

    private func loadFile(_ file: URL) {
        do {
            fileContents = try String(contentsOf: file, encoding: .utf8)
            self.selectedFile = file  // No need for DispatchQueue
        } catch {
            print("Error loading file: \(error.localizedDescription)")
        }
    }
    
    private func saveFile() {
        guard let selectedFile = selectedFile else { return }
        do {
            try fileContents.write(to: selectedFile, atomically: true, encoding: .utf8)
        } catch {
            print("Error saving file: \(error.localizedDescription)")
        }
    }
}

#Preview {
    EditorView(folder: FileManager.default.homeDirectoryForCurrentUser)
}
