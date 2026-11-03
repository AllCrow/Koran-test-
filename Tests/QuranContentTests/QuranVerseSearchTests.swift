import Foundation
import XCTest
import QuranCore
@testable import QuranData

final class QuranVerseSearchTests: XCTestCase {
    private var bundledDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("App/Resources/Quran", isDirectory: true)
    }

    func testUnvocalizedKeyboardPhraseFindsTheSameVerseAsSourceDiacritics() async throws {
        let search = QuranVerseSearch(repository: QuranRepository(resourceDirectory: bundledDirectory))
        let keyboard = try await search.search("قل هو الله احد")
        let source = try await search.search("قُلْ هُوَ ٱللَّهُ أَحَدٌ")
        XCTAssertEqual(keyboard, source)
        XCTAssertEqual(keyboard.hits.map(\.reference), [AyahReference(surahID: 112, ayahNumber: 1)!])
        XCTAssertFalse(keyboard.hasMore)
    }

    func testSearchPreservesSourceBytesAndUsesReaderBasmalaPresentation() async throws {
        let repository = QuranRepository(resourceDirectory: bundledDirectory)
        let chapter = try await repository.loadChapter(id: 1)
        let original = try XCTUnwrap(chapter.ayahs.first)
        let sourceBytes = Data(original.text.utf8)
        let search = QuranVerseSearch(repository: repository)
        let result = try await search.search("بسم الله")
        let first = try XCTUnwrap(result.hits.first { $0.reference == original.reference })
        XCTAssertEqual(Data(first.text.utf8), sourceBytes)
        // The opening Basmala is a separate header outside al-Fatiha; it must
        // not make every chapter's first numbered verse a false positive.
        XCTAssertFalse(result.hits.contains { $0.reference == AyahReference(surahID: 2, ayahNumber: 1) })
        let after = try await repository.loadChapter(id: 1)
        XCTAssertEqual(Data(after.ayahs[0].text.utf8), sourceBytes)
    }

    func testCopyNormalizationHandlesKeyboardVariantsTatweelAndWhitespace() {
        let first = "\u{FEFF}  ٱللَّهُ\nأَحَدٌ  "
        XCTAssertEqual(QuranVerseSearch.normalizedCopy(first), "الله احد")
        XCTAssertEqual(QuranVerseSearch.normalizedCopy("إلى كِتَابٍ"),
                       QuranVerseSearch.normalizedCopy("اِلـي  کتاب"))
        XCTAssertEqual(first.utf8.first, 0xEF) // normalization did not replace the source value
        XCTAssertEqual(QuranVerseSearch.normalizedCopy("ٱلْحَمْدُ ۚ لِلَّهِ"), "الحمد لله")
    }

    func testResultsAreBoundedInQuranOrderAndReportAdditionalMatches() async throws {
        let search = QuranVerseSearch(repository: QuranRepository(resourceDirectory: bundledDirectory))
        let two = try await search.search("الله", limit: 2)
        XCTAssertEqual(two.hits.count, 2)
        XCTAssertTrue(two.hasMore)
        let bounded = try await search.search("الله", limit: Int.max)
        XCTAssertEqual(bounded.hits.count, QuranVerseSearch.maximumResultCount)
        XCTAssertTrue(bounded.hasMore)
        XCTAssertEqual(Array(bounded.hits.prefix(2)), two.hits)
        XCTAssertEqual(bounded.hits.map(\.reference.id), bounded.hits.sorted {
            ($0.reference.surahID, $0.reference.ayahNumber) < ($1.reference.surahID, $1.reference.ayahNumber)
        }.map(\.reference.id))
        XCTAssertEqual(Set(bounded.hits.map(\.id)).count, bounded.hits.count)
    }

    func testEmptyShortAndNonArabicQueriesDoNotReadResources() async throws {
        let search = QuranVerseSearch(repository: QuranRepository(resourceDirectory: URL(fileURLWithPath: "/missing-search-fixture")))
        for query in ["", " \n", "ا", "\u{064B}\u{0651}", "Allah", "123"] {
            let result = try await search.search(query)
            XCTAssertTrue(result.hits.isEmpty)
            XCTAssertFalse(result.hasMore)
            XCTAssertFalse(QuranVerseSearch.isSearchable(query))
        }
    }

    func testOverlongQueryIsRejectedBeforeReadingResources() async {
        let search = QuranVerseSearch(repository: QuranRepository(resourceDirectory: URL(fileURLWithPath: "/missing-search-fixture")))
        do {
            _ = try await search.search(String(repeating: "الله", count: 200))
            XCTFail("An overlong query must be rejected")
        } catch {
            XCTAssertEqual(error as? QuranVerseSearch.SearchError, .queryTooLong)
        }
    }

    func testCancelledSearchDoesNotReadOrPublishResults() async {
        let search = QuranVerseSearch(repository: QuranRepository(resourceDirectory: URL(fileURLWithPath: "/missing-search-fixture")))
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await search.search("الله")
        }
        do {
            _ = try await task.value
            XCTFail("A cancelled search must throw")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testNoMatchHasNoTruncationFlag() async throws {
        let search = QuranVerseSearch(repository: QuranRepository(resourceDirectory: bundledDirectory))
        let result = try await search.search("زززززز")
        XCTAssertTrue(result.hits.isEmpty)
        XCTAssertFalse(result.hasMore)
    }
}
