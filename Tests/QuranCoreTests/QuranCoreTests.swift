import Foundation
import XCTest
@testable import QuranCore

final class QuranReferenceTests: XCTestCase {
    func testHafsReferenceBoundsAndTotal() throws {
        XCTAssertEqual(AyahReference.ayahCounts.count, 114)
        XCTAssertEqual(AyahReference.ayahCounts.reduce(0, +), 6_236)
        XCTAssertNotNil(AyahReference(surahID: 1, ayahNumber: 7))
        XCTAssertNotNil(AyahReference(surahID: 2, ayahNumber: 286))
        XCTAssertNotNil(AyahReference(surahID: 114, ayahNumber: 6))
        for (surah, ayah) in [(0, 1), (115, 1), (1, 0), (1, 8), (2, 287), (114, 7)] {
            XCTAssertNil(AyahReference(surahID: surah, ayahNumber: ayah))
        }
    }

    func testInvalidSavedReferenceCannotBypassValidation() throws {
        let invalid = Data(#"{"surahID":2,"ayahNumber":287}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(AyahReference.self, from: invalid))
        let valid = try XCTUnwrap(AyahReference(surahID: 2, ayahNumber: 255))
        XCTAssertEqual(try JSONDecoder().decode(AyahReference.self, from: JSONEncoder().encode(valid)), valid)
        XCTAssertEqual(valid.id, "2:255")
    }

    func testRecordingsAreBoundToExactReciterAndVerse() throws {
        let reference = try XCTUnwrap(AyahReference(surahID: 2, ayahNumber: 255))
        let expected: [Reciter: String] = [
            .alafasy: "https://everyayah.com/data/Alafasy_128kbps/002255.mp3",
            .husary: "https://everyayah.com/data/Husary_128kbps/002255.mp3",
            .minshawi: "https://everyayah.com/data/Minshawy_Murattal_128kbps/002255.mp3"
        ]
        for reciter in Reciter.allCases {
            XCTAssertEqual(reciter.audioURL(for: reference).absoluteString, expected[reciter])
        }
    }
}

final class StreakTrackerTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func testOnlyCompletedSessionsCountAndSameDayIsIdempotent() {
        var tracker = StreakTracker()
        XCTAssertEqual(tracker.summary(asOf: date(2026, 10, 24), calendar: calendar).current, 0)
        XCTAssertTrue(tracker.complete(on: date(2026, 10, 24, hour: 8), calendar: calendar))
        XCTAssertFalse(tracker.complete(on: date(2026, 10, 24, hour: 23), calendar: calendar))
        XCTAssertEqual(tracker.completionDays.count, 1)
        let summary = tracker.summary(asOf: date(2026, 10, 24), calendar: calendar)
        XCTAssertEqual(summary.current, 1)
        XCTAssertEqual(summary.best, 1)
        XCTAssertTrue(summary.completedToday)
    }

    func testYesterdayRunRemainsCurrentButMissedDayResetsIt() {
        var tracker = StreakTracker()
        for day in [21, 22, 23] { tracker.complete(on: date(2026, 10, day), calendar: calendar) }
        let today = tracker.summary(asOf: date(2026, 10, 24), calendar: calendar)
        XCTAssertEqual(today.current, 3)
        XCTAssertFalse(today.completedToday)
        let missedDay = tracker.summary(asOf: date(2026, 10, 25), calendar: calendar)
        XCTAssertEqual(missedDay.current, 0)
        XCTAssertEqual(missedDay.best, 3)
        tracker.complete(on: date(2026, 10, 25), calendar: calendar)
        XCTAssertEqual(tracker.summary(asOf: date(2026, 10, 25), calendar: calendar).current, 1)
    }

    func testDaylightSavingTransitionsUseCivilDays() {
        var spring = StreakTracker()
        for day in [28, 29, 30] { spring.complete(on: date(2026, 3, day), calendar: calendar) }
        XCTAssertEqual(spring.summary(asOf: date(2026, 3, 30), calendar: calendar).current, 3)
        var autumn = StreakTracker()
        for day in [24, 25, 26] { autumn.complete(on: date(2026, 10, day), calendar: calendar) }
        XCTAssertEqual(autumn.summary(asOf: date(2026, 10, 26), calendar: calendar).current, 3)
    }

    func testGregorianYearBoundaryAndLeapDay() {
        var tracker = StreakTracker()
        tracker.complete(on: date(2024, 2, 28), calendar: calendar)
        tracker.complete(on: date(2024, 2, 29), calendar: calendar)
        tracker.complete(on: date(2024, 3, 1), calendar: calendar)
        XCTAssertEqual(tracker.summary(asOf: date(2024, 3, 1), calendar: calendar).current, 3)
        XCTAssertNil(ReadingDay(year: 2025, month: 2, day: 29))
        var year = StreakTracker()
        year.complete(on: date(2025, 12, 31), calendar: calendar)
        year.complete(on: date(2026, 1, 1), calendar: calendar)
        XCTAssertEqual(year.summary(asOf: date(2026, 1, 1), calendar: calendar).current, 2)
    }

    func testFutureClockChangesDoNotInflateCurrentOrBest() {
        var tracker = StreakTracker()
        for day in [24, 25, 26, 27] { tracker.complete(on: date(2026, 10, day), calendar: calendar) }
        let summary = tracker.summary(asOf: date(2026, 10, 24), calendar: calendar)
        XCTAssertEqual(summary.current, 1)
        XCTAssertEqual(summary.best, 1)
    }

    func testCompletionRemainsItsOriginalCivilDayAfterTravel() {
        var tracker = StreakTracker()
        let session = date(2026, 10, 24, hour: 0, minute: 15)
        tracker.complete(on: session, calendar: calendar)
        XCTAssertEqual(tracker.completionDays.first?.id, "2026-10-24")
        var destination = Calendar(identifier: .gregorian)
        destination.timeZone = TimeZone(identifier: "America/New_York")!
        let destinationToday = destination.date(from: DateComponents(year: 2026, month: 10, day: 24, hour: 12))!
        XCTAssertTrue(tracker.isCompleted(on: destinationToday, calendar: destination))
        XCTAssertEqual(tracker.completionDays.first?.id, "2026-10-24")
    }

    func testSavedCivilDayAdjacencyIsStableInTimezoneWithSkippedDate() throws {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        var apia = Calendar(identifier: .gregorian)
        apia.timeZone = try XCTUnwrap(TimeZone(identifier: "Pacific/Apia"))
        // Apia skipped December 30 when it moved across the date line. These
        // saved labels may have been completed elsewhere before travelling.
        let december29 = try XCTUnwrap(ReadingDay(year: 2011, month: 12, day: 29))
        let december30 = try XCTUnwrap(ReadingDay(year: 2011, month: 12, day: 30))
        let december31 = try XCTUnwrap(ReadingDay(year: 2011, month: 12, day: 31))
        let consecutive = StreakTracker(completionDays: [december29, december30])
        let gap = StreakTracker(completionDays: [december29, december31])
        for zone in [utc, apia] {
            let today = try XCTUnwrap(zone.date(from: DateComponents(year: 2011, month: 12, day: 31, hour: 12)))
            let preserved = consecutive.summary(asOf: today, calendar: zone)
            XCTAssertEqual(preserved.current, 2, "Saved December 30 must not normalize to December 31")
            XCTAssertEqual(preserved.best, 2)
            XCTAssertFalse(preserved.completedToday)
            let separated = gap.summary(asOf: today, calendar: zone)
            XCTAssertEqual(separated.current, 1, "A timezone must not make non-adjacent civil labels adjacent")
            XCTAssertEqual(separated.best, 1)
            XCTAssertTrue(separated.completedToday)
        }
    }

    func testSavedDataDeduplicatesAndRejectsInvalidDays() throws {
        let duplicate = Data(#"{"completionDays":[{"year":2026,"month":10,"day":24},{"year":2026,"month":10,"day":24}]}"#.utf8)
        let tracker = try JSONDecoder().decode(StreakTracker.self, from: duplicate)
        XCTAssertEqual(tracker.completionDays.count, 1)
        let invalid = Data(#"{"completionDays":[{"year":2026,"month":2,"day":31}]}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(StreakTracker.self, from: invalid))
        XCTAssertEqual(try JSONDecoder().decode(StreakTracker.self, from: JSONEncoder().encode(tracker)), tracker)
    }
}

final class TajweedParserTests: XCTestCase {
    func testAnnotatedBasmalaKeepsExactArabicScalars() {
        let source = "بِسْمِ [h:1[ٱ]للَّهِ [h:2[ٱ][l[ل]رَّحْمَ[n[ـٰ]نِ [h:3[ٱ][l[ل]رَّح[p[ِي]مِ"
        let expected = "بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ"
        let spans = TajweedParser.parse(source)
        XCTAssertEqual(spans.map(\.text).joined().unicodeScalars.map(\.value), expected.unicodeScalars.map(\.value))
        XCTAssertEqual(spans.filter { $0.rule == .hamzatWasl }.count, 3)
        XCTAssertEqual(spans.first { $0.rule == .maddNormal }?.text, "ـٰ")
    }

    func testUnknownAndMalformedAnnotationsAreNeverSilentlyDiscarded() {
        for source in ["نَصٌّ [x[عَرَبِيٌّ]", "[h:1[ٱ", "[g[ن[h[ٱ]", "[h:[ٱ]", "نَصٌّ بلا وسوم"] {
            XCTAssertEqual(TajweedParser.plainText(source).unicodeScalars.map(\.value), source.unicodeScalars.map(\.value))
        }
    }

    func testCombiningMarksAfterAnnotationBoundaryRemainPresent() {
        let source = "[p[ِي]مِ [g[نّ]َهَا"
        let expected = "ِيمِ نَّهَا"
        XCTAssertEqual(TajweedParser.plainText(source).unicodeScalars.map(\.value), expected.unicodeScalars.map(\.value))
        XCTAssertEqual(TajweedParser.parse(source).filter { $0.rule != nil }.map(\.rule), [.maddPermissible, .ghunnah])
    }

    func testNestedSourceAnnotationsKeepCombiningMarksAndInnerRulePrecedence() {
        // Real nested form from the quran-tajweed edition of 2:190.
        let source = "[o[ُوٓ[s[اْ]‌ۚ]"
        let spans = TajweedParser.parse(source)
        XCTAssertEqual(spans.map(\.text).joined().unicodeScalars.map(\.value), "ُوٓاْ‌ۚ".unicodeScalars.map(\.value))
        XCTAssertEqual(spans.map(\.rule), [.maddObligatory, .silent, .maddObligatory])
        // Missing the outer closing bracket leaves the entire token intact.
        let incomplete = "[o[ُوٓ[s[اْ]‌ۚ"
        XCTAssertEqual(TajweedParser.plainText(incomplete).unicodeScalars.map(\.value), incomplete.unicodeScalars.map(\.value))
    }

    func testUnknownUpstreamSquareBracketsRemainVerbatim() {
        let source = "ٱفْتَرَ[ٮٰ]هُ"
        XCTAssertEqual(TajweedParser.plainText(source).unicodeScalars.map(\.value), source.unicodeScalars.map(\.value))
    }

    func testExcessivelyNestedInputFallsBackWithoutDroppingAnySource() {
        let source = "عَرَبِيٌّ " + String(repeating: "[g[", count: 10_000) + "نِّ" + String(repeating: "]", count: 10_000)
        let spans = TajweedParser.parse(source)
        XCTAssertTrue(spans.map(\.text).joined().utf8.elementsEqual(source.utf8))
        XCTAssertTrue(spans.allSatisfy { $0.rule == nil })
        // Valid ordinary nesting must continue giving the inner rule priority.
        XCTAssertEqual(TajweedParser.parse("[g[نِّ[n[ـٰ]]").map(\.rule), [.ghunnah, .maddNormal])
    }

    func testEmptyTextAndAllKnownRuleCodes() {
        XCTAssertTrue(TajweedParser.parse("").isEmpty)
        for rule in TajweedRule.allCases {
            let spans = TajweedParser.parse("[\(rule.rawValue)[ن]")
            XCTAssertEqual(spans, [TajweedSpan(text: "ن", rule: rule)])
        }
    }
}

final class QuranPresentationTests: XCTestCase {
    private let standard = "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ "
    private let sourceVariant = "بِّسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ "

    private func ayah(surah: Int, number: Int = 1, text: String) -> Ayah {
        Ayah(id: 1, surahID: surah, numberInSurah: number, text: text)
    }

    private func chapter(_ ayah: Ayah) -> QuranChapter {
        let surah = Surah(id: ayah.surahID, name: "", englishName: "", englishNameTranslation: "", numberOfAyahs: 1, revelationType: "")
        return QuranChapter(surah: surah, ayahs: [ayah])
    }

    func testBothRecognizedPrefixesAreExtractedVerbatimAndReconstructRawText() throws {
        for (surah, prefix) in [(2, standard), (95, sourceVariant), (97, sourceVariant)] {
            let raw = prefix + "نَصُّ الْآيَةِ"
            let original = ayah(surah: surah, text: raw)
            let header = try XCTUnwrap(QuranPresentation.basmala(for: original))
            XCTAssertEqual(Array(header.utf8), Array(prefix.dropLast().utf8))
            XCTAssertEqual(QuranPresentation.basmala(for: chapter(original)), header)
            XCTAssertEqual(QuranPresentation.verseText(original), "نَصُّ الْآيَةِ")
            XCTAssertEqual(Array((header + " " + QuranPresentation.verseText(original)).utf8), Array(raw.utf8))
            XCTAssertEqual(Array(original.text.utf8), Array(raw.utf8))
        }
    }

    func testFatihaAndTawbaRemainUnchangedEvenWithRecognizedText() {
        for surah in [1, 9] {
            let original = ayah(surah: surah, text: standard + "نَصٌّ")
            XCTAssertNil(QuranPresentation.basmala(for: original))
            XCTAssertNil(QuranPresentation.basmala(for: chapter(original)))
            XCTAssertEqual(QuranPresentation.verseText(original), original.text)
        }
    }

    func testNoHeaderIsInventedForUnknownOrAbsentPrefix() {
        for raw in ["نَصُّ الْآيَةِ", "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ نَصٌّ", standard.dropLast().description] {
            let original = ayah(surah: 2, text: raw)
            XCTAssertNil(QuranPresentation.basmala(for: original))
            XCTAssertNil(QuranPresentation.basmala(for: chapter(original)))
            XCTAssertEqual(Array(QuranPresentation.verseText(original).utf8), Array(raw.utf8))
        }
    }

    func testLaterAyahsAreNeverSplit() {
        let original = ayah(surah: 2, number: 2, text: standard + "نَصٌّ")
        XCTAssertNil(QuranPresentation.basmala(for: original))
        XCTAssertNil(QuranPresentation.basmala(for: chapter(original)))
        XCTAssertEqual(QuranPresentation.verseText(original), original.text)
    }
}

final class BundledQuranPresentationTests: XCTestCase {
    /// This is a repository integration test: missing bundled resources fail.
    func testEveryBundledVerseKeepsItsRawScalarsWhenRendered() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let directory = root.appendingPathComponent("App/Resources/Quran", isDirectory: true)
        let markup = try NSRegularExpression(pattern: #"\[[a-z](?::\d+)?\[([^\[\]]*)\]"#)
        var verseCount = 0
        var headerCount = 0
        var preservedUnknownMarkup: [String] = []
        for surahID in 1...114 {
            let file = directory.appendingPathComponent(String(format: "%03d.json", surahID))
            let chapter = try JSONDecoder().decode(QuranChapter.self, from: Data(contentsOf: file))
            XCTAssertEqual(chapter.surah.id, surahID)
            XCTAssertEqual(chapter.ayahs.count, AyahReference.ayahCounts[surahID - 1])
            let opening = try XCTUnwrap(chapter.ayahs.first)
            if surahID == 1 || surahID == 9 {
                XCTAssertNil(QuranPresentation.basmala(for: chapter))
            } else {
                let header = try XCTUnwrap(QuranPresentation.basmala(for: chapter), "Missing Basmala for surah \(surahID)")
                XCTAssertEqual(Array((header + " " + QuranPresentation.verseText(opening)).utf8), Array(opening.text.utf8))
                headerCount += 1
            }
            for ayah in chapter.ayahs {
                verseCount += 1
                XCTAssertNotNil(ayah.reference)
                if let header = QuranPresentation.basmala(for: ayah) {
                    XCTAssertEqual(Array((header + " " + QuranPresentation.verseText(ayah)).utf8), Array(ayah.text.utf8))
                } else {
                    XCTAssertEqual(Array(QuranPresentation.verseText(ayah).utf8), Array(ayah.text.utf8))
                }
                let annotation = try XCTUnwrap(ayah.tajweed)
                let rendered = TajweedParser.plainText(annotation)
                if rendered.contains("[") || rendered.contains("]") {
                    preservedUnknownMarkup.append("\(surahID):\(ayah.numberInSurah)")
                }
                // An independent regex removes only annotation syntax; comparing
                // scalars detects lost/reordered harakat and unmarked text.
                var expected = annotation
                while true {
                    let replacement = markup.stringByReplacingMatches(in: expected, range: NSRange(expected.startIndex..., in: expected), withTemplate: "$1")
                    if replacement == expected { break }
                    expected = replacement
                }
                XCTAssertEqual(rendered.unicodeScalars.map(\.value), expected.unicodeScalars.map(\.value))
            }
        }
        XCTAssertEqual(headerCount, 112)
        XCTAssertEqual(verseCount, 6_236)
        // The upstream edition contains an uncoded literal [ٮٰ] in 32:3.
        // Keep it intact at the parser boundary; UI uses canonical-text fallback.
        XCTAssertEqual(preservedUnknownMarkup, ["32:3"])
    }
}
