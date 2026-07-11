//
//  QueueView.swift
//  AuraPlayer
//
//  Created by mobile on 11/7/26.
//
//  Upcoming-tracks queue. Reorder by dragging (Edit mode), swipe to remove,
//  tap a row to jump to that track.
//

import SwiftUI

struct QueueView: View {
    @EnvironmentObject var player: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(player.queueItems) { item in
                        HStack(spacing: AuraSpacing.md) {
                            if item.isCurrent {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundStyle(Color.accent)
                                    .frame(width: 20)
                            } else {
                                Text("\(item.orderIndex + 1)")
                                    .font(.auraCaption)
                                    .foregroundStyle(Color.textTertiary)
                                    .frame(width: 20)
                            }
                            
                            Text(item.title)
                                .font(.auraBody)
                                .foregroundStyle(item.isCurrent ? Color.accent : Color.textPrimary)
                                .lineLimit(1)
                            
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { player.playQueueItem(at: item.orderIndex) }
                        .listRowBackground(Color.surface)
                    }
                    .onMove { player.moveQueueItem(from: $0, to: $1) }
                    .onDelete { player.removeQueueItems(at: $0) }
                } header: {
                    Text("Playing Next · \(player.queueItems.count) tracks")
                        .font(.auraCaption)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.background)
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                        .foregroundStyle(Color.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    let vm = PlayerViewModel()
    vm.currentTitle = "Bohemian Rhapsody"
    vm.currentArtist = "Queen"
    vm.duration = 354
    vm.currentTime = 132
    vm.progress = 132.0 / 354.0
    vm.isPlaying = true
    
    return QueueView()
        .environmentObject(vm)
}
