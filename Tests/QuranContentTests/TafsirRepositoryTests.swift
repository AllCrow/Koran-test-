import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
import QuranCore
import QuranData

final class TafsirRepositoryTests: XCTestCase {
    func testRequestsExactVerseAndKeepsArabicSourceText() async throws {
        let reference = try XCTUnwrap(AyahReference(surahID: 2, ayahNumber: 255))
        let log = RequestLog()
        let fixture = try makePayload(for: reference)
        let environment = StubEnvironment { request in
            log.append(request)
            return (200, fixture)
        }
        defer { environment.close() }
        let repository = TafsirRepository(session: environment.session)
        let entry = try await repository.tafsir(for: reference)
        XCTAssertEqual(entry.text, "تفسير عربي محفوظ كما ورد من المصدر.")
        XCTAssertEqual(entry.sourceName, "al-Muyassar")
        XCTAssertEqual(entry.language, "ar")
        let request = try XCTUnwrap(log.requests.first)
        XCTAssertEqual(request.url?.scheme, "https")
        XCTAssertEqual(request.url?.host, "api.alquran.cloud")
        XCTAssertEqual(request.url?.path, "/v1/ayah/2:255/ar.muyassar")
        XCTAssertNil(request.url?.query)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertFalse(request.httpShouldHandleCookies)
        let cached = try await repository.tafsir(for: reference)
        XCTAssertEqual(cached, entry)
        XCTAssertEqual(log.requests.count, 1)
    }

    func testWrongVerseAndWrongEditionAreNeverShown() async throws {
        let reference = try XCTUnwrap(AyahReference(surahID: 2, ayahNumber: 255))
        let changes: [(String, (inout [String: Any]) -> Void)] = [
            ("surah", { $0["surah"] = ["number": 1] }),
            ("verse", { $0["numberInSurah"] = 254 }),
            ("global identity", { $0["number"] = 255 }),
            ("edition", { $0["edition"] = edition(identifier: "ar.quran") }),
            ("language", { $0["edition"] = edition(language: "en") }),
            ("type", { $0["edition"] = edition(type: "translation") }),
            ("format", { $0["edition"] = edition(format: "audio") }),
            ("empty text", { $0["text"] = " \n\t" })
        ]
        for (label, change) in changes {
            let fixture = try makePayload(for: reference, change: change)
            let environment = StubEnvironment { _ in (200, fixture) }
            defer { environment.close() }
            let repository = TafsirRepository(session: environment.session)
            do {
                _ = try await repository.tafsir(for: reference)
                XCTFail("Accepted mismatching \(label)")
            } catch {
                XCTAssertEqual(error as? TafsirRepository.TafsirError, .unexpectedContent, label)
            }
        }
    }

    func testFailedValidationDoesNotPoisonCache() async throws {
        let reference = try XCTUnwrap(AyahReference(surahID: 2, ayahNumber: 255))
        let log = RequestLog()
        let incorrect = try makePayload(for: reference) { $0["numberInSurah"] = 1 }
        let correct = try makePayload(for: reference)
        let environment = StubEnvironment { request in
            let count = log.append(request)
            return (200, count == 1 ? incorrect : correct)
        }
        defer { environment.close() }
        let repository = TafsirRepository(session: environment.session)
        await assertError(.unexpectedContent) { _ = try await repository.tafsir(for: reference) }
        let entry = try await repository.tafsir(for: reference)
        XCTAssertEqual(entry.language, "ar")
        XCTAssertEqual(log.requests.count, 2)
    }

    func testHTTPFailureAndOfflineNetworkUseUnavailableError() async throws {
        let reference = try XCTUnwrap(AyahReference(surahID: 1, ayahNumber: 1))
        let handlers: [StubURLProtocol.Handler] = [
            { _ in (503, Data()) },
            { _ in throw URLError(.notConnectedToInternet) }
        ]
        for handler in handlers {
            let environment = StubEnvironment(handler: handler)
            defer { environment.close() }
            let repository = TafsirRepository(session: environment.session)
            await assertError(.unavailable) { _ = try await repository.tafsir(for: reference) }
        }
    }

    func testMalformedJSONIsRejected() async throws {
        let reference = try XCTUnwrap(AyahReference(surahID: 1, ayahNumber: 1))
        let environment = StubEnvironment { _ in (200, Data("<html>error</html>".utf8)) }
        defer { environment.close() }
        let repository = TafsirRepository(session: environment.session)
        await assertError(.unexpectedContent) { _ = try await repository.tafsir(for: reference) }
    }

    func testOversizedSourceIsRejectedWithoutPoisoningTheVerseCache() async throws {
        let reference = try XCTUnwrap(AyahReference(surahID: 1, ayahNumber: 1))
        let log = RequestLog()
        let valid = try makePayload(for: reference)
        let environment = StubEnvironment { request in
            let count = log.append(request)
            return (200, count == 1 ? Data(repeating: 32, count: TafsirRepository.maximumResponseBytes + 1) : valid)
        }
        defer { environment.close() }
        let repository = TafsirRepository(session: environment.session)
        await assertError(.unexpectedContent) { _ = try await repository.tafsir(for: reference) }
        let recovered = try await repository.tafsir(for: reference)
        XCTAssertEqual(recovered.language, "ar")
        XCTAssertEqual(log.requests.count, 2)
        _ = try await repository.tafsir(for: reference)
        XCTAssertEqual(log.requests.count, 2, "Only the valid response should have been cached")
    }

    func testURLSessionCancellationStaysCancellation() async throws {
        let reference = try XCTUnwrap(AyahReference(surahID: 1, ayahNumber: 1))
        let environment = StubEnvironment { _ in throw URLError(.cancelled) }
        defer { environment.close() }
        let repository = TafsirRepository(session: environment.session)
        do {
            _ = try await repository.tafsir(for: reference)
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // A dismissed sheet should not display a network failure.
        } catch {
            XCTFail("Cancellation changed to \(error)")
        }
    }

    func testAlreadyCancelledTaskDoesNotStartNetworkRequest() async throws {
        let reference = try XCTUnwrap(AyahReference(surahID: 1, ayahNumber: 1))
        let log = RequestLog()
        let fixture = try makePayload(for: reference)
        let environment = StubEnvironment { request in
            log.append(request)
            return (200, fixture)
        }
        defer { environment.close() }
        let repository = TafsirRepository(session: environment.session)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            _ = try await repository.tafsir(for: reference)
        }
        do {
            try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            XCTAssertTrue(log.requests.isEmpty)
        }
    }

    func testTafsirCacheIsBounded() async throws {
        let log = RequestLog()
        let environment = StubEnvironment { request in
            log.append(request)
            let part = try XCTUnwrap(request.url?.path.split(separator: "/").dropFirst(2).first)
            let ayah = try XCTUnwrap(Int(try XCTUnwrap(part.split(separator: ":").last)))
            let reference = try XCTUnwrap(AyahReference(surahID: 2, ayahNumber: ayah))
            return (200, try makePayload(for: reference))
        }
        defer { environment.close() }
        let repository = TafsirRepository(session: environment.session)
        for ayah in 1...65 {
            let reference = try XCTUnwrap(AyahReference(surahID: 2, ayahNumber: ayah))
            _ = try await repository.tafsir(for: reference)
        }
        XCTAssertEqual(log.requests.count, 65)
        _ = try await repository.tafsir(for: try XCTUnwrap(AyahReference(surahID: 2, ayahNumber: 1)))
        XCTAssertEqual(log.requests.count, 66, "The oldest response must have been evicted")
        _ = try await repository.tafsir(for: try XCTUnwrap(AyahReference(surahID: 2, ayahNumber: 64)))
        XCTAssertEqual(log.requests.count, 66, "A recent response should remain cached")
    }

    private func assertError(
        _ expected: TafsirRepository.TafsirError,
        file: StaticString = #filePath, line: UInt = #line,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? TafsirRepository.TafsirError, expected, file: file, line: line)
        }
    }
}

private func edition(identifier: String = "ar.muyassar", language: String = "ar", type: String = "tafsir", format: String = "text") -> [String: Any] {
    ["identifier": identifier, "language": language, "type": type, "format": format]
}

private func makePayload(for reference: AyahReference, change: ((inout [String: Any]) -> Void)? = nil) throws -> Data {
    var data: [String: Any] = [
        "number": AyahReference.ayahCounts.prefix(reference.surahID - 1).reduce(0, +) + reference.ayahNumber,
        "numberInSurah": reference.ayahNumber,
        "surah": ["number": reference.surahID],
        "text": "تفسير عربي محفوظ كما ورد من المصدر.",
        "edition": edition()
    ]
    change?(&data)
    return try JSONSerialization.data(withJSONObject: ["code": 200, "data": data])
}

private final class RequestLog: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URLRequest] = []

    var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    @discardableResult
    func append(_ request: URLRequest) -> Int {
        lock.lock()
        defer { lock.unlock() }
        storage.append(request)
        return storage.count
    }
}

private final class StubEnvironment {
    let session: URLSession
    private let token = UUID().uuidString

    init(handler: @escaping StubURLProtocol.Handler) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.httpAdditionalHeaders = ["X-Test-Session": token]
        session = URLSession(configuration: configuration)
        StubURLProtocol.register(token: token, handler: handler)
    }

    func close() {
        session.invalidateAndCancel()
        StubURLProtocol.unregister(token: token)
    }
}

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = (URLRequest) throws -> (Int, Data)
    private static let registry = HandlerRegistry()

    static func register(token: String, handler: @escaping Handler) { registry.set(token, handler: handler) }
    static func unregister(token: String) { registry.remove(token) }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let handler = try XCTUnwrap(Self.registry.get(request.value(forHTTPHeaderField: "X-Test-Session")))
            let (status, data) = try handler(request)
            let response = try XCTUnwrap(HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"]))
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private final class HandlerRegistry: @unchecked Sendable {
        private let lock = NSLock()
        private var handlers: [String: Handler] = [:]

        func set(_ token: String, handler: @escaping Handler) {
            lock.lock()
            defer { lock.unlock() }
            handlers[token] = handler
        }

        func get(_ token: String?) -> Handler? {
            lock.lock()
            defer { lock.unlock() }
            if let token { return handlers[token] }
            // FoundationNetworking invokes URLProtocol before applying session
            // configuration headers. Each test scopes one transport at a time;
            // refuse ambiguity instead of routing a request to another fixture.
            return handlers.count == 1 ? handlers.values.first : nil
        }

        func remove(_ token: String) {
            lock.lock()
            defer { lock.unlock() }
            handlers.removeValue(forKey: token)
        }
    }
}
