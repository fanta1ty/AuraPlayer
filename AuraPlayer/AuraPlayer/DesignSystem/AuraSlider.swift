//
//  AuraSlider.swift
//  AuraPlayer
//
//  Created by Thinh Nguyen on 4/7/26.
//
//  Custom seek / EQ slider. Accent fill + glowing thumb, smooth drag.
//

import SwiftUI

struct AuraSlider: View {
    @Binding var value: Double          // 0...1
    var trackHeight: CGFloat = 6
    var thumbSize: CGFloat = 18

    @State private var isDragging = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let clamped = min(max(value, 0), 1)
            let x = clamped * (w - thumbSize) + thumbSize / 2

            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color.surfaceElevated)
                    .frame(height: trackHeight)

                // Fill
                Capsule()
                    .fill(Color.accent)
                    .frame(width: x, height: trackHeight)

                // Thumb
                Circle()
                    .fill(Color.accent)
                    .frame(width: thumbSize, height: thumbSize)
                    .glowEffect(radius: isDragging ? 20 : 12)
                    .scaleEffect(isDragging ? 1.15 : 1.0)
                    .offset(x: x - thumbSize / 2)
                    .animation(.easeOut(duration: 0.12), value: isDragging)
            }
            .frame(height: max(thumbSize, trackHeight))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        isDragging = true
                        let newValue = (g.location.x - thumbSize / 2) / (w - thumbSize)
                        value = min(max(newValue, 0), 1)
                    }
                    .onEnded { _ in isDragging = false }
            )
        }
        .frame(height: max(thumbSize, trackHeight))
    }
}

#Preview("AuraSlider") {
    struct Demo: View {
        @State private var seek = 0.4
        @State private var eq = 0.65
        var body: some View {
            VStack(spacing: AuraSpacing.xl) {
                VStack(alignment: .leading, spacing: AuraSpacing.sm) {
                    Text("Seek").font(.auraCaption).foregroundStyle(Color.textTertiary)
                    AuraSlider(value: $seek)
                    HStack {
                        Text("2:12").font(.auraTimestamp).foregroundStyle(Color.textSecondary)
                        Spacer()
                        Text("5:54").font(.auraTimestamp).foregroundStyle(Color.textSecondary)
                    }
                }
                VStack(alignment: .leading, spacing: AuraSpacing.sm) {
                    Text("EQ band").font(.auraCaption).foregroundStyle(Color.textTertiary)
                    AuraSlider(value: $eq)
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
