import Foundation
import Combine

/// Container object to share recorder and logger across views
final class AppServices: ObservableObject {
    @Published var gpsLogger = GPSLogger()
    @Published lazy var videoRecorder = VideoRecorder(gpsLogger: gpsLogger)
}
