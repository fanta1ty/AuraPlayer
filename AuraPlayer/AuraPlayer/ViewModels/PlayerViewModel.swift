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
import Combine
import SwiftUI

enum RepeatMode: Int {
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
    @Published var repeatMode: RepeatMode = .none {
        didSet {
            UserDefaults.standard
                .set(repeatMode.rawValue, forKey: Keys.repeatMode)
        }
    }
    @Published private(set) var isShuffled = false {
        didSet {
            UserDefaults.standard.set(isShuffled, forKey: Keys.isShuffled)
        }
    }
    
    @Published var currentTitle: String = ""
    @Published var currentArtist: String = ""
    @Published var currentArtwork: UIImage?
    @Published private(set) var hasTrack = false

    // MARK: - Dependencies

    private let engine = AuraAudioEngine.shared
    private var timer: Timer?
    private var trackIndex: [URL: Track] = [:]

    var currentTrackURL: URL? {
        guard order.indices.contains(position),
              queue.indices.contains(order[position]) else { return nil }
        return queue[order[position]]
    }
    
    private enum Keys {
        static let repeatMode = "player.repeatMode"
        static let isShuffled = "player.isShuffled"
    }
    
    init() {
        let defaults = UserDefaults.standard
        repeatMode = RepeatMode(
            rawValue: defaults.integer(forKey: Keys.repeatMode)
        ) ?? .none
        isShuffled = defaults.bool(forKey: Keys.isShuffled)
    }

    // MARK: - Loading

    /// Load a queue and start playing at `index`.
    func load(queue: [URL], startAt index: Int = 0) {
        self.queue = queue
        engine.onTrackFinished = { [weak self] in self?.handleTrackFinished() }
        
        let start = queue.indices.contains(index) ? index : 0
        if isShuffled {
            var rest = Array(queue.indices).filter { $0 != start }
            rest.shuffle()
            order = [start] + rest
            position = 0
        } else {
            order = Array(queue.indices)
            position = start
        }
        playCurrent()
    }
    
    /// Load a list of already-scanned tracks as the queue.
    func load(tracks: [Track], startAt index: Int = 0) {
        trackIndex = Dictionary(tracks.map({
            ($0.url, $0)
        }), uniquingKeysWith: { a, _ in
            a
        })
        load(queue: tracks.map(\.url), startAt: index)
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
        
        if let track = trackIndex[url] {
            currentTitle = track.title
            currentArtist = track.artist
            currentArtwork = track.artworkData.flatMap({
                UIImage(data: $0)
            })
        } else {
            loadMetadata(for: url) // fallback for the debug/bundle path
        }
        
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
    
    // MARK: - Queue editing (for QueueView)
    
    struct QueueItem: Identifiable {
        let id: Int             // stable = queue index (unique even with duplicate URLs)
        let url: URL
        let orderIndex: Int     // position within `order`
        let isCurrent: Bool
        var title: String { url.deletingPathExtension().lastPathComponent }
    }
    
    /// The play sequence as display items.
    var queueItems: [QueueItem] {
        order.enumerated().map { i, qIdx in
            QueueItem(
                id: qIdx,
                url: queue[qIdx],
                orderIndex: i,
                isCurrent: i == position
            )
        }
    }
    
    func playQueueItem(at orderIndex: Int) {
        guard order.indices.contains(orderIndex) else { return }
        position = orderIndex
        playCurrent()
    }
    
    func moveQueueItem(from source: IndexSet, to destination: Int) {
        let currentQIdx = order.indices.contains(position) ? order[position] : nil
        order.move(fromOffsets: source, toOffset: destination)
        if let cur = currentQIdx, let newPos = order.firstIndex(of: cur) {
            position = newPos // keep pointing at the playing track
        }
    }
    
    func removeQueueItems(at offsets: IndexSet) {
        let removingCurrent = offsets.contains(position)
        let currentQIdx = order.indices.contains(position) ? order[position] : nil
        
        order.remove(atOffsets: offsets)
        
        if order.isEmpty {
            stop()
        } else if removingCurrent {
            position = min(position, order.count - 1)
            playCurrent() // current was removed → play the new one at this slot
        } else if let cur = currentQIdx, let newPos = order.firstIndex(
            of: cur
        ) {
            position = newPos
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
