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
    @State private var completionOpacity: Double = 0

    private let targetSize: CGFloat = 46
    private let ballSize: CGFloat = 18
    private let movementRange: CGFloat = 115
    private let holdDuration: Double = 3
    private let requiredReverseSamples = 10

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
            // Each phase has its own hints; start each one fresh.
            hintLevel = 0
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
                            ? VoidTheme.accent
                            : VoidTheme.secondary.opacity(0.35)
                    )
                    .frame(
                        width: targetSize,
                        height: targetSize
                    )
                    .scaleEffect(
                        phase == .completed ? completionScale : (targetPulse ? 1.2 : 1.0)
                    )
                    .shadow(
                        color: targetPulse
                        ? (phase == .completed ? VoidColor.success : VoidTheme.accent).opacity(0.6)
                        : .clear,
                        radius: targetPulse ? 20 : 0
                    )
                    .position(
                        x: geometry.size.width / 2,
                        y: geometry.size.height / 2
                    )
                    .animation(
                        .easeInOut(duration: 0.6),
                        value: targetPulse
                    )

                if phase == .seek || phase == .hold {
                    Circle()
                        .fill(.white)
                        .frame(
                            width: ballSize,
                            height: ballSize
                        )
                        .position(
                            x: geometry.size.width / 2 + ballPosition.x,
                            y: geometry.size.height / 2 + ballPosition.y
                        )
                        .shadow(
                            color: .white.opacity(0.4),
                            radius: 12
                        )
                }

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
                    .tint(.white)
                    .frame(width: 140)
                    .accessibilityLabel("Hold")

                hintSection(
                        primary: "Some things require stillness.",
                        hints: [
                            "You have already found the point.",
                            "Stop moving your device.",
                            "Keep the ball in the center until the bar fills."
                        ]
                    )

            case .reverse:
                Text("TURN IT OVER")
                    .voidText(.headline)
                    .foregroundStyle(.white)

                hintSection(
                    primary: "The other side is waiting.",
                    hints: [
                        "You are holding the answer.",
                        "What if the screen wasn't facing you?",
                        "Turn your device face down."
                    ]
                )

            case .completed:
                Text("FOUND IT.")
                    .voidText(.headline)
                    .foregroundStyle(.white)

                VStack(spacing: 4) {
                    Button("CONTINUE") {
                        onContinue()
                    }
                    .buttonStyle(VoidPrimaryButtonStyle())

                    Button("RESTART") {
                        restartPuzzle()
                    }
                    .buttonStyle(VoidSecondaryButtonStyle())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 200, alignment: .top)
    }

    /// Hints read as part of the text, not as a card inside a card.
    /// Shares the one-line hint pattern with Resonance.
    private func hintSection(
        primary: String,
        hints: [String]
    ) -> some View {
        PuzzleHints(primary: primary, hints: hints, level: $hintLevel)
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
                    completionOpacity = 1
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

        let limitedX = min(
            max(newX, -movementRange),
            movementRange
        )

        let limitedY = min(
            max(newY, -movementRange),
            movementRange
        )

        ballPosition = CGPoint(
            x: limitedX,
            y: limitedY
        )
    }

    private func provideFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func provideSuccessFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
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
        completionOpacity = 0

        motion.startUpdates()
    }
}

#Preview {
    PuzzleView()
}
