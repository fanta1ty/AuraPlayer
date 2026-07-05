//
//  ContentView.swift
//  AuraPlayer
//
//  Created by mobile on 4/7/26.
//

import SwiftUI

struct ContentView: View {
    private let engine = AuraAudioEngine.shared
    
    var body: some View {
        VStack(spacing: AuraSpacing.xl) {
            Text("AuraPlayer")
                .font(.auraDisplay)
                .foregroundStyle(Color.textPrimary)
            
            AuraButton("Play Test File", systemImage: "play.fill", variant: .primary) {
                // Change "test" / "mp3" to match the file you added.
                if let url = Bundle.main.url(forResource: "test", withExtension: "mp3") {
                    engine.play(url: url)
                } else {
                    print("⚠️ test.mp3 not found in bundle")
                }
            }
            
            HStack(spacing: AuraSpacing.lg) {
                AuraButton(systemImage: "pause.fill", variant: .icon) { engine.pause() }
                AuraButton(systemImage: "play.fill",  variant: .icon) { engine.resume() }
                AuraButton(systemImage: "stop.fill",  variant: .icon) { engine.stop() }
            }
        }
        .padding(AuraSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
