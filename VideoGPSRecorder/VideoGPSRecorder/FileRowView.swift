import CoreLocation
import SwiftUI

struct FileRowView: View {
    let item: MediaListItem
    let onShare: () -> Void
    let onDelete: () -> Void
    let formatFileSize: (Int64) -> String
    let formatDate: (Date) -> String
    let formatDuration: (TimeInterval?) -> String
    let formatDistance: (CLLocationDistance?) -> String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnailView
                .frame(width: 84, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(1)

                metadataView
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                }

                Menu {
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        switch item.type {
        case .video:
            VideoThumbnailView(url: item.url)
                .scaledToFill()
        case .photo:
            AsyncImage(url: item.url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ZStack {
                    Color.blue.opacity(0.1)
                    Image(systemName: "photo")
                        .foregroundColor(.blue)
                }
            }
        case .gpx:
            ZStack {
                Color.orange.opacity(0.1)
                Image(systemName: "location.fill")
                    .foregroundColor(.orange)
            }
        }
    }

    @ViewBuilder
    private var metadataView: some View {
        switch item.type {
        case .video:
            VStack(alignment: .leading, spacing: 2) {
                Text("Length \(formatDuration(item.duration)) • \(formatFileSize(item.fileSize))")
                Text("Recorded \(formatDate(item.creationDate))")
            }
        case .photo:
            VStack(alignment: .leading, spacing: 2) {
                Text("\(formatFileSize(item.fileSize))")
                Text("Captured \(formatDate(item.creationDate))")
            }
        case .gpx:
            VStack(alignment: .leading, spacing: 2) {
                Text("Length \(formatDistance(item.gpxDistance)) • \(formatFileSize(item.fileSize))")
                Text("City \(item.gpxCity ?? "Unknown")")
            }
        }
    }
}
