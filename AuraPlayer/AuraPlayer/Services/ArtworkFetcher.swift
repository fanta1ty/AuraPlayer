//
//  ArtworkFetcher.swift
//  AuraPlayer
//
//  Looks up cover art via the public iTunes Search API.
//

import Foundation

enum ArtworkFetcher {

    private struct SearchResponse: Decodable {
        struct Item: Decodable { let artworkUrl100: String? }
        let results: [Item]
    }

    /// Returns JPEG data for the best match, or nil if nothing was found.
    static func fetchArtwork(title: String, artist: String) async -> Data? {
        var term = title
        if !artist.isEmpty, artist != "Unknown Artist" {
            term += " " + artist
        }

        guard var components = URLComponents(string: "https://itunes.apple.com/search") else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let searchURL = components.url else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: searchURL)
            let response = try JSONDecoder().decode(SearchResponse.self, from: data)
            guard let small = response.results.first?.artworkUrl100 else { return nil }

            // The API returns 100x100; ask for a usable size instead.
            let large = small.replacingOccurrences(of: "100x100bb", with: "600x600bb")
            guard let artURL = URL(string: large) else { return nil }

            let (imageData, _) = try await URLSession.shared.data(from: artURL)
            return imageData
        } catch {
            return nil
        }
    }
}
