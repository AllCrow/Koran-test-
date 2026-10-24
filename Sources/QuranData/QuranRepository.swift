import Foundation
import QuranCore

/// The index is small; chapter text is decoded only when a reader requests it.
public actor QuranRepository {
    public enum RepositoryError: LocalizedError, Equatable {
        case missingResource(String)
        case invalidIndex
        case invalidChapter(Int)

        public var errorDescription: String? {
            switch self {
            case .missingResource:
                return "Korantexten saknas i appen. Installera om appen och försök igen."
            case .invalidIndex, .invalidChapter:
                return "Korantexten kunde inte verifieras. Försök installera om appen."
            }
        }
    }

    private let resourceDirectory: URL
    private var cachedIndex: ContentIndex?
    private var chapters: [Int: QuranChapter] = [:]
    private var recentChapterIDs: [Int] = []
    private let chapterCacheLimit = 4

    public init(bundle: Bundle = .main) {
        resourceDirectory = (bundle.resourceURL ?? bundle.bundleURL)
            .appendingPathComponent("Quran", isDirectory: true)
    }

    /// The directory contains index.json and one numbered JSON file per chapter.
    public init(resourceDirectory: URL) {
        self.resourceDirectory = resourceDirectory
    }

    public func loadIndex() throws -> ContentIndex {
        if let cachedIndex { return cachedIndex }
        let index = try decode(ContentIndex.self, named: "index")
        guard index.version == 1, !index.source.isEmpty,
              index.surahs.count == AyahReference.ayahCounts.count,
              index.surahs.enumerated().allSatisfy({ position, surah in
                  surah.id == position + 1 &&
                  surah.numberOfAyahs == AyahReference.ayahCounts[position] &&
                  !surah.name.isEmpty && !surah.englishName.isEmpty
              }) else {
            throw RepositoryError.invalidIndex
        }
        cachedIndex = index
        return index
    }

    public func loadChapter(id: Int) throws -> QuranChapter {
        guard (1...AyahReference.ayahCounts.count).contains(id) else {
            throw RepositoryError.invalidChapter(id)
        }
        if let chapter = chapters[id] {
            touch(id)
            return chapter
        }
        let index = try loadIndex()
        let chapter = try decode(QuranChapter.self, named: String(format: "%03d", id))
        let expectedCount = AyahReference.ayahCounts[id - 1]
        let firstGlobalID = AyahReference.ayahCounts.prefix(id - 1).reduce(0, +) + 1
        guard chapter.surah == index.surahs[id - 1], chapter.ayahs.count == expectedCount,
              chapter.ayahs.enumerated().allSatisfy({ position, ayah in
                  ayah.surahID == id && ayah.numberInSurah == position + 1 &&
                  ayah.id == firstGlobalID + position && !ayah.text.isEmpty
              }) else {
            throw RepositoryError.invalidChapter(id)
        }
        chapters[id] = chapter
        touch(id)
        while recentChapterIDs.count > chapterCacheLimit {
            chapters.removeValue(forKey: recentChapterIDs.removeFirst())
        }
        return chapter
    }

    private func touch(_ id: Int) {
        recentChapterIDs.removeAll { $0 == id }
        recentChapterIDs.append(id)
    }

    private func decode<T: Decodable>(_ type: T.Type, named name: String) throws -> T {
        let url = resourceDirectory.appendingPathComponent(name).appendingPathExtension("json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw RepositoryError.missingResource(name)
        }
        return try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }
}
