//
//  HTTPRequest.swift
//  AuraPlayer
//
//  Just enough HTTP/1.1 parsing for the Wi-Fi transfer server: request line,
//  headers, and multipart/form-data file uploads.
//

import Foundation

struct HTTPRequest {
    var method: String
    var path: String
    var query: [String: String]
    var headers: [String: String]
    var body: Data

    /// Total bytes the client said it would send.
    var contentLength: Int {
        Int(headers["content-length"] ?? "") ?? 0
    }

    /// Parse headers only. Returns nil while the header block is incomplete.
    static func parseHead(_ data: Data) -> (request: HTTPRequest, headerLength: Int)? {
        let separator = Data("\r\n\r\n".utf8)
        guard let range = data.range(of: separator) else { return nil }

        let headText = String(decoding: data[..<range.lowerBound], as: UTF8.self)
        var lines = headText.components(separatedBy: "\r\n")
        guard !lines.isEmpty else { return nil }

        // "GET /path?a=b HTTP/1.1"
        let requestLine = lines.removeFirst().split(separator: " ")
        guard requestLine.count >= 2 else { return nil }

        let method = String(requestLine[0])
        let target = String(requestLine[1])

        var path = target
        var query: [String: String] = [:]
        if let q = target.firstIndex(of: "?") {
            path = String(target[..<q])
            let queryString = String(target[target.index(after: q)...])
            for pair in queryString.split(separator: "&") {
                let parts = pair.split(separator: "=", maxSplits: 1)
                guard parts.count == 2 else { continue }
                query[String(parts[0]).removingPercentEncoding ?? String(parts[0])] =
                    String(parts[1]).removingPercentEncoding?.replacingOccurrences(of: "+", with: " ")
                    ?? String(parts[1])
            }
        }

        var headers: [String: String] = [:]
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }

        let request = HTTPRequest(method: method, path: path.removingPercentEncoding ?? path,
                                  query: query, headers: headers, body: Data())
        return (request, range.upperBound)
    }

    // MARK: - Multipart

    struct FilePart {
        let filename: String
        let data: Data
    }

    /// Extract uploaded files from a multipart/form-data body.
    func multipartFiles() -> [FilePart] {
        guard let contentType = headers["content-type"],
              let boundaryRange = contentType.range(of: "boundary=")
        else { return [] }

        var boundary = String(contentType[boundaryRange.upperBound...])
        if boundary.hasPrefix("\"") { boundary = String(boundary.dropFirst().dropLast()) }

        let delimiter = Data("--\(boundary)".utf8)
        let separator = Data("\r\n\r\n".utf8)

        var files: [FilePart] = []
        var searchStart = body.startIndex

        while let start = body.range(of: delimiter, in: searchStart..<body.endIndex) {
            let partStart = start.upperBound
            guard partStart < body.endIndex else { break }

            // Find where this part ends (the next boundary).
            let nextStart = body.range(of: delimiter, in: partStart..<body.endIndex)?.lowerBound
                ?? body.endIndex
            guard let headerEnd = body.range(of: separator, in: partStart..<nextStart) else {
                searchStart = nextStart
                if nextStart == body.endIndex { break }
                continue
            }

            let partHeaders = String(decoding: body[partStart..<headerEnd.lowerBound], as: UTF8.self)

            if let filename = Self.filename(in: partHeaders), !filename.isEmpty {
                var contentEnd = nextStart
                // Trim the CRLF that precedes the next boundary.
                if contentEnd > headerEnd.upperBound + 1 { contentEnd -= 2 }
                let content = body[headerEnd.upperBound..<contentEnd]
                if !content.isEmpty {
                    files.append(FilePart(filename: filename, data: Data(content)))
                }
            }

            searchStart = nextStart
            if nextStart == body.endIndex { break }
        }
        return files
    }

    /// filename="Song.mp3" out of a Content-Disposition header.
    private static func filename(in headers: String) -> String? {
        guard let range = headers.range(of: "filename=\"") else { return nil }
        let rest = headers[range.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return nil }
        // Browsers may send a full path; keep only the last component.
        return String(rest[..<end]).components(separatedBy: "/").last
    }
}
