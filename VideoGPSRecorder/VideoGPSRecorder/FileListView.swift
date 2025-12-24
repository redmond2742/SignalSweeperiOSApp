import AVFoundation
import CoreLocation
import SwiftUI

struct MediaListItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let name: String
    let type: MediaType
    let creationDate: Date
    let fileSize: Int64
    let duration: TimeInterval?
    let gpxDistance: CLLocationDistance?
    let gpxCoordinate: CLLocationCoordinate2D?
    var gpxCity: String?

    enum MediaType {
        case video
        case photo
        case gpx
    }
}

@MainActor
final class FileListViewModel: ObservableObject {
    @Published var items: [MediaListItem] = []
    @Published var isLoading = false
    @Published var selectedItem: MediaListItem?
    @Published var showingDeleteAlert = false
    @Published var itemToDelete: MediaListItem?

    private let fileManager = FileManager.default

    func loadFiles() {
        isLoading = true

        Task.detached { [weak self] in
            guard let self else { return }
            let urls = (try? self.fileManager.contentsOfDirectory(
                at: self.fileManager.temporaryDirectory,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )) ?? []

            let items = urls.compactMap { url -> MediaListItem? in
                guard let type = self.mediaType(for: url) else { return nil }
                guard let resourceValues = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey]) else {
                    return nil
                }

                let creationDate = resourceValues.creationDate ?? Date()
                let fileSize = Int64(resourceValues.fileSize ?? 0)
                let name = url.lastPathComponent

                switch type {
                case .video:
                    let asset = AVURLAsset(url: url)
                    let duration = asset.duration.seconds
                    return MediaListItem(
                        url: url,
                        name: name,
                        type: type,
                        creationDate: creationDate,
                        fileSize: fileSize,
                        duration: duration,
                        gpxDistance: nil,
                        gpxCoordinate: nil,
                        gpxCity: nil
                    )
                case .photo:
                    return MediaListItem(
                        url: url,
                        name: name,
                        type: type,
                        creationDate: creationDate,
                        fileSize: fileSize,
                        duration: nil,
                        gpxDistance: nil,
                        gpxCoordinate: nil,
                        gpxCity: nil
                    )
                case .gpx:
                    let coordinates = self.parseGPXCoordinates(from: url)
                    let gpxDistance = self.distance(for: coordinates)
                    let coordinate = coordinates.first
                    return MediaListItem(
                        url: url,
                        name: name,
                        type: type,
                        creationDate: creationDate,
                        fileSize: fileSize,
                        duration: nil,
                        gpxDistance: gpxDistance,
                        gpxCoordinate: coordinate,
                        gpxCity: coordinate == nil ? "Unknown" : "Resolving..."
                    )
                }
            }

            let sortedItems = items.sorted { $0.creationDate > $1.creationDate }

            await MainActor.run {
                self.items = sortedItems
                self.isLoading = false
            }

            for item in sortedItems where item.type == .gpx {
                await self.updateCity(for: item)
            }
        }
    }

    func confirmDelete(_ item: MediaListItem) {
        itemToDelete = item
        showingDeleteAlert = true
    }

    func deleteItem(_ item: MediaListItem) {
        do {
            try fileManager.removeItem(at: item.url)
            items.removeAll { $0.id == item.id }
        } catch {
            print("Failed to delete file: \(error)")
        }
    }

    func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    func formatDuration(_ duration: TimeInterval?) -> String {
        guard let duration, duration.isFinite else { return "0:00" }
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    func formatDistance(_ distance: CLLocationDistance?) -> String {
        guard let distance else { return "0.0 mi" }
        let miles = distance * 0.000621371
        return String(format: "%.2f mi", miles)
    }

    private func mediaType(for url: URL) -> MediaListItem.MediaType? {
        switch url.pathExtension.lowercased() {
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

    private func parseGPXCoordinates(from url: URL) -> [CLLocationCoordinate2D] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let pattern = "lat=\\\"([0-9.+-]+)\\\" lon=\\\"([0-9.+-]+)\\\""
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        let matches = regex.matches(in: content, range: range)

        return matches.compactMap { match -> CLLocationCoordinate2D? in
            guard match.numberOfRanges == 3,
                  let latRange = Range(match.range(at: 1), in: content),
                  let lonRange = Range(match.range(at: 2), in: content),
                  let lat = Double(content[latRange]),
                  let lon = Double(content[lonRange]) else {
                return nil
            }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    private func distance(for coordinates: [CLLocationCoordinate2D]) -> CLLocationDistance {
        guard coordinates.count > 1 else { return 0 }
        var distance: CLLocationDistance = 0
        for index in 1..<coordinates.count {
            let start = CLLocation(latitude: coordinates[index - 1].latitude, longitude: coordinates[index - 1].longitude)
            let end = CLLocation(latitude: coordinates[index].latitude, longitude: coordinates[index].longitude)
            distance += start.distance(from: end)
        }
        return distance
    }

    private func updateCity(for item: MediaListItem) async {
        guard let coordinate = item.gpxCoordinate else { return }
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            let placemark = placemarks.first
            let city = placemark?.locality ?? placemark?.administrativeArea ?? "Unknown"
            await MainActor.run {
                if let index = self.items.firstIndex(where: { $0.id == item.id }) {
                    self.items[index].gpxCity = city
                }
            }
        } catch {
            await MainActor.run {
                if let index = self.items.firstIndex(where: { $0.id == item.id }) {
                    self.items[index].gpxCity = "Unknown"
                }
            }
        }
    }
}

struct FileListView: View {
    @StateObject private var viewModel = FileListViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView("Loading files...")
                        .progressViewStyle(.circular)
                } else if viewModel.items.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(viewModel.items) { item in
                            FileRowView(
                                item: item,
                                onShare: { viewModel.selectedItem = item },
                                onDelete: { viewModel.confirmDelete(item) },
                                formatFileSize: viewModel.formatFileSize,
                                formatDate: viewModel.formatDate,
                                formatDuration: viewModel.formatDuration,
                                formatDistance: viewModel.formatDistance
                            )
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Recordings")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        viewModel.loadFiles()
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadFiles()
        }
        .alert("Delete File", isPresented: $viewModel.showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
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
            ShareSheet(activityItems: [item.url])
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 52))
                .foregroundColor(.secondary)

            Text("No files saved yet")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Record a video or save a GPX track to see it listed here.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}
