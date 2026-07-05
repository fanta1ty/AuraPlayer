//
//  AuraAudioEngine.swift
//  AuraPlayer
//
//  Created by mobile on 5/7/26.
//
//  Core AVAudioEngine graph: PlayerNode -> mainMixerNode -> outputNode.
//  EQ nodes will be inserted between player and mixer in a later phase.
//

import Foundation
import AVFoundation

final class AuraAudioEngine {
    static let shared = AuraAudioEngine()
    
    let engine = AVAudioEngine()
    let playerNode = AVAudioPlayerNode()
    
    /// Format used to connect the graph. Set when a file is loaded (Task 2.3);
    /// nil means "use the output's native format" for the initial wiring.
    private var currentFormat: AVAudioFormat?
    
    private init() {
        buildGraph()
        registerObservers()
    }
    
    // MARK: - Graph
    
    private func buildGraph() {
        engine.attach(playerNode)
        
        // Connect player -> mixer using a format. Nil lets the engine pick the
        // mixer's default; when we load a real file we reconnect with its format.
        let format = currentFormat
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        
        // mainMixerNode -> outputNode is connected by the engine autimatically,
        // but referencing outputNode here ensures the graph is realized.
        _ = engine.outputNode
    }
    
    /// Reconnect the player node with a specific file format (called from play())
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
    private var audioFile: AVAudioFile?
    
    // Time tracking
    private var sampleRate: Double = 44_100
    private var lengthSamples: AVAudioFramePosition = 0
    private var seekFrame: AVAudioFramePosition = 0
    
    /// Total duration of the loaded file, in seconds.
    var duration: TimeInterval {
        guard sampleRate > 0 else { return 0 }
        return Double(lengthSamples) / sampleRate
    }
    
    /// Current playback position, in seconds
    var currentTime: TimeInterval {
        guard let nodeTime = playerNode.lastRenderTime, let playerTime = playerNode.playerTime(
            forNodeTime: nodeTime
        ) else {
            return Double(seekFrame) / sampleRate
        }
        let current = Double(seekFrame + playerTime.sampleTime) / sampleRate
        return min(max(current, 0), duration)
    }
    
    /// Fires when a track finishes playing naturally (not via stop/seek/skip)
    var onTrackFinished: (() -> Void)?
    
    /// Bumped every time we stop/seek/reschedule so stale completions are ignored.
    private var playGeneration = 0
    
    /// Load and play a local audio file from the given URL.
    func play(url: URL) {
        do {
            let file = try AVAudioFile(forReading: url)
            audioFile = file
            sampleRate = file.processingFormat.sampleRate
            lengthSamples = file.length
            seekFrame = 0
            
            // Reconnect the graph to match this file's format, then ensure running.
            reconnect(with: file.processingFormat)
            start()
            
            playGeneration += 1
            let gen = playGeneration
            
            // Schedule the whole file, then play.
            playerNode.stop()
            playerNode.scheduleFile(file, at: nil) { [weak self] in
                guard let self else { return }
                print("ℹ️ Finished playing: \(url.lastPathComponent)")
                
                DispatchQueue.main.async {
                    guard gen == self.playGeneration else { return } // stale -> ignore
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
        playerNode
            .scheduleSegment(
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
    
    var isPlaying: Bool { playerNode.isPlaying }

    
    // MARK: - Configuration changes
    
    private func registerObservers() {
        NotificationCenter.default
            .addObserver(
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
