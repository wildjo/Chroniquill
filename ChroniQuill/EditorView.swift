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
    @State private var selectedDate: Date = Date()
    @State private var fileName: String = "NewFile.md"
    @State private var pendingDate: Date?
    @State private var pendingFileName: String?
    
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
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button("+ New Long Form") {
                        createNewDocument(formType: "long-form")
                    }
                    .disabled(!SettingsModel.shared.isFormTypeEnabled("long-form"))

                    Button("+ New Short Form") {
                        createNewDocument(formType: "short-form")
                    }
                    .disabled(!SettingsModel.shared.isFormTypeEnabled("short-form"))
                    }
                .padding()
            }
            
            // Right Pane: Markdown editor
            VStack {
                if selectedFile != nil {
                    HStack {
                        DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                            .onChange(of: selectedDate) { _, newValue in
                                pendingDate = newValue
                                evaluateEditingState()
                            }
                        
                        Button("Save", action: saveFile)
                            .keyboardShortcut("s", modifiers: .command)
                            .disabled(!hasEdited)
                        
                        Button("Revert", action: revertFile)
                            .keyboardShortcut("r", modifiers: .command)
                            .disabled(!(hasEdited && hasBackup))
                        Spacer()
                    }
                    .padding([.top, .horizontal])
                    
                    TextField("Filename", text: $fileName)
                        .onChange(of: fileName) { _, newValue in
                            let sanitized = sanitizedFileName(from: newValue)
                            if let selected = selectedFile, sanitized != selected.deletingPathExtension().lastPathComponent {
                                pendingFileName = sanitized
                            }
                            evaluateEditingState()
                        }
                        .padding()
                    
                    TextEditor(text: $fileContents)
                        .padding()
                        .border(Color.gray, width: 1)
                        .onChange(of: fileContents) {
                            if !isProgrammaticChange {
                                evaluateEditingState()
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
        
    private func loadFile(_ file: URL) {
        if let previousFile = selectedFile, previousFile != file { // Avoid deleting backup if re-selecting same file
             deleteBackup(for: previousFile)
        }
        // Only create backup if it doesn't exist or if forced update needed
        let backupURL = file.deletingPathExtension().appendingPathExtension("_old.md")
        if !FileManager.default.fileExists(atPath: backupURL.path) {
             createBackup(for: file)
        }

        do {
            #if DEBUG
            print("📂 Loading file: \(file.lastPathComponent)")
            #endif
            isProgrammaticChange = true // Set flag BEFORE changing state

            let newContents = try String(contentsOf: file, encoding: .utf8)
            let newName = file.deletingPathExtension().lastPathComponent // Use name from URL

            // Extract date from file path structure (assuming "archive/type/YYYY/MM MMMM/dd EEEE/filename.md")
            var newDate = Date() // Default to today
            let pathComponents = file.pathComponents
            // Example path indices (adjust if structure differs):
            // [-1]: filename.md
            // [-2]: dd EEEE
            // [-3]: MM MMMM
            // [-4]: YYYY
            if pathComponents.count > 4 {
                 let dayStr = pathComponents[pathComponents.count - 2]
                 let monthStr = pathComponents[pathComponents.count - 3]
                 let yearStr = pathComponents[pathComponents.count - 4]

                 let dateFormatter = DateFormatter()
                 dateFormatter.locale = Locale(identifier: "en_US_POSIX") // Use fixed locale
                 dateFormatter.dateFormat = "yyyy/MM MMMM/dd EEEE"
                 if let date = dateFormatter.date(from: "\(yearStr)/\(monthStr)/\(dayStr)") {
                    newDate = date
                 } else {
                    print("⚠️ Could not parse date from path: \(yearStr)/\(monthStr)/\(dayStr)")
                 }
            }

            // Update state variables
            fileContents = newContents
            fileName = newName // Update TextField content
            selectedDate = newDate // Update DatePicker
            selectedFile = file
            pendingFileName = nil // Clear pending changes on load
            pendingDate = nil // Clear pending changes on load

            #if DEBUG
            print("📄 File contents loaded.")
            print("   Name set to: \(fileName)")
            print("   Date set to: \(selectedDate)")
            #endif

            // Now evaluate the initial state (should be not edited)
            evaluateEditingState() // This will set hasEdited=false, hasBackup=true

            // Reset flag after state updates, likely on main thread if UI updates are involved
            DispatchQueue.main.async {
                isProgrammaticChange = false
            }
        } catch {
            print("Error loading file: \(error.localizedDescription)")
            // Reset state if loading fails
            isProgrammaticChange = false
            fileContents = ""
            fileName = "Error.md"
            selectedDate = Date()
            selectedFile = nil
            pendingFileName = nil
            pendingDate = nil
            evaluateEditingState() // Reset button states
        }
    }
    
    private func saveFile() {
        guard var currentFile = selectedFile else { return }
        let originalFile = currentFile // Keep track for potential backup deletion if moved/renamed
        var fileWasMovedOrRenamed = false

        // Store pending changes before clearing them
        let dateToUse = pendingDate ?? selectedDate // Use pending if set, else current
        let nameToUse = pendingFileName ?? sanitizedFileName(from: fileName) // Use pending if set, else current sanitized

        do {
            // 1. Handle Date Change (Move File)
            let targetFolderPath = formattedFolderPath(from: dateToUse) // Use the final date
            guard let formType = SettingsModel.shared.formType(for: originalFile) else { return }
            let targetFolderURL = folder.appendingPathComponent("archive/\(formType)/\(targetFolderPath)")
            let potentialNewPathBasedOnDate = targetFolderURL.appendingPathComponent(currentFile.lastPathComponent) // Keep current name for now

            if currentFile.deletingLastPathComponent().path != targetFolderURL.path {
                 #if DEBUG
                 print("💾 Moving file due to date change...")
                 print("   From: \(currentFile.path)")
                 print("   To Dir: \(targetFolderURL.path)")
                 #endif
                try FileManager.default.createDirectory(at: targetFolderURL, withIntermediateDirectories: true)
                // Ensure the target doesn't already exist (maybe prompt user?) - simple overwrite for now
                 if FileManager.default.fileExists(atPath: potentialNewPathBasedOnDate.path) && potentialNewPathBasedOnDate != currentFile {
                     try FileManager.default.removeItem(at: potentialNewPathBasedOnDate)
                 }
                try FileManager.default.moveItem(at: currentFile, to: potentialNewPathBasedOnDate)
                currentFile = potentialNewPathBasedOnDate // Update currentFile URL
                fileWasMovedOrRenamed = true
                 #if DEBUG
                 print("   Move successful. New currentFile: \(currentFile.path)")
                 #endif
            }

             // 2. Handle Filename Change (Rename File)
            let finalFileName = "\(nameToUse).md" // Use the final name
            let finalFileURL = currentFile.deletingLastPathComponent().appendingPathComponent(finalFileName)

            if currentFile.lastPathComponent != finalFileName {
                 #if DEBUG
                 print("💾 Renaming file...")
                 print("   From: \(currentFile.lastPathComponent)")
                 print("   To: \(finalFileName)")
                 #endif
                 // Ensure the target doesn't already exist - simple overwrite for now
                 if FileManager.default.fileExists(atPath: finalFileURL.path) && finalFileURL != currentFile {
                     try FileManager.default.removeItem(at: finalFileURL)
                 }
                try FileManager.default.moveItem(at: currentFile, to: finalFileURL)
                currentFile = finalFileURL // Update currentFile URL
                fileWasMovedOrRenamed = true
                 #if DEBUG
                 print("   Rename successful. New currentFile: \(currentFile.path)")
                 #endif
            }

            // 3. Write Contents
            #if DEBUG
            print("💾 Writing content to: \(currentFile.path)")
            #endif
            try fileContents.write(to: currentFile, atomically: true, encoding: .utf8)

             // 4. Update State and UI
             // Delete old backup only if file was moved/renamed
             if fileWasMovedOrRenamed && originalFile != currentFile {
                 deleteBackup(for: originalFile)
             }
             createBackup(for: currentFile) // Create new backup for the final file state

            selectedFile = currentFile // Update the main @State variable
             fileName = currentFile.deletingPathExtension().lastPathComponent // Sync TextField
             selectedDate = dateToUse // Sync DatePicker

            pendingDate = nil // Clear pending states
            pendingFileName = nil

            buildFolderTree() // Update file hierarchy view
            evaluateEditingState() // Reset button states (should set hasEdited=false)

        } catch {
            print("Error saving file: \(error.localizedDescription)")
            // Optionally: Add user feedback like an alert
        }
    }

    private func revertFile() {
        guard let selectedFile = selectedFile, hasBackup else { return } // Ensure backup exists
        let backupURL = selectedFile.deletingPathExtension().appendingPathExtension("_old.md")

        do {
            isProgrammaticChange = true // Prevent TextEditor onChange loop

            // Restore content from backup
            let restoredContents = try String(contentsOf: backupURL, encoding: .utf8)
            fileContents = restoredContents // Update editor view

            // Also revert filename and date if they were pending changes
             fileName = selectedFile.deletingPathExtension().lastPathComponent
             pendingFileName = nil // Clear pending name change

             // Attempt to re-parse date from the selectedFile's path (as done in loadFile)
            var originalDate = Date() // Default
            let pathComponents = selectedFile.pathComponents
             if pathComponents.count > 4 {
                 let dayStr = pathComponents[pathComponents.count - 2]
                 let monthStr = pathComponents[pathComponents.count - 3]
                 let yearStr = pathComponents[pathComponents.count - 4]
                 let dateFormatter = DateFormatter()
                 dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                 dateFormatter.dateFormat = "yyyy/MM MMMM/dd EEEE"
                 if let date = dateFormatter.date(from: "\(yearStr)/\(monthStr)/\(dayStr)") {
                    originalDate = date
                 }
            }
            selectedDate = originalDate // Update DatePicker
            pendingDate = nil // Clear pending date change

            // Overwrite the main file with restored content (optional, could just reset state)
            // try fileContents.write(to: selectedFile, atomically: true, encoding: .utf8)
            // createBackup(for: selectedFile) // Re-create backup if main file is overwritten

            #if DEBUG
            print("↩️ Reverted state from backup. Pending changes cleared.")
            #endif

            evaluateEditingState() // Recalculate states (should be hasEdited=false)

            DispatchQueue.main.async { // Reset flag after updates
                isProgrammaticChange = false
            }
        } catch {
            print("⚠️ Failed to revert: \(error.localizedDescription)")
            isProgrammaticChange = false // Ensure flag is reset on error
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

    private func createNewDocument(formType: String) {
        let folderPath = formattedFolderPath(from: selectedDate)
        let newFolderURL = folder.appendingPathComponent("archive/\(formType)/\(folderPath)")
        
        do {
            try FileManager.default.createDirectory(at: newFolderURL, withIntermediateDirectories: true)
            let sanitizedName = sanitizedFileName(from: fileName)
            let newDocURL = newFolderURL.appendingPathComponent("\(sanitizedName).md")
            let content = "# New Document\n\nWrite something here..."
            try content.write(to: newDocURL, atomically: true, encoding: .utf8)
            loadFile(newDocURL)
            buildFolderTree()
        } catch {
            print("⚠️ Failed to create new document: \(error.localizedDescription)")
        }
    }
        
    private func evaluateEditingState() {
        guard let selected = selectedFile else {
            hasEdited = false
            hasBackup = false
            return
        }

        // --- Check for Name Change ---
        let originalName = selected.deletingPathExtension().lastPathComponent
        // Use pendingFileName if set, otherwise the current sanitized text field value
        let currentPotentiallyEditedName = pendingFileName ?? sanitizedFileName(from: fileName)
        let nameChanged = currentPotentiallyEditedName != originalName
        #if DEBUG
        print("🧐 evaluateEditingState: Original Name: \(originalName), Current/Pending Name: \(currentPotentiallyEditedName), Name Changed: \(nameChanged)")
        #endif

        // --- Check for Date Change ---
        let dateChanged = pendingDate != nil
        #if DEBUG
        print("🧐 evaluateEditingState: Pending Date: \(pendingDate != nil), Date Changed: \(dateChanged)")
        #endif


        // --- Check for Content Change ---
        var fileChanged = false
        do {
            // Compare current editor content with the content *currently* on disk at selectedFile URL
            let currentDiskContents = try String(contentsOf: selected, encoding: .utf8)
            fileChanged = fileContents != currentDiskContents
        } catch {
            // If we can't read the file, assume content might have changed if editor isn't empty
            fileChanged = !fileContents.isEmpty
            print("⚠️ Could not read original file content for comparison: \(error.localizedDescription)")
        }
        #if DEBUG
        print("🧐 evaluateEditingState: Content Changed: \(fileChanged)")
        #endif


        // --- Set Final State ---
        hasEdited = nameChanged || dateChanged || fileChanged

        // --- Check for Backup ---
        let backupURL = selected.deletingPathExtension().appendingPathExtension("_old.md")
        hasBackup = FileManager.default.fileExists(atPath: backupURL.path)

        #if DEBUG
        print("🏁 evaluateEditingState: Final hasEdited: \(hasEdited), hasBackup: \(hasBackup)")
        #endif
    }
    
    private func moveSelectedFileToMatchDate() {
        guard let selectedFile = selectedFile else { return }
        let targetFolderPath = formattedFolderPath(from: selectedDate)
        guard let formType = SettingsModel.shared.formType(for: selectedFile) else { return }
        let targetFolderURL = folder.appendingPathComponent("archive/\(formType)/\(targetFolderPath)")
        let targetFileURL = targetFolderURL.appendingPathComponent(selectedFile.lastPathComponent)
        
        do {
            try FileManager.default.createDirectory(at: targetFolderURL, withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: selectedFile, to: targetFileURL)
            self.selectedFile = targetFileURL
            buildFolderTree()
        } catch {
            print("⚠️ Failed to move file: \(error.localizedDescription)")
        }
    }
    
    private func renameSelectedFile() {
        guard let selectedFile = selectedFile else { return }
        let sanitizedName = sanitizedFileName(from: fileName)
        let newFileURL = selectedFile.deletingLastPathComponent().appendingPathComponent("\(sanitizedName).md")
        do {
            try FileManager.default.moveItem(at: selectedFile, to: newFileURL)
            self.selectedFile = newFileURL
            buildFolderTree()
        } catch {
            print("⚠️ Failed to rename file: \(error.localizedDescription)")
        }
    }
    
    private func formattedFolderPath(from date: Date) -> String {
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"
        let year = yearFormatter.string(from: date)
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MM MMMM"
        let month = monthFormatter.string(from: date)
        
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "dd EEEE"
        let day = dayFormatter.string(from: date)
        
        return "\(year)/\(month)/\(day)"
    }
    
    private func sanitizedFileName(from name: String) -> String {
        var trimmed = name
        if trimmed.lowercased().hasSuffix(".md") {
            trimmed = String(trimmed.dropLast(3))
        }
        return trimmed.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
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
