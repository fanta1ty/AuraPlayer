//
//  LockScreenManager.swift
//  AuraPlayer
//
//  Created by mobile on 16/7/26.
//
//  Publishes now-playing metadata to the system (lock screen, Control Center,
//  CarPlay) via MPNowPlayingInfoCenter.
//

import Foundation
import MediaPlayer
import UIKit

final class LockScreenManager {
    static let shared = LockScreenManager()
    
    private init() {}
    
    private let center = MPNowPlayingInfoCenter.default()
    
    /// Publish full metadata for a newly loaded track.
    func update(title: String,
                artist: String,
                album: String?,
                artwork: UIImage?,
                duration: TimeInterval,
                elapsed: TimeInterval,
                rate: Double) {
        
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyArtist] = artist
        if let album, !album.isEmpty {
            info[MPMediaItemPropertyAlbumTitle] = album
        }
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        info[MPNowPlayingInfoPropertyPlaybackRate] = rate
        
        if let artwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(
                boundsSize: artwork.size
            ) { _ in
                artwork
            }
        }
        
        center.nowPlayingInfo = info
    }
    
    /// Cheap refresh for play/pause, seek, and periodic drift correction.
    func updatePlaybackState(elapsed: TimeInterval, rate: Double) {
        guard var info = center.nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        info[MPNowPlayingInfoPropertyPlaybackRate] = rate
        center.nowPlayingInfo = info
    }
    
    func clear() {
        center.nowPlayingInfo = nil
    }
}
