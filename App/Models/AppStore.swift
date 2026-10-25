import Combine
import Foundation
import QuranCore
import QuranData
import UIKit

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var index: ContentIndex?
    @Published private(set) var chapter: QuranChapter?
    @Published private(set) var selectedSurahID: Int = 1
    @Published private(set) var lastRead: AyahReference?
    @Published private(set) var bookmarks: Set<AyahReference> = []
    @Published private(set) var tajweedEnabled = true
    @Published private(set) var dailyGoal = 3
    @Published private(set) var streak = StreakTracker()
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

    private let repository: QuranRepository
    private let defaults: UserDefaults
    private let now: () -> Date
    private let calendar: () -> Calendar
    private let storageKey = "sakina.reading-state.v1"
    private var readAyahsByDay: [String: Set<AyahReference>] = [:]
    private var currentDay: ReadingDay
    private var summaryDate: Date
    private var chapterRequestID = UUID()
    private var dayChangeSubscription: AnyCancellable?

    var streakSummary: StreakSummary {
        streak.summary(asOf: summaryDate, calendar: calendar())
    }

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
        selectedSurahID = id
        persist()
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
        tajweedEnabled = enabled
        persist()
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
    }

    private func updateDailyProgress() {
        todayReadCount = readAyahsByDay[currentDay.id]?.count ?? 0
        if todayReadCount >= dailyGoal {
            streak.complete(on: summaryDate, calendar: calendar())
        }
        // Changing a goal never removes a reading day already completed.
        dailyGoalMet = streak.isCompleted(on: summaryDate, calendar: calendar())
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
