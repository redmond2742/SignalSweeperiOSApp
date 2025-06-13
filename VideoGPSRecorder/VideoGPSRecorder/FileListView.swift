
import SwiftUI

struct FileListView: View {
    @State private var fileInfos: [(name: String, size: String, url: URL)] = []
    @State private var selectedFile: URL?
    @State private var showShareSheet = false
    @State private var fileToDelete: URL?
    @State private var showDeleteConfirm = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(fileInfos, id: \.url) { file in
                    FileRowView(
                        file: file,
                        selectedFile: $selectedFile,
                        showShareSheet: $showShareSheet,
                        fileToDelete: $fileToDelete,
                        showDeleteConfirm: $showDeleteConfirm
                    )
                    .swipeActions {
                        Button(role: .destructive) {
                            fileToDelete = file.url
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                
            }
        }
        .navigationTitle("Files")
        .onAppear(perform: loadFiles)
        .sheet(isPresented: $showShareSheet) {
            if let selected = selectedFile {
                ShareSheet(activityItems: [selected])
            }
        }
        .confirmationDialog("Delete this file?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let file = fileToDelete {
                    try? FileManager.default.removeItem(at: file)
                    loadFiles()
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    
    private func loadFiles() {
        fileInfos = []
        let fm = FileManager.default
        let docDir = FileManager.default.temporaryDirectory
        
        if let files = try? fm.contentsOfDirectory(at: docDir, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey], options: .skipsHiddenFiles).filter ({ !$0.lastPathComponent.hasSuffix(".tmp") }) {
            let fileTuples = files.compactMap { url -> (name: String, size: String, url: URL, date: Date)? in
                guard
                    let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey]),
                    let size = resourceValues.fileSize,
                    let date = resourceValues.creationDate
                else {
                    return nil
                }
                let mbSize = Double(size) / 1_048_576
                return (name: url.lastPathComponent, size: String(format: "%.2f MB", mbSize), url: url, date: date)
            }
            
            // Sort by most recent creation date
            fileInfos = fileTuples
                .sorted(by: { $0.date > $1.date })
                .map { ($0.name, $0.size, $0.url) }
        }
    }
}


