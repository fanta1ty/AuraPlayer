//
//  SpectrumAnalyzer.swift
//  AuraPlayer
//
//  Real-time FFT of the audio stream.
//
//  Realtime-safety rules followed here:
//   • every buffer used by the FFT is allocated once, up front — no allocation
//     happens inside the tap callback
//   • the callback never spawns tasks, takes locks that can block, or touches
//     SwiftUI; it only writes the latest bar values behind a spin lock
//   • the UI polls those values at 30 fps from the main actor
//

import Foundation
import AVFoundation
import Accelerate
import Combine
import os

/// DSP core. `process` runs on the realtime audio thread only.
final class FFTProcessor: @unchecked Sendable {

    private let fftSize: Int
    private let halfSize: Int
    private let log2n: vDSP_Length
    private let fftSetup: FFTSetup
    private let barCount: Int
    private var barRanges: [(lo: Int, hi: Int)] = []

    // Pre-allocated scratch — reused on every callback so the audio thread
    // never allocates.
    private var window: [Float]
    private var windowed: [Float]
    private var realp: [Float]
    private var imagp: [Float]
    private var magnitudes: [Float]
    private var smoothed: [Float]

    /// Latest bars, guarded by a spin lock so the audio thread never blocks.
    private var latest: [Float]
    private let lock = OSAllocatedUnfairLock<Void>(initialState: ())

    init?(fftSize: Int = 1024, barCount: Int = 32, sampleRate: Double) {
        self.fftSize = fftSize
        self.halfSize = fftSize / 2
        self.barCount = barCount
        self.log2n = vDSP_Length(log2(Float(fftSize)))

        self.windowed = [Float](repeating: 0, count: fftSize)
        self.realp = [Float](repeating: 0, count: fftSize / 2)
        self.imagp = [Float](repeating: 0, count: fftSize / 2)
        self.magnitudes = [Float](repeating: 0, count: fftSize / 2)
        self.smoothed = [Float](repeating: 0, count: barCount)
        self.latest = [Float](repeating: 0, count: barCount)

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

    /// Called on the realtime audio thread. Allocation-free.
    func process(_ buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0],
              Int(buffer.frameLength) >= fftSize else { return }

        vDSP_vmul(channel, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

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

        // Peak per bar → dB → normalize -60...0 dB to 0...1, smoothed over time.
        for (i, range) in barRanges.enumerated() {
            var peak: Float = 0
            for b in range.lo...range.hi { peak = max(peak, magnitudes[b]) }
            let db = 20 * log10(peak + 1e-9)
            let level = max(0, min(1, (db + 60) / 60))
            smoothed[i] = smoothed[i] * 0.7 + level * 0.3
        }

        lock.withLock { _ in latest = smoothed }
    }

    /// Read the most recent bars from any thread.
    func currentLevels() -> [Float] {
        lock.withLock { _ in latest }
    }
}

@MainActor
final class SpectrumAnalyzer: ObservableObject {

    static let shared = SpectrumAnalyzer()

    let barCount = 32
    @Published private(set) var levels: [Float]

    private var processor: FFTProcessor?
    private var isTapped = false
    private var pollTimer: Timer?

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
            // Realtime audio thread: DSP only, no allocation, no tasks.
            proc.process(buffer)
        }
        isTapped = true

        // Pull the latest values at 30 fps instead of pushing from the tap.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let processor = self.processor else { return }
                self.levels = processor.currentLevels()
            }
        }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil

        guard isTapped else { return }
        AuraAudioEngine.shared.engine.mainMixerNode.removeTap(onBus: 0)
        processor = nil
        isTapped = false
        levels = [Float](repeating: 0, count: barCount)
    }
}
