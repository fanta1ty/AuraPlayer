//
//  SmartPlaylist.swift
//  AuraPlayer
//
//  A playlist defined by rules rather than a fixed track list, so it stays
//  current as ratings, play counts and imports change.
//

import Foundation

/// What a rule looks at.
enum SmartField: String, Codable, CaseIterable, Identifiable {
    case rating
    case playCount
    case lastPlayed        // days ago
    case dateAdded         // days ago
    case artist
    case album
    case genre

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rating:     return "Rating"
        case .playCount:  return "Play count"
        case .lastPlayed: return "Last played"
        case .dateAdded:  return "Date added"
        case .artist:     return "Artist"
        case .album:      return "Album"
        case .genre:      return "Genre"
        }
    }

    var isText: Bool {
        switch self {
        case .artist, .album, .genre: return true
        default: return false
        }
    }

    /// Days-based fields read more naturally as "within the last N days".
    var isDayCount: Bool {
        self == .lastPlayed || self == .dateAdded
    }
}

enum SmartComparison: String, Codable, CaseIterable, Identifiable {
    case isAtLeast
    case isAtMost
    case isExactly
    case contains
    case isNot
    case isNever          // never played

    var id: String { rawValue }

    var label: String {
        switch self {
        case .isAtLeast: return "is at least"
        case .isAtMost:  return "is at most"
        case .isExactly: return "is"
        case .contains:  return "contains"
        case .isNot:     return "is not"
        case .isNever:   return "never"
        }
    }

    static func options(for field: SmartField) -> [SmartComparison] {
        if field.isText { return [.contains, .isExactly, .isNot] }
        if field == .lastPlayed { return [.isAtMost, .isAtLeast, .isNever] }
        return [.isAtLeast, .isAtMost, .isExactly]
    }
}

struct SmartRule: Codable, Identifiable, Hashable {
    var id = UUID()
    var field: SmartField = .rating
    var comparison: SmartComparison = .isAtLeast
    /// Numeric rules use `number`; text rules use `text`.
    var number: Int = 4
    var text: String = ""
}

struct SmartPlaylist: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var rules: [SmartRule]
    /// All rules must pass, or any one of them.
    var matchAll: Bool = true
    var limit: Int?
    var createdDate: Date = .now

    /// Ready-made starting points.
    static var presets: [SmartPlaylist] {
        [
            SmartPlaylist(name: "Favourites",
                          rules: [SmartRule(field: .rating, comparison: .isAtLeast, number: 4)]),
            SmartPlaylist(name: "Never Played",
                          rules: [SmartRule(field: .lastPlayed, comparison: .isNever)]),
            SmartPlaylist(name: "Recently Added",
                          rules: [SmartRule(field: .dateAdded, comparison: .isAtMost, number: 30)]),
            SmartPlaylist(name: "Most Played",
                          rules: [SmartRule(field: .playCount, comparison: .isAtLeast, number: 5)])
        ]
    }
}
