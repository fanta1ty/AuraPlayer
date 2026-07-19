//
//  SleepTimerView.swift
//  AuraPlayer
//
//  Pick a sleep duration, or stop at the end of the current track.
//

import SwiftUI

struct SleepTimerView: View {
    @StateObject private var timer = SleepTimer.shared
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: AuraSpacing.md),
        GridItem(.flexible(), spacing: AuraSpacing.md),
        GridItem(.flexible(), spacing: AuraSpacing.md)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: AuraSpacing.xl) {
                if timer.isActive {
                    activeState
                } else {
                    picker
                }
                Spacer(minLength: 0)
            }
            .padding(AuraSpacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.background)
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - States

    private var activeState: some View {
        VStack(spacing: AuraSpacing.xl) {
            if timer.stopAtEndOfTrack {
                VStack(spacing: AuraSpacing.sm) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.accent)
                        .glowEffect(radius: 14)
                    Text("Stopping at end of track")
                        .font(.auraHeadline)
                        .foregroundStyle(Color.textPrimary)
                }
            } else {
                AuraProgressRing(progress: timer.progress, size: 160, showsLabel: false)
                    .overlay {
                        VStack(spacing: AuraSpacing.xs) {
                            Text(timer.remainingText)
                                .font(.auraDisplay)
                                .foregroundStyle(Color.textPrimary)
                            Text("remaining")
                                .font(.auraCaption)
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
            }

            AuraButton("Cancel Timer", systemImage: "xmark", variant: .secondary) {
                timer.cancel()
            }
        }
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.lg) {
            Text("Fade out and pause after…")
                .font(.auraCaption)
                .foregroundStyle(Color.textSecondary)

            LazyVGrid(columns: columns, spacing: AuraSpacing.md) {
                ForEach(SleepTimer.presets, id: \.self) { minutes in
                    Button {
                        timer.start(minutes: minutes)
                    } label: {
                        Text("\(minutes)m")
                            .font(.auraHeadline)
                            .foregroundStyle(Color.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AuraSpacing.md)
                            .background(Color.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.medium))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }

            AuraButton("End of Current Track", systemImage: "music.note", variant: .secondary) {
                timer.startEndOfTrack()
            }

            Text("Audio fades out over the last \(Int(timer.fadeDuration)) seconds.")
                .font(.auraCaption)
                .foregroundStyle(Color.textTertiary)
        }
    }
}
