import CoreLocation


class GPSLogger: NSObject, ObservableObject, CLLocationManagerDelegate {
    private var locationManager = CLLocationManager()
    private var gpxFileURL: URL!
    private var fileHandle: FileHandle?
    private var timer: Timer?

    @Published var lastLocation: CLLocation?

    func startLogging() {
        DispatchQueue.main.async {
            self.locationManager.delegate = self
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
            self.locationManager.distanceFilter  = kCLDistanceFilterNone
            self.locationManager.activityType    = .otherNavigation
            self.locationManager.pausesLocationUpdatesAutomatically = false
            self.locationManager.requestWhenInUseAuthorization()
         
            self.locationManager.startUpdatingLocation()
            
          
        }
        
       

        final class LocationService: NSObject, CLLocationManagerDelegate {

            private let locationManager = CLLocationManager()

            override init() {
                super.init()
                locationManager.delegate = self
                locationManager.desiredAccuracy = kCLLocationAccuracyBest
                // Ask for permission up‑front
                locationManager.requestWhenInUseAuthorization()
            }

            // MARK: - CLLocationManagerDelegate (iOS 14+)
            func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
                switch manager.authorizationStatus {

                case .notDetermined:
                    // The user hasn’t seen the prompt yet
                    manager.requestWhenInUseAuthorization()

                case .restricted, .denied:
                    print("❌ Location permission denied.")

                case .authorizedWhenInUse, .authorizedAlways:
                    startUpdatingLocation()

                @unknown default:
                    // Future‑proofing
                    break
                }
            }

            // MARK: - Helpers
            private func startUpdatingLocation() {
                locationManager.startUpdatingLocation()
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
