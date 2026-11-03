import SwiftUI
import QuranCore
import QuranData

@MainActor
struct VerseSearchSheet: View {
    let onSelect: (AyahReference) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var page: QuranVerseSearch.Page?
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var activeRequestID: UUID?
    private static let searchService = QuranVerseSearch()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Skriv arabiska ord från versen", text: searchQuery, axis: .vertical)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .frame(minHeight: 44)
                        .environment(\.layoutDirection, .rightToLeft)
                        .accessibilityLabel("Sök i arabisk korantext")
                        .accessibilityIdentifier("reader.search.query")
                    Text("Sök i hela den arabiska korantexten, även utan vokaltecken. Sökningen fungerar offline. Svensk översättning och translittererad verstext ingår inte.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                if isSearching {
                    ProgressView("Söker i Koranen …")
                        .accessibilityIdentifier("reader.search.loading")
                } else if let errorMessage {
                    ErrorBanner(message: errorMessage)
                } else if let page {
                    Section {
                        ForEach(page.hits) { hit in
                            VStack(alignment: .leading, spacing: 12) {
                                Text("\(hit.surahName) · \(hit.reference.surahID):\(hit.reference.ayahNumber)")
                                    .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.green)
                                    .accessibilityAddTraits(.isHeader)
                                // Keep the exact Arabic preview separate from
                                // the Swedish action so VoiceOver preserves
                                // ArabicText's explicit Arabic language.
                                ArabicText(text: hit.text, tajweed: nil, colored: false)
                                Button {
                                    onSelect(hit.reference)
                                    dismiss()
                                } label: {
                                    Label("Öppna versen", systemImage: "arrow.right")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .frame(minHeight: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Palette.green)
                                .accessibilityLabel("Öppna \(hit.surahName), vers \(hit.reference.surahID):\(hit.reference.ayahNumber)")
                                .accessibilityIdentifier("reader.search.result.\(hit.reference.surahID).\(hit.reference.ayahNumber)")
                            }
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityElement(children: .contain)
                        }
                    } header: {
                        Text(page.hasMore ? "Visar de första \(page.hits.count) träffarna" : "\(page.hits.count) träffar")
                            .accessibilityIdentifier("reader.search.count")
                    } footer: {
                        if page.hasMore { Text("Fler verser matchar. Lägg till fler ord för att begränsa sökningen.") }
                    }
                    if page.hits.isEmpty {
                        Text("Ingen vers matchade. Prova färre ord eller en annan arabisk stavning.")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("reader.search.noResults")
                    }
                } else {
                    Text("Skriv minst två arabiska bokstäver för att söka efter en vers.")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("reader.search.empty")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Sök i verser")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Stäng") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    if !query.isEmpty {
                        Button("Rensa") { updateQuery("") }
                            .accessibilityIdentifier("reader.search.clear")
                    }
                }
            }
            .task(id: query) { await search() }
        }
    }

    private var searchQuery: Binding<String> {
        Binding(get: { query }, set: updateQuery)
    }

    private func updateQuery(_ value: String) {
        guard value != query else { return }
        // Invalidate old results before publishing new input, so a suspended
        // previous request cannot publish during this query's debounce window.
        activeRequestID = nil
        page = nil
        errorMessage = nil
        isSearching = false
        query = value
    }

    private func search() async {
        let requestID = UUID()
        activeRequestID = requestID
        page = nil
        errorMessage = nil
        isSearching = false
        let requestedQuery = query
        guard requestedQuery.utf8.count <= QuranVerseSearch.maximumQueryUTF8Bytes else {
            errorMessage = QuranVerseSearch.SearchError.queryTooLong.localizedDescription
            return
        }
        guard QuranVerseSearch.isSearchable(requestedQuery) else { return }
        isSearching = true
        defer { if activeRequestID == requestID { isSearching = false } }
        do {
            try await Task.sleep(for: .milliseconds(300))
            let result = try await Self.searchService.search(requestedQuery)
            try Task.checkCancellation()
            guard activeRequestID == requestID, query == requestedQuery else { return }
            page = result
        } catch is CancellationError {
            // Newer input owns its own progress and results.
        } catch {
            guard !Task.isCancelled, activeRequestID == requestID, query == requestedQuery else { return }
            errorMessage = "Sökningen kunde inte slutföras. Ändra söktexten och försök igen."
        }
    }
}
