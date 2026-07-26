//
//  JSONFileStore.swift
//  AuraPlayer
//
//  Small helper for the app's JSON side-stores. Centralises two things the
//  ad-hoc `try?` calls were getting wrong: failures were silent, and caches
//  kept in UserDefaults grew without bound (UserDefaults is loaded into
//  memory wholesale, so it's the wrong home for per-track data).
//

import Foundation
import os

enum JSONFileStore {

    private static let log = Logger(subsystem: "com.thinh.AuraPlayer", category: "storage")

    /// Documents directory — user data that should persist and be backed up.
    static func documentsURL(_ filename: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
    }

    /// Caches directory — regenerable data the system may purge.
    static func cachesURL(_ filename: String) -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
    }

    static func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
        } catch {
            log.error("Failed to read \(url.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }

    /// Writes atomically. Returns false (and logs) if the write failed, so
    /// callers can tell the user their data didn't save.
    @discardableResult
    static func save<T: Encodable>(_ value: T, to url: URL) -> Bool {
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            log.error("Failed to write \(url.lastPathComponent): \(error.localizedDescription)")
            return false
        }
    }
}

/// A dictionary cache that evicts its oldest entries once it exceeds a limit.
struct BoundedCache<Value: Codable>: Codable {
    private(set) var entries: [String: Value] = [:]
    /// Insertion order, oldest first — used for eviction.
    private(set) var order: [String] = []
    var limit: Int = 2000

    subscript(key: String) -> Value? {
        get { entries[key] }
        set {
            if let newValue {
                if entries[key] == nil { order.append(key) }
                entries[key] = newValue
                evictIfNeeded()
            } else {
                entries.removeValue(forKey: key)
                order.removeAll { $0 == key }
            }
        }
    }

    func contains(_ key: String) -> Bool { entries[key] != nil }

    mutating func removeAll() {
        entries.removeAll()
        order.removeAll()
    }

    private mutating func evictIfNeeded() {
        guard order.count > limit else { return }
        let overflow = order.count - limit
        for key in order.prefix(overflow) { entries.removeValue(forKey: key) }
        order.removeFirst(overflow)
    }
}
