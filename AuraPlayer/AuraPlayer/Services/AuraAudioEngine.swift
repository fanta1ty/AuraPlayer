//
//  AuraAudioEngine.swift
//  AuraPlayer
//
//  Created by mobile on 5/7/26.
//
//  Dual-player graph so tracks can overlap for crossfade:
//
//      player[0] -> mixer[0] ─┐
//                             ├─> eqNode -> mainMixerNode -> output
//      player[1] -> mixer[1] ─┘
//
//  Only the player->mixer edge is format-specific; the EQ always sees one
//  canonical format, so it is never rewired mid-playback.
//

import Foundation
import AVFoundation

final class AuraAudioEngine {

    static let shared = AuraAudioEngine()

    // MARK: - Nodes

    let engine = AVAudioEngine()
    let eqNode = AVAudioUnitEQ(numberOfBands: 10)

    private let players = [AVAudioPlayerNode(), AVAudioPlayerNode()]
    private let mixers  = [AVAudioMixerNode(), AVAudioMixerNode()]
    /// Sums both players before the EQ — effect nodes only accept one input.
    private let submix  = AVAudioMixerNode()
    /// Independent pitch (cents) and tempo (rate) control.
    let timePitchNode = AVAudioUnitTimePitch()

    /// Standard 10-band graphic EQ centers (Hz).
    static let eqFrequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

    // MARK: - Slot state

    private struct Slot {
        var file: AVAudioFile?
        var format: AVAudioFormat?          // format this slot is currently wired for
        var sampleRate: Double = 44_100
        var lengthSamples: AVAudioFramePosition = 0
        var seekFrame: AVAudioFramePosition = 0
        var generation = 0
    }

    private var slots = [Slot(), Slot()]
    private var activeIndex = 0
    private var inactiveIndex: Int { 1 - activeIndex }

    private var crossfadeTimer: Timer?
    private(set) var isCrossfading = false

    /// Fires when the ACTIVE track finishes naturally (not via stop/seek/skip).
    var onTrackFinished: (() -> Void)?

    private init() {
        buildGraph()
        registerObservers()
    }

    // MARK: - Convenience accessors

    /// The node currently responsible for playback.
    var playerNode: AVAudioPlayerNode { players[activeIndex] }

    var isPlaying: Bool { playerNode.isPlaying }

    var duration: TimeInterval {
        let slot = slots[activeIndex]
        guard slot.sampleRate > 0 else { return 0 }
        return Double(slot.lengthSamples) / slot.sampleRate
    }

    var currentTime: TimeInterval {
        let slot = slots[activeIndex]
        let node = players[activeIndex]
        guard
            let nodeTime = node.lastRenderTime,
            let playerTime = node.playerTime(forNodeTime: nodeTime)
        else {
            return Double(slot.seekFrame) / slot.sampleRate
        }
        let current = Double(slot.seekFrame + playerTime.sampleTime) / slot.sampleRate
        return min(max(current, 0), duration)
    }

    // MARK: - Graph

    private func buildGraph() {
        // Attach everything first — connecting an unattached node traps.
        engine.attach(eqNode)
        engine.attach(submix)
        engine.attach(timePitchNode)
        for index in 0..<2 {
            engine.attach(players[index])
            engine.attach(mixers[index])
        }

        configureEQBands()

        // players -> per-track mixers -> submix -> EQ -> main mixer -> output
        for index in 0..<2 {
            engine.connect(players[index], to: mixers[index], format: nil)
            engine.connect(mixers[index], to: submix, format: nil)
            mixers[index].outputVolume = index == 0 ? 1 : 0
        }
        engine.connect(submix, to: timePitchNode, format: nil)
        engine.connect(timePitchNode, to: eqNode, format: nil)
        engine.connect(eqNode, to: engine.mainMixerNode, format: nil)
        _ = engine.outputNode
    }

    /// Flat 10-band parametric EQ, 1 octave wide per band.
    private func configureEQBands() {
        for (index, band) in eqNode.bands.enumerated() {
            band.filterType = .parametric
            band.frequency = Self.eqFrequencies[index]
            band.bandwidth = 1.0
            band.gain = 0.0
            band.bypass = false
        }
        eqNode.globalGain = 0.0
        eqNode.bypass = false
    }

    /// Wire one player to its mixer for a specific file format.
    /// Returns false if a rewire was needed but the engine is mid-crossfade.
    @discardableResult
    private func wire(slot index: Int, format: AVAudioFormat) -> Bool {
        if let existing = slots[index].format, existing == format { return true }

        // Reconnecting requires a brief stop; never do that during a crossfade.
        if isCrossfading { return false }

        let wasRunning = engine.isRunning
        engine.stop()
        engine.disconnectNodeOutput(players[index])
        engine.connect(players[index], to: mixers[index], format: format)
        slots[index].format = format
        if wasRunning { start() }
        return true
    }

    // MARK: - Lifecycle

    @discardableResult
    func start() -> Bool {
        guard !engine.isRunning else { return true }
        do {
            engine.prepare()
            try engine.start()
            return true
        } catch {
            print("⚠️ AuraAudioEngine failed to start: \(error)")
            return false
        }
    }

    func stopEngine() { engine.stop() }

    // MARK: - Playback

    /// Load and play immediately on the active slot (hard switch).
    func play(url: URL) {
        cancelCrossfade()

        do {
            let file = try AVAudioFile(forReading: url)
            let index = activeIndex

            slots[index].file = file
            slots[index].sampleRate = file.processingFormat.sampleRate
            slots[index].lengthSamples = file.length
            slots[index].seekFrame = 0

            players[inactiveIndex].stop()
            mixers[inactiveIndex].outputVolume = 0
            mixers[index].outputVolume = 1

            wire(slot: index, format: file.processingFormat)
            start()

            schedule(file: file, slot: index, startingFrame: nil)
            players[index].play()
            print("▶️ Playing: \(url.lastPathComponent)")
        } catch {
            print("⚠️ Could not load audio file at \(url.lastPathComponent): \(error)")
        }
    }

    /// Begin overlapping the next track. Returns false if a crossfade isn't
    /// possible right now (already fading, or the file needs a graph rewire).
    @discardableResult
    func crossfade(to url: URL, duration: TimeInterval) -> Bool {
        guard !isCrossfading, duration > 0 else { return false }

        guard let file = try? AVAudioFile(forReading: url) else { return false }
        let next = inactiveIndex

        // A format change needs an engine stop, which would break the overlap.
        guard wire(slot: next, format: file.processingFormat) else { return false }

        slots[next].file = file
        slots[next].sampleRate = file.processingFormat.sampleRate
        slots[next].lengthSamples = file.length
        slots[next].seekFrame = 0

        schedule(file: file, slot: next, startingFrame: nil)
        mixers[next].outputVolume = 0
        start()
        players[next].play()

        let outgoing = activeIndex
        activeIndex = next              // time/seek now follow the new track
        isCrossfading = true
        ramp(from: outgoing, to: next, duration: duration)
        print("🔀 Crossfading to: \(url.lastPathComponent)")
        return true
    }

    private func ramp(from outgoing: Int, to incoming: Int, duration: TimeInterval) {
        let step: TimeInterval = 0.05
        var elapsed: TimeInterval = 0

        crossfadeTimer?.invalidate()
        crossfadeTimer = Timer.scheduledTimer(withTimeInterval: step, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            elapsed += step
            let t = Float(min(1, elapsed / duration))
            self.mixers[outgoing].outputVolume = 1 - t
            self.mixers[incoming].outputVolume = t

            if t >= 1 {
                timer.invalidate()
                self.crossfadeTimer = nil
                self.players[outgoing].stop()
                self.slots[outgoing].file = nil
                self.isCrossfading = false
            }
        }
    }

    private func cancelCrossfade() {
        crossfadeTimer?.invalidate()
        crossfadeTimer = nil
        isCrossfading = false
    }

    /// Schedule a file (or segment) on a slot, firing onTrackFinished only if
    /// that slot is still the active one when it completes.
    private func schedule(file: AVAudioFile, slot index: Int, startingFrame: AVAudioFramePosition?) {
        slots[index].generation += 1
        let gen = slots[index].generation

        let completion: () -> Void = { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async {
                guard gen == self.slots[index].generation else { return }  // stale
                guard index == self.activeIndex else { return }            // outgoing track
                self.onTrackFinished?()
            }
        }

        players[index].stop()
        if let startingFrame {
            let frames = slots[index].lengthSamples - startingFrame
            guard frames > 0 else { return }
            players[index].scheduleSegment(file,
                                           startingFrame: startingFrame,
                                           frameCount: AVAudioFrameCount(frames),
                                           at: nil,
                                           completionHandler: completion)
        } else {
            players[index].scheduleFile(file, at: nil, completionHandler: completion)
        }
    }

    /// Seek within the active track.
    func seek(to time: TimeInterval) {
        let index = activeIndex
        guard let file = slots[index].file else { return }
        let wasPlaying = players[index].isPlaying
        let newFrame = AVAudioFramePosition(max(0, time) * slots[index].sampleRate)
        guard slots[index].lengthSamples - newFrame > 0 else { return }

        slots[index].seekFrame = newFrame
        schedule(file: file, slot: index, startingFrame: newFrame)

        if wasPlaying {
            start()
            players[index].play()
        }
    }

    func pause() {
        playerNode.pause()
    }

    func resume() {
        start()
        playerNode.play()
    }

    func stop() {
        cancelCrossfade()
        for index in 0..<2 {
            slots[index].generation += 1
            players[index].stop()
            slots[index].file = nil
        }
        mixers[activeIndex].outputVolume = 1
        mixers[inactiveIndex].outputVolume = 0
    }

    // MARK: - Configuration changes

    private func registerObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConfigChange(_:)),
            name: .AVAudioEngineConfigurationChange,
            object: engine
        )
    }

    @objc private func handleConfigChange(_ notification: Notification) {
        print("ℹ️ Engine configuration changed — rebuilding graph.")
        let wasRunning = engine.isRunning
        buildGraph()
        if wasRunning { start() }
    }
}
