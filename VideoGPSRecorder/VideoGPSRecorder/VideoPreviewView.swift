//
//  VideoPreviewView.swift
//  VideoGPSRecorder
//
//  Created by Matt on 6/3/25.
//


import SwiftUI
import AVFoundation
import CoreLocation

struct VideoPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    @ObservedObject var orientationObserver: OrientationObserver

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        let transform: CGAffineTransform

        switch orientationObserver.orientation {
        case .landscapeLeft:
            transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 2)
        case .landscapeRight:
            transform = CGAffineTransform(rotationAngle: CGFloat.pi / 2)
        case .portraitUpsideDown:
            transform = CGAffineTransform(rotationAngle: CGFloat.pi)
        default: // portrait or unknown
            transform = .identity
        }

        uiView.transform = transform
        uiView.setNeedsLayout()
    }
}

class PreviewUIView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}


class OrientationObserver: ObservableObject {
    @Published var orientation: UIDeviceOrientation = UIDevice.current.orientation

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didChangeOrientation),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    @objc private func didChangeOrientation() {
            let newOrientation = UIDevice.current.orientation
            // Avoid unknown or flat orientations
            if newOrientation.isPortrait || newOrientation.isLandscape {
                self.orientation = newOrientation
            }
        }}



//struct VideoPreviewView: UIViewRepresentable {
//    let session: AVCaptureSession
//
//    func makeUIView(context: Context) -> UIView {
//        let view = UIView(frame: .zero)
//        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
//        previewLayer.videoGravity = .resizeAspectFill
//
//        // ✅ Force landscape orientation regardless of device orientation
//        if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported {
//            connection.videoRotationAngle = .landscapeRight  // or .landscapeLeft
//        }
//
//        view.layer.addSublayer(previewLayer)
//        previewLayer.frame = view.bounds
//        previewLayer.masksToBounds = true
//
//        return view
//    }
//
//    func updateUIView(_ uiView: UIView, context: Context) {
//        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
//            previewLayer.frame = uiView.bounds
//        }
//    }
//}
