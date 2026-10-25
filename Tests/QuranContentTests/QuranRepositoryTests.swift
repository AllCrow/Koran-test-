import Foundation
import XCTest
import QuranCore
import QuranData

final class QuranRepositoryTests: XCTestCase {
    private var bundledDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("App/Resources/Quran", isDirectory: true)
    }

    func testAllBundledChaptersPassRuntimeValidation() async throws {
        let repository = QuranRepository(resourceDirectory: bundledDirectory)
        let index = try await repository.loadIndex()
        XCTAssertEqual(index.surahs.count, 114)
        var verseCount = 0
        for metadata in index.surahs {
            let chapter = try await repository.loadChapter(id: metadata.id)
            XCTAssertEqual(chapter.surah, metadata)
            verseCount += chapter.ayahs.count
        }
        XCTAssertEqual(verseCount, 6_236)
        let firstChapter = try await repository.loadChapter(id: 1)
        XCTAssertEqual(firstChapter.ayahs.first?.text, "\u{FEFF}بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ")
        XCTAssertNotNil(firstChapter.ayahs.first?.tajweed)
        let lastChapter = try await repository.loadChapter(id: 114)
        XCTAssertEqual(lastChapter.ayahs.last?.id, 6_236)
    }

    func testIndexLoadingDoesNotRequireAnyChapterFiles() async throws {
        try await withFixture { directory in
            let repository = QuranRepository(resourceDirectory: directory)
            let index = try await repository.loadIndex()
            XCTAssertEqual(index.surahs.first?.englishName, "Al-Faatiha")
            await assertError(.missingResource("001")) {
                _ = try await repository.loadChapter(id: 1)
            }
        }
    }

    func testUnsupportedContentVersionIsRejected() async throws {
        try await withFixture { directory in
            try mutateJSON(at: directory.appendingPathComponent("index.json")) { json in
                json["version"] = 2
            }
            let repository = QuranRepository(resourceDirectory: directory)
            await assertError(.invalidIndex) { _ = try await repository.loadIndex() }
        }
    }

    func testIndexCannotChangeCanonicalVerseCount() async throws {
        try await withFixture { directory in
            try mutateJSON(at: directory.appendingPathComponent("index.json")) { json in
                var surahs = try XCTUnwrap(json["surahs"] as? [[String: Any]])
                surahs[0]["numberOfAyahs"] = 8
                json["surahs"] = surahs
            }
            let repository = QuranRepository(resourceDirectory: directory)
            await assertError(.invalidIndex) { _ = try await repository.loadIndex() }
        }
    }

    func testChapterWithWrongGlobalVerseIdentityIsRejected() async throws {
        try await withFixture(chapters: [1]) { directory in
            try mutateJSON(at: directory.appendingPathComponent("001.json")) { json in
                var ayahs = try XCTUnwrap(json["ayahs"] as? [[String: Any]])
                ayahs[1]["id"] = 3
                json["ayahs"] = ayahs
            }
            let repository = QuranRepository(resourceDirectory: directory)
            await assertError(.invalidChapter(1)) { _ = try await repository.loadChapter(id: 1) }
        }
    }

    func testChapterCannotOmitAVerse() async throws {
        try await withFixture(chapters: [1]) { directory in
            try mutateJSON(at: directory.appendingPathComponent("001.json")) { json in
                var ayahs = try XCTUnwrap(json["ayahs"] as? [[String: Any]])
                ayahs.removeLast()
                json["ayahs"] = ayahs
            }
            let repository = QuranRepository(resourceDirectory: directory)
            await assertError(.invalidChapter(1)) { _ = try await repository.loadChapter(id: 1) }
        }
    }

    func testMalformedIndexUsesLocalizedValidationErrorAndCanBeRetried() async throws {
        try await withFixture { directory in
            let path = directory.appendingPathComponent("index.json")
            let original = try Data(contentsOf: path)
            try Data("{\"version\":".utf8).write(to: path)
            let repository = QuranRepository(resourceDirectory: directory)
            await assertError(.invalidIndex) { _ = try await repository.loadIndex() }
            // Failed decoding must not poison the cache with a partial index.
            try original.write(to: path)
            let recovered = try await repository.loadIndex()
            XCTAssertEqual(recovered.surahs.count, 114)
        }
    }

    func testMalformedChapterUsesLocalizedValidationErrorAndCanBeRetried() async throws {
        try await withFixture(chapters: [1]) { directory in
            let path = directory.appendingPathComponent("001.json")
            let original = try Data(contentsOf: path)
            try Data("[]".utf8).write(to: path)
            let repository = QuranRepository(resourceDirectory: directory)
            await assertError(.invalidChapter(1)) { _ = try await repository.loadChapter(id: 1) }
            try original.write(to: path)
            let recovered = try await repository.loadChapter(id: 1)
            XCTAssertEqual(recovered.ayahs.count, 7)
        }
    }

    func testInvalidChapterIDFailsBeforeReadingResources() async {
        let repository = QuranRepository(resourceDirectory: URL(fileURLWithPath: "/nonexistent-quran-test"))
        await assertError(.invalidChapter(0)) { _ = try await repository.loadChapter(id: 0) }
        await assertError(.invalidChapter(115)) { _ = try await repository.loadChapter(id: 115) }
    }

    func testChapterCacheIsBoundedAndRetainsRecentlyUsedChapter() async throws {
        try await withFixture(chapters: [1, 2, 3, 4, 5]) { directory in
            let repository = QuranRepository(resourceDirectory: directory)
            for id in 1...4 { _ = try await repository.loadChapter(id: id) }
            // A cached chapter remains available without another disk read.
            try FileManager.default.removeItem(at: directory.appendingPathComponent("001.json"))
            let cached = try await repository.loadChapter(id: 1)
            XCTAssertEqual(cached.surah.id, 1)
            _ = try await repository.loadChapter(id: 5)
            // Four entries fit. Chapter 2 is now the oldest; it must be read again.
            try FileManager.default.removeItem(at: directory.appendingPathComponent("002.json"))
            await assertError(.missingResource("002")) { _ = try await repository.loadChapter(id: 2) }
            let retained = try await repository.loadChapter(id: 1)
            XCTAssertEqual(retained.surah.id, 1)
        }
    }

    private func withFixture(chapters: [Int] = [], operation: (URL) async throws -> Void) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let filenames = ["index.json"] + chapters.map { String(format: "%03d.json", $0) }
        for filename in filenames {
            try FileManager.default.copyItem(at: bundledDirectory.appendingPathComponent(filename), to: directory.appendingPathComponent(filename))
        }
        try await operation(directory)
    }

    private func mutateJSON(at url: URL, mutation: (inout [String: Any]) throws -> Void) throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        try mutation(&json)
        try JSONSerialization.data(withJSONObject: json).write(to: url)
    }

    private func assertError(
        _ expected: QuranRepository.RepositoryError,
        file: StaticString = #filePath, line: UInt = #line,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? QuranRepository.RepositoryError, expected, file: file, line: line)
        }
    }
}
