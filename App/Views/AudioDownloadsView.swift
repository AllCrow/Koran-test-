import Foundation
import QuranCore
import SwiftUI

@MainActor
struct AudioDownloadsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var player: RecitationPlayer
    @EnvironmentObject private var recorder: PracticeRecorder
    @EnvironmentObject private var audioLibrary: AudioLibrary
    @EnvironmentObject private var network: AudioNetworkPreferences
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedSurahID = 1
    @State private var selectedReciter: Reciter = .alafasy
    @State private var downloadedCount = 0
    @State private var hasStoredFiles = false
    @State private var initializedSelection = false
    @State private var showSurahs = false
    @State private var confirmDeletion = false
    @State private var deletionTarget: DeletionTarget?
    @State private var inventoryRefreshTask: Task<Void, Never>?
    @State private var playbackNotice: String?
    @State private var playbackTarget: DownloadedVerseTarget?

    private struct DeletionTarget {
        let surah: Surah
        let reciter: Reciter
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                Section {
                    Label("Lyssna utan internet", systemImage: "arrow.down.circle")
                        .font(.headline)
                        .foregroundStyle(Palette.green)
                    Text("Spara en sura med den recitatör du vill lyssna på. Sparat ljud används sedan automatiskt när du spelar verserna.")
                        .font(.callout)
                    Text(network.allowsCellularAudio
                         ? "Nedladdning kräver internet och kan använda mobildata."
                         : "Nedladdning använder Wi-Fi. Sparat ljud kan spelas utan internet.")
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
                        .accessibilityIdentifier("downloads.surah")
                        .accessibilityLabel("Välj sura")
                        .accessibilityValue(surah.englishName)
                        .disabled(isDownloading)

                        Picker("Recitatör", selection: $selectedReciter) {
                            ForEach(Reciter.allCases) { reciter in
                                Text(reciter.displayName).tag(reciter)
                            }
                        }
                        .pickerStyle(.menu)
                        .accessibilityIdentifier("downloads.reciter")
                        .disabled(isDownloading)
                    }
                    .id("downloads.selection")

                    Section("På din iPhone") {
                        LabeledContent("Sparade verser", value: "\(visibleDownloadedCount) av \(surah.numberOfAyahs)")
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("downloads.selection.count")
                            .accessibilityValue("\(visibleDownloadedCount) av \(surah.numberOfAyahs) verser")
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

                        if visibleDownloadedCount > 0 {
                            Button { playSavedVerse(in: surah) } label: {
                                Label("Lyssna på första sparade versen", systemImage: "play.circle")
                                    .frame(minHeight: 44)
                            }
                            .accessibilityIdentifier("downloads.saved.play")
                        }

                        if !isDownloading && hasStoredFiles {
                            Button(role: .destructive) {
                                deletionTarget = DeletionTarget(surah: surah, reciter: selectedReciter)
                                confirmDeletion = true
                            } label: {
                                Label("Radera sparat ljud", systemImage: "trash")
                                    .frame(minHeight: 44)
                            }
                            .accessibilityIdentifier("downloads.delete.present")
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
                        Text("Du kan fortsätta läsa i appen medan ljudet hämtas. Nedladdningen avbryts om appen går till bakgrunden. Färdiga verser finns kvar, och du kan fortsätta hämta resten här.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                savedAudioSection(proxy: proxy)

                if let notice = playbackNotice {
                    Section { Text(notice).font(.callout).foregroundStyle(.secondary) }
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
                if let target = deletionTarget {
                    Button("Radera ljud", role: .destructive) {
                        if player.requestedReference?.surahID == target.surah.id,
                           player.selectedReciter == target.reciter { player.stop() }
                        audioLibrary.deleteSurah(target.surah, reciter: target.reciter)
                        refreshDownloadedCount()
                        reloadInventory()
                    }
                    .accessibilityIdentifier("downloads.delete.confirm")
                }
                Button("Avbryt", role: .cancel) {}
            } message: {
                if let target = deletionTarget {
                    Text("\(target.surah.englishName) med \(target.reciter.displayName) tas bort från telefonen. Du kan ladda ned ljudet igen senare.")
                }
            }
            .navigationDestination(item: $playbackTarget) { target in
                DownloadedVerseDestination(target: target)
            }
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                await audioLibrary.refreshInventory()
            }
            .refreshable {
                guard scenePhase == .active else { return }
                await audioLibrary.refreshInventory()
            }
            .onDisappear { inventoryRefreshTask?.cancel(); inventoryRefreshTask = nil }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refreshDownloadedCount() }
                else { inventoryRefreshTask?.cancel(); inventoryRefreshTask = nil }
            }
            .onAppear {
                if !initializedSelection { initializeSelection() }
                refreshDownloadedCount()
            }
            .onChange(of: selectedSurahID) { _, _ in playbackNotice = nil; refreshDownloadedCount() }
            .onChange(of: selectedReciter) { _, _ in playbackNotice = nil; refreshDownloadedCount() }
            .onChange(of: audioLibrary.entries) { _, _ in
                if !isDownloading { refreshDownloadedCount() }
            }
            .onChange(of: store.index?.surahs.count) { _, _ in
                initializeSelection()
                refreshDownloadedCount()
            }
            .onChange(of: audioLibrary.downloadingSurahID) { _, id in
                if id == nil {
                    refreshDownloadedCount()
                    reloadInventory()
                } else {
                    initializeSelection()
                }
            }
            .onChange(of: audioLibrary.downloadingReciter) { _, reciter in
                if reciter != nil { initializeSelection() }
            }
        }
    }

    private func savedAudioSection(proxy: ScrollViewProxy) -> some View {
        Section("Ditt sparade ljud") {
            LabeledContent("Lagringsutrymme", value: audioLibrary.hasCurrentInventory
                ? sizeLabel(audioLibrary.inventoryBytes) : (audioLibrary.isScanning ? "Kontrolleras …" : "Behöver uppdateras"))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("downloads.inventory.bytes")
                .accessibilityValue(audioLibrary.hasCurrentInventory ? "\(audioLibrary.inventoryBytes) byte" : "Inte kontrollerat")
            if audioLibrary.isScanning {
                ProgressView("Kontrollerar sparat ljud …")
                    .accessibilityIdentifier("downloads.inventory.scanning")
            }
            if !audioLibrary.hasCurrentInventory && !audioLibrary.isScanning && audioLibrary.inventoryError == nil {
                Text(isDownloading ? "Listan uppdateras när hämtningen är klar." : "Uppdatera listan för att kontrollera det sparade ljudet.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            if audioLibrary.entries.isEmpty && audioLibrary.hasCurrentInventory && audioLibrary.inventoryError == nil {
                Text("Här visas dina sparade suror och recitatörer. Börja med att ladda ned en sura ovan.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            ForEach(audioLibrary.entries) { entry in
                Button {
                    selectedSurahID = entry.surahID
                    selectedReciter = entry.reciter
                    initializedSelection = true
                    playbackNotice = nil
                    refreshDownloadedCount()
                    withAnimation { proxy.scrollTo("downloads.selection", anchor: .top) }
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(surahName(entry.surahID)).font(.headline).foregroundStyle(.primary)
                            Text(entry.reciter.displayName).font(.subheadline).foregroundStyle(.secondary)
                            Text((audioLibrary.hasCurrentInventory ? "" : "Senast kontrollerat: ") + "\(entry.verseCount) av \(entry.totalVerses) verser · \(sizeLabel(entry.bytes))")
                                .font(.caption).foregroundStyle(.secondary)
                            if entry.damagedVerseCount > 0 {
                                Text("\(entry.damagedVerseCount) ljudfiler behöver hämtas igen")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 8)
                        Image(systemName: entry.damagedVerseCount > 0 ? "exclamationmark.circle" : (entry.isComplete ? "checkmark.circle.fill" : "circle.lefthalf.filled"))
                            .foregroundStyle(Palette.green)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 5)
                    .frame(minHeight: 44)
                }
                .disabled(isDownloading)
                .accessibilityIdentifier("downloads.saved.\(entry.surahID).\(entry.reciter.rawValue)")
                .accessibilityLabel("Öppna \(surahName(entry.surahID)) med \(entry.reciter.displayName)")
                .accessibilityValue((audioLibrary.hasCurrentInventory ? "" : "Senast kontrollerat: ") + "\(entry.verseCount) av \(entry.totalVerses) verser, \(entry.bytes) byte")
            }
            if let error = audioLibrary.inventoryError { ErrorBanner(message: error) }
            Button { reloadInventory() } label: {
                Label("Uppdatera listan", systemImage: "arrow.clockwise").frame(minHeight: 44)
            }
            .disabled(audioLibrary.isScanning)
            .accessibilityIdentifier("downloads.inventory.refresh")
            Text("Välj en sparad sura för att lyssna, hämta saknade verser eller radera just det ljudet. Storleken omfattar även skadade ljudfiler i listan.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func sizeLabel(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func surahName(_ id: Int) -> String {
        store.index?.surahs.first { $0.id == id }?.englishName ?? "Sura \(id)"
    }

    private func reloadInventory() {
        inventoryRefreshTask?.cancel()
        guard scenePhase == .active else { inventoryRefreshTask = nil; return }
        inventoryRefreshTask = Task { await audioLibrary.refreshInventory() }
    }

    private func playSavedVerse(in surah: Surah) {
        let reference = (1...surah.numberOfAyahs).compactMap {
            AyahReference(surahID: surah.id, ayahNumber: $0)
        }.first { audioLibrary.localURL(for: $0, reciter: selectedReciter) != nil }
        guard let reference else {
            playbackNotice = "Det sparade ljudet finns inte kvar. Uppdatera listan och ladda ned suran igen."
            reloadInventory()
            return
        }
        playbackNotice = nil
        recorder.stopAll()
        player.stop()
        playbackTarget = DownloadedVerseTarget(reference: reference, reciter: selectedReciter,
                                               chapterVerseCount: surah.numberOfAyahs)
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
        if audioLibrary.downloadingSurahID == selectedSurahID,
           audioLibrary.downloadingReciter == selectedReciter {
            // The foreground job already counted admitted files and updates
            // this count as it saves them. Avoid rescanning the directory when
            // the user revisits this screen during the same download.
            downloadedCount = audioLibrary.completed
        } else {
            downloadedCount = audioLibrary.downloadedVerseCount(surahID: selectedSurahID, reciter: selectedReciter)
        }
        hasStoredFiles = downloadedCount > 0 || audioLibrary.hasStoredAudio(surahID: selectedSurahID, reciter: selectedReciter)
    }

    private func startDownload(_ surah: Surah) {
        // Reserve the job before this action returns, so quick taps cannot queue
        // a request using a selection that has already changed.
        audioLibrary.beginDownload(surah, reciter: selectedReciter)
    }
}

private struct DownloadedVerseTarget: Hashable {
    let reference: AyahReference
    let reciter: Reciter
    let chapterVerseCount: Int
}

/// A saved-audio action opens the exact text before starting its one-verse
/// session. The library's own selection remains unchanged when this route ends.
@MainActor
private struct DownloadedVerseDestination: View {
    let target: DownloadedVerseTarget
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var player: RecitationPlayer
    @EnvironmentObject private var audioLibrary: AudioLibrary
    @Environment(\.scenePhase) private var scenePhase
    @State private var loadToken: UUID?
    @State private var hasOpened = false
    @State private var savedSessionToken: UUID?
    @State private var readerReady = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            if readerReady {
                ReaderView(initialReference: target.reference)
            } else {
                VStack(spacing: 18) {
                    if let error = errorMessage {
                        ErrorBanner(message: error)
                        Button("Försök igen") { loadToken = UUID() }
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("downloads.reader.retry")
                    } else {
                        ProgressView("Öppnar den sparade versen …")
                            .accessibilityIdentifier("downloads.reader.loading")
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("Koranen")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !hasOpened else { return }
            hasOpened = true
            if scenePhase == .active { loadToken = UUID() }
            else { errorMessage = "Öppningen avbröts. Tryck på Försök igen när du vill lyssna." }
        }
        .onDisappear {
            loadToken = nil
            if !readerReady {
                errorMessage = "Öppningen avbröts. Tryck på Försök igen när du vill lyssna."
            }
            if let token = savedSessionToken { player.stopSavedSession(token) }
            savedSessionToken = nil
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active && !readerReady {
                loadToken = nil
                errorMessage = "Öppningen avbröts. Tryck på Försök igen när du vill lyssna."
            }
        }
        .task(id: loadToken) {
            guard let token = loadToken, scenePhase == .active, !Task.isCancelled else { return }
            errorMessage = nil
            readerReady = false
            await store.openSurah(target.reference.surahID)
            guard !Task.isCancelled, loadToken == token, scenePhase == .active else { return }
            guard let chapter = store.chapter,
                  chapter.surah.id == target.reference.surahID,
                  chapter.surah.numberOfAyahs == target.chapterVerseCount,
                  chapter.ayahs.contains(where: { $0.reference == target.reference }) else {
                errorMessage = store.errorMessage ?? "Den valda suran kunde inte öppnas. Försök igen."
                return
            }
            guard let localURL = audioLibrary.localURL(for: target.reference, reciter: target.reciter) else {
                errorMessage = "Den sparade ljudfilen finns inte kvar. Gå tillbaka och hämta den igen."
                return
            }
            // There is no suspension between the final local admission check
            // and the fixed-file session; it cannot fall back to streaming.
            savedSessionToken = player.playSavedOnce(reference: target.reference,
                                 chapterVerseCount: target.chapterVerseCount,
                                 reciter: target.reciter, localURL: localURL)
            store.setLastRead(target.reference)
            readerReady = true
        }
    }
}
