import SwiftUI
import QuranCore
import QuranData

@MainActor
struct TafsirSheet: View {
    let reference: AyahReference
    @Environment(\.dismiss) private var dismiss
    private enum LoadState {
        case loading
        case loaded(AyahReference, TafsirEntry)
        case failed(AyahReference, String)
    }
    private struct RequestKey: Hashable {
        let reference: AyahReference
        let retryID: UUID
    }
    @State private var state = LoadState.loading
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
                    switch state {
                    case .loaded(let loadedReference, let entry) where loadedReference == reference:
                        Card {
                            ArabicText(text: entry.text, tajweed: nil, colored: false)
                            Divider().padding(.vertical, 20)
                            Text("Källa: \(entry.sourceName), via AlQuran Cloud. Detta är källans förklaring på arabiska.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    case .failed(let failedReference, let errorMessage) where failedReference == reference:
                        ErrorBanner(message: errorMessage)
                        PrimaryButton(title: "Försök igen", icon: "arrow.clockwise") { loadID = UUID() }
                    default:
                        ProgressView("Hämtar tafsir …")
                            .frame(maxWidth: .infinity).padding(.vertical, 32)
                    }
                    Text("De senast öppnade förklaringarna kan läsas offline när de har sparats på din iPhone. För nya verser behövs internet. Korantexten finns alltid i appen.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(24)
            }
            .background(Palette.background)
            .navigationTitle("Tafsir").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Stäng") { dismiss() } } }
            .task(id: RequestKey(reference: reference, retryID: loadID)) { await load() }
        }
    }

    private func load() async {
        guard !Task.isCancelled else { return }
        // Every execution gets its own identity, including a lifecycle restart
        // with the same retry ID. An older cancelled task must not suppress the
        // new load or clear its loading state when it eventually unwinds.
        let requestID = UUID()
        activeRequestID = requestID
        state = .loading
        defer {
            if activeRequestID == requestID {
                activeRequestID = nil
            }
        }
        do {
            let loaded = try await Self.repository.tafsir(for: reference)
            try Task.checkCancellation()
            guard activeRequestID == requestID else { return }
            state = .loaded(reference, loaded)
        }
        catch is CancellationError { }
        catch {
            guard activeRequestID == requestID, !Task.isCancelled else { return }
            state = .failed(reference, error.localizedDescription)
        }
    }
}
