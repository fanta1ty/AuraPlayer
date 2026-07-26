//
//  PlaybackSessionStore.swift
//  AuraPlayer
//
//  Persists the last playback session so the app can resume on launch.
//

import Foundation

enum PlaybackSessionStore {

    private static let fileURL = JSONFileStore.documentsURL("playback-session.json")

    static func load() -> PlaybackSession? {
        guard let session = JSONFileStore.load(PlaybackSession.self, from: fileURL),
              !session.isEmpty else { return nil }
        return session
    }

    static func save(_ session: PlaybackSession) {
        JSONFileStore.save(session, to: fileURL)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
