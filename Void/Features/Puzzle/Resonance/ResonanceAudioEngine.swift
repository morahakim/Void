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
    
    private let playbackLock = NSLock()
    private var referencePlaybackActive = false

    private var shouldAnalyzeMicrophone: Bool {
        playbackLock.lock()
        defer { playbackLock.unlock() }
        return !referencePlaybackActive
    }

    private func setReferencePlayback(_ active: Bool) {
        playbackLock.lock()
        referencePlaybackActive = active
        playbackLock.unlock()

        DispatchQueue.main.async {
            self.isPlayingReference = active

            if active {
                self.detectedFrequency = 0
                self.inputLevel = 0
            }
        }
    }

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
                mode: .default,
                options: [.defaultToSpeaker]
            )

            try session.setActive(true)
            try session.overrideOutputAudioPort(.speaker)

            let inputNode = engine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)

            engine.attach(player)
            player.volume = 1.0

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
                      self.shouldAnalyzeMicrophone,
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
                    guard !self.isPlayingReference else { return }

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
                    0.5 * sin(2 * .pi * frequency * time)
                )
            }
        }


        if player.isPlaying {
            player.stop()
        }

        setReferencePlayback(true)

        player.scheduleBuffer(
            buffer,
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.setReferencePlayback(false)
                completion()
            }
        }

        player.play()
    }
    
    func playReferenceSequence(
        completion: @escaping () -> Void = {}
    ) {
        guard isRunning, !isPlayingReference else { return }

        let format = player.outputFormat(forBus: 0)
        let sampleRate = format.sampleRate
        let channelCount = Int(format.channelCount)

        guard channelCount > 0 else { return }

        func makeBuffer(
            frequency: Double?,
            duration: Double
        ) -> AVAudioPCMBuffer? {

            let frameCount = Int(sampleRate * duration)

            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(frameCount)
            ),
            let channels = buffer.floatChannelData else {
                return nil
            }

            buffer.frameLength = AVAudioFrameCount(frameCount)

            for channel in 0..<channelCount {
                for frame in 0..<frameCount {
                    let value: Float

                    if let frequency {
                        let time = Double(frame) / sampleRate
                        value = Float(
                            0.5 * sin(2 * .pi * frequency * time)
                        )
                    } else {
                        value = 0
                    }

                    channels[channel][frame] = value
                }
            }

            return buffer
        }

        guard
            let lowNote = makeBuffer(
                frequency: 110,
                duration: 1.2
            ),
            let silence = makeBuffer(
                frequency: nil,
                duration: 0.6
            ),
            let highNote = makeBuffer(
                frequency: 196,
                duration: 1.2
            )
        else {
            return
        }

        if player.isPlaying {
            player.stop()
        }

        setReferencePlayback(true)

        player.scheduleBuffer(lowNote)
        player.scheduleBuffer(silence)

        player.scheduleBuffer(
            highNote,
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in

            DispatchQueue.main.async {
                guard let self else { return }

                self.setReferencePlayback(false)
                completion()
            }
        }

        player.play()
    }


    // MARK: - Audio Analysia

    private func analyzeAudio(
        samples: UnsafePointer<Float>,
        count: Int,
        sampleRate: Double
    ) -> (frequency: Double, level: Double) {

        guard count > 1024 else {
            return (0, 0)
        }

        // MARK: - RMS

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

        // MARK: - YIN Configuration

        let minFrequency = 55.0
        let maxFrequency = 600.0

        let minLag = max(2, Int(sampleRate / maxFrequency))
        let maxLag = min(
            Int(sampleRate / minFrequency),
            count / 2
        )

        guard minLag < maxLag else {
            return (0, rms)
        }

        // MARK: - Difference Function

        var difference = [Double](
            repeating: 0,
            count: maxLag + 1
        )

        let comparisonCount = count - maxLag

        for lag in minLag...maxLag {
            var sumDifference: Double = 0

            for i in 0..<comparisonCount {
                let a = Double(samples[i]) - mean
                let b = Double(samples[i + lag]) - mean

                let delta = a - b
                sumDifference += delta * delta
            }

            difference[lag] = sumDifference
        }

        // MARK: - Cumulative Mean Normalized Difference

        var normalizedDifference = [Double](
            repeating: 1,
            count: maxLag + 1
        )

        var runningSum: Double = 0

        for lag in 1...maxLag {
            runningSum += difference[lag]

            if runningSum > 0 {
                normalizedDifference[lag] =
                    difference[lag] * Double(lag) / runningSum
            }
        }

        // MARK: - Find Fundamental Period

        let threshold = 0.15
        var selectedLag: Int?

        for lag in minLag..<maxLag {
            if normalizedDifference[lag] < threshold {
                var bestLag = lag

                while bestLag + 1 <= maxLag &&
                        normalizedDifference[bestLag + 1] <
                        normalizedDifference[bestLag] {
                    bestLag += 1
                }

                selectedLag = bestLag
                break
            }
        }

        guard let lag = selectedLag else {
            return (0, rms)
        }

        // MARK: - Parabolic Interpolation

        let previous = Double(
            normalizedDifference[max(minLag, lag - 1)]
        )

        let current = Double(normalizedDifference[lag])

        let next = Double(
            normalizedDifference[min(maxLag, lag + 1)]
        )

        let denominator = previous - 2 * current + next

        var refinedLag = Double(lag)

        if abs(denominator) > 0.000001 {
            refinedLag += 0.5 * (previous - next) / denominator
        }

        guard refinedLag > 0 else {
            return (0, rms)
        }

        let frequency = sampleRate / refinedLag

        guard frequency >= minFrequency,
              frequency <= maxFrequency else {
            return (0, rms)
        }

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

