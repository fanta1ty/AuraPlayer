//
//  AuraPlayerTests.swift
//  AuraPlayerTests
//
//  Created by mobile on 4/7/26.
//
//  Test suites live in dedicated files:
//    • LyricsParserTests — .lrc parsing and active-line lookup
//    • EQCurveTests      — frequency response maths
//    • ModelTests        — downloads, EQ presets, overrides, playlists
//

import Testing
@testable import AuraPlayer

struct AuraPlayerTests {

    /// Sanity check that the test target can see the app module.
    @Test func appModuleIsReachable() {
        #expect(AuraAudioEngine.eqFrequencies.count == 10)
        #expect(AuraSpacing.md == 16)
    }
}
