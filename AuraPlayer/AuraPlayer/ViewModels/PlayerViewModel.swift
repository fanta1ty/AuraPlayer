//
//  PlayerViewModel.swift
//  AuraPlayer
//
//  Created by mobile on 5/7/26.
//
//  Observable playback state for the UI. Polls AuraAudioEngine and
//  publishes currentTime / duration / progress / isPlaying, and owns the queue.
//

import AVFoundation
import UIKit
import Foundation
import Combine

enum RepeatMode {
    case none, one, all
}

final class PlayerViewModel: ObservableObject {

    // MARK: - Published state

    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var progress: Double = 0            // 0...1, for AuraSlider
    @Published var isPlaying = false

    @Published var queue: [URL] = []               // original order (never mutated by shuffle)
    @Published private(set) var order: [Int] = []  // play sequence: indices into `queue`
    @Published private(set) var position = 0       // index into `order`
    @Published var repeatMode: RepeatMode = .none
    @Published private(set) var isShuffled = false
    
    @Published var currentTitle: String = ""
    @Published var currentArtist: String = ""
    @Published var currentArtwork: UIImage?
    @Published private(set) var hasTrack = false

    // MARK: - Dependencies

    private let engine = AuraAudioEngine.shared
    private var timer: Timer?

    var currentTrackURL: URL? {
        guard order.indices.contains(position),
              queue.indices.contains(order[position]) else { return nil }
        return queue[order[position]]
    }

    // MARK: - Loading

    /// Load a queue and start playing at `index`.
    func load(queue: [URL], startAt index: Int = 0) {
        self.queue = queue
        self.order = Array(queue.indices)
        self.position = index
        self.isShuffled = false
        engine.onTrackFinished = { [weak self] in self?.handleTrackFinished() }
        playCurrent()
    }

    private func playCurrent() {
        guard let url = currentTrackURL else { return }
        play(url: url)
    }

    // MARK: - Transport

    func play(url: URL) {
        engine.play(url: url)
        duration = engine.duration
        isPlaying = true
        hasTrack = true
        loadMetadata(for: url)
        startTicking()
    }

    func togglePlayPause() {
        engine.isPlaying ? engine.pause() : engine.resume()
        isPlaying = engine.isPlaying
    }

    func stop() {
        engine.stop()
        isPlaying = false
        currentTime = 0
        progress = 0
        hasTrack = false
        currentTitle = ""
        currentArtist = ""
        currentArtwork = nil
        stopTicking()
    }

    /// Called by the UI while scrubbing the slider (progress is 0...1).
    func seek(toProgress p: Double) {
        engine.seek(to: p * duration)
        currentTime = p * duration
        progress = p
    }

    // MARK: - Queue navigation

    func skipNext() {
        guard !queue.isEmpty else { return }
        if position < order.count - 1 {
            position += 1
            playCurrent()
        } else if repeatMode == .all {
            position = 0
            playCurrent()
        } else {
            stop()                       // end of queue
        }
    }

    func skipPrevious() {
        guard !queue.isEmpty else { return }
        if currentTime > 3 {             // restart current track if >3s in
            seek(toProgress: 0)
            return
        }
        if position > 0 {
            position -= 1
            playCurrent()
        } else if repeatMode == .all {
            position = order.count - 1
            playCurrent()
        } else {
            seek(toProgress: 0)
        }
    }

    private func handleTrackFinished() {
        switch repeatMode {
        case .one:
            playCurrent()                // replay same track indefinitely
        case .none, .all:
            skipNext()                   // .all wraps, .none stops at end
        }
    }

    // MARK: - Shuffle & Repeat

    func toggleShuffle() {
        guard !queue.isEmpty else { isShuffled.toggle(); return }
        let currentTrack = order.indices.contains(position) ? order[position] : 0

        if !isShuffled {
            // Turn ON: keep current track first, shuffle the rest.
            var rest = Array(queue.indices).filter { $0 != currentTrack }
            rest.shuffle()
            order = [currentTrack] + rest
            position = 0
        } else {
            // Turn OFF: restore original order, stay on the same track.
            order = Array(queue.indices)
            position = currentTrack
        }
        isShuffled.toggle()
    }

    func cycleRepeatMode() {
        switch repeatMode {
        case .none: repeatMode = .one
        case .one:  repeatMode = .all
        case .all:  repeatMode = .none
        }
    }
    
    // MARK: - Metadata
    
    private func loadMetadata(for url: URL) {
        // Immediate fallback so the UI never shows empty.
        currentTitle = url.deletingPathExtension().lastPathComponent
        currentArtist = "Unknown Artist"
        currentArtwork = nil
        
        let asset = AVURLAsset(url: url)
        Task { [weak self] in
            guard let items = try? await asset.load(.commonMetadata) else { return }
            var title: String?
            var artist: String?
            var artwork: UIImage?
            
            for item in items {
                switch item.commonKey {
                case .commonKeyTitle: title = try? await item.load(.stringValue)
                case .commonKeyArtist: artist = try? await item.load(.stringValue)
                case .commonKeyArtwork:
                    if let data = try? await item.load(.dataValue) {
                        artwork = UIImage(data: data)
                    }
                default: break
                }
            }
            
            await MainActor.run {
                if let title, !title.isEmpty { self?.currentTitle = title }
                if let artist, !artist.isEmpty { self?.currentArtist = artist }
                if let artwork { self?.currentArtwork = artwork }
            }
        }
    }

    // MARK: - Ticking

    private func startTicking() {
        stopTicking()
        // Fires on the main run loop, so UI updates are safe.
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.currentTime = self.engine.currentTime
            self.isPlaying = self.engine.isPlaying
            self.progress = self.duration > 0 ? self.currentTime / self.duration : 0
        }
    }

    private func stopTicking() {
        timer?.invalidate()
        timer = nil
    }

    deinit { stopTicking() }
}
