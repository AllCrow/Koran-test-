import AVFoundation
import Combine
import Foundation
import Network
import QuranCore
import XCTest
@testable import Sakina

/// Real URLSession downloads over loopback HTTP, followed by normal admission.
/// The adapter restores the requested HTTPS response URL. These probes do not
/// establish production TLS, EveryAyah availability, reciter content or energy.
@MainActor
final class AudioDownloadTransportTests: XCTestCase {
    func testRealDownloadsDecodeAndReopenOfflineForEveryReciter() async throws {
        let audio = try XCTUnwrap(GeneratedMP3Fixture.data)
        let server = try await startServer { _, _ in .complete(audio) }
        let transport = HTTPDownloadTransport(server: server)
        defer { transport.stop() }
        let root = try storage()
        let library = AudioLibrary(directory: root, download: transport.download)
        defer { library.cancelDownload() }

        for reciter in Reciter.allCases {
            library.beginDownload(chapter, reciter: reciter)
            await finish(library)
            XCTAssertNil(library.errorMessage)
            XCTAssertEqual(library.completed, 3)
            XCTAssertEqual(library.downloadedVerseCount(surahID: 108, reciter: reciter), 3)
            for number in 1...3 {
                let reference = try verse(number)
                let url = try XCTUnwrap(library.localURL(for: reference, reciter: reciter))
                XCTAssertEqual(try Data(contentsOf: url), audio)
                let decoded = try AVAudioFile(forReading: url)
                let pcm = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: decoded.processingFormat, frameCapacity: 1_024))
                try decoded.read(into: pcm)
                XCTAssertGreaterThan(pcm.frameLength, 0)
            }
        }

        let expected = try Reciter.allCases.flatMap { reciter in
            try (1...3).map { reciter.audioURL(for: try verse($0)) }
        }
        XCTAssertEqual(transport.requests.compactMap(\.url), expected)
        XCTAssertEqual(server.requests.map(\.path), expected.map(\.path))
        XCTAssertTrue(server.requests.allSatisfy { $0.method == "GET" && $0.headers["cookie"] == nil })
        XCTAssertTrue(server.requests.allSatisfy { $0.headers["accept"]?.contains("audio/mpeg") == true })
        XCTAssertTrue(transport.requests.allSatisfy { $0.url?.scheme == "https" && !$0.httpShouldHandleCookies })
        XCTAssertTrue(transport.temporaryFiles.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })

        server.stop()
        transport.stop()
        let reopened = AudioLibrary(directory: root, download: { _, _ in
            XCTFail("Reopening saved audio must not request a network transfer")
            throw URLError(.notConnectedToInternet)
        })
        for reciter in Reciter.allCases {
            XCTAssertEqual(reopened.downloadedVerseCount(surahID: 108, reciter: reciter), 3)
            XCTAssertNotNil(reopened.localURL(for: try verse(3), reciter: reciter))
        }
    }

    func testHTTPFailureKeepsFinishedVersesAndResumeFetchesOnlyMissingOnes() async throws {
        let audio = try XCTUnwrap(GeneratedMP3Fixture.data)
        let server = try await startServer { _, call in
            call == 2 ? .complete(Data("unavailable".utf8), status: 503, mime: "text/plain") : .complete(audio)
        }
        let transport = HTTPDownloadTransport(server: server)
        defer { transport.stop() }
        let library = AudioLibrary(directory: try storage(), download: transport.download)
        defer { library.cancelDownload() }

        library.beginDownload(chapter, reciter: .husary)
        await finish(library)
        XCTAssertEqual(library.completed, 1)
        XCTAssertNotNil(library.errorMessage)
        XCTAssertNotNil(library.localURL(for: try verse(1), reciter: .husary))
        XCTAssertNil(library.localURL(for: try verse(2), reciter: .husary))

        library.beginDownload(chapter, reciter: .husary)
        await finish(library)
        XCTAssertNil(library.errorMessage)
        XCTAssertEqual(library.completed, 3)
        let expected = try [1, 2, 2, 3].map { Reciter.husary.audioURL(for: try verse($0)).path }
        XCTAssertEqual(server.requests.map(\.path), expected)
        XCTAssertTrue(transport.temporaryFiles.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
    }

    func testCancellingAnOpenHTTPBodyPreservesCompletedVersesAndCanResume() async throws {
        let audio = try XCTUnwrap(GeneratedMP3Fixture.data)
        let held = expectation(description: "The second HTTP body is open and incomplete")
        let server = try await startServer { _, call in
            call == 2 ? .held(audio, onHeld: { held.fulfill() }) : .complete(audio)
        }
        let transport = HTTPDownloadTransport(server: server)
        defer { transport.stop() }
        let library = AudioLibrary(directory: try storage(), download: transport.download)
        defer { library.cancelDownload(); server.releaseHeldBodies() }

        library.beginDownload(chapter, reciter: .minshawi)
        await fulfillment(of: [held], timeout: 5)
        XCTAssertEqual(library.completed, 1)
        library.cancelDownload()
        await finish(library)
        XCTAssertNil(library.errorMessage)
        XCTAssertEqual(library.completed, 1)
        XCTAssertNil(library.localURL(for: try verse(2), reciter: .minshawi))
        server.releaseHeldBodies()

        library.beginDownload(chapter, reciter: .minshawi)
        await finish(library)
        XCTAssertEqual(library.completed, 3)
        XCTAssertNil(library.errorMessage)
        let expected = try [1, 2, 2, 3].map { Reciter.minshawi.audioURL(for: try verse($0)).path }
        XCTAssertEqual(server.requests.map(\.path), expected)
        XCTAssertTrue(transport.temporaryFiles.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
    }

    func testAdvertisedOversizeCancelsBeforeTheServerCompletesItsBody() async throws {
        let server = try await startServer { _, _ in .advertisedOversize }
        let transport = HTTPDownloadTransport(server: server)
        defer { transport.stop() }
        let library = AudioLibrary(directory: try storage(), download: transport.download)
        defer { library.cancelDownload() }

        library.beginDownload(chapter, reciter: .alafasy)
        await finish(library)
        XCTAssertEqual(server.requests.count, 1)
        XCTAssertEqual(library.completed, 0)
        XCTAssertEqual(library.downloadedVerseCount(surahID: 108, reciter: .alafasy), 0)
        XCTAssertTrue(try XCTUnwrap(library.errorMessage).contains("stor"))
        XCTAssertTrue(transport.temporaryFiles.isEmpty, "The unfinished transfer must be cancelled by the delegate")
    }

    func testUnknownLengthOversizeCancelsWhileChunkedResponseIsStillOpen() async throws {
        let server = try await startServer { _, _ in .chunkedOversize }
        let transport = HTTPDownloadTransport(server: server)
        defer { transport.stop() }
        let library = AudioLibrary(directory: try storage(), download: transport.download)
        defer { library.cancelDownload() }

        library.beginDownload(chapter, reciter: .alafasy)
        await finish(library)
        XCTAssertEqual(server.requests.count, 1)
        XCTAssertEqual(library.completed, 0)
        XCTAssertEqual(library.downloadedVerseCount(surahID: 108, reciter: .alafasy), 0)
        XCTAssertTrue(try XCTUnwrap(library.errorMessage).contains("stor"))
        XCTAssertTrue(transport.temporaryFiles.isEmpty, "No terminating HTTP chunk was sent; delegate cancellation must finish the job")
    }

    private var chapter: Surah {
        Surah(id: 108, name: "test", englishName: "test", englishNameTranslation: "test",
              numberOfAyahs: 3, revelationType: "test")
    }

    private func verse(_ number: Int) throws -> AyahReference {
        try XCTUnwrap(AyahReference(surahID: 108, ayahNumber: number))
    }

    private func storage() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("sakina.http-tests.\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }

    private func startServer(handler: @escaping LoopbackAudioHTTPServer.Handler) async throws -> LoopbackAudioHTTPServer {
        let ready = expectation(description: "An HTTP fixture binds only to loopback")
        let server = try LoopbackAudioHTTPServer(ready: ready, handler: handler)
        addTeardownBlock { server.stop() }
        server.start()
        await fulfillment(of: [ready], timeout: 5)
        _ = try XCTUnwrap(server.port)
        return server
    }

    private func finish(_ library: AudioLibrary) async {
        guard library.downloadingSurahID != nil else { return }
        let done = expectation(description: "Real URLSession transfer completes or cancels")
        let subscription = library.$downloadingSurahID.dropFirst().first(where: { $0 == nil })
            .sink { _ in done.fulfill() }
        defer { subscription.cancel() }
        await fulfillment(of: [done], timeout: 10)
        XCTAssertNil(library.downloadingSurahID)
        XCTAssertNil(library.downloadingReciter)
    }
}

/// Routes only this test's requests through a real loopback URLSession task.
/// Status/headers/body come from HTTP; HTTPS origin metadata is restored for
/// AudioLibrary's existing admission checks. Production TLS is outside scope.
@MainActor
private final class HTTPDownloadTransport {
    private let server: LoopbackAudioHTTPServer
    private let session: URLSession
    private(set) var requests: [URLRequest] = []
    private(set) var temporaryFiles: [URL] = []

    init(server: LoopbackAudioHTTPServer) {
        self.server = server
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 10
        configuration.httpMaximumConnectionsPerHost = 1
        session = URLSession(configuration: configuration)
    }

    var download: AudioLibrary.Download {
        { [self] original, delegate in
            requests.append(original)
            let origin = try XCTUnwrap(original.url)
            let port = try XCTUnwrap(server.port)
            var components = URLComponents()
            components.scheme = "http"
            components.host = "127.0.0.1"
            components.port = Int(port)
            components.path = origin.path
            var routed = original
            routed.url = try XCTUnwrap(components.url)
            let (temporary, response) = try await session.download(for: routed, delegate: delegate)
            temporaryFiles.append(temporary)
            let http = try XCTUnwrap(response as? HTTPURLResponse)
            let fields = Dictionary(uniqueKeysWithValues: http.allHeaderFields.map {
                (String(describing: $0.key), String(describing: $0.value))
            })
            let restored = try XCTUnwrap(HTTPURLResponse(url: origin, statusCode: http.statusCode,
                                                       httpVersion: "HTTP/1.1", headerFields: fields))
            return (temporary, restored)
        }
    }

    func stop() { session.invalidateAndCancel() }
    deinit { session.invalidateAndCancel() }
}

/// A tiny queue-confined HTTP/1.1 server. No TLS keys, external interface,
/// persistent process or fixture recordings are used. Bodies can deliberately
/// remain incomplete so a successful cancellation cannot be confused with EOF.
private final class LoopbackAudioHTTPServer: @unchecked Sendable {
    struct Request: Sendable {
        let method: String
        let path: String
        let headers: [String: String]
    }

    enum Reply: Sendable {
        case complete(Data, status: Int = 200, mime: String = "audio/mpeg")
        case held(Data, onHeld: @Sendable () -> Void)
        case advertisedOversize
        case chunkedOversize
    }

    typealias Handler = @Sendable (Request, Int) -> Reply
    private let listener: NWListener
    private let queue = DispatchQueue(label: "sakina.loopback-audio-fixture")
    private let lock = NSLock()
    private let ready: XCTestExpectation
    private let handler: Handler
    private var boundPort: UInt16?
    private var received: [Request] = []
    // The following collections are touched only on queue.
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private var heldBodies: [(NWConnection, Data)] = []
    private var reportedReady = false

    var port: UInt16? { locked { boundPort } }
    var requests: [Request] { locked { received } }

    init(ready: XCTestExpectation, handler: @escaping Handler) throws {
        self.ready = ready
        self.handler = handler
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: parameters)
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.locked { self.boundPort = self.listener.port?.rawValue }
                self.reportReady()
            case .failed:
                self.reportReady()
            default: break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
    }

    func start() { listener.start(queue: queue) }

    func stop() {
        queue.async { [self] in
            listener.cancel()
            for connection in connections.values { connection.cancel() }
            connections.removeAll()
            heldBodies.removeAll()
        }
    }

    func releaseHeldBodies() {
        queue.async { [self] in
            let pending = heldBodies
            heldBodies.removeAll()
            for (connection, remaining) in pending {
                connection.send(content: remaining, contentContext: .finalMessage, isComplete: true,
                                completion: .contentProcessed { _ in connection.cancel() })
            }
        }
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    private func reportReady() {
        guard !reportedReady else { return }
        reportedReady = true
        ready.fulfill()
    }

    private func accept(_ connection: NWConnection) {
        connections[ObjectIdentifier(connection)] = connection
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }
            switch state {
            case .failed, .cancelled:
                self.connections.removeValue(forKey: ObjectIdentifier(connection))
                self.heldBodies.removeAll { $0.0 === connection }
            default: break
            }
        }
        connection.start(queue: queue)
        receiveHeaders(connection, buffered: Data())
    }

    private func receiveHeaders(_ connection: NWConnection, buffered: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, complete, error in
            guard let self else { return }
            var accumulated = buffered
            if let data { accumulated.append(data) }
            if let end = accumulated.range(of: Data("\r\n\r\n".utf8)),
               let text = String(data: accumulated[..<end.lowerBound], encoding: .utf8),
               let request = self.parse(text) {
                let call = self.locked { self.received.append(request); return self.received.count }
                self.respond(self.handler(request, call), to: connection)
            } else if error == nil, !complete, accumulated.count < 16_384 {
                self.receiveHeaders(connection, buffered: accumulated)
            } else {
                connection.cancel()
            }
        }
    }

    private func parse(_ text: String) -> Request? {
        let lines = text.components(separatedBy: "\r\n")
        guard let first = lines.first else { return nil }
        let words = first.split(separator: " ")
        guard words.count == 3, words[0] == "GET" else { return nil }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            headers[String(line[..<colon]).lowercased()] = line[line.index(after: colon)...]
                .trimmingCharacters(in: .whitespaces)
        }
        return Request(method: String(words[0]), path: String(words[1]), headers: headers)
    }

    private func header(status: Int = 200, mime: String = "audio/mpeg", length: Int? = nil) -> Data {
        let framing = length.map { "Content-Length: \($0)\r\n" } ?? "Transfer-Encoding: chunked\r\n"
        return Data("HTTP/1.1 \(status) Fixture\r\nContent-Type: \(mime)\r\n\(framing)Connection: close\r\n\r\n".utf8)
    }

    private func respond(_ reply: Reply, to connection: NWConnection) {
        switch reply {
        case let .complete(body, status, mime):
            connection.send(content: header(status: status, mime: mime, length: body.count) + body,
                            contentContext: .finalMessage, isComplete: true,
                            completion: .contentProcessed { _ in connection.cancel() })
        case let .held(body, onHeld):
            let count = min(128, body.count)
            heldBodies.append((connection, Data(body.dropFirst(count))))
            connection.send(content: header(length: body.count) + body.prefix(count), completion: .contentProcessed { _ in onHeld() })
        case .advertisedOversize:
            // Leave almost the entire advertised body unsent. The download
            // delegate, rather than EOF or file admission, must end the job.
            connection.send(content: header(length: 64 * 1_024 * 1_024) + Data(repeating: 0x41, count: 65_536),
                            completion: .contentProcessed { _ in })
        case .chunkedOversize:
            connection.send(content: header(), completion: .contentProcessed { [weak self] error in
                guard error == nil else { return }
                self?.sendChunks(connection, remaining: 32 * 1_024 * 1_024 + 65_536)
            })
        }
    }

    private func sendChunks(_ connection: NWConnection, remaining: Int) {
        guard remaining > 0 else { return } // No terminating zero chunk.
        let count = min(65_536, remaining)
        var chunk = Data("\(String(count, radix: 16))\r\n".utf8)
        chunk.append(Data(repeating: 0x41, count: count))
        chunk.append(Data("\r\n".utf8))
        connection.send(content: chunk, completion: .contentProcessed { [weak self] error in
            guard error == nil else { return }
            self?.sendChunks(connection, remaining: remaining - count)
        })
    }
}
