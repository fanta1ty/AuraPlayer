//
//  EQEngine.swift
//  AuraPlayer
//
//  Observable control layer over the AVAudioUnitEQ in AuraAudioEngine.
//  All band changes go through here so the UI and the audio graph stay in sync.
//

import Foundation
import AVFoundation
import Combine

struct EQBand: Identifiable, Hashable {
    let id: Int             // band index (0...9)
    let frequency: Float    // Hz
    var gain: Float         // dB
    var isEnabled: Bool

    /// Short display label: "32", "1k", "16k".
    var label: String {
        frequency >= 1000 ? "\(Int(frequency / 1000))k" : "\(Int(frequency))"
    }
}

@MainActor
final class EQEngine: ObservableObject {

    static let shared = EQEngine()

    static let minGain: Float = -12
    static let maxGain: Float = 12

    @Published private(set) var bands: [EQBand] = []

    /// Master EQ on/off (bypasses the whole node).
    @Published var isEnabled: Bool = true {
        didSet { eqNode.bypass = !isEnabled }
    }

    private let eqNode = AuraAudioEngine.shared.eqNode

    private init() {
        bands = eqNode.bands.enumerated().map { index, band in
            EQBand(id: index,
                   frequency: band.frequency,
                   gain: band.gain,
                   isEnabled: !band.bypass)
        }
    }

    /// All current gains, in band order — handy for saving presets.
    var gains: [Float] { bands.map(\.gain) }

    /// Set one band's gain in dB (clamped to ±12).
    func setBand(_ index: Int, gain: Float) {
        guard bands.indices.contains(index) else { return }
        let clamped = min(max(gain, Self.minGain), Self.maxGain)
        eqNode.bands[index].gain = clamped
        bands[index].gain = clamped
    }

    /// Enable/bypass a single band.
    func setBand(_ index: Int, enabled: Bool) {
        guard bands.indices.contains(index) else { return }
        eqNode.bands[index].bypass = !enabled
        bands[index].isEnabled = enabled
    }

    /// Flatten every band to 0 dB.
    func reset() {
        for index in bands.indices {
            setBand(index, gain: 0)
        }
    }

    /// Apply an array of gain values (one per band, in order).
    func apply(preset: [Float]) {
        for (index, gain) in preset.enumerated() where bands.indices.contains(index) {
            setBand(index, gain: gain)
        }
    }
}
