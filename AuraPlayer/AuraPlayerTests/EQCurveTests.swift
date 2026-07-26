//
//  EQCurveTests.swift
//  AuraPlayerTests
//
//  The EQ response curve is pure math, so it can be verified exactly.
//

import Testing
import Foundation
@testable import AuraPlayer

struct EQCurveTests {

    /// Ten flat bands at the standard frequencies.
    private func bands(gains: [Float]) -> [EQBand] {
        zip(AuraAudioEngine.eqFrequencies, gains).enumerated().map { index, pair in
            EQBand(id: index, frequency: pair.0, gain: pair.1, isEnabled: true)
        }
    }

    private var flatBands: [EQBand] { bands(gains: Array(repeating: 0, count: 10)) }

    @Test func flatEQProducesFlatCurve() {
        let points = EQCurve.response(bands: flatBands, preamp: 0)

        #expect(points.count == 120)
        #expect(points.allSatisfy { abs($0.gain) < 0.001 })
    }

    @Test func curveSpansTheAudibleRange() {
        let points = EQCurve.response(bands: flatBands, preamp: 0)

        // Log spacing round-trips through pow/log10, so compare with tolerance.
        #expect(abs((points.first?.frequency ?? 0) - EQCurve.minFreq) < 0.001)
        #expect(abs((points.last?.frequency ?? 0) - EQCurve.maxFreq) < 0.01)
    }

    @Test func frequenciesIncreaseMonotonically() {
        let points = EQCurve.response(bands: flatBands, preamp: 0)

        for (a, b) in zip(points, points.dropFirst()) {
            #expect(b.frequency > a.frequency)
        }
    }

    @Test func preampShiftsWholeCurve() {
        let points = EQCurve.response(bands: flatBands, preamp: 6)

        #expect(points.allSatisfy { abs($0.gain - 6) < 0.001 })
    }

    /// Boosting a low band should lift the bottom of the curve, not the top.
    @Test func bassBoostRaisesLowFrequenciesOnly() {
        var gains = [Float](repeating: 0, count: 10)
        gains[0] = 12                       // 32 Hz
        let points = EQCurve.response(bands: bands(gains: gains), preamp: 0)

        let low = points.first { $0.frequency >= 32 }!
        let high = points.first { $0.frequency >= 8000 }!

        #expect(low.gain > 6)
        #expect(abs(high.gain) < 0.5)
    }

    @Test func cutProducesNegativeGain() {
        var gains = [Float](repeating: 0, count: 10)
        gains[5] = -12                      // 1 kHz
        let points = EQCurve.response(bands: bands(gains: gains), preamp: 0)

        let atBand = points.first { $0.frequency >= 1000 }!
        #expect(atBand.gain < -6)
    }

    @Test func disabledBandsAreIgnored() {
        var band = EQBand(id: 0, frequency: 1000, gain: 12, isEnabled: false)
        let points = EQCurve.response(bands: [band], preamp: 0)
        #expect(points.allSatisfy { abs($0.gain) < 0.001 })

        // Same band enabled should now affect the curve.
        band = EQBand(id: 0, frequency: 1000, gain: 12, isEnabled: true)
        let enabled = EQCurve.response(bands: [band], preamp: 0)
        #expect(enabled.contains { $0.gain > 6 })
    }

    @Test func adjacentBoostsAccumulate() {
        var gains = [Float](repeating: 0, count: 10)
        gains[4] = 6                        // 500 Hz
        gains[5] = 6                        // 1 kHz
        let points = EQCurve.response(bands: bands(gains: gains), preamp: 0)

        // Between the two centres the curves overlap, exceeding either alone.
        let between = points.first { $0.frequency >= 700 }!
        #expect(between.gain > 6)
    }
}
