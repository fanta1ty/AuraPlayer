//
//  EQCurve.swift
//  AuraPlayer
//
//  Computes the combined frequency response of the 10 parametric EQ bands.
//  Filters in series multiply magnitudes → their dB values add.
//

import Foundation

enum EQCurve {

    struct Point: Identifiable {
        let id: Int
        let frequency: Double
        let gain: Double
    }

    static let minFreq: Double = 20
    static let maxFreq: Double = 20_000
    private static let sampleRate: Double = 44_100
    private static let bandwidthOctaves: Double = 1.0   // matches AuraAudioEngine

    /// Combined response (preamp + all bands) at `count` log-spaced frequencies.
    static func response(bands: [EQBand], preamp: Float, count: Int = 120) -> [Point] {
        let logMin = log10(minFreq)
        let logMax = log10(maxFreq)

        return (0..<count).map { i in
            let t = Double(i) / Double(count - 1)
            let f = pow(10, logMin + t * (logMax - logMin))

            var dB = Double(preamp)
            for band in bands where band.isEnabled && band.gain != 0 {
                dB += peakingGainDB(at: f,
                                    centerFreq: Double(band.frequency),
                                    gainDB: Double(band.gain))
            }
            return Point(id: i, frequency: f, gain: dB)
        }
    }

    /// Magnitude (dB) of an RBJ peaking-EQ biquad at frequency `f`.
    private static func peakingGainDB(at f: Double, centerFreq f0: Double, gainDB: Double) -> Double {
        let A = pow(10, gainDB / 40)
        let w0 = 2 * .pi * f0 / sampleRate
        let bw = bandwidthOctaves
        let Q = sqrt(pow(2, bw)) / (pow(2, bw) - 1)
        let alpha = sin(w0) / (2 * Q)

        let b0 = 1 + alpha * A
        let b1 = -2 * cos(w0)
        let b2 = 1 - alpha * A
        let a0 = 1 + alpha / A
        let a1 = -2 * cos(w0)
        let a2 = 1 - alpha / A

        // Evaluate H(z) at z = e^{jw}
        let w = 2 * .pi * f / sampleRate
        let cosW = cos(w),  sinW = sin(w)
        let cos2W = cos(2 * w), sin2W = sin(2 * w)

        let numRe = b0 + b1 * cosW + b2 * cos2W
        let numIm = -(b1 * sinW + b2 * sin2W)
        let denRe = a0 + a1 * cosW + a2 * cos2W
        let denIm = -(a1 * sinW + a2 * sin2W)

        let num = sqrt(numRe * numRe + numIm * numIm)
        let den = sqrt(denRe * denRe + denIm * denIm)
        guard den > 0 else { return 0 }

        return 20 * log10(num / den)
    }
}
