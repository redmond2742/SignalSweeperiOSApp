import Foundation

extension FileManager {
    /// Remove files older than the provided number of days from a directory
    func removeFiles(olderThan days: Int, in directory: URL) {
        let calendar = Calendar.current
        guard let files = try? contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles]) else { return }
        for url in files {
            guard let created = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate else { continue }
            if let diff = calendar.dateComponents([.day], from: created, to: Date()).day, diff >= days {
                try? removeItem(at: url)
            }
        }
    }
}
