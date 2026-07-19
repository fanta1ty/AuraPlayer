//
//  SpectrumView.swift
//  AuraPlayer
//
//  Animated spectrum bars drawn with Canvas.
//

import SwiftUI

struct SpectrumView: View {
    let levels: [Float]
    var barSpacing: CGFloat = 2

    var body: some View {
        Canvas { context, size in
            let count = levels.count
            guard count > 0 else { return }

            let totalSpacing = barSpacing * CGFloat(count - 1)
            let barWidth = max(1, (size.width - totalSpacing) / CGFloat(count))

            for (i, level) in levels.enumerated() {
                let height = max(2, CGFloat(level) * size.height)
                let x = CGFloat(i) * (barWidth + barSpacing)
                let rect = CGRect(x: x, y: size.height - height, width: barWidth, height: height)
                let path = Path(roundedRect: rect, cornerRadius: barWidth / 3)

                context.fill(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [Color.textPrimary, Color.accent]),
                        startPoint: CGPoint(x: 0, y: size.height - height),
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )
            }
        }
        .animation(.linear(duration: 0.05), value: levels)
    }
}
