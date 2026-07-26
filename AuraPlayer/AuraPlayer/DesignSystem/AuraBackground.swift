//
//  AuraBackground.swift
//  AuraPlayer
//
//  A slow drifting aurora — the app's namesake. Three soft radial glows move
//  on long, offset cycles so the pattern never visibly repeats.
//
//  Cheap by design: no per-frame Canvas drawing, just three blurred circles
//  animated by a TimelineView clock. Honours Reduce Motion.
//

import SwiftUI

struct AuraBackground: View {
    /// 0 = barely there, 1 = vivid. Keep low behind content.
    var intensity: Double = 0.5
    /// Optional colour pulled from album art to tint the glow.
    var tint: Color?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var accent: Color { tint ?? .accent }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.background

                if reduceMotion {
                    // Static composition — same look, no movement.
                    blobs(size: geo.size, phase: 0.25)
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 20, paused: false)) { timeline in
                        let seconds = timeline.date.timeIntervalSinceReferenceDate
                        blobs(size: geo.size, phase: seconds)
                    }
                }
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func blobs(size: CGSize, phase: Double) -> some View {
        let w = size.width
        let h = size.height

        ZStack {
            blob(color: accent,
                 diameter: w * 1.1,
                 opacity: 0.22 * intensity,
                 x: w * (0.5 + 0.30 * sin(phase / 17)),
                 y: h * (0.22 + 0.10 * cos(phase / 23)))

            blob(color: accent.opacity(0.8),
                 diameter: w * 0.9,
                 opacity: 0.16 * intensity,
                 x: w * (0.5 + 0.34 * cos(phase / 29)),
                 y: h * (0.68 + 0.12 * sin(phase / 19)))

            blob(color: .surfaceElevated,
                 diameter: w * 1.3,
                 opacity: 0.5 * intensity,
                 x: w * (0.5 + 0.18 * sin(phase / 37)),
                 y: h * (0.45 + 0.16 * cos(phase / 31)))
        }
        .blur(radius: 70)
        .drawingGroup()          // composite once on the GPU
    }

    private func blob(color: Color, diameter: CGFloat,
                      opacity: Double, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color.opacity(opacity), color.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter / 2
                )
            )
            .frame(width: diameter, height: diameter)
            .position(x: x, y: y)
    }
}

#Preview {
    ZStack {
        AuraBackground(intensity: 0.9)
        Text("AuraPlayer")
            .font(.auraDisplay)
            .foregroundStyle(Color.textPrimary)
    }
    .preferredColorScheme(.dark)
}
