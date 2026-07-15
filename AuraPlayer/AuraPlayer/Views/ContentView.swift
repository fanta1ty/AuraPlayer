//
//  ContentView.swift
//  AuraPlayer
//
//  Created by mobile on 4/7/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var player: PlayerViewModel
    @EnvironmentObject var library: LibraryViewModel
    
    @State private var showPlayer = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                LibrarySongsView()
                    .tabItem {
                        Label("Songs", systemImage: "music.note")
                    }
                
                LibraryAlbumsView()
                    .tabItem {
                        Label("Albums", systemImage: "square.stack")
                    }
                
                LibraryArtistsView()
                    .tabItem {
                        Label("Artists", systemImage: "music.mic")
                    }
                
                PlaylistsView()
                    .tabItem {
                        Label("Playlists", systemImage: "music.note.list")
                    }
            }
            .tint(Color.accent)
            
            if player.hasTrack {
                AuraNowPlayingBar { showPlayer = true }
                    .padding(.horizontal, AuraSpacing.md)
                    .padding(.bottom, 49) // clear the tab bar
                    .transition(.move(edge: .bottom)
                        .combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: player.hasTrack)
        .preferredColorScheme(.dark)
        .task { if library.tracks.isEmpty { await library.scan() } }
        .sheet(isPresented: $showPlayer) {
            NowPlayingView().environmentObject(player)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(PlayerViewModel())
        .environmentObject(LibraryViewModel())
        .environmentObject(PlaylistViewModel())
}
