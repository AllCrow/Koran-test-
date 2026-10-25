import Combine
import Foundation
import QuranCore
import QuranData
import UIKit

@MainActor
final class AppStore: ObservableObject {
    static let maximumReadingBackupBytes = 4 * 1_024 * 1_024

    enum ReadingBackupError: LocalizedError {
        case tooLarge, invalidFile, unsupportedVersion, cannotExport

        var errorDescription: String? {
            switch self {
            case .tooLarge:
                return "Filen är för stor för en läskopia. Välj en kopia som har skapats av Sakina."
            case .invalidFile:
                return "Filen är ingen giltig läskopia från Sakina. Dina befintliga läsdata har inte ändrats."
            case .unsupportedVersion:
                return "Kopian använder en annan version. Uppdatera appen innan du försöker igen."
            case .cannotExport:
                return "Läskopian kunde inte skapas. Försök igen."
            }
        }
    }
    @Published private(set) var index: ContentIndex?
    @Published private(set) var chapter: QuranChapter?
    @Published private(set) var selectedSurahID: Int = 1
    @Published private(set) var lastRead: AyahReference?
    @Published private(set) var bookmarks: Set<AyahReference> = []
    @Published private(set) var tajweedEnabled = true
    @Published private(set) var dailyGoal = 3
    @Published private(set) var streak = StreakTracker()
    @Published private(set) var streakSummary = StreakSummary(current: 0, best: 0, completedToday: false)
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var todayReadCount = 0
    @Published private(set) var dailyGoalMet = false

    private struct SavedState: Codable {
        let version: Int
        let selectedSurahID: Int
        let lastRead: AyahReference?
        let bookmarks: Set<AyahReference>
        let tajweedEnabled: Bool
        let dailyGoal: Int
        let streak: StreakTracker
        let readAyahsByDay: [String: Set<AyahReference>]
    }

    /// Independent of the signing bundle ID so personal reinstalls can recover
    /// reading data. No recordings, audio files or account information is exported.
    private struct ReadingBackup: Codable {
        let format: String
        let version: Int
        let exportedAt: Date
        let bookmarks: Set<AyahReference>
        let lastRead: AyahReference?
        let completedDays: [ReadingDay]
        let readAyahsByDay: [String: Set<AyahReference>]
    }

    private let repository: QuranRepository
    private let defaults: UserDefaults
    private let now: () -> Date
    private let calendar: () -> Calendar
    private let storageKey = "sakina.reading-state.v1"
    private var readAyahsByDay: [String: Set<AyahReference>] = [:]
    private var currentDay: ReadingDay
    private var summaryDate: Date
    private var summarizedDay: ReadingDay?
    private var summarizedHistory: StreakTracker?
    private var chapterRequestID = UUID()
    private var dayChangeSubscription: AnyCancellable?

    init(repository: QuranRepository = QuranRepository(), defaults: UserDefaults = .standard,
         now: @escaping () -> Date = Date.init, calendar: @escaping () -> Calendar = { .current }) {
        self.repository = repository
        self.defaults = defaults
        self.now = now
        self.calendar = calendar
        summaryDate = now()
        currentDay = ReadingDay(date: summaryDate, calendar: calendar())
        if let data = defaults.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(SavedState.self, from: data), saved.version == 1 {
            selectedSurahID = (1...114).contains(saved.selectedSurahID) ? saved.selectedSurahID : 1
            lastRead = saved.lastRead
            bookmarks = saved.bookmarks
            tajweedEnabled = saved.tajweedEnabled
            dailyGoal = min(50, max(1, saved.dailyGoal))
            streak = saved.streak
            readAyahsByDay = saved.readAyahsByDay
        }
        refreshDay()
        dayChangeSubscription = NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
            .merge(with: NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange),
                   NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.refreshDay() }
            }
    }

    func load() async {
        if index == nil {
            isLoading = true
            errorMessage = nil
            do {
                index = try await repository.loadIndex()
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                return
            }
        }
        await openSurah(selectedSurahID)
    }

    /// A slow earlier request must never replace the chapter selected afterward.
    func openSurah(_ id: Int) async {
        guard (1...AyahReference.ayahCounts.count).contains(id) else { return }
        let requestID = UUID()
        chapterRequestID = requestID
        if selectedSurahID != id {
            selectedSurahID = id
            persist()
        }
        if chapter?.surah.id == id {
            isLoading = false
            errorMessage = nil
            return
        }
        chapter = nil
        isLoading = true
        errorMessage = nil
        do {
            let loadedChapter = try await repository.loadChapter(id: id)
            guard chapterRequestID == requestID else { return }
            chapter = loadedChapter
            isLoading = false
        } catch {
            guard chapterRequestID == requestID else { return }
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    func setLastRead(_ reference: AyahReference) {
        guard lastRead != reference else { return }
        lastRead = reference
        persist()
    }

    func toggleBookmark(_ reference: AyahReference) {
        if bookmarks.contains(reference) {
            bookmarks.remove(reference)
        } else {
            bookmarks.insert(reference)
        }
        persist()
    }

    /// Only an explicit reading action counts; opening a screen does not.
    func markRead(_ reference: AyahReference) {
        refreshDay()
        readAyahsByDay[currentDay.id, default: []].insert(reference)
        lastRead = reference
        updateDailyProgress()
        persist()
    }

    func isReadToday(_ reference: AyahReference) -> Bool {
        readAyahsByDay[currentDay.id]?.contains(reference) ?? false
    }

    func setDailyGoal(_ goal: Int) {
        dailyGoal = min(50, max(1, goal))
        refreshDay()
        updateDailyProgress()
        persist()
    }

    func setTajweedEnabled(_ enabled: Bool) {
        guard tajweedEnabled != enabled else { return }
        tajweedEnabled = enabled
        persist()
    }

    func readingBackupData() throws -> Data {
        refreshDay()
        let backup = ReadingBackup(
            format: "sakina-reading-backup", version: 1, exportedAt: now(),
            bookmarks: bookmarks, lastRead: lastRead,
            completedDays: streak.completionDays, readAyahsByDay: readAyahsByDay
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data: Data
        do { data = try encoder.encode(backup) }
        catch { throw ReadingBackupError.cannotExport }
        guard data.count <= Self.maximumReadingBackupBytes else { throw ReadingBackupError.tooLarge }
        return data
    }

    /// Validate everything before changing any state. Import is additive and
    /// idempotent; current preferences and an existing reading position remain.
    func mergeReadingBackup(_ data: Data) throws {
        guard data.count <= Self.maximumReadingBackupBytes else { throw ReadingBackupError.tooLarge }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup: ReadingBackup
        do { backup = try decoder.decode(ReadingBackup.self, from: data) }
        catch { throw ReadingBackupError.invalidFile }
        guard backup.format == "sakina-reading-backup" else { throw ReadingBackupError.invalidFile }
        guard backup.version == 1 else { throw ReadingBackupError.unsupportedVersion }
        guard backup.exportedAt.timeIntervalSinceReferenceDate.isFinite,
              backup.readAyahsByDay.count <= 7,
              backup.readAyahsByDay.keys.allSatisfy(Self.isValidReadingDayKey) else {
            throw ReadingBackupError.invalidFile
        }

        var mergedMarks = readAyahsByDay
        for (day, references) in backup.readAyahsByDay {
            mergedMarks[day, default: []].formUnion(references)
        }
        let mergedStreak = StreakTracker(completionDays: streak.completionDays + backup.completedDays)
        bookmarks.formUnion(backup.bookmarks)
        if lastRead == nil { lastRead = backup.lastRead }
        readAyahsByDay = mergedMarks
        streak = mergedStreak
        refreshDay()
        updateDailyProgress()
        persist()
    }

    private static func isValidReadingDayKey(_ key: String) -> Bool {
        let pieces = key.split(separator: "-", omittingEmptySubsequences: false)
        guard pieces.count == 3, let year = Int(pieces[0]),
              let month = Int(pieces[1]), let day = Int(pieces[2]),
              let readingDay = ReadingDay(year: year, month: month, day: day) else { return false }
        return readingDay.id == key
    }

    /// Call when the app becomes active as well as at local midnight.
    func refreshDay() {
        summaryDate = now()
        let currentCalendar = calendar()
        currentDay = ReadingDay(date: summaryDate, calendar: currentCalendar)
        // Detailed verse marks are needed only for the current week. Completed
        // civil days remain in StreakTracker, so pruning never erases a streak.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = currentCalendar.timeZone
        let retainedDays = Set((0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: summaryDate)
                .map { ReadingDay(date: $0, calendar: calendar).id }
        })
        let previousCount = readAyahsByDay.count
        readAyahsByDay = readAyahsByDay.filter { retainedDays.contains($0.key) }
        if readAyahsByDay.count != previousCount { persist() }
        todayReadCount = readAyahsByDay[currentDay.id]?.count ?? 0
        dailyGoalMet = streak.isCompleted(on: summaryDate, calendar: currentCalendar)
        updateStreakSummary()
    }

    private func updateDailyProgress() {
        todayReadCount = readAyahsByDay[currentDay.id]?.count ?? 0
        if todayReadCount >= dailyGoal {
            streak.complete(on: summaryDate, calendar: calendar())
        }
        // Changing a goal never removes a reading day already completed.
        dailyGoalMet = streak.isCompleted(on: summaryDate, calendar: calendar())
        updateStreakSummary()
    }

    private func updateStreakSummary() {
        // Calendar arithmetic over years of history belongs to a day/history
        // change, not every Home/Settings render or playback state update.
        guard summarizedDay != currentDay || summarizedHistory != streak else { return }
        summarizedDay = currentDay
        summarizedHistory = streak
        let value = streak.summary(asOf: summaryDate, calendar: calendar())
        if value != streakSummary { streakSummary = value }
    }

    private func persist() {
        let state = SavedState(
            version: 1,
            selectedSurahID: selectedSurahID,
            lastRead: lastRead,
            bookmarks: bookmarks,
            tajweedEnabled: tajweedEnabled,
            dailyGoal: dailyGoal,
            streak: streak,
            readAyahsByDay: readAyahsByDay
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
