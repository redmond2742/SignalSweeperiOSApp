import CoreLocation

class GPSLogger: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var totalDistance: CLLocationDistance = 0.0
    @Published var lastLocation: CLLocation?

    private let locationManager = CLLocationManager()
    private let fileWriteQueue = DispatchQueue(label: "com.videogpsrecorder.gpx.write")
    private let stateQueue = DispatchQueue(label: "com.videogpsrecorder.gpx.state")

    private var gpxFileURL: URL?
    private var fileHandle: FileHandle?
    private var samplingTimer: DispatchSourceTimer?
    private var latestLocation: CLLocation?
    private var lastDistanceLocation: CLLocation?
    private var isLogging = false

    func startLogging() {
        guard !isLogging else { return }
        isLogging = true

        stateQueue.sync {
            latestLocation = nil
        }
        DispatchQueue.main.async {
            self.totalDistance = 0.0
            self.lastLocation = nil
            self.lastDistanceLocation = nil
        }

        configureLocationManager()
        prepareGPXFile()
        writeHeader()
        startSamplingTimer()
    }

    func stopLogging() {
        guard isLogging else { return }
        isLogging = false

        locationManager.stopUpdatingLocation()
        stopSamplingTimer()
        finalizeGPXFile()
    }

    private func configureLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.activityType = .otherNavigation
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.requestWhenInUseAuthorization()

        if locationManager.authorizationStatus == .authorizedAlways
            || locationManager.authorizationStatus == .authorizedWhenInUse {
            locationManager.startUpdatingLocation()
        }
    }

    private func prepareGPXFile() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yyyy--HH-mm-ss.SSS"
        formatter.timeZone = TimeZone.current

        let dateString = formatter.string(from: Date())
        let timeZoneAbbreviation = TimeZone.current.abbreviation() ?? "UTC"
        let filename = "track_\(dateString)-\(timeZoneAbbreviation).gpx"

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        gpxFileURL = url
        FileManager.default.createFile(atPath: url.path, contents: nil)
        fileHandle = try? FileHandle(forWritingTo: url)
    }

    private func startSamplingTimer() {
        let timer = DispatchSource.makeTimerSource(queue: fileWriteQueue)
        timer.schedule(deadline: .now(), repeating: 1.0)
        timer.setEventHandler { [weak self] in
            self?.captureSample()
        }
        timer.resume()
        samplingTimer = timer
    }

    private func stopSamplingTimer() {
        samplingTimer?.cancel()
        samplingTimer = nil
    }

    private func captureSample() {
        guard let location = stateQueue.sync(execute: { latestLocation }),
              location.horizontalAccuracy >= 0 else { return }
        writeLocation(location, timestamp: Date())
    }

    private func finalizeGPXFile() {
        fileWriteQueue.sync {
            writeFooter()
            fileHandle?.synchronizeFile()
            fileHandle?.closeFile()
        }

        if let url = gpxFileURL {
            print("Saved GPX to: \(url.path)")
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .notDetermined, .restricted, .denied:
            break
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last,
              newLocation.horizontalAccuracy >= 0 else { return }

        stateQueue.sync {
            latestLocation = newLocation
        }

        DispatchQueue.main.async {
            if let last = self.lastDistanceLocation {
                self.totalDistance += newLocation.distance(from: last)
            }
            self.lastLocation = newLocation
            self.lastDistanceLocation = newLocation
        }
    }

    private func writeLocation(_ location: CLLocation, timestamp: Date) {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestampString = isoFormatter.string(from: timestamp)

        let line = "  <trkpt lat=\"\(location.coordinate.latitude)\" lon=\"\(location.coordinate.longitude)\"><ele>\(location.altitude)</ele><time>\(timestampString)</time></trkpt>\n"

        if let data = line.data(using: .utf8) {
            fileHandle?.write(data)
            fileHandle?.synchronizeFile()
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
        fileWriteQueue.sync {
            self.fileHandle?.write(Data(header.utf8))
            self.fileHandle?.synchronizeFile()
        }
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
