//
//  DownloadManager.swift
//  AuraPlayer
//
//  Background URLSession downloads with a 3-at-a-time queue.
//  Background sessions survive app suspension, so we must use the delegate
//  API (not async/await) and move the finished file synchronously.
//

import Foundation
import Combine

@MainActor
final class DownloadManager: NSObject, ObservableObject {

    static let shared = DownloadManager()

    static let maxConcurrent = 3

    @Published private(set) var items: [DownloadItem] = []

    /// Called after a file lands successfully, so the library can rescan.
    var onDownloadFinished: (() -> Void)?

    private var session: URLSession!
    /// Maps URLSession task identifiers back to our items.
    private var taskMap: [Int: UUID] = [:]
    /// Partial data captured when a download is paused.
    private var resumeData: [UUID: Data] = [:]
    /// Last progress sample per item, for speed calculation.
    private var progressStamps: [UUID: (time: Date, bytes: Int64)] = [:]

    private override init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: "com.auraplayer.downloads")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        // Delegate callbacks arrive off the main thread; we hop back in each one.
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    // MARK: - Queue control

    func enqueue(urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme?.hasPrefix("http") == true else { return }
        items.append(DownloadItem(url: url))
        startNextIfPossible()
    }

    func cancel(_ item: DownloadItem) {
        if let taskID = taskMap.first(where: { $0.value == item.id })?.key {
            session.getAllTasks { tasks in
                tasks.first { $0.taskIdentifier == taskID }?.cancel()
            }
            taskMap.removeValue(forKey: taskID)
        }
        update(item.id) { $0.status = .cancelled }
        startNextIfPossible()
    }

    /// Pause by cancelling with resume data so we can continue from the same byte.
    func pause(_ item: DownloadItem) {
        guard let taskID = taskMap.first(where: { $0.value == item.id })?.key else { return }
        session.getAllTasks { tasks in
            guard let task = tasks.first(where: { $0.taskIdentifier == taskID }) as? URLSessionDownloadTask
            else { return }
            task.cancel(byProducingResumeData: { data in
                Task { @MainActor in
                    if let data { self.resumeData[item.id] = data }
                    self.taskMap.removeValue(forKey: taskID)
                    self.update(item.id) { $0.status = .paused; $0.speed = 0 }
                    self.startNextIfPossible()
                }
            })
        }
    }

    func resume(_ item: DownloadItem) {
        update(item.id) { $0.status = .queued }
        startNextIfPossible()
    }

    func retry(_ item: DownloadItem) {
        update(item.id) { $0.status = .queued; $0.progress = 0; $0.bytesWritten = 0 }
        startNextIfPossible()
    }

    func clearCompleted() {
        items.removeAll {
            if case .finished = $0.status { return true }
            if case .cancelled = $0.status { return true }
            if case .failed = $0.status { return true }
            return false
        }
    }

    private var activeCount: Int {
        items.filter { $0.status == .downloading }.count
    }

    private func startNextIfPossible() {
        guard activeCount < Self.maxConcurrent else { return }
        guard let next = items.first(where: { $0.status == .queued }) else { return }

        // Continue from partial data when resuming a paused download.
        let task: URLSessionDownloadTask
        if let data = resumeData.removeValue(forKey: next.id) {
            task = session.downloadTask(withResumeData: data)
        } else {
            task = session.downloadTask(with: next.url)
        }
        taskMap[task.taskIdentifier] = next.id
        update(next.id) { $0.status = .downloading }
        task.resume()

        // Fill remaining slots.
        if activeCount < Self.maxConcurrent { startNextIfPossible() }
    }

    private func update(_ id: UUID, _ change: (inout DownloadItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[index])
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManager: URLSessionDownloadDelegate {

    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didWriteData bytesWritten: Int64,
                                totalBytesWritten: Int64,
                                totalBytesExpectedToWrite: Int64) {
        let taskID = downloadTask.taskIdentifier
        Task { @MainActor in
            guard let id = self.taskMap[taskID] else { return }
            // Sample transfer speed at most twice a second.
            var speed: Double?
            let now = Date()
            if let last = self.progressStamps[id] {
                let dt = now.timeIntervalSince(last.time)
                if dt >= 0.5 {
                    speed = Double(totalBytesWritten - last.bytes) / dt
                    self.progressStamps[id] = (now, totalBytesWritten)
                }
            } else {
                self.progressStamps[id] = (now, totalBytesWritten)
            }

            self.update(id) { item in
                item.bytesWritten = totalBytesWritten
                item.totalBytes = totalBytesExpectedToWrite
                item.progress = totalBytesExpectedToWrite > 0
                    ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
                    : 0
                if let speed { item.speed = speed }
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didFinishDownloadingTo location: URL) {
        // `location` is deleted as soon as this method returns — move it NOW,
        // synchronously, before hopping to the main actor.
        let taskID = downloadTask.taskIdentifier
        let suggested = downloadTask.response?.suggestedFilename
        let staged = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "-" + (suggested ?? location.lastPathComponent))
        try? FileManager.default.moveItem(at: location, to: staged)

        Task { @MainActor in
            guard let id = self.taskMap[taskID] else { return }
            self.taskMap.removeValue(forKey: taskID)

            let imported = AudioImporter.importFiles([staged])
            try? FileManager.default.removeItem(at: staged)

            if let destination = imported.first {
                let sourceURL = self.items.first(where: { $0.id == id })?.url
                self.update(id) { item in
                    item.filename = destination.lastPathComponent
                    item.progress = 1
                    item.status = .finished
                }
                if let sourceURL {
                    DownloadHistory.append(filename: destination.lastPathComponent,
                                           sourceURL: sourceURL)
                }
                self.onDownloadFinished?()
            } else {
                self.update(id) { $0.status = .failed("Couldn't save file") }
            }
            self.startNextIfPossible()
        }
    }

    nonisolated func urlSession(_ session: URLSession,
                                task: URLSessionTask,
                                didCompleteWithError error: Error?) {
        guard let error else { return }   // success is handled above
        let taskID = task.taskIdentifier
        let message = (error as NSError).code == NSURLErrorCancelled ? nil : error.localizedDescription

        Task { @MainActor in
            guard let id = self.taskMap[taskID] else { return }
            self.taskMap.removeValue(forKey: taskID)
            if let message {
                self.update(id) { $0.status = .failed(message) }
            }
            self.startNextIfPossible()
        }
    }
}
