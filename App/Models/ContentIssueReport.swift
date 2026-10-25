import Foundation
import QuranCore

/// A deliberately small, user-created content report. It takes no AppStore,
/// filesystem URL, recording, account or history input. The description is the
/// only free-form field and is always shown before the user exports it.
struct ContentIssueReport: Encodable, Equatable, Sendable {
    enum Topic: String, CaseIterable, Identifiable, Encodable, Sendable {
        case readingText = "reading_text", tajweed, tafsir, recitation

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .readingText: return "Arabisk korantext"
            case .tajweed: return "Tajweedvisning"
            case .tafsir: return "Tafsirförklaring"
            case .recitation: return "Recitationsljud"
            }
        }
    }

    enum ValidationError: LocalizedError, Equatable {
        case missingDescription, descriptionTooLong

        var errorDescription: String? {
            switch self {
            case .missingDescription: return "Beskriv vad du vill få granskat innan du skapar rapporten."
            case .descriptionTooLong: return "Beskrivningen är för lång. Korta den till högst 2 000 tecken."
            }
        }
    }

    static let maximumDescriptionCharacters = 2_000
    // A grapheme may contain arbitrarily many combining marks. Bound bytes too.
    static let maximumDescriptionBytes = 16_000

    let schemaVersion = 1
    let reference: AyahReference
    let topic: Topic
    let readingEdition = "quran-uthmani"
    let tajweedEdition = "quran-tajweed"
    let tajweedEnabled: Bool
    let relatedSource: String
    let reciter: Reciter?
    let description: String

    init(reference: AyahReference, topic: Topic, tajweedEnabled: Bool,
         reciter: Reciter, description: String) throws {
        let description = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty else { throw ValidationError.missingDescription }
        guard description.count <= Self.maximumDescriptionCharacters,
              description.utf8.count <= Self.maximumDescriptionBytes else {
            throw ValidationError.descriptionTooLong
        }
        self.reference = reference
        self.topic = topic
        self.tajweedEnabled = tajweedEnabled
        self.description = description
        self.reciter = topic == .recitation ? reciter : nil
        switch topic {
        case .readingText: relatedSource = "quran-uthmani"
        case .tajweed: relatedSource = "quran-tajweed"
        case .tafsir: relatedSource = "ar.muyassar"
        case .recitation: relatedSource = "EveryAyah/\(reciter.directoryName)"
        }
    }

    func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version", reference, topic, description, reciter
        case readingEdition = "reading_edition", tajweedEdition = "tajweed_edition"
        case tajweedEnabled = "tajweed_enabled", relatedSource = "related_source"
    }
}
