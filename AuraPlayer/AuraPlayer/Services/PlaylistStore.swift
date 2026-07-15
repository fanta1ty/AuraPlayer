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
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([Playlist].self, from: data)) ?? []
    }

    static func save(_ playlists: [Playlist]) {
        guard let data = try? JSONEncoder().encode(playlists) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
