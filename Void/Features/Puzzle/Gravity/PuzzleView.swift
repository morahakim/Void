//
//  PuzzleView.swift
//  Void
//
//  Created by Mora Hakim on 17/11/26.
//

import SwiftUI
import Combine

struct PuzzleView: View {
    var onContinue: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @StateObject private var motion = MotionManager()
    @State private var hintLevel = 0
    @State private var hintAvailable = false

    private enum Phase {
        case seek
        case hold
        case reverse
        case completed
    }

    @State private var phase: Phase = .seek
    @State private var ballPosition = CGPoint(x: 0, y: 85)
    @State private var holdStartedAt: Date?
    @State private var holdProgress: Double = 0
    @State private var reverseSampleCount = 0
    @State private var showReverseSymbol = false
    @State private var targetPulse = false
    @State private var completionScale: CGFloat = 0.7
    @State private var completionRingActive = false
    @State private var completionTextVisible = false
    @State private var completionActionsVisible = false

    private let targetSize: CGFloat = 46
    private let ballSize: CGFloat = 18
    private let movementRange: CGFloat = 115
    private let holdDuration: Double = 3
    private let requiredReverseSamples = 10
    private let mediumFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let successFeedback = UINotificationFeedbackGenerator()

    var body: some View {
        ZStack {
            VoidTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                PuzzleHeader(number: 1) {
                    dismiss()
                }

                titleSection
                    .padding(.top, VoidMetrics.titleTopSpacing)

                Spacer(minLength: 16)

                puzzleArea

                Spacer(minLength: 16)

                instruction
            }
            .voidScreen()
        }
        .onAppear {
            motion.startUpdates()
        }
        .onDisappear {
            motion.stopUpdates()
        }
        .onReceive(
            Publishers.CombineLatest3(
                motion.$x,
                motion.$y,
                motion.$z
            )
        ) { x, y, z in
            updatePuzzle(x: x, y: y, z: z)
        }
        .onChange(of: phase) { _, _ in
            hintLevel = 0
            hintAvailable = false
        }
        .task(id: phase) {
            hintAvailable = false

            guard phase != .completed else { return }

            try? await Task.sleep(for: .seconds(hintDelay))

            guard !Task.isCancelled else { return }

            hintAvailable = true
        }
    }

    // MARK: - Sections

    private var titleSection: some View {
        VStack(spacing: 16) {
            PuzzleTitle(
                title: "GRAVITY",
                subtitle: "PHASE \(currentPhaseIndex) OF 3 · \(phaseName)"
            )

            HStack(spacing: 4) {
                ForEach(1...3, id: \.self) { index in
                    Capsule()
                        .fill(
                            index <= currentPhaseIndex
                                ? VoidTheme.accent
                                : VoidTheme.secondary.opacity(0.25)
                        )
                        .frame(width: 28, height: 3)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: currentPhaseIndex)
            .accessibilityHidden(true)
        }
    }

    private var puzzleArea: some View {
        GeometryReader { geometry in
            ZStack {
                Circle()
                    .stroke(
                        VoidTheme.secondary.opacity(0.4),
                        lineWidth: 1
                    )
                    .frame(
                        width: movementRange * 2,
                        height: movementRange * 2
                    )

                Circle()
                    .fill(
                        phase == .completed
                            ? VoidColor.success
                            : targetPulse
                                ? VoidTheme.accent.opacity(
                                    0.65 + Double(holdIntensity) * 0.35
                                )
                                : VoidTheme.secondary.opacity(0.35)
                    )
                    .frame(
                        width: targetSize,
                        height: targetSize
                    )
                    .scaleEffect(
                        phase == .completed
                            ? completionScale
                            : targetPulse
                                ? 1.2
                                : 1.0 + targetProximity * 0.12
                    )
                    .shadow(
                        color: targetPulse
                            ? (phase == .completed
                                ? VoidColor.success
                                : VoidTheme.accent).opacity(
                                    0.35 + Double(holdIntensity) * 0.4
                                )
                            : VoidTheme.accent.opacity(
                                Double(targetProximity) * 0.45
                            ),
                        radius: targetPulse
                            ? 14 + holdIntensity * 16
                            : targetProximity * 14
                    )
                    .position(
                        x: geometry.size.width / 2,
                        y: geometry.size.height / 2
                    )
                    .animation(
                        .easeOut(duration: 0.15),
                        value: targetProximity
                    )

                if phase == .seek || phase == .hold {
                    Circle()
                        .fill(.white)
                        .frame(width: ballSize, height: ballSize)
                        .position(
                            x: geometry.size.width / 2 + ballPosition.x,
                            y: geometry.size.height / 2 + ballPosition.y
                        )
                        .shadow(
                            color: .white.opacity(0.4),
                            radius: 12
                        )
                }

                // COMPLETION RING
                Circle()
                    .stroke(
                        VoidColor.success.opacity(
                            phase == .completed
                                ? (completionRingActive ? 0 : 0.65)
                                : 0
                        ),
                        lineWidth: 2
                    )
                    .frame(
                        width: targetSize,
                        height: targetSize
                    )
                    .scaleEffect(
                        completionRingActive ? 1.9 : 0.65
                    )
                    .position(
                        x: geometry.size.width / 2,
                        y: geometry.size.height / 2
                    )
                    .animation(
                        .easeOut(duration: 0.9),
                        value: completionRingActive
                    )
                    .allowsHitTesting(false)

                if phase == .reverse || phase == .completed {
                    Image(systemName: "arrow.uturn.down")
                        .font(.system(size: 42, weight: .ultraLight))
                        .foregroundStyle(
                            phase == .completed ? VoidColor.success : VoidTheme.accent
                        )
                        // With Reduce Motion the symbol fades in already turned.
                        .rotationEffect(
                            .degrees(reduceMotion || showReverseSymbol ? 180 : 0)
                        )
                        .opacity(showReverseSymbol ? 1 : 0)
                        .zIndex(10)
                        .animation(
                            .easeInOut(duration: 1.2),
                            value: showReverseSymbol
                        )
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
        }
        .frame(height: 300)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Gravity puzzle")
        .accessibilityValue(accessibilityState)
    }

    private var instruction: some View {
        VStack(spacing: 16) {
            switch phase {
            case .seek:
                Text("FIND THE POINT")
                    .voidText(.headline)
                    .foregroundStyle(.white)

                hintSection(
                        primary: "It is closer than you think.",
                        hints: [
                            "The screen isn't the only thing you can move.",
                            "Let gravity guide the ball.",
                            "Tilt your device until the ball reaches the center."
                        ]
                    )

            case .hold:
                Text("DON'T LET GO")
                    .voidText(.headline)
                    .foregroundStyle(.white)

                ProgressView(value: holdProgress)
                    .tint(VoidTheme.accent)
                    .frame(width: 160)
                    .animation(.linear(duration: 0.1), value: holdProgress)
                    .accessibilityLabel("Hold")
                    .accessibilityValue("\(Int(holdProgress * 100)) percent")

                hintSection(
                        primary: "Some things require stillness.",
                        hints: [
                            "You have already found the point.",
                            "Stop moving your device.",
                            "Keep the ball in the center until the bar fills."
                        ]
                    )

            case .reverse:
                if hintLevel == 0 {
                    Text("...")
                        .voidText(.headline)
                        .foregroundStyle(.white)
                        .transition(.opacity)
                }

                hintSection(
                    primary: "The other side is waiting.",
                    hints: [
                        "There is more to this device than its screen.",
                        "Maybe the answer is on the other side.",
                        "Turn your device face down."
                    ]
                )

            case .completed:
                Text("FOUND IT.")
                    .voidText(.headline)
                    .foregroundStyle(.white)
                    .opacity(completionTextVisible ? 1 : 0)
                    .offset(y: completionTextVisible ? 0 : 8)
                    .animation(
                        .easeOut(duration: 0.4),
                        value: completionTextVisible
                    )

                VStack(spacing: 4) {
                    Button("CONTINUE") {
                        onContinue()
                    }
                    .buttonStyle(VoidPrimaryButtonStyle())

                    Button("RESTART") {
                        restartPuzzle()
                    }
                    .buttonStyle(VoidSecondaryButtonStyle())
                    .opacity(0.65)
                }
                .opacity(completionActionsVisible ? 1 : 0)
                .offset(y: completionActionsVisible ? 0 : 10)
                .animation(
                    .easeOut(duration: 0.45),
                    value: completionActionsVisible
                )
            }
        }
        .animation(.easeInOut(duration: 0.3), value: hintLevel)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 200, alignment: .top)
    }

    /// Hints read as part of the text, not as a card inside a card.
    /// Shares the one-line hint pattern with Resonance.
    private func hintSection(
        primary: String,
        hints: [String]
    ) -> some View {
        PuzzleHints(
            primary: primary,
            hints: hints,
            level: $hintLevel,
            isHintAvailable: hintAvailable
        )
    }

    // MARK: - Derived State

    private var currentPhaseIndex: Int {
        switch phase {
        case .seek:
            return 1
        case .hold:
            return 2
        case .reverse, .completed:
            return 3
        }
    }
    
    private var targetProximity: CGFloat {
        let distance = hypot(
            ballPosition.x,
            ballPosition.y
        )

        return min(max(1 - distance / 80, 0), 1)
    }
    
    private var hintDelay: Double {
        switch phase {
        case .seek, .hold, .reverse:
            50
        case .completed:
            0
        }
    }
    
    private var holdIntensity: CGFloat {
        guard phase == .hold else { return 0 }
        return CGFloat(holdProgress)
    }

    private var phaseName: String {
        switch phase {
        case .seek: return "SEEK"
        case .hold: return "HOLD"
        case .reverse: return "REVERSE"
        case .completed: return "COMPLETE"
        }
    }

    /// Describes what is on screen without giving the solution away.
    private var accessibilityState: String {
        switch phase {
        case .seek:
            return "A ball rests away from the center point."
        case .hold:
            return "The ball is on the center point. \(Int(holdProgress * 100)) percent held."
        case .reverse:
            return "The ball is gone. A curved arrow points downward."
        case .completed:
            return "Solved."
        }
    }

    // MARK: - Puzzle Logic (unchanged)

    private func updatePuzzle(
        x: Double,
        y: Double,
        z: Double
    ) {
        switch phase {
        case .seek:
            updateBallPosition(x: x, y: y)

            let distance = hypot(
                ballPosition.x,
                ballPosition.y
            )

            if distance < 12 {
                holdStartedAt = Date()
                holdProgress = 0

                withAnimation(.easeInOut(duration: 0.5)) {
                    targetPulse = true
                    phase = .hold
                }

                provideFeedback()
            }

        case .hold:
            updateBallPosition(x: x, y: y)

            let distance = hypot(
                ballPosition.x,
                ballPosition.y
            )

            guard distance < 18 else {
                holdStartedAt = Date()
                holdProgress = 0

                withAnimation(.easeInOut(duration: 0.3)) {
                    targetPulse = false
                }

                return
            }
            withAnimation(.easeInOut(duration: 0.3)) {
                targetPulse = true
            }

            guard let start = holdStartedAt else {
                holdStartedAt = Date()
                return
            }

            let elapsed = Date().timeIntervalSince(start)
            holdProgress = min(elapsed / holdDuration, 1)

            if elapsed >= holdDuration {
                reverseSampleCount = 0

                withAnimation(.easeInOut(duration: 0.8)) {
                    phase = .reverse
                    showReverseSymbol = true
                }

                provideFeedback()
            }

        case .reverse:
            // Face-down signature measured on this device.
            let isFaceDown = y > 0.75 && z < -0.15

            if isFaceDown {
                reverseSampleCount += 1
            } else {
                reverseSampleCount = 0
            }

            if reverseSampleCount >= requiredReverseSamples {
                phase = .completed
                PuzzleProgress.markDiscovered(1)

                withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) {
                    targetPulse = true
                    completionScale = 1.15
                }

                withAnimation(.easeOut(duration: 0.9).delay(0.1)) {
                    completionRingActive = true
                }
                
                withAnimation(.easeOut(duration: 0.4).delay(0.25)) {
                    completionTextVisible = true
                }

                withAnimation(.easeOut(duration: 0.45).delay(0.65)) {
                    completionActionsVisible = true
                }

                provideSuccessFeedback()
            }

        case .completed:
            break
        }
    }

    private func updateBallPosition(x: Double, y: Double) {
        let sensitivity: CGFloat = 220

        let newX = CGFloat(x) * sensitivity
        let newY = 85 - CGFloat(y) * sensitivity

        ballPosition = CGPoint(
            x: min(max(newX, -movementRange), movementRange),
            y: min(max(newY, -movementRange), movementRange)
        )
    }

    private func provideFeedback() {
        mediumFeedback.impactOccurred()
    }

    private func provideSuccessFeedback() {
        successFeedback.notificationOccurred(.success)
    }

    private func restartPuzzle() {
        motion.stopUpdates()

        phase = .seek
        hintLevel = 0

        ballPosition = CGPoint(x: 0, y: 85)
        holdStartedAt = nil
        holdProgress = 0
        reverseSampleCount = 0

        showReverseSymbol = false
        targetPulse = false

        completionScale = 0.7
        completionRingActive = false
        completionTextVisible = false
        completionActionsVisible = false

        motion.startUpdates()
    }
}

#Preview {
    PuzzleView()
}
