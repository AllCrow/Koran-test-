import SwiftUI
import UIKit
import QuranCore

@MainActor
struct PracticeView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var player: RecitationPlayer
    @EnvironmentObject private var recorder: PracticeRecorder
    @EnvironmentObject private var assessment: RecitationAssessmentStore
    @EnvironmentObject private var audioLibrary: AudioLibrary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var verseNumber = 1
    @State private var showSurahs = false
    @State private var includeBasmala = false
    @State private var uploadError: String?
    @State private var confirmNewTake = false
    @State private var confirmDelete = false
    @State private var confirmChooseSurah = false
    @State private var pendingVerseNumber: Int?
    @State private var isVisible = false
    @State private var restoreTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Lyssna. Läs. Försök igen.")
                    .font(.system(.largeTitle, design: .serif)).foregroundStyle(Palette.green)
                Text("Öva en vers i taget med en recitatör som förebild.")
                    .foregroundStyle(.secondary)
                if let chapter = store.chapter, !isRestoringTake {
                    selectionControls(chapter: chapter)
                    if let ayah = chapter.ayahs.first(where: { $0.numberInSurah == verseNumber }),
                       let reference = ayah.reference {
                        verseCard(ayah: ayah, reference: reference)
                        referenceControls(reference: reference, chapter: chapter)
                        recordingControls(ayah: ayah, reference: reference)
                        if let feedback = assessment.response { AssessmentFeedbackView(response: feedback) }
                        if let error = assessment.errorMessage ?? uploadError { ErrorBanner(message: error) }
                    }
                } else if store.isLoading {
                    ProgressView("Öppnar suran …")
                } else if let error = store.errorMessage {
                    ErrorBanner(message: error)
                    Button("Försök igen") { restorePracticeChapter() }
                } else if isRestoringTake {
                    ProgressView("Återgår till din inspelning …")
                }
                aboutPractice
            }.padding(24)
        }
        .background(Palette.background)
        .navigationTitle("Öva").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSurahs) {
            SurahPicker { surah in
                guard surah.id != store.chapter?.surah.id, recorder.deleteRecording() else { return }
                assessment.reset()
                uploadError = nil
                player.stop()
                Task { await store.openSurah(surah.id) }
            }
        }
        .onChange(of: store.chapter?.surah.id) { _, _ in
            // The reader and practice currently share chapter selection. Browsing
            // elsewhere, including a nil loading transition, must not erase a take.
            if recorder.hasRecording || recorder.isRecording {
                if let reference = recorder.recordedReference,
                   reference.surahID == store.chapter?.surah.id {
                    verseNumber = reference.ayahNumber
                    includeBasmala = recorder.recordedIncludesBasmala
                }
                return
            }
            assessment.reset()
            uploadError = nil
            includeBasmala = false
            verseNumber = lastReadVerseNumber
        }
        .onChange(of: verseNumber) { _, _ in
            let selectedReference = store.chapter.flatMap {
                AyahReference(surahID: $0.surah.id, ayahNumber: verseNumber)
            }
            if recorder.hasRecording {
                if recorder.recordedReference == selectedReference {
                    includeBasmala = recorder.recordedIncludesBasmala
                }
            } else {
                assessment.reset()
                uploadError = nil
                includeBasmala = false
            }
            if isVisible { player.stop() }
        }
        .onChange(of: includeBasmala) { _, _ in
            assessment.reset()
            uploadError = nil
            if isVisible { player.stop() }
        }
        .onAppear {
            isVisible = true
            // Practice plays once, independently of the reading autoplay setting.
            player.stop()
            if recorder.hasRecording, let reference = recorder.recordedReference {
                verseNumber = reference.ayahNumber
                includeBasmala = recorder.recordedIncludesBasmala
                if reference.surahID != store.chapter?.surah.id { restorePracticeChapter() }
            } else {
                verseNumber = lastReadVerseNumber
            }
        }
        .onDisappear {
            isVisible = false
            restoreTask?.cancel()
            restoreTask = nil
            assessment.cancel()
            recorder.stopAll()
            player.stop()
        }
    }

    private func selectionControls(chapter: QuranChapter) -> some View {
        selectionLayout {
            Button {
                if recorder.hasRecording { confirmChooseSurah = true }
                else { showSurahs = true }
            } label: {
                Label(chapter.surah.englishName, systemImage: "book")
            }
            .frame(minHeight: 44).disabled(selectionLocked)
            .confirmationDialog("Välja en annan sura?", isPresented: $confirmChooseSurah, titleVisibility: .visible) {
                Button("Välj sura") { showSurahs = true }
                Button("Behåll tagningen", role: .cancel) { }
            } message: {
                Text("Väljer du en annan sura tas din tillfälliga inspelning bort.")
            }
            if !usesVerticalControls { Spacer() }
            Picker("Vers", selection: Binding(get: { verseNumber }, set: { selectVerse($0) })) {
                ForEach(1...chapter.surah.numberOfAyahs, id: \.self) { number in
                    Text("Vers \(number)").tag(number)
                }
            }.pickerStyle(.menu).disabled(selectionLocked)
                .confirmationDialog("Byta vers och radera tagningen?", isPresented: Binding(
                    get: { pendingVerseNumber != nil },
                    set: { if !$0 { pendingVerseNumber = nil } }
                ), titleVisibility: .visible) {
                    if let number = pendingVerseNumber {
                        Button("Byt till vers \(number)", role: .destructive) {
                            if recorder.deleteRecording() { verseNumber = number }
                            pendingVerseNumber = nil
                        }
                    }
                    Button("Behåll tagningen", role: .cancel) { pendingVerseNumber = nil }
                } message: {
                    Text("Du har en tillfällig inspelning för den valda versen. Den tas bort om du byter vers.")
                }
        }
    }

    private func verseCard(ayah: Ayah, reference: AyahReference) -> some View {
        Card {
            Text("\(reference.surahID):\(reference.ayahNumber)").font(.caption).foregroundStyle(.secondary)
            if let basmala = QuranPresentation.basmala(for: ayah) {
                Toggle("Läs även Basmala", isOn: $includeBasmala)
                    .font(.subheadline).padding(.top, 12).disabled(phraseChoiceLocked)
                Text(phraseChoiceHint)
                    .font(.caption).foregroundStyle(.secondary).padding(.top, 6)
                if includeBasmala {
                    ArabicText(text: basmala, tajweed: nil, colored: false).padding(.top, 14)
                }
            }
            ArabicText(text: QuranPresentation.verseText(ayah), tajweed: ayah.tajweed, colored: store.tajweedEnabled)
                .padding(.vertical, 14)
        }
    }

    private func recordingControls(ayah: Ayah, reference: AyahReference) -> some View {
        Card {
            Label("Din recitation", systemImage: "mic").font(.headline).accessibilityAddTraits(.isHeader)
            Text(recorder.isRecording ? "Läs lugnt i din egen takt. Inspelningen avslutas automatiskt efter en minut." : "Spela in upp till en minut och lyssna tillbaka.")
                .font(.callout).foregroundStyle(.secondary).padding(.top, 6)
            if recorder.isRecording {
                // This subtree exists only during a take. A one-second refresh
                // reads AVAudioRecorder's clock without an idle/background timer.
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    let elapsed = recorder.elapsedRecordingTime
                    let remaining = max(0, Int(ceil(PracticeRecorder.maximumRecordingDuration - elapsed)))
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(recordingClock(elapsed)) / \(recordingClock(PracticeRecorder.maximumRecordingDuration)) · \(remaining) s kvar")
                            .font(.subheadline.weight(.medium)).monospacedDigit()
                        ProgressView(value: elapsed, total: PracticeRecorder.maximumRecordingDuration)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Inspelning")
                    .accessibilityValue("\(Int(elapsed)) sekunder inspelat, \(remaining) sekunder kvar")
                }.padding(.top, 12)
            }
            PrimaryButton(
                title: recorder.isRecording ? "Avsluta inspelning" : (recorder.isRequestingPermission ? "Väntar på mikrofon …" : "Spela in min recitation"),
                icon: recorder.isRecording ? "stop.fill" : "mic.fill"
            ) {
                if recorder.isRecording { recorder.finishRecordingIfNeeded() }
                else if recorder.hasRecording { confirmNewTake = true }
                else { beginRecording(reference: reference) }
            }.padding(.top, 16).disabled(recorder.isRequestingPermission)
                .confirmationDialog("Spela in en ny tagning?", isPresented: $confirmNewTake, titleVisibility: .visible) {
                    Button("Spela in en ny tagning", role: .destructive) { beginRecording(reference: reference) }
                    Button("Behåll tagningen", role: .cancel) { }
                } message: {
                    Text("Din nuvarande tagning ersätts när den nya inspelningen startar.")
                }
            if recorder.hasRecording && !recorder.isRequestingPermission && !recorder.isRecording && recorder.recordedReference == reference {
                savedTakeControls
                if assessment.isAvailable { assessmentControls(ayah: ayah) }
            }
            if let error = recorder.errorMessage { ErrorBanner(message: error).padding(.top, 10) }
            if recorder.permissionDenied, let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Öppna Inställningar", destination: url).padding(.top, 10)
            }
        }
    }

    private var savedTakeControls: some View {
        selectionLayout {
            Button {
                player.stop()
                if recorder.isPlaying { recorder.stopPlayback() } else { recorder.playRecording() }
            } label: {
                Label(recorder.isPlaying ? "Stoppa" : "Lyssna på mig", systemImage: recorder.isPlaying ? "stop.fill" : "play.fill")
            }.buttonStyle(.bordered).frame(minHeight: 44)
            if !usesVerticalControls { Spacer() }
            Button(role: .destructive) { confirmDelete = true } label: {
                Image(systemName: "trash").frame(width: 44, height: 44)
            }.accessibilityLabel("Radera inspelningen")
                .confirmationDialog("Radera inspelningen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Radera inspelningen", role: .destructive) {
                        assessment.reset()
                        uploadError = nil
                        recorder.deleteRecording()
                    }
                    Button("Behåll tagningen", role: .cancel) { }
                } message: {
                    Text("Den här tagningen tas bort från din iPhone.")
                }
        }.padding(.top, 10)
    }

    private func referenceControls(reference: AyahReference, chapter: QuranChapter) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Recitatör", selection: Binding(get: { player.selectedReciter }, set: { reciter in
                guard reciter != player.selectedReciter else { return }
                recorder.stopAll()
                player.selectReciter(reciter)
            })) {
                ForEach(Reciter.allCases) { Text($0.displayName).tag($0) }
            }.pickerStyle(.menu).disabled(recorder.isRecording || recorder.isRequestingPermission)
            PrimaryButton(title: canPause(reference) ? "Pausa förebilden" : "Lyssna på förebilden", icon: "headphones") {
                recorder.stopAll()
                if player.requestedReference == reference {
                    if canPause(reference) { player.pause() } else { player.resume() }
                } else {
                    player.playOnce(reference: reference, chapterVerseCount: chapter.surah.numberOfAyahs)
                }
            }
            if player.isBuffering { ProgressView("Hämtar recitation …") }
            if let error = player.errorMessage { ErrorBanner(message: error) }
            Text(audioLibrary.localURL(for: reference, reciter: player.selectedReciter) != nil
                 ? "Den här versens ljud finns sparat och kan spelas offline."
                 : "Ljudet strömmas från internet. Spara suror för offline-lyssning under Mitt.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func assessmentControls(ayah: Ayah) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("När du väljer Analysera skickas inspelningen för den här versen till analystjänsten. Funktionen är experimentell.")
                .font(.caption).foregroundStyle(.secondary)
            if assessment.isAssessing {
                ProgressView("Analyserar recitation …")
                Button("Avbryt analys") { assessment.cancel() }
            } else {
                Button {
                    do {
                        guard recorder.recordedReference == ayah.reference else {
                            throw PracticeRecorder.RecordingDataError.missingRecording
                        }
                        let audio = try recorder.recordingData()
                        uploadError = nil
                        assessment.beginAssessment(audioData: audio, ayah: ayah, includeBasmala: recorder.recordedIncludesBasmala)
                    } catch { uploadError = error.localizedDescription }
                } label: { Label("Analysera min recitation", systemImage: "waveform") }
                    .buttonStyle(.bordered).frame(minHeight: 44)
            }
        }.padding(.top, 16)
    }

    private var aboutPractice: some View {
        Card {
            Label("Om övningen", systemImage: "info.circle").font(.headline)
            Text(assessment.isAvailable
                 ? "Den automatiska återkopplingen är en testfunktion. Modellen kan missa fel och ge felaktiga markeringar. Den är inte verifierad som ersättning för en kunnig lärare."
                 : "Automatisk tajweedbedömning är inte tillgänglig i den här versionen. Övningen hjälper dig att lyssna och jämföra; den ger inga uttalsbetyg eller rättningar.")
                .font(.callout).foregroundStyle(.secondary).padding(.top, 8)
            Text(assessment.isAvailable
                 ? "Ingen röst laddas upp automatiskt. När du väljer Analysera skickas din valda inspelning till analystjänsten."
                 : "Din röst stannar på din iPhone. Inspelningen sparas tillfälligt och ersätts när du spelar in på nytt.")
                .font(.caption).foregroundStyle(.secondary).padding(.top, 8)
        }
    }

    private var isRestoringTake: Bool {
        recorder.hasRecording && recorder.recordedReference?.surahID != store.chapter?.surah.id
    }

    private func restorePracticeChapter() {
        restoreTask?.cancel()
        let reference = recorder.hasRecording ? recorder.recordedReference : nil
        restoreTask = Task { @MainActor in
            guard !Task.isCancelled, isVisible else { return }
            if let reference {
                guard recorder.hasRecording, recorder.recordedReference == reference else { return }
                await store.openSurah(reference.surahID)
            } else {
                await store.load()
            }
        }
    }

    private var selectionLayout: AnyLayout {
        usesVerticalControls
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
    }

    private var usesVerticalControls: Bool { dynamicTypeSize >= .xxLarge }

    private var selectionLocked: Bool {
        recorder.isRecording || recorder.isRequestingPermission || assessment.isAssessing
    }

    private var lastReadVerseNumber: Int {
        store.lastRead?.surahID == store.chapter?.surah.id ? (store.lastRead?.ayahNumber ?? 1) : 1
    }

    private func selectVerse(_ number: Int) {
        guard number != verseNumber else { return }
        if recorder.hasRecording { pendingVerseNumber = number }
        else { verseNumber = number }
    }

    private func beginRecording(reference: AyahReference) {
        assessment.reset()
        uploadError = nil
        player.stop()
        recorder.beginRecording(reference: reference, includeBasmala: includeBasmala)
    }

    private var phraseChoiceLocked: Bool {
        recorder.hasRecording || recorder.isRecording || recorder.isRequestingPermission || assessment.isAssessing
    }

    private var phraseChoiceHint: String {
        if recorder.hasRecording {
            return "Valet hör till din inspelning. Radera inspelningen för att ändra det."
        }
        if recorder.isRecording || recorder.isRequestingPermission {
            return "Läs frasen du valde innan inspelningen startade."
        }
        return "Välj före inspelningen. Recitatörens ljudklipp kan börja direkt med versen."
    }

    private func canPause(_ reference: AyahReference) -> Bool {
        player.requestedReference == reference && (player.isPlaying || player.isBuffering)
    }

    private func recordingClock(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
