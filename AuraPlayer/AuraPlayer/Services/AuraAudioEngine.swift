//
//  AuraAudioEngine.swift
//  AuraPlayer
//
//  Created by mobile on 5/7/26.
//
//  Core AVAudioEngine graph: playerNode -> mainMixerNode -> outputNode.
//  EQ nodes will be inserted between player and mixer in a later phase.
//

import Foundation
import AVFoundation

final class AuraAudioEngine {

    static let shared = AuraAudioEngine()

    // MARK: - Nodes

    let engine = AVAudioEngine()
    let playerNode = AVAudioPlayerNode()

    // MARK: - State

    private var currentFormat: AVAudioFormat?        // format used to wire the graph
    private var audioFile: AVAudioFile?              // currently loaded file

    // Time tracking
    private var sampleRate: Double = 44_100
    private var lengthSamples: AVAudioFramePosition = 0
    private var seekFrame: AVAudioFramePosition = 0

    /// Bumped on every stop/seek/reschedule so stale completions are ignored.
    private var playGeneration = 0

    /// Fires when a track finishes playing naturally (not via stop/seek/skip).
    var onTrackFinished: (() -> Void)?

    private init() {
        buildGraph()
        registerObservers()
    }

    // MARK: - Derived state

    var isPlaying: Bool { playerNode.isPlaying }

    /// Total duration of the loaded file, in seconds.
    var duration: TimeInterval {
        guard sampleRate > 0 else { return 0 }
        return Double(lengthSamples) / sampleRate
    }

    /// Current playback position, in seconds.
    var currentTime: TimeInterval {
        guard
            let nodeTime = playerNode.lastRenderTime,
            let playerTime = playerNode.playerTime(forNodeTime: nodeTime)
        else {
            return Double(seekFrame) / sampleRate
        }
        let current = Double(seekFrame + playerTime.sampleTime) / sampleRate
        return min(max(current, 0), duration)
    }

    // MARK: - Graph

    private func buildGraph() {
        engine.attach(playerNode)
        // nil format = engine picks the mixer's default; we reconnect per-file in reconnect(with:).
        engine.connect(playerNode, to: engine.mainMixerNode, format: currentFormat)
        _ = engine.outputNode   // referencing realizes the graph
    }

    /// Reconnect the player node with a specific file format (called from play()).
    func reconnect(with format: AVAudioFormat) {
        currentFormat = format
        engine.disconnectNodeOutput(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
    }

    // MARK: - Lifecycle

    /// Start the engine. Safe to call multiple times.
    @discardableResult
    func start() -> Bool {
        guard !engine.isRunning else { return true }
        do {
            engine.prepare()
            try engine.start()
            print("✅ AuraAudioEngine started. isRunning = \(engine.isRunning)")
            return true
        } catch {
            print("⚠️ AuraAudioEngine failed to start: \(error)")
            return false
        }
    }

    func stopEngine() {
        engine.stop()
    }

    // MARK: - Playback

    /// Load and play a local audio file.
    func play(url: URL) {
        do {
            let file = try AVAudioFile(forReading: url)
            audioFile = file
            sampleRate = file.processingFormat.sampleRate
            lengthSamples = file.length
            seekFrame = 0

            reconnect(with: file.processingFormat)
            start()

            playGeneration += 1
            let gen = playGeneration
            playerNode.stop()
            playerNode.scheduleFile(file, at: nil) { [weak self] in
                guard let self else { return }
                DispatchQueue.main.async {
                    guard gen == self.playGeneration else { return }   // stale -> ignore
                    print("ℹ️ Finished playing: \(url.lastPathComponent)")
                    self.onTrackFinished?()
                }
            }
            playerNode.play()
            print("▶️ Playing: \(url.lastPathComponent)")
        } catch {
            print("⚠️ Could not load audio file at \(url.lastPathComponent): \(error)")
        }
    }

    /// Seek to a time offset. Works while playing or paused.
    func seek(to time: TimeInterval) {
        guard let file = audioFile else { return }
        let wasPlaying = playerNode.isPlaying
        let newFrame = AVAudioFramePosition(max(0, time) * sampleRate)
        let framesToPlay = lengthSamples - newFrame
        guard framesToPlay > 0 else { return }

        playGeneration += 1
        let gen = playGeneration
        playerNode.stop()
        seekFrame = newFrame
        playerNode.scheduleSegment(
            file,
            startingFrame: newFrame,
            frameCount: AVAudioFrameCount(framesToPlay),
            at: nil
        ) { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async {
                guard gen == self.playGeneration else { return }
                self.onTrackFinished?()
            }
        }

        if wasPlaying {
            start()
            playerNode.play()
        }
    }

    func pause() {
        playerNode.pause()
        print("⏸️ Paused")
    }

    func resume() {
        start()
        playerNode.play()
        print("▶️ Resumed")
    }

    func stop() {
        playGeneration += 1
        playerNode.stop()
        audioFile = nil
        print("⏹️ Stopped")
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
        // The graph was reset (e.g. output device changed). Rebuild & restart.
        print("ℹ️ Engine configuration changed — rebuilding graph.")
        let wasRunning = engine.isRunning
        buildGraph()
        if wasRunning { start() }
    }
}
