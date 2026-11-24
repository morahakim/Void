//
//  HomeView.swift
//  Void
//
//  Created by Mora Hakim on 17/11/26.
//

import SwiftUI

struct HomeView: View {
    @State private var showArchive = false
    @State private var discoveredCount = PuzzleProgress.discoveredCount

    var body: some View {
        ZStack {
            VoidTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Text("v0.1")
                }
                .voidText(.label)
                .foregroundStyle(VoidTheme.secondary)

                Spacer()

                VStack(spacing: 28) {
                    Text("VOID")
                        .voidText(.display)
                        .foregroundStyle(.white)
                        .accessibilityAddTraits(.isHeader)

                    Circle()
                        .stroke(
                            VoidTheme.secondary.opacity(0.5),
                            lineWidth: 1
                        )
                        .frame(width: 110, height: 110)
                        .overlay {
                            Circle()
                                .fill(.white)
                                .frame(width: 9, height: 9)
                        }
                        .accessibilityHidden(true)

                    Text("NOT EVERYTHING IS ON SCREEN.")
                        .voidText(.label)
                        .foregroundStyle(VoidTheme.secondary)
                }

                Spacer()

                Button("ENTER") {
                    showArchive = true
                }
                .buttonStyle(VoidPrimaryButtonStyle())

                Text(
                    String(
                        format: "%02d / %02d PUZZLES DISCOVERED",
                        discoveredCount,
                        PuzzleProgress.totalCount
                    )
                )
                .voidText(.label)
                .foregroundStyle(VoidTheme.secondary)
                .padding(.top, 20)
                .accessibilityLabel(
                    "\(discoveredCount) of \(PuzzleProgress.totalCount) puzzles discovered"
                )
            }
            .voidScreen()
        }
        .fullScreenCover(isPresented: $showArchive) {
            PuzzleSelectionView()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UserDefaults.didChangeNotification
            )
        ) { _ in
            discoveredCount = PuzzleProgress.discoveredCount
        }
    }
}

#Preview {
    HomeView()
}
