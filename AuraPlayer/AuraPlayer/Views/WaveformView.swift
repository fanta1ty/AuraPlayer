//
//  WaveformView.swift
//  AuraPlayer
//
//  Track waveform with a playhead. Played portion is accent, remaining is dim.
//  Tap or drag anywhere to seek.
//

import SwiftUI

struct WaveformView: View {
    let samples: [Float]
    let progress: Double          // 0...1
    var loopRange: ClosedRange<Double>? = nil   // 0...1 fractions of the track
    var onScrub: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                // Highlight the A-B region behind the waveform.
                if let loopRange {
                    let x0 = size.width * CGFloat(loopRange.lowerBound)
                    let x1 = size.width * CGFloat(loopRange.upperBound)
                    let rect = CGRect(x: x0, y: 0, width: max(1, x1 - x0), height: size.height)
                    context.fill(Path(rect), with: .color(Color.accent.opacity(0.15)))
                    for x in [x0, x1] {
                        let marker = CGRect(x: x - 1, y: 0, width: 2, height: size.height)
                        context.fill(Path(marker), with: .color(Color.accent.opacity(0.7)))
                    }
                }

                guard !samples.isEmpty else {
                    // Placeholder line while the waveform is generating.
                    let mid = size.height / 2
                    let rect = CGRect(x: 0, y: mid - 1, width: size.width, height: 2)
                    context.fill(Path(roundedRect: rect, cornerRadius: 1),
                                 with: .color(Color.surfaceElevated))
                    return
                }

                let count = samples.count
                let spacing: CGFloat = 1
                let barWidth = max(1, (size.width - spacing * CGFloat(count - 1)) / CGFloat(count))
                let mid = size.height / 2
                let playedX = size.width * CGFloat(min(max(progress, 0), 1))

                for (i, sample) in samples.enumerated() {
                    let height = max(2, CGFloat(sample) * size.height)
                    let x = CGFloat(i) * (barWidth + spacing)
                    let rect = CGRect(x: x, y: mid - height / 2, width: barWidth, height: height)
                    let isPlayed = (x + barWidth / 2) <= playedX

                    context.fill(
                        Path(roundedRect: rect, cornerRadius: barWidth / 2),
                        with: .color(isPlayed ? Color.accent : Color.textDisabled)
                    )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard geo.size.width > 0 else { return }
                        let p = min(max(value.location.x / geo.size.width, 0), 1)
                        onScrub(Double(p))
                    }
            )
        }
    }
}
