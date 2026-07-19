//
//  Lyrics.swift
//  AuraPlayer
//
//  Lyrics for a track: either plain text or time-synced (.lrc).
//

import Foundation

struct LyricLine: Identifiable, Hashable {
    let id: Int
    /// Seconds into the track. nil for unsynced lyrics.
    let time: TimeInterval?
    let text: String
}

struct Lyrics: Hashable {
    var lines: [LyricLine]

    var isSynced: Bool { lines.contains { $0.time != nil } }
    var isEmpty: Bool { lines.isEmpty }

    var plainText: String {
        lines.map(\.text).joined(separator: "\n")
    }

    /// Index of the line that should be highlighted at `time`.
    func activeIndex(at time: TimeInterval) -> Int? {
        guard isSynced else { return nil }

        var result: Int?
        for line in lines {
            guard let lineTime = line.time else { continue }
            if lineTime <= time { result = line.id } else { break }
        }
        return result
    }
}

// MARK: - Parsing

enum LyricsParser {

    /// Matches [mm:ss.xx] or [mm:ss] — a line may carry several timestamps.
    private static let timestamp = try! NSRegularExpression(
        pattern: #"\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]"#
    )

    /// Parse .lrc content, falling back to plain text when no timestamps exist.
    static func parse(_ raw: String) -> Lyrics {
        var entries: [(time: TimeInterval?, text: String)] = []

        for rawLine in raw.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            let range = NSRange(line.startIndex..., in: line)
            let matches = timestamp.matches(in: line, range: range)

            guard !matches.isEmpty else {
                // Skip metadata tags like [ar:Artist], keep real text.
                if line.hasPrefix("["), line.hasSuffix("]") { continue }
                entries.append((nil, line))
                continue
            }

            // Text is whatever follows the final timestamp.
            let textStart = line.index(line.startIndex, offsetBy: matches.last!.range.upperBound)
            let text = String(line[textStart...]).trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }

            // One line can repeat for multiple timestamps.
            for match in matches {
                guard let minutes = Int(substring(line, match.range(at: 1))),
                      let seconds = Int(substring(line, match.range(at: 2))) else { continue }

                var time = TimeInterval(minutes * 60 + seconds)
                let fractionRange = match.range(at: 3)
                if fractionRange.location != NSNotFound {
                    let digits = substring(line, fractionRange)
                    if let value = Double(digits) {
                        time += value / pow(10, Double(digits.count))
                    }
                }
                entries.append((time, text))
            }
        }

        // Synced lines sort by time; unsynced keep their original order.
        if entries.contains(where: { $0.time != nil }) {
            entries.sort { ($0.time ?? 0) < ($1.time ?? 0) }
        }

        return Lyrics(lines: entries.enumerated().map { index, entry in
            LyricLine(id: index, time: entry.time, text: entry.text)
        })
    }

    private static func substring(_ string: String, _ range: NSRange) -> String {
        guard let swiftRange = Range(range, in: string) else { return "" }
        return String(string[swiftRange])
    }
}
