//
//  PuzzleProgress.swift
//  Void
//
//  Created by Mora Hakim on 18/11/26.
//

import Foundation

enum PuzzleProgress {
    
    static let totalCount = 5
    
    private static func key(for puzzleID: Int) -> String {
        switch puzzleID {
        case 1: return "gravityDiscovered"
        case 2: return "puzzle002Discovered"
        case 3: return "puzzle003Discovered"
        case 4: return "puzzle004Discovered"
        case 5: return "puzzle005Discovered"
        default: return "unknownPuzzle"
        }
    }
    
    static var discoveredCount: Int {
        (1...totalCount).filter(isDiscovered).count
    }
    
    static func isDiscovered(_ puzzleID: Int) -> Bool {
        UserDefaults.standard.bool(
            forKey: key(for: puzzleID)
        )
    }
    
    static func markDiscovered(_ puzzleID: Int) {
        guard (1...totalCount).contains(puzzleID) else { return }
        
        UserDefaults.standard.set(
            true,
            forKey: key(for: puzzleID)
        )
    }
    
    static func isUnlocked(_ puzzleID: Int) -> Bool {
        guard (1...totalCount).contains(puzzleID) else { return false }
        
        if puzzleID == 1 {
            return true
        }
        
        return isDiscovered(puzzleID - 1)
    }
}
