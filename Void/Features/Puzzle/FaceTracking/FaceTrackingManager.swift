//
//  FaceTrackingManager.swift
//  Void
//
//  Created by Mora Hakim on 20/11/26.
//

import Foundation
import ARKit
import AVFoundation
import Combine

final class FaceTrackingManager: NSObject, ObservableObject, ARSessionDelegate {

    enum Availability {
        case unknown
        case unsupported
        case denied
        case ready
    }

    @Published var availability: Availability = .unknown
    @Published var isRunning = false
    @Published var isFaceDetected = false
    @Published var eyesClosed = false
    @Published var headYaw: Float = 0

    static var isSupported: Bool {
        ARFaceTrackingConfiguration.isSupported
    }

    let closedThreshold: Float = 0.7
    let openThreshold: Float = 0.4

    private let session = ARSession()

    override init() {
        super.init()

        session.delegate = self

        if !Self.isSupported {
            availability = .unsupported
        }
    }

    // MARK: - Authorization

    func requestPermissionAccess() {
        guard Self.isSupported else {
            availability = .unsupported
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            start()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }

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
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
              availability == .denied else {
            return
        }

        start()
    }

    // MARK: - Session

    func start() {
        guard Self.isSupported else {
            availability = .unsupported
            return
        }

        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            availability = .denied
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
        headYaw = 0
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let face = anchors.compactMap({ $0 as? ARFaceAnchor }).first else {
            return
        }

        let tracked = face.isTracked

        let yaw = atan2(
            face.transform.columns.0.z,
            face.transform.columns.0.x
        )

        let left = face.blendShapes[.eyeBlinkLeft]?.floatValue ?? 0
        let right = face.blendShapes[.eyeBlinkRight]?.floatValue ?? 0

        updateOnMain {
            self.isFaceDetected = tracked
            self.headYaw = yaw

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
            self.headYaw = 0
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        updateOnMain {
            self.isRunning = false
            self.isFaceDetected = false
            self.eyesClosed = false

            if (error as? ARError)?.code == .cameraUnauthorized {
                self.availability = .denied
            }
        }
    }

    func sessionWasInterrupted(_ session: ARSession) {
        updateOnMain {
            self.isFaceDetected = false
            self.eyesClosed = false
        }
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        updateOnMain {
            guard self.isRunning,
                  AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
                return
            }

            let configuration = ARFaceTrackingConfiguration()
            configuration.isLightEstimationEnabled = false

            session.run(configuration)
        }
    }

    // MARK: - Helpers

    private func updateOnMain(_ action: @escaping () -> Void) {
        DispatchQueue.main.async {
            action()
        }
    }
}
