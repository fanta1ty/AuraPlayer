//
//  SmartPlaylistEditorView.swift
//  AuraPlayer
//
//  Build the rules for a smart playlist, with a live count of what matches.
//

import SwiftUI

struct SmartPlaylistEditorView: View {
    @State var playlist: SmartPlaylist
    let isNew: Bool

    @EnvironmentObject var library: LibraryViewModel
    @EnvironmentObject var stats: TrackStatsViewModel
    @StateObject private var smart = SmartPlaylistViewModel.shared
    @Environment(\.dismiss) private var dismiss

    private var matchCount: Int {
        SmartPlaylistEngine.evaluate(playlist, tracks: library.tracks, stats: stats).count
    }

    private var canSave: Bool {
        !playlist.name.trimmingCharacters(in: .whitespaces).isEmpty && !playlist.rules.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $playlist.name)
                        .foregroundStyle(Color.textPrimary)
                        .listRowBackground(Color.surface)

                    Picker("Match", selection: $playlist.matchAll) {
                        Text("All rules").tag(true)
                        Text("Any rule").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.surface)
                }

                Section {
                    ForEach($playlist.rules) { $rule in
                        ruleEditor($rule)
                    }
                    .onDelete { playlist.rules.remove(atOffsets: $0) }

                    Button {
                        playlist.rules.append(SmartRule())
                    } label: {
                        Label("Add Rule", systemImage: "plus")
                            .foregroundStyle(Color.accent)
                    }
                    .listRowBackground(Color.surface)
                } header: {
                    Text("Rules")
                        .font(.auraCaption)
                        .foregroundStyle(Color.textSecondary)
                } footer: {
                    Text("\(matchCount) track\(matchCount == 1 ? "" : "s") match right now.")
                        .font(.auraCaption)
                        .foregroundStyle(Color.accent)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.background)
            .navigationTitle(isNew ? "New Smart Playlist" : "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .foregroundStyle(canSave ? Color.accent : Color.textDisabled)
                        .disabled(!canSave)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func ruleEditor(_ rule: Binding<SmartRule>) -> some View {
        VStack(alignment: .leading, spacing: AuraSpacing.sm) {
            Picker("Field", selection: rule.field) {
                ForEach(SmartField.allCases) { Text($0.label).tag($0) }
            }
            .onChange(of: rule.wrappedValue.field) { _, newField in
                // Keep the comparison valid for the new field.
                let options = SmartComparison.options(for: newField)
                if !options.contains(rule.wrappedValue.comparison) {
                    rule.wrappedValue.comparison = options.first ?? .isAtLeast
                }
            }

            Picker("Comparison", selection: rule.comparison) {
                ForEach(SmartComparison.options(for: rule.wrappedValue.field)) {
                    Text($0.label).tag($0)
                }
            }

            if rule.wrappedValue.comparison != .isNever {
                if rule.wrappedValue.field.isText {
                    TextField("Value", text: rule.text)
                        .foregroundStyle(Color.textPrimary)
                } else {
                    Stepper(
                        value: rule.number,
                        in: numberRange(for: rule.wrappedValue.field)
                    ) {
                        Text(rule.wrappedValue.field.isDayCount
                             ? "\(rule.wrappedValue.number) days ago"
                             : "\(rule.wrappedValue.number)")
                            .foregroundStyle(Color.textPrimary)
                    }
                }
            }
        }
        .padding(.vertical, AuraSpacing.xs)
        .listRowBackground(Color.surface)
    }

    private func numberRange(for field: SmartField) -> ClosedRange<Int> {
        switch field {
        case .rating:    return 0...5
        case .playCount: return 0...100
        default:         return 1...365
        }
    }

    private func save() {
        if isNew {
            smart.add(playlist)
        } else {
            smart.update(playlist)
        }
        dismiss()
    }
}
