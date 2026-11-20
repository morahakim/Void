//
//  MotionManager.swift
//  Void
//
//  Created by Mora Hakim on 17/11/26.
//

import Foundation
import CoreMotion

final class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()

    @Published var x: Double = 0
    @Published var y: Double = 0
    @Published var z: Double = 0

    func startUpdates() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device Motion unavailable")
            return
        }

        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0

        motionManager.startDeviceMotionUpdates(to: .main) {
            [weak self] motion, error in

            guard let self else { return }

            if let error {
                print("Motion Error:", error.localizedDescription)
                return
            }

            guard let motion else { return }

            self.x = motion.gravity.x
            self.y = motion.gravity.y
            self.z = motion.gravity.z
        }
    }

    func stopUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
}


