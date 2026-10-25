import Foundation
import XCTest
import QuranCore
@testable import Sakina

final class ContentIssueReportTests: XCTestCase {
    func testExportContainsOnlyExplicitReportInputsAndFixedSourceIdentities() throws {
        let report = try makeReport(topic: .readingText)
        let object = try object(report)
        XCTAssertEqual(Set(object.keys), ["schema_version", "reference", "topic", "reading_edition",
                                          "tajweed_edition", "tajweed_enabled", "related_source", "description"])
        XCTAssertEqual(object["reading_edition"] as? String, "quran-uthmani")
        XCTAssertEqual(object["tajweed_edition"] as? String, "quran-tajweed")
        let reference = try XCTUnwrap(object["reference"] as? [String: Int])
        XCTAssertEqual(reference, ["surahID": 2, "ayahNumber": 255])
        XCTAssertEqual(object["description"] as? String, "Kontrollera visningen.")
        XCTAssertEqual(try report.jsonData(), try report.jsonData())
    }

    func testTafsirAndRecitationAreBoundToTheirOwnSources() throws {
        let tafsir = try makeReport(topic: .tafsir)
        XCTAssertEqual(tafsir.relatedSource, "ar.muyassar")
        XCTAssertNil(tafsir.reciter)
        for reciter in Reciter.allCases {
            let report = try makeReport(topic: .recitation, reciter: reciter)
            XCTAssertEqual(report.relatedSource, "EveryAyah/\(reciter.directoryName)")
            XCTAssertEqual(report.reciter, reciter)
            XCTAssertEqual(try object(report)["reciter"] as? String, reciter.rawValue)
        }
        XCTAssertEqual(try makeReport(topic: .tajweed).relatedSource, "quran-tajweed")
    }

    func testEmptyAndOversizedDescriptionsAreRejectedIncludingCombiningMarkPayload() throws {
        for empty in ["", " \n\t "] {
            XCTAssertThrowsError(try makeReport(description: empty)) {
                XCTAssertEqual($0 as? ContentIssueReport.ValidationError, .missingDescription)
            }
        }
        XCTAssertNoThrow(try makeReport(description: String(repeating: "ع", count: 2_000)))
        let oversized = [String(repeating: "ع", count: 2_001), "ا" + String(repeating: "\u{064E}", count: 8_001)]
        for input in oversized {
            XCTAssertThrowsError(try makeReport(description: input)) {
                XCTAssertEqual($0 as? ContentIssueReport.ValidationError, .descriptionTooLong)
            }
        }
    }

    func testDescriptionRetainsArabicScalarsAndUnknownCharacters() throws {
        let description = "\u{FEFF}بِّسْمِ ٱللَّهِ\u{200F} e\u{0301}"
        let report = try makeReport(description: description)
        XCTAssertEqual(Array(report.description.utf8), Array(description.utf8), "The report input must retain every scalar")
        let encoded = try report.jsonData()
        struct DescriptionOnly: Decodable { let description: String }
        let typed = try JSONDecoder().decode(DescriptionOnly.self, from: encoded)
        XCTAssertEqual(Array(typed.description.utf8), Array(description.utf8))
        let exported = try XCTUnwrap(try object(report)["description"] as? String)
        XCTAssertEqual(Array(exported.utf8), Array(description.utf8))
        XCTAssertNotNil(encoded.range(of: Data("\\uFEFF".utf8)), "The leading scalar uses an unambiguous JSON escape")

        // A control with the system encoder localizes the prior Darwin loss.
        // This is a fixed synthetic fixture, never an actual user's report.
        let control = try JSONEncoder().encode(report)
        let controlObject = try XCTUnwrap(JSONSerialization.jsonObject(with: control) as? [String: Any])
        let controlDescription = try XCTUnwrap(controlObject["description"] as? String)
        print("Content report Unicode control: raw input marker=\(report.description.utf8.starts(with: [0xEF, 0xBB, 0xBF])), encoded literal marker=\(control.range(of: Data([0xEF, 0xBB, 0xBF])) != nil), Foundation-decoded marker=\(controlDescription.utf8.starts(with: [0xEF, 0xBB, 0xBF]))")
    }

    private func makeReport(topic: ContentIssueReport.Topic = .readingText, reciter: Reciter = .alafasy,
                            description: String = "Kontrollera visningen.") throws -> ContentIssueReport {
        try ContentIssueReport(reference: XCTUnwrap(AyahReference(surahID: 2, ayahNumber: 255)),
                               topic: topic, tajweedEnabled: true, reciter: reciter, description: description)
    }

    private func object(_ report: ContentIssueReport) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: report.jsonData()) as? [String: Any])
    }
}
