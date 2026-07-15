//
//  PlaylistsView.swift
//  AuraPlayer
//
//  Created by mobile on 16/7/26.
//

import SwiftUI

struct PlaylistsView: View {
    @EnvironmentObject var playlists: PlaylistViewModel
    @State private var showingCreate = false
    @State private var newName = ""
    
    var body: some View {
        NavigationStack {
            Group {
                if playlists.playlists.isEmpty {
                    ContentUnavailableView("No Playlists", systemImage: "music.note.list",
                                           description: Text("Tap + to create your first playlist."))
                } else {
                    List {
                        ForEach(playlists.playlists) { playlist in
                            NavigationLink {
                                PlaylistDetailView(playlistID: playlist.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(playlist.name)
                                        .font(.auraBody)
                                        .foregroundStyle(Color.textPrimary)
                                    Text("\(playlist.trackFilenames.count) track\(playlist.trackFilenames.count == 1 ? "" : "s")")
                                        .font(.auraCaption)
                                        .foregroundStyle(Color.textSecondary)
                                }
                            }
                            .listRowBackground(Color.background)
                        }
                        .onDelete { playlists.delete(at: $0) }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.background)
            .navigationTitle("Playlists")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingCreate = true } label: {
                        Image(systemName: "plus").foregroundStyle(Color.accent)
                    }
                }
            }
            .alert("New Playlist", isPresented: $showingCreate) {
                TextField("Name", text: $newName)
                Button("Create") {
                    let name = newName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty { playlists.create(name: name) }
                    newName = ""
                }
                Button("Cancel", role: .cancel) { newName = "" }
            }
        }
        .preferredColorScheme(.dark)
    }
}
