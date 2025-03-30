//
//  EditorView.swift
//  ChroniQuill
//
//   Created by Johanna Wilder and ChatGPT on 3/19/25.
//

import SwiftUI

struct FolderNode: Identifiable {
    let id = UUID()
    let url: URL
    var children: [FolderNode] = []
    var files: [URL] = []
    
    var name: String {
        url.lastPathComponent
    }
}

struct EditorView: View {
    let folder: URL
    @State private var markdownFiles: [URL] = []
    @State private var selectedFile: URL?
    @State private var fileContents: String = ""
    @State private var hasEdited = false
    @State private var hasBackup = false
    @State private var folderTree: [FolderNode] = []
    @State private var isProgrammaticChange = false

    var body: some View {
        HStack(spacing: 0) {
            // Combined Left Pane: Folder + Files Hierarchy
            VStack(alignment: .leading, spacing: 0) {
                List {
                    if FileManager.default.fileExists(atPath: folder.appendingPathComponent("archive/short-form").path) {
                        Section("Short Form") {
                            ForEach(folderTree.filter { $0.url.path.contains("short-form") }) { node in
                                FolderDisclosureView(node: node, selectedFile: $selectedFile, loadFile: loadFile)
                            }
                        }
                    }
                    if FileManager.default.fileExists(atPath: folder.appendingPathComponent("archive/long-form").path) {
                        Section("Long Form") {
                            ForEach(folderTree.filter { $0.url.path.contains("long-form") }) { node in
                                FolderDisclosureView(node: node, selectedFile: $selectedFile, loadFile: loadFile)
                            }
                        }
                    }
                }
                .frame(minWidth: 240, idealWidth: 260, maxWidth: 300)
            }

            // Right Pane: Markdown editor
            VStack {
                if selectedFile != nil {
                    HStack {
                        Button("Save", action: saveFile)
                            .keyboardShortcut("s", modifiers: .command)
                            .disabled(!hasEdited)

                        Button("Revert", action: revertFile)
                            .keyboardShortcut("r", modifiers: .command)
                            .disabled(!(hasEdited && hasBackup))
                        Spacer()
                    }
                    .padding([.top, .horizontal])

                    TextEditor(text: $fileContents)
                        .padding()
                        .border(Color.gray, width: 1)
                        .onChange(of: fileContents) {
                            if !isProgrammaticChange {
                                hasEdited = true
                                updateButtonStates()
                            }
                        }
                } else {
                    Text("Select a file to edit")
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .frame(minWidth: 400, maxWidth: .infinity)
        }
        .onAppear(perform: buildFolderTree)
        .onDisappear {
            if let selectedFile = selectedFile {
                deleteBackup(for: selectedFile)
            }
        }
        .navigationTitle("ChroniQuill \(selectedFile?.lastPathComponent ?? "")")
    }

    private func buildFolderTree() {
        folderTree = []
        let basePaths = ["archive/short-form", "archive/long-form"]
        for base in basePaths {
            let baseURL = folder.appendingPathComponent(base)
            if FileManager.default.fileExists(atPath: baseURL.path) {
                let rootNode = buildNode(from: baseURL)
                folderTree.append(rootNode)
            }
        }
    }

    private func buildNode(from url: URL) -> FolderNode {
        var node = FolderNode(url: url)
        let fm = FileManager.default
        if let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
            for item in contents {
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: item.path, isDirectory: &isDir) {
                    if isDir.boolValue {
                        node.children.append(buildNode(from: item))
                    } else if item.pathExtension == "md", !item.lastPathComponent.hasSuffix("_old.md") {
                        node.files.append(item)
                    }
                }
            }
        }
        return node
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

    private func updateButtonStates() {
        // Save is enabled if there are unsaved edits
        // Revert is enabled if edits have been made and a backup exists
        // Note: Backup is assumed to exist after file selection
        // and should persist unless manually reverted.
        #if DEBUG
        print("🔧 updateButtonStates() called")
        print("   selectedFile: \(selectedFile?.lastPathComponent ?? "nil")")
        #endif
        
        // Detect user edits
        DispatchQueue.main.async {
            isProgrammaticChange = false
        }
        
        if let selected = selectedFile {
            let backupURL = selected.deletingPathExtension().appendingPathExtension("_old.md")
            hasBackup = FileManager.default.fileExists(atPath: backupURL.path)
            #if DEBUG
            print("   checking backup exists: \(hasBackup)")
            #endif
            do {
                let currentContents = try String(contentsOf: selected, encoding: .utf8)
                hasEdited = fileContents != currentContents
                #if DEBUG
                print("   hasEdited (computed): \(hasEdited)")
                #endif

            } catch {
                hasEdited = false
            }
        } else {
            hasEdited = false
            hasBackup = false
        }
    }

    private func loadFile(_ file: URL) {
        if let previousFile = selectedFile {
            deleteBackup(for: previousFile)
        }
        createBackup(for: file)
        do {
            #if DEBUG
            print("📂 Loading file: \(file.lastPathComponent)")
            #endif
            isProgrammaticChange = true
            fileContents = try String(contentsOf: file, encoding: .utf8)
            selectedFile = file
            #if DEBUG
            print("📄 File contents loaded.")
            #endif
            hasEdited = false
            hasBackup = true
            updateButtonStates()
            
            // Delay assigning selectedFile until state is reset
            DispatchQueue.main.async {
                self.selectedFile = file
            }
        } catch {
            print("Error loading file: \(error.localizedDescription)")
        }
    }
    
    private func saveFile() {
        guard let selectedFile = selectedFile else { return }
        do {
            try fileContents.write(to: selectedFile, atomically: true, encoding: .utf8)
            deleteBackup(for: selectedFile) //delete old backup of old saved state
            createBackup(for: selectedFile) //create new backup from new saved state
            hasEdited = false
            hasBackup = true
            updateButtonStates()
        } catch {
            print("Error saving file: \(error.localizedDescription)")
        }
    }

    private func createBackup(for file: URL) {
        let backupURL = file.deletingPathExtension().appendingPathExtension("_old.md")
        do {
            try FileManager.default.copyItem(at: file, to: backupURL)
            #if DEBUG
            print("📦 Backup created for: \(file.lastPathComponent)")
            #endif
        } catch {
            print("⚠️ Failed to create backup: \(error.localizedDescription)")
        }
    }

    private func deleteBackup(for file: URL) {
        let backupURL = file.deletingPathExtension().appendingPathExtension("_old.md")
        if FileManager.default.fileExists(atPath: backupURL.path) {
            do {
                try FileManager.default.removeItem(at: backupURL)
                #if DEBUG
                print("🗑️ Deleted backup: \(backupURL.lastPathComponent)")
                #endif
            } catch {
                print("⚠️ Failed to delete backup: \(error.localizedDescription)")
            }
        }
    }

    private func revertFile() {
        guard let selectedFile = selectedFile else { return }
        let backupURL = selectedFile.deletingPathExtension().appendingPathExtension("_old.md")
        do {
            fileContents = try String(contentsOf: backupURL, encoding: .utf8)
            isProgrammaticChange = true
            try fileContents.write(to: selectedFile, atomically: true, encoding: .utf8)
            createBackup(for: selectedFile)
            hasEdited = false
            hasBackup = true
            updateButtonStates()
            #if DEBUG
            print("↩️ Reverted to backup")
            #endif
            DispatchQueue.main.async {
                isProgrammaticChange = false
            }
        } catch {
            print("⚠️ Failed to revert: \(error.localizedDescription)")
        }
    }
}

struct FolderDisclosureView: View {
    let node: FolderNode
    @Binding var selectedFile: URL?
    var loadFile: (URL) -> Void
    @State private var isExpanded = true

    private var fileListView: some View {
        ForEach(node.files, id: \.self) { file in
            let isSelected = selectedFile == file
            Text("📄 \(file.lastPathComponent)")
                .font(.subheadline)
                .foregroundColor(.primary)
                .padding(.leading, 8)
                .padding(.vertical, 2)
                .background(
                    isSelected ? Color.accentColor.opacity(0.2) : Color.clear
                )
                .onTapGesture {
                    loadFile(file)
                }
        }
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(node.children) { child in
                FolderDisclosureView(node: child, selectedFile: $selectedFile, loadFile: loadFile)
            }
            fileListView
            if node.files.isEmpty {
                Text("No files")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
            }
        } label: {
            Text("\(isExpanded ? "🗀" : "🗁") \(node.name)")
        }
    }
}

#Preview {
    EditorView(folder: FileManager.default.homeDirectoryForCurrentUser)
}
