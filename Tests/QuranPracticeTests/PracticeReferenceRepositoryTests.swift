import Foundation
import XCTest
import QuranCore
@testable import QuranPractice

final class PracticeReferenceRepositoryTests: XCTestCase {
    private var resourceDirectory: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/QuranPractice/Resources/PracticeReferences", isDirectory: true)
    }

    func testEveryPracticeReferencePreservesItsOwnEditionAndVerseIdentity() async throws {
        let repository = PracticeReferenceRepository()
        var total = 0
        for surahID in 1...114 {
            let file = resourceDirectory.appendingPathComponent(String(format: "%03d.json", surahID))
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
            XCTAssertEqual(object["surah_id"] as? Int, surahID)
            let ayahs = try XCTUnwrap(object["ayahs"] as? [[String: Any]])
            let basmala = object["basmala"] as? String
            XCTAssertEqual(ayahs.count, AyahReference.ayahCounts[surahID - 1])
            for (index, ayah) in ayahs.enumerated() {
                let number = index + 1
                XCTAssertEqual(ayah["ayah_number"] as? Int, number)
                let source = try XCTUnwrap(ayah["text"] as? String)
                let reference = try XCTUnwrap(AyahReference(surahID: surahID, ayahNumber: number))
                let result = try await repository.text(for: reference)
                XCTAssertTrue(result.text.utf8.elementsEqual(source.utf8))
                XCTAssertEqual(result.scalarOffset, 0)
                if number == 1, let basmala {
                    let combined = try await repository.text(for: reference, includeBasmala: true)
                    XCTAssertTrue(combined.text.utf8.elementsEqual((basmala + " " + source).utf8))
                    XCTAssertEqual(combined.scalarOffset, 0)
                }
                total += 1
            }
        }
        XCTAssertEqual(total, 6236)
    }

    func testRejectsWrongEditionAndChapterReferenceCounts() async throws {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let indexURL = resourceDirectory.appendingPathComponent("index.json")
        var index = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: indexURL)) as? [String: Any])
        let reference = AyahReference(surahID: 1, ayahNumber: 1)!
        index["source"] = "quran-uthmani"
        try JSONSerialization.data(withJSONObject: index).write(to: temporary.appendingPathComponent("index.json"))
        do {
            _ = try await PracticeReferenceRepository(resourceDirectory: temporary).text(for: reference)
            XCTFail("Wrong edition must be rejected")
        } catch { XCTAssertEqual(error as? AssessmentError, .invalidReference) }

        try Data(contentsOf: indexURL).write(to: temporary.appendingPathComponent("index.json"))
        let badChapter: [String: Any] = ["surah_id": 1, "basmala": NSNull(), "ayahs": [["ayah_number": 1, "text": "بِسْمِ"]]]
        try JSONSerialization.data(withJSONObject: badChapter).write(to: temporary.appendingPathComponent("001.json"))
        do {
            _ = try await PracticeReferenceRepository(resourceDirectory: temporary).text(for: reference)
            XCTFail("Incomplete chapter must be rejected")
        } catch { XCTAssertEqual(error as? AssessmentError, .invalidReference) }
    }
}
