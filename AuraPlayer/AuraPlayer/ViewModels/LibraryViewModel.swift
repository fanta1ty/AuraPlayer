//
//  LibraryViewModel.swift
//  AuraPlayer
//
//  Created by mobile on 12/7/26.
//
//  Runs the library scan and publishes the resulting tracks.
//

import Foundation
import Combine

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published private(set) var tracks: [Track] = []
    @Published private(set) var isScanning = false
    
    func scan() async {
        isScanning = true
        tracks = await LibraryScanner.scanDocuments()
        isScanning = false

        // Show the library immediately, then fill in missing artwork
        // from cache/network and republish.
        let enhanced = await MetadataEnhancer.enhance(tracks)
        if enhanced.count == tracks.count {
            tracks = enhanced
        }
    }
}
