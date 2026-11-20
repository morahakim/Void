//
//  ResonanceView.swift
//  Void
//
//  Created by Mora Hakim on 18/11/26.
//

import SwiftUI
import Combine

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
    @State private var lastValidSignalAt: Date?
    @State private var hintLevel = 0
    @State private var searchStartedAt: Date?
    @State private var hintAvailable = false

    private let targetFrequency = 110.0
    private let tolerance = 0.08
    private let requiredDuration = 2.0

    private let timer = Timer.publish(
        every: 0.1,
        on: .main,
        in: .common
    ).autoconnect()
    
    private let hints = [
        "The tone at the start was the clue. Listen again.",
        "Your voice can be higher or lower. Hum the same note.",
        "Hum one steady note without stopping for two seconds. The rings glow brighter as you get closer."
    ]
    
    private let maxOctaveShift = 3

    /// Folds the detected pitch down by whole octaves, so the same note
    /// hummed higher (most women's and children's voices) still matches.
    /// Folding keeps the error as a percentage, so `tolerance` stays just as strict.
    private var normalizedFrequency: Double {
        var frequency = audio.detectedFrequency
        guard frequency > 0 else { return 0 }

        var octaves = 0
        while frequency > targetFrequency * 2.squareRoot(),
              octaves < maxOctaveShift {
            frequency /= 2
            octaves += 1
        }

        return frequency
    }

    private var isFrequencyMatched: Bool {
        let difference = abs(normalizedFrequency - targetFrequency)

        return normalizedFrequency > 0 &&
            difference <= targetFrequency * tolerance &&
            audio.inputLevel > 0.01
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
        .sensoryFeedback(.success, trigger: phase) { _, newPhase in
            newPhase == .completed
        }
        .onChange(of: audio.isRunning) { _, running in
            guard running, phase == .ready else { return }

            phase = .listening

            audio.playReferenceTone(
                frequency: targetFrequency,
                duration: 0.5
            ) {
                guard phase == .listening else { return }
                phase = .responding
            }
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
    
    /// The latest hint, shown in place of the instruction while humming.
    private var revealedHint: String? {
        guard phase == .responding || phase == .listening,
              hintLevel > 0 else { return nil }
        return hints[hintLevel - 1]
    }

    // MARK: - Sections

    private var visualizer: some View {
        let intensity = resonanceIntensity
        let tint = phase == .completed ? VoidColor.success : VoidTheme.accent
        let coreSize = 8 + CGFloat(intensity * 8)

        return ZStack {
            ForEach(0..<4, id: \.self) { index in
                let size = CGFloat(100 + index * 55) + CGFloat(intensity * 18)

                Circle()
                    .stroke(
                        tint.opacity(0.08 + intensity * 0.45),
                        lineWidth: 1
                    )
                    .frame(width: size, height: size)
                    .scaleEffect(
                        reduceMotion ? 1 : 1 + CGFloat(intensity) * 0.12
                    )
            }

            Circle()
                .fill(tint)
                .frame(width: coreSize, height: coreSize)
                .shadow(
                    color: tint.opacity(0.3 + intensity * 0.7),
                    radius: 8 + intensity * 22
                )
        }
        .animation(.easeInOut(duration: 0.25), value: intensity)
        .frame(height: 280)
        .accessibilityHidden(true)
    }

    private var statusSection: some View {
        VStack(spacing: 8) {
            Text(statusText)
                .voidText(.status)
                .foregroundStyle(
                    phase == .completed
                        ? VoidColor.success
                        : VoidTheme.secondary
                )

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
                    .accessibilityLabel("Hint \(hintLevel) of \(hints.count). \(revealedHint)")
            } else if let instructionText {
                Text(instructionText)
                    .voidText(.label)
                    .foregroundStyle(VoidTheme.secondary)
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
                if hintAvailable {
                    HStack(spacing: 8) {
                        if hintLevel < hints.count {
                            PuzzleHintButton(level: $hintLevel, count: hints.count)
                        }

                        if hintLevel >= 1 {
                            Button("REPLAY TONE") {
                                replayReferenceTone()
                            }
                            .buttonStyle(VoidSecondaryButtonStyle())
                            .disabled(phase == .listening)
                        }
                    }
                    .transition(.opacity)
                } else {
                    Color.clear
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
        
        if searchStartedAt == nil {
            searchStartedAt = Date()
        }

        if isFrequencyMatched {
            if stableSince == nil {
                stableSince = Date()
            }

            lastValidSignalAt = Date()
        } else {
            stableSince = nil
            lastValidSignalAt = nil
        }
    }

    // MARK: - Completion

    private func checkResonanceDuration() {
        guard phase == .responding,
              let stableSince,
              let lastValidSignalAt else {
            return
        }

        let now = Date()

        if now.timeIntervalSince(lastValidSignalAt) > 0.35 {
            self.stableSince = nil
            self.lastValidSignalAt = nil
            return
        }

        if now.timeIntervalSince(stableSince) >= requiredDuration {
            phase = .completed
            PuzzleProgress.markDiscovered(2)
        }
    }
    
    private func replayReferenceTone() {
        guard phase == .responding else { return }

        stableSince = nil
        lastValidSignalAt = nil
        phase = .listening

        // Same note one octave up: much more audible on phone speakers.
        audio.playReferenceTone(
            frequency: targetFrequency * 2,
            duration: 1.5
        ) {
            guard phase == .listening else { return }
            phase = .responding
        }
    }
}


