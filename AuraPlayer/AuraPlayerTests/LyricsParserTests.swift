//
//  LyricsParserTests.swift
//  AuraPlayerTests
//
//  Parsing .lrc files is pure logic with lots of edge cases — the ideal
//  place to have a regression net.
//

import Testing
@testable import AuraPlayer

struct LyricsParserTests {

    // MARK: - Synced parsing

    @Test func parsesTimestampsIntoSeconds() {
        let lyrics = LyricsParser.parse("""
        [00:12.50]First line
        [01:05.00]Second line
        """)

        #expect(lyrics.lines.count == 2)
        #expect(lyrics.isSynced)
        #expect(lyrics.lines[0].time == 12.5)
        #expect(lyrics.lines[0].text == "First line")
        #expect(lyrics.lines[1].time == 65.0)
    }

    @Test func handlesTimestampsWithoutFractions() {
        let lyrics = LyricsParser.parse("[02:30]Halfway there")

        #expect(lyrics.lines.first?.time == 150)
        #expect(lyrics.lines.first?.text == "Halfway there")
    }

    /// Fractions may be 1–3 digits; ".5" means half a second, not 5ms.
    @Test func scalesFractionsByDigitCount() {
        let twoDigits = LyricsParser.parse("[00:01.25]x").lines.first?.time
        let threeDigits = LyricsParser.parse("[00:01.250]x").lines.first?.time

        #expect(twoDigits == 1.25)
        #expect(threeDigits == 1.25)
    }

    /// A repeated chorus can carry several timestamps on one line.
    @Test func expandsMultipleTimestampsOnOneLine() {
        let lyrics = LyricsParser.parse("[00:10.00][01:20.00]Chorus")

        #expect(lyrics.lines.count == 2)
        #expect(lyrics.lines.allSatisfy { $0.text == "Chorus" })
        #expect(lyrics.lines[0].time == 10)
        #expect(lyrics.lines[1].time == 80)
    }

    @Test func sortsSyncedLinesByTime() {
        let lyrics = LyricsParser.parse("""
        [00:30.00]Later
        [00:10.00]Earlier
        """)

        #expect(lyrics.lines[0].text == "Earlier")
        #expect(lyrics.lines[1].text == "Later")
    }

    // MARK: - Plain text and noise

    @Test func treatsUntimedTextAsPlainLyrics() {
        let lyrics = LyricsParser.parse("""
        Just some words
        And more words
        """)

        #expect(lyrics.lines.count == 2)
        #expect(!lyrics.isSynced)
        #expect(lyrics.lines.allSatisfy { $0.time == nil })
    }

    @Test func skipsMetadataTagsAndBlankLines() {
        let lyrics = LyricsParser.parse("""
        [ar:Some Artist]
        [ti:Some Title]

        [00:05.00]Actual lyric
        """)

        #expect(lyrics.lines.count == 1)
        #expect(lyrics.lines.first?.text == "Actual lyric")
    }

    @Test func ignoresTimestampsWithNoText() {
        let lyrics = LyricsParser.parse("""
        [00:01.00]
        [00:02.00]Real line
        """)

        #expect(lyrics.lines.count == 1)
        #expect(lyrics.lines.first?.text == "Real line")
    }

    @Test func emptyInputProducesEmptyLyrics() {
        #expect(LyricsParser.parse("").isEmpty)
    }

    // MARK: - Active line lookup

    @Test func findsActiveLineForCurrentTime() {
        let lyrics = LyricsParser.parse("""
        [00:00.00]One
        [00:10.00]Two
        [00:20.00]Three
        """)

        #expect(lyrics.activeIndex(at: 0) == 0)
        #expect(lyrics.activeIndex(at: 9.9) == 0)
        #expect(lyrics.activeIndex(at: 10) == 1)
        #expect(lyrics.activeIndex(at: 999) == 2)
    }

    @Test func plainLyricsHaveNoActiveLine() {
        let lyrics = LyricsParser.parse("No timestamps here")
        #expect(lyrics.activeIndex(at: 42) == nil)
    }
}
