//
//  VolumeControls.swift
//  AuraPlayer
//
//  Created by mobile on 11/7/26.
//
//  System volume slider (MPVolumeView) + AirPlay route picker (AVRoutePickerView).
//  MPVolumeView is the only Apple-sanctioned way to control device volume;
//  AVAudioSession.outputVolume is read-only.
//

import SwiftUI
import MediaPlayer
import AVKit

/// The real system volume slider, tinted to match the design.
struct SystemVolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        view.showsVolumeSlider = true
        if let slider = view.subviews.compactMap({ $0 as? UISlider })
            .first {
            slider.minimumTrackTintColor = UIColor(Color.accent)
            slider.maximumTrackTintColor = UIColor(Color.surfaceElevated)
        }
        return view
    }
    
    func updateUIView(_ uiView: MPVolumeView, context: Context) {
        
    }
}

/// AirPlay / output-device picker button
struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView(frame: .zero)
        view.tintColor = UIColor(Color.textSecondary)
        view.activeTintColor = UIColor(Color.accent)
        view.prioritizesVideoDevices = false
        return view
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        
    }
}
