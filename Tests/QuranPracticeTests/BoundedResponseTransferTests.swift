#if canImport(Darwin)
import Foundation
import XCTest
import QuranCore
@testable import QuranPractice

/// Exercises URLSession.AsyncBytes on the same Foundation implementation used
/// by iPhone. FoundationNetworking lacks that API, so Linux tests separately
/// verify the common semantic response limit.
final class BoundedResponseTransferTests: XCTestCase {
    func testNativeResponseLimitStopsUnknownAndAdvertisedOversizedTransfers() async throws {
        for advertisesSize in [false, true] {
            let stopped = expectation(description: "Oversized transfer is cancelled")
            let probe = ResponseStreamProbe(advertisesSize: advertisesSize) { stopped.fulfill() }
            let host = UUID().uuidString.lowercased() + ".bounded.test"
            BoundedResponseURLProtocol.register(probe, host: host)
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [BoundedResponseURLProtocol.self]
            let session = URLSession(configuration: configuration)
            defer {
                session.invalidateAndCancel()
                BoundedResponseURLProtocol.unregister(host: host)
            }
            let client = try RecitationAssessmentClient(baseURL: URL(string: "https://" + host)!, session: session)
            let ayah = Ayah(id: 2, surahID: 1, numberInSurah: 2, text: "ٱلْحَمْدُ لِلَّهِ")
            let audio = Data(Array("RIFF".utf8) + [0, 0, 0, 0] + Array("WAVE".utf8))
            do {
                _ = try await client.assess(audioData: audio, format: .wav, ayah: ayah)
                XCTFail("Expected the receive limit to reject this response")
            } catch {
                XCTAssertEqual(error as? AssessmentError, .responseTooLarge)
            }
            await fulfillment(of: [stopped], timeout: 3)
            XCTAssertLessThan(probe.deliveredBytes, probe.totalBytes,
                              "The task must stop before receiving the complete oversized body")
        }
    }

    func testCancellingSwiftTaskStopsAMidstreamResponse() async throws {
        let firstChunk = expectation(description: "The response has started streaming")
        let stopped = expectation(description: "Cancelled response stops its URL loading task")
        let probe = ResponseStreamProbe(advertisesSize: false, onFirstChunk: { firstChunk.fulfill() }) {
            stopped.fulfill()
        }
        let host = UUID().uuidString.lowercased() + ".bounded.test"
        BoundedResponseURLProtocol.register(probe, host: host)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [BoundedResponseURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer {
            session.invalidateAndCancel()
            BoundedResponseURLProtocol.unregister(host: host)
        }
        let client = try RecitationAssessmentClient(baseURL: URL(string: "https://" + host)!, session: session)
        let ayah = Ayah(id: 2, surahID: 1, numberInSurah: 2, text: "ٱلْحَمْدُ لِلَّهِ")
        let audio = Data(Array("RIFF".utf8) + [0, 0, 0, 0] + Array("WAVE".utf8))
        let transfer = Task { try await client.assess(audioData: audio, format: .wav, ayah: ayah) }
        defer { transfer.cancel() }
        // The protocol signals actual delivery. No timing sleep is needed to
        // guess whether cancellation happened before or after the request began.
        await fulfillment(of: [firstChunk], timeout: 5)
        transfer.cancel()
        do {
            _ = try await transfer.value
            XCTFail("A cancelled response must not become an assessment")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        await fulfillment(of: [stopped], timeout: 3)
        XCTAssertGreaterThan(probe.deliveredBytes, 0)
        XCTAssertLessThan(probe.deliveredBytes, probe.totalBytes)
    }
}

private final class ResponseStreamProbe: @unchecked Sendable {
    let totalBytes = 16 * RecitationAssessmentClient.maximumResponseBytes
    let advertisesSize: Bool
    private let lock = NSLock()
    private var bytes = 0
    private var stopped = false
    private var notifiedFirstChunk = false
    private let onFirstChunk: () -> Void
    private let onStop: () -> Void

    init(advertisesSize: Bool, onFirstChunk: @escaping () -> Void = {}, onStop: @escaping () -> Void) {
        self.advertisesSize = advertisesSize
        self.onFirstChunk = onFirstChunk
        self.onStop = onStop
    }

    var deliveredBytes: Int {
        lock.lock()
        defer { lock.unlock() }
        return bytes
    }

    func recordChunk(_ count: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !stopped else { return false }
        bytes += count
        return true
    }

    func stop() {
        lock.lock()
        let notify = !stopped
        stopped = true
        lock.unlock()
        if notify { onStop() }
    }

    func chunkDelivered() {
        lock.lock()
        let notify = !notifiedFirstChunk && !stopped
        notifiedFirstChunk = true
        lock.unlock()
        if notify { onFirstChunk() }
    }
}

private final class BoundedResponseURLProtocol: URLProtocol, @unchecked Sendable {
    private static let probes = ProbeRegistry()
    private var activeProbe: ResponseStreamProbe?

    static func register(_ probe: ResponseStreamProbe, host: String) { probes.set(probe, host: host) }
    static func unregister(host: String) { probes.remove(host: host) }
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host?.hasSuffix(".bounded.test") == true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let probe = Self.probes.get(host: url.host) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        activeProbe = probe
        var headers = ["Content-Type": "application/json"]
        if probe.advertisesSize { headers["Content-Length"] = String(probe.totalBytes) }
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let chunk = Data(repeating: 32, count: 16 * 1024)
            for _ in 0..<(probe.totalBytes / chunk.count) {
                guard probe.recordChunk(chunk.count) else { return }
                self.client?.urlProtocol(self, didLoad: chunk)
                probe.chunkDelivered()
                Thread.sleep(forTimeInterval: 0.005)
            }
            self.client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() { activeProbe?.stop() }

    private final class ProbeRegistry: @unchecked Sendable {
        private let lock = NSLock()
        private var values: [String: ResponseStreamProbe] = [:]

        func set(_ probe: ResponseStreamProbe, host: String) {
            lock.lock()
            defer { lock.unlock() }
            values[host] = probe
        }
        func get(host: String?) -> ResponseStreamProbe? {
            lock.lock()
            defer { lock.unlock() }
            return host.flatMap { values[$0] }
        }
        func remove(host: String) {
            lock.lock()
            defer { lock.unlock() }
            values.removeValue(forKey: host)
        }
    }
}
#endif
