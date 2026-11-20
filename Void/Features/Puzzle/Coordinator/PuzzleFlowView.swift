//
//  PuzzleFlowView.swift
//  Void
//
//  Created by Mora Hakim on 18/11/26.
//

import SwiftUI

struct PuzzleFlowView: View {

    @Environment(\.dismiss) private var dismiss

    let initialPuzzleID: Int

    @State private var currentPuzzleID: Int

    init(initialPuzzleID: Int) {
        self.initialPuzzleID = initialPuzzleID
        _currentPuzzleID = State(initialValue: initialPuzzleID)
    }

    var body: some View {
        ZStack {
            // Shared background so the cross-fade between puzzles never flashes.
            VoidTheme.background
                .ignoresSafeArea()

            switch currentPuzzleID {
            case 1:
                PuzzleView {
                    continueToNextPuzzle()
                }
                .transition(.opacity)

            case 2:
                ResonanceView {
                    continueToNextPuzzle()
                }
                .transition(.opacity)
                
            case 3:
                FaceTrackingView {
                    continueToNextPuzzle()
                }
                .transition(.opacity)
            default:
                EmptyView()
            }
        }
        .preferredColorScheme(.dark)
    }

    private func continueToNextPuzzle() {
        guard let nextID = PuzzleCoordinator.nextPuzzleID(
            after: currentPuzzleID
        ) else {
            dismiss()
            return
        }

        withAnimation(.easeInOut(duration: 0.4)) {
            currentPuzzleID = nextID
        }
    }
}

