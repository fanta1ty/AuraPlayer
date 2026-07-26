//
//  ZipImporter.swift
//  AuraPlayer
//
//  Unpacks a zipped album into the library.
//
//  Uses NSFileCoordinator's built-in archive reading rather than a third-party
//  zip library — the system already knows how to expand an archive, and this
//  avoids adding a dependency for one feature.
//

import Foundation

enum ZipImporter {

    struct Result {
        var imported: Int
        var error: String?
    }

    /// Expand a .zip and import every supported audio file inside it.
    static func importArchive(at url: URL) async -> Result {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        return await withCheckedContinuation { continuation in
            var coordinatorError: NSError?
            var result = Result(imported: 0, error: nil)

            let coordinator = NSFileCoordinator()
            // Reading a zip with .forUploading gives us an expanded copy.
            coordinator.coordinate(readingItemAt: url,
                                   options: [.forUploading],
                                   error: &coordinatorError) { expandedURL in
                result = extractAudio(from: expandedURL, originalName: url.lastPathComponent)
            }

            if let coordinatorError {
                result.error = coordinatorError.localizedDescription
            }
            continuation.resume(returning: result)
        }
    }

    /// Walk the expanded archive and copy audio files into the library.
    private static func extractAudio(from directory: URL, originalName: String) -> Result {
        let fm = FileManager.default

        // If coordination handed back the archive itself rather than a folder,
        // there's nothing we can walk.
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return Result(imported: 0, error: "Couldn't open \(originalName).")
        }

        // Keep the album's folder structure by importing into a named subfolder.
        let albumName = (originalName as NSString).deletingPathExtension
        let destinationFolder = AudioImporter.musicDirectory
            .appendingPathComponent(albumName, isDirectory: true)

        var imported = 0

        guard let walker = fm.enumerator(at: directory,
                                         includingPropertiesForKeys: nil,
                                         options: [.skipsHiddenFiles]) else {
            return Result(imported: 0, error: "Couldn't read the archive.")
        }

        for case let file as URL in walker
        where LibraryScanner.supportedExtensions.contains(file.pathExtension.lowercased()) {
            do {
                try fm.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
                let destination = uniqueURL(
                    destinationFolder.appendingPathComponent(file.lastPathComponent)
                )
                try fm.copyItem(at: file, to: destination)
                imported += 1
            } catch {
                continue
            }
        }

        if imported == 0 {
            return Result(imported: 0, error: "No audio files found in \(originalName).")
        }
        return Result(imported: imported, error: nil)
    }

    private static func uniqueURL(_ url: URL) -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return url }

        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var counter = 2
        var candidate = url
        repeat {
            candidate = url.deletingLastPathComponent()
                .appendingPathComponent("\(base) \(counter).\(ext)")
            counter += 1
        } while fm.fileExists(atPath: candidate.path)
        return candidate
    }
}
