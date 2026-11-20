//
//  PuzzleDefinition.swift
//  Void
//
//  Created by Mora Hakim on 18/11/26.
//

import Foundation

struct PuzzleDefinition: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let symbol: String
    let isImplemented: Bool

    var code: String {
        String(format: "%03d", id)
    }

    static let all: [PuzzleDefinition] = [
        PuzzleDefinition(
            id: 1,
            title: "GRAVITY",
            subtitle: "LET GRAVITY GUIDE YOU.",
            symbol: "circle.dotted",
            isImplemented: true
        ),
        PuzzleDefinition(
            id: 2,
            title: "RESONANCE",
            subtitle: "NOT EVERY SOUND IS NOISE.",
            symbol: "waveform",
            isImplemented: true
        ),
        PuzzleDefinition(
            id: 3,
            title: "???",
            subtitle: "UNKNOWN",
            symbol: "eye",
            isImplemented: true
        ),
        PuzzleDefinition(
            id: 4,
            title: "???",
            subtitle: "UNKNOWN",
            symbol: "speaker.wave.2",
            isImplemented: false
        ),
        PuzzleDefinition(
            id: 5,
            title: "???",
            subtitle: "UNKNOWN",
            symbol: "circle.hexagongrid",
            isImplemented: false
        )
    ]
}
