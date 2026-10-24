import SwiftUI
import QuranCore

struct PracticeView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var player: RecitationPlayer
    @EnvironmentObject private var recorder: PracticeRecorder
    @State private var verseNumber = 1
    @State private var showSurahs = false

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
                                    player.stop()
                                    Task { await recorder.start(reference: reference) }
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
                                    Button(role: .destructive) { recorder.deleteRecording() } label: {
                                        Image(systemName: "trash").frame(width: 44, height: 44)
                                    }.accessibilityLabel("Radera inspelningen")
                                }.padding(.top, 10)
                            }
                            if let error = recorder.errorMessage {
                                ErrorBanner(message: error).padding(.top, 10)
                            }
                            if recorder.permissionDenied, let url = URL(string: UIApplication.openSettingsURLString) {
                                Link("Öppna Inställningar", destination: url).padding(.top, 10)
                            }
                        }
                    }
                } else if store.isLoading {
                    ProgressView("Öppnar suran …")
                } else if let error = store.errorMessage {
                    ErrorBanner(message: error)
                    Button("Försök igen") { Task { await store.load() } }
                }
                Card {
                    Label("Om övningen", systemImage: "info.circle").font(.headline)
                    Text("Automatisk tajweedbedömning är inte tillgänglig i den här versionen. Övningen hjälper dig att lyssna och jämföra; den ger inga uttalsbetyg eller rättningar.")
                        .font(.callout).foregroundStyle(.secondary).padding(.top, 8)
                    Text("Din röst stannar på din iPhone. Inspelningen sparas tillfälligt och ersätts när du spelar in på nytt.")
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
            recorder.deleteRecording()
            verseNumber = store.lastRead?.surahID == store.chapter?.surah.id ? (store.lastRead?.ayahNumber ?? 1) : 1
        }
        .onChange(of: verseNumber) { _, _ in
            recorder.deleteRecording()
            player.stop()
        }
        .onAppear {
            verseNumber = store.lastRead?.surahID == store.chapter?.surah.id ? (store.lastRead?.ayahNumber ?? 1) : 1
        }
        .onDisappear { recorder.stopAll() }
    }

    private func referenceControls(reference: AyahReference, chapter: QuranChapter) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Recitatör", selection: Binding(get: { player.selectedReciter }, set: { player.selectReciter($0) })) {
                ForEach(Reciter.allCases) { Text($0.displayName).tag($0) }
            }.pickerStyle(.menu)
            PrimaryButton(title: player.isPlaying && player.requestedReference == reference ? "Pausa förebilden" : "Lyssna på förebilden", icon: "headphones") {
                recorder.stopAll()
                if player.isPlaying && player.requestedReference == reference { player.pause() }
                else { player.playOnce(reference: reference, chapterVerseCount: chapter.surah.numberOfAyahs) }
            }
            if player.isBuffering { ProgressView("Hämtar recitation …") }
            if let error = player.errorMessage { ErrorBanner(message: error) }
            Text("Recitationen strömmas och behöver internet.").font(.caption).foregroundStyle(.secondary)
        }
    }
}
