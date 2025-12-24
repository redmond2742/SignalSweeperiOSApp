import SwiftUI

struct FileRowView: View {
    var file: (name: String, size: String, url: URL)
    @Binding var selectedFile: URL?
    @Binding var showShareSheet: Bool
    @Binding var fileToDelete: URL?
    @Binding var showDeleteConfirm: Bool

    var iconName: String {
        switch file.url.pathExtension.lowercased() {
        case "mov": return "video.fill"
        case "gpx": return "map"
        case "jpg", "jpeg", "png": return "camera.fill"
        default: return "doc.fill"
        }
    }

    var iconColor: Color {
        switch file.url.pathExtension.lowercased() {
        case "mov": return .red
        case "gpx": return .green
        case "jpg", "jpeg", "png": return .blue
        default: return .gray
        }
    }

    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading) {
                Text(file.name)
                Text(file.size)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Button {
                selectedFile = file.url
                showShareSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.blue)
            }

            Menu {
                Button(role: .destructive) {
                    fileToDelete = file.url
                    showDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.gray)
            }
        }
    }
}

