//
//  PlaylistStore.swift
//  AuraPlayer
//
//  Created by mobile on 15/7/26.
//
//  JSON persistence for playlists in the Documents folder.
//

import Foundation

enum PlaylistStore {
    private static var fileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("playlists.json")
    }

    static func load() -> [Playlist] {
        JSONFileStore.load([Playlist].self, from: fileURL) ?? []
    }

    /// Returns false if the write failed (logged by JSONFileStore).
    @discardableResult
    static func save(_ playlists: [Playlist]) -> Bool {
        JSONFileStore.save(playlists, to: fileURL)
    }
}
