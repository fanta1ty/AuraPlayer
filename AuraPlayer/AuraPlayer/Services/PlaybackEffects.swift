//
//  PlaybackEffects.swift
//  AuraPlayer
//
//  Pitch (semitones) and tempo (rate) control via AVAudioUnitTimePitch.
//  The unit shifts pitch and speed independently, so changing one does not
//  affect the other — unlike naive resampling.
//

import Foundation
import AVFoundation
import Combine

@MainActor
final class PlaybackEffects: ObservableObject {

    static let shared = PlaybackEffects()

    static let minSemitones: Float = -12
    static let maxSemitones: Float = 12
    static let minRate: Float = 0.5
    static let maxRate: Float = 2.0

    /// Pitch shift in semitones (the node works in cents: 100 cents = 1 semitone).
    @Published private(set) var semitones: Float = 0
    /// Playback speed multiplier (1.0 = normal).
    @Published private(set) var rate: Float = 1

    private let node = AuraAudioEngine.shared.timePitchNode

    private enum Keys {
        static let semitones = "effects.semitones"
        static let rate = "effects.rate"
    }

    private init() {
        let defaults = UserDefaults.standard
        semitones = defaults.object(forKey: Keys.semitones) as? Float ?? 0
        let storedRate = defaults.object(forKey: Keys.rate) as? Float ?? 1
        rate = storedRate > 0 ? storedRate : 1
        applyToNode()
    }

    var isModified: Bool { semitones != 0 || rate != 1 }

    func setSemitones(_ value: Float) {
        semitones = min(max(value, Self.minSemitones), Self.maxSemitones)
        applyToNode()
        persist()
    }

    func setRate(_ value: Float) {
        rate = min(max(value, Self.minRate), Self.maxRate)
        applyToNode()
        persist()
    }

    func reset() {
        semitones = 0
        rate = 1
        applyToNode()
        persist()
    }

    private func applyToNode() {
        node.pitch = semitones * 100     // cents
        node.rate = rate
    }

    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(semitones, forKey: Keys.semitones)
        defaults.set(rate, forKey: Keys.rate)
    }
}
