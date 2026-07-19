//
//  AuraPlayerApp.swift
//  AuraPlayer
//
//  Created by mobile on 4/7/26.
//

import SwiftUI

@main
struct AuraPlayerApp: App {
    @StateObject private var player = PlayerViewModel()
    @StateObject private var library = LibraryViewModel()
    @StateObject private var playlists = PlaylistViewModel()
    @StateObject private var eq = EQEngine.shared
    @StateObject private var stats = TrackStatsViewModel()
    
    init() {
        AudioSessionManager.shared.configure()  // Session first
        AuraAudioEngine.shared.start()          // then engine
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(player)
                .environmentObject(library)
                .environmentObject(playlists)
                .environmentObject(eq)
                .environmentObject(stats)
                .onOpenURL { url in
                    handleIncomingFile(url)
                }
        }
    }

    /// A file was handed to us from Safari, Mail, Files, etc.
    /// Copy it into the library, rescan, then play it immediately.
    private func handleIncomingFile(_ url: URL) {
        guard let destination = AudioImporter.importFiles([url]).first else { return }
        Task { @MainActor in
            await library.scan()
            if let track = library.tracks.first(where: { $0.url == destination }) {
                player.load(tracks: [track])
            } else {
                player.play(url: destination)
            }
        }
    }
}
