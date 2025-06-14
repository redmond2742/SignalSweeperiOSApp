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
    @State private var use60FPS = false
    @State private var useUltraWideCamera = false

    
    init() {
        let logger = GPSLogger()
        _gpsLogger = StateObject(wrappedValue: logger)
        _recorder = StateObject(wrappedValue: VideoRecorder(gpsLogger: logger))
    }
    
    var body: some View {
        if #available(iOS 16.0, *) {
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
        } else {
            // Fallback on earlier versions
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
            wideAngleToggle
            
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
        Text("\(estimatedMinutesLeft) min available")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.red)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
          
    }
    
    var menuButton: some View {
   
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
            fpsToggle
            
            
            
            // Photo button and mic toggle
            photoControlsSection
            
          
        }
    }
    
    var fpsToggle: some View {
        Toggle(isOn: $use60FPS) {
            Text(use60FPS ? "60 FPS" : "30 FPS")
                .foregroundColor(.primary)
                .font(.caption)
        }
        .toggleStyle(SwitchToggleStyle(tint: .blue))
        .frame(width: 120)
        .disabled(recorder.isRecording) // prevent change while recording

    }
    
    var wideAngleToggle: some View {
        Toggle(isOn: $useUltraWideCamera) {
            Text(useUltraWideCamera ? "Wide" : "Standard")
                .foregroundColor(.black)
                .font(.caption)
        }
        .toggleStyle(SwitchToggleStyle(tint: .blue))
        .frame(width: 160)
        .onChange(of: useUltraWideCamera) {
            recorder.switchCamera(useUltraWide: useUltraWideCamera)
        }


    }
    
    var recordButton: some View {
        Button(action: {
            if recorder.isRecording {
                recorder.stopRecording()
                gpsLogger.stopLogging()
                stopTimer()
            } else {
                recorder.startRecording(use60FPS: use60FPS)
                gpsLogger.startLogging()
                startTimer()
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: recorder.isRecording ? "stop.circle.fill" : "record.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(recorder.isRecording ? .red : .green)
                
                Text(recorder.isRecording ? "STOP" : "START")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(recorder.isRecording ? .red : .green)
            }
        }
        .frame(width: 120, height: 80)
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
                        .frame(width: 120, height: 80)
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
                    Text("Not Recording")
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
