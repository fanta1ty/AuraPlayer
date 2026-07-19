//
//  DownloadHistory.swift
//  AuraPlayer
//
//  Log of past downloads, stored as JSON in Documents. Capped at 100 entries.
//

import Foundation

struct DownloadRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let filename: String
    let sourceURL: URL
    let date: Date
    let size: Int64

    init(id: UUID = UUID(), filename: String, sourceURL: URL, date: Date = .now, size: Int64) {
        self.id = id
        self.filename = filename
        self.sourceURL = sourceURL
        self.date = date
        self.size = size
    }

    /// Whether the downloaded file still exists on disk.
    var fileExists: Bool {
        let music = AudioImporter.musicDirectory.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: music.path)
    }
}

enum DownloadHistory {

    private static let maxEntries = 100

    private static var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("download-history.json")
    }

    static func load() -> [DownloadRecord] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let records = (try? JSONDecoder().decode([DownloadRecord].self, from: data)) ?? []
        return records.sorted { $0.date > $1.date }
    }

    static func append(filename: String, sourceURL: URL) {
        let path = AudioImporter.musicDirectory.appendingPathComponent(filename)
        let size = (try? path.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0

        var records = load()
        records.insert(
            DownloadRecord(filename: filename, sourceURL: sourceURL, size: size),
            at: 0
        )
        if records.count > maxEntries {
            records = Array(records.prefix(maxEntries))
        }
        save(records)
    }

    static func clear() {
        save([])
    }

    private static func save(_ records: [DownloadRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
