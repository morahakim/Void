//
//  FaceTrackingManager.swift
//  Void
//
//  Created by Mora Hakim on 20/11/26.
//

import Foundation
import ARKit

final class FaceTrackingManager: NSObject, ObservableObject, ARSessionDelegate {
    
    enum Availibility {
        case unknown
        case unsupported
        case denied
        case ready
    }
    
    @Published var availability: Availibility = .unknown
    @Published var isRunning = false
    @Published var isFaceDetected = false
    @Published var eyesClosed = false
    
    static var isSupported: Bool {
        ARFaceTrackingConfiguration.isSupported
    }
    
    let closedThreshold: Float = 0.7
    let openThreshold: Float = 0.4
    let session = ARSession()
    
    override init() {
        super.init()
        session.delegate = self
        
        if !Self.isSupported {
            availability = .unsupported
        }
    }
    
    func requestPermissionAccess() {
        guard Self.isSupported else {
            availability = .unsupported
            return
        }
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            start()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                self.updateOnMain {
                    if granted {
                        self.start()
                    } else {
                        self.availability = .denied
                    }
                }
            }
        default:
            availability = .denied
        }
    }
    
    func refreshAuthorization() {
        guard availability == .denied, AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            return
        }
        
        self.start()
    }
    
    func start() {
        guard Self.isSupported else {
            availability = .unsupported
            return
        }

        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = false

        session.run(
            configuration,
            options: [.resetTracking, .removeExistingAnchors]
        )

        availability = .ready
        isRunning = true
    }
    
    func stop() {
        session.pause()
        isRunning = false
        isFaceDetected = false
        eyesClosed = false
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let face = anchors.compactMap({ $0 as? ARFaceAnchor }).first else {
            return
        }

        let tracked = face.isTracked
        let left = face.blendShapes[.eyeBlinkLeft]?.floatValue ?? 0
        let right = face.blendShapes[.eyeBlinkRight]?.floatValue ?? 0

        updateOnMain {
            self.isFaceDetected = tracked

            if min(left, right) > self.closedThreshold {
                self.eyesClosed = true
            } else if min(left, right) < self.openThreshold {
                self.eyesClosed = false
            }
        }
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        guard anchors.contains(where: { $0 is ARFaceAnchor }) else {
            return
        }

        updateOnMain {
            self.isFaceDetected = false
            self.eyesClosed = false
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        updateOnMain {
            self.isRunning = false
            self.isFaceDetected = false

            if (error as? ARError)?.code == .cameraUnauthorized {
                self.availability = .denied
            }
        }
    }
    
    private func updateOnMain(_ action: @escaping () -> Void) {
        DispatchQueue.main.async {
            action()
        }
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        updateOnMain {
            self.isFaceDetected = false
        }
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        updateOnMain {
            guard self.isRunning else { return }

            let configuration = ARFaceTrackingConfiguration()
            configuration.isLightEstimationEnabled = false

            session.run(configuration)
        }
    }
}
