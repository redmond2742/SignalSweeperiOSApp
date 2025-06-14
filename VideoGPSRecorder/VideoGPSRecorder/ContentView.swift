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
                        // Modern gradient background
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.95),
                                Color.black.opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .ignoresSafeArea()
                        
                        VStack(spacing: 0) {
                            // Top status bar with modern glass morphism
                            topStatusBar
                            
                            // Main content area with improved spacing
                            HStack(spacing: 4) {
                                // Left side - Video preview (70% width)
                                videoPreviewSection
                                    .frame(maxWidth: geometry.size.width * 0.70)
                                
                                // Right side - Controls (25% width)
                                controlsSection
                                    .frame(maxWidth: geometry.size.width * 0.25)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            
                            // Bottom GPS info bar with compact styling
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
        HStack(spacing: 8) {
            // GPS/Recording status indicator
            VStack(spacing: 2) {
                statusIndicator
                storageIndicator
            }
            
            Spacer()
            
            // Recording timer (centered)
            recordingTimer
            
            Spacer()
            
            // Right side controls
            VStack(spacing: 4) {
                // Camera and FPS toggles
                HStack(spacing: 6) {
                    wideAngleToggle
                    fpsToggle
                }
            }
            
            // Menu button
            menuButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            // Glass morphism effect
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            }
        )
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }
    
    var statusIndicator: some View {
        HStack(spacing: 8) {
            // Animated recording indicator
            ZStack {
                Circle()
                    .fill(gpsLogger.lastLocation != nil && recorder.isRecording ?
                          Color.red : Color.orange)
                    .frame(width: 10, height: 10)
                
                if recorder.isRecording {
                    Circle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 16, height: 16)
                        .scaleEffect(recorder.isRecording ? 1.5 : 1.0)
                        .opacity(recorder.isRecording ? 0.0 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false),
                                 value: recorder.isRecording)
                }
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text("GPS & Video")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(gpsLogger.lastLocation != nil ? "Connected" : "Searching...")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.3))
        )
    }
    
    var recordingTimer: some View {
        VStack(spacing: 2) {
            Text(recorder.isRecording ? "REC" : "READY")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(recorder.isRecording ? .red : .white.opacity(0.7))
            
            Text(recorder.isRecording ? elapsedTimeString : "00:00:00")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .contentTransition(.numericText(countsDown: false))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(recorder.isRecording ?
                      Color.red.opacity(0.2) : Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(recorder.isRecording ? Color.red : Color.white.opacity(0.3),
                               lineWidth: 2)
                )
        )
    }
    
    var storageIndicator: some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: "internaldrive")
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.7))
                
                Text("\(estimatedMinutesLeft) min")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Text("available")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    var wideAngleToggle: some View {
        VStack(spacing: 3) {
            Image(systemName: useUltraWideCamera ? "camera.aperture" : "camera")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
            
            Text(useUltraWideCamera ? "Wide" : "Std")
                .font(.system(size: 7, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(width: 44, height: 32)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(useUltraWideCamera ? Color.blue.opacity(0.3) : Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(useUltraWideCamera ? Color.blue : Color.white.opacity(0.3),
                               lineWidth: 1)
                )
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                useUltraWideCamera.toggle()
                recorder.switchCamera(useUltraWide: useUltraWideCamera)
            }
        }
    }
    
    var fpsToggle: some View {
        HStack(spacing: 0) {
            // 30 FPS option
            Text("30")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(use60FPS ? .white.opacity(0.6) : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(use60FPS ? Color.clear : Color.blue)
                )
                .onTapGesture {
                    if !recorder.isRecording {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            use60FPS = false
                        }
                    }
                }
            
            // 60 FPS option
            Text("60")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(use60FPS ? .white : .white.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(use60FPS ? Color.blue : Color.clear)
                )
                .onTapGesture {
                    if !recorder.isRecording {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            use60FPS = true
                        }
                    }
                }
        }
        .frame(width: 44, height: 32)
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        )
        .opacity(recorder.isRecording ? 0.5 : 1.0)
        .overlay(
            VStack {
                Text("FPS")
                    .font(.system(size: 6, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
            }
            .padding(.top, -16)
        )
    }
    
    var menuButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isMenuOpen.toggle()
            }
        }) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .scaleEffect(isMenuOpen ? 0.9 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isMenuOpen)
    }
    
    // MARK: - Video Preview Section
    var videoPreviewSection: some View {
        VStack(spacing: 1) {
            // Video preview with modern styling
            VideoPreviewView(session: recorder.session, orientationObserver: orientationObserver)
                .aspectRatio(16/9, contentMode: .fit)
                .background(Color.black)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.3), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: .black.opacity(0.5), radius: 15, x: 0, y: 8)
                .overlay(
                    // Recording indicator overlay
                    recorder.isRecording ?
                    VStack {
                        HStack {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 6, height: 6)
                                    .opacity(recorder.isRecording ? 1.0 : 0.0)
                                    .animation(.easeInOut(duration: 1.0).repeatForever(),
                                             value: recorder.isRecording)
                                
                                Text("REC")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.7))
                            )
                            
                            Spacer()
                        }
                        .padding(12)
                        
                        Spacer()
                    } : nil
                )
        }
    }
    
    // MARK: - Controls Section
    var controlsSection: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // Main record button
            recordButton
            
            // Photo and mic controls
            photoControlsSection
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    var recordButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                if recorder.isRecording {
                    recorder.stopRecording()
                    gpsLogger.stopLogging()
                    stopTimer()
                } else {
                    recorder.startRecording(use60FPS: use60FPS)
                    gpsLogger.startLogging()
                    startTimer()
                }
            }
        }) {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(recorder.isRecording ? Color.red : Color.red.opacity(0.3),
                           lineWidth: 3)
                    .frame(width: 70, height: 70)
                
                // Inner button
                RoundedRectangle(cornerRadius: recorder.isRecording ? 6 : 35)
                    .fill(Color.red)
                    .frame(width: recorder.isRecording ? 24 : 50,
                           height: recorder.isRecording ? 24 : 50)
                    .animation(.easeInOut(duration: 0.2), value: recorder.isRecording)
            }
            .background(
                Circle()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 76, height: 76)
            )
        }
        .scaleEffect(recorder.isRecording ? 0.95 : 1.0)
        .shadow(color: .red.opacity(0.3), radius: recorder.isRecording ? 8 : 0)
    }
    
    var photoControlsSection: some View {
        HStack(spacing: 6) {
            // Photo capture button
            Button(action: {
                withAnimation(.easeOut(duration: 0.15)) {
                    isTakingPhoto = true
                }
                recorder.capturePhoto(withAudio: isMicEnabled)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        isTakingPhoto = false
                    }
                }
            }) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue, Color.blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .scaleEffect(isTakingPhoto ? 0.85 : 1.0)
                    .shadow(color: .blue.opacity(0.3), radius: 6, x: 0, y: 3)
            }
            .accessibilityLabel("Take Photo")
            
            if recorder.micCountdown > 0 {
                countdownOverlay
            }
            
            // Mic toggle with compact styling
            micToggle
        }
    }
    
    var micToggle: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: isMicEnabled ? "mic.fill" : "mic.slash.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isMicEnabled ? .green : .red)
                
                Text(isMicEnabled ? "ON" : "OFF")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(isMicEnabled ? .green : .red)
            }
            .frame(width: 60, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isMicEnabled ? Color.green : Color.red, lineWidth: 1)
                    )
            )
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isMicEnabled.toggle()
                }
            }
            
            Text("Audio")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    // MARK: - Bottom GPS Bar
    var bottomGPSBar: some View {
        HStack(spacing: 12) {
            if let loc = gpsLogger.lastLocation {
                let lat = String(format: "%.3f", loc.coordinate.latitude)
                let lon = String(format: "%.3f", loc.coordinate.longitude)
                let alt = String(format: "%.1f", loc.altitude)
                let speedMph = loc.speed * 2.23694
                
                // Coordinates
                HStack(spacing: 3) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                    
                    Text("(\(lat), \(lon))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Altitude
                HStack(spacing: 3) {
                    Image(systemName: "mountain.2.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    
                    Text("\(alt)m")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                // Speed
                HStack(spacing: 3) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    
                    Text("\(String(format: "%.1f", speedMph)) mph")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                // Distance (when recording)
                if recorder.isRecording {
                    HStack(spacing: 3) {
                        Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                            .font(.system(size: 10))
                            .foregroundColor(.purple)
                        
                        Text("\(String(format: "%.2f", gpsLogger.totalDistance * 0.000621371)) mi")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
                
                // Time
                HStack(spacing: 3) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.cyan)
                    
                    Text(formattedTime(from: loc.timestamp))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "location.slash")
                        .foregroundColor(.red)
                        .font(.system(size: 12))
                    
                    Text("GPS Not Available")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            .ultraThinMaterial
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.white.opacity(0.2)),
            alignment: .top
        )
    }
    
    // MARK: - Countdown Circle
    var countdownOverlay: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.red.opacity(0.3), lineWidth: 2)
                    .frame(width: 40, height: 40)
                
                Circle()
                    .trim(from: 0, to: CGFloat(10 - recorder.micCountdown) / 10.0)
                    .stroke(Color.red, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: recorder.micCountdown)
                
                Text("\(recorder.micCountdown)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.red)
            }
            
            Text("🎤 Recording")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.red)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .red.opacity(0.2), radius: 6, x: 0, y: 3)
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
