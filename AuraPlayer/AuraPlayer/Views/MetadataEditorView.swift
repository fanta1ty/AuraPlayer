//
//  MetadataEditorView.swift
//  AuraPlayer
//
//  Edit a track's metadata. Changes are stored app-side and layered over the
//  file's own tags — the audio file itself is never modified.
//

import SwiftUI
import PhotosUI

struct MetadataEditorView: View {
    let track: Track

    @EnvironmentObject var library: LibraryViewModel
    @StateObject private var overrides = MetadataOverrideViewModel.shared
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var artist = ""
    @State private var album = ""
    @State private var genre = ""
    @State private var year = ""

    @State private var pickedItem: PhotosPickerItem?
    @State private var artworkData: Data?
    @State private var showRevertConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: AuraSpacing.sm) {
                            artworkPreview
                            PhotosPicker(selection: $pickedItem, matching: .images) {
                                Text("Change Artwork")
                                    .font(.auraCaption)
                                    .foregroundStyle(Color.accent)
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.background)
                }

                Section {
                    field("Title", text: $title)
                    field("Artist", text: $artist)
                    field("Album", text: $album)
                    field("Genre", text: $genre)
                    field("Year", text: $year, keyboard: .numberPad)
                } header: {
                    Text("Details")
                        .font(.auraCaption)
                        .foregroundStyle(Color.textSecondary)
                }

                Section {
                    LabeledContent("File", value: track.url.lastPathComponent)
                        .font(.auraCaption)
                        .foregroundStyle(Color.textTertiary)
                        .listRowBackground(Color.surface)

                    if overrides.hasOverride(for: track.url) {
                        Button("Revert to File Tags", role: .destructive) {
                            showRevertConfirm = true
                        }
                        .listRowBackground(Color.surface)
                    }
                } footer: {
                    Text("Edits are saved in AuraPlayer. Your audio file is not modified.")
                        .font(.auraCaption)
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.background)
            .navigationTitle("Edit Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }.foregroundStyle(Color.accent)
                }
            }
            .alert("Revert Changes?", isPresented: $showRevertConfirm) {
                Button("Revert", role: .destructive) {
                    overrides.revert(url: track.url)
                    library.refreshOverrides()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This restores the metadata stored in the file itself.")
            }
            .task { loadCurrentValues() }
            .onChange(of: pickedItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        artworkData = data
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Pieces

    @ViewBuilder private var artworkPreview: some View {
        Group {
            if let data = artworkData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.surfaceElevated
                    .overlay(Image(systemName: "music.note").font(.system(size: 32))
                        .foregroundStyle(Color.accent))
            }
        }
        .frame(width: 120, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.medium))
    }

    private func field(_ label: String,
                       text: Binding<String>,
                       keyboard: UIKeyboardType = .default) -> some View {
        HStack {
            Text(label)
                .font(.auraCaption)
                .foregroundStyle(Color.textSecondary)
                .frame(width: 60, alignment: .leading)
            TextField(label, text: text)
                .keyboardType(keyboard)
                .foregroundStyle(Color.textPrimary)
        }
        .listRowBackground(Color.surface)
    }

    // MARK: - Actions

    private func loadCurrentValues() {
        title = track.title
        artist = track.artist
        album = track.album
        genre = track.genre ?? ""
        year = track.year ?? ""
        artworkData = track.artworkData
    }

    private func save() {
        var edit = overrides.override(for: track.url)

        // Only store a field if it differs from what the file already says.
        edit.title  = title  == track.title  ? edit.title  : title
        edit.artist = artist == track.artist ? edit.artist : artist
        edit.album  = album  == track.album  ? edit.album  : album
        edit.genre  = genre  == (track.genre ?? "") ? edit.genre : genre
        edit.year   = year   == (track.year  ?? "") ? edit.year  : year

        overrides.save(edit, for: track.url)

        if let data = artworkData, data != track.artworkData {
            overrides.setArtwork(data, for: track.url)
        }

        library.refreshOverrides()
        dismiss()
    }
}
