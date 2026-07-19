//
//  EQPreset.swift
//  AuraPlayer
//
//  A named set of 10 band gains. Built-ins are code-defined;
//  custom presets are user-saved.
//

import Foundation

struct EQPreset: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var gains: [Float]        // 10 values, band order (32Hz ... 16kHz)
    var isBuiltIn: Bool

    init(id: UUID = UUID(), name: String, gains: [Float], isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.gains = gains
        self.isBuiltIn = isBuiltIn
    }
}

extension EQPreset {
    //                                    32   64  125  250  500   1k   2k   4k   8k  16k
    static let flat       = EQPreset(name: "Flat",       gains: [ 0,  0,  0,  0,  0,  0,  0,  0,  0,  0], isBuiltIn: true)
    static let bassBoost  = EQPreset(name: "Bass Boost", gains: [ 6,  5,  4,  2,  0,  0,  0,  0,  0,  0], isBuiltIn: true)
    static let rock       = EQPreset(name: "Rock",       gains: [ 5,  4,  3,  1, -1, -1,  1,  3,  4,  4], isBuiltIn: true)
    static let pop        = EQPreset(name: "Pop",        gains: [-1,  0,  2,  4,  4,  2,  0, -1, -1, -1], isBuiltIn: true)
    static let jazz       = EQPreset(name: "Jazz",       gains: [ 3,  2,  1,  2, -1, -1,  0,  1,  2,  3], isBuiltIn: true)
    static let classical  = EQPreset(name: "Classical",  gains: [ 4,  3,  2,  0, -1, -1,  0,  2,  3,  4], isBuiltIn: true)
    static let vocal      = EQPreset(name: "Vocal",      gains: [-2, -2,  0,  2,  4,  4,  3,  1,  0, -1], isBuiltIn: true)
    static let electronic = EQPreset(name: "Electronic", gains: [ 5,  4,  1,  0, -2,  1,  0,  1,  4,  5], isBuiltIn: true)
    static let hipHop     = EQPreset(name: "Hip-Hop",    gains: [ 6,  5,  3,  1, -1, -1,  1,  2,  3,  3], isBuiltIn: true)

    static let builtIns: [EQPreset] = [
        .flat, .bassBoost, .rock, .pop, .jazz, .classical, .vocal, .electronic, .hipHop
    ]
}
