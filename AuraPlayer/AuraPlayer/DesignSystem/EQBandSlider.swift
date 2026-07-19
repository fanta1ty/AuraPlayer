//
//  EQBandSlider.swift
//  AuraPlayer
//
//  Vertical EQ band slider with center-origin fill (0 dB at middle).
//

import SwiftUI

struct EQBandSlider: View {
    let band: EQBand
    var trackHeight: CGFloat = 170
    var onChange: (Float) -> Void

    private let minGain = EQEngine.minGain
    private let maxGain = EQEngine.maxGain
    private var range: Float { maxGain - minGain }

    var body: some View {
        VStack(spacing: AuraSpacing.xs) {
            Text(String(format: "%+.0f", band.gain))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(band.gain == 0 ? Color.textTertiary : Color.accent)

            GeometryReader { geo in
                let h = geo.size.height
                let norm = CGFloat((band.gain - minGain) / range)   // 0 (bottom) ... 1 (top)
                let thumbY = h - norm * h
                let centerY = h / 2

                ZStack(alignment: .top) {
                    Capsule()
                        .fill(Color.surfaceElevated)
                        .frame(width: 5, height: h)

                    Capsule()
                        .fill(Color.accent)
                        .frame(width: 5, height: abs(centerY - thumbY))
                        .offset(y: min(centerY, thumbY))

                    Circle()
                        .fill(Color.accent)
                        .frame(width: 16, height: 16)
                        .glowEffect(radius: 8)
                        .offset(y: thumbY - 8)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let y = min(max(value.location.y, 0), h)
                            let newNorm = Float(1 - y / h)
                            onChange(minGain + newNorm * range)
                        }
                )
            }
            .frame(height: trackHeight)

            Text(band.label)
                .font(.system(size: 9))
                .foregroundStyle(Color.textSecondary)
        }
    }
}
