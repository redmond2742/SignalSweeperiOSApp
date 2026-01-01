import CoreLocation


class GPSLogger: NSObject, ObservableObject, CLLocationManagerDelegate {
    private var locationManager = CLLocationManager()
    private var gpxFileURL: URL!
    private var fileHandle: FileHandle?
    private var timer: Timer?
    @Published var totalDistance: CLLocationDistance = 0.0
    
    @Published var lastLocationFix: CLLocation?
    



    @Published var lastLocation: CLLocation?

    func startLogging() {
        DispatchQueue.main.async {
            self.locationManager.delegate = self
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
            self.locationManager.distanceFilter  = kCLDistanceFilterNone
            self.locationManager.activityType    = .otherNavigation
            self.locationManager.pausesLocationUpdatesAutomatically = false
            self.locationManager.requestWhenInUseAuthorization()
            switch self.locationManager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.locationManager.startUpdatingLocation()
            case .notDetermined, .restricted, .denied:
                break
            @unknown default:
                break
            }
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yyyy--HH-mm-ss.SSS"
        formatter.timeZone = TimeZone.current

        let dateString = formatter.string(from: Date())
        let timeZoneAbbreviation = TimeZone.current.abbreviation() ?? "UTC"

        let filename = "track_\(dateString)-\(timeZoneAbbreviation).gpx"
        gpxFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        FileManager.default.createFile(atPath: gpxFileURL.path, contents: nil)
        fileHandle = try? FileHandle(forWritingTo: gpxFileURL)


        writeHeader()

        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let location = self.lastLocation, location.horizontalAccuracy >= 0 else {
                return
            }
            let timestamp = Date()
            DispatchQueue.global(qos: .utility).async {
                self.writeLocation(location, timestamp: timestamp)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }


    func stopLogging() {
        locationManager.stopUpdatingLocation()
        timer?.invalidate()
        timer = nil
        writeFooter()
        fileHandle?.closeFile()
        print("Saved GPX to: \(gpxFileURL.path)")
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
        guard let newLocation = locations.last, newLocation.horizontalAccuracy >= 0 else { return }

        if let last = lastLocation {
            let distance = newLocation.distance(from: last) // in meters
            totalDistance += distance
        }

        lastLocation = newLocation
        self.lastLocationFix = newLocation
        //logLocation(newLocation)
    }

    
    private func writeLocation(_ loc: CLLocation, timestamp: Date) {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestampString = isoFormatter.string(from: timestamp)
        let line = "  <trkpt lat=\"\(loc.coordinate.latitude)\" lon=\"\(loc.coordinate.longitude)\"><ele>\(loc.altitude)</ele><time>\(timestampString)</time></trkpt>\n"

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
