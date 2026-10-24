import SwiftUI
import QuranCore

struct TafsirSheet: View {
    let reference: AyahReference
    @Environment(\.dismiss) private var dismiss
    @State private var entry: TafsirEntry?
    @State private var errorMessage: String?
    @State private var isLoading = false
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
                        Button("Försök igen") { Task { await load() } }
                    }
                    Text("Tafsir hämtas från internet. Korantexten kan du alltid läsa offline.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(24)
            }
            .background(Palette.background)
            .navigationTitle("Tafsir").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Stäng") { dismiss() } } }
            .task { await load() }
        }
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do { entry = try await Self.repository.tafsir(for: reference) }
        catch is CancellationError { }
        catch { errorMessage = error.localizedDescription }
    }
}
