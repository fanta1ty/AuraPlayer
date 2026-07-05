//
//  AudioSessionManager.swift
//  AuraPlayer
//
//  Created by mobile on 5/7/26.
//
//  Configures AVAudioSession for music playback and handles
//  interruptions (calls/Siri) and route changes (headphones unplugged)
//

import Foundation
import AVFoundation

final class AudioSessionManager {
    static let shared = AudioSessionManager()
    
    /// Called when the session is interrupted or a route change requires pausing.
    /// The player/engine layer sets this to react (e.g. pause playback).
    var onShouldPause: (() -> Void)?
    
    /// Called when an interruption ends and the system hints we may resume.
    var onMayResume: (() -> Void)?
    
    private let session = AVAudioSession.sharedInstance()
    
    private init() {}
    
    // MARK: - Configuration
    
    /// Configure and activate the session. Call once on app launch.
    func configure() {
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            
            registerObservers()
        } catch {
            print("⚠️ AudioSession configuration failed: \(error)")
        }
    }
    
    func activate() {
        do {
            try session.setActive(true)
        } catch {
            print("⚠️ AudioSession activate failed: \(error)")
        }
    }
    
    // MARK: - Notifications
    
    private func registerObservers() {
        let nc = NotificationCenter.default
        nc
            .addObserver(
                self,
                selector: #selector(handleInterruption(_:)),
                name: AVAudioSession.interruptionNotification,
                object: session
            )
        
        nc
            .addObserver(
                self,
                selector: #selector(handleRouteChange(_:)),
                name: AVAudioSession.routeChangeNotification,
                object: session
            )
    }
    
    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
                let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                let type = AVAudioSession.InterruptionType(rawValue: raw) else {
            return
        }
        
        switch type {
        case .began:
            // A call/Siri/alarm started - pause
            onShouldPause?()
        case .ended:
            // Interruption over. If the system says we should resume, offer it.
            if let optionsRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(
                    rawValue: optionsRaw
                )
                if options.contains(.shouldResume) {
                    onMayResume?()
                }
            }
        @unknown default:
            break
        }
    }
    
    @objc private func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let raw = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else {
            return
        }
        
        // Headphones/Bluetooth removed -> pause (don't blast the speaker)
        if reason == .oldDeviceUnavailable {
            onShouldPause?()
        }
    }
}
