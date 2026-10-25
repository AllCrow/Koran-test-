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
        let exported = try XCTUnwrap(try object(report)["description"] as? String)
        XCTAssertEqual(Array(exported.utf8), Array(description.utf8))
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
