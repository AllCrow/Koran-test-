import SwiftUI
import QuranCore
import QuranData

@MainActor
struct TafsirSheet: View {
    let reference: AyahReference
    @Environment(\.dismiss) private var dismiss
    @State private var entry: TafsirEntry?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var loadID = UUID()
    @State private var activeRequestID: UUID?
    private static let repository = TafsirRepository()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Label("Al-Muyassar · arabiska", systemImage: "text.book.closed")
                        .font(.headline).foregroundStyle(Palette.green)
                    Text("Förklaring till vers \(reference.surahID):\(reference.ayahNumber)")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if isLoading { ProgressView("Hämtar tafsir …").frame(maxWidth: .infinity).padding() }
                    if let entry {
                        ArabicText(text: entry.text, tajweed: nil, colored: false)
                        Divider()
                        Text("Källa: \(entry.sourceName), via AlQuran Cloud. Detta är källans förklaring på arabiska.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if let errorMessage {
                        ErrorBanner(message: errorMessage)
                        Button("Försök igen") { loadID = UUID() }
                            .frame(minHeight: 44)
                    }
                    Text("Tafsir hämtas från internet. Korantexten kan du alltid läsa offline.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(24)
            }
            .background(Palette.background)
            .navigationTitle("Tafsir").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Stäng") { dismiss() } } }
            .task(id: loadID) { await load() }
        }
    }

    private func load() async {
        guard !Task.isCancelled else { return }
        // Every execution gets its own identity, including a lifecycle restart
        // with the same retry ID. An older cancelled task must not suppress the
        // new load or clear its loading state when it eventually unwinds.
        let requestID = UUID()
        activeRequestID = requestID
        isLoading = true
        errorMessage = nil
        defer {
            if activeRequestID == requestID {
                isLoading = false
                activeRequestID = nil
            }
        }
        do {
            let loaded = try await Self.repository.tafsir(for: reference)
            try Task.checkCancellation()
            guard activeRequestID == requestID else { return }
            entry = loaded
        }
        catch is CancellationError { }
        catch {
            guard activeRequestID == requestID, !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }
}
