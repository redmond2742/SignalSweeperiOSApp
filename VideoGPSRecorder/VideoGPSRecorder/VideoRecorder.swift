import AVFoundation
import Foundation
import AVFAudio
import CoreLocation


import ImageIO



private var audioRecorder: AVAudioRecorder?
private var micRecordingTimer: Timer?



func getFreeDiskSpaceInMB() -> Double {
    if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
       let freeSize = attrs[.systemFreeSize] as? NSNumber {
        return freeSize.doubleValue / (1024 * 1024)  // convert bytes to MB
    }
    return 0
}

func gpsMetadata(from location: CLLocation) -> [String: Any] {
    var gps: [String: Any] = [:]

    gps[kCGImagePropertyGPSLatitude as String] = abs(location.coordinate.latitude)
    gps[kCGImagePropertyGPSLatitudeRef as String] = location.coordinate.latitude >= 0 ? "N" : "S"

    gps[kCGImagePropertyGPSLongitude as String] = abs(location.coordinate.longitude)
    gps[kCGImagePropertyGPSLongitudeRef as String] = location.coordinate.longitude >= 0 ? "E" : "W"

    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SS"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    gps[kCGImagePropertyGPSTimeStamp as String] = formatter.string(from: location.timestamp)

    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy:MM:dd"
    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    gps[kCGImagePropertyGPSDateStamp as String] = dateFormatter.string(from: location.timestamp)

    gps[kCGImagePropertyGPSAltitude as String] = location.altitude
    gps[kCGImagePropertyGPSAltitudeRef as String] = location.altitude < 0 ? 1 : 0
    gps[kCGImagePropertyGPSDOP as String] = location.horizontalAccuracy

    return gps
}



class VideoRecorder: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private var movieOutput = AVCaptureMovieFileOutput()
    private let photoOutput = AVCapturePhotoOutput()

    private var outputURL: URL?

    @Published var isRecording = false
    @Published var micCountdown: Int = 0
    private var countdownTimer: Timer?
    
    //private var pendingLocation: CLLocation?
    
    var gpsLogger: GPSLogger
    var pendingLocation: CLLocation? = nil
    

    init(gpsLogger:GPSLogger) {
        self.gpsLogger = gpsLogger
        super.init()
        setupSession()
        DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
    }

    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .hd1920x1080
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }


        guard let videoDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoInput) else { return }

        if videoDevice.activeFormat.isVideoStabilizationModeSupported(.standard) {
            try? videoDevice.lockForConfiguration()

            let frameRateRanges = videoDevice.activeFormat.videoSupportedFrameRateRanges
            if let range = frameRateRanges.first, range.maxFrameRate >= 60 {
                videoDevice.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 60)
                videoDevice.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 60)
            }

            videoDevice.unlockForConfiguration()
        }


        session.addInput(videoInput)

        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }

        session.commitConfiguration()
    }

    func startRecording() {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime, .withFractionalSeconds]

        let timestampString = isoFormatter.string(from: Date())
        let sanitizedTimestamp = timestampString.replacingOccurrences(of: ":", with: "-")  // avoid colons in filename

        let filename = "video_\(sanitizedTimestamp).mov"
        let outputPath = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        outputURL = outputPath

        DispatchQueue.global(qos: .userInitiated).async {
          

            // 90° clockwise from portrait‑up ⇒ landscape‑right
            let desiredAngle: CGFloat = 0  //actual recording of video file angle. 0: landscape, 90: portat.

            if let connection = self.movieOutput.connection(with: .video),
               connection.isVideoRotationAngleSupported(desiredAngle) {

                connection.videoRotationAngle = desiredAngle
            }


            DispatchQueue.main.async {
                self.movieOutput.startRecording(to: outputPath, recordingDelegate: self)
                self.isRecording = true
            }
        }
    }

    func stopRecording() {
        movieOutput.stopRecording()
       
        isRecording = false
    }
    
//    func capturePhoto(withAudio: Bool) {
//        let settings = AVCapturePhotoSettings()
//        
//        
//        
//        settings.flashMode = .off
//        photoOutput.capturePhoto(with: settings, delegate: self)
//        if withAudio {
//            startMicRecording(duration: 10)
//        }
//        // 90° clockwise from portrait‑up ⇒ landscape‑right
//        let desiredAngle: CGFloat = 0  //actual recording of video file angle. 0: landscape, 90: portat.
//
//        if let connection = photoOutput.connection(with: .video),
//           connection.isVideoRotationAngleSupported(desiredAngle) {
//
//            connection.videoRotationAngle = desiredAngle
//        }
//
//            let photoSettings = AVCapturePhotoSettings()
//            photoSettings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
//
//
//            // Attach GPS metadata if available
//            if let location = gpsLogger.lastLocation {
//                photoSettings.embeddedThumbnailPhotoFormat = [
//                    AVVideoCodecKey: AVVideoCodecType.jpeg
//                ]
//                self.pendingLocation = location // Save for use in delegate
//            }
//
//            photoOutput.capturePhoto(with: photoSettings, delegate: self)
//    }
    
    func capturePhoto(withAudio: Bool) {
        // Save latest GPS location before taking photo
        self.pendingLocation = gpsLogger.lastLocation

        // Create photo settings
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        //settings.isHighResolutionPhotoEnabled = true
        settings.embeddedThumbnailPhotoFormat = [AVVideoCodecKey: AVVideoCodecType.jpeg]

        // Set orientation
        if let connection = photoOutput.connection(with: .video) {
            let desiredAngle: CGFloat = 0 // 0 = landscape
            if connection.isVideoRotationAngleSupported(desiredAngle) {
                connection.videoRotationAngle = desiredAngle
            }
            
            let photoSettings = AVCapturePhotoSettings()
            photoSettings.maxPhotoDimensions = photoOutput.maxPhotoDimensions

        }

        // Capture photo
        photoOutput.capturePhoto(with: settings, delegate: self)

        // Start mic recording if enabled
        if withAudio {
            startMicRecording(duration: 10)
        }
    }

    
    func startMicRecording(duration: Int = 10) {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)

            AVAudioApplication.requestRecordPermission { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.beginMicRecording(duration: duration)
                    }
                } else {
                    print("❌ Microphone permission not granted")
                }
            }
        } catch {
            print("❌ Error setting up audio session: \(error.localizedDescription)")
        }
    }

    private func beginMicRecording(duration: Int) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss-SSS"
        let fileName = "mic_\(formatter.string(from: Date())).m4a"
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: outputURL, settings: settings)
            audioRecorder?.record()

            micCountdown = duration
            countdownTimer?.invalidate()
            countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                self.micCountdown -= 1
                if self.micCountdown <= 0 {
                    self.countdownTimer?.invalidate()
                    self.countdownTimer = nil
                    self.stopMicRecording()
                }
            }

        } catch {
            print("❌ Failed to start mic recording: \(error.localizedDescription)")
        }
    }


    private func stopMicRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        micRecordingTimer?.invalidate()
        micRecordingTimer = nil
        print("🎙️ Mic recording stopped")
    }

    

}



extension VideoRecorder: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        print("Saved video to: \(outputFileURL.path)")
    }
}

extension VideoRecorder: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let location = pendingLocation else {
                  print("failed to get image data or location")
             
                  return
              }
        
        // Add EXIF GPS metadata
       let source = CGImageSourceCreateWithData(imageData as CFData, nil)!
       let uti = CGImageSourceGetType(source)!

       let mutableData = NSMutableData()
       guard let destination = CGImageDestinationCreateWithData(mutableData, uti, 1, nil) else {
           return
       }

       var metadata = photo.metadata

       metadata[kCGImagePropertyGPSDictionary as String] = gpsMetadata(from: location)

       CGImageDestinationAddImageFromSource(destination, source, 0, metadata as CFDictionary)
       CGImageDestinationFinalize(destination)

       // Save photo with GPS metadata
       let filename = "photo_\(Date().timeIntervalSince1970 * 1000).jpg"
       let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

       do {
           try mutableData.write(to: url)
           print("📸 Saved photo with GPS to \(url.lastPathComponent)")
       } catch {
           print("❌ Error saving photo with GPS metadata: \(error.localizedDescription)")
       }

//        let formatter = DateFormatter()
//        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
//        let photo_filename = "photo_\(formatter.string(from: Date())).jpg"
//        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(photo_filename)
//
//        do {
//            try imageData.write(to: fileURL)
//            print("Photo saved to: \(fileURL)")
//        } catch {
//            print("Error saving photo: \(error)")
//        }
    }
}

