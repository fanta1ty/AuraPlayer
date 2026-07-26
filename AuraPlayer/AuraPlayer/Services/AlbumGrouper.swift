//
//  AlbumGrouper.swift
//  AuraPlayer
//
//  Turning a flat track list into albums is deceptively fiddly, and it was
//  previously duplicated in three views that could disagree with each other.
//
//  Two rules drive everything here:
//
//  1. Match on normalised text. Tags are hand-made and inconsistent —
//     "Abbey Road", "abbey road" and "Abbey Road " are one record, not three.
//
//  2. Only split an album by artist when the files actually say so. A
//     missing album-artist tag means we know nothing, and falling back to
//     the per-track artist would tear compilations and featured-guest
//     tracks into one-song albums.
//

import Foundation

enum AlbumGrouper {

    /// Every album in the library, deterministically ordered.
    static func albums(from tracks: [Track]) -> [Album] {
        Dictionary(grouping: tracks) { normalize($0.album) }
            .flatMap { titleKey, group in albums(titleKey: titleKey, tracks: group) }
            .sorted(by: precedes)
    }

    /// Albums for a subset — used by artist pages, which have already
    /// narrowed the tracks down.
    static func albums(from tracks: [Track], matching query: String) -> [Album] {
        guard !query.isEmpty else { return albums(from: tracks) }
        return albums(from: tracks).filter {
            $0.title.localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: - Splitting one title

    /// Decide whether tracks sharing an album name are one record or several.
    private static func albums(titleKey: String, tracks: [Track]) -> [Album] {
        let title = commonest(tracks.map(\.album))

        // Distinct album-artist tags that are actually present.
        let tagged = Set(
            tracks
                .compactMap { $0.albumArtist }
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .map(normalize)
        )

        // Zero or one credited album artist: it's a single record. Files
        // missing the tag inherit it rather than splitting off on their own.
        guard tagged.count > 1 else {
            return [Album(id: titleKey,
                          title: title,
                          artist: displayArtist(for: tracks, tagged: tagged),
                          tracks: ordered(tracks))]
        }

        // Several credited album artists genuinely share this title — e.g.
        // two different "Greatest Hits". Trust the tags and keep them apart.
        return Dictionary(grouping: tracks) { normalize($0.effectiveAlbumArtist) }
            .map { artistKey, group in
                Album(id: "\(titleKey)\u{1F}\(artistKey)",
                      title: title,
                      artist: commonest(group.map(\.effectiveAlbumArtist)),
                      tracks: ordered(group))
            }
            .sorted(by: precedes)
    }

    /// Who to credit on the album card.
    private static func displayArtist(for tracks: [Track], tagged: Set<String>) -> String {
        // An explicit album-artist tag always wins.
        if tagged.count == 1,
           let credited = tracks.compactMap({ $0.albumArtist })
               .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            return credited
        }

        // Otherwise fall back to the track artists — one name if they agree,
        // "Various Artists" if they don't, which is what a compilation is.
        let distinct = Set(tracks.map { normalize($0.artist) })
        return distinct.count == 1 ? commonest(tracks.map(\.artist)) : "Various Artists"
    }

    // MARK: - Ordering

    /// Disc, then track number, then title — so an album reads in play order
    /// rather than filesystem order.
    private static func ordered(_ tracks: [Track]) -> [Track] {
        tracks.sorted { $0.albumSortKey < $1.albumSortKey }
    }

    /// A *total* order. Sorting on title alone leaves same-named albums in
    /// whatever arbitrary order the dictionary produced, which changes
    /// between recomputations and makes cards visibly swap places.
    private static func precedes(_ lhs: Album, _ rhs: Album) -> Bool {
        switch lhs.title.localizedCaseInsensitiveCompare(rhs.title) {
        case .orderedAscending: return true
        case .orderedDescending: return false
        case .orderedSame: break
        }
        switch lhs.artist.localizedCaseInsensitiveCompare(rhs.artist) {
        case .orderedAscending: return true
        case .orderedDescending: return false
        case .orderedSame: return lhs.id < rhs.id     // final tie-break
        }
    }

    // MARK: - Text

    /// Case-, accent- and whitespace-insensitive key for matching tags that
    /// were typed by different people at different times.
    static func normalize(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                     locale: .current)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// The spelling used by the most files, ties broken alphabetically so the
    /// displayed name never changes between launches.
    private static func commonest(_ values: [String]) -> String {
        let counts = values.reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        let best = counts.max { lhs, rhs in
            lhs.value != rhs.value ? lhs.value < rhs.value : lhs.key > rhs.key
        }
        return best?.key ?? values.first ?? "Unknown Album"
    }
}
