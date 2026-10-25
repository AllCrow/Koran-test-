import Combine
import Foundation
import QuranCore
import QuranData
import UIKit

@MainActor
final class AppStore: ObservableObject {
    nonisolated static let maximumReadingBackupBytes = 4 * 1_024 * 1_024
    typealias ChapterLoader = @MainActor @Sendable (Int) async throws -> QuranChapter
    typealias IndexLoader = @MainActor @Sendable () async throws -> ContentIndex

    enum ArabicTextSize: String, CaseIterable, Identifiable {
        case small, standard, large, extraLarge

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .small: return "Liten"
            case .standard: return "Standard"
            case .large: return "Stor"
            case .extraLarge: return "Mycket stor"
            }
        }

        var pointSize: Double {
            switch self {
            case .small: return 26
            case .standard: return 30
            case .large: return 36
            case .extraLarge: return 42
            }
        }
    }

    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .system: return "Följ iPhone"
            case .light: return "Ljust"
            case .dark: return "Mörkt"
            }
        }
    }

    struct ReadingDayProgress: Equatable, Identifiable {
        let day: ReadingDay
        /// Noon in UTC represents a civil label, not a completion instant.
        /// Format in UTC so travel cannot move its weekday or date label.
        let date: Date
        let readCount: Int
        let goalCompleted: Bool
        let isToday: Bool
        var id: String { day.id }
    }

    enum ReadingBackupError: LocalizedError {
        case tooLarge, combinedDataTooLarge, invalidFile, unsupportedVersion, cannotExport

        var errorDescription: String? {
            switch self {
            case .tooLarge:
                return "Filen är för stor för en läskopia. Välj en kopia som har skapats av Sakina."
            case .combinedDataTooLarge:
                return "Den sammanlagda läsdatan blir för stor. Dina befintliga läsdata har inte ändrats."
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
    @Published private(set) var arabicTextSize: ArabicTextSize = .standard
    @Published private(set) var appearance: Appearance = .system
    @Published private(set) var dailyGoal = 3
    @Published private(set) var streak = StreakTracker()
    @Published private(set) var streakSummary = StreakSummary(current: 0, best: 0, completedToday: false)
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var todayReadCount = 0
    @Published private(set) var dailyGoalMet = false
    @Published private(set) var recentReadingDays: [ReadingDayProgress] = []

    private struct SavedState: Codable {
        let version: Int
        let selectedSurahID: Int
        let lastRead: AyahReference?
        let bookmarks: Set<AyahReference>
        let tajweedEnabled: Bool
        /// Optional so earlier v1 reading states continue to decode unchanged.
        /// A future unknown choice falls back without discarding reading data.
        let arabicTextSize: String?
        let appearance: String?
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
    private let chapterLoader: ChapterLoader
    private let indexLoader: IndexLoader
    private let defaults: UserDefaults
    private let now: () -> Date
    private let calendar: () -> Calendar
    private let readingDataByteLimit: Int
    private let storageKey = "sakina.reading-state.v1"
    private var readAyahsByDay: [String: Set<AyahReference>] = [:]
    private var currentDay: ReadingDay
    private var summaryDate: Date
    private var summarizedDay: ReadingDay?
    private var summarizedHistory: StreakTracker?
    private var completedDayLabels: Set<ReadingDay> = []
    private var chapterRequestID = UUID()
    private var dayChangeSubscription: AnyCancellable?

    init(repository: QuranRepository = QuranRepository(), defaults: UserDefaults = .standard,
         now: @escaping () -> Date = Date.init, calendar: @escaping () -> Calendar = { .current },
         readingDataByteLimit: Int = AppStore.maximumReadingBackupBytes,
         chapterLoader: ChapterLoader? = nil, indexLoader: IndexLoader? = nil) {
        self.repository = repository
        self.chapterLoader = chapterLoader ?? { id in try await repository.loadChapter(id: id) }
        self.indexLoader = indexLoader ?? { try await repository.loadIndex() }
        self.defaults = defaults
        self.now = now
        self.calendar = calendar
        self.readingDataByteLimit = min(Self.maximumReadingBackupBytes, max(1, readingDataByteLimit))
        summaryDate = now()
        currentDay = ReadingDay(date: summaryDate, calendar: calendar())
        if let data = defaults.data(forKey: storageKey), data.count <= self.readingDataByteLimit,
           let saved = try? JSONDecoder().decode(SavedState.self, from: data), saved.version == 1 {
            selectedSurahID = (1...114).contains(saved.selectedSurahID) ? saved.selectedSurahID : 1
            lastRead = saved.lastRead
            bookmarks = saved.bookmarks
            tajweedEnabled = saved.tajweedEnabled
            arabicTextSize = saved.arabicTextSize.flatMap(ArabicTextSize.init(rawValue:)) ?? .standard
            appearance = saved.appearance.flatMap(Appearance.init(rawValue:)) ?? .system
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
        guard !Task.isCancelled else { return }
        if index == nil {
            let requestID = UUID()
            chapterRequestID = requestID
            isLoading = true
            let loaded = await withTaskCancellationHandler {
                do {
                    let loadedIndex = try await indexLoader()
                    guard !Task.isCancelled else {
                        cancelChapterRequest(requestID)
                        return false
                    }
                    // The immutable catalogue remains useful even when a
                    // newer explicit chapter request supersedes cold start.
                    // Publish it without settling that newer request's state.
                    if index == nil { index = loadedIndex }
                    guard chapterRequestID == requestID else { return false }
                    return true
                } catch {
                    guard chapterRequestID == requestID else { return false }
                    guard !Task.isCancelled, !(error is CancellationError) else {
                        cancelChapterRequest(requestID)
                        return false
                    }
                    isLoading = false
                    errorMessage = error.localizedDescription
                    return false
                }
            } onCancel: { [weak self] in
                Task { @MainActor [weak self] in self?.cancelChapterRequest(requestID) }
            }
            guard loaded, chapterRequestID == requestID else { return }
            guard !Task.isCancelled else {
                cancelChapterRequest(requestID)
                return
            }
            // Index loading has settled. A cancellation between this point
            // and openSurah's entry must not leave its progress flag behind.
            isLoading = false
        }
        await openSurah(selectedSurahID)
    }

    /// Loading is transactional: leaving a screen preserves the last settled
    /// chapter, selection and error. An obsolete result cannot replace a newer
    /// request, including when the repository does not cooperate with cancellation.
    func openSurah(_ id: Int) async {
        guard !Task.isCancelled, (1...AyahReference.ayahCounts.count).contains(id) else { return }
        let requestID = UUID()
        chapterRequestID = requestID
        if chapter?.surah.id == id {
            isLoading = false
            errorMessage = nil
            return
        }
        isLoading = true
        await withTaskCancellationHandler {
            guard !Task.isCancelled else {
                cancelChapterRequest(requestID)
                return
            }
            do {
                let loadedChapter = try await chapterLoader(id)
                guard chapterRequestID == requestID else { return }
                guard !Task.isCancelled else {
                    cancelChapterRequest(requestID)
                    return
                }
                let selectionChanged = selectedSurahID != id
                if selectionChanged { selectedSurahID = id }
                chapter = loadedChapter
                errorMessage = nil
                isLoading = false
                if selectionChanged { persist() }
            } catch {
                guard chapterRequestID == requestID else { return }
                guard !Task.isCancelled, !(error is CancellationError) else {
                    cancelChapterRequest(requestID)
                    return
                }
                // Keep the failed target for the existing explicit retry action.
                // Only a genuine failure changes the settled selection and error.
                let selectionChanged = selectedSurahID != id
                if selectionChanged { selectedSurahID = id }
                chapter = nil
                isLoading = false
                errorMessage = error.localizedDescription
                if selectionChanged { persist() }
            }
        } onCancel: { [weak self] in
            // A decoder may finish after the user has left. Clear only this
            // request's progress promptly, without retaining the store or
            // cancelling/reverting a later reader selection.
            Task { @MainActor [weak self] in self?.cancelChapterRequest(requestID) }
        }
    }

    private func cancelChapterRequest(_ requestID: UUID) {
        guard chapterRequestID == requestID else { return }
        chapterRequestID = UUID()
        isLoading = false
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
        let inserted = readAyahsByDay[currentDay.id, default: []].insert(reference).inserted
        let moved = lastRead != reference
        guard inserted || moved else { return }
        if moved { lastRead = reference }
        if inserted {
            _ = pruneDetailedMarks()
            updateDailyProgress()
        }
        persist()
    }

    func isReadToday(_ reference: AyahReference) -> Bool {
        readAyahsByDay[currentDay.id]?.contains(reference) ?? false
    }

    func setDailyGoal(_ goal: Int) {
        let boundedGoal = min(50, max(1, goal))
        guard dailyGoal != boundedGoal else {
            refreshDay()
            return
        }
        dailyGoal = boundedGoal
        refreshDay()
        updateDailyProgress()
        persist()
    }

    func setTajweedEnabled(_ enabled: Bool) {
        guard tajweedEnabled != enabled else { return }
        tajweedEnabled = enabled
        persist()
    }

    func setArabicTextSize(_ size: ArabicTextSize) {
        guard arabicTextSize != size else { return }
        arabicTextSize = size
        persist()
    }

    func setAppearance(_ choice: Appearance) {
        guard appearance != choice else { return }
        appearance = choice
        persist()
    }

    func readingBackupData() throws -> Data {
        refreshDay()
        let data = try encodedReadingBackup(bookmarks: bookmarks, lastRead: lastRead,
                                           streak: streak, marks: readAyahsByDay, exportedAt: now())
        guard data.count <= readingDataByteLimit else { throw ReadingBackupError.tooLarge }
        return data
    }

    /// Validate everything before changing any state. Import is additive and
    /// idempotent; current preferences and an existing reading position remain.
    func mergeReadingBackup(_ data: Data) throws {
        guard data.count <= readingDataByteLimit else { throw ReadingBackupError.tooLarge }
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
        let mergeDate = now()
        let mergeCalendar = calendar()
        let mergeDay = ReadingDay(date: mergeDate, calendar: mergeCalendar)
        let retained = Self.retainedDetailedDays(in: mergedMarks, currentDay: mergeDay)
        mergedMarks = mergedMarks.filter { retained.contains($0.key) }
        var mergedStreak = StreakTracker(completionDays: streak.completionDays + backup.completedDays)
        let mergedCount = mergedMarks[mergeDay.id]?.count ?? 0
        if mergedCount >= dailyGoal, !mergedStreak.isCompleted(on: mergeDate, calendar: mergeCalendar) {
            mergedStreak.complete(on: mergeDate, calendar: mergeCalendar)
        }
        let mergedBookmarks = bookmarks.union(backup.bookmarks)
        let mergedLastRead = lastRead ?? backup.lastRead
        guard let savedData = encodedReadingState(bookmarks: mergedBookmarks, lastRead: mergedLastRead,
                                                 streak: mergedStreak, marks: mergedMarks) else {
            throw ReadingBackupError.invalidFile
        }
        let exportData = try encodedReadingBackup(bookmarks: mergedBookmarks, lastRead: mergedLastRead,
                                                 streak: mergedStreak, marks: mergedMarks, exportedAt: mergeDate)
        // Individually valid files can have a union larger than the launch
        // reader accepts. Reject before publishing or replacing any saved data.
        guard savedData.count <= readingDataByteLimit, exportData.count <= readingDataByteLimit else {
            throw ReadingBackupError.combinedDataTooLarge
        }

        if bookmarks != mergedBookmarks { bookmarks = mergedBookmarks }
        if lastRead != mergedLastRead { lastRead = mergedLastRead }
        readAyahsByDay = mergedMarks
        if streak != mergedStreak { streak = mergedStreak }
        summaryDate = mergeDate
        currentDay = mergeDay
        if todayReadCount != mergedCount { todayReadCount = mergedCount }
        let completed = mergedStreak.isCompleted(on: mergeDate, calendar: mergeCalendar)
        if dailyGoalMet != completed { dailyGoalMet = completed }
        updateReadingSummaries()
        defaults.set(savedData, forKey: storageKey)
    }

    private static func isValidReadingDayKey(_ key: String) -> Bool {
        readingDay(for: key) != nil
    }

    private static func readingDay(for key: String) -> ReadingDay? {
        let pieces = key.split(separator: "-", omittingEmptySubsequences: false)
        guard pieces.count == 3, let year = Int(pieces[0]),
              let month = Int(pieces[1]), let day = Int(pieces[2]),
              let readingDay = ReadingDay(year: year, month: month, day: day),
              readingDay.id == key else { return nil }
        return readingDay
    }

    /// Call when the app becomes active as well as at local midnight.
    func refreshDay() {
        summaryDate = now()
        let currentCalendar = calendar()
        currentDay = ReadingDay(date: summaryDate, calendar: currentCalendar)
        // Keep at most seven detailed civil labels. A westward trip or clock
        // correction must not erase a just-completed day that is now tomorrow.
        // Completed history remains in StreakTracker regardless of pruning.
        if pruneDetailedMarks() { persist() }
        let count = readAyahsByDay[currentDay.id]?.count ?? 0
        if todayReadCount != count { todayReadCount = count }
        let completed = streak.isCompleted(on: summaryDate, calendar: currentCalendar)
        if dailyGoalMet != completed { dailyGoalMet = completed }
        updateReadingSummaries()
    }

    private static func retainedDetailedDays(in marks: [String: Set<AyahReference>],
                                            currentDay: ReadingDay) -> Set<String> {
        var civil = Calendar(identifier: .gregorian)
        civil.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let today = currentDay.date(in: civil),
              let firstDate = civil.date(byAdding: .day, value: -6, to: today) else { return [] }
        let firstDay = ReadingDay(date: firstDate, calendar: civil)
        let candidates = marks.keys.compactMap { key -> (key: String, distance: Int)? in
            guard let day = Self.readingDay(for: key), day >= firstDay,
                  let date = day.date(in: civil),
                  let distance = civil.dateComponents([.day], from: today, to: date).day else { return nil }
            return (key, distance)
        }
        // The closest labels win after a merge or a larger clock jump. Always
        // retain today before another day, and prefer the past on equal distance.
        let nearest = candidates.sorted {
            if abs($0.distance) != abs($1.distance) { return abs($0.distance) < abs($1.distance) }
            return $0.distance < $1.distance
        }
        return Set(nearest.prefix(7).map(\.key))
    }

    private func pruneDetailedMarks() -> Bool {
        let retainedDays = Self.retainedDetailedDays(in: readAyahsByDay, currentDay: currentDay)
        let previousCount = readAyahsByDay.count
        readAyahsByDay = readAyahsByDay.filter { retainedDays.contains($0.key) }
        return readAyahsByDay.count != previousCount
    }

    private func updateDailyProgress() {
        let count = readAyahsByDay[currentDay.id]?.count ?? 0
        if todayReadCount != count { todayReadCount = count }
        if todayReadCount >= dailyGoal, !streak.isCompleted(on: summaryDate, calendar: calendar()) {
            streak.complete(on: summaryDate, calendar: calendar())
        }
        // Changing a goal never removes a reading day already completed.
        let completed = streak.isCompleted(on: summaryDate, calendar: calendar())
        if dailyGoalMet != completed { dailyGoalMet = completed }
        updateReadingSummaries()
    }

    private func updateReadingSummaries() {
        // Calendar arithmetic over years of history belongs to a day/history
        // change, not every Home/Settings render or playback state update.
        if summarizedDay != currentDay || summarizedHistory != streak {
            if summarizedHistory != streak { completedDayLabels = Set(streak.completionDays) }
            summarizedDay = currentDay
            summarizedHistory = streak
            let value = streak.summary(asOf: summaryDate, calendar: calendar())
            if value != streakSummary { streakSummary = value }
        }
        var civil = Calendar(identifier: .gregorian)
        civil.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let today = currentDay.date(in: civil) else { return }
        let recent = (0..<7).reversed().compactMap { offset -> ReadingDayProgress? in
            guard let date = civil.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let day = ReadingDay(date: date, calendar: civil)
            return ReadingDayProgress(day: day, date: date,
                                      readCount: readAyahsByDay[day.id]?.count ?? 0,
                                      goalCompleted: completedDayLabels.contains(day), isToday: day == currentDay)
        }
        if recent != recentReadingDays { recentReadingDays = recent }
    }

    private func persist() {
        guard let data = encodedReadingState(bookmarks: bookmarks, lastRead: lastRead,
                                            streak: streak, marks: readAyahsByDay),
              data.count <= readingDataByteLimit else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func encodedReadingState(bookmarks: Set<AyahReference>, lastRead: AyahReference?,
                                     streak: StreakTracker, marks: [String: Set<AyahReference>]) -> Data? {
        let state = SavedState(
            version: 1,
            selectedSurahID: selectedSurahID,
            lastRead: lastRead,
            bookmarks: bookmarks,
            tajweedEnabled: tajweedEnabled,
            arabicTextSize: arabicTextSize.rawValue,
            appearance: appearance.rawValue,
            dailyGoal: dailyGoal,
            streak: streak,
            readAyahsByDay: marks
        )
        return try? JSONEncoder().encode(state)
    }

    private func encodedReadingBackup(bookmarks: Set<AyahReference>, lastRead: AyahReference?,
                                      streak: StreakTracker, marks: [String: Set<AyahReference>],
                                      exportedAt: Date) throws -> Data {
        let backup = ReadingBackup(format: "sakina-reading-backup", version: 1, exportedAt: exportedAt,
                                   bookmarks: bookmarks, lastRead: lastRead,
                                   completedDays: streak.completionDays, readAyahsByDay: marks)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        do { return try encoder.encode(backup) }
        catch { throw ReadingBackupError.cannotExport }
    }
}
