import CoreLocation


class GPSLogger: NSObject, ObservableObject, CLLocationManagerDelegate {
    private var locationManager = CLLocationManager()
    private var gpxFileURL: URL!
    private var fileHandle: FileHandle?
    private var timer: Timer?

    @Published var lastLocation: CLLocation?

    func startLogging() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.activityType = .otherNavigation
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()

        // Retry GPS lock if we haven't received a location
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            if self.lastLocation == nil {
                self.locationManager.startUpdatingLocation()
            }
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime, .withFractionalSeconds]

        let timestampString = isoFormatter.string(from: Date())
        let sanitizedTimestamp = timestampString.replacingOccurrences(of: ":", with: "-")  // avoid colons in filename

        let filename = "track_\(sanitizedTimestamp).gpx"
        gpxFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        FileManager.default.createFile(atPath: gpxFileURL.path, contents: nil)
        fileHandle = try? FileHandle(forWritingTo: gpxFileURL)

        writeHeader()
    }


    func stopLogging() {
        locationManager.stopUpdatingLocation()
        timer?.invalidate()
        timer = nil
        writeFooter()
        fileHandle?.closeFile()
        print("Saved GPX to: \(gpxFileURL.path)")
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        lastLocation = loc
        writeLocation(loc)
    }
    
    private func writeLocation(_ loc: CLLocation) {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = isoFormatter.string(from: loc.timestamp)
        let line = "  <trkpt lat=\"\(loc.coordinate.latitude)\" lon=\"\(loc.coordinate.longitude)\"><ele>\(loc.altitude)</ele><time>\(timestamp)</time></trkpt>\n"

        if let data = line.data(using: .utf8) {
            fileHandle?.write(data)
        }
    }


    private func writeHeader() {
        let header = """
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<gpx version=\"1.1\" creator=\"VideoGPSRecorder\" xmlns=\"http://www.topografix.com/GPX/1/1\">
  <trk>
    <name>Track</name>
    <trkseg>
"""
        fileHandle?.write(Data(header.utf8))
    }

    private func writeFooter() {
        let footer = """
    </trkseg>
  </trk>
</gpx>
"""
        fileHandle?.write(Data(footer.utf8))
    }
}
