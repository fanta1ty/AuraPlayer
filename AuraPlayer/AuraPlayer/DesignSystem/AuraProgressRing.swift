//
//  AuraProgressRing.swift
//  AuraPlayer
//
//  Created by Thinh Nguyen on 4/7/26.
//
//  Circular progress indicator with glowing accent stroke.
//  Use for sleep timer, buffering/loading, or download progress.
//

import SwiftUI

struct AuraProgressRing: View {
    var progress: Double            // 0...1
    var lineWidth: CGFloat = 8
    var size: CGFloat = 96
    var showsLabel: Bool = true

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.surfaceElevated, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    Color.accent,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .glowEffect(radius: 10)
                .animation(.easeInOut(duration: 0.4), value: clamped)

            if showsLabel {
                Text("\(Int(clamped * 100))%")
                    .font(.auraHeadline)
                    .foregroundStyle(Color.textPrimary)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview("AuraProgressRing") {
    struct Demo: View {
        @State private var p = 0.25
        var body: some View {
            VStack(spacing: AuraSpacing.xl) {
                AuraProgressRing(progress: p)
                HStack(spacing: AuraSpacing.xl) {
                    AuraProgressRing(progress: 0.66, size: 56, showsLabel: false)
                    AuraProgressRing(progress: 1.0, size: 56, showsLabel: false)
                }
                AuraButton("Advance", systemImage: "arrow.clockwise", variant: .secondary) {
                    withAnimation { p = p >= 1 ? 0 : p + 0.25 }
                }
            }
            .padding(AuraSpacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.background)
            .preferredColorScheme(.dark)
        }
    }
    return Demo()
}
