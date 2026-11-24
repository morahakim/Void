//
//  PuzzleProgress.swift
//  Void
//
//  Created by Mora Hakim on 18/11/26.
//

import Foundation

enum PuzzleProgress {
    
    private static func key(for puzzleID: Int) -> String {
        switch puzzleID {
        case 1: return "gravityDiscovered"
        case 2: return "puzzle002Discovered"
        case 3: return "puzzle003Discovered"
        case 4: return "puzzle004Discovered"
        case 5: return "puzzle005Discovered"
        default: return "puzzle\(String(format: "%03d", puzzleID))Discovered"
        }
    }
    
    static var totalCount: Int {
        PuzzleDefinition.all.count
    }
    
    static var discoveredCount: Int {
        PuzzleDefinition.all.filter {
            isDiscovered($0.id)
        }.count
    }
    
    static func isDiscovered(_ puzzleID: Int) -> Bool {
        guard PuzzleDefinition.all.contains(where: {
            $0.id == puzzleID
        }) else {
            return false
        }

        return UserDefaults.standard.bool(
            forKey: key(for: puzzleID)
        )
    }
    
    static func markDiscovered(_ puzzleID: Int) {
        guard PuzzleDefinition.all.contains(where: {
            $0.id == puzzleID
        }) else {
            return
        }

        UserDefaults.standard.set(
            true,
            forKey: key(for: puzzleID)
        )
    }
    
    static func isUnlocked(_ puzzleID: Int) -> Bool {
        guard let puzzle = PuzzleDefinition.all.first(where: {
            $0.id == puzzleID
        }) else {
            return false
        }

        if puzzle.id == 1 {
            return true
        }

        return isDiscovered(puzzle.id - 1)
    }
}
