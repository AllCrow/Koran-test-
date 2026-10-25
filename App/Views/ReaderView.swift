import SwiftUI
import QuranCore

@MainActor
struct ReaderView: View {
    var initialReference: AyahReference? = nil
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var player: RecitationPlayer
    @EnvironmentObject private var recorder: PracticeRecorder
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSurahs = false
    @State private var showLegend = false
    @State private var showVerseSearch = false
    @State private var searchSelection: AyahReference?
    @State private var searchNavigationTask: Task<Void, Never>?
    @State private var searchNavigationID = UUID()
    @State private var issueAyah: Ayah?
    @State private var isReaderVisible = false
    @State private var tracksManualScrolling = false
    @State private var manualCandidate: AyahReference?
    @State private var viewportHeight: CGFloat = 0
    @State private var verseFrames: [ReadingVerseFrame] = []
    @State private var tafsirReference: AyahReference?
    @State private var showVerseJump = false
    @State private var showRepeatPlayback = false
    @State private var showPracticeQueueError = false
    @State private var practiceQueueErrorMessage = ""
    @State private var prefersLatestReadingPosition = false
    @State private var pendingJumpReference: AyahReference?
    @State private var scrollRequest: ScrollRequest?

    private struct ScrollRequest {
        let id = UUID()
        let targetID: String
        let anchor: UnitPoint
    }

    var body: some View {
        ScrollViewReader { proxy in
            trackedReaderList
            .task(id: store.chapter?.surah.id) {
                guard store.chapter != nil else { return }
                await Task.yield()
                guard !Task.isCancelled else { return }
                requestScroll(to: preferredReference?.id ?? "chapter-heading", anchor: .top)
            }
            .task(id: scrollRequest?.id) {
                guard let request = scrollRequest else { return }
                // Each command has its own identity, including a repeat jump
                // to the same verse. Native cells resolve the target by row.
                await Task.yield()
                guard !Task.isCancelled else { return }
                proxy.scrollTo(request.targetID, anchor: request.anchor)
            }
            .onAppear {
                if let reference = preferredReference {
                    requestScroll(to: reference.id, anchor: .top)
                }
            }
            .onChange(of: player.activeReference) { _, reference in
                guard let reference, reference.surahID == store.chapter?.surah.id else { return }
                prefersLatestReadingPosition = true
                store.setLastRead(reference)
                // Each new recitation begins at the start of its verse. A long
                // Arabic card can exceed the viewport, so centering it would
                // hide its opening while that opening is being recited.
                requestScroll(to: reference.id, anchor: .top)
            }
            .sheet(isPresented: $showVerseJump, onDismiss: {
                guard let reference = pendingJumpReference else { return }
                pendingJumpReference = nil
                guard reference.surahID == store.chapter?.surah.id else { return }
                // Resolve the native row after the keyboard/sheet viewport
                // has been restored, using the same path as reading recovery.
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
        .onAppear { isReaderVisible = true }
        .onDisappear {
            saveManualPosition()
            isReaderVisible = false
            prepareExplicitReaderAction()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { saveManualPosition(); prepareExplicitReaderAction() }
        }
        .navigationTitle("Koranen").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { prepareExplicitReaderAction(); showSurahs = true } label: { Label("Välj sura", systemImage: "list.bullet") }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { prepareExplicitReaderAction(); searchSelection = nil; showVerseSearch = true } label: {
                        Label("Sök i korantexten", systemImage: "magnifyingglass")
                    }
                    .accessibilityIdentifier("reader.search.present")
                    Button { prepareExplicitReaderAction(); pendingJumpReference = nil; showVerseJump = true } label: {
                        Label("Gå till vers", systemImage: "number")
                    }
                    .disabled(store.chapter == nil)
                    .accessibilityIdentifier("reader.jump.present")
                    Button { prepareExplicitReaderAction(); showRepeatPlayback = true } label: {
                        Label("Repetera verser", systemImage: "repeat")
                    }
                    .disabled(store.chapter == nil)
                    .accessibilityIdentifier("reader.repeat.present")
                    Picker("Arabisk textstorlek", selection: Binding(get: { store.arabicTextSize }, set: { store.setArabicTextSize($0) })) {
                        ForEach(AppStore.ArabicTextSize.allCases) { size in
                            Text(size.displayName).tag(size)
                        }
                    }
                    Toggle("Tajweedfärger", isOn: Binding(get: { store.tajweedEnabled }, set: { store.setTajweedEnabled($0) }))
                    Toggle("Visa färgförklaring", isOn: $showLegend)
                    Toggle("Fortsätt till nästa vers", isOn: $player.autoplay)
                } label: { Label("Läsinställningar", systemImage: "slider.horizontal.3") }
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
        .sheet(item: $issueAyah) { ayah in
            ContentIssueReportView(ayah: ayah, tajweedEnabled: store.tajweedEnabled, reciter: player.reciter)
        }
        .sheet(isPresented: $showVerseSearch, onDismiss: {
            guard let reference = searchSelection else { return }
            searchSelection = nil
            recorder.stopAll()
            player.stop()
            cancelSearchNavigation()
            let requestID = searchNavigationID
            searchNavigationTask = Task { @MainActor in
                await store.openSurah(reference.surahID)
                guard !Task.isCancelled, searchNavigationID == requestID, player.requestedReference == nil,
                      store.chapter?.surah.id == reference.surahID else { return }
                prefersLatestReadingPosition = true
                store.setLastRead(reference)
                requestScroll(to: reference.id, anchor: .top)
            }
        }) {
            VerseSearchSheet { reference in searchSelection = reference }
        }
        .sheet(isPresented: $showRepeatPlayback) {
            if let chapter = store.chapter {
                RepeatPlaybackSheet(surah: chapter.surah, initialVerse: preferredReference?.ayahNumber ?? 1)
            }
        }
        .alert("Övningskön kunde inte ändras", isPresented: $showPracticeQueueError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(practiceQueueErrorMessage)
        }
    }

    private var trackedReaderList: some View {
        readerList
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.vertical, 12, for: .scrollContent)
            .id(store.chapter?.surah.id)
            .coordinateSpace(name: "reader.viewport")
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(key: ReaderViewportHeightKey.self, value: geometry.size.height)
                }
            }
            .onPreferenceChange(ReaderViewportHeightKey.self) { height in
                viewportHeight = height
                updateManualCandidate()
            }
            .onPreferenceChange(ReaderVerseFramesKey.self) { frames in
                verseFrames = frames
                updateManualCandidate()
            }
            .simultaneousGesture(DragGesture(minimumDistance: 10).onChanged { _ in
                guard mayTrackManualPosition else { return }
                tracksManualScrolling = true
                updateManualCandidate()
            })
            .task(id: manualCandidate) {
                guard manualCandidate != nil else { return }
                do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
                guard !Task.isCancelled else { return }
                saveManualPosition()
            }
            .onChange(of: store.lastRead) { _, reference in
                // Explicit reading/listening/import wins over a queued scroll save.
                if reference != manualCandidate { stopTrackingManualPosition() }
            }
            .onChange(of: player.requestedReference) { _, _ in stopTrackingManualPosition() }
            .onChange(of: showVerseJump) { _, _ in cancelSearchNavigation(); stopTrackingManualPosition() }
            .onChange(of: showSurahs) { _, _ in cancelSearchNavigation(); stopTrackingManualPosition() }
            .onChange(of: showVerseSearch) { _, shown in
                if shown { cancelSearchNavigation() }
                stopTrackingManualPosition()
            }
            .onChange(of: issueAyah) { _, _ in stopTrackingManualPosition() }
            .onChange(of: tafsirReference) { _, _ in stopTrackingManualPosition() }
            .onChange(of: showRepeatPlayback) { _, _ in stopTrackingManualPosition() }
    }

    @ViewBuilder
    private var readerList: some View {
        // Keep the chapter's individually identified rows directly in List.
        // Native cell reuse preserves continuous reading, while navigation
        // identifies a row instead of calculating its offset in Arabic text.
        if let chapter = store.chapter {
            List {
                chapterHeading(chapter).modifier(ReaderRowStyle()).id("chapter-heading")
                if let basmala = QuranPresentation.basmala(for: chapter) {
                    ArabicText(text: basmala, tajweed: nil, colored: false)
                        .padding(.vertical, 12).padding(.horizontal, 8)
                        .modifier(ReaderRowStyle())
                }
                if showLegend && store.tajweedEnabled {
                    Card { TajweedLegend() }.modifier(ReaderRowStyle())
                }
                ForEach(chapter.ayahs, id: \.readerScrollID) { ayah in
                    verseCard(ayah, chapter: chapter)
                        .modifier(ReaderRowStyle()).id(ayah.readerScrollID)
                }
                if let next = store.index?.surahs.first(where: { $0.id == chapter.surah.id + 1 }) {
                    nextSurahCard(next).modifier(ReaderRowStyle())
                }
                Text("Arabisk text: Tanzil.net via AlQuran Cloud. Läsningen följer Hafs-numrering.")
                    .font(.caption).foregroundStyle(.secondary).padding(.vertical, 12)
                    .modifier(ReaderRowStyle())
                readerError
            }
        } else {
            List {
                if store.isLoading {
                    ProgressView("Öppnar Koranen …").padding(50).modifier(ReaderRowStyle())
                }
                readerError
            }
        }
    }

    @ViewBuilder
    private var readerError: some View {
        if let error = store.errorMessage {
            ErrorBanner(message: error).modifier(ReaderRowStyle())
            Button("Försök igen") { Task { await store.load() } }
                .frame(minHeight: 44)
                .accessibilityIdentifier("reader.retry")
                .modifier(ReaderRowStyle())
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

    /// A bookmark sets the first position. After playback or an explicit jump, later
    /// reading/listening actions keep their newer saved position on return.
    private var preferredReference: AyahReference? {
        let chapterID = store.chapter?.surah.id
        if prefersLatestReadingPosition, let lastRead = store.lastRead, lastRead.surahID == chapterID { return lastRead }
        if let initialReference, initialReference.surahID == chapterID { return initialReference }
        if let lastRead = store.lastRead, lastRead.surahID == chapterID { return lastRead }
        return nil
    }

    private func requestScroll(to targetID: String, anchor: UnitPoint) {
        stopTrackingManualPosition()
        scrollRequest = ScrollRequest(targetID: targetID, anchor: anchor)
    }

    private func prepareExplicitReaderAction() {
        cancelSearchNavigation()
        stopTrackingManualPosition()
    }

    private func cancelSearchNavigation() {
        searchNavigationTask?.cancel()
        searchNavigationTask = nil
        searchNavigationID = UUID()
    }

    private var mayTrackManualPosition: Bool { maySaveManualPosition && scenePhase == .active }

    private var maySaveManualPosition: Bool {
        isReaderVisible && !store.isLoading
            && !showSurahs && !showVerseJump && !showVerseSearch && !showRepeatPlayback
            && tafsirReference == nil && issueAyah == nil
            && !player.isPlaying && !player.isBuffering && !player.isWaitingBetweenVerses
    }

    private func updateManualCandidate() {
        guard tracksManualScrolling, mayTrackManualPosition, let chapter = store.chapter else { return }
        manualCandidate = ReadingViewport.leadingReference(in: verseFrames, surahID: chapter.surah.id,
                                                           height: Double(viewportHeight))
    }

    private func saveManualPosition() {
        guard tracksManualScrolling, maySaveManualPosition, let reference = manualCandidate,
              reference.surahID == store.chapter?.surah.id else { return }
        // Save a reading place only. Scrolling never marks a verse as completed.
        prefersLatestReadingPosition = true
        store.setLastRead(reference)
    }

    private func stopTrackingManualPosition() {
        tracksManualScrolling = false
        manualCandidate = nil
    }

    private func nextSurahCard(_ surah: Surah) -> some View {
        Card {
            Text("Nästa sura").font(.subheadline).foregroundStyle(.secondary)
            Text(surah.englishName).font(.system(.title2, design: .serif))
                .foregroundStyle(Palette.green).padding(.top, 6)
            PrimaryButton(title: "Fortsätt läsa", icon: "arrow.right") {
                prepareExplicitReaderAction()
                recorder.stopAll()
                player.stop()
                prefersLatestReadingPosition = true
                Task { @MainActor in
                    await store.openSurah(surah.id)
                    guard store.chapter?.surah.id == surah.id,
                          let reference = AyahReference(surahID: surah.id, ayahNumber: 1) else { return }
                    // Navigation saves a position but never completes a verse.
                    store.setLastRead(reference)
                    requestScroll(to: reference.id, anchor: .top)
                }
            }
            .padding(.top, 16)
            .accessibilityIdentifier("reader.nextSurah.\(surah.id)")
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
                    // A container identifier propagates to SwiftUI children
                    // and masks the action buttons' individual identifiers.
                    .accessibilityIdentifier("reader.verse.\(chapter.surah.id).\(ayah.numberInSurah)")
                if active {
                    Label(player.isWaitingBetweenVerses ? "Paus mellan verser" : (player.isPlaying ? "Spelas nu" : "Pausad"), systemImage: "speaker.wave.2")
                        .font(.caption).foregroundStyle(Palette.green)
                }
                Spacer()
                if loading { ProgressView().accessibilityLabel("Laddar recitation") }
                if let reference, store.isReadToday(reference) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.green)
                        .accessibilityLabel("Läst idag")
                }
                if let reference {
                    Menu {
                        Button {
                            prepareExplicitReaderAction()
                            prefersLatestReadingPosition = true
                            store.setLastRead(reference)
                        } label: {
                            Label("Spara läsplats här", systemImage: "book.closed")
                        }
                        .accessibilityIdentifier("reader.savePosition.\(reference.surahID).\(reference.ayahNumber)")
                        Button { prepareExplicitReaderAction(); issueAyah = ayah } label: {
                            Label("Granska innehåll", systemImage: "exclamationmark.bubble")
                        }
                        .accessibilityIdentifier("reader.report.\(reference.surahID).\(reference.ayahNumber)")
                    } label: {
                        Image(systemName: "ellipsis").frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Versalternativ för \(reference.id)")
                    .accessibilityIdentifier("reader.verseOptions.\(reference.surahID).\(reference.ayahNumber)")
                }
            }
            ArabicText(text: QuranPresentation.verseText(ayah), tajweed: ayah.tajweed, colored: store.tajweedEnabled)
                .padding(.vertical, 18)
            if let reference {
                verseActions(reference, verseCount: chapter.surah.numberOfAyahs)
            }
        }
        .background {
            GeometryReader { geometry in
                let frame = geometry.frame(in: .named("reader.viewport"))
                Color.clear.preference(key: ReaderVerseFramesKey.self, value: reference.map {
                    [ReadingVerseFrame(reference: $0, minY: Double(frame.minY), maxY: Double(frame.maxY))]
                } ?? [])
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24).strokeBorder(active ? Palette.green : .clear, lineWidth: 2)
        }
        .contextMenu {
            if let reference {
                Button {
                    let adding = !store.isQueuedForPractice(reference)
                    if !store.togglePracticeQueue(reference) {
                        practiceQueueErrorMessage = adding && store.practiceQueue.count >= AppStore.maximumPracticeQueueCount
                            ? "Kön rymmer högst \(AppStore.maximumPracticeQueueCount) verser. Ta bort någon vers ur kön och försök igen."
                            : "Ändringen kunde inte sparas. Din tidigare övningskö finns kvar. Försök igen."
                        showPracticeQueueError = true
                    }
                } label: {
                    Label(store.isQueuedForPractice(reference) ? "Ta bort från övningskön" : "Öva igen", systemImage: "text.badge.plus")
                }
                .accessibilityIdentifier("reader.practiceQueue.\(reference.surahID).\(reference.ayahNumber)")
                Button { prepareExplicitReaderAction(); issueAyah = ayah } label: {
                    Label("Granska innehåll", systemImage: "exclamationmark.bubble")
                }
                .accessibilityIdentifier("reader.report.\(reference.surahID).\(reference.ayahNumber)")
            }
        }
    }

    @ViewBuilder
    private func verseActions(_ reference: AyahReference, verseCount: Int) -> some View {
        // At accessibility sizes each action gets its own growing row. Keep
        // both the icon and label readable instead of clipping a scaled glyph
        // into a fixed square or compressing four controls into a narrow card.
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                verseActionButtons(reference, verseCount: verseCount, expanded: true)
            }
            .buttonStyle(.plain).foregroundStyle(Palette.green)
        } else {
            HStack(spacing: 8) {
                verseActionButtons(reference, verseCount: verseCount, expanded: false)
            }
            .buttonStyle(.plain).foregroundStyle(Palette.green)
        }
    }

    @ViewBuilder
    private func verseActionButtons(_ reference: AyahReference, verseCount: Int, expanded: Bool) -> some View {
        let requested = player.requestedReference == reference
        let canPause = requested && (player.isPlaying || player.isBuffering || player.isWaitingBetweenVerses)
        let bookmarked = store.bookmarks.contains(reference)
        let readToday = store.isReadToday(reference)
        Button {
            prepareExplicitReaderAction()
            prefersLatestReadingPosition = true
            recorder.stopAll()
            if requested && !player.repetitionComplete {
                if canPause { player.pause() } else { player.resume() }
            } else {
                player.play(reference: reference, chapterVerseCount: verseCount)
            }
            store.setLastRead(reference)
        } label: {
            verseActionLabel(canPause ? "Pausa" : "Lyssna", icon: canPause ? "pause.fill" : "play.fill", expanded: expanded)
        }
        .accessibilityLabel(canPause ? "Pausa versen" : "Lyssna på vers \(reference.ayahNumber)")
        .accessibilityIdentifier("reader.listen.\(reference.surahID).\(reference.ayahNumber)")
        Button { store.toggleBookmark(reference) } label: {
            verseActionLabel(bookmarked ? "Ta bort bokmärke" : "Spara bokmärke", icon: bookmarked ? "bookmark.fill" : "bookmark", expanded: expanded)
        }
        .accessibilityLabel(bookmarked ? "Ta bort bokmärke" : "Spara bokmärke")
        .accessibilityIdentifier("reader.bookmark.\(reference.surahID).\(reference.ayahNumber)")
        Button { prepareExplicitReaderAction(); tafsirReference = reference } label: {
            if expanded {
                verseActionLabel("Tafsir", icon: "text.book.closed", expanded: true)
            } else {
                Text("Tafsir").font(.subheadline).frame(minWidth: 44, minHeight: 44)
            }
        }
        .accessibilityLabel("Tafsir för vers \(reference.ayahNumber)")
        .accessibilityIdentifier("reader.tafsir.\(reference.surahID).\(reference.ayahNumber)")
        if !expanded { Spacer(minLength: 0) }
        Button {
            prepareExplicitReaderAction()
            prefersLatestReadingPosition = true
            store.markRead(reference)
        } label: {
            verseActionLabel(readToday ? "Läst idag" : "Markera som läst", icon: readToday ? "checkmark.circle.fill" : "checkmark.circle", expanded: expanded)
        }
        .accessibilityLabel(readToday ? "Redan läst idag" : "Markera vers \(reference.ayahNumber) som läst")
        .disabled(readToday)
        .accessibilityIdentifier("reader.markRead.\(reference.surahID).\(reference.ayahNumber)")
    }

    private func verseActionLabel(_ title: String, icon: String, expanded: Bool) -> some View {
        Group {
            if expanded {
                Label(title, systemImage: icon)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Image(systemName: icon)
            }
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
    }
}

private struct ReaderVerseFramesKey: PreferenceKey {
    static let defaultValue: [ReadingVerseFrame] = []
    static func reduce(value: inout [ReadingVerseFrame], nextValue: () -> [ReadingVerseFrame]) {
        value.append(contentsOf: nextValue())
    }
}

private struct ReaderViewportHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct ReaderRowStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
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
    @Environment(\.scenePhase) private var scenePhase
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
            if let loop = player.repetition {
                Text(repetitionSummary(loop))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("reader.repeat.status")
            }
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
                    Image(systemName: "xmark").frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }.accessibilityLabel("Stäng spelaren")
                    .accessibilityIdentifier("reader.playback.stop")
            }
            HStack(spacing: 28) {
                Spacer(minLength: 0)
                Button { recorder.stopAll(); player.previous() } label: {
                    Image(systemName: "backward.end.fill").frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }.accessibilityLabel("Föregående vers")
                    .disabled((player.requestedReference?.ayahNumber ?? 1) <= (player.repetition?.startVerse ?? 1))
                Button {
                    recorder.stopAll()
                    if player.isPlaying || player.isBuffering || player.isWaitingBetweenVerses { player.pause() } else { player.resume() }
                } label: {
                    Group {
                        if player.isBuffering { ProgressView() }
                        else { Image(systemName: player.isPlaying || player.isWaitingBetweenVerses ? "pause.fill" : "play.fill") }
                    }.frame(minWidth: 56, minHeight: 44).contentShape(Rectangle())
                }.accessibilityLabel(player.isPlaying || player.isBuffering || player.isWaitingBetweenVerses ? "Pausa" : (player.repetitionComplete ? "Spela igen" : "Spela"))
                    .accessibilityIdentifier("reader.playback.toggle")
                Button { recorder.stopAll(); player.next() } label: {
                    Image(systemName: "forward.end.fill").frame(minWidth: 44, minHeight: 44)
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
        return reference.ayahNumber >= (player.repetition?.endVerse ?? AyahReference.ayahCounts[reference.surahID - 1])
    }

    private func repetitionSummary(_ loop: RecitationLoop) -> String {
        let range = "Vers \(loop.surahID):\(loop.startVerse)–\(loop.endVerse)"
        if player.repetitionComplete { return "\(range) · Repetitionspasset är klart" }
        let cycle = "\(player.repetitionCycle) av \(loop.cycles)"
        return "\(range) · Omgång \(cycle)" + (player.isWaitingBetweenVerses ? " · Paus mellan verser" : "")
    }
}
