//
//  SettingsView.swift
//  AuraPlayer
//
//  App settings hub.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var library: LibraryViewModel
    @EnvironmentObject var player: PlayerViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        DownloadView()
                    } label: {
                        Label("Downloads", systemImage: "arrow.down.circle")
                            .foregroundStyle(Color.textPrimary)
                    }
                    .listRowBackground(Color.surface)

                    NavigationLink {
                        StorageView()
                    } label: {
                        Label("Storage", systemImage: "internaldrive")
                            .foregroundStyle(Color.textPrimary)
                    }
                    .listRowBackground(Color.surface)
                } header: {
                    Text("Library")
                        .font(.auraCaption)
                        .foregroundStyle(Color.textSecondary)
                }

                Section {
                    HStack {
                        Text("Tracks")
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Text("\(library.tracks.count)")
                            .foregroundStyle(Color.textTertiary)
                    }
                    .listRowBackground(Color.surface)
                } header: {
                    Text("About")
                        .font(.auraCaption)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.background)
            .navigationTitle("Settings")
        }
        .preferredColorScheme(.dark)
    }
}
