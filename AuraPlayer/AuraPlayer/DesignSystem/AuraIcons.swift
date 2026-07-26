//
//  AuraIcons.swift
//  AuraPlayer
//
//  Hand-drawn icons for the moments where an SF Symbol swap looks abrupt
//  or generic. Everything here is vector geometry in a unit square, so it
//  scales to any size and tints with any colour.
//

import SwiftUI

// MARK: - Play / pause morph

/// A single shape that continuously morphs between a play triangle and a
/// pause bar pair, rather than swapping one glyph for another.
///
/// Both states are drawn as two quadrilaterals — a left half and a right
/// half. In the play state the right half collapses to the triangle's tip,
/// which is what makes the two forms interpolate cleanly.
struct PlayPauseShape: Shape {
    /// 0 = play triangle, 1 = pause bars.
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let t = min(max(progress, 0), 1)

        // Unit-square corners for each half, in both end states.
        let leftPlay  = [CGPoint(x: 0.02, y: 0.00), CGPoint(x: 0.50, y: 0.25),
                         CGPoint(x: 0.50, y: 0.75), CGPoint(x: 0.02, y: 1.00)]
        let leftPause = [CGPoint(x: 0.04, y: 0.00), CGPoint(x: 0.38, y: 0.00),
                         CGPoint(x: 0.38, y: 1.00), CGPoint(x: 0.04, y: 1.00)]

        let rightPlay  = [CGPoint(x: 0.50, y: 0.25), CGPoint(x: 0.98, y: 0.50),
                          CGPoint(x: 0.98, y: 0.50), CGPoint(x: 0.50, y: 0.75)]
        let rightPause = [CGPoint(x: 0.62, y: 0.00), CGPoint(x: 0.96, y: 0.00),
                          CGPoint(x: 0.96, y: 1.00), CGPoint(x: 0.62, y: 1.00)]

        var path = Path()
        path.addLines(interpolate(leftPlay, leftPause, t, in: rect))
        path.closeSubpath()
        path.addLines(interpolate(rightPlay, rightPause, t, in: rect))
        path.closeSubpath()
        return path
    }

    private func interpolate(_ from: [CGPoint], _ to: [CGPoint],
                             _ t: Double, in rect: CGRect) -> [CGPoint] {
        zip(from, to).map { a, b in
            CGPoint(x: rect.minX + (a.x + (b.x - a.x) * t) * rect.width,
                    y: rect.minY + (a.y + (b.y - a.y) * t) * rect.height)
        }
    }
}

/// Drop-in play/pause button glyph that animates between states.
struct AuraPlayPauseIcon: View {
    var isPlaying: Bool
    var size: CGFloat = 24
    var color: Color = .textPrimary

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        PlayPauseShape(progress: isPlaying ? 1 : 0)
            .fill(color)
            // Play triangles read as smaller than pause bars at equal size,
            // so the glyph is slightly wider than tall.
            .frame(width: size, height: size * 0.92)
            .animation(reduceMotion ? nil : .spring(duration: 0.32, bounce: 0.2),
                       value: isPlaying)
    }
}

// MARK: - Vinyl

/// A record: grooves, a coloured label, a spindle hole. Spins while playing
/// and holds its angle when paused, the way a real deck coasts to a stop.
struct AuraVinylView: View {
    var size: CGFloat
    var isSpinning: Bool
    /// Degrees per second — a slow, deliberate turn rather than a real 33⅓.
    var speed: Double = 36
    var labelColor: Color = .accent

    @State private var accumulated: Double = 0
    @State private var spinStart: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isAnimating: Bool { isSpinning && !reduceMotion }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isAnimating)) { context in
            disc.rotationEffect(.degrees(angle(at: context.date)))
        }
        .frame(width: size, height: size)
        .onAppear { if isAnimating { spinStart = .now } }
        .onChange(of: isAnimating) { _, spinning in
            if spinning {
                spinStart = .now
            } else {
                accumulated = angle(at: .now)
                spinStart = nil
            }
        }
        .accessibilityHidden(true)
    }

    private func angle(at date: Date) -> Double {
        guard let spinStart else { return accumulated }
        return accumulated + date.timeIntervalSince(spinStart) * speed
    }

    private var disc: some View {
        ZStack {
            Circle().fill(
                RadialGradient(colors: [Color(white: 0.16), Color(white: 0.06)],
                               center: .center, startRadius: 0, endRadius: size / 2)
            )

            // Grooves. Thin, low-contrast rings catch the light as it turns.
            ForEach(1..<5) { ring in
                Circle()
                    .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
                    .padding(size * 0.055 * CGFloat(ring))
            }

            Circle()
                .fill(labelColor)
                .frame(width: size * 0.34, height: size * 0.34)

            // Spindle hole — the detail that makes it read as a record.
            Circle()
                .fill(Color.background)
                .frame(width: size * 0.07, height: size * 0.07)

            // A single highlight sweeping the surface sells the rotation.
            Circle()
                .trim(from: 0.05, to: 0.18)
                .stroke(Color.white.opacity(0.10), lineWidth: size * 0.5)
                .blur(radius: size * 0.08)
                .clipShape(Circle())
        }
    }
}

// MARK: - Waveform glyph

/// Symmetric amplitude bars — our stand-in for "audio" wherever a generic
/// music note would otherwise appear.
struct AuraWaveGlyph: View {
    var size: CGFloat = 24
    var color: Color = .accent

    /// A fixed, pleasing silhouette — deterministic so it never flickers.
    private let heights: [CGFloat] = [0.30, 0.62, 1.00, 0.78, 0.44, 0.86, 0.36]

    var body: some View {
        HStack(alignment: .center, spacing: size * 0.075) {
            ForEach(heights.indices, id: \.self) { index in
                Capsule()
                    .fill(color)
                    .frame(width: size * 0.1, height: size * heights[index])
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Equalizer glyph

/// Three faders at different positions — more literal than
/// `slider.vertical.3`, and it matches the EQ screen it opens.
struct AuraEqualizerGlyph: View {
    var size: CGFloat = 24
    var color: Color = .textPrimary

    private let knobPositions: [CGFloat] = [0.30, 0.62, 0.44]

    var body: some View {
        HStack(spacing: size * 0.18) {
            ForEach(knobPositions.indices, id: \.self) { index in
                ZStack(alignment: .top) {
                    Capsule()
                        .fill(color.opacity(0.35))
                        .frame(width: size * 0.08)

                    Circle()
                        .fill(color)
                        .frame(width: size * 0.2, height: size * 0.2)
                        .offset(y: size * knobPositions[index])
                }
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview("Aura Icons") {
    VStack(spacing: AuraSpacing.xl) {
        HStack(spacing: AuraSpacing.xl) {
            AuraPlayPauseIcon(isPlaying: false, size: 32)
            AuraPlayPauseIcon(isPlaying: true, size: 32)
            AuraWaveGlyph(size: 32)
            AuraEqualizerGlyph(size: 32)
        }
        HStack(spacing: AuraSpacing.xl) {
            AuraVinylView(size: 72, isSpinning: true)
            AuraVinylView(size: 44, isSpinning: false)
        }
    }
    .padding(AuraSpacing.xxl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.background)
    .preferredColorScheme(.dark)
}
