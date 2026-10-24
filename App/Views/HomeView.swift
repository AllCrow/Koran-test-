import SwiftUI
import QuranCore

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
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

                Card {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Din läsvana", systemImage: "leaf")
                                .font(.subheadline).foregroundStyle(Palette.green)
                            Text("\(store.streakSummary.current) dagar")
                                .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                            Text(streakMessage).font(.callout).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "sun.max.fill").font(.largeTitle)
                            .foregroundStyle(Palette.gold).accessibilityHidden(true)
                    }
                    Divider().padding(.vertical, 12)
                    HStack {
                        Text("Dagens mål").font(.subheadline)
                        Spacer()
                        Text("\(store.todayReadCount) / \(store.dailyGoal) verser").font(.subheadline.monospacedDigit())
                    }
                    ProgressView(value: Double(min(store.todayReadCount, store.dailyGoal)),
                                 total: Double(store.dailyGoal)).padding(.top, 8)
                        .accessibilityLabel("Dagens läsmål")
                    Text(store.dailyGoalMet ? "Dagens mål är klart. Fint att du tog dig tid." : "Markera verser som lästa i läsvyn. Varje liten stund räknas.")
                        .font(.caption).foregroundStyle(.secondary).padding(.top, 8)
                }

                SectionLabel(title: "Fortsätt där du var")
                Card {
                    HStack(spacing: 16) {
                        Image(systemName: "book.closed").font(.title2).foregroundStyle(Palette.green)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(lastSurahName).font(.headline)
                            Text("Sura \(store.lastRead?.surahID ?? 1) · vers \(store.lastRead?.ayahNumber ?? 1)")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    PrimaryButton(title: "Fortsätt läsa", icon: "arrow.right", action: read).padding(.top, 18)
                }
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

    private var lastSurahName: String {
        store.index?.surahs.first { $0.id == (store.lastRead?.surahID ?? 1) }?.englishName ?? "Al-Faatiha"
    }
    private var streakMessage: String {
        if store.dailyGoalMet { return "Du har gjort plats för Koranen idag." }
        if store.streakSummary.current > 0 { return "En ny stund väntar idag." }
        return "Börja med idag. Du är alltid välkommen tillbaka."
    }
}
