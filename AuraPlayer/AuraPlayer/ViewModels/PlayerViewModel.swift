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
    @Published var currentAlbum: String = ""
    @Published var currentArtwork: UIImage?
    @Published private(set) var hasTrack = false
    @Published private(set) var waveform: [Float] = []

    // MARK: - Dependencies

    private let engine = AuraAudioEngine.shared
    private var timer: Timer?
    private var waveformTask: Task<Void, Never>?
    private var trackIndex: [URL: Track] = [:]
    
    /// Fires once per play when the track passes the 30s threshold.
    var onPlayedThreshold: ((URL) -> Void)?
    private var countedThisPlay = false
    private let playCountThreshold: TimeInterval = 30

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
        setupRemoteCommands()

        // Sleep timer pauses playback when it fires.
        SleepTimer.shared.onFire = { [weak self] in
            guard let self, self.isPlaying else { return }
            self.togglePlayPause()
        }
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
        countedThisPlay = false
        
        updateMetadata(for: url)

        startTicking()
        publishNowPlaying()
        loadWaveform(for: url)
    }

    /// Use metadata from the scanned track when we have it, else read tags async.
    private func updateMetadata(for url: URL) {
        if let track = trackIndex[url] {
            currentTitle = track.title
            currentArtist = track.artist
            currentAlbum = track.album
            currentArtwork = track.artworkData.flatMap { UIImage(data: $0) }
        } else {
            currentAlbum = ""
            loadMetadata(for: url)      // fallback for the debug/bundle path
        }
    }

    // MARK: - Crossfade

    private enum CrossfadeKeys {
        static let enabled = "player.crossfadeEnabled"
        static let duration = "player.crossfadeDuration"
    }

    @Published var crossfadeEnabled: Bool = UserDefaults.standard.bool(forKey: CrossfadeKeys.enabled) {
        didSet { UserDefaults.standard.set(crossfadeEnabled, forKey: CrossfadeKeys.enabled) }
    }

    /// Overlap length in seconds (2...12).
    @Published var crossfadeDuration: Double = {
        let stored = UserDefaults.standard.double(forKey: CrossfadeKeys.duration)
        return stored > 0 ? stored : 6
    }() {
        didSet { UserDefaults.standard.set(crossfadeDuration, forKey: CrossfadeKeys.duration) }
    }

    /// The track that would play next, if any.
    private var upcomingTrackURL: URL? {
        guard !queue.isEmpty else { return nil }
        if position < order.count - 1 { return queue[order[position + 1]] }
        if repeatMode == .all, let first = order.first { return queue[first] }
        return nil
    }

    /// Called from the ticker: start overlapping the next track near the end.
    private func beginCrossfadeIfNeeded() {
        guard crossfadeEnabled,
              isPlaying,
              repeatMode != .one,            // repeat-one shouldn't fade into itself
              duration > 0,
              !engine.isCrossfading,
              let nextURL = upcomingTrackURL
        else { return }

        let remaining = duration - currentTime
        guard remaining > 0, remaining <= crossfadeDuration else { return }

        if engine.crossfade(to: nextURL, duration: crossfadeDuration) {
            advancePositionAfterCrossfade()
        }
    }

    /// The engine already switched tracks; move our queue pointer to match.
    private func advancePositionAfterCrossfade() {
        if position < order.count - 1 {
            position += 1
        } else {
            position = 0
        }
        duration = engine.duration
        if let url = currentTrackURL {
            countedThisPlay = false
            updateMetadata(for: url)
            loadWaveform(for: url)
        }
        publishNowPlaying()
    }

    /// Generate the waveform envelope off the main thread; cancels any in-flight job.
    private func loadWaveform(for url: URL) {
        waveformTask?.cancel()
        waveform = []
        waveformTask = Task { [weak self] in
            let points = await WaveformGenerator.generate(url: url)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.waveform = points }
        }
    }

    func togglePlayPause() {
        engine.isPlaying ? engine.pause() : engine.resume()
        isPlaying = engine.isPlaying
        refreshNowPlayingState()
    }

    func stop() {
        engine.stop()
        isPlaying = false
        currentTime = 0
        progress = 0
        hasTrack = false
        currentTitle = ""
        currentArtist = ""
        currentAlbum = ""
        currentArtwork = nil
        waveformTask?.cancel()
        waveform = []
        stopTicking()
        LockScreenManager.shared.clear()
    }

    /// Called by the UI while scrubbing the slider (progress is 0...1).
    func seek(toProgress p: Double) {
        engine.seek(to: p * duration)
        currentTime = p * duration
        progress = p
        refreshNowPlayingState()
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
        // Sleep timer set to "end of track" wins over repeat/advance.
        if SleepTimer.shared.shouldStopAfterTrack() {
            stop()
            return
        }

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
                
                self?.publishNowPlaying()
            }
        }
    }

    // MARK: - Ticking

    private var tickCount = 0
    
    private func startTicking() {
        
        stopTicking()
        // Fires on the main run loop, so UI updates are safe.
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.currentTime = self.engine.currentTime
            self.isPlaying = self.engine.isPlaying
            self.progress = self.duration > 0 ? self.currentTime / self.duration : 0
            
            if !self.countedThisPlay,
               self.currentTime >= self.playCountThreshold,
               let url = self.currentTrackURL {
                self.countedThisPlay = true
                self.onPlayedThreshold?(url)
            }
            
            self.beginCrossfadeIfNeeded()

            self.tickCount += 1
            if self.tickCount % 10 == 0 {      // 0.5s × 10 = every 5s
                self.refreshNowPlayingState()
            }
        }
    }

    private func stopTicking() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Lock screen
    
    private func publishNowPlaying() {
        LockScreenManager.shared.update(
            title: currentTitle,
            artist: currentArtist,
            album: currentAlbum,
            artwork: currentArtwork,
            duration: duration,
            elapsed: currentTime,
            rate: isPlaying ? 1 : 0
        )
    }
    
    private func refreshNowPlayingState() {
        LockScreenManager.shared.updatePlaybackState(
            elapsed: currentTime,
            rate: isPlaying ? 1 : 0
        )
    }

    /// Registering remote commands is what makes iOS treat us as the Now Playing
    /// app — without it, nowPlayingInfo never appears on the lock screen.
    private func setupRemoteCommands() {
        LockScreenManager.shared.configureRemoteCommands(
            LockScreenManager.Handlers(
                play: { [weak self] in
                    guard let self, !self.isPlaying else { return }
                    self.togglePlayPause()
                },
                pause: { [weak self] in
                    guard let self, self.isPlaying else { return }
                    self.togglePlayPause()
                },
                toggle: { [weak self] in self?.togglePlayPause() },
                next: { [weak self] in self?.skipNext() },
                previous: { [weak self] in self?.skipPrevious() },
                seek: { [weak self] time in
                    guard let self, self.duration > 0 else { return }
                    self.seek(toProgress: time / self.duration)
                }
            )
        )
    }

    deinit { stopTicking() }
}
