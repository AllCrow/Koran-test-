import Combine
import Foundation
import QuranCore
import QuranData
import XCTest
import UIKit
@testable import Sakina

/// Hosted iOS tests. These exercise native persistence and Combine observation;
/// the portable package suite cannot verify AppStore on Linux.
@MainActor
final class AppStoreTests: XCTestCase {
    private func calendar(_ timezone: String = "Europe/Stockholm") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timezone)!
        return calendar
    }

    private func date(_ day: Int, hour: Int = 12) -> Date {
        calendar().date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    private func defaults() throws -> UserDefaults {
        let name = "sakina.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    private func reference(_ ayah: Int, surah: Int = 1) throws -> AyahReference {
        try XCTUnwrap(AyahReference(surahID: surah, ayahNumber: ayah))
    }

    func testExplicitUniqueVersesCompleteGoalAndSurviveRelaunch() throws {
        let storage = try defaults()
        let today = date(24)
        let store = AppStore(defaults: storage, now: { today }, calendar: { self.calendar() })
        let first = try reference(1)
        let second = try reference(2)
        let third = try reference(3)
        store.setLastRead(first)
        XCTAssertEqual(store.todayReadCount, 0, "Navigation alone must never count as reading")
        store.markRead(first)
        store.markRead(first)
        store.markRead(second)
        XCTAssertEqual(store.todayReadCount, 2)
        XCTAssertFalse(store.dailyGoalMet)
        store.markRead(third)
        XCTAssertTrue(store.dailyGoalMet)
        XCTAssertEqual(store.streakSummary.current, 1)

        let restored = AppStore(defaults: storage, now: { today }, calendar: { self.calendar() })
        XCTAssertEqual(restored.todayReadCount, 3)
        XCTAssertEqual(restored.lastRead, third)
        XCTAssertTrue(restored.isReadToday(first))
        XCTAssertTrue(restored.dailyGoalMet)
        XCTAssertEqual(restored.streakSummary.current, 1)
    }

    func testMidnightClearsDailyMarksButPreservesStreakAndBookmarks() throws {
        var instant = date(24, hour: 23)
        let store = AppStore(defaults: try defaults(), now: { instant }, calendar: { self.calendar() })
        let first = try reference(1)
        store.setDailyGoal(1)
        store.markRead(first)
        store.toggleBookmark(first)
        instant = date(25, hour: 4) // Crosses midnight and the autumn DST fallback.
        store.refreshDay()
        XCTAssertEqual(store.todayReadCount, 0)
        XCTAssertFalse(store.isReadToday(first))
        XCTAssertFalse(store.dailyGoalMet)
        XCTAssertEqual(store.streakSummary.current, 1, "Yesterday's run remains encouraging today")
        XCTAssertTrue(store.bookmarks.contains(first))
        store.markRead(first)
        XCTAssertEqual(store.streakSummary.current, 2)
    }

    func testChangingGoalNeverRemovesAnEarnedDay() throws {
        let today = date(24)
        let store = AppStore(defaults: try defaults(), now: { today }, calendar: { self.calendar() })
        store.markRead(try reference(1))
        store.setDailyGoal(1)
        XCTAssertTrue(store.dailyGoalMet)
        store.setDailyGoal(50)
        XCTAssertEqual(store.todayReadCount, 1)
        XCTAssertTrue(store.dailyGoalMet)
        XCTAssertEqual(store.streakSummary.current, 1)
        store.setDailyGoal(-1)
        XCTAssertEqual(store.dailyGoal, 1)
        store.setDailyGoal(100)
        XCTAssertEqual(store.dailyGoal, 50)
    }

    func testSignificantClockChangeRefreshesVisibleDailyProgress() async throws {
        var instant = date(24, hour: 23)
        let store = AppStore(defaults: try defaults(), now: { instant }, calendar: { self.calendar() })
        store.setDailyGoal(1)
        store.markRead(try reference(1))
        let refreshed = expectation(description: "Daily progress refreshes after a system clock change")
        let subscription = store.$todayReadCount.dropFirst().first(where: { $0 == 0 }).sink { _ in refreshed.fulfill() }
        defer { subscription.cancel() }
        instant = date(25, hour: 4)
        NotificationCenter.default.post(name: UIApplication.significantTimeChangeNotification, object: nil)
        await fulfillment(of: [refreshed], timeout: 2)
        XCTAssertFalse(store.dailyGoalMet)
        XCTAssertEqual(store.streakSummary.current, 1)
    }

    func testBookmarkAndPresentationPreferencesPersistWithoutReadingCredit() throws {
        let storage = try defaults()
        let today = date(24)
        let store = AppStore(defaults: storage, now: { today }, calendar: { self.calendar() })
        let verse = try reference(255, surah: 2)
        store.toggleBookmark(verse)
        store.setLastRead(verse)
        store.setTajweedEnabled(false)
        store.setDailyGoal(7)
        let restored = AppStore(defaults: storage, now: { today }, calendar: { self.calendar() })
        XCTAssertEqual(restored.bookmarks, [verse])
        XCTAssertEqual(restored.lastRead, verse)
        XCTAssertFalse(restored.tajweedEnabled)
        XCTAssertEqual(restored.dailyGoal, 7)
        XCTAssertEqual(restored.todayReadCount, 0)
        restored.toggleBookmark(verse)
        XCTAssertTrue(restored.bookmarks.isEmpty)
    }

    func testOldDetailedMarksArePrunedWithoutLosingCompletedHistory() throws {
        let storage = try defaults()
        var instant = date(1)
        let store = AppStore(defaults: storage, now: { instant }, calendar: { self.calendar() })
        store.setDailyGoal(1)
        store.markRead(try reference(1))
        instant = date(24)
        store.refreshDay()
        XCTAssertEqual(store.todayReadCount, 0)
        XCTAssertEqual(store.streakSummary.best, 1)
        let saved = try XCTUnwrap(storage.data(forKey: "sakina.reading-state.v1"))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: saved) as? [String: Any])
        let marks = try XCTUnwrap(object["readAyahsByDay"] as? [String: Any])
        XCTAssertTrue(marks.isEmpty)
        let restored = AppStore(defaults: storage, now: { instant }, calendar: { self.calendar() })
        XCTAssertEqual(restored.streakSummary.best, 1)
    }

    func testCorruptSavedDataFallsBackToSafeDefaults() throws {
        let storage = try defaults()
        storage.set(Data("invalid saved state".utf8), forKey: "sakina.reading-state.v1")
        let today = date(24)
        let store = AppStore(defaults: storage, now: { today }, calendar: { self.calendar() })
        XCTAssertEqual(store.selectedSurahID, 1)
        XCTAssertEqual(store.dailyGoal, 3)
        XCTAssertEqual(store.todayReadCount, 0)
        XCTAssertNil(store.lastRead)
        XCTAssertTrue(store.bookmarks.isEmpty)
    }

    func testBundledNativeContentLoadsAndInvalidSelectionIsIgnored() async throws {
        let today = date(24)
        let store = AppStore(defaults: try defaults(), now: { today }, calendar: { self.calendar() })
        await store.load()
        XCTAssertEqual(store.index?.surahs.count, 114)
        XCTAssertEqual(store.chapter?.surah.id, 1)
        XCTAssertEqual(store.chapter?.ayahs.count, 7)
        XCTAssertFalse(store.isLoading)
        XCTAssertNil(store.errorMessage)
        await store.openSurah(114)
        XCTAssertEqual(store.chapter?.surah.id, 114)
        XCTAssertEqual(store.chapter?.ayahs.count, 6)
        await store.openSurah(115)
        XCTAssertEqual(store.selectedSurahID, 114)
        XCTAssertEqual(store.chapter?.surah.id, 114)
    }

    func testReadingBackupRestoresUniqueProgressAndBookmarksAcrossReinstall() throws {
        let today = date(24)
        let source = AppStore(defaults: try defaults(), now: { today }, calendar: { self.calendar() })
        let first = try reference(1)
        source.markRead(first)
        source.markRead(try reference(2))
        source.markRead(try reference(3))
        source.toggleBookmark(first)
        let data = try source.readingBackupData()
        let targetStorage = try defaults()
        let restored = AppStore(defaults: targetStorage, now: { today }, calendar: { self.calendar() })
        try restored.mergeReadingBackup(data)
        try restored.mergeReadingBackup(data)
        XCTAssertEqual(restored.todayReadCount, 3)
        XCTAssertEqual(restored.bookmarks, [first])
        XCTAssertEqual(restored.lastRead, try reference(3))
        XCTAssertEqual(restored.streakSummary.current, 1)
        let relaunched = AppStore(defaults: targetStorage, now: { today }, calendar: { self.calendar() })
        XCTAssertEqual(relaunched.todayReadCount, 3)
        XCTAssertEqual(relaunched.bookmarks, [first])
    }

    func testReadingBackupMergePreservesCurrentSettingsPositionAndEarnedDays() throws {
        let today = date(24)
        let source = AppStore(defaults: try defaults(), now: { today }, calendar: { self.calendar() })
        source.setDailyGoal(1)
        source.markRead(try reference(1))
        source.toggleBookmark(try reference(1))
        let target = AppStore(defaults: try defaults(), now: { today }, calendar: { self.calendar() })
        target.setDailyGoal(9)
        target.setTajweedEnabled(false)
        let existing = try reference(255, surah: 2)
        target.markRead(existing)
        target.toggleBookmark(existing)
        try target.mergeReadingBackup(source.readingBackupData())
        XCTAssertEqual(target.lastRead, existing)
        XCTAssertEqual(target.bookmarks, [existing, try reference(1)])
        XCTAssertEqual(target.todayReadCount, 2)
        XCTAssertEqual(target.dailyGoal, 9)
        XCTAssertFalse(target.tajweedEnabled)
        XCTAssertTrue(target.dailyGoalMet, "An earned imported day must not be revoked by the current higher goal")
    }

    func testBookmarkOnlyBackupNeverCreatesReadingCredit() throws {
        let today = date(24)
        let source = AppStore(defaults: try defaults(), now: { today }, calendar: { self.calendar() })
        let bookmark = try reference(1, surah: 112)
        source.toggleBookmark(bookmark)
        source.setLastRead(bookmark)
        let restored = AppStore(defaults: try defaults(), now: { today }, calendar: { self.calendar() })
        try restored.mergeReadingBackup(source.readingBackupData())
        XCTAssertEqual(restored.todayReadCount, 0)
        XCTAssertFalse(restored.dailyGoalMet)
        XCTAssertEqual(restored.streakSummary.current, 0)
        XCTAssertEqual(restored.lastRead, bookmark)
    }

    func testInvalidReadingBackupsNeverChangeExistingData() throws {
        let today = date(24)
        let store = AppStore(defaults: try defaults(), now: { today }, calendar: { self.calendar() })
        store.markRead(try reference(2))
        store.toggleBookmark(try reference(2))
        let original = try store.readingBackupData()
        let envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? [String: Any])
        var invalidFormat = envelope
        invalidFormat["format"] = "another-app"
        var futureVersion = envelope
        futureVersion["version"] = 2
        var invalidDay = envelope
        invalidDay["readAyahsByDay"] = ["2026-02-31": [["surahID": 1, "ayahNumber": 1]]]
        var invalidReference = envelope
        invalidReference["bookmarks"] = [["surahID": 1, "ayahNumber": 99]]
        var missingIdentity = envelope
        missingIdentity.removeValue(forKey: "format")
        let invalidFiles = try [invalidFormat, futureVersion, invalidDay, invalidReference, missingIdentity]
            .map { try JSONSerialization.data(withJSONObject: $0) }
        for data in invalidFiles + [Data("not JSON".utf8), Data(repeating: 0, count: AppStore.maximumReadingBackupBytes + 1)] {
            XCTAssertThrowsError(try store.mergeReadingBackup(data))
            XCTAssertEqual(try store.readingBackupData(), original, "Validation failure must be atomic")
        }
    }
}
