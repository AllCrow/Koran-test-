import SwiftUI
import QuranCore

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var player: RecitationPlayer

    var body: some View {
        List {
            Section("Din läsvana") {
                Stepper(value: Binding(get: { store.dailyGoal }, set: store.setDailyGoal), in: 1...50) {
                    LabeledContent("Dagligt mål", value: "\(store.dailyGoal) verser")
                }
                LabeledContent("Nuvarande streak", value: "\(store.streakSummary.current) dagar")
                LabeledContent("Längsta streak", value: "\(store.streakSummary.best) dagar")
                Text("Målet räknar olika verser som du själv markerar som lästa. Ett uppehåll är alltid en möjlighet att börja igen.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Läsning och ljud") {
                Toggle("Tajweedfärger", isOn: Binding(get: { store.tajweedEnabled }, set: store.setTajweedEnabled))
                Picker("Recitatör", selection: Binding(get: { player.selectedReciter }, set: { player.selectReciter($0) })) {
                    ForEach(Reciter.allCases) { Text($0.displayName).tag($0) }
                }
                Toggle("Spela nästa vers automatiskt", isOn: $player.autoplay)
            }
            Section("Bokmärken") {
                if store.bookmarks.isEmpty {
                    Label("Spara en vers med bokmärkessymbolen i läsvyn.", systemImage: "bookmark")
                        .font(.callout).foregroundStyle(.secondary)
                }
                ForEach(sortedBookmarks) { reference in
                    NavigationLink {
                        BookmarkDestination(reference: reference)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(surahName(reference))
                            Text("Vers \(reference.surahID):\(reference.ayahNumber)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions {
                        Button("Ta bort", role: .destructive) { store.toggleBookmark(reference) }
                    }
                }
            }
            Section("Om Sakina") {
                NavigationLink("Källor och textutgåvor") { SourceNoticeView() }
                NavigationLink("Integritet") { PrivacyView() }
                Text("Ingen prenumeration, inget konto och inga annonser i den här versionen.")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("Tafsir och recitation behöver internet. Automatisk tajweedbedömning ingår ännu inte.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Mitt")
    }

    private var sortedBookmarks: [AyahReference] {
        store.bookmarks.sorted { lhs, rhs in
            lhs.surahID == rhs.surahID ? lhs.ayahNumber < rhs.ayahNumber : lhs.surahID < rhs.surahID
        }
    }
    private func surahName(_ reference: AyahReference) -> String {
        store.index?.surahs.first { $0.id == reference.surahID }?.englishName ?? "Sura \(reference.surahID)"
    }
}

private struct BookmarkDestination: View {
    let reference: AyahReference
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var player: RecitationPlayer
    @EnvironmentObject private var recorder: PracticeRecorder

    var body: some View {
        ReaderView(initialReference: reference).task {
            recorder.stopAll()
            player.stop()
            store.setLastRead(reference)
            await store.openSurah(reference.surahID)
        }
    }
}

struct SourceNoticeView: View {
    @State private var notice = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Korantext och tajweed").font(.title2.bold())
                Text("Uthmani-texten och den annoterade tajweedutgåvan är separata utgåvor. Visningen följer Hafs-numrering. Båda källtexterna bevaras ordagrant i appens databas.")
                Link("Tanzil.net – korantext", destination: URL(string: "https://tanzil.net")!)
                Link("AlQuran Cloud – käll-API", destination: URL(string: "https://alquran.cloud")!)
                Link("Tajweednotation och färgförklaring", destination: URL(string: "https://alquran.cloud/tajweed-guide")!)
                Text("Recitation").font(.title2.bold())
                Text("Mishary Rashid al-Afasy, Mahmoud Khalil al-Husary och Muhammad Siddiq al-Minshawi. Inspelningarna strömmas från EveryAyah, en fil per vers. Textmarkeringen följer versen, inte enskilda ord.")
                Link("EveryAyah", destination: URL(string: "https://everyayah.com")!)
                Text("Tafsir").font(.title2.bold())
                Text("Al-Muyassar på arabiska via AlQuran Cloud. Ingen automatisk översättning eller AI-genererad tafsir används.")
                Divider()
                Text(notice).font(.footnote).textSelection(.enabled)
            }.padding(24)
        }
        .navigationTitle("Källor").navigationBarTitleDisplayMode(.inline)
        .task {
            if let url = Bundle.main.url(forResource: "NOTICE", withExtension: "txt", subdirectory: "Quran"),
               let text = try? String(contentsOf: url, encoding: .utf8) { notice = text }
        }
    }
}

struct PrivacyView: View {
    var body: some View {
        List {
            Section("Sparas på din iPhone") {
                Text("Läsposition, bokmärken, läsmål och streak sparas lokalt. Appen kräver inget konto och innehåller ingen analys- eller annonsspårning.")
                Text("Inspelningar stannar på telefonen, kan raderas i övningsvyn och tas bort vid nästa appstart. De laddas inte upp.")
            }
            Section("När du använder internet") {
                Text("När du lyssnar kontaktar appen EveryAyah. När du öppnar tafsir kontaktar den AlQuran Cloud. Tjänsterna får din IP-adress och vilken vers du begär, men ingen röstinspelning från appen.")
                Text("Du kan läsa hela korantexten med tajweedfärger utan internet.")
            }
        }.navigationTitle("Integritet").navigationBarTitleDisplayMode(.inline)
    }
}
