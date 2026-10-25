import Foundation
import QuranCore
import XCTest
@testable import Sakina

@MainActor
final class ArabicTextPreparationTests: XCTestCase {
    func testCanonicalEquivalentSourcesRetainTheirOwnExactUTF8() throws {
        let composed = "[g[أ]"
        let decomposed = "[g[ا\u{0654}]"
        XCTAssertEqual(composed, decomposed, "Swift strings compare canonical equivalents equally")
        XCTAssertNotEqual(Array(composed.utf8), Array(decomposed.utf8))
        let cache = ArabicTextPreparationCache()
        let first = try XCTUnwrap(cache.preparation(for: composed).plainText)
        let second = try XCTUnwrap(cache.preparation(for: decomposed).plainText)
        XCTAssertEqual(Array(first.utf8), Array("أ".utf8))
        XCTAssertEqual(Array(second.utf8), Array("ا\u{0654}".utf8))
        XCTAssertEqual(cache.entryCount, 2)
        XCTAssertEqual(Array(try XCTUnwrap(cache.preparation(for: composed).plainText).utf8), Array(first.utf8))
    }

    func testMalformedOrEmptyAnnotationsRequestCanonicalFallback() {
        let cache = ArabicTextPreparationCache()
        for source in ["", "ٱفْتَرَ[ٮٰ]هُ", "[g[ن", "[x[ن]"] {
            let prepared = cache.preparation(for: source)
            XCTAssertTrue(prepared.usesFallback, source)
            XCTAssertNil(prepared.spans, source)
            XCTAssertNil(prepared.plainText, source)
        }
    }

    func testNestedRulesPreserveWholeScalarSequenceAndInnerPrecedence() throws {
        let prepared = ArabicTextPreparationCache().preparation(for: "[o[ُوٓ[s[اْ]‌ۚ]")
        XCTAssertFalse(prepared.usesFallback)
        XCTAssertEqual(Array(try XCTUnwrap(prepared.plainText).utf8), Array("ُوٓاْ‌ۚ".utf8))
        XCTAssertEqual(prepared.spans?.map(\.rule), [.maddObligatory, .silent, .maddObligatory])
    }

    func testLongReadingSessionRetainsOnlyConfiguredNumberOfPreparations() {
        let cache = ArabicTextPreparationCache(capacity: 2)
        for number in 1...1_000 {
            let source = "نَصٌّ \(number)"
            let prepared = cache.preparation(for: source)
            XCTAssertEqual(Array(prepared.plainText?.utf8 ?? "".utf8), Array(source.utf8))
            XCTAssertLessThanOrEqual(cache.entryCount, 2)
        }
        XCTAssertEqual(cache.entryCount, 2)
    }

    func testSearchUsesKeyboardArabicWithoutChangingSourceNames() {
        let name = "سُورَةُ ٱلْفَاتِحَةِ"
        let fatiha = Surah(id: 1, name: name, englishName: "Al-Faatiha", englishNameTranslation: "The Opening", numberOfAyahs: 7, revelationType: "Meccan")
        let index = SurahSearchIndex(surahs: [fatiha])
        for query in ["الفاتحة", "ٱلفاتحة", "الفَاتِحَة", "  AL FAATIHA  ", "Fatiha", "Faatiha", "Faaatiha", "opening", "١", "۱"] {
            XCTAssertEqual(index.matching(query).map(\.id), [1], query)
        }
        XCTAssertTrue(index.matching("zzznomatch").isEmpty)
        XCTAssertTrue(index.matching("Fattiha").isEmpty, "Consonants must not be collapsed as transliterated long vowels")
        XCTAssertEqual(Array(index.surahs[0].name.utf8), Array(name.utf8))
        XCTAssertEqual(Array(index.surahs[0].englishName.utf8), Array("Al-Faatiha".utf8))
    }

    func testSearchRebuildDoesNotKeepResultsFromPreviousMetadata() {
        let fatiha = Surah(id: 1, name: "الفاتحة", englishName: "Al-Faatiha", englishNameTranslation: "The Opening", numberOfAyahs: 7, revelationType: "Meccan")
        let ikhlas = Surah(id: 112, name: "الإخلاص", englishName: "Al-Ikhlaas", englishNameTranslation: "Sincerity", numberOfAyahs: 4, revelationType: "Meccan")
        let index = SurahSearchIndex(surahs: [fatiha, ikhlas])
        XCTAssertEqual(index.matching("الاخلاص").map(\.id), [112])
        XCTAssertEqual(index.matching("١١٢").map(\.id), [112])
        for query in ["Ikhlas", "Ikhlaas", "al ikhlas"] {
            XCTAssertEqual(index.matching(query).map(\.id), [112], query)
        }
        let replaced = SurahSearchIndex(surahs: [ikhlas])
        XCTAssertTrue(replaced.matching("opening").isEmpty)
        XCTAssertEqual(replaced.matching("  ").map(\.id), [112])
    }

    func testVerseJumpAcceptsKeyboardNumeralsWithinCurrentSurah() {
        for input in ["255", "٢٥٥", "۲۵۵", "２５５", " ٢٥٥\n", "000255"] {
            XCTAssertEqual(VerseJumpInput.number(from: input, maximum: 286), 255, input)
        }
        XCTAssertEqual(VerseJumpInput.number(from: "1", maximum: 7), 1)
        XCTAssertEqual(VerseJumpInput.number(from: "٧", maximum: 7), 7)
    }

    func testVerseJumpRejectsOutOfRangeOrNonDecimalInput() {
        for input in ["", " ", "0", "٠", "287", "٢٨٧", "-1", "+1", "2:255", "2.5", "٢٫٥", "2 55", "²", "Ⅷ", "255verser", "99999999999999999999"] {
            XCTAssertNil(VerseJumpInput.number(from: input, maximum: 286), input)
        }
        XCTAssertNil(VerseJumpInput.number(from: "1", maximum: 0))
        XCTAssertNil(VerseJumpInput.number(from: "1", maximum: -1))
    }
}
