import SwiftUI
import QuranCore

struct ReaderView: View {
    var initialReference: AyahReference? = nil
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var player: RecitationPlayer
    @EnvironmentObject private var recorder: PracticeRecorder
    @State private var showSurahs = false
    @State private var showLegend = false
    @State private var tafsirReference: AyahReference?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if let chapter = store.chapter {
                        chapterHeading(chapter)
                        if chapter.surah.id != 1 && chapter.surah.id != 9 {
                            ArabicText(text: QuranPresentation.basmala, tajweed: nil, colored: false)
                                .padding(.vertical, 12).padding(.horizontal, 8)
                                .accessibilityLabel(QuranPresentation.basmala)
                        }
                        if showLegend && store.tajweedEnabled { Card { TajweedLegend() } }
                        ForEach(chapter.ayahs) { ayah in
                            verseCard(ayah, chapter: chapter).id(ayah.numberInSurah)
                        }
                        Text("Arabisk text: Tanzil.net via AlQuran Cloud. Läsningen följer Hafs-numrering.")
                            .font(.caption).foregroundStyle(.secondary).padding(.vertical, 12)
                    } else if store.isLoading {
                        ProgressView("Öppnar Koranen …").padding(50)
                    }
                    if let error = store.errorMessage {
                        ErrorBanner(message: error)
                        Button("Försök igen") { Task { await store.load() } }
                    }
                }.padding(20)
            }
            .task(id: store.chapter?.surah.id) {
                guard let reference = initialReference ?? store.lastRead,
                      reference.surahID == store.chapter?.surah.id else { return }
                await Task.yield()
                proxy.scrollTo(reference.ayahNumber, anchor: .top)
            }
            .onAppear {
                if let reference = initialReference ?? store.lastRead, reference.surahID == store.chapter?.surah.id {
                    proxy.scrollTo(reference.ayahNumber, anchor: .top)
                }
            }
            .onChange(of: player.activeReference) { _, reference in
                guard let reference, reference.surahID == store.chapter?.surah.id else { return }
                store.setLastRead(reference)
                proxy.scrollTo(reference.ayahNumber, anchor: .center)
            }
        }
        .background(Palette.background)
        .navigationTitle("Koranen").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showSurahs = true } label: { Label("Välj sura", systemImage: "list.bullet") }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle("Tajweedfärger", isOn: Binding(get: { store.tajweedEnabled }, set: store.setTajweedEnabled))
                    Toggle("Visa färgförklaring", isOn: $showLegend)
                    Toggle("Fortsätt till nästa vers", isOn: $player.autoplay)
                } label: { Label("Läsinställningar", systemImage: "textformat.size") }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if player.requestedReference != nil { PlaybackBar() }
        }
        .sheet(isPresented: $showSurahs) {
            SurahPicker { surah in
                recorder.stopAll()
                player.stop()
                Task { await store.openSurah(surah.id) }
            }
        }
        .sheet(item: $tafsirReference) { TafsirSheet(reference: $0) }
    }

    private func chapterHeading(_ chapter: QuranChapter) -> some View {
        Card {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SURA \(chapter.surah.id)").font(.caption.weight(.semibold)).tracking(2).foregroundStyle(Palette.gold)
                    Text(chapter.surah.englishName).font(.system(.title, design: .serif)).foregroundStyle(Palette.green)
                    Text("\(chapter.surah.numberOfAyahs) verser").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                Text(chapter.surah.name).font(.custom("GeezaPro", size: 26, relativeTo: .title2))
                    .environment(\.layoutDirection, .rightToLeft)
            }
        }
    }

    private func verseCard(_ ayah: Ayah, chapter: QuranChapter) -> some View {
        let reference = ayah.reference
        let active = reference != nil && player.activeReference == reference
        let loading = reference != nil && player.requestedReference == reference && player.isBuffering
        return Card {
            HStack {
                Text("\(chapter.surah.id):\(ayah.numberInSurah)")
                    .font(.caption.monospacedDigit().weight(.medium))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Palette.green.opacity(0.08), in: Capsule())
                if active {
                    Label(player.isPlaying ? "Spelas nu" : "Pausad", systemImage: "speaker.wave.2")
                        .font(.caption).foregroundStyle(Palette.green)
                }
                Spacer()
                if loading { ProgressView().accessibilityLabel("Laddar recitation") }
                if let reference, store.isReadToday(reference) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.green)
                        .accessibilityLabel("Läst idag")
                }
            }
            ArabicText(text: QuranPresentation.verseText(ayah), tajweed: ayah.tajweed, colored: store.tajweedEnabled)
                .padding(.vertical, 18)
            if let reference {
                HStack(spacing: 8) {
                    Button {
                        recorder.stopAll()
                        if active && player.isPlaying { player.pause() }
                        else { player.play(reference: reference, chapterVerseCount: chapter.surah.numberOfAyahs) }
                        store.setLastRead(reference)
                    } label: {
                        Image(systemName: active && player.isPlaying ? "pause.fill" : "play.fill")
                            .frame(width: 44, height: 44)
                    }.accessibilityLabel(active && player.isPlaying ? "Pausa versen" : "Lyssna på vers \(ayah.numberInSurah)")
                    Button { store.toggleBookmark(reference) } label: {
                        Image(systemName: store.bookmarks.contains(reference) ? "bookmark.fill" : "bookmark")
                            .frame(width: 44, height: 44)
                    }.accessibilityLabel(store.bookmarks.contains(reference) ? "Ta bort bokmärke" : "Spara bokmärke")
                    Button { tafsirReference = reference } label: { Text("Tafsir").font(.subheadline).frame(minHeight: 44) }
                    Spacer(minLength: 0)
                    Button { store.markRead(reference) } label: {
                        Image(systemName: store.isReadToday(reference) ? "checkmark.circle.fill" : "checkmark.circle")
                            .frame(width: 44, height: 44)
                    }.accessibilityLabel(store.isReadToday(reference) ? "Redan läst idag" : "Markera vers \(ayah.numberInSurah) som läst")
                        .disabled(store.isReadToday(reference))
                }.buttonStyle(.plain).foregroundStyle(Palette.green)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24).strokeBorder(active ? Palette.green : .clear, lineWidth: 2)
        }
    }
}

enum QuranPresentation {
    static let basmala = "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ"

    /// The source places Basmala inside the first Uthmani verse of these surahs.
    /// Show that exact prefix as a separate header; never change the stored text.
    static func verseText(_ ayah: Ayah) -> String {
        let prefix = basmala + " "
        if ayah.numberInSurah == 1, ayah.surahID != 1, ayah.surahID != 9,
           ayah.text.hasPrefix(prefix) {
            return String(ayah.text.dropFirst(prefix.count))
        }
        return ayah.text
    }
}

struct SurahPicker: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    let select: (Surah) -> Void

    var body: some View {
        NavigationStack {
            List(filtered) { surah in
                Button {
                    select(surah)
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        Text("\(surah.id)").font(.subheadline.monospacedDigit()).foregroundStyle(Palette.green).frame(width: 34)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(surah.englishName).foregroundStyle(.primary)
                            Text("\(surah.numberOfAyahs) verser").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(surah.name).font(.custom("GeezaPro", size: 21, relativeTo: .title3))
                            .foregroundStyle(Palette.green)
                    }.padding(.vertical, 6)
                }
            }
            .searchable(text: $search, prompt: "Namn eller surans nummer")
            .navigationTitle("Välj sura")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Stäng") { dismiss() } } }
        }
    }
    private var filtered: [Surah] {
        let surahs = store.index?.surahs ?? []
        guard !search.isEmpty else { return surahs }
        return surahs.filter {
            $0.englishName.localizedStandardContains(search) || $0.name.contains(search) || String($0.id) == search
        }
    }
}

struct PlaybackBar: View {
    @EnvironmentObject private var player: RecitationPlayer
    @EnvironmentObject private var recorder: PracticeRecorder

    var body: some View {
        VStack(spacing: 6) {
            if let error = player.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            HStack(spacing: 12) {
                Menu {
                    ForEach(Reciter.allCases) { reciter in
                        Button { player.selectReciter(reciter) } label: {
                            if reciter == player.selectedReciter { Label(reciter.displayName, systemImage: "checkmark") }
                            else { Text(reciter.displayName) }
                        }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(player.selectedReciter.displayName).font(.caption.weight(.semibold))
                        if let ref = player.requestedReference {
                            Text("Vers \(ref.surahID):\(ref.ayahNumber) · byt recitatör")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: 44)
                }
                Button { recorder.stopAll(); player.previous() } label: {
                    Image(systemName: "backward.end.fill").frame(width: 40, height: 44)
                }.accessibilityLabel("Föregående vers")
                    .disabled((player.requestedReference?.ayahNumber ?? 1) <= 1)
                Button {
                    recorder.stopAll()
                    if player.isPlaying || player.isBuffering { player.pause() } else { player.resume() }
                } label: {
                    Group {
                        if player.isBuffering { ProgressView() }
                        else { Image(systemName: player.isPlaying ? "pause.fill" : "play.fill") }
                    }.frame(width: 44, height: 44)
                }.accessibilityLabel(player.isPlaying || player.isBuffering ? "Pausa" : "Spela")
                Button { recorder.stopAll(); player.next() } label: {
                    Image(systemName: "forward.end.fill").frame(width: 40, height: 44)
                }.accessibilityLabel("Nästa vers")
                    .disabled(isLastVerse)
                Button { player.stop() } label: {
                    Image(systemName: "xmark").frame(width: 32, height: 44)
                }.accessibilityLabel("Stäng spelaren")
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.regularMaterial)
    }
    private var isLastVerse: Bool {
        guard let reference = player.requestedReference else { return true }
        return reference.ayahNumber >= AyahReference.ayahCounts[reference.surahID - 1]
    }
}
