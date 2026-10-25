import SwiftUI
import UniformTypeIdentifiers
import QuranCore
import QuranData

@MainActor
struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var player: RecitationPlayer
    @EnvironmentObject private var recorder: PracticeRecorder
    @EnvironmentObject private var assessment: RecitationAssessmentStore
    @EnvironmentObject private var audioLibrary: AudioLibrary
    @EnvironmentObject private var audioNetwork: AudioNetworkPreferences
    @State private var exportDocument: ReadingBackupDocument?
    @State private var exportFilename = "Sakina-lasdata"
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var pendingImport: Data?
    @State private var showImportConfirmation = false
    @State private var isReadingBackup = false
    @State private var backupNotice: String?
    @State private var backupError: String?
    @State private var backupRequestID = UUID()
    @State private var backupReadTask: Task<Void, Never>?

    var body: some View {
        List {
            Section("Din läsvana") {
                Stepper(value: Binding(get: { store.dailyGoal }, set: { store.setDailyGoal($0) }), in: 1...50) {
                    LabeledContent("Dagligt mål", value: "\(store.dailyGoal) verser")
                }
                LabeledContent("Nuvarande streak", value: daysLabel(store.streakSummary.current))
                LabeledContent("Längsta streak", value: daysLabel(store.streakSummary.best))
                Text("Målet räknar olika verser som du själv markerar som lästa. Ett uppehåll är alltid en möjlighet att börja igen.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Läsning och ljud") {
                Picker("Utseende", selection: Binding(get: { store.appearance }, set: { store.setAppearance($0) })) {
                    ForEach(AppStore.Appearance.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("settings.appearance")
                NavigationLink("Ljud för offline-lyssning") { AudioDownloadsView() }
                    .accessibilityIdentifier("settings.audioLibrary")
                Toggle("Tajweedfärger", isOn: Binding(get: { store.tajweedEnabled }, set: { store.setTajweedEnabled($0) }))
                    .accessibilityIdentifier("settings.tajweed")
                NavigationLink {
                    ArabicTextSizeView()
                } label: {
                    LabeledContent("Arabisk textstorlek", value: store.arabicTextSize.displayName)
                }
                .accessibilityIdentifier("settings.arabicTextSize.present")
                Picker("Recitatör", selection: Binding(get: { player.selectedReciter }, set: {
                    recorder.stopAll()
                    player.selectReciter($0)
                })) {
                    ForEach(Reciter.allCases) { Text($0.displayName).tag($0) }
                }
                Toggle("Spela nästa vers automatiskt", isOn: $player.autoplay)
            }
            Section {
                Toggle("Använd mobildata för ljud", isOn: Binding(
                    get: { audioNetwork.allowsCellularAudio },
                    set: { allowed in
                        audioNetwork.setAllowsCellularAudio(allowed)
                        audioLibrary.setAllowsCellularAccess(allowed)
                        player.setAllowsCellularAccess(allowed)
                    }
                ))
                .accessibilityIdentifier("settings.audioCellular")
            } header: {
                Text("Nätverk för ljud")
            } footer: {
                Text("När mobildata är avstängt behöver nytt ljud Wi-Fi. Sparat ljud fungerar fortfarande offline. Ändrar du valet pausas pågående hämtning och strömning.")
                    .font(.caption)
            }
            readingBackupSection
            Section("Övning") {
                NavigationLink {
                    PracticeQueueView()
                } label: {
                    LabeledContent("Min övningskö", value: "\(store.practiceQueue.count) verser")
                }
                .accessibilityIdentifier("settings.practiceQueue")
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
                    .accessibilityIdentifier("settings.bookmark.\(reference.surahID).\(reference.ayahNumber)")
                    .swipeActions {
                        Button("Ta bort", role: .destructive) { store.toggleBookmark(reference) }
                    }
                }
            }
            Section("Om Sakina") {
                if let versionDescription {
                    Text(versionDescription).font(.caption).foregroundStyle(.secondary)
                        .accessibilityIdentifier("settings.version")
                }
                NavigationLink("Källor och textutgåvor") { SourceNoticeView() }
                NavigationLink("Integritet") { PrivacyView() }
                NavigationLink("Felsökningsrapport") {
                    DiagnosticsView(allowsCellularAudio: audioNetwork.allowsCellularAudio)
                }
                .accessibilityIdentifier("settings.diagnostics")
                Text("Ingen prenumeration, inget konto och inga annonser i den här versionen.")
                    .font(.footnote).foregroundStyle(.secondary)
                Text(assessment.isAvailable
                     ? "Ny tafsir och frivillig analys behöver internet. Tajweedhjälpen är en experimentell testfunktion."
                     : "Ny tafsir och nytt ljud behöver internet. Sparad tafsir och sparat ljud kan användas offline. Automatisk tajweedbedömning ingår ännu inte.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Mitt")
        .fileExporter(isPresented: $showExporter, document: exportDocument, contentType: .json,
                      defaultFilename: exportFilename) { result in
            exportDocument = nil
            switch result {
            case .success:
                backupNotice = "Läsdatan har exporterats till den fil du valde."
            case .failure(let error):
                if !isUserCancellation(error) { backupError = "Säkerhetskopian kunde inte sparas. Försök igen." }
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { readBackup(from: url) }
            case .failure(let error):
                if !isUserCancellation(error) { backupError = "Säkerhetskopian kunde inte öppnas. Försök igen." }
            }
        }
        .confirmationDialog("Lägg till läsdata från säkerhetskopian?", isPresented: $showImportConfirmation,
                            titleVisibility: .visible) {
            Button("Lägg till läsdata") {
                guard let data = pendingImport else { return }
                pendingImport = nil
                do {
                    try store.mergeReadingBackup(data)
                    backupNotice = "Läsdatan har lagts till. Dina befintliga data och inställningar är kvar."
                } catch { backupError = error.localizedDescription }
            }
            Button("Avbryt", role: .cancel) { pendingImport = nil }
        } message: {
            Text("Bokmärken, läsdagar och övningskö läggs till. Din befintliga läsposition och dina inställningar behålls.")
        }
        .onDisappear {
            backupRequestID = UUID()
            backupReadTask?.cancel()
            backupReadTask = nil
            isReadingBackup = false
        }
    }

    private var readingBackupSection: some View {
        Section("Säkerhetskopiera läsdata") {
            Button {
                do {
                    exportDocument = ReadingBackupDocument(data: try store.readingBackupData())
                    exportFilename = "Sakina-lasdata-" + Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash))
                    backupError = nil
                    backupNotice = nil
                    showExporter = true
                } catch { backupError = error.localizedDescription }
            } label: {
                Label("Exportera läsdata", systemImage: "square.and.arrow.up")
            }
            .accessibilityIdentifier("settings.backup.export")
            .disabled(isReadingBackup)
            Button {
                backupError = nil
                backupNotice = nil
                showImporter = true
            } label: {
                Label("Importera läsdata", systemImage: "square.and.arrow.down")
            }
            .accessibilityIdentifier("settings.backup.import")
            .disabled(isReadingBackup)
            Text("Spara bokmärken, läsposition, läsdagar och övningskö i en fil inför en ominstallation. Ljud, inspelningar och inställningar ingår inte.")
                .font(.caption).foregroundStyle(.secondary)
            if isReadingBackup { ProgressView("Läser säkerhetskopian …") }
            if let backupNotice {
                Label(backupNotice, systemImage: "checkmark.circle")
                    .font(.callout).foregroundStyle(Palette.green)
            }
            if let backupError { ErrorBanner(message: backupError) }
        }
    }

    private func readBackup(from url: URL) {
        backupReadTask?.cancel()
        let requestID = UUID()
        backupRequestID = requestID
        isReadingBackup = true
        pendingImport = nil
        backupNotice = nil
        backupError = nil
        let maximumBytes = AppStore.maximumReadingBackupBytes
        backupReadTask = Task { @MainActor in
            defer {
                if backupRequestID == requestID {
                    isReadingBackup = false
                    backupReadTask = nil
                }
            }
            guard !Task.isCancelled, backupRequestID == requestID else { return }
            let reader = Task.detached(priority: .userInitiated) {
                try ReadingBackupFileReader.read(url, maximumBytes: maximumBytes)
            }
            do {
                let data = try await withTaskCancellationHandler {
                    try await reader.value
                } onCancel: {
                    reader.cancel()
                }
                try Task.checkCancellation()
                guard backupRequestID == requestID else { return }
                pendingImport = data
                showImportConfirmation = true
            } catch is CancellationError { }
            catch {
                guard backupRequestID == requestID, !Task.isCancelled else { return }
                backupError = (error as? ReadingBackupFileReader.ReadError)?.errorDescription
                    ?? "Säkerhetskopian kunde inte läsas. Välj en Sakina-fil och försök igen."
            }
        }
    }

    private func isUserCancellation(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == NSCocoaErrorDomain && error.code == NSUserCancelledError
    }

    private var versionDescription: String? {
        guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String else { return nil }
        return "Version \(version) (\(build))"
    }

    private var sortedBookmarks: [AyahReference] {
        store.bookmarks.sorted { lhs, rhs in
            lhs.surahID == rhs.surahID ? lhs.ayahNumber < rhs.ayahNumber : lhs.surahID < rhs.surahID
        }
    }
    private func daysLabel(_ count: Int) -> String { count == 1 ? "1 dag" : "\(count) dagar" }
    private func surahName(_ reference: AyahReference) -> String {
        store.index?.surahs.first { $0.id == reference.surahID }?.englishName ?? "Sura \(reference.surahID)"
    }
}

@MainActor
private struct ArabicTextSizeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var previewText: String?

    var body: some View {
        List {
            Section {
                ForEach(AppStore.ArabicTextSize.allCases) { size in
                    Button { store.setArabicTextSize(size) } label: {
                        HStack {
                            Text(size.displayName).foregroundStyle(.primary)
                            Spacer(minLength: 12)
                            if store.arabicTextSize == size {
                                Image(systemName: "checkmark").foregroundStyle(Palette.green)
                                    .accessibilityHidden(true)
                            }
                        }.frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .accessibilityValue(store.arabicTextSize == size ? "Vald" : "")
                    .accessibilityAddTraits(store.arabicTextSize == size ? .isSelected : [])
                    .accessibilityIdentifier("settings.arabicTextSize.\(size.rawValue)")
                }
            } footer: {
                Text("Gäller arabisk text i läsning, tafsir och övning. Din iPhones inställning för textstorlek gäller också.")
            }
            if let previewText {
                Section("Förhandsvisning · 1:1") {
                    ArabicText(text: previewText, tajweed: nil, colored: false).padding(.vertical, 12)
                }
            }
        }
        .navigationTitle("Arabisk textstorlek")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Use the bundled, validated source for the preview as well.
            let chapter = try? await QuranRepository().loadChapter(id: 1)
            guard !Task.isCancelled else { return }
            previewText = chapter?.ayahs.first.map { QuranPresentation.verseText($0) }
        }
    }
}

private struct ReadingBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// A provider file may need coordination/download. Keep that work off the UI
/// actor, keep its security scope open, and stop after the accepted byte bound.
private enum ReadingBackupFileReader {
    enum ReadError: LocalizedError {
        case tooLarge
        case unavailable
        var errorDescription: String? {
            switch self {
            case .tooLarge: return "Filen är för stor. Välj en säkerhetskopia skapad av Sakina."
            case .unavailable: return "Säkerhetskopian kunde inte läsas. Försök igen."
            }
        }
    }

    static func read(_ url: URL, maximumBytes: Int) throws -> Data {
        try Task.checkCancellation()
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        var coordinationError: NSError?
        var result: Result<Data, Error>?
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
            result = Result {
                let handle = try FileHandle(forReadingFrom: coordinatedURL)
                defer { try? handle.close() }
                var data = Data()
                while data.count <= maximumBytes {
                    try Task.checkCancellation()
                    let chunk = try handle.read(upToCount: min(65_536, maximumBytes + 1 - data.count)) ?? Data()
                    if chunk.isEmpty { return data }
                    data.append(chunk)
                    if data.count > maximumBytes { throw ReadError.tooLarge }
                }
                throw ReadError.tooLarge
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw ReadError.unavailable }
        return try result.get()
    }
}

@MainActor
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

@MainActor
struct SourceNoticeView: View {
    @State private var notice = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Korantext och tajweed").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                Text("Uthmani-texten och den annoterade tajweedutgåvan är separata utgåvor. Visningen följer Hafs-numrering. Båda källtexterna bevaras ordagrant i appens databas.")
                Link("Tanzil.net – korantext", destination: URL(string: "https://tanzil.net")!)
                Link("AlQuran Cloud – käll-API", destination: URL(string: "https://alquran.cloud")!)
                Link("Tajweednotation och färgförklaring", destination: URL(string: "https://alquran.cloud/tajweed-guide")!)
                Text("Typsnitt: Amiri Quran, SIL Open Font License 1.1. Originallicensen finns med i appen.").font(.footnote)
                Link("Amiri – typsnittsprojektet", destination: URL(string: "https://github.com/aliftype/amiri")!)
                Text("Recitation").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                Text("Mishary Rashid al-Afasy, Mahmoud Khalil al-Husary och Muhammad Siddiq al-Minshawi. Inspelningarna strömmas från EveryAyah, en fil per vers. Textmarkeringen följer versen, inte enskilda ord.")
                Link("EveryAyah", destination: URL(string: "https://everyayah.com")!)
                Text("Tafsir").font(.title2.bold()).accessibilityAddTraits(.isHeader)
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

@MainActor
struct PrivacyView: View {
    @EnvironmentObject private var assessment: RecitationAssessmentStore
    var body: some View {
        List {
            Section("Sparas på din iPhone") {
                Text("Läsposition, bokmärken, övningskö, läsmål och streak sparas lokalt. Appen kräver inget konto och innehåller ingen användningsspårning eller annonser.")
                Text("Tidigare öppnade tafsirförklaringar kan sparas på telefonen för läsning utan internet. De senaste förklaringarna prioriteras när utrymmet fylls.")
                Text("Inspelningar kan raderas i övningsvyn och tas bort vid nästa appstart. Ingen röst laddas upp automatiskt.")
                Text("Du kan själv exportera läsdata till en fil och lägga till dem igen efter en ominstallation. Appen gör ingen automatisk säkerhetskopiering till en server.")
                Text("En felsökningsrapport skapas först när du själv väljer det. Du kan granska och spara rapporten i Filer; appen skickar den inte automatiskt. Den innehåller inte läshistorik eller inspelningar.")
            }
            Section("När du använder internet") {
                Text("När du strömmar eller laddar ned recitationsljud kontaktar appen EveryAyah. Sparat ljud spelas från telefonen. När en tafsirförklaring behöver hämtas kontaktar appen AlQuran Cloud. Tjänsterna får din IP-adress och vilken vers du begär, men ingen röstinspelning från appen.")
                Text("Du kan läsa hela korantexten med tajweedfärger utan internet.")
                Text("Ljud som du väljer att ladda ned sparas på telefonen tills du raderar det under Offline-lyssning.")
            }
            if assessment.isAvailable {
                Section("Frivillig recitationsanalys") {
                    Text("När du själv väljer Analysera skickas den valda inspelningen till analystjänsten. Om du bara spelar in och lyssnar tillbaka stannar den på telefonen.")
                    Text("Analysfunktionen är experimentell. Ingen automatisk uppladdning sker när du öppnar appen eller läser Koranen.")
                }
            }
        }.navigationTitle("Integritet").navigationBarTitleDisplayMode(.inline)
    }
}
