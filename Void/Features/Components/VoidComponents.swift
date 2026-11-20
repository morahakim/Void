//
//  VoidBackButton.swift
//  Void
//
//  Created by Mora Hakim on 19/11/26.
//

import SwiftUI

enum VoidMetrics {
    static let screenPadding: CGFloat = 28
    static let topPadding: CGFloat = 16
    static let bottomPadding: CGFloat = 24
    static let titleTopSpacing: CGFloat = 32
    static let cornerRadius: CGFloat = 12
    static let primaryButtonHeight: CGFloat = 50
    static let minimumTapTarget: CGFloat = 44
    static let puzzleCount = PuzzleProgress.totalCount
}

enum VoidColor {
    /// Single success color, used for every "solved" state.
    static let success = Color(.systemGreen)
    static let error = Color(.systemRed)
}

/// Text styles are built on Dynamic Type text styles (never below 11 pt)
/// so they scale with the user's settings.
enum VoidTextStyle {
    case display    // App wordmark
    case title      // Puzzle names
    case headline   // Current instruction
    case status     // Live puzzle state
    case label      // Metadata, eyebrows, secondary actions
    case body       // Hints and sentences

    var font: Font {
        switch self {
        case .display:  return .largeTitle.weight(.light)
        case .title:    return .title2.weight(.light)
        case .headline: return .callout.weight(.medium)
        case .status:   return .footnote.weight(.medium)
        case .label:    return .caption2.weight(.medium)
        case .body:     return .subheadline
        }
    }

    var tracking: CGFloat {
        switch self {
        case .display:  return 12
        case .title:    return 8
        case .headline: return 3
        case .status:   return 3
        case .label:    return 1.5
        case .body:     return 0
        }
    }
}

extension View {
    func voidText(_ style: VoidTextStyle) -> some View {
        font(style.font).tracking(style.tracking)
    }

    /// Shared screen chrome: dark scheme, consistent insets, sane Dynamic Type ceiling
    /// for heavily tracked uppercase text.
    func voidScreen() -> some View {
        self
            .padding(.horizontal, VoidMetrics.screenPadding)
            .padding(.top, VoidMetrics.topPadding)
            .padding(.bottom, VoidMetrics.bottomPadding)
            .preferredColorScheme(.dark)
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

/// The one primary button in the app: full width, 50 pt tall, pressed state.
struct VoidPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote.weight(.semibold))
            .tracking(3)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, minHeight: VoidMetrics.primaryButtonHeight)
            .background(
                Color.white,
                in: RoundedRectangle(
                    cornerRadius: VoidMetrics.cornerRadius,
                    style: .continuous
                )
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Text-only secondary action with a full 44 pt hit area.
struct VoidSecondaryButtonStyle: ButtonStyle {
    var tint: Color = VoidTheme.secondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .voidText(.label)
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .frame(minHeight: VoidMetrics.minimumTapTarget)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

struct VoidBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 12, weight: .medium))

                Text("BACK")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1.5)
            }
            .foregroundStyle(.white)
            .frame(height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct PuzzleHeader: View {
    let number: Int
    let onBack: () -> Void

    var body: some View {
        HStack {
            VoidBackButton {
                onBack()
            }

            Spacer()

            Text(String(format: "%03d / %03d", number, VoidMetrics.puzzleCount))
                .voidText(.label)
                .foregroundStyle(VoidTheme.secondary)
                .accessibilityLabel("Puzzle \(number) of \(VoidMetrics.puzzleCount)")
        }
    }
}

struct PuzzleTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .voidText(.title)
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)

            Text(subtitle)
                .voidText(.label)
                .foregroundStyle(VoidTheme.secondary)
        }
        .multilineTextAlignment(.center)
    }
}

/// Progressive hints, shared by every puzzle.
/// One line of guidance: the primary text, replaced by the latest hint.
struct PuzzleHints: View {
    let primary: String
    let hints: [String]
    @Binding var level: Int

    private var revealedHint: String? {
        level > 0 && level <= hints.count ? hints[level - 1] : nil
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(revealedHint ?? primary)
                .voidText(.body)
                .foregroundStyle(revealedHint == nil ? VoidTheme.secondary : .white)
                .id(level)
                .transition(.opacity)
                .accessibilityLabel(
                    revealedHint.map { "Hint \(level) of \(hints.count). \($0)" } ?? primary
                )

            if level < hints.count {
                PuzzleHintButton(level: $level, count: hints.count)
            }
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct PuzzleHintButton: View {
    @Binding var level: Int
    let count: Int

    var body: some View {
        Button(level == 0 ? "NEED A HINT?" : "NEXT HINT") {
            withAnimation(.easeInOut(duration: 0.25)) {
                level += 1
            }
        }
        .buttonStyle(VoidSecondaryButtonStyle(tint: VoidTheme.accent))
        .accessibilityHint("\(count - level) hints left")
    }
}
