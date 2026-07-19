//
//  EQView.swift
//  AuraPlayer
//
//  10-band equalizer with preset chips. Changes apply to audio in real time.
//

import SwiftUI

struct EQView: View {
    @EnvironmentObject var eq: EQEngine
    @Environment(\.dismiss) private var dismiss

    @State private var showSave = false
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: AuraSpacing.lg) {
                presetChips
                preampControl
                EQCurveView(bands: eq.bands, preamp: eq.preamp)
                sliders
                Spacer(minLength: 0)
            }
            .padding(.vertical, AuraSpacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.background)
            .navigationTitle("Equalizer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Toggle("EQ Enabled", isOn: Binding(
                            get: { eq.isEnabled },
                            set: { eq.isEnabled = $0 }
                        ))
                        Button("Reset to Flat") { eq.reset() }
                        Button("Save as Preset…") { showSave = true }
                    } label: {
                        Image(systemName: "ellipsis.circle").foregroundStyle(Color.accent)
                    }
                }
            }
            .alert("Save Preset", isPresented: $showSave) {
                TextField("Name", text: $newName)
                Button("Save") {
                    eq.saveCustomPreset(named: newName)
                    newName = ""
                }
                Button("Cancel", role: .cancel) { newName = "" }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var presetChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AuraSpacing.sm) {
                ForEach(eq.allPresets) { preset in
                    let selected = eq.selectedPresetID == preset.id
                    Text(preset.name)
                        .font(.auraCaption)
                        .foregroundStyle(selected ? Color.background : Color.textPrimary)
                        .padding(.horizontal, AuraSpacing.md)
                        .padding(.vertical, AuraSpacing.sm)
                        .background(selected ? Color.accent : Color.surfaceElevated)
                        .clipShape(Capsule())
                        .contentShape(Capsule())
                        .onTapGesture { eq.apply(preset) }
                        .contextMenu {
                            if !preset.isBuiltIn {
                                Button("Delete", role: .destructive) { eq.delete(preset) }
                            }
                        }
                }
            }
            .padding(.horizontal, AuraSpacing.md)
        }
    }

    private var preampControl: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.xs) {
            HStack {
                Text("Preamp")
                    .font(.auraCaption)
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                Text(String(format: "%+.1f dB", eq.preamp))
                    .font(.auraTimestamp)
                    .foregroundStyle(eq.preamp == 0 ? Color.textTertiary : Color.accent)
            }
            AuraSlider(value: Binding(
                get: {
                    Double((eq.preamp - EQEngine.minGain) / (EQEngine.maxGain - EQEngine.minGain))
                },
                set: { newValue in
                    let range = EQEngine.maxGain - EQEngine.minGain
                    eq.setPreamp(EQEngine.minGain + Float(newValue) * range)
                }
            ))
        }
        .padding(.horizontal, AuraSpacing.md)
    }

    private var sliders: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(eq.bands) { band in
                EQBandSlider(band: band) { gain in
                    eq.setBand(band.id, gain: gain)
                }
            }
        }
        .padding(.horizontal, AuraSpacing.sm)
        .opacity(eq.isEnabled ? 1 : 0.4)
    }
}
