//
//  SpectrumView.swift
//  AuraPlayer
//
//  Animated spectrum drawn with Canvas. Three display modes.
//

import SwiftUI

enum SpectrumDisplayMode: String, CaseIterable {
    case bars, line, mirror

    var icon: String {
        switch self {
        case .bars:   return "chart.bar.fill"
        case .line:   return "waveform.path.ecg"
        case .mirror: return "waveform"
        }
    }

    var next: SpectrumDisplayMode {
        let all = Self.allCases
        let i = all.firstIndex(of: self) ?? 0
        return all[(i + 1) % all.count]
    }
}

struct SpectrumView: View {
    let levels: [Float]
    var barSpacing: CGFloat = 2

    @AppStorage("spectrum.displayMode") private var modeRaw = SpectrumDisplayMode.bars.rawValue

    private var mode: SpectrumDisplayMode {
        SpectrumDisplayMode(rawValue: modeRaw) ?? .bars
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Canvas { context, size in
                guard !levels.isEmpty else { return }
                switch mode {
                case .bars:   drawBars(context: context, size: size)
                case .line:   drawLine(context: context, size: size)
                case .mirror: drawMirror(context: context, size: size)
                }
            }
            .animation(.linear(duration: 0.05), value: levels)

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    modeRaw = mode.next.rawValue
                }
            } label: {
                Image(systemName: mode.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
                    .padding(6)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    // MARK: - Renderers

    private func barWidth(for size: CGSize) -> CGFloat {
        let total = barSpacing * CGFloat(levels.count - 1)
        return max(1, (size.width - total) / CGFloat(levels.count))
    }

    private func drawBars(context: GraphicsContext, size: CGSize) {
        let w = barWidth(for: size)
        for (i, level) in levels.enumerated() {
            let h = max(2, CGFloat(level) * size.height)
            let x = CGFloat(i) * (w + barSpacing)
            let rect = CGRect(x: x, y: size.height - h, width: w, height: h)
            context.fill(
                Path(roundedRect: rect, cornerRadius: w / 3),
                with: .linearGradient(
                    Gradient(colors: [Color.textPrimary, Color.accent]),
                    startPoint: CGPoint(x: 0, y: size.height - h),
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )
        }
    }

    private func drawMirror(context: GraphicsContext, size: CGSize) {
        let w = barWidth(for: size)
        let mid = size.height / 2
        for (i, level) in levels.enumerated() {
            let h = max(1, CGFloat(level) * mid)
            let x = CGFloat(i) * (w + barSpacing)
            let rect = CGRect(x: x, y: mid - h, width: w, height: h * 2)
            context.fill(
                Path(roundedRect: rect, cornerRadius: w / 3),
                with: .linearGradient(
                    Gradient(colors: [Color.textPrimary, Color.accent, Color.textPrimary]),
                    startPoint: CGPoint(x: 0, y: mid - h),
                    endPoint: CGPoint(x: 0, y: mid + h)
                )
            )
        }
    }

    private func drawLine(context: GraphicsContext, size: CGSize) {
        guard levels.count > 1 else { return }
        let step = size.width / CGFloat(levels.count - 1)

        func point(_ i: Int) -> CGPoint {
            CGPoint(x: CGFloat(i) * step,
                    y: size.height - CGFloat(levels[i]) * size.height)
        }

        var line = Path()
        line.move(to: point(0))
        for i in 1..<levels.count {
            let prev = point(i - 1)
            let curr = point(i)
            let midX = (prev.x + curr.x) / 2
            line.addCurve(to: curr,
                          control1: CGPoint(x: midX, y: prev.y),
                          control2: CGPoint(x: midX, y: curr.y))
        }

        var fill = line
        fill.addLine(to: CGPoint(x: size.width, y: size.height))
        fill.addLine(to: CGPoint(x: 0, y: size.height))
        fill.closeSubpath()

        context.fill(
            fill,
            with: .linearGradient(
                Gradient(colors: [Color.accent.opacity(0.35), Color.accent.opacity(0.02)]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )
        context.stroke(line, with: .color(Color.accent), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
    }
}
