import SwiftUI
import QuranCore

@MainActor
struct ReaderView: View {
    var initialReference: AyahReference? = nil
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var player: RecitationPlayer
    @EnvironmentObject private var recorder: PracticeRecorder
    @State private var showSurahs = false
    @State private var showLegend = false
    @State private var tafsirReference: AyahReference?
    @State private var showVerseJump = false
    @State private var prefersLatestReadingPosition = false
    @State private var pendingJumpReference: AyahReference?
    @State private var scrollPosition: String?
    @State private var scrollAnchor: UnitPoint = .top
    @State private var scrollRequest: ScrollRequest?

    private struct ScrollRequest {
        let id = UUID()
        let targetID: String
        let anchor: UnitPoint
    }

    var body: some View {
        Group {
            ScrollView {
                readerContent
            }
            .scrollPosition(id: $scrollPosition, anchor: scrollAnchor)
            .onChange(of: scrollPosition) { previous, next in
                #if DEBUG
                if CommandLine.arguments.contains("--ui-test-suite") {
                    print("Reader scroll position \(previous ?? "nil") -> \(next ?? "nil"); requested \(scrollRequest?.targetID ?? "nil")")
                }
                #endif
            }
            .task(id: store.chapter?.surah.id) {
                guard store.chapter != nil else { return }
                await Task.yield()
                guard !Task.isCancelled else { return }
                requestScroll(to: preferredReference?.id ?? "chapter-heading", anchor: .top)
            }
            .task(id: scrollRequest?.id) {
                guard let request = scrollRequest else { return }
                // Clearing the binding makes a repeated explicit jump work
                // even when its verse is already the currently tracked row.
                scrollPosition = nil
                scrollAnchor = request.anchor
                await Task.yield()
                guard !Task.isCancelled else { return }
                scrollPosition = request.targetID
            }
            .onAppear {
                if let reference = preferredReference {
                    requestScroll(to: reference.id, anchor: .top)
                }
            }
            .onChange(of: player.activeReference) { _, reference in
                guard let reference, reference.surahID == store.chapter?.surah.id else { return }
                store.setLastRead(reference)
                requestScroll(to: reference.id, anchor: .center)
            }
            .sheet(isPresented: $showVerseJump, onDismiss: {
                guard let reference = pendingJumpReference else { return }
                pendingJumpReference = nil
                guard reference.surahID == store.chapter?.surah.id else { return }
                // Wait for the keyboard/sheet viewport to be restored. The
                // semantic target then survives lazy row-height corrections.
                requestScroll(to: reference.id, anchor: .top)
            }) {
                if let chapter = store.chapter {
                    VerseJumpSheet(surah: chapter.surah) { reference in
                        guard reference.surahID == store.chapter?.surah.id else { return }
                        recorder.stopAll()
                        player.stop()
                        prefersLatestReadingPosition = true
                        store.setLastRead(reference)
                        pendingJumpReference = reference
                    }
                }
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
                    Button { pendingJumpReference = nil; showVerseJump = true } label: {
                        Label("Gå till vers", systemImage: "number")
                    }
                    .disabled(store.chapter == nil)
                    .accessibilityIdentifier("reader.jump.present")
                    Toggle("Tajweedfärger", isOn: Binding(get: { store.tajweedEnabled }, set: { store.setTajweedEnabled($0) }))
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

    @ViewBuilder
    private var readerContent: some View {
        // Bind the chapter before creating the lazy target layout. Its
        // ForEach exposes each verse directly at the target layout's root,
        // alongside the heading, instead of through a whole-chapter group.
        if let chapter = store.chapter {
            LazyVStack(spacing: 16) {
                chapterHeading(chapter).id("chapter-heading")
                if let basmala = QuranPresentation.basmala(for: chapter) {
                    ArabicText(text: basmala, tajweed: nil, colored: false)
                        .padding(.vertical, 12).padding(.horizontal, 8)
                }
                if showLegend && store.tajweedEnabled { Card { TajweedLegend() } }
                ForEach(chapter.ayahs, id: \.readerScrollID) { ayah in
                    verseCard(ayah, chapter: chapter).id(ayah.readerScrollID)
                }
                Text("Arabisk text: Tanzil.net via AlQuran Cloud. Läsningen följer Hafs-numrering.")
                    .font(.caption).foregroundStyle(.secondary).padding(.vertical, 12)
                readerError
            }
            .scrollTargetLayout()
            .padding(20)
        } else {
            VStack(spacing: 16) {
                if store.isLoading { ProgressView("Öppnar Koranen …").padding(50) }
                readerError
            }.padding(20)
        }
    }

    @ViewBuilder
    private var readerError: some View {
        if let error = store.errorMessage {
            ErrorBanner(message: error)
            Button("Försök igen") { Task { await store.load() } }
                .frame(minHeight: 44)
                .accessibilityIdentifier("reader.retry")
        }
    }

    private func chapterHeading(_ chapter: QuranChapter) -> some View {
        Card {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 12) {
                    chapterDetails(chapter).fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    chapterArabicName(chapter).fixedSize(horizontal: true, vertical: false)
                }
                VStack(alignment: .leading, spacing: 14) {
                    chapterDetails(chapter)
                    chapterArabicName(chapter).frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }

    private func chapterDetails(_ chapter: QuranChapter) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SURA \(chapter.surah.id)").font(.caption.weight(.semibold)).tracking(2).foregroundStyle(Palette.gold)
            Text(chapter.surah.englishName).font(.system(.title, design: .serif)).foregroundStyle(Palette.green)
                .accessibilityIdentifier("reader.chapter.\(chapter.surah.id)")
                .accessibilityAddTraits(.isHeader)
            Text("\(chapter.surah.numberOfAyahs) verser").font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func chapterArabicName(_ chapter: QuranChapter) -> some View {
        Text(chapter.surah.name).font(.custom("AmiriQuran-Regular", size: 26, relativeTo: .title2))
            .environment(\.layoutDirection, .rightToLeft)
            .accessibilityRepresentation { ArabicAccessibilityLabel(text: chapter.surah.name) }
    }

    /// A bookmark sets the first position. After an explicit jump, later
    /// reading/listening actions keep their newer saved position on return.
    private var preferredReference: AyahReference? {
        let chapterID = store.chapter?.surah.id
        if prefersLatestReadingPosition, let lastRead = store.lastRead, lastRead.surahID == chapterID { return lastRead }
        if let initialReference, initialReference.surahID == chapterID { return initialReference }
        if let lastRead = store.lastRead, lastRead.surahID == chapterID { return lastRead }
        return nil
    }

    private func requestScroll(to targetID: String, anchor: UnitPoint) {
        scrollRequest = ScrollRequest(targetID: targetID, anchor: anchor)
    }

    private func verseCard(_ ayah: Ayah, chapter: QuranChapter) -> some View {
        let reference = ayah.reference
        let active = reference != nil && player.activeReference == reference
        let requested = reference != nil && player.requestedReference == reference
        let canPause = requested && (player.isPlaying || player.isBuffering)
        let loading = reference != nil && player.requestedReference == reference && player.isBuffering
        return Card {
            HStack {
                Text("\(chapter.surah.id):\(ayah.numberInSurah)")
                    .font(.caption.monospacedDigit().weight(.medium))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Palette.green.opacity(0.08), in: Capsule())
                    // A container identifier propagates to SwiftUI children
                    // and masks the action buttons' individual identifiers.
                    .accessibilityIdentifier("reader.verse.\(chapter.surah.id).\(ayah.numberInSurah)")
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
                        if requested {
                            if canPause { player.pause() } else { player.resume() }
                        } else {
                            player.play(reference: reference, chapterVerseCount: chapter.surah.numberOfAyahs)
                        }
                        store.setLastRead(reference)
                    } label: {
                        Image(systemName: canPause ? "pause.fill" : "play.fill")
                            .frame(width: 44, height: 44)
                    }.accessibilityLabel(canPause ? "Pausa versen" : "Lyssna på vers \(ayah.numberInSurah)")
                    Button { store.toggleBookmark(reference) } label: {
                        Image(systemName: store.bookmarks.contains(reference) ? "bookmark.fill" : "bookmark")
                            .frame(width: 44, height: 44)
                    }.accessibilityLabel(store.bookmarks.contains(reference) ? "Ta bort bokmärke" : "Spara bokmärke")
                        .accessibilityIdentifier("reader.bookmark.\(reference.surahID).\(reference.ayahNumber)")
                    Button { tafsirReference = reference } label: { Text("Tafsir").font(.subheadline).frame(minHeight: 44) }
                    Spacer(minLength: 0)
                    Button { store.markRead(reference) } label: {
                        Image(systemName: store.isReadToday(reference) ? "checkmark.circle.fill" : "checkmark.circle")
                            .frame(width: 44, height: 44)
                    }.accessibilityLabel(store.isReadToday(reference) ? "Redan läst idag" : "Markera vers \(ayah.numberInSurah) som läst")
                        .disabled(store.isReadToday(reference))
                        .accessibilityIdentifier("reader.markRead.\(reference.surahID).\(reference.ayahNumber)")
                }.buttonStyle(.plain).foregroundStyle(Palette.green)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24).strokeBorder(active ? Palette.green : .clear, lineWidth: 2)
        }
    }
}

private extension Ayah {
    var readerScrollID: String { "\(surahID):\(numberInSurah)" }
}

/// A jump is a reading position, never an automatic reading-completion action.
enum VerseJumpInput {
    static func number(from input: String, maximum: Int) -> Int? {
        guard maximum > 0 else { return nil }
        let input = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, input.unicodeScalars.count <= 10 else { return nil }
        var number = 0
        for scalar in input.unicodeScalars {
            guard CharacterSet.decimalDigits.contains(scalar),
                  let digit = Character(String(scalar)).wholeNumberValue,
                  (0...9).contains(digit) else { return nil }
            let (shifted, multiplicationOverflow) = number.multipliedReportingOverflow(by: 10)
            let (next, additionOverflow) = shifted.addingReportingOverflow(digit)
            guard !multiplicationOverflow, !additionOverflow, next <= maximum else { return nil }
            number = next
        }
        return number >= 1 ? number : nil
    }
}

@MainActor
private struct VerseJumpSheet: View {
    let surah: Surah
    let select: (AyahReference) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @FocusState private var numberFocused: Bool

    private var reference: AyahReference? {
        guard let number = VerseJumpInput.number(from: input, maximum: surah.numberOfAyahs) else { return nil }
        return AyahReference(surahID: surah.id, ayahNumber: number)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Sura \(surah.id) · \(surah.englishName)").font(.callout)
                    TextField("Versnummer", text: $input)
                        .keyboardType(.numberPad)
                        .focused($numberFocused)
                        .accessibilityLabel("Versnummer")
                        .accessibilityIdentifier("reader.jump.number")
                } footer: {
                    Text("Välj en vers mellan 1 och \(surah.numberOfAyahs).")
                }
                if !input.isEmpty && reference == nil {
                    Text("Skriv ett helt versnummer inom surans intervall.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Gå till vers").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Stäng") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Öppna") {
                        guard let reference else { return }
                        select(reference)
                        dismiss()
                    }
                    .disabled(reference == nil)
                    .accessibilityIdentifier("reader.jump.open")
                }
            }
            .task { numberFocused = true }
        }
        .presentationDetents([.medium, .large])
    }
}

@MainActor
struct SurahPicker: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var searchIndex = SurahSearchIndex(surahs: [])
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let select: (Surah) -> Void

    var body: some View {
        let matches = filtered
        NavigationStack {
            List(matches) { surah in
                Button {
                    select(surah)
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        Text("\(surah.id)").font(.subheadline.monospacedDigit()).foregroundStyle(Palette.green)
                            .frame(minWidth: 34).fixedSize(horizontal: true, vertical: false)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(surah.englishName).foregroundStyle(.primary)
                            Text("\(surah.numberOfAyahs) verser").font(.caption).foregroundStyle(.secondary)
                            if dynamicTypeSize.isAccessibilitySize { arabicName(surah) }
                        }
                        Spacer()
                        if !dynamicTypeSize.isAccessibilitySize { arabicName(surah) }
                    }.padding(.vertical, 6)
                }
                .accessibilityIdentifier("surah.select.\(surah.id)")
            }
            .overlay {
                if matches.isEmpty && store.index != nil {
                    ContentUnavailableView("Ingen sura hittades", systemImage: "magnifyingglass",
                                           description: Text("Prova ett annat namn eller surans nummer."))
                }
            }
            .searchable(text: $search, prompt: "Namn eller surans nummer")
            .onAppear { refreshSearchIndex() }
            .onChange(of: store.index?.surahs) { _, _ in refreshSearchIndex() }
            .navigationTitle("Välj sura")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Stäng") { dismiss() } } }
        }
    }

    private func arabicName(_ surah: Surah) -> some View {
        Text(surah.name).font(.custom("AmiriQuran-Regular", size: 21, relativeTo: .title3))
            .foregroundStyle(Palette.green)
            .environment(\.layoutDirection, .rightToLeft)
            .accessibilityRepresentation { ArabicAccessibilityLabel(text: surah.name) }
    }
    private var filtered: [Surah] {
        let surahs = store.index?.surahs ?? []
        // The appearance/index-change handlers do the Unicode work once. This
        // fallback covers the first frame before those handlers have run.
        if searchIndex.surahs == surahs { return searchIndex.matching(search) }
        if search.isEmpty { return surahs }
        return SurahSearchIndex(surahs: surahs).matching(search)
    }

    private func refreshSearchIndex() {
        let surahs = store.index?.surahs ?? []
        if searchIndex.surahs != surahs { searchIndex = SurahSearchIndex(surahs: surahs) }
    }
}

/// Search keys are copies. Display names and Quran text keep their original UTF-8.
/// Preparing the index avoids refolding every sura name on each typed character.
struct SurahSearchIndex {
    let surahs: [Surah]
    private let entries: [(surah: Surah, names: [String], transliteration: String, number: String)]

    init(surahs: [Surah]) {
        self.surahs = surahs
        entries = surahs.map { surah in
            (surah, [surah.englishName, surah.name, surah.englishNameTranslation].map(Self.normalized),
             Self.transliterationKey(Self.normalized(surah.englishName)), String(surah.id))
        }
    }

    func matching(_ search: String) -> [Surah] {
        let query = Self.normalized(search)
        guard !query.isEmpty else { return surahs }
        let transliteration = Self.transliterationKey(query)
        return entries.compactMap { entry in
            entry.number == query || entry.names.contains(where: { $0.contains(query) }) ||
                entry.transliteration.contains(transliteration) ? entry.surah : nil
        }
    }

    private static func transliterationKey(_ input: String) -> String {
        var result = ""
        var previous: Unicode.Scalar?
        for scalar in input.unicodeScalars {
            if scalar == previous && [0x61, 0x65, 0x69, 0x6F, 0x75].contains(scalar.value) { continue }
            result.unicodeScalars.append(scalar)
            previous = scalar
        }
        return result
    }

    private static func normalized(_ input: String) -> String {
        let folded = input.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let scalars = folded.unicodeScalars.filter {
            !CharacterSet.nonBaseCharacters.contains($0) &&
            !CharacterSet.whitespacesAndNewlines.contains($0) &&
            !CharacterSet.punctuationCharacters.contains($0) && $0.value != 0x0640
        }
        // A normal Arabic keyboard produces alif rather than the source name's
        // alif-wasl. Treat those common search spellings alike on this copy.
        let keyboardScalars = scalars.map { scalar -> Unicode.Scalar in
            [0x0622, 0x0623, 0x0625, 0x0671].contains(scalar.value) ? Unicode.Scalar(0x0627)! : scalar
        }
        return String(String.UnicodeScalarView(keyboardScalars)).map { character in
            character.wholeNumberValue.map { String($0) } ?? String(character)
        }.joined()
    }
}

@MainActor
struct PlaybackBar: View {
    @EnvironmentObject private var player: RecitationPlayer
    @EnvironmentObject private var recorder: PracticeRecorder

    var body: some View {
        VStack(spacing: 4) {
            if let error = player.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(alignment: .center, spacing: 12) {
                Menu {
                    ForEach(Reciter.allCases) { reciter in
                        Button {
                            recorder.stopAll()
                            player.selectReciter(reciter)
                        } label: {
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
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Byt recitatör")
                .accessibilityValue(player.selectedReciter.displayName)
                Button { player.stop() } label: {
                    Image(systemName: "xmark").frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }.accessibilityLabel("Stäng spelaren")
            }
            HStack(spacing: 28) {
                Spacer(minLength: 0)
                Button { recorder.stopAll(); player.previous() } label: {
                    Image(systemName: "backward.end.fill").frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }.accessibilityLabel("Föregående vers")
                    .disabled((player.requestedReference?.ayahNumber ?? 1) <= 1)
                Button {
                    recorder.stopAll()
                    if player.isPlaying || player.isBuffering { player.pause() } else { player.resume() }
                } label: {
                    Group {
                        if player.isBuffering { ProgressView() }
                        else { Image(systemName: player.isPlaying ? "pause.fill" : "play.fill") }
                    }.frame(width: 56, height: 44).contentShape(Rectangle())
                }.accessibilityLabel(player.isPlaying || player.isBuffering ? "Pausa" : "Spela")
                    .accessibilityIdentifier("reader.playback.toggle")
                Button { recorder.stopAll(); player.next() } label: {
                    Image(systemName: "forward.end.fill").frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }.accessibilityLabel("Nästa vers")
                    .disabled(isLastVerse)
                Spacer(minLength: 0)
            }
            .font(.title3)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(.regularMaterial)
    }
    private var isLastVerse: Bool {
        guard let reference = player.requestedReference else { return true }
        return reference.ayahNumber >= AyahReference.ayahCounts[reference.surahID - 1]
    }
}
