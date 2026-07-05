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
