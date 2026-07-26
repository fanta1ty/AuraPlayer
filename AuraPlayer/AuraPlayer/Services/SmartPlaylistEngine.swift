//
//  SmartPlaylistEngine.swift
//  AuraPlayer
//
//  Evaluates smart-playlist rules against the library. Stats (rating, play
//  count, last played) live in TrackStatsViewModel, so they're passed in.
//

import Foundation

enum SmartPlaylistEngine {

    /// Tracks matching the playlist's rules, newest-first for date fields.
    static func evaluate(_ playlist: SmartPlaylist,
                         tracks: [Track],
                         stats: TrackStatsViewModel) -> [Track] {

        guard !playlist.rules.isEmpty else { return [] }

        var matched = tracks.filter { track in
            let results = playlist.rules.map { matches($0, track: track, stats: stats) }
            return playlist.matchAll ? !results.contains(false) : results.contains(true)
        }

        // Sensible ordering: most recently added first.
        matched.sort { $0.dateAdded > $1.dateAdded }

        if let limit = playlist.limit, matched.count > limit {
            matched = Array(matched.prefix(limit))
        }
        return matched
    }

    // MARK: - Rule evaluation

    private static func matches(_ rule: SmartRule,
                                track: Track,
                                stats: TrackStatsViewModel) -> Bool {
        if rule.field.isText {
            return matchesText(rule, track: track)
        }
        return matchesNumber(rule, track: track, stats: stats)
    }

    private static func matchesText(_ rule: SmartRule, track: Track) -> Bool {
        let needle = rule.text.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return true }   // an empty rule filters nothing

        let haystack: String
        switch rule.field {
        case .artist: haystack = track.artist
        case .album:  haystack = track.album
        case .genre:  haystack = track.genre ?? ""
        default:      return true
        }

        switch rule.comparison {
        case .contains:  return haystack.localizedCaseInsensitiveContains(needle)
        case .isExactly: return haystack.compare(needle, options: .caseInsensitive) == .orderedSame
        case .isNot:     return haystack.compare(needle, options: .caseInsensitive) != .orderedSame
        default:         return true
        }
    }

    private static func matchesNumber(_ rule: SmartRule,
                                      track: Track,
                                      stats: TrackStatsViewModel) -> Bool {
        // "Never played" is a presence check, not a comparison.
        if rule.field == .lastPlayed, rule.comparison == .isNever {
            return stats.lastPlayed(for: track.url) == nil
        }

        let value: Int
        switch rule.field {
        case .rating:
            value = stats.rating(for: track.url)
        case .playCount:
            value = stats.playCount(for: track.url)
        case .lastPlayed:
            guard let date = stats.lastPlayed(for: track.url) else { return false }
            value = daysSince(date)
        case .dateAdded:
            value = daysSince(track.dateAdded)
        default:
            return true
        }

        switch rule.comparison {
        case .isAtLeast: return value >= rule.number
        case .isAtMost:  return value <= rule.number
        case .isExactly: return value == rule.number
        default:         return true
        }
    }

    private static func daysSince(_ date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: date, to: .now).day ?? 0
    }

    /// Human-readable rule, e.g. "Rating is at least 4".
    static func describe(_ rule: SmartRule) -> String {
        if rule.field == .lastPlayed, rule.comparison == .isNever {
            return "Never played"
        }
        if rule.field.isText {
            return "\(rule.field.label) \(rule.comparison.label) \"\(rule.text)\""
        }
        if rule.field.isDayCount {
            return "\(rule.field.label) \(rule.comparison.label) \(rule.number) days ago"
        }
        return "\(rule.field.label) \(rule.comparison.label) \(rule.number)"
    }
}
