import SwiftUI
import UniformTypeIdentifiers
import QuranCore

@MainActor
struct ContentSourcesView: View {
    @State private var notice = ""

    var body: some View {
        List {
            Section("Korantext på arabiska") {
                Text("Alla 114 suror och 6 236 verser finns i appen. Versnumreringen följer Hafs.")
                Text("Lästexten använder Uthmani-utgåvan quran-uthmani från AlQuran Cloud, med källhänvisning till Tanzil. Den arabiska källtexten bevaras ordagrant.")
                    .accessibilityIdentifier("sources.readingEdition")
                Link("Tanzil – korantext", destination: URL(string: "https://tanzil.net")!)
                Link("AlQuran Cloud – textkälla", destination: URL(string: "https://alquran.cloud")!)
                Text("Ingen svensk översättning ingår i den här versionen.")
            }
            Section("Tajweedfärger") {
                Text("Färgerna kommer från en separat annoterad utgåva: quran-tajweed. Utgåvorna kan skilja sig i stavningsdetaljer och tecken. Om färgvisningen inte kan tolkas visas den ordagranna Uthmani-texten.")
                    .accessibilityIdentifier("sources.tajweedEdition")
                Text("Färgerna är läshjälp och bedömer inte ditt uttal.")
                Link("Tajweednotation och färgförklaring", destination: URL(string: "https://alquran.cloud/tajweed-guide")!)
            }
            Section("Tafsir – förklaring på arabiska") {
                Text("Al-Muyassar, utgåva ar.muyassar, hämtas separat från AlQuran Cloud. Tjänstens källangivelse är King Fahad Quran Complex.")
                    .accessibilityIdentifier("sources.tafsirEdition")
                Text("Tafsir är en förklaring, skild från korantexten. Ingen automatisk översättning eller AI-genererad tafsir används.")
                Text("Ny tafsir behöver internet. Tidigare öppnade förklaringar kan sparas lokalt för senare läsning utan internet.")
            }
            Section("Recitationsljud") {
                ForEach(Reciter.allCases) { reciter in Text(reciter.displayName) }
                Text("Ljudet kommer från EveryAyah, en fil per vers. Markeringen följer hela versen, inte enskilda ord. Ljud behöver hämtas innan det kan spelas offline.")
                Link("EveryAyah – ljudkälla", destination: URL(string: "https://everyayah.com")!)
            }
            Section("Typsnitt och textvillkor") {
                Text("Amiri Quran används med SIL Open Font License 1.1. Originallicensen följer med appen.")
                Link("Amiri – typsnittsprojektet", destination: URL(string: "https://github.com/aliftype/amiri")!)
                Link("Tanzils textlicens", destination: URL(string: "https://tanzil.net/docs/text_license")!)
                Link("AlQuran Clouds villkor", destination: URL(string: "https://alquran.cloud/terms-and-conditions")!)
                Text("Källtexterna kontrolleras för ordagrann kopiering. Detta är ingen oberoende sakkunnig certifiering.")
                DisclosureGroup("Visa den medföljande källnotisen") {
                    Text(notice.isEmpty ? "Källnotisen kunde inte öppnas." : notice)
                        .font(.footnote).textSelection(.enabled)
                }
            }
            Section("Om du upptäcker något") {
                Text("Öppna menyn vid versen och välj Granska innehåll. Där kan du beskriva problemet, granska rapporten och själv spara den i Filer. Appen skickar ingen rapport automatiskt.")
            }
        }
        .navigationTitle("Källor och textutgåvor")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let url = Bundle.main.url(forResource: "NOTICE", withExtension: "txt", subdirectory: "Quran"),
               let text = try? String(contentsOf: url, encoding: .utf8) { notice = text }
        }
    }
}

/// The verse and selected source choices are immutable for this sheet. A later
/// chapter change cannot silently bind a draft to a different verse.
@MainActor
struct ContentIssueReportView: View {
    let ayah: Ayah
    let tajweedEnabled: Bool
    let reciter: Reciter
    @Environment(\.dismiss) private var dismiss
    @FocusState private var descriptionFocused: Bool
    @State private var topic = ContentIssueReport.Topic.readingText
    @State private var issueDescription = ""
    @State private var reportData: Data?
    @State private var exportDocument: ContentIssueDocument?
    @State private var showExporter = false
    @State private var notice: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Versen som ska granskas") {
                    Text("Sura \(ayah.surahID) · vers \(ayah.numberInSurah)")
                        .font(.headline)
                        .accessibilityIdentifier("contentIssue.reference")
                    // Show the canonical edition separately from any coloured
                    // display; do not copy model offsets or normalize its text.
                    ArabicText(text: ayah.text, tajweed: nil, colored: false)
                    Text("Källtext: quran-uthmani. Rapporten innehåller versreferensen och källans namn, inte versens text.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Picker("Vad vill du få granskat?", selection: $topic) {
                        ForEach(ContentIssueReport.Topic.allCases) { Text($0.displayName).tag($0) }
                    }
                    .accessibilityIdentifier("contentIssue.topic")
                    if topic == .recitation {
                        LabeledContent("Recitatör", value: reciter.displayName)
                    }
                    TextEditor(text: $issueDescription)
                        .focused($descriptionFocused)
                        .frame(minHeight: 120)
                        .accessibilityLabel("Beskriv problemet")
                        .accessibilityIdentifier("contentIssue.description")
                } header: {
                    Text("Beskriv vad du upptäckte")
                } footer: {
                    Text("Högst 2 000 tecken. Skriv inga privata uppgifter. Rapporten innehåller din beskrivning, versreferens och källuppgifter. Läshistorik och inspelningar ingår inte.")
                }
                Section {
                    Button("Granska rapport") { createReport() }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("contentIssue.preview")
                }
                if let reportData, let preview = String(data: reportData, encoding: .utf8) {
                    Section("Detta sparas i rapporten") {
                        Text(preview).font(.caption.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("contentIssue.report")
                        Button {
                            exportDocument = ContentIssueDocument(data: reportData)
                            showExporter = true
                        } label: {
                            Label("Spara rapport i Filer", systemImage: "square.and.arrow.up")
                                .frame(minHeight: 44)
                        }
                        .accessibilityIdentifier("contentIssue.export")
                        Text("Du väljer själv om och med vem du sedan delar filen. Ingen rapport skickas från appen.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let notice {
                    Section { Label(notice, systemImage: "checkmark.circle").foregroundStyle(Palette.green) }
                }
                if let errorMessage { Section { ErrorBanner(message: errorMessage) } }
                Section { NavigationLink("Källor och textutgåvor") { ContentSourcesView() } }
            }
            .navigationTitle("Granska innehåll")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Stäng") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Klart") { descriptionFocused = false }
                        .accessibilityIdentifier("contentIssue.keyboardDone")
                }
            }
        }
        .onChange(of: issueDescription) { _, _ in clearPreview() }
        .onChange(of: topic) { _, _ in clearPreview() }
        .fileExporter(isPresented: $showExporter, document: exportDocument, contentType: .json,
                      defaultFilename: "Sakina-innehall-\(ayah.surahID)-\(ayah.numberInSurah)") { result in
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

    private func createReport() {
        descriptionFocused = false
        clearPreview()
        guard let reference = ayah.reference else {
            errorMessage = "Versreferensen kunde inte verifieras. Stäng och öppna versen igen."
            return
        }
        do {
            reportData = try ContentIssueReport(reference: reference, topic: topic, tajweedEnabled: tajweedEnabled,
                                               reciter: reciter, description: issueDescription).jsonData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearPreview() {
        reportData = nil
        notice = nil
        errorMessage = nil
    }
}

private struct ContentIssueDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
