//
//  LoudnessAnalyzer.swift
//  AuraPlayer
//
//  Measures average loudness (RMS) and derives a ReplayGain-style correction
//  so tracks play at a consistent perceived level. Results are cached per file.
//
//  Note: this is an RMS approximation, not full EBU R128 gated loudness.
//  It is accurate enough to stop quiet tracks disappearing after loud ones.
//

import Foundation
import AVFoundation
import Accelerate

enum LoudnessAnalyzer {

    /// Reference level. Most ReplayGain implementations target about -18 dBFS RMS.
    private static let targetDBFS: Float = -18
    /// Never boost or cut more than this.
    private static let maxAdjustment: Float = 12

    private static let cacheKey = "replaygain.cache"

    // MARK: - Cache

    private static func cached(_ key: String) -> Float? {
        let cache = UserDefaults.standard.dictionary(forKey: cacheKey) as? [String: Double]
        return cache?[key].map(Float.init)
    }

    private static func store(_ gain: Float, for key: String) {
        var cache = UserDefaults.standard.dictionary(forKey: cacheKey) as? [String: Double] ?? [:]
        cache[key] = Double(gain)
        UserDefaults.standard.set(cache, forKey: cacheKey)
    }

    static func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }

    // MARK: - Analysis

    /// Gain in dB to apply to this file. Cached after the first analysis.
    static func gain(for url: URL) async -> Float {
        let key = url.lastPathComponent
        if let cached = cached(key) { return cached }

        let gain = await analyze(url: url)
        store(gain, for: key)
        return gain
    }

    /// Samples the file at intervals (like the waveform) so long tracks stay fast.
    private static func analyze(url: URL) async -> Float {
        await Task.detached(priority: .utility) { () -> Float in
            guard let file = try? AVAudioFile(forReading: url) else { return 0 }

            let format = file.processingFormat
            let total = file.length
            guard total > 0 else { return 0 }

            let windows = 120
            let windowFrames = AVAudioFrameCount(4096)
            let stride = max(1, Int(total) / windows)

            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: windowFrames) else {
                return 0
            }

            var sumOfSquares: Double = 0
            var sampleCount: Double = 0

            for i in 0..<windows {
                let position = AVAudioFramePosition(i * stride)
                guard position < total else { break }
                file.framePosition = position
                guard (try? file.read(into: buffer, frameCount: windowFrames)) != nil else { break }

                let n = Int(buffer.frameLength)
                guard n > 0, let channel = buffer.floatChannelData?[0] else { break }

                var meanSquare: Float = 0
                vDSP_measqv(channel, 1, &meanSquare, vDSP_Length(n))
                sumOfSquares += Double(meanSquare) * Double(n)
                sampleCount += Double(n)
            }

            guard sampleCount > 0 else { return 0 }

            let rms = sqrt(sumOfSquares / sampleCount)
            guard rms > 0 else { return 0 }

            let measuredDBFS = Float(20 * log10(rms))
            let adjustment = targetDBFS - measuredDBFS
            return min(max(adjustment, -maxAdjustment), maxAdjustment)
        }.value
    }
}
