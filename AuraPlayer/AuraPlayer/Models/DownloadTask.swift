//
//  DownloadTask.swift
//  AuraPlayer
//
//  One queued or in-flight download.
//

import Foundation

enum DownloadStatus: Equatable {
    case queued
    case downloading
    case finished
    case failed(String)
    case cancelled

    var label: String {
        switch self {
        case .queued:            return "Queued"
        case .downloading:       return "Downloading"
        case .finished:          return "Done"
        case .cancelled:         return "Cancelled"
        case .failed(let msg):   return msg
        }
    }
}

struct DownloadItem: Identifiable, Equatable {
    let id: UUID
    let url: URL
    var filename: String
    var progress: Double        // 0...1
    var status: DownloadStatus
    var bytesWritten: Int64
    var totalBytes: Int64

    init(url: URL) {
        self.id = UUID()
        self.url = url
        // Fall back to a generated name if the URL has no usable last component.
        let last = url.lastPathComponent
        self.filename = last.isEmpty || !last.contains(".") ? "download-\(UUID().uuidString.prefix(6)).mp3" : last
        self.progress = 0
        self.status = .queued
        self.bytesWritten = 0
        self.totalBytes = 0
    }
}
