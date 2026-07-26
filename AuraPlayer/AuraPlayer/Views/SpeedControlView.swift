//
//  SpeedControlView.swift
//  AuraPlayer
//
//  Tempo and pitch, driven by the AVAudioUnitTimePitch node that already
//  sits in the graph. The two are independent: speed leaves pitch alone,
//  pitch leaves speed alone.
//
//  Settings are global and persist — someone playing a long mix at 1.25×
//  expects it to stay there for the whole session, not reset per track.
//

import SwiftUI

struct SpeedControlView: View {
    @EnvironmentObject var player: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    /// The speeds people actually reach for, as one-tap chips.
    private let presets: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AuraSpacing.xl) {
                    readout
                    presetRow
                    speedSlider
                    pitchSection
                    footnote
                }
                .padding(AuraSpacing.lg)
            }
            .background(Color.background)
            .navigationTitle("Speed & Pitch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset") { player.resetSpeed() }
                        .foregroundStyle(player.isSpeedNeutral ? Color.textDisabled : Color.accent)
                        .disabled(player.isSpeedNeutral)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Readout

    private var readout: some View {
        VStack(spacing: AuraSpacing.xs) {
            Text(Self.rateLabel(player.playbackRate))
                .font(.system(size: 52, weight: .semibold, design: .rounded))
                .foregroundStyle(player.isSpeedNeutral ? Color.textPrimary : Color.accent)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.25), value: player.playbackRate)

            if player.pitchSemitones != 0 {
                Text(Self.pitchLabel(player.pitchSemitones))
                    .font(.auraCaption)
                    .foregroundStyle(Color.accent)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AuraSpacing.md)
        .animation(.easeOut(duration: 0.2), value: player.pitchSemitones)
    }

    // MARK: - Presets

    private var presetRow: some View {
        HStack(spacing: AuraSpacing.sm) {
            ForEach(presets, id: \.self) { preset in
                let isSelected = abs(player.playbackRate - preset) < 0.001

                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        player.playbackRate = preset
                    }
                } label: {
                    Text(Self.rateLabel(preset))
                        .font(.auraCaption)
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? Color.background : Color.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AuraSpacing.sm)
                        .background(isSelected ? Color.accent : Color.surface)
                        .clipShape(Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("\(Self.rateLabel(preset)) speed")
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .sensoryFeedback(.selection, trigger: player.playbackRate)
    }

    // MARK: - Fine speed

    private var speedSlider: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.sm) {
            sectionLabel("Speed", detail: "\(Self.rateLabel(AuraAudioEngine.rateRange.lowerBound)) – \(Self.rateLabel(AuraAudioEngine.rateRange.upperBound))")

            Slider(
                value: Binding(
                    get: { Double(player.playbackRate) },
                    // Snap to 0.05 so the readout lands on clean values.
                    set: { player.playbackRate = (Float($0) * 20).rounded() / 20 }
                ),
                in: Double(AuraAudioEngine.rateRange.lowerBound)...Double(AuraAudioEngine.rateRange.upperBound)
            )
            .tint(Color.accent)
            .accessibilityLabel("Playback speed")
            .accessibilityValue(Self.rateLabel(player.playbackRate))
        }
    }

    // MARK: - Pitch

    private var pitchSection: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.sm) {
            sectionLabel("Pitch", detail: "semitones")

            HStack(spacing: AuraSpacing.md) {
                stepButton(systemImage: "minus", enabled: player.pitchSemitones > -12) {
                    player.pitchSemitones -= 1
                }

                Text(Self.pitchLabel(player.pitchSemitones))
                    .font(.auraHeadline)
                    .monospacedDigit()
                    .foregroundStyle(player.pitchSemitones == 0 ? Color.textSecondary : Color.accent)
                    .contentTransition(.numericText())
                    .frame(maxWidth: .infinity)

                stepButton(systemImage: "plus", enabled: player.pitchSemitones < 12) {
                    player.pitchSemitones += 1
                }
            }
            .padding(AuraSpacing.md)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.medium))
            .animation(.snappy(duration: 0.2), value: player.pitchSemitones)
            .sensoryFeedback(.selection, trigger: player.pitchSemitones)
            // One control for VoiceOver, adjustable with a swipe.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Pitch")
            .accessibilityValue(Self.pitchLabel(player.pitchSemitones))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment where player.pitchSemitones < 12: player.pitchSemitones += 1
                case .decrement where player.pitchSemitones > -12: player.pitchSemitones -= 1
                default: break
                }
            }
        }
    }

    private func stepButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.auraHeadline)
                .foregroundStyle(enabled ? Color.accent : Color.textDisabled)
                .frame(width: 44, height: 44)
                .background(Color.surfaceElevated)
                .clipShape(Circle())
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!enabled)
    }

    // MARK: - Chrome

    private func sectionLabel(_ title: String, detail: String) -> some View {
        HStack {
            Text(title)
                .font(.auraHeadline)
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Text(detail)
                .font(.auraCaption)
                .foregroundStyle(Color.textTertiary)
        }
    }

    private var footnote: some View {
        Text("Speed and pitch are independent — changing one leaves the other alone. Both apply to every track until you reset them.")
            .font(.auraCaption)
            .foregroundStyle(Color.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Formatting

    /// "1×", "1.25×" — trailing zeroes dropped.
    static func rateLabel(_ rate: Float) -> String {
        let rounded = (rate * 100).rounded() / 100
        if rounded == rounded.rounded() {
            return String(format: "%.0f×", rounded)
        }
        return String(format: "%.2f×", rounded)
            .replacingOccurrences(of: "0×", with: "×")
    }

    static func pitchLabel(_ semitones: Float) -> String {
        let value = Int(semitones.rounded())
        if value == 0 { return "Original pitch" }
        return value > 0 ? "+\(value) semitones" : "\(value) semitones"
    }
}

#Preview {
    let vm = PlayerViewModel()
    vm.playbackRate = 1.25
    return SpeedControlView().environmentObject(vm)
}
