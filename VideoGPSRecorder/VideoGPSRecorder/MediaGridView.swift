//
//  MediaGridView.swift
//  VideoGPSRecorder
//
//  Created by Matt on 6/9/25.
//

import SwiftUI
import AVFoundation
import AVKit
import UniformTypeIdentifiers

// MARK: - Media Item Model
struct MediaItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let name: String
    let type: MediaType
    let creationDate: Date
    let fileSize: Int64
    
    enum MediaType {
        case video, photo, gpx
        
        var color: Color {
            switch self {
            case .video: return .blue
            case .photo: return .green
            case .gpx: return .orange
 
            }
        }
        
        var icon: String {
            switch self {
            case .video: return "video.fill"
            case .photo: return "photo.fill"
            case .gpx: return "location.fill"
    
            }
        }
    }
    
    static func == (lhs: MediaItem, rhs: MediaItem) -> Bool {
        lhs.url == rhs.url
    }
}

// MARK: - Media Grid View Model
@MainActor
class MediaGridViewModel: ObservableObject {
    @Published var mediaItems: [MediaItem] = []
    @Published var isLoading = false
    @Published var selectedItem: MediaItem?
    @Published var showingDeleteAlert = false
    @Published var itemToDelete: MediaItem?
    
    private let fileManager = FileManager.default
    private var tempDirectory: URL {
        fileManager.temporaryDirectory
    }
    
    func loadMediaFiles() {
        isLoading = true
        
        Task {
            do {
                let contents = try fileManager.contentsOfDirectory(
                    at: tempDirectory,
                    includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
                    options: []
                )
                
                let items = contents.compactMap { url -> MediaItem? in
                    guard let type = mediaType(for: url) else { return nil }
                    
                    let resources = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
                    let creationDate = resources?.creationDate ?? Date()
                    let fileSize = resources?.fileSize ?? 0
                    
                    return MediaItem(
                        url: url,
                        name: url.lastPathComponent,
                        type: type,
                        creationDate: creationDate,
                        fileSize: Int64(fileSize)
                    )
                }
                
                await MainActor.run {
                    self.mediaItems = items.sorted { $0.creationDate > $1.creationDate }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.mediaItems = []
                    self.isLoading = false
                }
            }
        }
    }
    
    private func mediaType(for url: URL) -> MediaItem.MediaType? {
        let pathExtension = url.pathExtension.lowercased()
        switch pathExtension {
        case "mov", "mp4", "m4v":
            return .video
        case "jpg", "jpeg", "png", "heic":
            return .photo
        case "gpx":
            return .gpx
        default:
            return nil
        }
    }
    
    func deleteItem(_ item: MediaItem) {
        do {
            try fileManager.removeItem(at: item.url)
            mediaItems.removeAll { $0.id == item.id }
        } catch {
            print("Failed to delete file: \(error)")
        }
    }
    
    func confirmDelete(_ item: MediaItem) {
        itemToDelete = item
        showingDeleteAlert = true
    }
    
    func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Main Media Grid View
struct MediaGridView: View {
    @StateObject private var viewModel = MediaGridViewModel()
    @Environment(\.dismiss) private var dismiss
    
    // Grid layout
    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 16)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.mediaItems.isEmpty {
                    emptyStateView
                } else {
                    mediaGridContent
                }
            }
            .navigationTitle("Media Files")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .font(.headline)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: FileListView()) {
                        Text("List View")
                            .font(.headline)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        viewModel.loadMediaFiles()
                    }
                    .font(.headline)
                }
            }
        }
        .onAppear {
            viewModel.loadMediaFiles()
        }
        .alert("Delete File", isPresented: $viewModel.showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let item = viewModel.itemToDelete {
                    viewModel.deleteItem(item)
                }
            }
        } message: {
            if let item = viewModel.itemToDelete {
                Text("Are you sure you want to delete \(item.name)?")
            }
        }
        .sheet(item: $viewModel.selectedItem) { item in
            MediaPreviewView(item: item)
        }
    }
    
    // MARK: - Loading View
    var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading media files...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Empty State View
    var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("No Media Files")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start recording videos or taking photos to see them here.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
    
    // MARK: - Media Grid Content
    var mediaGridContent: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.mediaItems) { item in
                    MediaItemCard(
                        item: item,
                        onTap: { viewModel.selectedItem = item },
                        onDelete: { viewModel.confirmDelete(item) },
                        formatFileSize: viewModel.formatFileSize,
                        formatDate: viewModel.formatDate
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - Media Item Card
struct MediaItemCard: View {
    let item: MediaItem
    let onTap: () -> Void
    let onDelete: () -> Void
    let formatFileSize: (Int64) -> String
    let formatDate: (Date) -> String
    
    @State private var showingShareSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Thumbnail/Preview Area
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(item.type.color.opacity(0.1))
                    .frame(height: 120)
                
                thumbnailContent
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(item.type.color, lineWidth: 2)
            )
            
            // File Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text(formatDate(item.creationDate))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Text(formatFileSize(item.fileSize))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(item.type.color)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Action Buttons
            HStack(spacing: 8) {
                Button(action: onTap) {
                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 12))
                        Text("View")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(item.type.color)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Button(action: { showingShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.system(size: 12))
                        .padding(6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
                
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 12))
                        .padding(6)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [item.url])
        }
    }
    
    @ViewBuilder
    var thumbnailContent: some View {
        switch item.type {
        case .photo:
            AsyncImage(url: item.url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipped()
                    .cornerRadius(12)
            } placeholder: {
                Image(systemName: "photo.fill")
                    .font(.system(size: 32))
                    .foregroundColor(item.type.color)
            }
            
        case .video:
            VideoThumbnailView(url: item.url)
                .frame(height: 120)
                .cornerRadius(12)
            
        case .gpx:
            VStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .font(.system(size: 32))
                    .foregroundColor(item.type.color)
                Text("GPS Log")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(item.type.color)
            }
        }
    }
}

// MARK: - Video Thumbnail View
struct VideoThumbnailView: View {
    let url: URL
    @State private var thumbnail: UIImage?
    
    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "video.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
            }
            
            // Play button overlay
            Circle()
                .fill(Color.black.opacity(0.6))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "play.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .offset(x: 2)
                )
        }
        .onAppear {
            generateThumbnail()
        }
    }
    
    private func generateThumbnail() {
        Task {
            let asset = AVURLAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            
            do {
                let cgImage = try await imageGenerator.image(at: .zero).image
                await MainActor.run {
                    self.thumbnail = UIImage(cgImage: cgImage)
                }
            } catch {
                // Thumbnail generation failed, will show default icon
            }
        }
    }
}

// MARK: - Media Preview View
struct MediaPreviewView: View {
    let item: MediaItem
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                switch item.type {
                case .photo:
                    AsyncImage(url: item.url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        ProgressView()
                            .tint(.white)
                    }
                    
                case .video:
                    VideoPlayer(player: AVPlayer(url: item.url))
                    
                case .gpx:
                    GPXPreviewView(url: item.url)
                }
            }
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - GPX Preview View
struct GPXPreviewView: View {
    let url: URL
    @State private var gpxContent = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("GPS Log File")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if !gpxContent.isEmpty {
                    Text(gpxContent)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                } else {
                    Text("Loading GPX content...")
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding()
        }
        .onAppear {
            loadGPXContent()
        }
    }
    
    private func loadGPXContent() {
        do {
            gpxContent = try String(contentsOf: url, encoding: .utf8)
        } catch {
            gpxContent = "Failed to load GPX file: \(error.localizedDescription)"
        }
    }
}

//// MARK: - Share Sheet
//struct ShareSheet: UIViewControllerRepresentable {
//    let items: [Any]
//    
//    func makeUIViewController(context: Context) -> UIActivityViewController {
//        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
//        return controller
//    }
//    
//    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
//}


