//
//  PlaylistViewModel.swift
//  AuraPlayer
//
//  Created by mobile on 16/7/26.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class PlaylistViewModel: ObservableObject {
    @Published private(set) var playlists: [Playlist] = []

    init() {
        playlists = PlaylistStore.load()
    }

    func playlist(id: UUID) -> Playlist? { playlists.first { $0.id == id } }

    func create(name: String) {
        playlists.append(Playlist(name: name))
        persist()
    }

    func delete(at offsets: IndexSet) {
        playlists.remove(atOffsets: offsets)
        persist()
    }

    func add(track: Track, to playlist: Playlist) {
        guard let i = playlists.firstIndex(where: { $0.id == playlist.id }) else {
            return
        }
        let filename = track.url.lastPathComponent
        guard !playlists[i].trackFilenames.contains(filename) else { return }
        playlists[i].trackFilenames.append(filename)
        if playlists[i].coverFilename == nil { playlists[i].coverFilename = filename }
        persist()
    }

    func removeTracks(at offsets: IndexSet, from id: UUID) {
        guard let i = playlists.firstIndex(where: { $0.id == id }) else {
            return
        }
        playlists[i].trackFilenames.remove(atOffsets: offsets)
        persist()
    }

    func moveTracks(from source: IndexSet, to destination: Int, in id: UUID) {
        guard let i = playlists.firstIndex(where: { $0.id == id }) else {
            return
        }
        playlists[i].trackFilenames
            .move(fromOffsets: source, toOffset: destination)
        persist()
    }

    private func persist() { PlaylistStore.save(playlists) }
}
