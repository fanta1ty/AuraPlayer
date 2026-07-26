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
    /// Filter width in octaves — smaller is narrower/more surgical.
    var bandwidth: Float = 1.0
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
    /// AVAudioUnitEQ accepts 0.05...5.0 octaves; keep to a musically useful range.
    static let minBandwidth: Float = 0.2
    static let maxBandwidth: Float = 3.0

    @Published private(set) var bands: [EQBand] = []
    @Published private(set) var customPresets: [EQPreset] = []
    @Published private(set) var selectedPresetID: String?
    @Published private(set) var preamp: Float = 0

    /// Built-in presets followed by the user's saved ones.
    var allPresets: [EQPreset] { EQPreset.builtIns + customPresets }

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
                   bandwidth: band.bandwidth,
                   isEnabled: !band.bypass)
        }
        customPresets = EQPresetStore.load()
        restoreSettings()
    }

    /// All current gains, in band order — handy for saving presets.
    var gains: [Float] { bands.map(\.gain) }

    /// Set one band's gain in dB (clamped to ±12).
    func setBand(_ index: Int, gain: Float) {
        guard bands.indices.contains(index) else { return }
        let clamped = min(max(gain, Self.minGain), Self.maxGain)
        eqNode.bands[index].gain = clamped
        bands[index].gain = clamped
        selectedPresetID = nil    // manual edit = no longer a stock preset
        persistSettings()
    }

    /// Master gain applied by the EQ unit (-12…+12 dB).
    func setPreamp(_ value: Float) {
        let clamped = min(max(value, Self.minGain), Self.maxGain)
        preamp = clamped
        eqNode.globalGain = clamped
        persistSettings()
    }

    /// Set one band's width in octaves. Narrow bands cut/boost a tighter
    /// range — useful for notching out a resonance rather than shaping tone.
    func setBand(_ index: Int, bandwidth: Float) {
        guard bands.indices.contains(index) else { return }
        let clamped = min(max(bandwidth, Self.minBandwidth), Self.maxBandwidth)
        eqNode.bands[index].bandwidth = clamped
        bands[index].bandwidth = clamped
        selectedPresetID = nil
        persistSettings()
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
        selectedPresetID = EQPreset.flat.id
        persistSettings()
    }

    /// Apply an array of gain values (one per band, in order).
    func apply(preset: [Float]) {
        for (index, gain) in preset.enumerated() where bands.indices.contains(index) {
            setBand(index, gain: gain)
        }
        persistSettings()
    }

    // MARK: - Presets

    func apply(_ preset: EQPreset) {
        apply(preset: preset.gains)     // setBand() clears the selection…
        selectedPresetID = preset.id    // …so set it after,
        persistSettings()               // …and persist after that.
    }

    /// Capture the current band gains as a new named preset.
    func saveCustomPreset(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let preset = EQPreset(name: trimmed, gains: gains)
        customPresets.append(preset)
        EQPresetStore.save(customPresets)
        selectedPresetID = preset.id
        persistSettings()
    }

    /// Delete a custom preset (built-ins can't be removed).
    func delete(_ preset: EQPreset) {
        guard !preset.isBuiltIn else { return }
        customPresets.removeAll { $0.id == preset.id }
        EQPresetStore.save(customPresets)
        if selectedPresetID == preset.id { selectedPresetID = nil }
    }

    // MARK: - Persistence

    private enum Keys {
        static let gains      = "eq.gains"
        static let bandwidths = "eq.bandwidths"
        static let preamp   = "eq.preamp"
        static let enabled  = "eq.enabled"
        static let selected = "eq.selectedPreset"
    }

    private func persistSettings() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(gains) {
            defaults.set(data, forKey: Keys.gains)
        }
        if let data = try? JSONEncoder().encode(bands.map(\.bandwidth)) {
            defaults.set(data, forKey: Keys.bandwidths)
        }
        defaults.set(preamp, forKey: Keys.preamp)
        defaults.set(isEnabled, forKey: Keys.enabled)
        defaults.set(selectedPresetID, forKey: Keys.selected)
    }

    private func restoreSettings() {
        let defaults = UserDefaults.standard

        if let data = defaults.data(forKey: Keys.gains),
           let saved = try? JSONDecoder().decode([Float].self, from: data) {
            for (index, gain) in saved.enumerated() where bands.indices.contains(index) {
                let clamped = min(max(gain, Self.minGain), Self.maxGain)
                eqNode.bands[index].gain = clamped
                bands[index].gain = clamped
            }
        }

        if let data = defaults.data(forKey: Keys.bandwidths),
           let saved = try? JSONDecoder().decode([Float].self, from: data) {
            for (index, width) in saved.enumerated() where bands.indices.contains(index) {
                let clamped = min(max(width, Self.minBandwidth), Self.maxBandwidth)
                eqNode.bands[index].bandwidth = clamped
                bands[index].bandwidth = clamped
            }
        }

        if defaults.object(forKey: Keys.preamp) != nil {
            preamp = defaults.float(forKey: Keys.preamp)
            eqNode.globalGain = preamp
        }

        if let enabled = defaults.object(forKey: Keys.enabled) as? Bool {
            isEnabled = enabled          // assignment in init doesn't fire didSet…
            eqNode.bypass = !enabled     // …so set the node directly
        }

        // Restore which preset chip is highlighted (IDs are stable across launches).
        selectedPresetID = defaults.string(forKey: Keys.selected)
    }
}
