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
    /// Total track length, so VoiceOver can announce a real time position.
    var duration: TimeInterval = 0
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
        // Acts as the seek control, so expose it as an adjustable slider
        // that announces elapsed time rather than a percentage.
        .accessibilityElement()
        .accessibilityLabel("Playback position")
        .accessibilityValue(positionDescription)
        .accessibilityHint("Swipe up or down to scrub")
        .accessibilityAdjustableAction { direction in
            // Step by 5 seconds, or 5% when the duration isn't known yet.
            let step = duration > 0 ? 5 / duration : 0.05
            switch direction {
            case .increment: onScrub(min(1, progress + step))
            case .decrement: onScrub(max(0, progress - step))
            @unknown default: break
            }
        }
    }

    private var positionDescription: String {
        guard duration > 0 else { return "\(Int(progress * 100)) percent" }
        let elapsed = Int(progress * duration)
        let total = Int(duration)
        return "\(spoken(elapsed)) of \(spoken(total))"
    }

    private func spoken(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if minutes == 0 { return "\(secs) seconds" }
        return "\(minutes) minute\(minutes == 1 ? "" : "s") \(secs) second\(secs == 1 ? "" : "s")"
    }
}
