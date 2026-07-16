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

// MARK: - Remote commands

extension LockScreenManager {

    struct Handlers {
        var play: () -> Void
        var pause: () -> Void
        var toggle: () -> Void
        var next: () -> Void
        var previous: () -> Void
        var seek: (TimeInterval) -> Void
    }

    /// Register lock screen / Control Center / headphone command handlers.
    /// Registering at least one command is what makes iOS show our now-playing info.
    func configureRemoteCommands(_ handlers: Handlers) {
        let center = MPRemoteCommandCenter.shared()

        // Clear any previous targets (safe if called more than once).
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.togglePlayPauseCommand.removeTarget(nil)
        center.nextTrackCommand.removeTarget(nil)
        center.previousTrackCommand.removeTarget(nil)
        center.changePlaybackPositionCommand.removeTarget(nil)

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { _ in
            handlers.play()
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { _ in
            handlers.pause()
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { _ in
            handlers.toggle()
            return .success
        }

        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { _ in
            handlers.next()
            return .success
        }

        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { _ in
            handlers.previous()
            return .success
        }

        // Lock screen scrubbing
        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            handlers.seek(event.positionTime)
            return .success
        }

        // Commands we don't support — hide them.
        center.ratingCommand.isEnabled = false
        center.likeCommand.isEnabled = false
        center.dislikeCommand.isEnabled = false
        center.bookmarkCommand.isEnabled = false
        center.changeRepeatModeCommand.isEnabled = false
        center.changeShuffleModeCommand.isEnabled = false
        center.skipForwardCommand.isEnabled = false
        center.skipBackwardCommand.isEnabled = false
        center.seekForwardCommand.isEnabled = false
        center.seekBackwardCommand.isEnabled = false
    }
}
