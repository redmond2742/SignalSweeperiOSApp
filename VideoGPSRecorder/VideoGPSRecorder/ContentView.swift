//import SwiftUI
//
//
//
//
//struct ContentView: View {
//  
//    @StateObject private var gpsLogger = GPSLogger()
//    @StateObject private var recorder = VideoRecorder(gpsLogger: GPSLogger())
//    @StateObject private var orientationObserver = OrientationObserver()
//    
//    @State private var recordingStartTime: Date?
//    @State private var recordingTimer: Timer?
//    @State private var elapsedTimeString: String = "00:00:00"
//    @State private var previewSize: CGFloat = UIScreen.main.bounds.width - 40
//    @State private var isMenuOpen: Bool = false
//    @State private var isMicEnabled: Bool = false
//    @State private var isTakingPhoto = false
//    
//
//  
//
//
//
//
//    
//    var body: some View {
//        NavigationStack {
//            GeometryReader { geometry in
//     
//                ZStack(alignment: .topLeading) {
//                    // your main UI here (e.g., VStack)
//
//                        gpsRecordingStatusIcon
//                    
//                VStack(spacing: 5) {
//             
//                       
//                        HStack {
//                            statusLabel  // ✅ Shows at top of screen
//                            Button(action: {
//                                isMenuOpen.toggle()
//                            }) {
//                                Image(systemName: "line.horizontal.3")
//                                    .resizable()
//                                    .frame(width: 30, height: 20)
//                                    .padding()
//                            }
//
//                            Spacer()
//                        }
//                 
//
//                    ScrollView {
//                
//                            VStack(spacing: 0) {
//                                HStack(alignment: .top, spacing: 20) {
//                                    videoPreview
//                                    
//                                    VStack(spacing: 10) {
//                                        statusBtns
//                                        Spacer()
//                                        picBtn
//                                    }
//                                    VStack {
//                                        Spacer()
//                                        micCountdownDisplay
//                                        Spacer()
//                                        
//                                        
//                                        
//                                    }
//                                    .frame(width: 100)
//                            }
//                           
//                                gpsInfo
//                                    .padding()
//                                    .frame(maxWidth: .infinity)
//                                    .background(Color.black.opacity(0.05))
//                                }
//                           
//                            .padding()
//                        
//                    }
//                }
//                }
//
//            }
//        }
//        .sheet(isPresented: $isMenuOpen) {
//            FileListView()
//        }
//        .onAppear {
//            OrientationLock.lockToLandscape()
//        }
//    }
//
//    
//    var videoPreview: some View {
//        VideoPreviewView(session: recorder.session, orientationObserver: orientationObserver)
//            .aspectRatio(16/9, contentMode: .fit)
//            .cornerRadius(10)
//            .frame(maxHeight: 220)
//            .clipped()
//
//    }
//    
//    var gpsRecordingStatusIcon: some View {
//        HStack(spacing: 8) {
//            Circle()
//                .fill((gpsLogger.lastLocation != nil && recorder.isRecording) ? Color.green : Color.red)
//                .frame(width: 12, height: 12)
//            
//            Text("GPS & Video")
//                .font(.caption)
//                .foregroundColor(.primary)
//        }
//        .padding(8)
//        .background(Color.black.opacity(0.1))
//        .cornerRadius(8)
//        .padding(.leading)
//        .padding(.top, 10)
//    }
//    
//    var micCountdownDisplay: some View {
//        Group {
//            if recorder.micCountdown > 0 {
//                Text("\(recorder.micCountdown)")
//                    .font(.system(size: 64, weight: .bold, design: .rounded))
//                    .foregroundColor(.orange)
//                    .padding(.top)
//            } else {
//                EmptyView()
//            }
//        }
//    }
//
//    
//    var estimatedMinutesLeft: Int {
//        let freeMB = getFreeDiskSpaceInMB()
//        let mbPerMinute = 100.0  // adjust as needed
//        return Int(freeMB / mbPerMinute)
//    }
//
//    
//    var picBtn: some View {
//        VStack(spacing: 20) {
//            Button(action: {
//                isTakingPhoto = true
//                recorder.capturePhoto(withAudio: isMicEnabled)
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                        isTakingPhoto = false
//                    }
//            }) {
//                Image(systemName: "camera.circle.fill")
//                    .resizable()
//                    .frame(width: isTakingPhoto ? 90 : 100, height: isTakingPhoto ? 90 : 100)
//                    .foregroundColor(.yellow)
//                    .shadow(radius: 6)
//                    .animation(.easeOut(duration: 0.1), value: isTakingPhoto)
//            }
//            .accessibilityLabel("Take Photo")
//
//            Toggle(isOn: $isMicEnabled) {
//                Text("Audio Clip")
//                    .foregroundColor(.primary)
//                    .font(.caption)
//            }
//            .toggleStyle(SwitchToggleStyle(tint: .red))
//            .frame(width: 120)
//        }
//    }
//
//
//    
//    var statusBtns: some View {
//        VStack(spacing: 10) {
//            
//            Button(action: {
//                if recorder.isRecording {
//                    recorder.stopRecording()
//                    gpsLogger.stopLogging()
//                    stopTimer()
//                } else {
//                    recorder.startRecording()
//                    gpsLogger.startLogging()
//                    startTimer()
//                }
//            }) {
//                Text(recorder.isRecording ? "Stop" : "Start")
//                    .font(.largeTitle)
//                    .padding()
//                    .background(Color.green)
//                    .foregroundColor(.white)
//                    .clipShape(Capsule())
//            }
//            
//        
//        }
//    }
//    
//    
//    var statusLabel: some View {
//        
//        Text(recorder.isRecording ? elapsedTimeString + " 🕒 \(estimatedMinutesLeft) min left" : "Idle")
//            .font(.title)
//            .frame(maxWidth: .infinity, alignment: .center)
//            .padding(.top, 10)
//    }
//    
//
//    var gpsInfo: some View {
//        VStack {
//            Spacer()
//            HStack(spacing: 20) {
//                if let loc = gpsLogger.lastLocation {
//                    let lat = String(format: "%.3f", loc.coordinate.latitude)
//                    let lon = String(format: "%.3f", loc.coordinate.longitude)
//                    let alt = String(format: "%.1f", loc.altitude)
//                    let speedMph = loc.speed * 2.23694
//
//                    Text("(\(lat), \(lon))")
//                    Text("Alt: \(alt) m")
//                    Text("🕒 \(formattedTime(from: loc.timestamp))")
//                    Text("🚗 \(String(format: "%.2f", speedMph)) mph")
//                } else {
//                    Text("No GPS signal")
//                }
//            }
//            .font(.system(size: 16, weight: .medium, design: .monospaced))
//            .padding(.vertical, 12)
//            .frame(maxWidth: .infinity)
//            .background(Color.black.opacity(0.08))
//        }
//    }
//
//    
//    func formattedTime(from date: Date) -> String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "HH:mm:ss"
//        return formatter.string(from: date)
//    }
//    
//    func setMicEnabled(_ enabled: Bool) {
//        // You could disable the audio input connection here
//    }
//
//   
//    
//    func startTimer() {
//        recordingStartTime = Date()
//        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
//            if let start = recordingStartTime {
//                let interval = Int(Date().timeIntervalSince(start))
//                let hours = interval / 3600
//                let minutes = (interval % 3600) / 60
//                let seconds = interval % 60
//                elapsedTimeString = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
//            }
//        }
//    }
//    
//    func stopTimer() {
//        recordingTimer?.invalidate()
//        recordingTimer = nil
//        recordingStartTime = nil
//        elapsedTimeString = "00:00:00"
//    }
//
//
//
//
//}
//

import SwiftUI

struct ContentView: View {
    @StateObject private var gpsLogger = GPSLogger()
    @StateObject private var recorder = VideoRecorder(gpsLogger: GPSLogger())
    @StateObject private var orientationObserver = OrientationObserver()
    
    @State private var recordingStartTime: Date?
    @State private var timer: Timer?
    @State private var elapsedTimeString: String = "00:00:00"
    @State private var isMenuOpen: Bool = false
    @State private var isMicEnabled: Bool = false
    @State private var isTakingPhoto = false
    
    init() {
        let logger = GPSLogger()
        _gpsLogger = StateObject(wrappedValue: logger)
        _recorder = StateObject(wrappedValue: VideoRecorder(gpsLogger: logger))
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Main background
                    Color(.systemGray6)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // Top status bar
                        topStatusBar
                        
                        // Main content area
                        HStack(spacing: 1) {
                            // Left side - Video preview
                            videoPreviewSection
                                .frame(maxWidth: geometry.size.width * 0.6)
                            
                            // Right side - Controls
                            controlsSection
                                .frame(maxWidth: geometry.size.width * 0.25)
                            HStack(spacing: 0) {
                              
                            }
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 4)
                        
                       
                      
                        
                        // Bottom GPS info bar
                        bottomGPSBar
                    }
                    
                   
                }
            }
        }
        .sheet(isPresented: $isMenuOpen) {
            MediaGridView()
        }
        .onAppear {
            OrientationLock.lockToLandscape()
        }
    }
    
    // MARK: - Top Status Bar
    var topStatusBar: some View {
        HStack {
            // GPS/Recording status indicator
            statusIndicator
            
            Spacer()
            
            // Recording timer (centered)
            recordingTimer
            
            Spacer()
            
            countdownTimer
            
            Spacer()
            
            // Hamburger menu button
            menuButton
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(Color.white.opacity(0.95))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
    }
    
    var statusIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill((gpsLogger.lastLocation != nil && recorder.isRecording) ? Color.green : Color.yellow)
                .frame(width: 16, height: 16)
                .shadow(radius: 2)
            
            Text("GPS & Video")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.08))
        .cornerRadius(20)
    }
    
    var recordingTimer: some View {
        Text(recorder.isRecording ? elapsedTimeString : "Ready")
            .font(.system(size: 24, weight: .bold, design: .monospaced))
            .foregroundColor(.red)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(radius: 2)
    }
    
    var countdownTimer: some View {
        Text("~\(estimatedMinutesLeft) min remaining")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.red)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
          
    }
    
    var menuButton: some View {
        //        Button(action: {
        //            isMenuOpen.toggle()
        //        }) {
        //            Image(systemName: "line.3.horizontal")
        //                .font(.system(size: 20, weight: .medium))
        //                .foregroundColor(.primary)
        //                .frame(width: 44, height: 44)
        //                .background(Color.white)
        //                .cornerRadius(12)
        //                .shadow(radius: 2)
        //        }
        //    }
        Button(action: {
            isMenuOpen.toggle()
        }) {
            Image(systemName: "line.horizontal.3")
                .resizable()
                .frame(width: 30, height: 20)
                .padding()
        }
    }
    
    // MARK: - Video Preview Section
    var videoPreviewSection: some View {
        VStack(spacing: 0) {
        
            
            // Video preview
            VideoPreviewView(session: recorder.session, orientationObserver: orientationObserver)
                .aspectRatio(16/9, contentMode: .fit)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                )
            
 
           
           
            
        }
    }
    
    // MARK: - Controls Section
    var controlsSection: some View {
        VStack(spacing: 2) {
            Spacer()
            
            // Record button
            recordButton
            
            Spacer()
            
            // Photo button and mic toggle
            photoControlsSection
            
            Spacer()
        }
    }
    
    var recordButton: some View {
        Button(action: {
            if recorder.isRecording {
                recorder.stopRecording()
                gpsLogger.stopLogging()
                stopTimer()
            } else {
                recorder.startRecording()
                gpsLogger.startLogging()
                startTimer()
            }
        }) {
            VStack(spacing: 8) {
                Image(systemName: recorder.isRecording ? "stop.circle.fill" : "record.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(recorder.isRecording ? .red : .green)
                
                Text(recorder.isRecording ? "STOP" : "START")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(recorder.isRecording ? .red : .green)
            }
        }
        .frame(width: 120, height: 120)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .scaleEffect(recorder.isRecording ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: recorder.isRecording)
    }
    
    var photoControlsSection: some View {
        VStack(spacing: 3) {
            HStack(spacing: 2){
                // Photo capture button
                Button(action: {
                    isTakingPhoto = true
                    recorder.capturePhoto(withAudio: isMicEnabled)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        isTakingPhoto = false
                    }
                }) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.blue)
                                .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                        )
                        .scaleEffect(isTakingPhoto ? 0.9 : 1.0)
                        .animation(.easeOut(duration: 0.15), value: isTakingPhoto)
                }
                .accessibilityLabel("Take Photo")
                
                // Overlay countdown display
                if recorder.micCountdown > 0 {
                    countdownOverlay
                }
            }
            
            // Mic toggle
            VStack(spacing: 8) {
                Toggle(isOn: $isMicEnabled) {
                    if isMicEnabled {
                        Text("🎤 Enabled")
                            .font(.caption)
                            .foregroundColor(.green)
                    }else{
                        
                    
                    Text("🎤 Diabled")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                }
                }
                .toggleStyle(SwitchToggleStyle(tint: .green))
                
               
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(radius: 2)
        }
    }
    
    // MARK: - Bottom GPS Bar
    var bottomGPSBar: some View {
        HStack(spacing: 0) {
            if let loc = gpsLogger.lastLocation {
                let lat = String(format: "%.3f", loc.coordinate.latitude)
                let lon = String(format: "%.3f", loc.coordinate.longitude)
                let alt = String(format: "%.1f", loc.altitude)
                let speedMph = loc.speed * 2.23694
                
                // Coordinates
                Text("(\(lat), \(lon))")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                
                Spacer()
                
                // Altitude
                HStack(spacing: 4) {
                    Image(systemName: "mountain.2.fill")
                        .font(.caption)
                    Text("\(alt)m")
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                }
                
                Spacer()
                
                // Speed
                HStack(spacing: 4) {
                    Image(systemName: "speedometer")
                        .font(.caption)
                    Text("\(String(format: "%.1f", speedMph)) mph")
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                }
                
                Spacer()
                
                // Time
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                    Text(formattedTime(from: loc.timestamp))
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                }
            } else {
                HStack {
                    Image(systemName: "location.slash")
                        .foregroundColor(.red)
                    Text("No GPS Signal")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
        .foregroundColor(.red)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.95), Color.white.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: -2)
    }
    

    
// MARK: - Countdown Circle
   var countdownOverlay: some View {
       VStack(spacing: 2) {
           ZStack {
               Circle()
                   .stroke(Color.red.opacity(0.3), lineWidth: 4)
                   .frame(width: 60, height: 60)
               
               Circle()
                   .trim(from: 0, to: CGFloat(10 - recorder.micCountdown) / 10.0)
                   .stroke(Color.red, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                   .frame(width: 60, height: 60)
                   .rotationEffect(.degrees(-90))
                   .animation(.linear(duration: 1), value: recorder.micCountdown)
               
               Text("\(recorder.micCountdown)")
                   .font(.system(size: 28, weight: .bold, design: .rounded))
                   .foregroundColor(.red)
           }
           
           Text("🎤 Recording")
               .font(.system(size: 12, weight: .medium))
               .foregroundColor(.red)
       }
       .padding(6)
       .background(Color.white)
       .cornerRadius(16)
       .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
   }
    
    // MARK: - Computed Properties
    var estimatedMinutesLeft: Int {
        let freeMB = getFreeDiskSpaceInMB()
        let mbPerMinute = 100.0
        return Int(freeMB / mbPerMinute)
    }
    
    // MARK: - Helper Functions
    func formattedTime(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    func startTimer() {
        recordingStartTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let start = recordingStartTime {
                let interval = Int(Date().timeIntervalSince(start))
                let hours = interval / 3600
                let minutes = (interval % 3600) / 60
                let seconds = interval % 60
                elapsedTimeString = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            }
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        recordingStartTime = nil
        elapsedTimeString = "00:00:00"
    }
}
