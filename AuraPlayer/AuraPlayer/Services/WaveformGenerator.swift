//
//  WaveformGenerator.swift
//  AuraPlayer
//
//  Downsamples an audio file into N peak-amplitude points for display.
//  Seeks per bucket instead of decoding the whole file, so a 60-minute
//  track costs about the same as a 3-minute one.
//

import Foundation
import AVFoundation
import Accelerate

enum WaveformGenerator {

    /// Peak envelope of the file, normalized to 0...1.
    static func generate(url: URL, pointCount: Int = 200) async -> [Float] {
        await Task.detached(priority: .utility) { () -> [Float] in
            guard let file = try? AVAudioFile(forReading: url) else { return [] }

            let format = file.processingFormat
            let totalFrames = file.length
            guard totalFrames > 0 else { return [] }

            let framesPerPoint = max(1, Int(totalFrames) / pointCount)
            let window = AVAudioFrameCount(min(framesPerPoint, 4096))

            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: window) else {
                return []
            }

            var points = [Float](repeating: 0, count: pointCount)

            for i in 0..<pointCount {
                if Task.isCancelled { return [] }

                let position = AVAudioFramePosition(i * framesPerPoint)
                guard position < totalFrames else { break }

                file.framePosition = position
                do {
                    try file.read(into: buffer, frameCount: window)
                } catch {
                    break
                }

                let n = Int(buffer.frameLength)
                guard n > 0, let channel = buffer.floatChannelData?[0] else { break }

                var peak: Float = 0
                vDSP_maxmgv(channel, 1, &peak, vDSP_Length(n))
                points[i] = peak
            }

            // Normalize so quiet tracks still fill the view.
            if let maxValue = points.max(), maxValue > 0 {
                points = points.map { $0 / maxValue }
            }
            return points
        }.value
    }
}
