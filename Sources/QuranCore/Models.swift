import Foundation

public struct Surah: Codable, Hashable, Identifiable, Sendable {
    public let id: Int
    public let name: String
    public let englishName: String
    public let englishNameTranslation: String
    public let numberOfAyahs: Int
    public let revelationType: String

    public init(id: Int, name: String, englishName: String, englishNameTranslation: String, numberOfAyahs: Int, revelationType: String) {
        self.id = id
        self.name = name
        self.englishName = englishName
        self.englishNameTranslation = englishNameTranslation
        self.numberOfAyahs = numberOfAyahs
        self.revelationType = revelationType
    }
}

public struct Ayah: Codable, Hashable, Identifiable, Sendable {
    /// Global verse number in the Hafs numbering used by the bundled source.
    public let id: Int
    public let surahID: Int
    public let numberInSurah: Int
    /// Verbatim Uthmani source text. Never normalize or rebuild it for display.
    public let text: String
    /// A separate annotated edition; its character offsets do not match `text`.
    public let tajweed: String?

    public var reference: AyahReference? { AyahReference(surahID: surahID, ayahNumber: numberInSurah) }

    public init(id: Int, surahID: Int, numberInSurah: Int, text: String, tajweed: String? = nil) {
        self.id = id
        self.surahID = surahID
        self.numberInSurah = numberInSurah
        self.text = text
        self.tajweed = tajweed
    }
}

public struct QuranChapter: Codable, Hashable, Sendable {
    public let surah: Surah
    public let ayahs: [Ayah]

    public init(surah: Surah, ayahs: [Ayah]) {
        self.surah = surah
        self.ayahs = ayahs
    }
}

public struct ContentIndex: Codable, Hashable, Sendable {
    public let version: Int
    public let source: String
    public let surahs: [Surah]

    public init(version: Int, source: String, surahs: [Surah]) {
        self.version = version
        self.source = source
        self.surahs = surahs
    }
}

/// A validated reference for the Hafs verse numbering used by the text and audio.
public struct AyahReference: Codable, Hashable, Identifiable, Sendable {
    public let surahID: Int
    public let ayahNumber: Int
    public var id: String { "\(surahID):\(ayahNumber)" }

    public static let ayahCounts = [
        7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128,
        111, 110, 98, 135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30,
        73, 54, 45, 83, 182, 88, 75, 85, 54, 53, 89, 59, 37, 35, 38, 29, 18,
        45, 60, 49, 62, 55, 78, 96, 29, 22, 24, 13, 14, 11, 11, 18, 12, 12,
        30, 52, 52, 44, 28, 28, 20, 56, 40, 31, 50, 40, 46, 42, 29, 19, 36,
        25, 22, 17, 19, 26, 30, 20, 15, 21, 11, 8, 8, 19, 5, 8, 8, 11, 11,
        8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5, 6
    ]

    public init?(surahID: Int, ayahNumber: Int) {
        guard (1...Self.ayahCounts.count).contains(surahID),
              (1...Self.ayahCounts[surahID - 1]).contains(ayahNumber) else { return nil }
        self.surahID = surahID
        self.ayahNumber = ayahNumber
    }

    private enum CodingKeys: String, CodingKey { case surahID, ayahNumber }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let surah = try container.decode(Int.self, forKey: .surahID)
        let ayah = try container.decode(Int.self, forKey: .ayahNumber)
        guard let reference = Self(surahID: surah, ayahNumber: ayah) else {
            throw DecodingError.dataCorruptedError(forKey: .ayahNumber, in: container, debugDescription: "Invalid Hafs ayah reference")
        }
        self = reference
    }
}

public enum Reciter: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case alafasy
    case husary
    case minshawi

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .alafasy: return "Mishary al-Afasy"
        case .husary: return "Mahmoud al-Husary"
        case .minshawi: return "Muhammad al-Minshawi"
        }
    }

    public var directoryName: String {
        switch self {
        case .alafasy: return "Alafasy_128kbps"
        case .husary: return "Husary_128kbps"
        case .minshawi: return "Minshawy_Murattal_128kbps"
        }
    }

    /// EveryAyah supplies a separate recording for each validated verse.
    public func audioURL(for reference: AyahReference) -> URL {
        let filename = String(format: "%03d%03d.mp3", reference.surahID, reference.ayahNumber)
        // All components are constants or range-validated integers.
        return URL(string: "https://everyayah.com/data/\(directoryName)/\(filename)")!
    }
}
