//
//  AudioImporter.swift
//  AuraPlayer
//
//  Copies incoming audio files into Documents/Music, auto-renaming on
//  filename collisions so imports never silently overwrite each other.
//

import Foundation

enum AudioImporter {

    /// Documents/Music — created on first access.
    static var musicDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let music = docs.appendingPathComponent("Music", isDirectory: true)
        if !FileManager.default.fileExists(atPath: music.path) {
            try? FileManager.default.createDirectory(at: music, withIntermediateDirectories: true)
        }
        return music
    }

    /// Copy files into the music folder. Returns the destination URLs that succeeded.
    @discardableResult
    static func importFiles(_ urls: [URL]) -> [URL] {
        var imported: [URL] = []

        for source in urls {
            // Files outside our sandbox need security scope; harmless if not needed.
            let scoped = source.startAccessingSecurityScopedResource()
            defer { if scoped { source.stopAccessingSecurityScopedResource() } }

            let destination = uniqueDestination(for: source.lastPathComponent)
            do {
                try FileManager.default.copyItem(at: source, to: destination)
                imported.append(destination)
            } catch {
                print("⚠️ Import failed for \(source.lastPathComponent): \(error)")
            }
        }
        return imported
    }

    /// "Song.mp3" → "Song 2.mp3" if the name is taken.
    private static func uniqueDestination(for filename: String) -> URL {
        let fm = FileManager.default
        var candidate = musicDirectory.appendingPathComponent(filename)
        guard fm.fileExists(atPath: candidate.path) else { return candidate }

        let base = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        var counter = 2
        repeat {
            let name = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
            candidate = musicDirectory.appendingPathComponent(name)
            counter += 1
        } while fm.fileExists(atPath: candidate.path)

        return candidate
    }
}
