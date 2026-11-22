//
//  ResonanceView.swift
//  Void
//
//  Created by Mora Hakim on 18/11/26.
//

import SwiftUI
import Combine
import UIKit

struct ResonanceView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var audio = ResonanceAudioEngine()
    var onContinue: () -> Void = {}

    private enum Phase {
        case ready
        case listening
        case responding
        case completed
    }

    @State private var phase: Phase = .ready
    @State private var stableSince: Date?
    @State private var lastDetectedSignalAt: Date?
    @State private var lastValidSignalAt: Date?
    @State private var hintLevel = 0
    @State private var searchStartedAt: Date?
    @State private var hintAvailable = false
    @State private var isWithinTargetZone = false
    @State private var outOfRangeSince: Date?

    private let targetFrequency = 146.83
    private let enterTolerance = 0.08
    private let exitTolerance = 0.12
    private let requiredDuration = 1.5
    private let gracePeriod = 0.4

    private let timer = Timer.publish(
        every: 0.1,
        on: .main,
        in: .common
    ).autoconnect()
    
    private let hints = [
        "Two notes. One space between them.",
        "The missing note is equally distant from both.",
        "Find the middle in pitch, not in frequency."
    ]
    
    private let maxOctaveShift = 3

    /// Folds the detected pitch down by whole octaves, so the same note
    /// hummed higher (most women's and children's voices) still matches.
    /// Folding keeps the error as a percentage, so `tolerance` stays just as strict.
    
    private var normalizedFrequency: Double {
        let frequency = audio.detectedFrequency

        guard frequency > 0 else { return 0 }

        // Only fold frequencies that are already close
        // to an exact octave equivalent of the target.
        for octaveShift in -maxOctaveShift...maxOctaveShift {
            let candidate = frequency / pow(
                2.0,
                Double(octaveShift)
            )

            let difference = abs(candidate - targetFrequency)

            if difference <= targetFrequency * exitTolerance {
                return candidate
            }
        }

        // Keep the original frequency for correct LOW/HIGH feedback.
        return frequency
    }

    private var isFrequencyMatched: Bool {
        isWithinTargetZone
    }
    
    private var pitchDeviation: Double {
        guard normalizedFrequency > 0 else { return 0 }

        return log2(normalizedFrequency / targetFrequency)
    }
    
    
    private var pitchFeedbackText: String {
        guard audio.inputLevel > 0.01,
              normalizedFrequency > 0 else {
            return "LISTENING"
        }

        if isFrequencyMatched {
            return "IN TUNE"
        }

        return pitchDeviation < 0
            ? "TOO LOW"
            : "TOO HIGH"
    }

    private var pitchInstructionText: String {
        guard audio.inputLevel > 0.01,
              normalizedFrequency > 0 else {
            return "HUM TO FIND THE MISSING NOTE"
        }

        if isFrequencyMatched {
            return "HOLD THIS NOTE"
        }

        return pitchDeviation < 0
            ? "RAISE YOUR PITCH"
            : "LOWER YOUR PITCH"
    }


    private var frequencyProgress: Double {
        guard normalizedFrequency > 0,
              audio.inputLevel > 0.01 else {
            return 0
        }

        let difference = abs(normalizedFrequency - targetFrequency)
        let discoveryRange = targetFrequency * 0.5

        return max(0, 1 - difference / discoveryRange)
    }

    private var resonanceIntensity: Double {
        switch phase {
        case .responding:
            return frequencyProgress
        case .completed:
            // Hold the visualizer at full strength once solved
            // instead of collapsing back to idle.
            return 1
        case .ready, .listening:
            return 0
        }
    }

    var body: some View {
        ZStack {
            VoidTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                PuzzleHeader(number: 2) {
                    audio.stop()
                    dismiss()
                }

                PuzzleTitle(
                    title: "RESONANCE",
                    subtitle: "LISTEN BEFORE YOU SPEAK."
                )
                .padding(.top, VoidMetrics.titleTopSpacing)

                Spacer(minLength: 16)

                visualizer

                Spacer(minLength: 16)

                statusSection

                Spacer(minLength: 24)

                actionSection
            }
            .voidScreen()
        }
        .onChange(of: audio.isRunning) { _, running in
            guard running, phase == .ready else { return }

            phase = .listening
            playReferenceSequence()
        }
        .onReceive(timer) { _ in
            evaluateSignal()
            checkResonanceDuration()

            if phase == .responding,
               let searchStartedAt,
               Date().timeIntervalSince(searchStartedAt) >= 25 {
                hintAvailable = true
            }
        }
        .onDisappear {
            audio.stop()
        }
    }
    
    private func playReferenceSequence() {
        audio.playReferenceSequence {
            guard phase == .listening else { return }

            phase = .responding
        }
    }
    
    
    @MainActor
    private func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    
    /// The latest hint, shown in place of the instruction while humming.
    private var revealedHint: String? {
        guard phase == .responding || phase == .listening,
              hintLevel > 0 else { return nil }
        return hints[hintLevel - 1]
    }

    // MARK: - Sections
    private var visualizer: some View {
        let isCompleted = phase == .completed

        let hasSignal = audio.detectedFrequency > 0 &&
            audio.inputLevel > 0.01

        let deviation = pitchDeviation
        let isMatched = isFrequencyMatched

        let indicatorPosition = isMatched
            ? 0
            : min(max(deviation / 0.5, -1), 1)

        let indicatorColor = isMatched
            ? VoidColor.success
            : VoidTheme.accent

        return VStack(spacing: 28) {
            ZStack {
                if isCompleted {
                    // Final locked state
                    Circle()
                        .stroke(
                            VoidColor.success.opacity(0.25),
                            lineWidth: 1
                        )
                        .frame(width: 58, height: 58)

                    Circle()
                        .fill(VoidColor.success)
                        .frame(width: 12, height: 12)

                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VoidColor.success)
                        .offset(y: 42)
                } else {
                    ForEach(-4...4, id: \.self) { index in
                        Capsule()
                            .fill(
                                index == 0
                                    ? VoidTheme.primary
                                    : VoidTheme.secondary.opacity(0.35)
                            )
                            .frame(
                                width: index == 0 ? 2 : 1,
                                height: index == 0 ? 34 : 12
                            )
                            .offset(x: CGFloat(index) * 28)
                    }

                    Circle()
                        .fill(indicatorColor)
                        .frame(width: 12, height: 12)
                        .shadow(
                            color: indicatorColor.opacity(0.3),
                            radius: 6
                        )
                        .offset(
                            x: hasSignal
                                ? CGFloat(indicatorPosition) * 112
                                : 0
                        )
                        .animation(
                            reduceMotion ? nil : .easeOut(duration: 0.15),
                            value: indicatorPosition
                        )
                }
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity)

            
            VStack(spacing: 6) {
                if isCompleted {
                    Text("YOU FOUND THE SPACE BETWEEN.")
                        .voidText(.label)
                        .foregroundStyle(VoidTheme.secondary)
                } else {
                    Text(pitchFeedbackText)
                        .voidText(.status)
                        .foregroundStyle(
                            isMatched
                                ? VoidColor.success
                                : VoidTheme.primary
                        )

                    Text(pitchInstructionText)
                        .voidText(.label)
                        .foregroundStyle(VoidTheme.secondary)
                }
            }
            .multilineTextAlignment(.center)
        }
        .frame(height: 280)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pitch indicator")
        .accessibilityValue(
            isCompleted ? "Resonance found" : pitchFeedbackText
        )
    }



   
    private var statusSection: some View {
        VStack(spacing: 8) {
            if let error = audio.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(VoidColor.error)

            } else if let revealedHint {
                Text(revealedHint)
                    .voidText(.body)
                    .foregroundStyle(.white)
                    .id(hintLevel)
                    .transition(.opacity)
                    .accessibilityLabel(
                        "Hint \(hintLevel) of \(hints.count). \(revealedHint)"
                    )

            } else if phase == .ready || phase == .completed {
                Text(statusText)
                    .voidText(.status)
                    .foregroundStyle(
                        phase == .completed
                            ? VoidColor.success
                            : VoidTheme.secondary
                    )

                if let instructionText {
                    Text(instructionText)
                        .voidText(.label)
                        .foregroundStyle(VoidTheme.secondary)
                }
            }
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }


    /// Reserves the button's height in every phase so the layout never jumps.
    /// Reserves the button's height in every phase so the layout never jumps.
    
    private var actionSection: some View {
        ZStack {
            switch phase {
            case .ready:
                Button("BEGIN") {
                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                    generator.prepare()
                    generator.impactOccurred()

                    audio.requestPermissionAndStart()
                }
                .buttonStyle(VoidPrimaryButtonStyle())

            case .completed:
                Button("CONTINUE") {
                    audio.stop()
                    onContinue()
                }
                .buttonStyle(VoidPrimaryButtonStyle())

            case .listening, .responding:
                HStack(spacing: 8) {
                    if hintAvailable && hintLevel < hints.count {
                        PuzzleHintButton(
                            level: $hintLevel,
                            count: hints.count
                        )
                    }

                    Button("REPLAY") {
                        replayReferenceTone()
                        impact(.heavy)
                    }
                    .buttonStyle(VoidSecondaryButtonStyle())
                    .disabled(
                        phase == .listening || audio.isPlayingReference
                    )
                }
            }
        }
        .frame(height: VoidMetrics.primaryButtonHeight)
        .animation(.easeInOut(duration: 0.3), value: hintAvailable)
        .animation(.easeInOut(duration: 0.3), value: hintLevel)
    }


    // MARK: - Status

    private var statusText: String {
        switch phase {
        case .ready:
            return "WAITING"
        case .listening:
            return "LISTEN"
        case .responding:
            return isFrequencyMatched
                ? "SIGNAL FOUND"
                : "SEARCHING"
        case .completed:
            return "RESONANCE FOUND"
        }
    }

    private var instructionText: String? {
        switch phase {
        case .ready:
            // HIG: explain why before the system permission prompt appears.
            return "THIS PUZZLE USES THE MICROPHONE"
        case .responding:
            return "HUM TO MATCH THE FREQUENCY"
        case .listening, .completed:
            return nil
        }
    }
    
    // MARK: - Signal Detection

    private func evaluateSignal() {
        guard phase == .responding else { return }

        let now = Date()

        if searchStartedAt == nil {
            searchStartedAt = now
        }

        let hasSignal = audio.detectedFrequency > 0 &&
            audio.inputLevel > 0.01

        let difference = normalizedFrequency > 0
            ? abs(normalizedFrequency - targetFrequency) / targetFrequency
            : Double.infinity

        if !isWithinTargetZone {
            // Masuk zona target: haptic hanya sekali.
            if hasSignal && difference <= enterTolerance {
                isWithinTargetZone = true
                outOfRangeSince = nil

                Task { @MainActor in
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
        } else {
            // Sudah di zona: toleransi lebih longgar.
            if hasSignal && difference <= exitTolerance {
                outOfRangeSince = nil
            } else {
                if outOfRangeSince == nil {
                    outOfRangeSince = now
                }

                if let outOfRangeSince,
                   now.timeIntervalSince(outOfRangeSince) > gracePeriod {
                    isWithinTargetZone = false
                    self.outOfRangeSince = nil
                    stableSince = nil
                    lastValidSignalAt = nil
                }
            }
        }

        if isWithinTargetZone {
            if stableSince == nil {
                stableSince = now
            }

            lastValidSignalAt = now
        } else {
            stableSince = nil
            lastValidSignalAt = nil
        }
    }


    // MARK: - Completion

    private func checkResonanceDuration() {
        guard phase == .responding,
              isWithinTargetZone,
              let stableSince else {
            return
        }

        let now = Date()

        if now.timeIntervalSince(stableSince) >= requiredDuration {
            isWithinTargetZone = false
            phase = .completed

            Task { @MainActor in
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            PuzzleProgress.markDiscovered(2)
        }
    }
    
    private func replayReferenceTone() {
        guard phase == .responding else { return }

        stableSince = nil
        lastValidSignalAt = nil
        isWithinTargetZone = false
        outOfRangeSince = nil
        phase = .listening
        playReferenceSequence()
    }
}


