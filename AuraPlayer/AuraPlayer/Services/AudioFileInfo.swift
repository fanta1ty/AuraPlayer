//
//  AudioFileInfo.swift
//  AuraPlayer
//
//  Technical details about an audio file: format, sample rate, bit depth,
//  bitrate and size. Read on demand for the Info screen.
//

import Foundation
import AVFoundation

struct AudioFileInfo {
    var format: String          // "MP3", "FLAC", …
    var sampleRate: Double      // Hz
    var channels: UInt32
    var bitDepth: UInt32?       // nil for lossy/compressed formats
    var bitrate: Double?        // bits per second
    var fileSize: Int64
    var isLossless: Bool

    // MARK: - Display helpers

    var sampleRateText: String {
        String(format: "%.1f kHz", sampleRate / 1000)
    }

    var channelsText: String {
        switch channels {
        case 1:  return "Mono"
        case 2:  return "Stereo"
        default: return "\(channels) channels"
        }
    }

    var bitDepthText: String? {
        bitDepth.map { "\($0)-bit" }
    }

    var bitrateText: String? {
        guard let bitrate, bitrate > 0 else { return nil }
        return String(format: "%.0f kbps", bitrate / 1000)
    }

    var fileSizeText: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    /// "FLAC · 44.1 kHz · 16-bit"
    var summary: String {
        [format, sampleRateText, bitDepthText].compactMap { $0 }.joined(separator: " · ")
    }

    // MARK: - Loading

    private static let losslessExtensions: Set<String> = ["flac", "alac", "wav", "aiff", "dsf", "dff"]

    static func load(for url: URL) async -> AudioFileInfo? {
        let ext = url.pathExtension.lowercased()
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0

        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let format = file.fileFormat

        // Bit depth is only meaningful for uncompressed/lossless streams.
        var bitDepth: UInt32?
        let description = format.streamDescription.pointee
        if description.mBitsPerChannel > 0 {
            bitDepth = description.mBitsPerChannel
        }

        // Bitrate comes from the asset; for lossless we can derive it instead.
        var bitrate: Double?
        let asset = AVURLAsset(url: url)
        if let track = try? await asset.loadTracks(withMediaType: .audio).first,
           let rate = try? await track.load(.estimatedDataRate), rate > 0 {
            bitrate = Double(rate)
        } else if size > 0, file.length > 0, format.sampleRate > 0 {
            let seconds = Double(file.length) / format.sampleRate
            if seconds > 0 { bitrate = Double(size) * 8 / seconds }
        }

        return AudioFileInfo(
            format: ext.uppercased(),
            sampleRate: format.sampleRate,
            channels: format.channelCount,
            bitDepth: bitDepth,
            bitrate: bitrate,
            fileSize: size,
            isLossless: losslessExtensions.contains(ext)
        )
    }
}
