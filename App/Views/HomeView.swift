import SwiftUI
import QuranCore

@MainActor
struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let read: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("En liten stund.\nEn närmare relation.")
                    .font(.system(.largeTitle, design: .serif)).foregroundStyle(Palette.green)
                    .accessibilityAddTraits(.isHeader)
                Text("Din stund med Koranen, i din egen takt.").foregroundStyle(.secondary)

                SectionLabel(title: store.lastRead == nil ? "Börja läsa" : "Fortsätt där du var")
                continueReadingCard
                readingHabitCard
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "wifi.slash").foregroundStyle(Palette.green)
                    Text("Korantexten finns på din iPhone. Du kan läsa även utan internet.")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding(.horizontal, 4)
                if let error = store.errorMessage { ErrorBanner(message: error) }
            }.padding(24)
        }
        .background(Palette.background)
        .navigationTitle("Sakina").navigationBarTitleDisplayMode(.inline)
    }

    private var continueReadingCard: some View {
        Card {
            HStack(spacing: 16) {
                if !dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: "book.closed").font(.title2).foregroundStyle(Palette.green)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(lastSurahName).font(.headline)
                    Text("Sura \(readingSurahID) · vers \(store.lastRead?.ayahNumber ?? 1)")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .accessibilityIdentifier("home.readingPosition")
                }
                Spacer(minLength: 0)
            }
            PrimaryButton(title: store.lastRead == nil ? "Öppna Koranen" : "Fortsätt läsa", icon: "arrow.right", action: read)
                .padding(.top, 18)
                .accessibilityIdentifier("home.continue")
        }
    }

    private var readingHabitCard: some View {
        Card {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Din läsvana", systemImage: "leaf")
                        .font(.subheadline).foregroundStyle(Palette.green)
                        .accessibilityAddTraits(.isHeader)
                    Text(store.streakSummary.current == 1 ? "1 dag" : "\(store.streakSummary.current) dagar")
                        .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    Text(streakMessage).font(.callout).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if !dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: "sun.max.fill").font(.largeTitle)
                        .foregroundStyle(Palette.gold).accessibilityHidden(true)
                }
            }
            Divider().padding(.vertical, 12)
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text("Dagens mål").fixedSize()
                    Spacer(minLength: 12)
                    Text("\(store.todayReadCount) / \(store.dailyGoal) verser").monospacedDigit().fixedSize()
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Dagens mål")
                    Text("\(store.todayReadCount) / \(store.dailyGoal) verser").monospacedDigit()
                }
            }
            .font(.subheadline)
            ProgressView(value: Double(min(store.todayReadCount, store.dailyGoal)),
                         total: Double(store.dailyGoal)).padding(.top, 8)
                .accessibilityLabel("Dagens läsmål")
                .accessibilityValue("\(store.todayReadCount) av \(store.dailyGoal) verser lästa")
                .accessibilityIdentifier("home.dailyProgress")
            Text(store.dailyGoalMet ? "Dagens mål är klart. Fint att du tog dig tid." : "Markera verser som lästa i läsvyn. Varje liten stund räknas.")
                .font(.caption).foregroundStyle(.secondary).padding(.top, 8)
            recentReadingHistory
        }
    }

    private var recentReadingHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider().padding(.top, 12)
            Text("Senaste sju dagarna").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            if dynamicTypeSize >= .xxLarge {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(store.recentReadingDays) { progress in
                        HStack(alignment: .top, spacing: 12) {
                            readingDayMarker(progress)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(dateLabel(progress, short: false)).font(.subheadline)
                                    .fontWeight(progress.isToday ? .semibold : .regular)
                                Text(readingDayStatus(progress)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(dateLabel(progress, short: false))
                        .accessibilityValue(readingDayStatus(progress))
                        .accessibilityIdentifier("home.readingDay.\(progress.id)")
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 6) {
                    ForEach(store.recentReadingDays) { progress in
                        VStack(spacing: 8) {
                            readingDayMarker(progress)
                            Text(dateLabel(progress, short: true)).font(.caption2)
                                .fontWeight(progress.isToday ? .semibold : .regular)
                                .foregroundStyle(progress.isToday ? Palette.green : .secondary)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(dateLabel(progress, short: false))
                        .accessibilityValue(readingDayStatus(progress))
                        .accessibilityIdentifier("home.readingDay.\(progress.id)")
                    }
                }
                Text("Prick för läsning, bock för uppnått dagsmål.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func readingDayMarker(_ progress: AppStore.ReadingDayProgress) -> some View {
        ZStack {
            Circle().fill(Palette.green.opacity(progress.goalCompleted ? 0.12 : 0.05))
            if progress.goalCompleted {
                Image(systemName: "checkmark").font(.caption.weight(.semibold)).foregroundStyle(Palette.green)
            } else if progress.readCount > 0 {
                Circle().fill(Palette.green).frame(width: 7, height: 7)
            }
            if progress.isToday {
                Circle().strokeBorder(Palette.green, lineWidth: 1.5)
            }
        }
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)
    }

    private func dateLabel(_ progress: AppStore.ReadingDayProgress, short: Bool) -> String {
        if short && progress.isToday { return "Idag" }
        var format = short
            ? Date.FormatStyle.dateTime.weekday(.abbreviated)
            : Date.FormatStyle.dateTime.weekday(.wide).day().month(.wide)
        // AppStore supplies civil-day labels at UTC noon. Formatting in UTC
        // keeps the saved weekday stable across travel and skipped local dates.
        format.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = progress.date.formatted(format)
        return !short && progress.isToday ? "Idag, \(date)" : date
    }

    private func readingDayStatus(_ progress: AppStore.ReadingDayProgress) -> String {
        let count = progress.readCount == 1 ? "1 vers markerad" : "\(progress.readCount) verser markerade"
        if progress.goalCompleted {
            return progress.readCount > 0 ? "Dagsmål uppnått · \(count)" : "Dagsmål uppnått"
        }
        return progress.readCount > 0 ? count : "Inga markerade verser"
    }

    private var lastSurahName: String {
        store.index?.surahs.first { $0.id == readingSurahID }?.englishName
            ?? (readingSurahID == 1 ? "Al-Faatiha" : "Sura \(readingSurahID)")
    }
    private var readingSurahID: Int { store.lastRead?.surahID ?? store.selectedSurahID }
    private var streakMessage: String {
        if store.dailyGoalMet { return "Du har gjort plats för Koranen idag." }
        if store.streakSummary.current > 0 { return "En ny stund väntar idag." }
        return "Börja med idag. Du är alltid välkommen tillbaka."
    }
}
