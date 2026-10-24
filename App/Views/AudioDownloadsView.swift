import QuranCore
import SwiftUI

@MainActor
struct AudioDownloadsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var player: RecitationPlayer
    @EnvironmentObject private var recorder: PracticeRecorder
    @EnvironmentObject private var audioLibrary: AudioLibrary
    @State private var selectedSurahID = 1
    @State private var selectedReciter: Reciter = .alafasy
    @State private var downloadedCount = 0
    @State private var initializedSelection = false
    @State private var showSurahs = false
    @State private var confirmDeletion = false

    var body: some View {
        List {
            Section {
                Label("Lyssna utan internet", systemImage: "arrow.down.circle")
                    .font(.headline)
                    .foregroundStyle(Palette.green)
                Text("Spara en sura med den recitatör du vill lyssna på. Sparat ljud används sedan automatiskt när du spelar verserna.")
                    .font(.callout)
                Text("Nedladdning kräver internet och kan använda mobildata.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if let surah = selectedSurah {
                Section("Välj ljud") {
                    Button { showSurahs = true } label: {
                        HStack {
                            Text("Sura").foregroundStyle(.primary)
                            Spacer()
                            Text(surah.englishName)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption).foregroundStyle(.secondary)
                        }.frame(minHeight: 44)
                    }
                    .accessibilityLabel("Välj sura")
                    .accessibilityValue(surah.englishName)
                    .disabled(isDownloading)

                    Picker("Recitatör", selection: $selectedReciter) {
                        ForEach(Reciter.allCases) { reciter in
                            Text(reciter.displayName).tag(reciter)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(isDownloading)
                }

                Section("På din iPhone") {
                    LabeledContent("Sparade verser", value: "\(visibleDownloadedCount) av \(surah.numberOfAyahs)")
                    if visibleDownloadedCount == surah.numberOfAyahs {
                        Label("Hela suran är tillgänglig offline", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Palette.green)
                            .font(.callout)
                    } else if visibleDownloadedCount > 0 && !isDownloading {
                        Text("De sparade verserna går redan att lyssna på offline. Du kan fortsätta hämta resten när du vill.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    if !isDownloading && downloadedCount < surah.numberOfAyahs {
                        Button {
                            startDownload(surah)
                        } label: {
                            Label(downloadedCount == 0 ? "Ladda ned suran" : "Fortsätt nedladdningen", systemImage: "arrow.down.circle")
                                .frame(minHeight: 44)
                        }
                    }

                    if !isDownloading && downloadedCount > 0 {
                        Button(role: .destructive) { confirmDeletion = true } label: {
                            Label("Radera sparat ljud", systemImage: "trash")
                                .frame(minHeight: 44)
                        }
                    }
                }
            } else if store.isLoading || store.index == nil && store.errorMessage == nil {
                Section { ProgressView("Öppnar surorna …") }
            } else if let error = store.errorMessage {
                Section {
                    ErrorBanner(message: error)
                    Button("Försök igen") { Task { await store.load() } }
                }
            }

            if isDownloading {
                Section("Hämtar ljud") {
                    if let activeName, let reciter = audioLibrary.downloadingReciter {
                        Text(activeName).font(.headline)
                        Text(reciter.displayName).font(.subheadline).foregroundStyle(.secondary)
                    }
                    ProgressView(value: audioLibrary.progress) {
                        Text("\(audioLibrary.completed) av \(audioLibrary.total) verser")
                            .font(.callout.monospacedDigit())
                    }
                    .accessibilityLabel("Nedladdning")
                    .accessibilityValue("\(audioLibrary.completed) av \(audioLibrary.total) verser")
                    Button("Avbryt nedladdning", role: .cancel) { audioLibrary.cancelDownload() }
                        .frame(minHeight: 44)
                    Text("Du kan fortsätta läsa i appen och återvända hit för att avbryta. Håll appen öppen tills nedladdningen är klar. Färdiga verser finns kvar om du avbryter.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            if let error = audioLibrary.errorMessage {
                Section { ErrorBanner(message: error) }
            }
        }
        .navigationTitle("Ljud offline")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSurahs) {
            SurahPicker { surah in
                // Download selection does not change the reader or its saved position.
                selectedSurahID = surah.id
            }
        }
        .confirmationDialog("Radera det sparade ljudet?", isPresented: $confirmDeletion, titleVisibility: .visible) {
            Button("Radera ljud", role: .destructive) {
                guard let surah = selectedSurah else { return }
                recorder.stopAll()
                player.stop()
                audioLibrary.deleteSurah(surah, reciter: selectedReciter)
                refreshDownloadedCount()
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            if let surah = selectedSurah {
                Text("\(surah.englishName) med \(selectedReciter.displayName) tas bort från telefonen. Du kan ladda ned ljudet igen senare.")
            }
        }
        .onAppear {
            initializeSelection()
            refreshDownloadedCount()
        }
        .onChange(of: selectedSurahID) { _, _ in refreshDownloadedCount() }
        .onChange(of: selectedReciter) { _, _ in refreshDownloadedCount() }
        .onChange(of: store.index?.surahs.count) { _, _ in
            initializeSelection()
            refreshDownloadedCount()
        }
        .onChange(of: audioLibrary.downloadingSurahID) { _, id in
            if id == nil {
                refreshDownloadedCount()
            } else {
                initializeSelection()
            }
        }
        .onChange(of: audioLibrary.downloadingReciter) { _, reciter in
            if reciter != nil { initializeSelection() }
        }
    }

    private var selectedSurah: Surah? {
        store.index?.surahs.first { $0.id == selectedSurahID }
    }

    private var isDownloading: Bool { audioLibrary.downloadingSurahID != nil }

    private var visibleDownloadedCount: Int {
        if audioLibrary.downloadingSurahID == selectedSurahID && audioLibrary.downloadingReciter == selectedReciter {
            return audioLibrary.completed
        }
        return downloadedCount
    }

    private var activeName: String? {
        guard let id = audioLibrary.downloadingSurahID else { return nil }
        return store.index?.surahs.first { $0.id == id }?.englishName ?? "Sura \(id)"
    }

    private func initializeSelection() {
        if let id = audioLibrary.downloadingSurahID, let reciter = audioLibrary.downloadingReciter {
            selectedSurahID = id
            selectedReciter = reciter
            initializedSelection = true
        } else if !initializedSelection {
            selectedSurahID = store.selectedSurahID
            selectedReciter = player.selectedReciter
            initializedSelection = store.index != nil
        }
    }

    private func refreshDownloadedCount() {
        downloadedCount = audioLibrary.downloadedVerseCount(surahID: selectedSurahID, reciter: selectedReciter)
    }

    private func startDownload(_ surah: Surah) {
        let reciter = selectedReciter
        let library = audioLibrary
        // A button starts an owned foreground job; navigating away does not cancel it.
        Task { await library.downloadSurah(surah, reciter: reciter) }
    }
}
