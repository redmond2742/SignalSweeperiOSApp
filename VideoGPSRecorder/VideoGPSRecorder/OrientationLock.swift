//
//  OrientationLock.swift
//  VideoGPSRecorder
//
//  Created by Matt on 6/8/25.
//

import UIKit

struct OrientationLock {
    static func lockToLandscape() {
        let orientationValue = UIInterfaceOrientation.landscapeRight.rawValue
        UIDevice.current.setValue(orientationValue, forKey: "orientation")

        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight)) { (error: Error?) in
                if let error = error {
                    print("Failed to update geometry: \(error.localizedDescription)")
                }
            }
        }
    }
}
