import SwiftUI
import CoreLocation

@main
struct VideoGPSRecorderApp: App {
    @StateObject private var services = AppServices()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(services)
        }
    }
}

