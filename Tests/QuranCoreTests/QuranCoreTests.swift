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

    func testEmptyTextAndAllKnownRuleCodes() {
        XCTAssertTrue(TajweedParser.parse("").isEmpty)
        for rule in TajweedRule.allCases {
            let spans = TajweedParser.parse("[\(rule.rawValue)[ن]")
            XCTAssertEqual(spans, [TajweedSpan(text: "ن", rule: rule)])
        }
    }
}
