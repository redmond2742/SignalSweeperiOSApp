import SwiftUI

/// Simple onboarding explaining app usage
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TabView {
            page(title: "Welcome to SignalSweeper", systemImage: "camera.fill", text: "Record street sweeper activity with synced video, audio and GPS data.")
            page(title: "Large Controls", systemImage: "hand.tap", text: "Use the big buttons to start recording or take photos even with gloves.")
            page(title: "Share Media", systemImage: "square.and.arrow.up", text: "Preview, share or delete recordings from the media browser.")
        }
        .tabViewStyle(PageTabViewStyle())
        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
        .overlay(alignment: .topTrailing) {
            Button("Done") { dismiss() }
                .padding()
        }
    }

    func page(title: String, systemImage: String, text: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: systemImage)
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.accentColor)
            Text(title)
                .font(.title)
                .fontWeight(.bold)
            Text(text)
                .multilineTextAlignment(.center)
                .padding()
            Spacer()
        }
        .padding()
    }
}

#Preview {
    OnboardingView()
}
