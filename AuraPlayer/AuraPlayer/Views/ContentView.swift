//
//  ContentView.swift
//  AuraPlayer
//
//  Created by mobile on 4/7/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var player: PlayerViewModel
    @State private var showPlayer = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
//            Color.background.ignoresSafeArea()
//            
//            VStack(spacing: AuraSpacing.xl) {
//                Text("AuraPlayer")
//                    .font(.auraDisplay)
//                    .foregroundStyle(Color.textPrimary)
//                
//                AuraButton("Play Queue", systemImage: "play.fill", variant: .primary) {
//                    let names = ["track1", "track2", "track3"]   // your 3 test files
//                    let urls = names.compactMap { Bundle.main.url(forResource: $0, withExtension: "mp3") }
//                    player.load(queue: urls)
//                }
//            }
//            .frame(maxWidth: .infinity, maxHeight: .infinity)
//            
//            if player.hasTrack {
//                AuraNowPlayingBar { showPlayer = true }
//                    .padding(.horizontal, AuraSpacing.md)
//                    .padding(.bottom, AuraSpacing.sm)
//                    .transition(.move(edge: .bottom).combined(with: .opacity))
//            }
            LibrarySongsView()
            
            if player.hasTrack {
                AuraNowPlayingBar { showPlayer = true }
                    .padding(.horizontal, AuraSpacing.md)
                    .padding(.bottom, AuraSpacing.sm)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: player.hasTrack)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPlayer) {
            NowPlayingView().environmentObject(player)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(PlayerViewModel())
}
