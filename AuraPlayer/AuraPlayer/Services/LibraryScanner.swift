//
//  LibraryScanner.swift
//  AuraPlayer
//
//  Created by mobile on 12/7/26.
//
//  Async scan of the app's Documents directory for audio files,
//  reading metadata from each via AVAsset.
//

import Foundation
import AVFoundation

enum LibraryScanner {
    static let supportedExtensions: Set<String> = [
        "mp3",
        "flac",
        "alac",
        "m4a",
        "aac",
        "wav",
        "aiff",
        "ogg",
        "dsf",
        "dff"
    ]
    
    /// Scan Documents and return a Track for every supported audio file.
    static func scanDocuments() async -> [Track] {
        let fm = FileManager.default
        guard let docs = fm.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            return []
        }
        
        // Recursive so imported files under Documents/Music are found too.
        var urls: [URL] = []
        if let enumerator = fm.enumerator(
            at: docs,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let url as URL in enumerator
            where supportedExtensions.contains(url.pathExtension.lowercased()) {
                urls.append(url)
            }
        }

        var tracks: [Track] = []
        for url in urls {
            tracks.append(await makeTrack(from: url))
        }
        return tracks
    }
    
    private static func makeTrack(from url: URL) async -> Track {
        let asset = AVURLAsset(url: url)
        
        var title = url.deletingPathExtension().lastPathComponent
        var artist = "Unknown Artist"
        var album = "Unknown Album"
        var genre: String?
        var year: String?
        var artworkData: Data?
        var duration: TimeInterval = 0
        
        if let cmDuration = try? await asset.load(.duration) {
            let seconds = CMTimeGetSeconds(cmDuration)
            if seconds.isFinite { duration = seconds }
        }
        
        if let items = try? await asset.load(.commonMetadata) {
            for item in items {
                switch item.commonKey {
                case .commonKeyTitle:
                    if let v = try? await item.load(.stringValue), !v.isEmpty {
                        title = v
                    }
                case .commonKeyArtist:
                    if let v = try? await item.load(.stringValue), !v.isEmpty {
                        artist = v
                    }
                case .commonKeyAlbumName:
                    if let v = try? await item.load(.stringValue), !v.isEmpty {
                        album = v
                    }
                case .commonKeyType:
                    genre = try? await item.load(.stringValue)
                case .commonKeyCreationDate:
                    year = try? await item.load(.stringValue)
                case .commonKeyArtwork:
                    artworkData = try? await item.load(.dataValue)
                default:
                    break
                }
            }
        }
        
        // Album artist, composer and track/disc numbers aren't part of
        // commonMetadata — they live in format-specific tags.
        var albumArtist: String?
        var composer: String?
        var trackNumber: Int?
        var discNumber: Int?

        if let all = try? await asset.load(.metadata) {
            for item in all {
                guard let identifier = item.identifier else { continue }
                switch identifier {
                case .id3MetadataBand, .iTunesMetadataAlbumArtist:
                    if albumArtist == nil {
                        albumArtist = try? await item.load(.stringValue)
                    }
                case .id3MetadataComposer, .iTunesMetadataComposer:
                    if composer == nil {
                        composer = try? await item.load(.stringValue)
                    }
                case .id3MetadataTrackNumber, .iTunesMetadataTrackNumber:
                    if trackNumber == nil {
                        trackNumber = await leadingNumber(from: item)
                    }
                case .id3MetadataPartOfASet, .iTunesMetadataDiscNumber:
                    if discNumber == nil {
                        discNumber = await leadingNumber(from: item)
                    }
                default:
                    break
                }
            }
        }

        let dateAdded = (
            try? url.resourceValues(forKeys: [.creationDateKey]).creationDate
        ) ?? .now

        return Track(
            title: title,
            artist: artist,
            album: album,
            albumArtist: albumArtist,
            composer: composer,
            trackNumber: trackNumber,
            discNumber: discNumber,
            genre: genre,
            year: year,
            duration: duration,
            url: url,
            artworkData: artworkData,
            dateAdded: dateAdded
        )
    }

    /// Track/disc numbers appear as a number, "3", "3/12", or raw bytes
    /// depending on the container. Take the leading value in each case.
    private static func leadingNumber(from item: AVMetadataItem) async -> Int? {
        if let number = try? await item.load(.numberValue) {
            return number.intValue
        }
        if let string = try? await item.load(.stringValue) {
            let head = string.split(separator: "/").first.map(String.init) ?? string
            return Int(head.trimmingCharacters(in: .whitespaces))
        }
        if let data = try? await item.load(.dataValue), data.count >= 4 {
            // iTunes packs disc/track as big-endian 16-bit pairs.
            return Int(data[2]) << 8 | Int(data[3])
        }
        return nil
    }
}
