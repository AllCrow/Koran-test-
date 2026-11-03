import Foundation
import QuranCore

/// Searches the bundled reading edition without modifying or indexing displayed text.
/// This actor and QuranRepository keep decoding and Unicode work off the UI actor.
public actor QuranVerseSearch {
    public static let maximumQueryUTF8Bytes = 512
    public static let maximumResultCount = 100

    public struct Hit: Identifiable, Equatable, Sendable {
        public let reference: AyahReference
        public let surahName: String
        /// Exact canonical presentation slice, never a normalized search key.
        public let text: String
        public var id: String { reference.id }
    }

    public struct Page: Equatable, Sendable {
        public let hits: [Hit]
        /// There is at least one further match. This is not a full result count.
        public let hasMore: Bool
    }

    public enum SearchError: LocalizedError, Equatable {
        case queryTooLong

        public var errorDescription: String? {
            "Sökningen är för lång. Skriv några ord från versen och försök igen."
        }
    }

    private let repository: QuranRepository

    public init(repository: QuranRepository = QuranRepository()) {
        self.repository = repository
    }

    /// Results follow Quran order. A short/empty/non-Arabic query performs no IO.
    /// Only the requested results and one decoded chapter are retained by this
    /// scan; the repository independently keeps its existing four-chapter cache.
    public func search(_ input: String, limit requestedLimit: Int = 50) async throws -> Page {
        try Task.checkCancellation()
        guard input.utf8.count <= Self.maximumQueryUTF8Bytes else { throw SearchError.queryTooLong }
        let query = Self.normalizedCopy(input)
        guard Self.arabicLetterCount(query) >= 2 else { return Page(hits: [], hasMore: false) }
        let limit = min(Self.maximumResultCount, max(1, requestedLimit))
        var hits: [Hit] = []
        hits.reserveCapacity(limit)
        for id in 1...AyahReference.ayahCounts.count {
            try Task.checkCancellation()
            let chapter = try await repository.loadChapter(id: id)
            try Task.checkCancellation()
            for ayah in chapter.ayahs {
                try Task.checkCancellation()
                let text = QuranPresentation.verseText(ayah)
                guard Self.normalizedCopy(text).contains(query), let reference = ayah.reference else { continue }
                if hits.count == limit {
                    try Task.checkCancellation()
                    return Page(hits: hits, hasMore: true)
                }
                hits.append(Hit(reference: reference, surahName: chapter.surah.englishName, text: text))
            }
        }
        try Task.checkCancellation()
        return Page(hits: hits, hasMore: false)
    }

    public nonisolated static func isSearchable(_ input: String) -> Bool {
        input.utf8.count <= maximumQueryUTF8Bytes && arabicLetterCount(normalizedCopy(input)) >= 2
    }

    /// Normalization is deliberately confined to disposable matching copies.
    /// No character ranges from this representation are used in the reading text.
    nonisolated static func normalizedCopy(_ input: String) -> String {
        var result = String.UnicodeScalarView()
        var needsSpace = false
        for scalar in input.decomposedStringWithCanonicalMapping.unicodeScalars {
            if CharacterSet.nonBaseCharacters.contains(scalar) || scalar.value == 0x0640 ||
                scalar.value == 0xFEFF || (0x06D6...0x06ED).contains(scalar.value) { continue }
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                needsSpace = !result.isEmpty
                continue
            }
            if needsSpace { result.append(" "); needsSpace = false }
            switch scalar.value {
            case 0x0671: result.append("ا") // alif-wasl from the reading edition
            case 0x0649, 0x06CC: result.append("ي") // alif-maqsura / keyboard ya
            case 0x06A9: result.append("ك") // keyboard kaf
            default: result.append(scalar)
            }
        }
        return String(result)
    }

    private nonisolated static func arabicLetterCount(_ input: String) -> Int {
        input.unicodeScalars.reduce(0) { count, scalar in
            count + (((0x0621...0x064A).contains(scalar.value) ||
                      (0x066E...0x06D3).contains(scalar.value)) && CharacterSet.letters.contains(scalar) ? 1 : 0)
        }
    }
}
