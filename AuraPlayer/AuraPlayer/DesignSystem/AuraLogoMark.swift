//
//  AuraLogoMark.swift
//  AuraPlayer
//
//  The app's spectrum-bar mark, matching the icon. Drawn rather than shipped
//  as an image so it tints, scales and animates.
//

import SwiftUI

struct AuraLogoMark: View {
    var size: CGFloat = 44
    /// Bars gently breathe when true — used on empty states and headers.
    var isAnimating: Bool = false
    var glows: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Symmetric silhouette, tallest in the middle.
    private let heights: [CGFloat] = [0.30, 0.52, 0.78, 1.00, 0.78, 0.52, 0.30]

    private var barWidth: CGFloat { size * 0.088 }
    private var spacing: CGFloat { size * 0.055 }

    var body: some View {
        Group {
            if isAnimating && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 24, paused: false)) { timeline in
                    let phase = timeline.date.timeIntervalSinceReferenceDate
                    bars { index in
                        // Each bar breathes on its own offset cycle.
                        let wave = sin(phase * 1.6 + Double(index) * 0.7)
                        return heights[index] * (0.78 + 0.22 * (wave + 1) / 2)
                    }
                }
            } else {
                bars { heights[$0] }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func bars(height: @escaping (Int) -> CGFloat) -> some View {
        HStack(spacing: spacing) {
            ForEach(heights.indices, id: \.self) { index in
                Capsule()
                    .fill(index == heights.count / 2 ? Color.textPrimary : Color.accent)
                    .frame(width: barWidth, height: size * height(index) * 0.92)
            }
        }
        .frame(height: size, alignment: .center)
        .modifier(GlowIf(active: glows))
    }
}

/// Applies the signature glow only when asked.
private struct GlowIf: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        if active {
            content.glowEffect(radius: 14)
        } else {
            content
        }
    }
}

#Preview {
    VStack(spacing: AuraSpacing.xxl) {
        AuraLogoMark(size: 80, isAnimating: true)
        AuraLogoMark(size: 44)
        AuraLogoMark(size: 24, glows: false)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.background)
    .preferredColorScheme(.dark)
}
