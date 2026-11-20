//
//  PuzzleSelectionView.swift
//  Void
//
//  Created by Mora Hakim on 18/11/26.
//

import SwiftUI

struct PuzzleSelectionView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("gravityDiscovered")
    private var gravityDiscovered = false

    @AppStorage("puzzle002Discovered")
    private var puzzle002Discovered = false

    @AppStorage("puzzle003Discovered")
    private var puzzle003Discovered = false

    @AppStorage("puzzle004Discovered")
    private var puzzle004Discovered = false

    @AppStorage("puzzle005Discovered")
    private var puzzle005Discovered = false

    @State private var selectedPuzzle: PuzzleDefinition?

    var body: some View {
        ZStack {
            VoidTheme.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header

                VStack(alignment: .leading, spacing: 10) {
                    Text("THE UNKNOWN.")
                        .font(.system(size: 30, weight: .light))
                        .tracking(3)
                        .foregroundStyle(.white)

                    Text("SOME THINGS ARE BETTER LEFT UNSEEN.")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1.5)
                        .foregroundStyle(VoidTheme.secondary)
                }
                .padding(.top, 65)
                .padding(.bottom, 24)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("DISCOVERY PROGRESS")
                        Spacer()
                        Text("\(discoveredCount) / 05")
                            .monospacedDigit()
                    }
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1.5)
                    .foregroundStyle(VoidTheme.secondary)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(VoidTheme.secondary.opacity(0.15))

                            Capsule()
                                .fill(VoidTheme.accent)
                                .frame(
                                    width: geometry.size.width *
                                    CGFloat(discoveredCount) / 5
                                )
                        }
                    }
                    .frame(height: 3)
                }
                .padding(.bottom, 32)

                VStack(spacing: 0) {
                    ForEach(PuzzleDefinition.all) { puzzle in
                        if puzzle.id > 1 {
                            Divider()
                                .overlay(
                                    VoidTheme.secondary.opacity(0.15)
                                )
                        }

                        puzzleRow(puzzle: puzzle)
                    }
                }

                Spacer()

                Text("\(String(format: "%02d", discoveredCount)) — 05")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(2)
                    .foregroundStyle(VoidTheme.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 25)
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $selectedPuzzle) { puzzle in
            PuzzleFlowView(initialPuzzleID: puzzle.id)
        }
    }

    private var header: some View {
        HStack {
            VoidBackButton {
                dismiss()
            }

            Spacer()

            Text("ARCHIVE")
                .font(.system(size: 9, weight: .medium))
                .tracking(2)
                .foregroundStyle(VoidTheme.secondary)
        }
    }

    // MARK: - Progression

    private func isDiscovered(_ index: Int) -> Bool {
        switch index {
        case 1: return gravityDiscovered
        case 2: return puzzle002Discovered
        case 3: return puzzle003Discovered
        case 4: return puzzle004Discovered
        case 5: return puzzle005Discovered
        default: return false
        }
    }

    private func isUnlocked(_ index: Int) -> Bool {
        PuzzleProgress.isUnlocked(index)
    }

    private var discoveredCount: Int {
        (1...5).filter { isDiscovered($0) }.count
    }

    // MARK: - Puzzle Row

    private func puzzleRow(puzzle: PuzzleDefinition) -> some View {
        let discovered = isDiscovered(puzzle.id)
        let unlocked = isUnlocked(puzzle.id)

        let status = discovered
            ? "DISCOVERED"
            : unlocked
                ? "READY TO EXPLORE"
                : "LOCKED"

        return Button {
                guard unlocked && puzzle.isImplemented else { return }

                selectedPuzzle = puzzle
        } label: {
            HStack(spacing: 16) {
                Image(systemName: discovered
                      ? "checkmark.circle"
                      : puzzle.symbol)
                    .font(.system(size: 23, weight: .ultraLight))
                    .foregroundStyle(
                        discovered
                            ? Color.green
                            : unlocked
                                ? VoidTheme.accent
                                : VoidTheme.secondary.opacity(0.4)
                    )
                    .frame(width: 42, height: 48)

                VStack(alignment: .leading, spacing: 6) {
                    Text("\(puzzle.code) — \(puzzle.title)")
                        .font(.system(size: 12, weight: .medium))
                        .tracking(1.5)
                        .foregroundStyle(
                            unlocked ? .white : VoidTheme.secondary
                        )

                    Text(status)
                        .font(.system(size: 8, weight: .medium))
                        .tracking(1.5)
                        .foregroundStyle(
                            discovered ? Color.green : VoidTheme.secondary
                        )
                }

                Spacer()

                Image(systemName: discovered
                      ? "checkmark"
                      : unlocked
                        ? "arrow.up.right"
                        : "lock")
                    .font(.system(size: 11))
                    .foregroundStyle(VoidTheme.secondary)
            }
            .padding(.vertical, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!unlocked || !puzzle.isImplemented)
    }

}

#Preview {
    PuzzleSelectionView()
}
