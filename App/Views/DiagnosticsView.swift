import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct DiagnosticsView: View {
    let allowsCellularAudio: Bool
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var player: RecitationPlayer
    @EnvironmentObject private var recorder: PracticeRecorder
    @EnvironmentObject private var audioLibrary: AudioLibrary
    @EnvironmentObject private var assessment: RecitationAssessmentStore
    @State private var report: DiagnosticsReport?
    @State private var reportData: Data?
    @State private var requestID: UUID?
    @State private var isCreating = false
    @State private var exportDocument: DiagnosticsDocument?
    @State private var showExporter = false
    @State private var notice: String?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                Text("Skapa en statusrapport om något inte fungerar. Granska innehållet och välj själv om du vill spara och dela filen.")
                    .font(.callout)
                Button {
                    notice = nil
                    errorMessage = nil
                    report = nil
                    reportData = nil
                    requestID = UUID()
                } label: {
                    Label(report == nil ? "Skapa rapport" : "Skapa ny rapport", systemImage: "doc.text.magnifyingglass")
                        .frame(minHeight: 44)
                }
                .disabled(isCreating)
                .accessibilityIdentifier("diagnostics.create")
                if isCreating { ProgressView("Samlar status …") }
            } footer: {
                Text("Inspelningar, läshistorik, versval och kontouppgifter ingår inte. Ingen rapport skickas automatiskt.")
            }

            if let report {
                Section("Rapportens innehåll") {
                    LabeledContent("Appversion", value: "\(report.appVersion) (\(report.appBuild))")
                    LabeledContent("iOS", value: report.systemVersion)
                    LabeledContent("Recitation", value: playbackLabel(report.audio.playback))
                    LabeledContent("Övning", value: practiceLabel(report.practice.state))
                    LabeledContent("Mobildata för ljud", value: report.audio.allowsCellularAudio ? "Tillåten" : "Avstängd")
                    if let selections = report.storage.savedSelections,
                       let bytes = report.storage.audioBytes {
                        LabeledContent("Sparade suror och recitatörer", value: "\(selections)")
                        LabeledContent("Sparat ljud", value: ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                    } else {
                        LabeledContent("Ljudlagring", value: report.storage.status == .pending ? "Kontroll pågår" : "Kunde inte kontrolleras")
                    }
                    LabeledContent("Områden med fel", value: report.services.errorAreas.isEmpty
                                   ? "Inga just nu" : report.services.errorAreas.map(errorLabel).joined(separator: ", "))
                    DisclosureGroup("Visa hela rapporten") {
                        if let reportData, let text = String(data: reportData, encoding: .utf8) {
                            Text(text)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityIdentifier("diagnostics.preview")
                        }
                    }
                }
                Section {
                    Button {
                        guard let reportData else { return }
                        exportDocument = DiagnosticsDocument(data: reportData)
                        showExporter = true
                    } label: {
                        Label("Spara rapport i Filer", systemImage: "square.and.arrow.up")
                            .frame(minHeight: 44)
                    }
                    .disabled(isCreating)
                    .accessibilityIdentifier("diagnostics.export")
                } footer: {
                    Text("Rapporten visar status när du skapade den. Skapa en ny efter att problemet har inträffat igen.")
                }
            }
            if let notice {
                Section { Label(notice, systemImage: "checkmark.circle").foregroundStyle(Palette.green) }
            }
            if let errorMessage { Section { ErrorBanner(message: errorMessage) } }
        }
        .navigationTitle("Felsökningsrapport")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: requestID) {
            // Opening the view performs no scan. The task starts only after
            // the explicit create action and is cancelled when the view leaves.
            guard let id = requestID else { return }
            isCreating = true
            defer {
                if requestID == id {
                    isCreating = false
                    requestID = nil
                }
            }
            await audioLibrary.refreshInventory()
            guard !Task.isCancelled, requestID == id else { return }
            let snapshot = makeReport()
            do {
                let data = try snapshot.jsonData()
                report = snapshot
                reportData = data
            } catch {
                errorMessage = "Rapporten kunde inte skapas. Försök igen."
            }
        }
        .fileExporter(isPresented: $showExporter, document: exportDocument, contentType: .json,
                      defaultFilename: "Sakina-felsokning") { result in
            exportDocument = nil
            switch result {
            case .success: notice = "Rapporten har sparats till den fil du valde."
            case .failure(let error):
                let value = error as NSError
                if !(value.domain == NSCocoaErrorDomain && value.code == CocoaError.userCancelled.rawValue) {
                    errorMessage = "Rapporten kunde inte sparas. Försök igen."
                }
            }
        }
    }

    private func makeReport() -> DiagnosticsReport {
        let playback: DiagnosticsReport.PlaybackState = player.isBuffering ? .loading
            : player.isPlaying ? .playing : player.requestedReference == nil ? .idle : .paused
        let practice: DiagnosticsReport.PracticeState = recorder.isRequestingPermission ? .requestingPermission
            : recorder.isRecording ? .recording : recorder.isPlaying ? .playing : .idle
        var errors: [DiagnosticsReport.ErrorArea] = []
        if store.errorMessage != nil { errors.append(.reading) }
        if player.errorMessage != nil { errors.append(.recitation) }
        if audioLibrary.errorMessage != nil { errors.append(.downloads) }
        if recorder.errorMessage != nil { errors.append(.recording) }
        if assessment.errorMessage != nil { errors.append(.assessment) }
        if audioLibrary.inventoryError != nil { errors.append(.storage) }
        let storage: DiagnosticsReport.Storage = audioLibrary.isScanning ? .pending
            : !audioLibrary.hasCurrentInventory ? .unavailable
            : .init(savedSelections: audioLibrary.entries.count, audioBytes: audioLibrary.inventoryBytes)
        return DiagnosticsReport(
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            appBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
            systemVersion: ProcessInfo.processInfo.operatingSystemVersion,
            audio: .init(playback: playback, allowsCellularAudio: allowsCellularAudio,
                         downloadActive: audioLibrary.downloadingSurahID != nil),
            practice: .init(state: practice, hasTemporaryTake: recorder.hasRecording),
            services: .init(readingLoading: store.isLoading, experimentalAssessmentAvailable: assessment.isAvailable,
                            assessmentRunning: assessment.isAssessing, errorAreas: errors),
            storage: storage
        )
    }

    private func playbackLabel(_ state: DiagnosticsReport.PlaybackState) -> String {
        switch state {
        case .idle: return "Stoppad"
        case .loading: return "Laddar"
        case .playing: return "Spelar"
        case .paused: return "Pausad"
        }
    }

    private func practiceLabel(_ state: DiagnosticsReport.PracticeState) -> String {
        switch state {
        case .idle: return "Vilande"
        case .requestingPermission: return "Väntar på mikrofonval"
        case .recording: return "Spelar in"
        case .playing: return "Återlyssnar"
        }
    }

    private func errorLabel(_ area: DiagnosticsReport.ErrorArea) -> String {
        switch area {
        case .reading: return "Läsning"
        case .recitation: return "Recitation"
        case .downloads: return "Nedladdning"
        case .recording: return "Inspelning"
        case .assessment: return "Analys"
        case .storage: return "Lagring"
        }
    }
}

private struct DiagnosticsDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
