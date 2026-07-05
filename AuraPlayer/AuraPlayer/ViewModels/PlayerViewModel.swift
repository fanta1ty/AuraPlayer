//
//  PlayerViewModel.swift
//  AuraPlayer
//
//  Created by mobile on 5/7/26.
//
//  Observable playback state for the UI. Polls AuraAudioEngine and
//  publishes currentTime / duration / progress / isPlaying.
//

import Foundation
import Combine

final class PlayerViewModel: ObservableObject {
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var progress: Double = 0 // 0...1, for AuraSlider
    @Published var isPlaying: Bool = false
    
    private let engine = AuraAudioEngine.shared
    private var timer: Timer?
    
    // MARK: - Queue
    @Published var queue: [URL] = []
    @Published private(set) var currentIndex = 0
    
    /// Whether skip wraps at the ends. Left off for now - repeat-all (Task 2.6)
    /// owns looping.
    var wrapAround = false
    
    var currentTrackURL: URL? {
        queue.indices.contains(currentIndex) ? queue[currentIndex] : nil
    }
    
    /// Load a queue and start playing at `index`
    func load(queue: [URL], startAt index: Int = 0) {
        self.queue = queue
        self.currentIndex = index
        engine.onTrackFinished = { [weak self] in
            self?.handleTrackFinished()
        }
        playCurrent()
    }
    
    func skipNext() {
        guard !queue.isEmpty else { return }
        if currentIndex < queue.count - 1 {
            currentIndex += 1
            playCurrent()
        } else if wrapAround {
            currentIndex = 0
            playCurrent()
        } else {
            stop()   // end of queue
        }
    }
    
    func skipPrevious() {
        guard !queue.isEmpty else { return }
        // Standard behavior: restart current track if we're more than 3s in.
        if currentTime > 3 {
            seek(toProgress: 0)
            return
        }
        if currentIndex > 0 {
            currentIndex -= 1
            playCurrent()
        } else if wrapAround {
            currentIndex = queue.count - 1
            playCurrent()
        } else {
            seek(toProgress: 0)   // already first track → just restart it
        }
    }
    
    private func handleTrackFinished() {
        skipNext()   // auto-advance
    }
    
    private func playCurrent() {
        guard let url = currentTrackURL else { return }
        play(url: url) // reuses your existing play(url:) (sets duration, starts ticking)
    }
    
    // MARK: - Transport
    
    func play(url: URL) {
        engine.play(url: url)
        duration = engine.duration
        isPlaying = true
        startTicking()
    }
    
    func togglePlayPause() {
        if engine.isPlaying {
            engine.pause()
        } else {
            engine.resume()
        }
        isPlaying = engine.isPlaying
    }
    
    func stop() {
        engine.stop()
        isPlaying = false
        currentTime = 0
        progress = 0
        stopTicking()
    }
    
    /// Called by the UI while scrubbing the slider (progress is 0...1)
    func seek(toProgress p: Double) {
        engine.seek(to: p * duration)
        currentTime = p * duration
        progress = p
    }
    
    // MARK: - Ticking
    
    private func startTicking() {
        stopTicking()
        
        // Fires on the main run loop, so UI updates are safe.
        timer = Timer
            .scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { [weak self] _ in
                guard let self else { return }
                self.currentTime = self.engine.currentTime
                self.isPlaying = self.engine.isPlaying
                self.progress = self.duration > 0 ? self.currentTime / self.duration : 0
            })
    }
    
    private func stopTicking() {
        timer?.invalidate()
        timer = nil
    }
    
    deinit { stopTicking() }
}
