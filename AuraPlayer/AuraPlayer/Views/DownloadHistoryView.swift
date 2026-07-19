//
//  DownloadHistoryView.swift
//  AuraPlayer
//
//  Past downloads with source URL, date and size. Missing files can be re-downloaded.
//

import SwiftUI

struct DownloadHistoryView: View {
    @StateObject private var downloads = DownloadManager.shared

    @State private var records: [DownloadRecord] = []
    @State private var showClearConfirm = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        List {
            ForEach(records) { record in
                VStack(alignment: .leading, spacing: AuraSpacing.xs) {
                    Text(record.filename)
                        .font(.auraBody)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    Text(record.sourceURL.absoluteString)
                        .font(.auraCaption)
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(1)

                    HStack(spacing: AuraSpacing.sm) {
                        Text(Self.dateFormatter.string(from: record.date))
                        Text("·")
                        Text(StorageManager.formatted(record.size))

                        Spacer()

                        if record.fileExists {
                            Label("In Library", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(Color.success)
                        } else {
                            Button {
                                downloads.enqueue(urlString: record.sourceURL.absoluteString)
                            } label: {
                                Label("Re-download", systemImage: "arrow.clockwise")
                                    .foregroundStyle(Color.accent)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .font(.auraCaption)
                    .foregroundStyle(Color.textSecondary)
                }
                .padding(.vertical, AuraSpacing.xs)
                .listRowBackground(Color.background)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.background)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if records.isEmpty {
                ContentUnavailableView("No Downloads Yet", systemImage: "clock.arrow.circlepath",
                                       description: Text("Downloaded files will be logged here."))
            }
        }
        .toolbar {
            if !records.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") { showClearConfirm = true }
                        .foregroundStyle(Color.accent)
                }
            }
        }
        .alert("Clear History?", isPresented: $showClearConfirm) {
            Button("Clear", role: .destructive) {
                DownloadHistory.clear()
                records = []
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This only clears the log. Your downloaded files are not deleted.")
        }
        .task { records = DownloadHistory.load() }
    }
}
