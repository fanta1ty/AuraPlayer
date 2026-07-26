//
//  NowPlayingIndicator.swift
//  AuraPlayer
//
//  Little dancing bars shown beside the track that's playing. They move while
//  audio is playing and settle to a flat line when paused, so a glance at the
//  list tells you the state.
//

import SwiftUI

struct NowPlayingIndicator: View {
    var isPlaying: Bool
    var size: CGFloat = 14

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let barCount = 4

    var body: some View {
        Group {
            if isPlaying && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 20, paused: false)) { timeline in
                    let phase = timeline.date.timeIntervalSinceReferenceDate
                    bars { index in
                        // Offset sine per bar gives an uneven, lively motion.
                        let wave = sin(phase * 5.5 + Double(index) * 1.3)
                        return 0.28 + 0.72 * (wave + 1) / 2
                    }
                }
            } else {
                // Paused (or reduced motion): a static, low silhouette.
                bars { index in index % 2 == 0 ? 0.35 : 0.55 }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func bars(height: @escaping (Int) -> CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: size * 0.13) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(Color.accent)
                    .frame(width: size * 0.16,
                           height: max(2, size * height(index)))
            }
        }
        .frame(height: size, alignment: .bottom)
    }
}

#Preview {
    HStack(spacing: AuraSpacing.xl) {
        NowPlayingIndicator(isPlaying: true, size: 18)
        NowPlayingIndicator(isPlaying: false, size: 18)
    }
    .padding(AuraSpacing.xl)
    .background(Color.background)
    .preferredColorScheme(.dark)
}
