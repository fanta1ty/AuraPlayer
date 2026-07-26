//
//  WiFiTransferServer.swift
//  AuraPlayer
//
//  A tiny HTTP server so a desktop browser on the same Wi-Fi can upload and
//  delete music. Runs only while the screen is on and the view is open —
//  iOS suspends the app in the background, which would drop connections.
//

import Foundation
import Network
import Combine

@MainActor
final class WiFiTransferServer: ObservableObject {

    static let shared = WiFiTransferServer()

    @Published private(set) var isRunning = false
    @Published private(set) var address: String?
    @Published private(set) var lastError: String?
    /// Bumped whenever files change so the UI can rescan.
    @Published private(set) var changeCount = 0

    private var listener: NWListener?
    private let port: NWEndpoint.Port = 8080

    private init() {}

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        lastError = nil

        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            let listener = try NWListener(using: parameters, port: port)

            listener.newConnectionHandler = { [weak self] connection in
                connection.start(queue: .global(qos: .userInitiated))
                Task { @MainActor in self?.receive(on: connection, buffer: Data()) }
            }

            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .ready:
                        self?.isRunning = true
                        self?.address = Self.localAddress().map { "http://\($0):8080" }
                    case .failed(let error):
                        self?.lastError = error.localizedDescription
                        self?.stop()
                    default:
                        break
                    }
                }
            }

            listener.start(queue: .global(qos: .userInitiated))
            self.listener = listener
        } catch {
            lastError = error.localizedDescription
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
        address = nil
    }

    // MARK: - Connection handling

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) {
            [weak self] chunk, _, isComplete, error in

            guard error == nil else { connection.cancel(); return }

            var data = buffer
            if let chunk { data.append(chunk) }

            Task { @MainActor in
                guard let self else { connection.cancel(); return }

                // Wait until the full request (headers + declared body) has arrived.
                guard let (head, headerLength) = HTTPRequest.parseHead(data) else {
                    if isComplete { connection.cancel() }
                    else { self.receive(on: connection, buffer: data) }
                    return
                }

                let expected = headerLength + head.contentLength
                guard data.count >= expected else {
                    if isComplete { connection.cancel() }
                    else { self.receive(on: connection, buffer: data) }
                    return
                }

                var request = head
                request.body = data.subdata(in: headerLength..<expected)
                self.respond(to: request, on: connection)
            }
        }
    }

    private func respond(to request: HTTPRequest, on connection: NWConnection) {
        switch (request.method, request.path) {
        case ("GET", "/"):
            send(html: page(), on: connection)

        case ("POST", "/upload"):
            let files = request.multipartFiles()
            var saved = 0
            for file in files {
                guard LibraryScanner.supportedExtensions
                    .contains((file.filename as NSString).pathExtension.lowercased())
                else { continue }

                let destination = AudioImporter.musicDirectory
                    .appendingPathComponent(file.filename)
                let unique = Self.uniqueURL(for: destination)
                if (try? file.data.write(to: unique, options: .atomic)) != nil { saved += 1 }
            }
            if saved > 0 { changeCount += 1 }
            redirectHome(on: connection)

        case ("POST", "/delete"):
            if let name = request.query["file"] {
                let target = StorageManager.audioFiles().first { $0.name == name }
                if let target {
                    StorageManager.delete(target)
                    changeCount += 1
                }
            }
            redirectHome(on: connection)

        default:
            send(status: "404 Not Found", html: "<h1>Not found</h1>", on: connection)
        }
    }

    // MARK: - Responses

    private func send(html: String, on connection: NWConnection) {
        send(status: "200 OK", html: html, on: connection)
    }

    private func send(status: String, html: String, on connection: NWConnection) {
        let body = Data(html.utf8)
        let header = """
        HTTP/1.1 \(status)\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(body.count)\r
        Connection: close\r
        \r

        """
        var response = Data(header.utf8)
        response.append(body)
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func redirectHome(on connection: NWConnection) {
        let header = "HTTP/1.1 303 See Other\r\nLocation: /\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(header.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    // MARK: - Helpers

    private static func uniqueURL(for url: URL) -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return url }

        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var counter = 2
        var candidate = url
        repeat {
            candidate = url.deletingLastPathComponent()
                .appendingPathComponent("\(base) \(counter).\(ext)")
            counter += 1
        } while fm.fileExists(atPath: candidate.path)
        return candidate
    }

    /// The device's Wi-Fi IPv4 address, so we can show a reachable URL.
    private static func localAddress() -> String? {
        var address: String?
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return nil }
        defer { freeifaddrs(head) }

        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            guard interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            // en0 is Wi-Fi on iOS devices.
            guard String(cString: interface.ifa_name) == "en0" else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname, socklen_t(hostname.count),
                        nil, 0, NI_NUMERICHOST)
            address = String(cString: hostname)
        }
        return address
    }

    // MARK: - Page

    private func page() -> String {
        let files = StorageManager.audioFiles()
        let total = StorageManager.formatted(StorageManager.totalSize(of: files))

        let rows = files.map { file in
            """
            <tr>
              <td>\(escape(file.name))</td>
              <td class="size">\(StorageManager.formatted(file.size))</td>
              <td>
                <form method="post" action="/delete?file=\(encode(file.name))"
                      onsubmit="return confirm('Delete \(escape(file.name))?')">
                  <button class="del">Delete</button>
                </form>
              </td>
            </tr>
            """
        }.joined()

        return """
        <!doctype html>
        <html><head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>AuraPlayer</title>
        <style>
          :root { color-scheme: dark; }
          body { margin:0; padding:40px 20px; background:#0A0C10; color:#F2F5F7;
                 font:16px -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif; }
          .wrap { max-width:720px; margin:0 auto; }
          h1 { font-size:28px; margin:0 0 4px; }
          .sub { color:#848C96; font-size:13px; margin-bottom:32px; }
          .drop { border:2px dashed #1A1E26; border-radius:16px; padding:40px 20px;
                  text-align:center; margin-bottom:32px; transition:.2s; }
          .drop.over { border-color:#1CE3CE; background:rgba(28,227,206,.06); }
          .drop p { margin:0 0 16px; color:#9AA3AD; }
          button { background:#1CE3CE; color:#0A0C10; border:0; border-radius:10px;
                   padding:10px 20px; font-size:15px; font-weight:600; cursor:pointer; }
          button:hover { background:#3DF0DD; }
          .del { background:transparent; color:#F87171; padding:4px 10px; font-weight:500; }
          .del:hover { background:rgba(248,113,113,.12); }
          table { width:100%; border-collapse:collapse; }
          td { padding:12px 8px; border-bottom:1px solid #1A1E26; }
          .size { color:#848C96; font-size:13px; white-space:nowrap; }
          form { display:inline; margin:0; }
          .total { color:#848C96; font-size:13px; margin-bottom:12px; }
          input[type=file] { display:none; }
          label.pick { display:inline-block; background:#1CE3CE; color:#0A0C10;
                       border-radius:10px; padding:10px 20px; font-weight:600; cursor:pointer; }
        </style>
        </head><body><div class="wrap">
          <h1>AuraPlayer</h1>
          <div class="sub">Wi-Fi transfer — keep the app open on your phone</div>

          <form id="up" class="drop" method="post" action="/upload" enctype="multipart/form-data">
            <p>Drop audio files here, or</p>
            <label class="pick">Choose files<input id="f" type="file" name="files" multiple></label>
          </form>

          <div class="total">\(files.count) file\(files.count == 1 ? "" : "s") · \(total)</div>
          <table>\(rows)</table>
        </div>
        <script>
          const form = document.getElementById('up');
          const input = document.getElementById('f');
          input.addEventListener('change', () => { if (input.files.length) form.submit(); });
          ['dragenter','dragover'].forEach(e =>
            form.addEventListener(e, ev => { ev.preventDefault(); form.classList.add('over'); }));
          ['dragleave','drop'].forEach(e =>
            form.addEventListener(e, ev => { ev.preventDefault(); form.classList.remove('over'); }));
          form.addEventListener('drop', ev => {
            input.files = ev.dataTransfer.files;
            if (input.files.length) form.submit();
          });
        </script>
        </body></html>
        """
    }

    private func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func encode(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? text
    }
}
