//
//  StorageManager.swift
//  AuraPlayer
//
//  Inspects and deletes audio files stored in the app's Documents folder.
//

import Foundation

struct StoredFile: Identifiable {
    let id: String        // full path
    let url: URL
    let name: String
    let size: Int64
}

enum StorageManager {

    /// All audio files under Documents, largest first.
    static func audioFiles() -> [StoredFile] {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return [] }

        var files: [StoredFile] = []
        if let enumerator = fm.enumerator(
            at: docs,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let url as URL in enumerator
            where LibraryScanner.supportedExtensions.contains(url.pathExtension.lowercased()) {
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                files.append(
                    StoredFile(id: url.path, url: url, name: url.lastPathComponent, size: Int64(size))
                )
            }
        }
        return files.sorted { $0.size > $1.size }
    }

    static func totalSize(of files: [StoredFile]) -> Int64 {
        files.reduce(0) { $0 + $1.size }
    }

    static func delete(_ file: StoredFile) {
        try? FileManager.default.removeItem(at: file.url)
    }

    static func deleteAll(_ files: [StoredFile]) {
        files.forEach { delete($0) }
    }

    static func formatted(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
