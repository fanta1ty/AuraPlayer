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
        }
    }
}
