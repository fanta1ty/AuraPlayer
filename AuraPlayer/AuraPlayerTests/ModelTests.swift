//
//  ModelTests.swift
//  AuraPlayerTests
//
//  Small models and derived values that are easy to get subtly wrong.
//

import Testing
import Foundation
@testable import AuraPlayer

// MARK: - Download items

struct DownloadItemTests {

    @Test func usesFilenameFromURL() {
        let item = DownloadItem(url: URL(string: "https://example.com/music/song.mp3")!)
        #expect(item.filename == "song.mp3")
    }

    /// URLs ending in a path with no extension shouldn't produce a nameless file.
    @Test func generatesFallbackNameWhenURLHasNoFilename() {
        let item = DownloadItem(url: URL(string: "https://example.com/stream")!)

        #expect(item.filename.hasSuffix(".mp3"))
        #expect(item.filename.hasPrefix("download-"))
    }

    @Test func startsQueuedWithNoProgress() {
        let item = DownloadItem(url: URL(string: "https://example.com/a.mp3")!)

        #expect(item.status == .queued)
        #expect(item.progress == 0)
        #expect(item.status.isActive)
    }

    @Test func onlyUnfinishedStatusesAreActive() {
        #expect(DownloadStatus.queued.isActive)
        #expect(DownloadStatus.downloading.isActive)
        #expect(DownloadStatus.paused.isActive)
        #expect(!DownloadStatus.finished.isActive)
        #expect(!DownloadStatus.cancelled.isActive)
        #expect(!DownloadStatus.failed("boom").isActive)
    }

    @Test func failureCarriesItsMessage() {
        #expect(DownloadStatus.failed("No connection").label == "No connection")
    }
}

// MARK: - EQ bands

struct EQBandTests {

    @Test func labelsUseKiloHertzAboveOneThousand() {
        #expect(EQBand(id: 0, frequency: 32, gain: 0, isEnabled: true).label == "32")
        #expect(EQBand(id: 1, frequency: 1000, gain: 0, isEnabled: true).label == "1k")
        #expect(EQBand(id: 2, frequency: 16000, gain: 0, isEnabled: true).label == "16k")
    }
}

// MARK: - EQ presets

struct EQPresetTests {

    @Test func everyBuiltInHasTenBands() {
        for preset in EQPreset.builtIns {
            #expect(preset.gains.count == 10, "\(preset.name) has \(preset.gains.count) bands")
        }
    }

    /// Built-in IDs must be stable across launches or the selected chip is lost.
    @Test func builtInIDsAreStableAndUnique() {
        let ids = EQPreset.builtIns.map(\.id)

        #expect(Set(ids).count == ids.count)
        #expect(ids.allSatisfy { $0.hasPrefix("builtin.") })
        #expect(EQPreset.jazz.id == "builtin.jazz")
    }

    @Test func flatPresetIsAllZeroes() {
        #expect(EQPreset.flat.gains.allSatisfy { $0 == 0 })
    }

    @Test func presetGainsStayWithinRange() {
        for preset in EQPreset.builtIns {
            #expect(preset.gains.allSatisfy { $0 >= EQEngine.minGain && $0 <= EQEngine.maxGain })
        }
    }

    @Test func customPresetsAreNotMarkedBuiltIn() {
        let custom = EQPreset(name: "Mine", gains: Array(repeating: 3, count: 10))
        #expect(!custom.isBuiltIn)
    }
}

// MARK: - Track overrides

struct TrackOverrideTests {

    @Test func emptyOverrideIsDetected() {
        #expect(TrackOverride().isEmpty)
    }

    @Test func anySetFieldMakesItNonEmpty() {
        var edit = TrackOverride()
        edit.artist = "Queen"
        #expect(!edit.isEmpty)
    }

    @Test func roundTripsThroughJSON() throws {
        var edit = TrackOverride()
        edit.title = "Bohemian Rhapsody"
        edit.year = "1975"

        let data = try JSONEncoder().encode(edit)
        let decoded = try JSONDecoder().decode(TrackOverride.self, from: data)

        #expect(decoded == edit)
    }
}

// MARK: - Playlists

struct PlaylistTests {

    @Test func newPlaylistStartsEmpty() {
        let playlist = Playlist(name: "Road Trip")

        #expect(playlist.trackFilenames.isEmpty)
        #expect(playlist.coverFilename == nil)
    }

    @Test func roundTripsThroughJSON() throws {
        let playlist = Playlist(name: "Focus", trackFilenames: ["a.mp3", "b.flac"])

        let data = try JSONEncoder().encode(playlist)
        let decoded = try JSONDecoder().decode(Playlist.self, from: data)

        #expect(decoded == playlist)
    }
}

// MARK: - Library scanning rules

struct LibraryScannerTests {

    @Test func recognisesLosslessAndLossyFormats() {
        for ext in ["mp3", "flac", "m4a", "wav", "aiff", "dsf"] {
            #expect(LibraryScanner.supportedExtensions.contains(ext))
        }
    }

    @Test func ignoresNonAudioExtensions() {
        for ext in ["txt", "jpg", "json", "lrc"] {
            #expect(!LibraryScanner.supportedExtensions.contains(ext))
        }
    }
}
