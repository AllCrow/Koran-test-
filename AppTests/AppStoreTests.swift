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

    private func backup(completedOn days: ClosedRange<Int>) throws -> Data {
        var instant = date(days.lowerBound)
        let source = AppStore(defaults: try defaults(), now: { instant }, calendar: { self.calendar() })
        source.setDailyGoal(1)
        for day in days {
            instant = date(day)
            source.markRead(try reference(1))
        }
        // Export completed days after the detail retention window has passed.
        instant = date(31)
        return try source.readingBackupData()
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

    func testCivilMarksSurviveWestwardTravelAndReturnAfterRelaunch() throws {
        let storage = try defaults()
        let instant = try XCTUnwrap(calendar("Etc/UTC").date(from: DateComponents(year: 2026, month: 10, day: 24, hour: 12)))
        var zone = calendar("Pacific/Kiritimati") // October 25, 02:00.
        let store = AppStore(defaults: storage, now: { instant }, calendar: { zone })
        let first = try reference(1)
        store.setDailyGoal(2)
        store.markRead(first)
        store.markRead(try reference(2))
        XCTAssertTrue(store.dailyGoalMet)
        zone = calendar("Pacific/Honolulu") // October 24, 02:00.
        store.refreshDay()
        XCTAssertEqual(store.todayReadCount, 0, "Tomorrow's saved label must not count as today's reading")
        XCTAssertFalse(store.dailyGoalMet)
        store.markRead(first)

        let restored = AppStore(defaults: storage, now: { instant }, calendar: { zone })
        XCTAssertEqual(restored.todayReadCount, 1)
        zone = calendar("Pacific/Kiritimati")
        restored.refreshDay()
        XCTAssertEqual(restored.todayReadCount, 2, "Travel must not erase unique verse marks from the original civil label")
        XCTAssertTrue(restored.dailyGoalMet)
        XCTAssertTrue(restored.isReadToday(first))
        zone = calendar("Pacific/Honolulu")
        restored.refreshDay()
        XCTAssertEqual(restored.todayReadCount, 1)
    }

    func testClockCorrectionKeepsCurrentMarksAndExportWithinSevenDetailedDays() throws {
        var instant = date(18)
        let store = AppStore(defaults: try defaults(), now: { instant }, calendar: { self.calendar() })
        for day in 18...24 {
            instant = date(day)
            store.markRead(try reference(1))
        }
        // All seven stored labels are now in the future. A new current-day mark
        // must win over a distant one and the app's own backup must stay valid.
        instant = date(17)
        store.markRead(try reference(2))
        XCTAssertEqual(store.todayReadCount, 1)
        let data = try store.readingBackupData()
        let envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let marks = try XCTUnwrap(envelope["readAyahsByDay"] as? [String: Any])
        XCTAssertEqual(marks.count, 7)
        XCTAssertNotNil(marks["2026-10-17"])
        XCTAssertNotNil(marks["2026-10-18"])
        XCTAssertNil(marks["2026-10-24"], "The farthest future detail is pruned before the current day")
        let restored = AppStore(defaults: try defaults(), now: { instant }, calendar: { self.calendar() })
        try restored.mergeReadingBackup(data)
        XCTAssertEqual(restored.todayReadCount, 1)
        XCTAssertTrue(restored.isReadToday(try reference(2)))
    }

    func testRecentReadingDaysShowUniqueMarksAndEarnedCompletionAcrossMidnight() throws {
        var instant = date(24)
        let store = AppStore(defaults: try defaults(), now: { instant }, calendar: { self.calendar() })
        XCTAssertEqual(store.recentReadingDays.map(\.id), (18...24).map { "2026-10-\($0)" })
        XCTAssertEqual(store.recentReadingDays.filter(\.isToday).count, 1)
        store.setDailyGoal(2)
        store.markRead(try reference(1))
        store.markRead(try reference(1))
        XCTAssertEqual(store.recentReadingDays.last?.readCount, 1)
        XCTAssertEqual(store.recentReadingDays.last?.goalCompleted, false)
        store.markRead(try reference(2))
        store.setDailyGoal(50)
        XCTAssertEqual(store.recentReadingDays.last?.readCount, 2)
        XCTAssertEqual(store.recentReadingDays.last?.goalCompleted, true, "Changing today's goal never rewrites an earned completion")
        instant = date(25, hour: 4)
        store.refreshDay()
        XCTAssertEqual(store.recentReadingDays.map(\.id), (19...25).map { "2026-10-\($0)" })
        let yesterday = try XCTUnwrap(store.recentReadingDays.first { $0.id == "2026-10-24" })
        XCTAssertEqual(yesterday.readCount, 2)
        XCTAssertTrue(yesterday.goalCompleted)
        XCTAssertFalse(yesterday.isToday)
        XCTAssertEqual(store.recentReadingDays.last?.readCount, 0)
        XCTAssertEqual(store.recentReadingDays.last?.goalCompleted, false)
    }

    func testRecentHistoryKeepsImportedCompletionWithoutInventingVerseCount() throws {
        let today = date(24)
        let source = AppStore(defaults: try defaults(), now: { today }, calendar: { self.calendar() })
        source.setDailyGoal(1)
        source.markRead(try reference(1))
        var envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: source.readingBackupData()) as? [String: Any])
        envelope["readAyahsByDay"] = [String: Any]()
        let target = AppStore(defaults: try defaults(), now: { today }, calendar: { self.calendar() })
        target.setDailyGoal(50)
        try target.mergeReadingBackup(JSONSerialization.data(withJSONObject: envelope))
        XCTAssertEqual(target.recentReadingDays.last?.readCount, 0)
        XCTAssertEqual(target.recentReadingDays.last?.goalCompleted, true)
        XCTAssertTrue(target.dailyGoalMet)
    }

    func testRecentHistoryUsesStableCivilLabelsInSkippedDateTimezone() throws {
        let apia = calendar("Pacific/Apia")
        let instant = try XCTUnwrap(apia.date(from: DateComponents(year: 2011, month: 12, day: 31, hour: 12)))
        let store = AppStore(defaults: try defaults(), now: { instant }, calendar: { apia })
        XCTAssertEqual(store.recentReadingDays.map(\.id), (25...31).map { "2011-12-\($0)" })
        let utc = calendar("Etc/UTC")
        for progress in store.recentReadingDays {
            XCTAssertEqual(ReadingDay(date: progress.date, calendar: utc), progress.day)
        }
    }

    func testRepeatedReadingActionDoesNotRepublishUnchangedProgress() throws {
        let today = date(24)
        let store = AppStore(defaults: try defaults(), now: { today }, calendar: { self.calendar() })
        let first = try reference(1)
        let second = try reference(2)
        store.markRead(first)
        store.markRead(second)
        var countChanges = 0
        var positionChanges = 0
        var historyChanges = 0
        let subscriptions = [
            store.$todayReadCount.dropFirst().sink { _ in countChanges += 1 },
            store.$lastRead.dropFirst().sink { _ in positionChanges += 1 },
            store.$recentReadingDays.dropFirst().sink { _ in historyChanges += 1 }
        ]
        defer { subscriptions.forEach { $0.cancel() } }
        store.markRead(second)
        store.refreshDay()
        store.setDailyGoal(store.dailyGoal)
        XCTAssertEqual(countChanges, 0)
        XCTAssertEqual(positionChanges, 0)
        XCTAssertEqual(historyChanges, 0)
        store.markRead(first)
        XCTAssertEqual(store.lastRead, first, "An already-read verse can still become the latest explicit position")
        XCTAssertEqual(positionChanges, 1)
        XCTAssertEqual(countChanges, 0)
        XCTAssertEqual(historyChanges, 0)
    }

    func testLegacySavedReadingStateWithoutDisplayChoicesKeepsProgressAndPreferences() throws {
        let storage = try defaults()
        let today = date(24)
        let original = AppStore(defaults: storage, now: { today }, calendar: { self.calendar() })
        let first = try reference(1)
        original.setDailyGoal(1)
        original.markRead(first)
        original.toggleBookmark(first)
        original.setTajweedEnabled(false)
        original.setAppearance(.dark)
        let data = try XCTUnwrap(storage.data(forKey: "sakina.reading-state.v1"))
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        legacy.removeValue(forKey: "arabicTextSize")
        legacy.removeValue(forKey: "appearance")
        storage.set(try JSONSerialization.data(withJSONObject: legacy), forKey: "sakina.reading-state.v1")

        let restored = AppStore(defaults: storage, now: { today }, calendar: { self.calendar() })
        XCTAssertEqual(restored.arabicTextSize, .standard)
        XCTAssertEqual(restored.arabicTextSize.pointSize, 30)
        XCTAssertEqual(restored.appearance, .system)
        XCTAssertEqual(restored.bookmarks, [first])
        XCTAssertEqual(restored.lastRead, first)
        XCTAssertEqual(restored.todayReadCount, 1)
        XCTAssertEqual(restored.dailyGoal, 1)
        XCTAssertTrue(restored.dailyGoalMet)
        XCTAssertFalse(restored.tajweedEnabled)
    }

    func testUnknownSavedDisplayChoicesFallBackWithoutLosingReadingState() throws {
        let storage = try defaults()
        let today = date(24)
        let original = AppStore(defaults: storage, now: { today }, calendar: { self.calendar() })
        let verse = try reference(255, surah: 2)
        original.markRead(verse)
        original.toggleBookmark(verse)
        original.setDailyGoal(7)
        original.setTajweedEnabled(false)
        original.setArabicTextSize(.extraLarge)
        original.setAppearance(.dark)
        let data = try XCTUnwrap(storage.data(forKey: "sakina.reading-state.v1"))
        var future = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        future["arabicTextSize"] = "a-future-size"
        future["appearance"] = "a-future-appearance"
        storage.set(try JSONSerialization.data(withJSONObject: future), forKey: "sakina.reading-state.v1")

        let restored = AppStore(defaults: storage, now: { today }, calendar: { self.calendar() })
        XCTAssertEqual(restored.arabicTextSize, .standard)
        XCTAssertEqual(restored.appearance, .system)
        XCTAssertEqual(restored.bookmarks, [verse])
        XCTAssertEqual(restored.lastRead, verse)
        XCTAssertEqual(restored.todayReadCount, 1)
        XCTAssertEqual(restored.dailyGoal, 7)
        XCTAssertFalse(restored.tajweedEnabled)
    }

    func testTextSizeSurvivesRelaunchAndReadingImportPreservesCurrentChoice() throws {
        let today = date(24)
        let source = AppStore(defaults: try defaults(), now: { today }, calendar: { self.calendar() })
        let verse = try reference(1, surah: 112)
        source.markRead(verse)
        source.toggleBookmark(verse)
        source.setArabicTextSize(.extraLarge)
        let backup = try source.readingBackupData()
        let envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: backup) as? [String: Any])
        XCTAssertNil(envelope["arabicTextSize"], "A reading backup must remain independent of display preferences")
        let storage = try defaults()
        let target = AppStore(defaults: storage, now: { today }, calendar: { self.calendar() })
        for choice in AppStore.ArabicTextSize.allCases {
            target.setArabicTextSize(choice)
            let restored = AppStore(defaults: storage, now: { today }, calendar: { self.calendar() })
            XCTAssertEqual(restored.arabicTextSize, choice)
            XCTAssertEqual(restored.todayReadCount, 0, "Changing typography must not award reading credit")
        }
        target.setArabicTextSize(.small)
        try target.mergeReadingBackup(backup)
        XCTAssertEqual(target.arabicTextSize, .small)
        XCTAssertEqual(target.bookmarks, [verse])
        XCTAssertEqual(target.todayReadCount, 1)
        let relaunched = AppStore(defaults: storage, now: { today }, calendar: { self.calendar() })
        XCTAssertEqual(relaunched.arabicTextSize, .small)
        XCTAssertEqual(relaunched.bookmarks, [verse])
    }

    func testRepeatedDisplayChoicesDoNotRepublishOrChangeReadingBackup() throws {
        let today = date(24)
        let store = AppStore(defaults: try defaults(), now: { today }, calendar: { self.calendar() })
        store.markRead(try reference(1))
        let readingData = try store.readingBackupData()
        var changes = 0
        var appearanceChanges = 0
        let subscription = store.$arabicTextSize.dropFirst().sink { _ in changes += 1 }
        let appearanceSubscription = store.$appearance.dropFirst().sink { _ in appearanceChanges += 1 }
        defer { subscription.cancel(); appearanceSubscription.cancel() }
        store.setArabicTextSize(.standard)
        XCTAssertEqual(changes, 0)
        store.setArabicTextSize(.large)
        XCTAssertEqual(changes, 1)
        store.setArabicTextSize(.large)
        XCTAssertEqual(changes, 1)
        store.setAppearance(.system)
        XCTAssertEqual(appearanceChanges, 0)
        store.setAppearance(.dark)
        XCTAssertEqual(appearanceChanges, 1)
        store.setAppearance(.dark)
        XCTAssertEqual(appearanceChanges, 1)
        XCTAssertEqual(try store.readingBackupData(), readingData)
    }

    func testAppearanceSurvivesRelaunchAndReadingImportPreservesCurrentChoice() throws {
        let today = date(24)
        let source = AppStore(defaults: try defaults(), now: { today }, calendar: { self.calendar() })
        let verse = try reference(1, surah: 112)
        source.markRead(verse)
        source.toggleBookmark(verse)
        source.setAppearance(.dark)
        let backup = try source.readingBackupData()
        let envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: backup) as? [String: Any])
        XCTAssertNil(envelope["appearance"], "A reading backup must not replace the destination's appearance")
        let storage = try defaults()
        let target = AppStore(defaults: storage, now: { today }, calendar: { self.calendar() })
        for choice in AppStore.Appearance.allCases {
            target.setAppearance(choice)
            let restored = AppStore(defaults: storage, now: { today }, calendar: { self.calendar() })
            XCTAssertEqual(restored.appearance, choice)
            XCTAssertEqual(restored.todayReadCount, 0, "Changing appearance must not award reading credit")
        }
        target.setAppearance(.light)
        try target.mergeReadingBackup(backup)
        XCTAssertEqual(target.appearance, .light)
        XCTAssertEqual(target.bookmarks, [verse])
        XCTAssertEqual(target.todayReadCount, 1)
        let relaunched = AppStore(defaults: storage, now: { today }, calendar: { self.calendar() })
        XCTAssertEqual(relaunched.appearance, .light)
        XCTAssertEqual(relaunched.bookmarks, [verse])
    }

    func testPracticeQueueKeepsInsertionOrderAndPersistsWithoutReadingCredit() throws {
        let storage = try defaults()
        let today = date(24)
        let store = AppStore(defaults: storage, now: { today }, calendar: { self.calendar() })
        let first = try reference(255, surah: 2)
        let second = try reference(2, surah: 112)
        XCTAssertTrue(store.togglePracticeQueue(first))
        XCTAssertTrue(store.togglePracticeQueue(second))
        XCTAssertEqual(store.practiceQueue, [first, second])
        XCTAssertTrue(store.isQueuedForPractice(first))
        XCTAssertTrue(store.togglePracticeQueue(first))
        XCTAssertFalse(store.isQueuedForPractice(first))
        XCTAssertTrue(store.togglePracticeQueue(first))
        XCTAssertEqual(store.practiceQueue, [second, first])
        XCTAssertEqual(store.todayReadCount, 0)
        XCTAssertNil(store.lastRead)
        XCTAssertTrue(store.bookmarks.isEmpty)
        XCTAssertTrue(store.streak.completionDays.isEmpty)

        let restored = AppStore(defaults: storage, now: { today }, calendar: { self.calendar() })
        XCTAssertEqual(restored.practiceQueue, [second, first])
        XCTAssertEqual(restored.todayReadCount, 0)
        XCTAssertNil(restored.lastRead)
        var publications = 0
        let subscription = restored.objectWillChange.sink { _ in publications += 1 }
        defer { subscription.cancel() }
        let original = storage.data(forKey: "sakina.reading-state.v1")
        XCTAssertTrue(restored.removeFromPracticeQueue(try reference(1)))
        XCTAssertEqual(publications, 0, "Removing an absent verse is a no-op")
        XCTAssertEqual(storage.data(forKey: "sakina.reading-state.v1"), original)
    }

    func testMalformedOptionalSavedQueueNeverDiscardsExistingReadingState() throws {
        let storage = try defaults()
        let today = date(24)
        let store = AppStore(defaults: storage, now: { today }, calendar: { self.calendar() })
        let verse = try reference(3)
        store.setDailyGoal(1)
        store.markRead(verse)
        store.toggleBookmark(verse)
        store.setArabicTextSize(.large)
        store.setAppearance(.dark)
        let original = try XCTUnwrap(storage.data(forKey: "sakina.reading-state.v1"))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? [String: Any])
        let malformed: [Any] = ["not-an-array", ["unexpected": true],
                                [["surahID": 115, "ayahNumber": 1]], NSNull()]
        for invalid in malformed {
            var saved = object
            saved["practiceQueue"] = invalid
            storage.set(try JSONSerialization.data(withJSONObject: saved), forKey: "sakina.reading-state.v1")
            let restored = AppStore(defaults: storage, now: { today }, calendar: { self.calendar() })
            XCTAssertTrue(restored.practiceQueue.isEmpty)
            XCTAssertEqual(restored.lastRead, verse)
            XCTAssertEqual(restored.bookmarks, [verse])
            XCTAssertEqual(restored.todayReadCount, 1)
            XCTAssertEqual(restored.streakSummary.current, 1)
            XCTAssertEqual(restored.arabicTextSize, .large)
            XCTAssertEqual(restored.appearance, .dark)
        }
        var legacy = object
        legacy.removeValue(forKey: "practiceQueue")
        storage.set(try JSONSerialization.data(withJSONObject: legacy), forKey: "sakina.reading-state.v1")
        let legacyRestored = AppStore(defaults: storage, now: { today }, calendar: { self.calendar() })
        XCTAssertTrue(legacyRestored.practiceQueue.isEmpty)
        XCTAssertEqual(legacyRestored.bookmarks, [verse])
        XCTAssertTrue(legacyRestored.dailyGoalMet)
    }

    func testSavedQueueDeduplicatesAndBoundsOnlyItsOwnOptionalField() throws {
        let storage = try defaults()
        let today = date(24)
        let store = AppStore(defaults: storage, now: { today }, calendar: { self.calendar() })
        let position = try reference(4)
        store.setLastRead(position)
        let original = try XCTUnwrap(storage.data(forKey: "sakina.reading-state.v1"))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? [String: Any])
        let references = try (1...201).map { try reference($0, surah: 2) }
        let encoded = try JSONEncoder().encode([references[0]] + references)
        object["practiceQueue"] = try JSONSerialization.jsonObject(with: encoded)
        storage.set(try JSONSerialization.data(withJSONObject: object), forKey: "sakina.reading-state.v1")
        let restored = AppStore(defaults: storage, now: { today }, calendar: { self.calendar() })
        XCTAssertEqual(restored.practiceQueue, Array(references.prefix(200)))
        XCTAssertEqual(restored.lastRead, position)
        XCTAssertEqual(restored.todayReadCount, 0)
    }

    func testPracticeQueueCapacityRejectsWithoutPublicationOrSavedMutation() throws {
        let storage = try defaults()
        let today = date(24)
        let store = AppStore(defaults: storage, now: { today }, calendar: { self.calendar() })
        let queue = try (1...200).map { try reference($0, surah: 2) }
        var envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: store.readingBackupData()) as? [String: Any])
        envelope["practiceQueue"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(queue))
        try store.mergeReadingBackup(JSONSerialization.data(withJSONObject: envelope))
        let original = storage.data(forKey: "sakina.reading-state.v1")
        var publications = 0
        let subscription = store.objectWillChange.sink { _ in publications += 1 }
        defer { subscription.cancel() }
        XCTAssertFalse(store.togglePracticeQueue(try reference(201, surah: 2)))
        XCTAssertEqual(publications, 0)
        XCTAssertEqual(store.practiceQueue, queue)
        XCTAssertEqual(storage.data(forKey: "sakina.reading-state.v1"), original)
        XCTAssertEqual(store.todayReadCount, 0)
        XCTAssertNil(store.lastRead)
        XCTAssertTrue(store.removeFromPracticeQueue(queue[0]))
        XCTAssertTrue(store.togglePracticeQueue(try reference(201, surah: 2)))
        XCTAssertEqual(store.practiceQueue.count, 200)
        XCTAssertEqual(store.practiceQueue.last, try reference(201, surah: 2))
    }

    func testPracticeQueueBackupMergeIsOrderedAdditiveAndLegacyImportKeepsQueue() throws {
        let today = date(24)
        let first = try reference(1)
        let second = try reference(2)
        let third = try reference(3)
        let source = AppStore(defaults: try defaults(), now: { today }, calendar: { self.calendar() })
        XCTAssertTrue(source.togglePracticeQueue(first))
        XCTAssertTrue(source.togglePracticeQueue(second))
        let data = try source.readingBackupData()
        let storage = try defaults()
        let target = AppStore(defaults: storage, now: { today }, calendar: { self.calendar() })
        target.setLastRead(third)
        target.setAppearance(.dark)
        XCTAssertTrue(target.togglePracticeQueue(second))
        XCTAssertTrue(target.togglePracticeQueue(third))
        try target.mergeReadingBackup(data)
        try target.mergeReadingBackup(data)
        XCTAssertEqual(target.practiceQueue, [second, third, first])
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        legacy.removeValue(forKey: "practiceQueue")
        try target.mergeReadingBackup(JSONSerialization.data(withJSONObject: legacy))
        XCTAssertEqual(target.practiceQueue, [second, third, first])
        XCTAssertEqual(target.lastRead, third)
        XCTAssertEqual(target.appearance, .dark)
        XCTAssertEqual(target.todayReadCount, 0)
        let restored = AppStore(defaults: storage, now: { today }, calendar: { self.calendar() })
        XCTAssertEqual(restored.practiceQueue, [second, third, first])
        XCTAssertEqual(restored.lastRead, third)
    }

    func testPracticeQueueUnionOverflowRejectsEntireReadingImportBeforeMutation() throws {
        let today = date(24)
        let storage = try defaults()
        let target = AppStore(defaults: storage, now: { today }, calendar: { self.calendar() })
        target.setLastRead(try reference(1))
        let queue = try (1...200).map { try reference($0, surah: 2) }
        var full = try XCTUnwrap(JSONSerialization.jsonObject(with: target.readingBackupData()) as? [String: Any])
        full["practiceQueue"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(queue))
        try target.mergeReadingBackup(JSONSerialization.data(withJSONObject: full))
        let source = AppStore(defaults: try defaults(), now: { today }, calendar: { self.calendar() })
        let extra = try reference(201, surah: 2)
        source.setDailyGoal(1)
        source.markRead(extra)
        source.toggleBookmark(extra)
        XCTAssertTrue(source.togglePracticeQueue(extra))
        let incoming = try source.readingBackupData()
        let beforeSaved = storage.data(forKey: "sakina.reading-state.v1")
        let beforeExport = try target.readingBackupData()
        var publications = 0
        let subscription = target.objectWillChange.sink { _ in publications += 1 }
        defer { subscription.cancel() }
        XCTAssertThrowsError(try target.mergeReadingBackup(incoming)) { error in
            guard case AppStore.ReadingBackupError.practiceQueueFull = error else {
                return XCTFail("Expected queue-union admission error, received \(error)")
            }
        }
        XCTAssertEqual(publications, 0)
        XCTAssertEqual(storage.data(forKey: "sakina.reading-state.v1"), beforeSaved)
        XCTAssertEqual(try target.readingBackupData(), beforeExport)
        XCTAssertEqual(target.practiceQueue, queue)
        XCTAssertTrue(target.bookmarks.isEmpty)
        XCTAssertEqual(target.todayReadCount, 0)
        XCTAssertTrue(target.streak.completionDays.isEmpty)
    }

    func testInvalidBackupQueueNeverChangesExistingReadingData() throws {
        let today = date(24)
        let storage = try defaults()
        let target = AppStore(defaults: storage, now: { today }, calendar: { self.calendar() })
        let first = try reference(1)
        target.markRead(first)
        XCTAssertTrue(target.togglePracticeQueue(first))
        let exported = try target.readingBackupData()
        let original = storage.data(forKey: "sakina.reading-state.v1")
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: exported) as? [String: Any])
        let tooMany = try (1...201).map { try reference($0, surah: 2) }
        let invalid: [Any] = ["not-an-array", [["surahID": 115, "ayahNumber": 1]],
                              [["surahID": 1, "ayahNumber": 1], ["surahID": 1, "ayahNumber": 1]],
                              try JSONSerialization.jsonObject(with: JSONEncoder().encode(tooMany))]
        var publications = 0
        let subscription = target.objectWillChange.sink { _ in publications += 1 }
        defer { subscription.cancel() }
        for malformed in invalid {
            var incoming = object
            incoming["practiceQueue"] = malformed
            XCTAssertThrowsError(try target.mergeReadingBackup(JSONSerialization.data(withJSONObject: incoming)))
            XCTAssertEqual(storage.data(forKey: "sakina.reading-state.v1"), original)
            XCTAssertEqual(target.practiceQueue, [first])
            XCTAssertEqual(target.todayReadCount, 1)
        }
        XCTAssertEqual(publications, 0)
    }

    func testPracticeQueueByteBudgetIsCheckedBeforePublishingItsEdit() throws {
        let today = date(24)
        let first = try reference(1)
        let probeStorage = try defaults()
        let probe = AppStore(defaults: probeStorage, now: { today }, calendar: { self.calendar() })
        probe.setLastRead(first)
        XCTAssertTrue(probe.togglePracticeQueue(first))
        let queuedState = try XCTUnwrap(probeStorage.data(forKey: "sakina.reading-state.v1"))
        let queuedExport = try probe.readingBackupData()
        let exactBudget = max(queuedState.count, queuedExport.count)
        let storage = try defaults()
        let target = AppStore(defaults: storage, now: { today }, calendar: { self.calendar() },
                              readingDataByteLimit: exactBudget - 1)
        target.setLastRead(first)
        let before = try XCTUnwrap(storage.data(forKey: "sakina.reading-state.v1"))
        var publications = 0
        let subscription = target.objectWillChange.sink { _ in publications += 1 }
        defer { subscription.cancel() }
        XCTAssertFalse(target.togglePracticeQueue(first))
        XCTAssertEqual(publications, 0)
        XCTAssertTrue(target.practiceQueue.isEmpty)
        XCTAssertEqual(storage.data(forKey: "sakina.reading-state.v1"), before)
        let acceptedStorage = try defaults()
        let accepted = AppStore(defaults: acceptedStorage, now: { today }, calendar: { self.calendar() },
                                readingDataByteLimit: exactBudget)
        accepted.setLastRead(first)
        XCTAssertTrue(accepted.togglePracticeQueue(first))
        let restored = AppStore(defaults: acceptedStorage, now: { today }, calendar: { self.calendar() },
                                readingDataByteLimit: exactBudget)
        XCTAssertEqual(restored.practiceQueue, [first])
    }

    func testCombinedReadingBackupLimitRejectsWithoutPublishingOrReplacingSavedState() throws {
        let first = try backup(completedOn: 1...12)
        let second = try backup(completedOn: 13...24)
        let budget = max(first.count, second.count) + 256
        let storage = try defaults()
        let today = date(31)
        let target = AppStore(defaults: storage, now: { today }, calendar: { self.calendar() },
                              readingDataByteLimit: budget)
        let existing = try reference(255, surah: 2)
        target.setLastRead(existing)
        target.toggleBookmark(existing)
        target.setAppearance(.dark)
        target.setArabicTextSize(.large)
        try target.mergeReadingBackup(first)
        let originalSaved = try XCTUnwrap(storage.data(forKey: "sakina.reading-state.v1"))
        let originalExport = try target.readingBackupData()
        let originalSummary = target.streakSummary
        let originalHistory = target.recentReadingDays
        XCTAssertLessThan(first.count, budget)
        XCTAssertLessThan(second.count, budget, "The incoming file itself fits; the union must be checked")
        XCTAssertLessThanOrEqual(originalSaved.count, budget)
        var publications = 0
        let subscription = target.objectWillChange.sink { _ in publications += 1 }
        defer { subscription.cancel() }

        XCTAssertThrowsError(try target.mergeReadingBackup(second)) { error in
            guard case AppStore.ReadingBackupError.combinedDataTooLarge = error else {
                return XCTFail("Expected combined-data limit, received \(error)")
            }
        }
        XCTAssertEqual(publications, 0, "Rejected imports must not publish partially merged state")
        XCTAssertEqual(storage.data(forKey: "sakina.reading-state.v1"), originalSaved)
        XCTAssertEqual(try target.readingBackupData(), originalExport)
        XCTAssertEqual(target.streakSummary, originalSummary)
        XCTAssertEqual(target.recentReadingDays, originalHistory)
        XCTAssertEqual(target.lastRead, existing)
        XCTAssertEqual(target.bookmarks, [existing])
        XCTAssertEqual(target.appearance, .dark)
        XCTAssertEqual(target.arabicTextSize, .large)
        let relaunched = AppStore(defaults: storage, now: { today }, calendar: { self.calendar() },
                                  readingDataByteLimit: budget)
        XCTAssertEqual(relaunched.streak.completionDays.count, 12)
        XCTAssertEqual(relaunched.bookmarks, [existing])
        XCTAssertEqual(relaunched.lastRead, existing)
        XCTAssertEqual(relaunched.appearance, .dark)
        XCTAssertEqual(relaunched.arabicTextSize, .large)
    }

    func testReadingBackupAtExactSerializedStateLimitSurvivesRelaunch() throws {
        let backup = try backup(completedOn: 1...12)
        let today = date(31)
        let probeStorage = try defaults()
        let probe = AppStore(defaults: probeStorage, now: { today }, calendar: { self.calendar() })
        probe.setDailyGoal(9)
        probe.setAppearance(.dark)
        probe.setArabicTextSize(.extraLarge)
        try probe.mergeReadingBackup(backup)
        let exactBudget = try XCTUnwrap(probeStorage.data(forKey: "sakina.reading-state.v1")).count
        XCTAssertLessThan(backup.count, exactBudget)

        let storage = try defaults()
        let target = AppStore(defaults: storage, now: { today }, calendar: { self.calendar() },
                              readingDataByteLimit: exactBudget)
        target.setDailyGoal(9)
        target.setAppearance(.dark)
        target.setArabicTextSize(.extraLarge)
        try target.mergeReadingBackup(backup)
        XCTAssertEqual(storage.data(forKey: "sakina.reading-state.v1")?.count, exactBudget)
        XCTAssertLessThanOrEqual(try target.readingBackupData().count, exactBudget)
        let relaunched = AppStore(defaults: storage, now: { today }, calendar: { self.calendar() },
                                  readingDataByteLimit: exactBudget)
        XCTAssertEqual(relaunched.streak.completionDays.count, 12)
        XCTAssertEqual(relaunched.streakSummary.best, 12)
        XCTAssertEqual(relaunched.dailyGoal, 9)
        XCTAssertEqual(relaunched.lastRead, try reference(1))
        XCTAssertEqual(relaunched.appearance, .dark)
        XCTAssertEqual(relaunched.arabicTextSize, .extraLarge)

        let smallerStorage = try defaults()
        let smaller = AppStore(defaults: smallerStorage, now: { today }, calendar: { self.calendar() },
                               readingDataByteLimit: exactBudget - 1)
        smaller.setDailyGoal(9)
        smaller.setAppearance(.dark)
        smaller.setArabicTextSize(.extraLarge)
        let before = smallerStorage.data(forKey: "sakina.reading-state.v1")
        XCTAssertThrowsError(try smaller.mergeReadingBackup(backup)) { error in
            guard case AppStore.ReadingBackupError.combinedDataTooLarge = error else {
                return XCTFail("Expected one-byte-over-bound rejection, received \(error)")
            }
        }
        XCTAssertEqual(smallerStorage.data(forKey: "sakina.reading-state.v1"), before)
        XCTAssertTrue(smaller.streak.completionDays.isEmpty)
        XCTAssertNil(smaller.lastRead)
    }
}
