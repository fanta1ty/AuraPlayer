//
//  WiFiTransferView.swift
//  AuraPlayer
//
//  Turn on a local web server and manage music from a desktop browser.
//

import SwiftUI

struct WiFiTransferView: View {
    @EnvironmentObject var library: LibraryViewModel
    @StateObject private var server = WiFiTransferServer.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            Section {
                Toggle("Wi-Fi Transfer", isOn: Binding(
                    get: { server.isRunning },
                    set: { $0 ? server.start() : server.stop() }
                ))
                .tint(Color.accent)
                .foregroundStyle(Color.textPrimary)
                .listRowBackground(Color.surface)

                if server.isRunning, let address = server.address {
                    VStack(alignment: .leading, spacing: AuraSpacing.xs) {
                        Text("Open this on your computer")
                            .font(.auraCaption)
                            .foregroundStyle(Color.textSecondary)
                        Text(address)
                            .font(.auraTitle)
                            .foregroundStyle(Color.accent)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, AuraSpacing.xs)
                    .listRowBackground(Color.surface)
                }

                if let error = server.lastError {
                    Text(error)
                        .font(.auraCaption)
                        .foregroundStyle(Color.error)
                        .listRowBackground(Color.surface)
                }
            } footer: {
                Text("Both devices must be on the same Wi-Fi network. Keep this screen open — iOS suspends the app in the background, which stops the server.")
                    .font(.auraCaption)
                    .foregroundStyle(Color.textTertiary)
            }

            Section {
                Label("Drag files into the browser to add them", systemImage: "arrow.down.doc")
                    .font(.auraCaption)
                    .foregroundStyle(Color.textSecondary)
                    .listRowBackground(Color.surface)
                Label("Delete tracks from the same page", systemImage: "trash")
                    .font(.auraCaption)
                    .foregroundStyle(Color.textSecondary)
                    .listRowBackground(Color.surface)
            } header: {
                Text("What you can do")
                    .font(.auraCaption)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.background)
        .navigationTitle("Wi-Fi Transfer")
        .navigationBarTitleDisplayMode(.inline)
        // Pick up files added or removed from the browser.
        .onChange(of: server.changeCount) { _, _ in
            Task { await library.scan() }
        }
        // The server can't survive backgrounding, so shut it down cleanly.
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { server.stop() }
        }
        .onDisappear { server.stop() }
    }
}
