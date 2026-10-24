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
    @State private var verseNumber = 1
    @State private var showSurahs = false
    @State private var includeBasmala = true
    @State private var uploadError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Lyssna. Läs. Försök igen.")
                    .font(.system(.largeTitle, design: .serif)).foregroundStyle(Palette.green)
                Text("Öva en vers i taget med en recitatör som förebild.")
                    .foregroundStyle(.secondary)
                if let chapter = store.chapter {
                    HStack {
                        Button { showSurahs = true } label: {
                            Label(chapter.surah.englishName, systemImage: "book")
                        }
                        Spacer()
                        Picker("Vers", selection: $verseNumber) {
                            ForEach(1...chapter.surah.numberOfAyahs, id: \.self) { number in
                                Text("Vers \(number)").tag(number)
                            }
                        }.pickerStyle(.menu)
                    }
                    if let ayah = chapter.ayahs.first(where: { $0.numberInSurah == verseNumber }),
                       let reference = ayah.reference {
                        Card {
                            Text("\(reference.surahID):\(reference.ayahNumber)").font(.caption).foregroundStyle(.secondary)
                            if let basmala = QuranPresentation.basmala(for: ayah) {
                                ArabicText(text: basmala, tajweed: nil, colored: false).padding(.top, 14)
                            }
                            ArabicText(text: QuranPresentation.verseText(ayah), tajweed: ayah.tajweed, colored: store.tajweedEnabled)
                                .padding(.vertical, 14)
                        }
                        referenceControls(reference: reference, chapter: chapter)
                        Card {
                            Label("Din recitation", systemImage: "mic").font(.headline)
                            Text(recorder.isRecording ? "Inspelning pågår. Läs lugnt i din egen takt." : "Spela in upp till en minut och lyssna tillbaka.")
                                .font(.callout).foregroundStyle(.secondary).padding(.top, 6)
                            PrimaryButton(
                                title: recorder.isRecording ? "Avsluta inspelning" : (recorder.isRequestingPermission ? "Väntar på mikrofon …" : "Spela in min recitation"),
                                icon: recorder.isRecording ? "stop.fill" : "mic.fill"
                            ) {
                                if recorder.isRecording { recorder.finishRecordingIfNeeded() }
                                else {
                                    assessment.reset()
                                    uploadError = nil
                                    player.stop()
                                    recorder.beginRecording(reference: reference)
                                }
                            }.padding(.top, 16).disabled(recorder.isRequestingPermission)
                            if recorder.hasRecording && recorder.recordedReference == reference {
                                HStack {
                                    Button {
                                        player.stop()
                                        if recorder.isPlaying { recorder.stopPlayback() } else { recorder.playRecording() }
                                    } label: {
                                        Label(recorder.isPlaying ? "Stoppa" : "Lyssna på mig", systemImage: recorder.isPlaying ? "stop.fill" : "play.fill")
                                    }.buttonStyle(.bordered).frame(minHeight: 44)
                                    Spacer()
                                    Button(role: .destructive) { assessment.reset(); recorder.deleteRecording() } label: {
                                        Image(systemName: "trash").frame(width: 44, height: 44)
                                    }.accessibilityLabel("Radera inspelningen")
                                }.padding(.top, 10)
                                if assessment.isAvailable {
                                    assessmentControls(ayah: ayah)
                                }
                            }
                            if let error = recorder.errorMessage {
                                ErrorBanner(message: error).padding(.top, 10)
                            }
                            if recorder.permissionDenied, let url = URL(string: UIApplication.openSettingsURLString) {
                                Link("Öppna Inställningar", destination: url).padding(.top, 10)
                            }
                        }
                        if let feedback = assessment.response { AssessmentFeedbackView(response: feedback) }
                        if let error = assessment.errorMessage ?? uploadError { ErrorBanner(message: error) }
                    }
                } else if store.isLoading {
                    ProgressView("Öppnar suran …")
                } else if let error = store.errorMessage {
                    ErrorBanner(message: error)
                    Button("Försök igen") { Task { await store.load() } }
                }
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
            }.padding(24)
        }
        .background(Palette.background)
        .navigationTitle("Öva").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSurahs) {
            SurahPicker { surah in
                recorder.deleteRecording()
                player.stop()
                Task { await store.openSurah(surah.id) }
            }
        }
        .onChange(of: store.chapter?.surah.id) { _, _ in
            assessment.reset()
            recorder.deleteRecording()
            verseNumber = store.lastRead?.surahID == store.chapter?.surah.id ? (store.lastRead?.ayahNumber ?? 1) : 1
        }
        .onChange(of: verseNumber) { _, _ in
            assessment.reset()
            uploadError = nil
            recorder.deleteRecording()
            player.stop()
        }
        .onAppear {
            // A practice reference must play once, even if normal reading was
            // already playing this same verse with autoplay enabled.
            player.stop()
            verseNumber = store.lastRead?.surahID == store.chapter?.surah.id ? (store.lastRead?.ayahNumber ?? 1) : 1
        }
        .onDisappear {
            assessment.cancel()
            recorder.stopAll()
            player.stop()
        }
    }

    private func referenceControls(reference: AyahReference, chapter: QuranChapter) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Recitatör", selection: Binding(get: { player.selectedReciter }, set: { player.selectReciter($0) })) {
                ForEach(Reciter.allCases) { Text($0.displayName).tag($0) }
            }.pickerStyle(.menu)
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
            if QuranPresentation.basmala(for: ayah) != nil {
                Toggle("Ta med Basmala i övningen", isOn: $includeBasmala)
                    .onChange(of: includeBasmala) { _, _ in assessment.reset() }
            }
            Text("När du väljer Analysera skickas inspelningen för den här versen till analystjänsten. Funktionen är experimentell.")
                .font(.caption).foregroundStyle(.secondary)
            if assessment.isAssessing {
                ProgressView("Analyserar recitation …")
                Button("Avbryt analys") { assessment.cancel() }
            } else {
                Button {
                    do {
                        let audio = try recorder.recordingData()
                        let withBasmala = QuranPresentation.basmala(for: ayah) != nil && includeBasmala
                        uploadError = nil
                        assessment.beginAssessment(audioData: audio, ayah: ayah, includeBasmala: withBasmala)
                    } catch { uploadError = error.localizedDescription }
                } label: { Label("Analysera min recitation", systemImage: "waveform") }
                    .buttonStyle(.bordered).frame(minHeight: 44)
            }
        }.padding(.top, 16)
    }

    private func canPause(_ reference: AyahReference) -> Bool {
        player.requestedReference == reference && (player.isPlaying || player.isBuffering)
    }
}
