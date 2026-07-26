//
//  BatchEditView.swift
//  AuraPlayer
//
//  Applies the same field values to several tracks at once.
//  Blank fields are left untouched, so you can set just the artist
//  without wiping albums or genres.
//

import SwiftUI

struct BatchEditView: View {
    let tracks: [Track]

    @EnvironmentObject var library: LibraryViewModel
    @StateObject private var overrides = MetadataOverrideViewModel.shared
    @Environment(\.dismiss) private var dismiss

    @State private var artist = ""
    @State private var album = ""
    @State private var genre = ""
    @State private var year = ""

    private var hasChanges: Bool {
        ![artist, album, genre, year].allSatisfy {
            $0.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    field("Artist", text: $artist)
                    field("Album", text: $album)
                    field("Genre", text: $genre)
                    field("Year", text: $year, keyboard: .numberPad)
                } header: {
                    Text("Apply to \(tracks.count) track\(tracks.count == 1 ? "" : "s")")
                        .font(.auraCaption)
                        .foregroundStyle(Color.textSecondary)
                } footer: {
                    Text("Only the fields you fill in are changed. Leave a field empty to keep each track's existing value.")
                        .font(.auraCaption)
                        .foregroundStyle(Color.textTertiary)
                }

                Section {
                    ForEach(tracks.prefix(8)) { track in
                        Text(track.title)
                            .font(.auraCaption)
                            .foregroundStyle(Color.textTertiary)
                            .lineLimit(1)
                            .listRowBackground(Color.surface)
                    }
                    if tracks.count > 8 {
                        Text("and \(tracks.count - 8) more…")
                            .font(.auraCaption)
                            .foregroundStyle(Color.textTertiary)
                            .listRowBackground(Color.surface)
                    }
                } header: {
                    Text("Selected")
                        .font(.auraCaption)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.background)
            .navigationTitle("Batch Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") { apply() }
                        .foregroundStyle(hasChanges ? Color.accent : Color.textDisabled)
                        .disabled(!hasChanges)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func field(_ label: String,
                       text: Binding<String>,
                       keyboard: UIKeyboardType = .default) -> some View {
        HStack {
            Text(label)
                .font(.auraCaption)
                .foregroundStyle(Color.textSecondary)
                .frame(width: 60, alignment: .leading)
            TextField("Unchanged", text: text)
                .keyboardType(keyboard)
                .foregroundStyle(Color.textPrimary)
        }
        .listRowBackground(Color.surface)
    }

    private func apply() {
        overrides.applyBatch(
            to: tracks.map(\.url),
            artist: artist.trimmingCharacters(in: .whitespaces),
            album: album.trimmingCharacters(in: .whitespaces),
            genre: genre.trimmingCharacters(in: .whitespaces),
            year: year.trimmingCharacters(in: .whitespaces)
        )
        library.refreshOverrides()
        dismiss()
    }
}
