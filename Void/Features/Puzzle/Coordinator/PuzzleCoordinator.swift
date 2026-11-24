//
//  PuzzleCoordinator.swift
//  Void
//
//  Created by Mora Hakim on 18/11/26.
//

import Foundation

enum PuzzleCoordinator {
    
    // Find the next puzzle that is unlocked and implemented.
    static func nextPuzzle(after currentID: Int) -> PuzzleDefinition? {
        let nextID = currentID + 1

        guard let puzzle = PuzzleDefinition.all.first(where: {
            $0.id == nextID
        }) else {
            return nil
        }

        guard puzzle.isImplemented,
              PuzzleProgress.isUnlocked(puzzle.id) else {
            return nil
        }

        return puzzle
    }

    // Get the next puzzle ID.
    static func nextPuzzleID(after currentID: Int) -> Int? {
        nextPuzzle(after: currentID)?.id
    }
}
