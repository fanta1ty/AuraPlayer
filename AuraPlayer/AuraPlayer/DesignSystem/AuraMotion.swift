//
//  AuraMotion.swift
//  AuraPlayer
//
//  Shared motion: shimmer for loading states and a staggered entrance for
//  lists. Every effect checks Reduce Motion and degrades to a still frame
//  rather than disappearing, so nothing depends on movement to be legible.
//

import SwiftUI

// MARK: - Shimmer

private struct ShimmerModifier: ViewModifier {
    let isActive: Bool

    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        guard isActive, !reduceMotion else { return AnyView(content) }

        return AnyView(
            content
                .overlay(
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [.clear, Color.white.opacity(0.12), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 0.6)
                        .offset(x: phase * geo.size.width * 1.6)
                    }
                    .allowsHitTesting(false)
                )
                .clipped()
                .onAppear {
                    withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
        )
    }
}

extension View {
    /// A light sweeping highlight, for placeholder content that's loading.
    func auraShimmer(_ isActive: Bool = true) -> some View {
        modifier(ShimmerModifier(isActive: isActive))
    }
}

// MARK: - Staggered entrance

private struct AppearModifier: ViewModifier {
    let delay: Double

    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 12)
            .onAppear {
                guard !shown else { return }
                if reduceMotion {
                    shown = true
                } else {
                    withAnimation(.easeOut(duration: 0.4).delay(delay)) { shown = true }
                }
            }
    }
}

extension View {
    /// Fade and rise into place. Pass an index to stagger a group; the delay
    /// is capped so a long list never leaves the last rows waiting.
    func auraAppear(index: Int = 0, step: Double = 0.04) -> some View {
        modifier(AppearModifier(delay: min(Double(index) * step, 0.3)))
    }
}

// MARK: - Skeleton row

/// Placeholder shaped like a `TrackRow`, shown while the library scans.
/// Far calmer than a spinner, and it tells you what's about to appear.
struct AuraSkeletonRow: View {
    /// Varying the bar widths stops a column of rows looking like a grid.
    var titleWidth: CGFloat = 0.55
    var subtitleWidth: CGFloat = 0.32

    var body: some View {
        HStack(spacing: AuraSpacing.md) {
            RoundedRectangle(cornerRadius: AuraRadius.small)
                .fill(Color.surfaceElevated)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: AuraSpacing.sm) {
                bar(width: titleWidth, height: 11)
                bar(width: subtitleWidth, height: 9)
            }

            Spacer()
        }
        .padding(.vertical, AuraSpacing.sm)
        .auraShimmer()
        .accessibilityHidden(true)
    }

    private func bar(width: CGFloat, height: CGFloat) -> some View {
        GeometryReader { geo in
            Capsule()
                .fill(Color.surfaceElevated)
                .frame(width: geo.size.width * width, height: height)
        }
        .frame(height: height)
    }
}

/// A full screen of skeleton rows.
struct AuraSkeletonList: View {
    var count: Int = 8

    /// Deterministic pseudo-random widths — stable across redraws.
    private func widths(_ index: Int) -> (CGFloat, CGFloat) {
        let title: [CGFloat] = [0.62, 0.44, 0.71, 0.38, 0.55, 0.66, 0.48, 0.58]
        let subtitle: [CGFloat] = [0.30, 0.38, 0.25, 0.34, 0.29, 0.22, 0.36, 0.27]
        return (title[index % title.count], subtitle[index % subtitle.count])
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { index in
                let (title, subtitle) = widths(index)
                AuraSkeletonRow(titleWidth: title, subtitleWidth: subtitle)
                    .auraAppear(index: index, step: 0.05)
            }
            Spacer()
        }
        .padding(.horizontal, AuraSpacing.md)
        .padding(.top, AuraSpacing.sm)
    }
}

#Preview("Skeleton") {
    AuraSkeletonList()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background)
        .preferredColorScheme(.dark)
}
