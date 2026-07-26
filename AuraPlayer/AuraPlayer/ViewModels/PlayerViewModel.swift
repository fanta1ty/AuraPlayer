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

/// How one track hands over to the next.
enum TrackTransition: String, CaseIterable, Identifiable {
    /// Next track starts after the previous fully stops (small gap).
    case none
    /// Next track is scheduled to the exact sample the previous ends — no gap.
    case gapless
    /// Tracks overlap with a volume ramp.
    case crossfade

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none:      return "Off"
        case .gapless:   return "Gapless"
        case .crossfade: return "Crossfade"
        }
    }
}

@MainActor
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

    /// Asked for a saved position when a long track starts. Return nil to start at 0.
    var resumePositionProvider: ((URL, TimeInterval) -> TimeInterval?)?
    /// Called periodically so the current position can be remembered.
    var onPositionChanged: ((URL, TimeInterval, TimeInterval) -> Void)?
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
        static let playbackRate = "player.playbackRate"
        static let pitchSemitones = "player.pitchSemitones"
    }

    init() {
        let defaults = UserDefaults.standard
        repeatMode = RepeatMode(
            rawValue: defaults.integer(forKey: Keys.repeatMode)
        ) ?? .none
        isShuffled = defaults.bool(forKey: Keys.isShuffled)
        restoreSpeedSettings()
        setupRemoteCommands()

        // Sleep timer pauses playback when it fires.
        SleepTimer.shared.onFire = { [weak self] in
            guard let self, self.isPlaying else { return }
            self.togglePlayPause()
        }

        setupSessionHandling()
    }

    /// Phone calls, Siri, and unplugged headphones must pause playback —
    /// otherwise audio suddenly blasts from the speaker.
    private func setupSessionHandling() {
        let session = AudioSessionManager.shared

        // Notifications can arrive off the main thread, so hop explicitly.
        session.onShouldPause = { [weak self] in
            Task { @MainActor in
                guard let self, self.isPlaying else { return }
                self.wasPlayingBeforeInterruption = true
                self.togglePlayPause()
            }
        }

        session.onMayResume = { [weak self] in
            Task { @MainActor in
                guard let self,
                      self.wasPlayingBeforeInterruption,
                      !self.isPlaying else { return }
                self.wasPlayingBeforeInterruption = false
                self.togglePlayPause()
            }
        }
    }

    /// Only auto-resume after an interruption if we were actually playing.
    private var wasPlayingBeforeInterruption = false

    // MARK: - Speed & pitch

    /// Tempo multiplier, pitch preserved. Deliberately global rather than
    /// per-track: someone listening to a long mix at 1.25× wants it to stay
    /// there across the whole session.
    @Published var playbackRate: Float = 1.0 {
        didSet {
            guard playbackRate != oldValue else { return }
            engine.rate = playbackRate
            UserDefaults.standard.set(playbackRate, forKey: Keys.playbackRate)
            // The lock screen scrubber advances at whatever rate we report,
            // so it drifts badly if we keep claiming 1×.
            refreshNowPlayingState()
        }
    }

    /// Pitch shift in semitones, tempo unaffected. Useful for transposing a
    /// backing track to a comfortable key.
    @Published var pitchSemitones: Float = 0 {
        didSet {
            guard pitchSemitones != oldValue else { return }
            engine.pitchCents = pitchSemitones * 100
            UserDefaults.standard.set(pitchSemitones, forKey: Keys.pitchSemitones)
        }
    }

    var isSpeedNeutral: Bool { playbackRate == 1 && pitchSemitones == 0 }

    func resetSpeed() {
        playbackRate = 1
        pitchSemitones = 0
    }

    private func restoreSpeedSettings() {
        let defaults = UserDefaults.standard

        // float(forKey:) returns 0 for a missing key, which would mean
        // silence — so check the key exists before trusting it.
        let storedRate = defaults.object(forKey: Keys.playbackRate) == nil
            ? 1.0
            : defaults.float(forKey: Keys.playbackRate)
        playbackRate = storedRate.clamped(to: AuraAudioEngine.rateRange)
        pitchSemitones = defaults.float(forKey: Keys.pitchSemitones).clamped(to: -12...12)

        // Push explicitly: the engine is a singleton that outlives this
        // view model, so it may still hold settings from a previous instance.
        engine.rate = playbackRate
        engine.pitchCents = pitchSemitones * 100
    }

    // MARK: - Loading

    /// Load a queue and start playing at `index`.
    func load(queue: [URL], startAt index: Int = 0) {
        self.queue = queue
        engine.onTrackFinished = { [weak self] in self?.handleTrackFinished() }
        engine.onGaplessAdvance = { [weak self] in self?.handleGaplessAdvance() }
        
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
        crossfadeRejectedURL = nil      // new track, allow fading again
        gaplessArmed = false

        updateMetadata(for: url)

        startTicking()
        publishNowPlaying()
        loadWaveform(for: url)
        applyNormalization(for: url)
        loadLyrics(for: url)

        // Long files (mixes, live sets) pick up where they were left off.
        if let resume = resumePositionProvider?(url, duration), resume > 0 {
            seek(toProgress: duration > 0 ? resume / duration : 0)
        }
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

    // MARK: - Session restore

    /// Snapshot the queue so the app can reopen where it left off.
    func saveSession() {
        guard !queue.isEmpty, !order.isEmpty else {
            PlaybackSessionStore.clear()
            return
        }
        PlaybackSessionStore.save(
            PlaybackSession(
                queueFilenames: queue.map(\.lastPathComponent),
                order: order,
                position: position,
                elapsed: currentTime,
                isShuffled: isShuffled,
                repeatModeRaw: repeatMode.rawValue,
                savedAt: .now
            )
        )
    }

    /// Rebuild the last session from the scanned library. Leaves playback
    /// paused at the saved position — reopening an app shouldn't blast audio.
    func restoreSession(from tracks: [Track]) {
        guard queue.isEmpty,                     // don't clobber an active queue
              let session = PlaybackSessionStore.load()
        else { return }

        // Resolve filenames against the library; files may have been deleted.
        let byName = Dictionary(tracks.map { ($0.url.lastPathComponent, $0) },
                                uniquingKeysWith: { a, _ in a })

        var resolved: [Track] = []
        var oldToNew: [Int: Int] = [:]           // old queue index -> new index
        for (oldIndex, name) in session.queueFilenames.enumerated() {
            guard let track = byName[name] else { continue }
            oldToNew[oldIndex] = resolved.count
            resolved.append(track)
        }
        guard !resolved.isEmpty else {
            PlaybackSessionStore.clear()
            return
        }

        // Remap the play order, dropping anything that no longer exists.
        let newOrder = session.order.compactMap { oldToNew[$0] }
        guard !newOrder.isEmpty else {
            PlaybackSessionStore.clear()
            return
        }

        trackIndex = Dictionary(resolved.map { ($0.url, $0) }, uniquingKeysWith: { a, _ in a })
        queue = resolved.map(\.url)
        order = newOrder
        // The saved track may have been removed — fall back to the start.
        position = min(session.position, newOrder.count - 1)
        isShuffled = session.isShuffled
        repeatMode = session.repeatMode

        guard let url = currentTrackURL else { return }

        let resumeAt = session.elapsed
        guard engine.prepare(url: url, startAt: resumeAt) else { return }

        duration = engine.duration
        currentTime = resumeAt
        progress = duration > 0 ? resumeAt / duration : 0
        isPlaying = false
        hasTrack = true
        countedThisPlay = resumeAt >= playCountThreshold

        engine.onTrackFinished = { [weak self] in self?.handleTrackFinished() }
        engine.onGaplessAdvance = { [weak self] in self?.handleGaplessAdvance() }

        updateMetadata(for: url)
        publishNowPlaying()
        loadWaveform(for: url)
        applyNormalization(for: url)
        loadLyrics(for: url)
        startTicking()          // keeps the lock screen and UI in sync
    }

    // MARK: - Lyrics

    @Published private(set) var lyrics = Lyrics(lines: [])
    @Published private(set) var isLoadingLyrics = false
    private var lyricsTask: Task<Void, Never>?

    /// Re-read lyrics for the current track (after editing a sidecar .lrc).
    func reloadLyrics() {
        guard let url = currentTrackURL else { return }
        loadLyrics(for: url)
    }

    private func loadLyrics(for url: URL) {
        lyricsTask?.cancel()
        lyrics = Lyrics(lines: [])

        guard let track = trackIndex[url] else { return }
        isLoadingLyrics = true

        lyricsTask = Task { [weak self] in
            let found = await LyricsProvider.lyrics(for: track)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.currentTrackURL == url else { return }
                self.lyrics = found
                self.isLoadingLyrics = false
            }
        }
    }

    // MARK: - Volume normalization (ReplayGain)

    private static let normalizationKey = "player.volumeNormalization"

    @Published var normalizationEnabled: Bool =
        UserDefaults.standard.bool(forKey: PlayerViewModel.normalizationKey) {
        didSet {
            UserDefaults.standard.set(normalizationEnabled, forKey: Self.normalizationKey)
            if !normalizationEnabled { engine.setGainDB(0) }
            else if let url = currentTrackURL { applyNormalization(for: url) }
        }
    }

    /// Analysis is cached, so this is usually instant after the first play.
    private func applyNormalization(for url: URL) {
        guard normalizationEnabled else {
            engine.setGainDB(0)
            return
        }
        Task { [weak self] in
            let gain = await LoudnessAnalyzer.gain(for: url)
            await MainActor.run {
                guard let self, self.currentTrackURL == url else { return }
                self.engine.setGainDB(gain)
            }
        }
    }

    /// Cached gain only — used when starting a crossfade, where we can't wait.
    private func cachedGain(for url: URL) async -> Float {
        guard normalizationEnabled else { return 0 }
        return await LoudnessAnalyzer.gain(for: url)
    }

    // MARK: - A-B repeat

    @Published private(set) var loopStart: TimeInterval?
    @Published private(set) var loopEnd: TimeInterval?

    var isLooping: Bool { loopStart != nil && loopEnd != nil }

    /// Tap cycles: set A → set B (loop starts) → clear.
    func cycleLoopPoint() {
        if loopStart == nil {
            loopStart = currentTime
        } else if loopEnd == nil {
            let candidate = currentTime
            // B must be after A; if the user taps too early, reset A instead.
            if candidate > (loopStart ?? 0) + 0.5 {
                loopEnd = candidate
            } else {
                loopStart = candidate
            }
        } else {
            clearLoop()
        }
    }

    func clearLoop() {
        loopStart = nil
        loopEnd = nil
    }

    /// Jump back to A when we pass B.
    private func enforceLoopIfNeeded() {
        guard let start = loopStart, let end = loopEnd else { return }
        if currentTime >= end {
            seek(toProgress: duration > 0 ? start / duration : 0)
        }
    }

    // MARK: - Crossfade

    private enum CrossfadeKeys {
        static let transition = "player.trackTransition"
        static let duration = "player.crossfadeDuration"
    }

    @Published var transition: TrackTransition = {
        let raw = UserDefaults.standard.string(forKey: CrossfadeKeys.transition) ?? ""
        return TrackTransition(rawValue: raw) ?? .none
    }() {
        didSet {
            UserDefaults.standard.set(transition.rawValue, forKey: CrossfadeKeys.transition)
            gaplessArmed = false
        }
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

    /// Guards against the 0.1s ticker firing repeated crossfade attempts:
    /// one attempt in flight at a time, and no retry for a track we already
    /// failed to fade into (e.g. a format that needs a graph rewire).
    private var crossfadeAttemptInFlight = false
    private var crossfadeRejectedURL: URL?

    /// Arm the next track shortly before the current one ends so the hand-off
    /// is sample-exact. Re-armed per track, not per tick.
    private var gaplessArmed = false

    private func armGaplessIfNeeded() {
        guard transition == .gapless,
              isPlaying,
              !isLooping,
              repeatMode != .one,
              duration > 0,
              !gaplessArmed,
              !engine.isGaplessArmed,
              let nextURL = upcomingTrackURL
        else { return }

        // Arm a few seconds out: long enough to load the file, short enough
        // that a skip or seek in between is unlikely.
        let remaining = duration - currentTime
        guard remaining > 0, remaining <= 5 else { return }

        gaplessArmed = true
        Task { [weak self] in
            guard let self else { return }
            let gain = await self.cachedGain(for: nextURL)
            await MainActor.run {
                // Falls back to a normal switch if formats differ.
                self.engine.queueGapless(to: nextURL, gainDB: gain)
            }
        }
    }

    /// The engine already handed over to the next track; catch the queue up.
    private func handleGaplessAdvance() {
        gaplessArmed = false
        advancePositionAfterCrossfade()   // same bookkeeping: pointer + metadata
    }

    /// Called from the ticker: start overlapping the next track near the end.
    private func beginCrossfadeIfNeeded() {
        guard transition == .crossfade,
              isPlaying,
              !isLooping,                    // never fade out of an A-B loop
              repeatMode != .one,            // repeat-one shouldn't fade into itself
              duration > 0,
              !engine.isCrossfading,
              !crossfadeAttemptInFlight,
              let nextURL = upcomingTrackURL,
              nextURL != crossfadeRejectedURL
        else { return }

        let remaining = duration - currentTime
        guard remaining > 0, remaining <= crossfadeDuration else { return }

        crossfadeAttemptInFlight = true

        // Kick off with cached gain if we have it; analysis fills in shortly after.
        Task { [weak self] in
            guard let self else { return }
            let gain = await self.cachedGain(for: nextURL)
            await MainActor.run {
                defer { self.crossfadeAttemptInFlight = false }
                guard !self.engine.isCrossfading else { return }

                if self.engine.crossfade(to: nextURL,
                                         duration: self.crossfadeDuration,
                                         gainDB: gain) {
                    self.advancePositionAfterCrossfade()
                } else {
                    // Can't fade into this file — fall back to a hard switch
                    // when it finishes rather than retrying every tick.
                    self.crossfadeRejectedURL = nextURL
                }
            }
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
        gaplessArmed = false
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
        saveSession()
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
        lyricsTask?.cancel()
        lyrics = Lyrics(lines: [])
        clearLoop()
        stopTicking()
        LockScreenManager.shared.clear()
        PlaybackSessionStore.clear()
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
    
    /// Insert a track directly after the one playing.
    func playNext(_ track: Track) {
        insert(track, at: position + 1)
    }

    /// Append a track to the end of the queue.
    func addToQueue(_ track: Track) {
        insert(track, at: order.count)
    }

    func addToQueue(_ tracks: [Track]) {
        for track in tracks { insert(track, at: order.count) }
    }

    /// Adds the track to the underlying queue and splices it into the play order.
    private func insert(_ track: Track, at orderIndex: Int) {
        trackIndex[track.url] = track

        // Nothing playing yet — just start this track.
        guard !queue.isEmpty else {
            load(tracks: [track])
            return
        }

        queue.append(track.url)
        let queueIndex = queue.count - 1
        let target = min(max(orderIndex, 0), order.count)
        order.insert(queueIndex, at: target)

        // Keep the pointer on the currently playing track.
        if target <= position { position += 1 }

        gaplessArmed = false          // the "next" track changed
        saveSession()
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
        // 0.1s keeps A-B looping tight and the playhead smooth.
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
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
            
            self.enforceLoopIfNeeded()
            self.armGaplessIfNeeded()
            self.beginCrossfadeIfNeeded()

            self.tickCount += 1
            if self.tickCount % 50 == 0 {      // 0.1s × 50 = every 5s
                self.refreshNowPlayingState()
                self.saveSession()             // survive a crash or force-quit
                if let url = self.currentTrackURL {
                    self.onPositionChanged?(url, self.currentTime, self.duration)
                }
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
            rate: isPlaying ? Double(playbackRate) : 0
        )
    }

    private func refreshNowPlayingState() {
        LockScreenManager.shared.updatePlaybackState(
            elapsed: currentTime,
            rate: isPlaying ? Double(playbackRate) : 0
        )
    }

    /// Registering remote commands is what makes iOS treat us as the Now Playing
    /// app — without it, nowPlayingInfo never appears on the lock screen.
    private func setupRemoteCommands() {
        LockScreenManager.shared.configureRemoteCommands(
            // Remote commands are delivered by MediaPlayer off the main actor.
            LockScreenManager.Handlers(
                play: { [weak self] in
                    Task { @MainActor in
                        guard let self, !self.isPlaying else { return }
                        self.togglePlayPause()
                    }
                },
                pause: { [weak self] in
                    Task { @MainActor in
                        guard let self, self.isPlaying else { return }
                        self.togglePlayPause()
                    }
                },
                toggle: { [weak self] in
                    Task { @MainActor in self?.togglePlayPause() }
                },
                next: { [weak self] in
                    Task { @MainActor in self?.skipNext() }
                },
                previous: { [weak self] in
                    Task { @MainActor in self?.skipPrevious() }
                },
                seek: { [weak self] time in
                    Task { @MainActor in
                        guard let self, self.duration > 0 else { return }
                        self.seek(toProgress: time / self.duration)
                    }
                }
            )
        )
    }

    deinit {
        timer?.invalidate()
        waveformTask?.cancel()
        lyricsTask?.cancel()
    }
}
