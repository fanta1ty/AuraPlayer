//
//  PlaybackSession.swift
//  AuraPlayer
//
//  A snapshot of what was playing, so the app can reopen where it left off.
//
//  Tracks are stored as filenames rather than absolute URLs: the app's
//  container path changes between installs, which would invalidate any
//  saved URL.
//

import Foundation

struct PlaybackSession: Codable, Equatable {
    /// Queue in its original order, as filenames.
    var queueFilenames: [String]
    /// Play sequence: indices into `queueFilenames` (already shuffled if applicable).
    var order: [Int]
    /// Index into `order`.
    var position: Int
    /// Seconds into the current track.
    var elapsed: TimeInterval
    var isShuffled: Bool
    var repeatModeRaw: Int
    var savedAt: Date

    var isEmpty: Bool { queueFilenames.isEmpty || order.isEmpty }

    var repeatMode: RepeatMode {
        RepeatMode(rawValue: repeatModeRaw) ?? .none
    }
}
