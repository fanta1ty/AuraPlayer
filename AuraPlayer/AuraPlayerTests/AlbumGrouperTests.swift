//
//  AlbumGrouperTests.swift
//  AuraPlayerTests
//
//  Album grouping is pure logic over messy real-world tags, which makes it
//  both easy to get wrong and easy to test.
//

import Testing
import Foundation
@testable import AuraPlayer

struct AlbumGrouperTests {

    private func track(_ title: String,
                       artist: String = "Artist",
                       album: String,
                       albumArtist: String? = nil,
                       trackNumber: Int? = nil) -> Track {
        Track(title: title,
              artist: artist,
              album: album,
              albumArtist: albumArtist,
              trackNumber: trackNumber,
              duration: 100,
              url: URL(fileURLWithPath: "/tmp/\(title).mp3"))
    }

    // MARK: - Normalisation

    @Test func differentCasingIsOneAlbum() {
        let albums = AlbumGrouper.albums(from: [
            track("A", album: "Abbey Road"),
            track("B", album: "abbey road")
        ])

        #expect(albums.count == 1)
        #expect(albums[0].trackCount == 2)
    }

    @Test func strayWhitespaceIsOneAlbum() {
        let albums = AlbumGrouper.albums(from: [
            track("A", album: "Kind of Blue"),
            track("B", album: "  Kind  of Blue ")
        ])

        #expect(albums.count == 1)
    }

    @Test func accentsDoNotSplitAnAlbum() {
        let albums = AlbumGrouper.albums(from: [
            track("A", album: "Café Bleu"),
            track("B", album: "Cafe Bleu")
        ])

        #expect(albums.count == 1)
    }

    // MARK: - Artist handling

    /// The original bug: a featured credit on one track split the album.
    @Test func differingTrackArtistsStayTogetherWithoutAlbumArtistTags() {
        let albums = AlbumGrouper.albums(from: [
            track("A", artist: "Nujabes", album: "Modal Soul"),
            track("B", artist: "Nujabes feat. Cise Starr", album: "Modal Soul")
        ])

        #expect(albums.count == 1)
        #expect(albums[0].artist == "Various Artists")
    }

    @Test func consistentArtistIsCredited() {
        let albums = AlbumGrouper.albums(from: [
            track("A", artist: "Radiohead", album: "In Rainbows"),
            track("B", artist: "Radiohead", album: "In Rainbows")
        ])

        #expect(albums[0].artist == "Radiohead")
    }

    @Test func albumArtistTagOverridesTrackArtists() {
        let albums = AlbumGrouper.albums(from: [
            track("A", artist: "Guest One", album: "Endtroducing", albumArtist: "DJ Shadow"),
            track("B", artist: "Guest Two", album: "Endtroducing")
        ])

        #expect(albums.count == 1)
        #expect(albums[0].artist == "DJ Shadow")
    }

    /// Two genuinely different records that share a title must stay apart
    /// when the files actually say who they belong to.
    @Test func distinctAlbumArtistsSplitASharedTitle() {
        let albums = AlbumGrouper.albums(from: [
            track("A", album: "Greatest Hits", albumArtist: "Queen"),
            track("B", album: "Greatest Hits", albumArtist: "ABBA")
        ])

        #expect(albums.count == 2)
        #expect(Set(albums.map(\.artist)) == ["Queen", "ABBA"])
    }

    // MARK: - Ordering

    @Test func tracksAreInDiscAndTrackOrder() {
        let albums = AlbumGrouper.albums(from: [
            track("Third", album: "X", trackNumber: 3),
            track("First", album: "X", trackNumber: 1),
            track("Second", album: "X", trackNumber: 2)
        ])

        #expect(albums[0].tracks.map(\.title) == ["First", "Second", "Third"])
    }

    /// Same-titled albums must not shuffle between recomputations.
    @Test func orderingIsStableAcrossRuns() {
        let tracks = [
            track("A", album: "Live", albumArtist: "Zeta"),
            track("B", album: "Live", albumArtist: "Alpha"),
            track("C", album: "Live", albumArtist: "Mid")
        ]

        let first = AlbumGrouper.albums(from: tracks).map(\.id)
        for _ in 0..<20 {
            #expect(AlbumGrouper.albums(from: tracks).map(\.id) == first)
        }
    }

    @Test func albumsSortByTitle() {
        let albums = AlbumGrouper.albums(from: [
            track("A", album: "Zoo"),
            track("B", album: "Apple")
        ])

        #expect(albums.map(\.title) == ["Apple", "Zoo"])
    }
}
