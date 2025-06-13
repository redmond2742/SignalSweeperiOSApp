import SwiftUI

/// Main application view
struct ContentView: View {
    @EnvironmentObject var services: AppServices
    @StateObject private var orientationObserver = OrientationObserver()

    @State private var isMenuOpen = false
    @State private var isMicEnabled = false
    @State private var recordingStartTime: Date?
    @State private var timer: Timer?
    @State private var elapsed = "00:00:00"
    @State private var isTakingPhoto = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false

    private var recorder: VideoRecorder { services.videoRecorder }
    private var logger: GPSLogger { services.gpsLogger }

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                HStack(alignment: .top) {
                    videoPreview
                    controlPanel
                }
                gpsBar
            }
        }
        .sheet(isPresented: $isMenuOpen) { MediaGridView() }
        .fullScreenCover(isPresented: $showOnboarding) { OnboardingView() }
        .onAppear {
            OrientationLock.lockToLandscape()
            showOnboarding = !hasSeenOnboarding
            hasSeenOnboarding = true
            cleanupOld()
        }
    }

    // MARK: - Subviews
    private var topBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: logger.lastLocation != nil ? "location.fill" : "location.slash")
                    .foregroundColor(logger.lastLocation != nil ? .green : .red)
                Circle()
                    .fill(recorder.isRecording ? Color.red : Color.gray)
                    .frame(width: 12, height: 12)
            }
            .padding(8)
            .background(Color.white.opacity(0.8))
            .cornerRadius(8)

            Spacer()

            Text(recorder.isRecording ? elapsed : "Ready")
                .font(.system(.title2, design: .monospaced))
                .foregroundColor(.red)

            Spacer()

            Button(action: { isMenuOpen = true }) {
                Image(systemName: "line.horizontal.3")
                    .font(.title2)
                    .padding()
            }
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }

    private var videoPreview: some View {
        ZStack(alignment: .topTrailing) {
            VideoPreviewView(session: recorder.session, orientationObserver: orientationObserver)
                .aspectRatio(16/9, contentMode: .fit)
                .cornerRadius(12)
                .shadow(radius: 4)

            if recorder.micCountdown > 0 {
                countdownOverlay
                    .padding(8)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var controlPanel: some View {
        VStack(spacing: 20) {
            Button(action: toggleRecording) {
                Image(systemName: recorder.isRecording ? "stop.fill" : "record.circle")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.red)
            }
            .padding(.top)

            Button(action: takePhoto) {
                Image(systemName: "camera.circle.fill")
                    .resizable()
                    .frame(width: isTakingPhoto ? 70 : 80, height: isTakingPhoto ? 70 : 80)
                    .foregroundColor(.yellow)
                    .animation(.easeOut(duration: 0.1), value: isTakingPhoto)
            }

            Toggle("Mic", isOn: $isMicEnabled)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: 180)
    }

    private var gpsBar: some View {
        HStack(spacing: 16) {
            if let loc = logger.lastLocation {
                Text(String(format: "%.3f, %.3f", loc.coordinate.latitude, loc.coordinate.longitude))
                Text("Alt \(Int(loc.altitude))m")
                Text(String(format: "%.1f mph", loc.speed * 2.23694))
            } else {
                Text("No GPS")
                    .foregroundColor(.red)
            }
            Spacer()
        }
        .font(.footnote.monospaced())
        .padding(6)
        .background(Color.white.opacity(0.8))
    }

    private var countdownOverlay: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle().stroke(Color.red.opacity(0.3), lineWidth: 4)
                    .frame(width: 60, height: 60)
                Circle()
                    .trim(from: 0, to: CGFloat(10 - recorder.micCountdown)/10)
                    .stroke(Color.red, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                Text("\(recorder.micCountdown)")
                    .font(.headline)
            }
            ZStack(alignment: .leading) {
                Capsule().fill(Color.gray.opacity(0.2)).frame(width: 60, height: 6)
                Capsule()
                    .fill(Color.red)
                    .frame(width: CGFloat(max(0, min(1, (recorder.audioLevel + 60)/60))) * 60, height: 6)
            }
        }
        .padding(6)
        .background(Color.white)
        .cornerRadius(12)
    }

    // MARK: - Actions
    private func toggleRecording() {
        if recorder.isRecording {
            recorder.stopRecording()
            logger.stopLogging()
            stopTimer()
        } else {
            recorder.startRecording()
            logger.startLogging()
            startTimer()
        }
    }

    private func takePhoto() {
        isTakingPhoto = true
        recorder.capturePhoto(withAudio: isMicEnabled)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isTakingPhoto = false }
    }

    private func startTimer() {
        recordingStartTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            guard let start = recordingStartTime else { return }
            let interval = Int(Date().timeIntervalSince(start))
            let h = interval / 3600
            let m = (interval % 3600) / 60
            let s = interval % 60
            elapsed = String(format: "%02d:%02d:%02d", h, m, s)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        elapsed = "00:00:00"
    }

    private func cleanupOld() {
        FileManager.default.removeFiles(olderThan: 7, in: FileManager.default.temporaryDirectory)
    }
}

#Preview {
    ContentView().environmentObject(AppServices())
}
