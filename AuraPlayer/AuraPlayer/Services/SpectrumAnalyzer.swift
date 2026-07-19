//
//  SpectrumAnalyzer.swift
//  AuraPlayer
//
//  Real-time FFT of the audio stream. A tap on the main mixer feeds
//  vDSP on the audio thread; results are published to the UI at ~43fps.
//

import Foundation
import AVFoundation
import Accelerate
import Combine

/// DSP core. Only ever touched from the realtime audio thread.
final class FFTProcessor: @unchecked Sendable {

    private let fftSize: Int
    private let halfSize: Int
    private let log2n: vDSP_Length
    private let fftSetup: FFTSetup
    private let window: [Float]
    private let barCount: Int
    private var barRanges: [(lo: Int, hi: Int)] = []
    private var smoothed: [Float]

    init?(fftSize: Int = 1024, barCount: Int = 32, sampleRate: Double) {
        self.fftSize = fftSize
        self.halfSize = fftSize / 2
        self.barCount = barCount
        self.log2n = vDSP_Length(log2(Float(fftSize)))
        self.smoothed = [Float](repeating: 0, count: barCount)

        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return nil }
        self.fftSetup = setup

        // Hann window reduces spectral leakage.
        var w = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&w, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        self.window = w

        buildBarRanges(sampleRate: sampleRate)
    }

    deinit { vDSP_destroy_fftsetup(fftSetup) }

    /// Log-spaced bin ranges: 20Hz up to 16kHz (or Nyquist).
    private func buildBarRanges(sampleRate: Double) {
        let minF = 20.0
        let maxF = min(16_000.0, sampleRate / 2)
        let binWidth = sampleRate / Double(fftSize)
        let logMin = log10(minF), logMax = log10(maxF)

        barRanges = (0..<barCount).map { i in
            let t0 = Double(i) / Double(barCount)
            let t1 = Double(i + 1) / Double(barCount)
            let f0 = pow(10, logMin + t0 * (logMax - logMin))
            let f1 = pow(10, logMin + t1 * (logMax - logMin))
            let lo = max(1, Int(f0 / binWidth))
            let hi = min(halfSize - 1, max(lo, Int(f1 / binWidth)))
            return (lo, hi)
        }
    }

    /// Returns smoothed 0...1 levels per bar, or nil if the buffer is too short.
    func process(_ buffer: AVAudioPCMBuffer) -> [Float]? {
        guard let channel = buffer.floatChannelData?[0],
              Int(buffer.frameLength) >= fftSize else { return nil }

        var windowed = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(channel, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        var realp = [Float](repeating: 0, count: halfSize)
        var imagp = [Float](repeating: 0, count: halfSize)
        var magnitudes = [Float](repeating: 0, count: halfSize)

        realp.withUnsafeMutableBufferPointer { rp in
            imagp.withUnsafeMutableBufferPointer { ip in
                var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
                windowed.withUnsafeBufferPointer { wp in
                    wp.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfSize) { cp in
                        vDSP_ctoz(cp, 2, &split, 1, vDSP_Length(halfSize))
                    }
                }
                vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvabs(&split, 1, &magnitudes, 1, vDSP_Length(halfSize))
            }
        }

        var scale = Float(1.0) / Float(fftSize)
        vDSP_vsmul(magnitudes, 1, &scale, &magnitudes, 1, vDSP_Length(halfSize))

        // Peak per bar → dB → normalize -60...0 dB to 0...1
        var bars = [Float](repeating: 0, count: barCount)
        for (i, range) in barRanges.enumerated() {
            var peak: Float = 0
            for b in range.lo...range.hi { peak = max(peak, magnitudes[b]) }
            let db = 20 * log10(peak + 1e-9)
            bars[i] = max(0, min(1, (db + 60) / 60))
        }

        // Temporal smoothing so bars glide instead of flickering.
        for i in 0..<barCount {
            smoothed[i] = smoothed[i] * 0.7 + bars[i] * 0.3
        }
        return smoothed
    }
}

@MainActor
final class SpectrumAnalyzer: ObservableObject {

    static let shared = SpectrumAnalyzer()

    let barCount = 32
    @Published private(set) var levels: [Float]

    private var processor: FFTProcessor?
    private var isTapped = false

    private init() {
        levels = [Float](repeating: 0, count: barCount)
    }

    func start() {
        guard !isTapped else { return }
        let mixer = AuraAudioEngine.shared.engine.mainMixerNode
        let format = mixer.outputFormat(forBus: 0)
        guard format.sampleRate > 0,
              let proc = FFTProcessor(barCount: barCount, sampleRate: format.sampleRate)
        else { return }

        processor = proc
        mixer.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            // Realtime audio thread — DSP only, then hop to main to publish.
            guard let bars = proc.process(buffer) else { return }
            Task { @MainActor in
                SpectrumAnalyzer.shared.levels = bars
            }
        }
        isTapped = true
    }

    func stop() {
        guard isTapped else { return }
        AuraAudioEngine.shared.engine.mainMixerNode.removeTap(onBus: 0)
        processor = nil
        isTapped = false
        levels = [Float](repeating: 0, count: barCount)
    }
}
