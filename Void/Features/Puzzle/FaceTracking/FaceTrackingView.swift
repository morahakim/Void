//
//  FaceTrackingView.swift
//  Void
//
//  Created by Mora Hakim on 20/11/26.
//

import SwiftUI
import ARKit

struct FaceTrackingView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var face = FaceTrackingManager()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var onContinue: () -> Void = { }
    
    private enum Phase {
        case ready
        case face
        case close
        case reveal
        case completed
    }
    
    @State private var phase: Phase = .ready
    @State private var faceSince: Date?
    @State private var closedSince: Date?
    @State private var lastClosedAt: Date?
    @State private var countedSeconds = 0
    @State private var closeProgress: Double = 0
    @State private var hintLevel = 0
    @State private var allHintsRevealedAt: Date?
    @State private var skipAvailable = false
    
    private let faceDuration = 1.0
    private let closeDuration = 5.0
    private let gracePeriod = 0.3
    private let skipDelay = 60.0
    
    private let lightFeedback = UIImpactFeedbackGenerator(style: .light)
    private let mediumFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let successFeedback = UINotificationFeedbackGenerator()
    
    private let faceHints = [
        "Look at it.",
        "Hold the phone in front of your face.",
        "Keep your face in front of the screen with your eyes open."
    ]
    
    private let closeHints = [
        "Not everything needs your eyes.",
        "Keep facing the screen, but stop seeing it.",
        "Close both eyes for five seconds. You will feel it count."
    ]
    
    private let timer = Timer.publish(
        every: 0.05,
        on: .main,
        in: .common
    ).autoconnect()
    
    
    var body: some View {
        ZStack {
            VoidTheme.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                PuzzleHeader(number: 3) {
                    face.stop()
                    dismiss()
                }
                
                PuzzleTitle(title: "UNSEEN", subtitle: "SOME THINGS ONLY APPEAR IN THE DARK")
                    .padding(.top, VoidMetrics.titleTopSpacing)
                
                Spacer(minLength: 16)
                
                statusSection
                
                completionMessage
                    .padding(.horizontal, 28)

                Spacer(minLength: 24)

                actionSection
            }
            .voidScreen()
            
            Color.black
                .opacity(
                    phase == .close || phase == .reveal
                        ? closeProgress * 0.92
                        : 0
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.linear(duration: 0.2), value: closeProgress)
                .animation(.easeInOut(duration: 0.6), value: phase)
                }
                .onChange(of: face.isRunning) { _, running in
                    guard running, phase == .ready else { return }
                    phase = .face
                }
                .onChange(of: phase) { _, _ in
                    // Each phase has its own hints; start each one fresh.
                    hintLevel = 0
                }
                .onChange(of: hintLevel) { _, level in
                    allHintsRevealedAt = level >= currentHints.count ? Date() : nil
                    skipAvailable = false
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        face.refreshAuthorization()
                    }
                }
                .onReceive(timer) { _ in
                    evaluate()
                }
                .onDisappear {
                    face.stop()
                }
            }

            // MARK: - Sections

            private var visual: some View {
                let tint = phase == .completed ? VoidColor.success : VoidTheme.accent

                return ZStack {
                    Circle()
                        .stroke(VoidTheme.secondary.opacity(0.4), lineWidth: 1)
                        .frame(width: 220, height: 220)

                    // Fills over the five seconds.
                    Circle()
                        .trim(from: 0, to: closeProgress)
                        .stroke(
                            VoidTheme.accent,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 220, height: 220)
                        .opacity(phase == .close ? 1 : 0)

                    if phase == .reveal || phase == .completed {
                        ZStack {
                            // Outer glow
                            Circle()
                                .fill(VoidTheme.accent.opacity(0.12))
                                .frame(width: 110, height: 110)
                                .blur(radius: 25)

                            // Inner light
                            Circle()
                                .fill(VoidTheme.accent.opacity(0.2))
                                .frame(width: 48, height: 48)
                                .blur(radius: 12)

                            Image(systemName: "eye.slash")
                                .font(.system(size: 42, weight: .ultraLight))
                                .foregroundStyle(tint)
                        }
                        .transition(.scale(scale: 0.65).combined(with: .opacity))
                    } else {                        // The eye mirrors the player's eyes.
                        ZStack {
                            Ellipse()
                                .stroke(tint, lineWidth: 1.25)
                                .frame(width: 72, height: isEyeOpen ? 32 : 2)

                            Circle()
                                .fill(tint)
                                .frame(width: 10, height: 10)
                                .opacity(isEyeOpen ? 1 : 0)
                        }
                        .animation(
                            reduceMotion ? nil : .easeInOut(duration: 0.2),
                            value: isEyeOpen
                        )
                    }
                }
                .animation(.easeInOut(duration: 0.8), value: phase)
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

                    if let unavailableText {
                        Text(unavailableText)
                            .font(.footnote)
                            .foregroundStyle(VoidColor.error)
                    } else if let revealedHint {
                        Text(revealedHint)
                            .voidText(.body)
                            .foregroundStyle(.white)
                            .id(hintLevel)
                            .transition(.opacity)
                            .accessibilityLabel(
                                "Hint \(hintLevel) of \(currentHints.count). \(revealedHint)"
                            )
                    } else if phase == .ready {
                        // HIG: explain why before the system permission prompt appears.
                        Text("USES THE FRONT CAMERA · NOTHING IS SAVED")
                            .voidText(.label)
                            .foregroundStyle(VoidTheme.secondary)
                    } else if let primaryText {
                        Text(primaryText)
                            .voidText(.body)
                            .foregroundStyle(VoidTheme.secondary)
                    }
                }
                .multilineTextAlignment(.center)
                .accessibilityElement(children: .combine)
            }

            /// Reserves the button's height in every phase so the layout never jumps.
            private var actionSection: some View {
                ZStack {
                    if face.availability == .unsupported {
                        Button("CONTINUE") {
                            // No TrueDepth camera: let the player through,
                            // or puzzles 4 and 5 stay locked forever.
                            PuzzleProgress.markDiscovered(3)
                            onContinue()
                        }
                        .buttonStyle(VoidPrimaryButtonStyle())
                    } else if face.availability == .denied {
                        Button("OPEN SETTINGS") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(VoidPrimaryButtonStyle())
                    } else {
                        switch phase {
                        case .ready:
                            Button("BEGIN") {
                                face.requestPermissionAccess()
                            }
                            .buttonStyle(VoidPrimaryButtonStyle())

                        case .completed:
                            Button("CONTINUE") {
                                face.stop()
                                onContinue()
                            }
                            .buttonStyle(VoidPrimaryButtonStyle())

                        case .face, .close:
                            HStack(spacing: 8) {
                                if hintLevel < currentHints.count {
                                    PuzzleHintButton(
                                        level: $hintLevel,
                                        count: currentHints.count
                                    )
                                }

                                if skipAvailable {
                                    Button("SKIP") {
                                        skipPuzzle()
                                    }
                                    .buttonStyle(VoidSecondaryButtonStyle())
                                    .transition(.opacity)
                                }
                            }

                        case .reveal:
                            Color.clear
                        }
                    }
                }
                .frame(height: VoidMetrics.primaryButtonHeight)
                .animation(.easeInOut(duration: 0.3), value: skipAvailable)
                .animation(.easeInOut(duration: 0.3), value: hintLevel)
            }
    
    private var completionMessage: some View {
        VStack(spacing: 12) {
            Text("YOU FOUND")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(4)
                .foregroundStyle(VoidTheme.secondary)

            Text("WHAT YOU COULDN'T SEE.")
                .font(.system(size: 19, weight: .light))
                .tracking(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(VoidTheme.primary)

            Text("SOME THINGS ARE ONLY FOUND WHEN YOU STOP LOOKING.")
                .font(.system(size: 9, weight: .regular, design: .monospaced))
                .tracking(1.5)
                .multilineTextAlignment(.center)
                .foregroundStyle(VoidTheme.secondary)
                .padding(.top, 6)
        }
        .opacity(phase == .completed ? 1 : 0)
        .offset(y: phase == .completed ? 0 : 12)
        .animation(.easeOut(duration: 1.0).delay(0.3), value: phase)
    }

            // MARK: - Derived State

            private var isEyeOpen: Bool {
                face.isRunning && face.isFaceDetected && !face.eyesClosed
            }

            private var currentHints: [String] {
                phase == .close ? closeHints : faceHints
            }

            private var revealedHint: String? {
                guard phase == .face || phase == .close,
                      hintLevel > 0,
                      hintLevel <= currentHints.count else {
                    return nil
                }

                return currentHints[hintLevel - 1]
            }

            private var unavailableText: String? {
                switch face.availability {
                case .unsupported:
                    return "This puzzle needs a Face ID camera."
                case .denied:
                    return "Allow camera access in Settings to play."
                case .unknown, .ready:
                    return nil
                }
            }

            private var primaryText: String? {
                switch phase {
                case .face:
                    return "It is waiting for you."
                case .close:
                    return "Some things only appear when you stop looking."
                case .ready, .reveal, .completed:
                    return nil
                }
            }

            private var statusText: String {
                switch face.availability {
                case .unsupported:
                    return "UNAVAILABLE"
                case .denied:
                    return "NO CAMERA ACCESS"
                case .unknown, .ready:
                    break
                }

                switch phase {
                case .ready:
                    return "WAITING"
                case .face:
                    return face.isFaceDetected ? "FOUND YOU" : "SEARCHING"
                case .close:
                    return closedSince == nil ? "WATCHING" : "\(countedSeconds) / 5"
                case .reveal:
                    return "OPEN YOUR EYES"
                case .completed:
                    return "FOUND IT."
                }
            }

            // MARK: - Puzzle Logic

            private func evaluate() {
                let now = Date()

                if let allHintsRevealedAt,
                   !skipAvailable,
                   now.timeIntervalSince(allHintsRevealedAt) >= skipDelay {
                    skipAvailable = true
                }

                switch phase {
                case .face:
                    evaluateFace(now: now)
                case .close:
                    evaluateClose(now: now)
                case .reveal:
                    // Opening the eyes (or moving away) after the reveal completes it.
                    if !face.eyesClosed || !face.isFaceDetected {
                        phase = .completed
                        PuzzleProgress.markDiscovered(3)
                    }
                case .ready, .completed:
                    break
                }
            }

            private func evaluateFace(now: Date) {
                guard face.isFaceDetected, !face.eyesClosed else {
                    faceSince = nil
                    return
                }

                if faceSince == nil {
                    faceSince = now
                }

                if let faceSince, now.timeIntervalSince(faceSince) >= faceDuration {
                    self.faceSince = nil
                    phase = .close
                    impact(.light)
                }
            }

            private func evaluateClose(now: Date) {
                if face.isFaceDetected && face.eyesClosed {
                    if closedSince == nil {
                        closedSince = now
                    }
                    lastClosedAt = now
                } else if let lastClosedAt,
                          now.timeIntervalSince(lastClosedAt) > gracePeriod {
                    // Eyes opened or face lost: the count restarts and the
                    // vibrations stop, so the player can feel the reset.
                    resetCount()
                    return
                }

                guard let closedSince else { return }

                let elapsed = now.timeIntervalSince(closedSince)
                closeProgress = min(elapsed / closeDuration, 1)

                let seconds = Int(elapsed)

                if seconds > countedSeconds, seconds < Int(closeDuration) {
                    countedSeconds = seconds

                    switch seconds {
                    case 1, 2:
                        impact(.soft)

                    case 3, 4:
                        impact(.medium)

                    default:
                        break
                    }
                }

                if elapsed >= closeDuration {
                    countedSeconds = Int(closeDuration)
                    phase = .reveal

                    // The signal to open the eyes.
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }

            private func resetCount() {
                closedSince = nil
                lastClosedAt = nil
                countedSeconds = 0

                withAnimation(.easeOut(duration: 0.3)) {
                    closeProgress = 0
                }
            }

            private func skipPuzzle() {
                PuzzleProgress.markDiscovered(3)
                face.stop()
                onContinue()
            }

            private func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
                UIImpactFeedbackGenerator(style: style).impactOccurred()
            }
        }
        
#Preview {
    FaceTrackingView()
}
