//
//  ResonanceAudioEngine.swift
//  Void
//
//  Created by Mora Hakim on 18/11/26.
//

import Foundation
import AVFoundation
import Combine

final class ResonanceAudioEngine: ObservableObject {

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    @Published var detectedFrequency: Double = 0
    @Published var inputLevel: Double = 0
    @Published var isRunning = false
    @Published var errorMessage: String?
    @Published var isPlayingReference = false

    private var tapInstalled = false

    // MARK: - Permission

    func requestPermissionAndStart() {
        AVAudioSession.sharedInstance().requestRecordPermission {
            [weak self] granted in

            DispatchQueue.main.async {
                guard let self else { return }

                guard granted else {
                    self.errorMessage = "Microphone permission denied."
                    return
                }

                self.startEngine()
            }
        }
    }

    // MARK: - Start Engine

    private func startEngine() {
        do {
            let session = AVAudioSession.sharedInstance()

            try session.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.defaultToSpeaker]
            )

            try session.setActive(true)

            let inputNode = engine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)

            engine.attach(player)

            engine.connect(
                player,
                to: engine.mainMixerNode,
                format: nil
            )

            inputNode.installTap(
                onBus: 0,
                bufferSize: 4096,
                format: inputFormat
            ) { [weak self] buffer, _ in

                guard let self,
                      let channelData = buffer.floatChannelData?[0]
                else {
                    return
                }

                let frameCount = Int(buffer.frameLength)

                let result = self.analyzeAudio(
                    samples: channelData,
                    count: frameCount,
                    sampleRate: inputFormat.sampleRate
                )

                DispatchQueue.main.async {
                    self.inputLevel = result.level
                    self.detectedFrequency = result.frequency
                }
            }

            tapInstalled = true

            try engine.start()

            isRunning = true
            errorMessage = nil

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Play Reference Tone
    func playReferenceTone(
        frequency: Double = 220,
        duration: Double = 0.5,
        completion: @escaping () -> Void = {}
    ) {
        guard isRunning else { return }

        let outputFormat = player.outputFormat(forBus: 0)
        let sampleRate = outputFormat.sampleRate
        let channelCount = Int(outputFormat.channelCount)

        guard channelCount > 0 else { return }

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: AVAudioFrameCount(sampleRate * duration)
        ) else {
            return
        }

        let frameCount = Int(sampleRate * duration)
        buffer.frameLength = AVAudioFrameCount(frameCount)

        guard let channelData = buffer.floatChannelData else {
            return
        }

        for channel in 0..<channelCount {
            for frame in 0..<frameCount {
                let time = Double(frame) / sampleRate

                channelData[channel][frame] = Float(
                    0.15 * sin(2 * .pi * frequency * time)
                )
            }
        }


        if player.isPlaying {
            player.stop()
        }

        isPlayingReference = true

        player.scheduleBuffer(
            buffer,
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.isPlayingReference = false
                completion()
            }
        }

        player.play()
    }


    // MARK: - Audio Analysis

    private func analyzeAudio(
        samples: UnsafePointer<Float>,
        count: Int,
        sampleRate: Double
    ) -> (frequency: Double, level: Double) {

        guard count > 1024 else {
            return (0, 0)
        }

        var sum: Double = 0

        for i in 0..<count {
            sum += Double(samples[i])
        }

        let mean = sum / Double(count)

        var energy: Double = 0

        for i in 0..<count {
            let value = Double(samples[i]) - mean
            energy += value * value
        }

        let rms = sqrt(energy / Double(count))

        guard rms > 0.01 else {
            return (0, rms)
        }

        let minLag = Int(sampleRate / 600)
        let maxLag = Int(sampleRate / 80)

        var bestLag = 0
        var bestCorrelation = 0.0

        for lag in minLag...maxLag {
            var correlation: Double = 0
            var energyA: Double = 0
            var energyB: Double = 0

            for i in 0..<(count - lag) {
                let a = Double(samples[i]) - mean
                let b = Double(samples[i + lag]) - mean

                correlation += a * b
                energyA += a * a
                energyB += b * b
            }

            let denominator = sqrt(energyA * energyB)

            guard denominator > 0 else { continue }

            let normalized = correlation / denominator

            if normalized > bestCorrelation {
                bestCorrelation = normalized
                bestLag = lag
            }
        }

        guard bestLag > 0,
              bestCorrelation > 0.6 else {
            return (0, rms)
        }

        let frequency = sampleRate / Double(bestLag)

        return (frequency, rms)
    }

    // MARK: - Stop

    func stop() {
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }

        player.stop()
        engine.stop()

        isRunning = false
        detectedFrequency = 0
        inputLevel = 0

        try? AVAudioSession.sharedInstance().setActive(false)
    }
}

