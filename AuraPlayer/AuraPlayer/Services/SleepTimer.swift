//
//  SleepTimer.swift
//  AuraPlayer
//
//  Counts down, fades the mixer out over the final seconds, then pauses.
//  Also supports "stop at end of current track".
//

import Foundation
import Combine
import AVFoundation

@MainActor
final class SleepTimer: ObservableObject {

    static let shared = SleepTimer()

    /// Preset durations offered in the UI (minutes).
    static let presets: [Int] = [5, 10, 15, 30, 45, 60]

    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var total: TimeInterval = 0
    @Published private(set) var isActive = false
    /// When true, playback stops once the current track finishes.
    @Published private(set) var stopAtEndOfTrack = false

    /// Length of the volume fade at the end, in seconds.
    var fadeDuration: TimeInterval = 10

    /// Set by PlayerViewModel so the timer can pause playback.
    var onFire: (() -> Void)?

    private var timer: Timer?
    private var mixer: AVAudioMixerNode { AuraAudioEngine.shared.engine.mainMixerNode }

    private init() {}

    /// 0...1 elapsed, for the progress ring.
    var progress: Double {
        guard total > 0 else { return 0 }
        return 1 - (remaining / total)
    }

    // MARK: - Control

    func start(minutes: Int) {
        cancel()
        total = TimeInterval(minutes * 60)
        remaining = total
        isActive = true
        stopAtEndOfTrack = false

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func startEndOfTrack() {
        cancel()
        stopAtEndOfTrack = true
        isActive = true
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        isActive = false
        stopAtEndOfTrack = false
        remaining = 0
        total = 0
        mixer.outputVolume = 1      // always restore volume
    }

    /// Called by PlayerViewModel when a track ends naturally.
    /// Returns true if playback should stop instead of advancing.
    func shouldStopAfterTrack() -> Bool {
        guard stopAtEndOfTrack else { return false }
        cancel()
        return true
    }

    // MARK: - Countdown

    private func tick() {
        guard isActive else { return }
        remaining = max(0, remaining - 1)

        // Ramp the mixer down over the final `fadeDuration` seconds.
        if remaining <= fadeDuration {
            mixer.outputVolume = Float(max(0, remaining / fadeDuration))
        }

        if remaining <= 0 {
            fire()
        }
    }

    private func fire() {
        onFire?()
        cancel()                    // also restores volume for the next play
    }

    /// "12:34" style remaining time.
    var remainingText: String {
        let seconds = Int(remaining)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
