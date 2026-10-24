import Foundation
import QuranCore

/// A separate, pinned edition used only for the experimental pronunciation model.
/// Its character positions must never be applied to the reading edition.
public actor PracticeReferenceRepository {
    public static let source = "quran-transcript-0.6.4"
    private let directory: URL?
    private var chapters: [Int: Chapter] = [:]
    private var recentlyUsed: [Int] = []
    private var validatedIndex = false

    private struct Index: Decodable {
        struct SurahCount: Decodable { let id: Int; let count: Int }
        let version: Int
        let source: String
        let surahs: [SurahCount]
    }

    private struct Chapter: Decodable {
        let surahID: Int
        let basmala: String?
        let ayahs: [Verse]
        enum CodingKeys: String, CodingKey { case surahID = "surah_id", basmala, ayahs }
    }
    private struct Verse: Decodable {
        let ayahNumber: Int
        let text: String
        enum CodingKeys: String, CodingKey { case ayahNumber = "ayah_number", text }
    }

    public init(resourceDirectory: URL? = nil) {
        directory = resourceDirectory ?? Bundle.module.resourceURL?.appendingPathComponent("PracticeReferences", isDirectory: true)
    }

    public func text(for reference: AyahReference, includeBasmala: Bool = false) throws -> AssessmentText {
        try validateIndex()
        if let chapter = chapters[reference.surahID] {
            touch(reference.surahID)
            return presentation(chapter: chapter, reference: reference, includeBasmala: includeBasmala)
        }
        guard let directory else { throw AssessmentError.invalidReference }
        let path = directory.appendingPathComponent(String(format: "%03d.json", reference.surahID))
        guard let data = try? Data(contentsOf: path),
              let chapter = try? JSONDecoder().decode(Chapter.self, from: data),
              chapter.surahID == reference.surahID,
              chapter.ayahs.count == AyahReference.ayahCounts[reference.surahID - 1],
              chapter.ayahs.enumerated().allSatisfy({ $0.element.ayahNumber == $0.offset + 1 && !$0.element.text.isEmpty }),
              ([1, 9].contains(chapter.surahID) ? chapter.basmala == nil : chapter.basmala?.isEmpty == false) else {
            throw AssessmentError.invalidReference
        }
        chapters[reference.surahID] = chapter
        touch(reference.surahID)
        while recentlyUsed.count > 4 { chapters.removeValue(forKey: recentlyUsed.removeFirst()) }
        return presentation(chapter: chapter, reference: reference, includeBasmala: includeBasmala)
    }

    private func presentation(chapter: Chapter, reference: AyahReference, includeBasmala: Bool) -> AssessmentText {
        AssessmentText(text: chapter.ayahs[reference.ayahNumber - 1].text, basmala: chapter.basmala,
                       reference: reference, includeBasmala: includeBasmala)
    }

    private func validateIndex() throws {
        guard !validatedIndex else { return }
        guard let directory,
              let data = try? Data(contentsOf: directory.appendingPathComponent("index.json")),
              let index = try? JSONDecoder().decode(Index.self, from: data),
              index.version == 1, index.source == Self.source, index.surahs.count == 114,
              index.surahs.enumerated().allSatisfy({ $0.element.id == $0.offset + 1 && $0.element.count == AyahReference.ayahCounts[$0.offset] }) else {
            throw AssessmentError.invalidReference
        }
        validatedIndex = true
    }

    private func touch(_ id: Int) {
        recentlyUsed.removeAll { $0 == id }
        recentlyUsed.append(id)
    }
}
