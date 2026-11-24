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
    
    @State private var phase: Phase = .ready
    @State private var faceSince: Date?
    @State private var neutralYaw: Float?
    @State private var yawSamples: [Float] = []
    
    @State private var hintLevel = 0
    @State private var allHintsRevealedAt: Date?
    @State private var skipAvailable = false
    
    @State private var sequenceIndex = 0
    @State private var observationIndex = 0
    @State private var observationPosition: HeadPosition = .unknown
    @State private var observationStartedAt: Date?
    @State private var preparingSince: Date?
    @State private var lastDetectedPosition: HeadPosition = .center
    
    @State private var sequence: [HeadPosition] = [
        .left,
        .right,
        .center,
        .left
    ]
    
    private let faceDuration = 1.0
    private let skipDelay = 60.0
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
                visual.padding(.top, 16)
                completionMessage
                    .padding(.horizontal, 28)
                
                Spacer(minLength: 24)
                
                actionSection
            }
            .voidScreen()
            
            Color.black
                .opacity(0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .onChange(of: face.isRunning) { _, running in
            guard running, phase == .ready else { return }
            phase = .calibrating
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
        let positions: [HeadPosition] = [.left, .center, .right]
        
        return VStack(spacing: 28) {
            HStack(spacing: 24) {
                ForEach(Array(positions.enumerated()), id: \.offset) { index, position in
                    VStack(spacing: 12) {
                        Circle()
                            .stroke(
                                VoidTheme.accent.opacity(0.6),
                                lineWidth: 1
                            )
                            .background {
                                Circle()
                                    .fill(
                                        observationPosition == position
                                        ? VoidTheme.accent.opacity(0.25)
                                        : .clear
                                    )
                            }
                            .frame(width: 54, height: 54)
                            .overlay {
                                Circle()
                                    .fill(VoidTheme.accent)
                                    .frame(width: 7, height: 7)
                            }
                        
                        Text(["LEFT", "CENTER", "RIGHT"][index])
                            .font(.system(size: 9, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(VoidTheme.secondary)
                    }
                }
            }
            
            if phase == .observing {
                HStack(spacing: 12) {
                    ForEach(sequence.indices, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                index == observationIndex
                                ? VoidTheme.accent
                                : VoidTheme.secondary.opacity(0.25)
                            )
                            .frame(width: 28, height: 3)
                    }
                }
            }
            
            if phase == .reconstructing {
                HStack(spacing: 14) {
                    ForEach(sequence.indices, id: \.self) { index in
                        Circle()
                            .fill(
                                index < sequenceIndex
                                ? VoidColor.success
                                : VoidTheme.secondary.opacity(0.25)
                            )
                            .frame(
                                width: index < sequenceIndex ? 11 : 7,
                                height: index < sequenceIndex ? 11 : 7
                            )
                            .shadow(
                                color: index < sequenceIndex
                                ? VoidColor.success.opacity(0.5)
                                : .clear,
                                radius: 8
                            )
                            .animation(
                                .spring(response: 0.35, dampingFraction: 0.6),
                                value: sequenceIndex
                            )
                    }
                }
            }
        }
        .frame(height: 280)
        .animation(.easeInOut(duration: 0.2), value: observationIndex)
        .accessibilityHidden(true)
    }
    
    private func evaluatePreparing(now: Date) {
        guard face.isFaceDetected else {
            preparingSince = nil
            return
        }
        
        guard face.eyesClosed else {
            preparingSince = nil
            return
        }
        
        if preparingSince == nil {
            preparingSince = now
            return
        }
        
        guard let preparingSince else { return }
        
        if now.timeIntervalSince(preparingSince) >= 1.0 {
            self.preparingSince = nil
            sequenceIndex = 0
            lastDetectedPosition = .center
            phase = .reconstructing
            impact(.light)
        }
    }
    
    private func evaluateReconstruction() {
        guard face.isFaceDetected else { return }
        
        // Gerakan hanya dihitung ketika kedua mata tertutup.
        guard face.eyesClosed else {
            lastDetectedPosition = detectHeadPosition()
            return
        }
        
        let currentPosition = detectHeadPosition()
        
        // Abaikan posisi yang belum terdeteksi atau belum berubah.
        guard currentPosition != .unknown,
              currentPosition != lastDetectedPosition else {
            return
        }
        
        lastDetectedPosition = currentPosition
        
        guard sequenceIndex < sequence.count else { return }
        
        // Center hanya diterima ketika memang menjadi target.
        if currentPosition == .center,
           sequence[sequenceIndex] != .center {
            return
        }
        
        if currentPosition == sequence[sequenceIndex] {
            sequenceIndex += 1
            impact(.light)
            
            if sequenceIndex == sequence.count {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    phase = .completed
                }
                
                successFeedback.notificationOccurred(.success)
            }
        } else {
            sequenceIndex = 0
            impact(.light)
        }
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

                case .calibrating, .observing, .preparing, .reconstructing:
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
        face.isRunning && face.isFaceDetected
    }
    
    // MARK: - Derived State

    private var currentHints: [String] {
        [
            "What you saw is still there.",
            "Remember the order, not the shapes.",
            "Move only when you know where to go."
        ]
    }

    private var revealedHint: String? {
        guard phase != .ready,
              phase != .completed,
              hintLevel > 0,
              hintLevel <= currentHints.count else {
            return nil
        }

        return currentHints[hintLevel - 1]
    }

    private var primaryText: String? {
        switch phase {
        case .ready:
            return nil
        case .calibrating:
            return "Stay still. Let the pattern find you."
        case .observing:
            return "Remember the sequence."
        case .preparing:
            return "Keep the pattern in your mind."
        case .reconstructing:
            return "Rebuild what you remember."
        case .completed:
            return nil
        }
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
        case .calibrating:
            return face.isFaceDetected ? "CALIBRATING" : "SEARCHING"
        case .observing:
            return "OBSERVE"
        case .preparing:
            return "REMEMBER"
        case .reconstructing:
            return "RECONSTRUCT"
        case .completed:
            return "FOUND IT."
        }
    }
    
    // MARK: - Puzzle Logic
    private func detectHeadPosition() -> HeadPosition {
        guard let neutralYaw else { return .unknown }

        let deviation = face.headYaw - neutralYaw

        if deviation <= -0.18 { return .right }
        if deviation >= 0.18 { return .left }
        if abs(deviation) <= 0.10 { return .center }

        return .unknown
    }

    private func evaluate() {
        let now = Date()

        if let allHintsRevealedAt,
           !skipAvailable,
           now.timeIntervalSince(allHintsRevealedAt) >= skipDelay {
            skipAvailable = true
        }

        switch phase {
        case .calibrating:
            evaluateFace(now: now)

        case .observing:
            evaluateObservation(now: now)

        case .preparing:
            evaluatePreparing(now: now)

        case .reconstructing:
            evaluateReconstruction()

        case .ready, .completed:
            break
        }
    }

    private func evaluateFace(now: Date) {
        guard face.isFaceDetected else {
            faceSince = nil
            yawSamples.removeAll()
            return
        }

        if faceSince == nil {
            faceSince = now
            yawSamples.removeAll()
        }

        yawSamples.append(face.headYaw)

        guard let faceSince,
              now.timeIntervalSince(faceSince) >= faceDuration,
              !yawSamples.isEmpty else {
            return
        }

        neutralYaw = yawSamples.reduce(0, +) / Float(yawSamples.count)

        self.faceSince = nil
        yawSamples.removeAll()

        observationStartedAt = now
        observationIndex = 0
        observationPosition = sequence[0]

        phase = .observing
        impact(.light)

        print("UNSEEN CALIBRATION: \(neutralYaw ?? 0)")
    }

    private func evaluateObservation(now: Date) {
        guard let startTime = observationStartedAt else {
            observationStartedAt = now
            observationIndex = 0
            observationPosition = sequence[0]
            return
        }

        let stepDuration = 0.8
        let gapDuration = 0.3
        let cycleDuration = stepDuration + gapDuration

        let totalDuration =
            Double(sequence.count - 1) * cycleDuration + stepDuration

        let elapsed = now.timeIntervalSince(startTime)

        guard elapsed < totalDuration else {
            observationPosition = .unknown
            observationStartedAt = nil
            phase = .preparing
            impact(.light)
            return
        }

        let currentIndex = Int(elapsed / cycleDuration)
        let timeInCycle = elapsed.truncatingRemainder(
            dividingBy: cycleDuration
        )

        observationIndex = currentIndex
        observationPosition = timeInCycle < stepDuration
            ? sequence[currentIndex]
            : .unknown
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

private enum Phase {
    case ready
    case calibrating
    case observing
    case preparing
    case reconstructing
    case completed
}

private enum HeadPosition: Equatable {
    case left
    case center
    case right
    case unknown
}

