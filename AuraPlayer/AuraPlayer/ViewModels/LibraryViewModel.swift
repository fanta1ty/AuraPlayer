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
    }
}
