//
//  EQPresetStore.swift
//  AuraPlayer
//
//  Persists user-created EQ presets in UserDefaults as JSON.
//

import Foundation

enum EQPresetStore {
    private static let key = "eq.customPresets"

    static func load() -> [EQPreset] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([EQPreset].self, from: data)) ?? []
    }

    static func save(_ presets: [EQPreset]) {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
