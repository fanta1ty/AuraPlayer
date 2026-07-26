//
//  SmartPlaylistViewModel.swift
//  AuraPlayer
//

import Foundation
import Combine

@MainActor
final class SmartPlaylistViewModel: ObservableObject {

    static let shared = SmartPlaylistViewModel()

    @Published private(set) var playlists: [SmartPlaylist] = []

    private static let fileURL = JSONFileStore.documentsURL("smart-playlists.json")

    private init() {
        playlists = JSONFileStore.load([SmartPlaylist].self, from: Self.fileURL) ?? []
    }

    func playlist(id: UUID) -> SmartPlaylist? {
        playlists.first { $0.id == id }
    }

    func add(_ playlist: SmartPlaylist) {
        playlists.append(playlist)
        persist()
    }

    func update(_ playlist: SmartPlaylist) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[index] = playlist
        persist()
    }

    func delete(at offsets: IndexSet) {
        playlists.remove(atOffsets: offsets)
        persist()
    }

    /// Seed the ready-made playlists, skipping any the user already has.
    func addPresets() {
        for preset in SmartPlaylist.presets
        where !playlists.contains(where: { $0.name == preset.name }) {
            playlists.append(preset)
        }
        persist()
    }

    private func persist() {
        JSONFileStore.save(playlists, to: Self.fileURL)
    }
}
