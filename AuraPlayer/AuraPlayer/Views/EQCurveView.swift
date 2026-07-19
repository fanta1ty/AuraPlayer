//
//  EQCurveView.swift
//  AuraPlayer
//
//  Bode plot of the current EQ curve. Display-only.
//

import SwiftUI
import Charts

struct EQCurveView: View {
    let bands: [EQBand]
    let preamp: Float

    private var points: [EQCurve.Point] {
        EQCurve.response(bands: bands, preamp: preamp)
    }

    var body: some View {
        Chart(points) { point in
            AreaMark(
                x: .value("Frequency", point.frequency),
                yStart: .value("Zero", 0),
                yEnd: .value("Gain", point.gain)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                .linearGradient(
                    colors: [Color.accent.opacity(0.35), Color.accent.opacity(0.05)],
                    startPoint: .top, endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Frequency", point.frequency),
                y: .value("Gain", point.gain)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Color.accent)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        .chartXScale(domain: EQCurve.minFreq...EQCurve.maxFreq, type: .log)
        .chartYScale(domain: -12...12)
        .chartXAxis {
            AxisMarks(values: [20, 50, 100, 500, 1000, 5000, 10000, 20000]) { value in
                AxisGridLine().foregroundStyle(Color.textDisabled.opacity(0.35))
                AxisValueLabel {
                    if let f = value.as(Double.self) {
                        Text(label(for: f))
                            .font(.system(size: 8))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: [-12, -6, 0, 6, 12]) { value in
                AxisGridLine().foregroundStyle(Color.textDisabled.opacity(0.35))
                AxisValueLabel {
                    if let db = value.as(Double.self) {
                        Text("\(Int(db))")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }
        }
        .frame(height: 130)
        .padding(.horizontal, AuraSpacing.md)
        .animation(.easeOut(duration: 0.15), value: bands)
    }

    private func label(for f: Double) -> String {
        f >= 1000 ? "\(Int(f / 1000))k" : "\(Int(f))"
    }
}
