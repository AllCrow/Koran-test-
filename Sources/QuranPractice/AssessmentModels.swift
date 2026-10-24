import Foundation
import QuranCore

/// A prototype model's output, never a certification or a recitation score.
public struct RecitationAssessment: Codable, Hashable, Sendable {
    public enum Status: String, Codable, Sendable { case assessed, unavailable, insufficientAudio = "insufficient_audio" }

    public let schemaVersion: Int
    public let status: Status
    public let experimental: Bool
    public let engine: String
    public let engineVersion: String
    public let model: String
    public let modelRevision: String
    public let reference: AssessmentReference
    public let referenceSource: String
    public let referenceText: String
    public let referenceScalarOffset: Int
    public let includeBasmala: Bool
    public let issues: [AssessmentIssue]
    public let message: String
    public let assumptions: [String]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version", status, experimental, engine
        case engineVersion = "engine_version", model, modelRevision = "model_revision"
        case reference, referenceSource = "reference_source", referenceText = "reference_text", referenceScalarOffset = "reference_scalar_offset"
        case includeBasmala = "include_basmala", issues, message, assumptions
    }
}

public struct AssessmentReference: Codable, Hashable, Sendable {
    public let surahID: Int
    public let ayahNumber: Int

    enum CodingKeys: String, CodingKey { case surahID = "surah_id", ayahNumber = "ayah_number" }
}

public struct AssessmentIssue: Codable, Hashable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable { case tajweed, normal, tashkeel }
    public enum Category: String, Codable, Sendable { case insert, delete, replace }

    public let kind: Kind
    public let category: Category
    /// Half-open offsets into `referenceText.unicodeScalars`, never UTF-16 or graphemes.
    public let startScalar: Int
    public let endScalar: Int
    public let expected: String
    public let observed: String
    public let message: String

    public var id: String { "\(kind.rawValue):\(category.rawValue):\(startScalar):\(endScalar):\(expected):\(observed)" }

    enum CodingKeys: String, CodingKey {
        case kind, category, startScalar = "start_scalar", endScalar = "end_scalar", expected, observed, message
    }
}

public enum RecordingFormat: String, Sendable {
    case m4a, wav
    public var mimeType: String { self == .m4a ? "audio/mp4" : "audio/wav" }

    func matches(_ data: Data) -> Bool {
        let bytes = Array(data.prefix(12))
        switch self {
        case .m4a:
            return bytes.count >= 8 && Array(bytes[4..<8]) == Array("ftyp".utf8)
        case .wav:
            return bytes.count >= 12 && Array(bytes[0..<4]) == Array("RIFF".utf8) && Array(bytes[8..<12]) == Array("WAVE".utf8)
        }
    }
}

public enum AssessmentError: LocalizedError, Equatable, Sendable {
    case invalidServiceURL
    case invalidReference
    case invalidRecording
    case recordingTooLarge
    case responseTooLarge
    case invalidResponse
    case serviceUnavailable
    case rateLimited
    case networkUnavailable

    public var errorDescription: String? {
        switch self {
        case .invalidServiceURL, .serviceUnavailable:
            return "Recitationshjälpen är inte tillgänglig just nu."
        case .invalidReference:
            return "Den valda versen kunde inte kontrolleras. Öppna versen igen och försök på nytt."
        case .invalidRecording:
            return "Inspelningen kunde inte läsas. Spela in en ny tagning."
        case .recordingTooLarge:
            return "Inspelningen är för stor. Spela in en kortare tagning."
        case .responseTooLarge, .invalidResponse:
            return "Svaret kunde inte kopplas säkert till din vers. Ingen återkoppling visas."
        case .rateLimited:
            return "Recitationshjälpen är upptagen. Försök igen om en stund."
        case .networkUnavailable:
            return "Recitationshjälpen kunde inte nås. Kontrollera anslutningen och försök igen."
        }
    }
}

/// Reproduces the backend's practice-edition reference using exact scalars.
public struct AssessmentText: Hashable, Sendable {
    public let text: String
    public let scalarOffset: Int

    public init(text: String, basmala: String? = nil, reference: AyahReference, includeBasmala: Bool) {
        let prefix = includeBasmala && reference.ayahNumber == 1 && ![1, 9].contains(reference.surahID) ? basmala : nil
        let combined = prefix.map { $0 + " " + text } ?? text
        let scalars = Array(combined.unicodeScalars)
        var start = 0
        while start < scalars.count && scalars[start] == "\u{FEFF}" { start += 1 }
        scalarOffset = start
        self.text = String(String.UnicodeScalarView(scalars.dropFirst(start)))
    }
}
