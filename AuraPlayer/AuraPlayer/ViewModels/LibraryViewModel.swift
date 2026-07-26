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
        let scanned = await LibraryScanner.scanDocuments()
        tracks = MetadataOverrideViewModel.shared.applying(scanned)
        isScanning = false

        // Show the library immediately, then fill in missing artwork
        // from cache/network and republish.
        let enhanced = await MetadataEnhancer.enhance(tracks)
        if enhanced.count == tracks.count {
            tracks = MetadataOverrideViewModel.shared.applying(enhanced)
        }
    }

    /// Re-apply user edits without re-reading every file (fast path after editing).
    func refreshOverrides() {
        tracks = MetadataOverrideViewModel.shared.applying(tracks)
    }
}
