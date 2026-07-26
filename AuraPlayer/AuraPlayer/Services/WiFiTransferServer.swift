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
            let listener = try NWListener(using: parameters, on: port)

            listener.newConnectionHandler = { [weak self] (connection: NWConnection) in
                connection.start(queue: .global(qos: .userInitiated))
                Task { @MainActor [weak self] in
                    self?.receive(on: connection, buffer: Data())
                }
            }

            listener.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    let url = Self.localAddress().map { "http://\($0):8080" }
                    Task { @MainActor [weak self] in
                        self?.isRunning = true
                        self?.address = url
                    }
                case .failed(let error):
                    let description = error.localizedDescription
                    Task { @MainActor [weak self] in
                        self?.lastError = description
                        self?.stop()
                    }
                default:
                    break
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

            // Build the accumulated data as an immutable value before hopping
            // actors — a captured `var` isn't Sendable in Swift 6.
            let data = chunk.map { buffer + $0 } ?? buffer
            let finished = isComplete

            Task { @MainActor [weak self] in
                guard let self else { connection.cancel(); return }
                self.handle(data: data, isComplete: finished, on: connection)
            }
        }
    }

    /// Parse what we have; wait for more if the request is incomplete.
    private func handle(data: Data, isComplete: Bool, on connection: NWConnection) {
        guard let (head, headerLength) = HTTPRequest.parseHead(data) else {
            if isComplete { connection.cancel() } else { receive(on: connection, buffer: data) }
            return
        }

        let expected = headerLength + head.contentLength
        guard data.count >= expected else {
            if isComplete { connection.cancel() } else { receive(on: connection, buffer: data) }
            return
        }

        var request = head
        request.body = data.subdata(in: headerLength..<expected)
        respond(to: request, on: connection)
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
    /// Pure C API with no shared state, so it's safe off the main actor.
    nonisolated private static func localAddress() -> String? {
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
            <li class="row">
              <span class="ico">\(Self.icon(for: file.name))</span>
              <span class="name" title="\(escape(file.name))">\(escape(file.name))</span>
              <span class="size">\(StorageManager.formatted(file.size))</span>
              <button class="del" data-file="\(escape(file.name))" title="Delete">
                <svg viewBox="0 0 24 24" width="17" height="17" fill="none"
                     stroke="currentColor" stroke-width="1.8" stroke-linecap="round">
                  <path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3"/>
                </svg>
              </button>
            </li>
            """
        }.joined()

        let emptyState = files.isEmpty ? """
            <li class="empty">Nothing here yet — drop some music above.</li>
            """ : ""

        return """
        <!doctype html>
        <html lang="en"><head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>AuraPlayer</title>
        <style>
          :root {
            --bg:#0A0C10; --surface:#12151B; --raised:#1A1E26;
            --text:#F2F5F7; --dim:#9AA3AD; --faint:#848C96;
            --accent:#1CE3CE; --glow:#3DF0DD; --danger:#F87171;
            color-scheme: dark;
          }
          * { box-sizing:border-box; }
          body {
            margin:0; padding:56px 24px 80px; background:var(--bg); color:var(--text);
            font:15px/1.5 -apple-system,BlinkMacSystemFont,'Inter','Segoe UI',sans-serif;
            -webkit-font-smoothing:antialiased;
            background-image:radial-gradient(ellipse 70% 50% at 50% -10%, rgba(28,227,206,.07), transparent 70%);
          }
          .wrap { max-width:680px; margin:0 auto; }

          header { display:flex; align-items:center; gap:14px; margin-bottom:6px; }
          .bars { display:flex; align-items:center; gap:3px; height:30px;
                  filter:drop-shadow(0 0 8px rgba(28,227,206,.55)); }
          .bars i { width:4px; border-radius:2px; background:var(--accent); display:block; }
          .bars i:nth-child(1){height:9px}  .bars i:nth-child(2){height:16px}
          .bars i:nth-child(3){height:26px} .bars i:nth-child(4){height:30px;background:var(--text)}
          .bars i:nth-child(5){height:26px} .bars i:nth-child(6){height:16px}
          .bars i:nth-child(7){height:9px}
          h1 { font-size:21px; font-weight:600; letter-spacing:-.02em; margin:0; }
          .sub { color:var(--faint); font-size:13px; margin:0 0 36px 44px; }

          .drop {
            position:relative; border:1.5px dashed #232833; border-radius:18px;
            padding:44px 24px; text-align:center; background:var(--surface);
            transition:border-color .18s, background .18s, transform .18s; cursor:pointer;
          }
          .drop:hover { border-color:#2f3644; }
          .drop.over {
            border-color:var(--accent); background:rgba(28,227,206,.06);
            transform:scale(1.008);
            box-shadow:0 0 0 4px rgba(28,227,206,.08), 0 0 40px rgba(28,227,206,.12);
          }
          .drop svg { color:var(--accent); margin-bottom:14px;
                      filter:drop-shadow(0 0 10px rgba(28,227,206,.4)); }
          .drop .big { font-size:16px; font-weight:500; }
          .drop .small { color:var(--faint); font-size:13px; margin-top:6px; }
          input[type=file] { display:none; }

          .bar { height:3px; border-radius:2px; background:var(--raised);
                 margin-top:22px; overflow:hidden; display:none; }
          .bar.on { display:block; }
          .bar span { display:block; height:100%; width:0;
                      background:linear-gradient(90deg,var(--accent),var(--glow));
                      box-shadow:0 0 12px rgba(28,227,206,.6); transition:width .15s; }

          .meta { display:flex; justify-content:space-between; align-items:baseline;
                  margin:40px 0 10px; }
          .meta h2 { font-size:12px; font-weight:600; letter-spacing:.09em;
                     text-transform:uppercase; color:var(--faint); margin:0; }
          .meta .tot { color:var(--faint); font-size:13px; font-variant-numeric:tabular-nums; }

          ul { list-style:none; margin:0; padding:0;
               background:var(--surface); border-radius:16px; overflow:hidden; }
          .row { display:flex; align-items:center; gap:14px; padding:13px 16px;
                 border-bottom:1px solid rgba(255,255,255,.04); transition:background .15s; }
          .row:last-child { border-bottom:0; }
          .row:hover { background:rgba(255,255,255,.025); }
          .ico { width:30px; height:30px; flex:none; border-radius:8px; background:var(--raised);
                 display:grid; place-items:center; color:var(--accent); font-size:11px;
                 font-weight:600; letter-spacing:.02em; }
          .name { flex:1; min-width:0; overflow:hidden; text-overflow:ellipsis;
                  white-space:nowrap; }
          .size { color:var(--faint); font-size:13px; font-variant-numeric:tabular-nums;
                  flex:none; }
          .del { flex:none; background:none; border:0; color:#4b5563; cursor:pointer;
                 padding:6px; border-radius:8px; display:grid; place-items:center;
                 transition:.15s; }
          .row:hover .del { color:var(--dim); }
          .del:hover { color:var(--danger); background:rgba(248,113,113,.1); }
          .empty { padding:40px 16px; text-align:center; color:var(--faint); font-size:14px; }

          .toast { position:fixed; left:50%; bottom:32px; transform:translate(-50%,80px);
                   background:var(--raised); color:var(--text); padding:11px 20px;
                   border-radius:12px; font-size:14px; opacity:0; transition:.28s;
                   box-shadow:0 12px 32px rgba(0,0,0,.5); }
          .toast.show { transform:translate(-50%,0); opacity:1; }
        </style>
        </head><body>
        <div class="wrap">
          <header>
            <div class="bars"><i></i><i></i><i></i><i></i><i></i><i></i><i></i></div>
            <h1>AuraPlayer</h1>
          </header>
          <p class="sub">Wi-Fi transfer · keep the app open on your phone</p>

          <label class="drop" id="drop">
            <svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                 stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
              <path d="M12 16V4m0 0L7.5 8.5M12 4l4.5 4.5"/>
              <path d="M4 15v3a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-3"/>
            </svg>
            <div class="big">Drop audio files here</div>
            <div class="small">or click to choose · MP3, FLAC, M4A, WAV, AIFF</div>
            <input id="file" type="file" name="files" multiple accept="audio/*,.flac,.m4a,.aiff,.dsf,.dff">
            <div class="bar" id="bar"><span id="fill"></span></div>
          </label>

          <div class="meta">
            <h2>\(files.count) file\(files.count == 1 ? "" : "s")</h2>
            <div class="tot">\(total)</div>
          </div>
          <ul id="list">\(rows)\(emptyState)</ul>
        </div>
        <div class="toast" id="toast"></div>

        <script>
          const drop = document.getElementById('drop');
          const input = document.getElementById('file');
          const bar = document.getElementById('bar');
          const fill = document.getElementById('fill');
          const toast = document.getElementById('toast');

          function say(text) {
            toast.textContent = text;
            toast.classList.add('show');
            setTimeout(() => toast.classList.remove('show'), 2200);
          }

          function upload(files) {
            if (!files.length) return;
            const data = new FormData();
            for (const f of files) data.append('files', f);

            const xhr = new XMLHttpRequest();
            xhr.open('POST', '/upload');
            bar.classList.add('on');
            xhr.upload.onprogress = e => {
              if (e.lengthComputable) fill.style.width = (e.loaded / e.total * 100) + '%';
            };
            xhr.onload = () => {
              say(files.length + (files.length === 1 ? ' file added' : ' files added'));
              setTimeout(() => location.reload(), 500);
            };
            xhr.onerror = () => { bar.classList.remove('on'); say('Upload failed'); };
            xhr.send(data);
          }

          input.addEventListener('change', () => upload(input.files));

          ['dragenter','dragover'].forEach(e => drop.addEventListener(e, ev => {
            ev.preventDefault(); drop.classList.add('over');
          }));
          ['dragleave','drop'].forEach(e => drop.addEventListener(e, ev => {
            ev.preventDefault(); drop.classList.remove('over');
          }));
          drop.addEventListener('drop', ev => upload(ev.dataTransfer.files));

          document.getElementById('list').addEventListener('click', ev => {
            const button = ev.target.closest('.del');
            if (!button) return;
            const name = button.dataset.file;
            if (!confirm('Delete ' + name + '?')) return;
            fetch('/delete?file=' + encodeURIComponent(name), { method: 'POST' })
              .then(() => { say('Deleted'); setTimeout(() => location.reload(), 400); });
          });
        </script>
        </body></html>
        """
    }

    /// Short badge showing the file type, e.g. FLAC.
    private static func icon(for filename: String) -> String {
        (filename as NSString).pathExtension.uppercased()
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
