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

    func testNonJSONResponseTypesAreRejectedEvenWhenBodyLooksValid() async throws {
        let reference = try XCTUnwrap(AyahReference(surahID: 1, ayahNumber: 1))
        let fixture = try makePayload(for: reference)
        for contentType in [nil, "text/html", "audio/mpeg", "text/plain"] as [String?] {
            let log = RequestLog()
            let environment = StubEnvironment(contentType: contentType) { request in
                log.append(request)
                return (200, fixture)
            }
            defer { environment.close() }
            let repository = TafsirRepository(session: environment.session)
            await assertError(.unexpectedContent) { _ = try await repository.tafsir(for: reference) }
            await assertError(.unexpectedContent) { _ = try await repository.tafsir(for: reference) }
            XCTAssertEqual(log.requests.count, 2, "An invalid content type must not populate the cache")
        }
    }

    func testStructuredJSONContentTypeKeepsSourceUnchanged() async throws {
        let reference = try XCTUnwrap(AyahReference(surahID: 1, ayahNumber: 1))
        let fixture = try makePayload(for: reference)
        let environment = StubEnvironment(contentType: "application/vnd.tafsir+json; charset=utf-8") { _ in (200, fixture) }
        defer { environment.close() }
        let entry = try await TafsirRepository(session: environment.session).tafsir(for: reference)
        XCTAssertEqual(entry.text, "تفسير عربي محفوظ كما ورد من المصدر.")
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

    func testReadingAnOlderMemoryEntryRefreshesItsEvictionPriority() async throws {
        let log = RequestLog()
        let environment = StubEnvironment { request in
            log.append(request)
            return (200, try makePayload(for: reference(in: request)))
        }
        defer { environment.close() }
        let repository = TafsirRepository(session: environment.session)
        for ayah in 1...TafsirRepository.maximumCachedEntries {
            _ = try await repository.tafsir(for: try XCTUnwrap(AyahReference(surahID: 2, ayahNumber: ayah)))
        }
        let first = try XCTUnwrap(AyahReference(surahID: 2, ayahNumber: 1))
        _ = try await repository.tafsir(for: first)
        _ = try await repository.tafsir(for: try XCTUnwrap(AyahReference(surahID: 2, ayahNumber: 65)))
        _ = try await repository.tafsir(for: first)
        XCTAssertEqual(log.requests.count, 65)
        _ = try await repository.tafsir(for: try XCTUnwrap(AyahReference(surahID: 2, ayahNumber: 2)))
        XCTAssertEqual(log.requests.count, 66, "The least recently used entry, not the oldest original insertion, is evicted")
    }

    func testSavedExplanationSurvivesNewRepositoryAndWorksWithoutNetwork() async throws {
        let directory = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let reference = try XCTUnwrap(AyahReference(surahID: 2, ayahNumber: 255))
        // Include combining marks and whitespace deliberately; caching must not
        // normalize, trim or rewrite the source's Arabic UTF-8 spelling.
        let text = "  ا\u{0653}يةٌ محفوظةٌ\nتفسيرٌ عربيٌّ.  "
        let fixture = try makePayload(for: reference) { $0["text"] = text }
        let online = StubEnvironment { _ in (200, fixture) }
        defer { online.close() }
        let fetched = try await TafsirRepository(session: online.session, cacheDirectory: directory).tafsir(for: reference)
        let file = cacheURL(reference, in: directory)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        XCTAssertLessThanOrEqual(try Data(contentsOf: file).count, TafsirRepository.maximumCachedEntryBytes)
        online.close()

        let log = RequestLog()
        let offline = StubEnvironment { request in
            log.append(request)
            throw URLError(.notConnectedToInternet)
        }
        defer { offline.close() }
        let restored = try await TafsirRepository(session: offline.session, cacheDirectory: directory).tafsir(for: reference)
        XCTAssertEqual(restored, fetched)
        XCTAssertEqual(Array(restored.text.utf8), Array(text.utf8))
        XCTAssertTrue(log.requests.isEmpty, "A validated disk hit must not require an internet connection")
    }

    func testInvalidPersistentEntriesAreReplacedOnlyByValidatedResponse() async throws {
        let reference = try XCTUnwrap(AyahReference(surahID: 1, ayahNumber: 1))
        let correct = try makePayload(for: reference)
        let wrongVerse = try makePayload(for: try XCTUnwrap(AyahReference(surahID: 1, ayahNumber: 2)))
        let wrongEdition = try makePayload(for: reference) { $0["edition"] = edition(identifier: "ar.other") }
        let empty = try makePayload(for: reference) { $0["text"] = " \n\t" }
        let invalidFiles = [
            Data("not a cache".utf8),
            try makeCachedPayload(correct, version: 2),
            try makeCachedPayload(correct, source: "https://other.example/ar.muyassar"),
            try makeCachedPayload(wrongVerse),
            try makeCachedPayload(wrongEdition),
            try makeCachedPayload(empty),
            Data(repeating: 32, count: TafsirRepository.maximumCachedEntryBytes + 1)
        ]
        for invalid in invalidFiles {
            let directory = temporaryCacheDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try invalid.write(to: cacheURL(reference, in: directory))
            let log = RequestLog()
            let online = StubEnvironment { request in
                log.append(request)
                return (200, correct)
            }
            defer { online.close() }
            let entry = try await TafsirRepository(session: online.session, cacheDirectory: directory).tafsir(for: reference)
            XCTAssertEqual(log.requests.count, 1)
            XCTAssertEqual(entry.text, "تفسير عربي محفوظ كما ورد من المصدر.")
            online.close()

            let offline = StubEnvironment { _ in throw URLError(.notConnectedToInternet) }
            defer { offline.close() }
            let recovered = try await TafsirRepository(session: offline.session, cacheDirectory: directory).tafsir(for: reference)
            XCTAssertEqual(recovered, entry)
        }
    }

    func testWrongOnlineVerseIsNeverPersisted() async throws {
        let directory = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let reference = try XCTUnwrap(AyahReference(surahID: 1, ayahNumber: 1))
        let wrong = try makePayload(for: reference) { $0["numberInSurah"] = 2 }
        let environment = StubEnvironment { _ in (200, wrong) }
        defer { environment.close() }
        let repository = TafsirRepository(session: environment.session, cacheDirectory: directory)
        await assertError(.unexpectedContent) { _ = try await repository.tafsir(for: reference) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheURL(reference, in: directory).path))
    }

    func testUnavailableCacheDoesNotBreakReadingAndCanRecover() async throws {
        let directory = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        // A file where a directory is expected simulates a cache setup failure
        // deterministically, including when the tests run as root.
        let sentinel = Data("preserve this file".utf8)
        try sentinel.write(to: URL(fileURLWithPath: directory.path))
        let environment = StubEnvironment { request in (200, try makePayload(for: reference(in: request))) }
        defer { environment.close() }
        let repository = TafsirRepository(session: environment.session, cacheDirectory: directory)
        let first = try XCTUnwrap(AyahReference(surahID: 1, ayahNumber: 1))
        let second = try XCTUnwrap(AyahReference(surahID: 1, ayahNumber: 2))
        _ = try await repository.tafsir(for: first)
        XCTAssertEqual(try Data(contentsOf: directory), sentinel)
        try FileManager.default.removeItem(at: directory)
        _ = try await repository.tafsir(for: second)
        XCTAssertTrue(FileManager.default.fileExists(atPath: cacheURL(second, in: directory).path))
    }

    func testLargeValidOnlineTextRemainsReadableWithoutOversizedDiskEntry() async throws {
        let directory = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let reference = try XCTUnwrap(AyahReference(surahID: 1, ayahNumber: 1))
        let text = String(repeating: "ت", count: 70_000)
        let fixture = try makePayload(for: reference) { $0["text"] = text }
        XCTAssertLessThan(fixture.count, TafsirRepository.maximumResponseBytes)
        let log = RequestLog()
        let environment = StubEnvironment { request in
            log.append(request)
            return (200, fixture)
        }
        defer { environment.close() }
        let repository = TafsirRepository(session: environment.session, cacheDirectory: directory)
        let entry = try await repository.tafsir(for: reference)
        XCTAssertEqual(entry.text, text)
        _ = try await repository.tafsir(for: reference)
        XCTAssertEqual(log.requests.count, 1, "A large valid entry can still be reused in the bounded memory cache")
        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheURL(reference, in: directory).path))
    }

    func testPersistentCacheCountEvictsLeastRecentlyOpenedExplanation() async throws {
        let directory = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for ayah in 1...64 {
            let reference = try XCTUnwrap(AyahReference(surahID: 2, ayahNumber: ayah))
            let file = cacheURL(reference, in: directory)
            try makeCachedPayload(makePayload(for: reference)).write(to: file)
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: TimeInterval(ayah))], ofItemAtPath: file.path)
        }
        let log = RequestLog()
        let environment = StubEnvironment { request in
            log.append(request)
            return (200, try makePayload(for: reference(in: request)))
        }
        defer { environment.close() }
        let repository = TafsirRepository(session: environment.session, cacheDirectory: directory)
        let first = try XCTUnwrap(AyahReference(surahID: 2, ayahNumber: 1))
        let second = try XCTUnwrap(AyahReference(surahID: 2, ayahNumber: 2))
        let new = try XCTUnwrap(AyahReference(surahID: 2, ayahNumber: 65))
        _ = try await repository.tafsir(for: first)
        XCTAssertTrue(log.requests.isEmpty)
        _ = try await repository.tafsir(for: new)
        XCTAssertEqual(log.requests.count, 1)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).count, 64)
        XCTAssertTrue(FileManager.default.fileExists(atPath: cacheURL(first, in: directory).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheURL(second, in: directory).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: cacheURL(new, in: directory).path))
    }

    func testPersistentCachePrunesItsTotalBytesAndLeavesUnrelatedFilesAlone() async throws {
        let directory = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let sentinel = directory.appendingPathComponent("notes.txt")
        try Data("unrelated".utf8).write(to: sentinel)
        for ayah in 1...50 {
            let reference = try XCTUnwrap(AyahReference(surahID: 2, ayahNumber: ayah))
            let file = cacheURL(reference, in: directory)
            let payload = try makePayload(for: reference) { $0["text"] = String(repeating: "ت", count: 40_000) }
            let cached = try makeCachedPayload(payload)
            XCTAssertLessThanOrEqual(cached.count, TafsirRepository.maximumCachedEntryBytes)
            try cached.write(to: file)
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: TimeInterval(ayah))], ofItemAtPath: file.path)
        }
        let environment = StubEnvironment { _ in throw URLError(.notConnectedToInternet) }
        defer { environment.close() }
        let recent = try XCTUnwrap(AyahReference(surahID: 2, ayahNumber: 50))
        _ = try await TafsirRepository(session: environment.session, cacheDirectory: directory).tafsir(for: recent)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        let bytes = try files.reduce(0) { try $0 + Data(contentsOf: $1).count }
        XCTAssertLessThanOrEqual(bytes, TafsirRepository.maximumCachedBytes)
        XCTAssertLessThanOrEqual(files.count, TafsirRepository.maximumCachedEntries)
        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheURL(try XCTUnwrap(AyahReference(surahID: 2, ayahNumber: 1)), in: directory).path))
        XCTAssertEqual(try Data(contentsOf: sentinel), Data("unrelated".utf8))
    }

    func testCacheDoesNotFollowOrOverwriteAnEntrySymlink() async throws {
        let directory = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let reference = try XCTUnwrap(AyahReference(surahID: 1, ayahNumber: 1))
        let outside = directory.appendingPathComponent("preserve.txt")
        let sentinel = Data("preserve this target".utf8)
        try sentinel.write(to: outside)
        let originalDate = Date(timeIntervalSince1970: 1_000)
        try FileManager.default.setAttributes([.modificationDate: originalDate], ofItemAtPath: outside.path)
        let link = cacheURL(reference, in: directory)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        let fixture = try makePayload(for: reference)
        let environment = StubEnvironment { _ in (200, fixture) }
        defer { environment.close() }
        let repository = TafsirRepository(session: environment.session, cacheDirectory: directory)
        let entry = try await repository.tafsir(for: reference)
        _ = try await repository.tafsir(for: reference)
        XCTAssertEqual(entry.language, "ar")
        XCTAssertEqual(try Data(contentsOf: outside), sentinel)
        XCTAssertEqual(try outside.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate, originalDate)
        XCTAssertTrue(try link.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true)
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

private func temporaryCacheDirectory() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("Sakina-Tafsir-\(UUID().uuidString)", isDirectory: true)
}

private func cacheURL(_ reference: AyahReference, in directory: URL) -> URL {
    directory.appendingPathComponent(String(format: "%03d-%03d.json", reference.surahID, reference.ayahNumber))
}

private func makeCachedPayload(_ response: Data, version: Int = 1, source: String = "https://api.alquran.cloud/ar.muyassar") throws -> Data {
    try JSONSerialization.data(withJSONObject: ["version": version, "source": source, "response": response.base64EncodedString()])
}

private func reference(in request: URLRequest) throws -> AyahReference {
    let components = try XCTUnwrap(request.url?.path.split(separator: "/").dropFirst(2).first?.split(separator: ":"))
    return try XCTUnwrap(AyahReference(surahID: try XCTUnwrap(Int(try XCTUnwrap(components.first))),
                                       ayahNumber: try XCTUnwrap(Int(try XCTUnwrap(components.last)))))
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

    init(contentType: String? = "application/json", handler: @escaping StubURLProtocol.Handler) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.httpAdditionalHeaders = ["X-Test-Session": token]
        session = URLSession(configuration: configuration)
        StubURLProtocol.register(token: token, handler: handler, contentType: contentType)
    }

    func close() {
        session.invalidateAndCancel()
        StubURLProtocol.unregister(token: token)
    }
}

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = (URLRequest) throws -> (Int, Data)
    struct Fixture {
        let handler: Handler
        let contentType: String?
    }
    private static let registry = HandlerRegistry()

    static func register(token: String, handler: @escaping Handler, contentType: String?) {
        registry.set(token, fixture: Fixture(handler: handler, contentType: contentType))
    }
    static func unregister(token: String) { registry.remove(token) }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let fixture = try XCTUnwrap(Self.registry.get(request.value(forHTTPHeaderField: "X-Test-Session")))
            let (status, data) = try fixture.handler(request)
            let headers = fixture.contentType.map { ["Content-Type": $0] } ?? [:]
            let response = try XCTUnwrap(HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers))
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
        private var handlers: [String: Fixture] = [:]

        func set(_ token: String, fixture: Fixture) {
            lock.lock()
            defer { lock.unlock() }
            handlers[token] = fixture
        }

        func get(_ token: String?) -> Fixture? {
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
