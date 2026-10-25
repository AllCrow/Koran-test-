import Foundation
import XCTest
@testable import Sakina

/// A support export is a strict public-status contract, never a dump of app
/// objects or UserDefaults. These tests guard that boundary as fields evolve.
final class DiagnosticsReportTests: XCTestCase {
    func testReportContainsOnlyWhitelistedPublicStatusFields() throws {
        let report = makeReport(storage: .init(savedSelections: 2, audioBytes: 12_345))
        let root = try object(report)
        XCTAssertEqual(Set(root.keys), ["schema_version", "app_version", "app_build", "platform",
                                       "device_family", "system_version", "audio", "practice", "services", "storage"])
        XCTAssertEqual(root["schema_version"] as? Int, 1)
        XCTAssertEqual(root["platform"] as? String, "iOS")
        XCTAssertEqual(root["device_family"] as? String, "iPhone")
        XCTAssertEqual(root["app_version"] as? String, "0.1.0")
        XCTAssertEqual(root["app_build"] as? String, "53")
        XCTAssertEqual(root["system_version"] as? String, "18.5.0")
        let audio = try XCTUnwrap(root["audio"] as? [String: Any])
        XCTAssertEqual(Set(audio.keys), ["playback", "allows_cellular_audio", "download_active"])
        let practice = try XCTUnwrap(root["practice"] as? [String: Any])
        XCTAssertEqual(Set(practice.keys), ["state", "has_temporary_take"])
        let services = try XCTUnwrap(root["services"] as? [String: Any])
        XCTAssertEqual(Set(services.keys), ["reading_loading", "experimental_assessment_available", "assessment_running", "error_areas"])
        let storage = try XCTUnwrap(root["storage"] as? [String: Any])
        XCTAssertEqual(Set(storage.keys), ["status", "saved_selections", "audio_bytes"])
        XCTAssertEqual(storage["audio_bytes"] as? Int, 12_345)
    }

    func testUnexpectedBundleStringsCannotBecomeAnExportChannel() throws {
        let privateValue = "private-person@example.invalid/private/recording.m4a?api_key=secret"
        for unsafe in [privateValue, "١.٢", "1..2", ".1", "1.", String(repeating: "1", count: 100)] {
            let report = makeReport(version: unsafe, build: unsafe)
            let root = try object(report)
            XCTAssertEqual(root["app_version"] as? String, "unknown")
            XCTAssertEqual(root["app_build"] as? String, "unknown")
            let text = try XCTUnwrap(String(data: report.jsonData(), encoding: .utf8))
            XCTAssertFalse(text.contains(unsafe))
            XCTAssertFalse(text.contains("api_key"))
            XCTAssertFalse(text.contains("recording.m4a"))
        }
    }

    func testUnavailableOrInvalidStorageDoesNotInventAnEmptyLibrary() throws {
        let unavailable: [DiagnosticsReport.Storage] = [
            .unavailable, .pending,
            .init(savedSelections: -1, audioBytes: 20),
            .init(savedSelections: 343, audioBytes: 20),
            .init(savedSelections: 1, audioBytes: -1),
            .init(savedSelections: 1, audioBytes: Int64.max)
        ]
        for value in unavailable {
            let storage = try XCTUnwrap(try object(makeReport(storage: value))["storage"] as? [String: Any])
            XCTAssertNotEqual(storage["status"] as? String, "checked")
            XCTAssertNil(storage["saved_selections"])
            XCTAssertNil(storage["audio_bytes"])
        }
        let empty = try XCTUnwrap(try object(makeReport(storage: .init(savedSelections: 0, audioBytes: 0)))["storage"] as? [String: Any])
        XCTAssertEqual(empty["status"] as? String, "checked")
        XCTAssertEqual(empty["saved_selections"] as? Int, 0)
        XCTAssertEqual(empty["audio_bytes"] as? Int, 0)
    }

    func testErrorAreasAreTypedDistinctAndStable() throws {
        let report = makeReport(errors: [.storage, .reading, .storage, .assessment, .reading])
        let services = try XCTUnwrap(try object(report)["services"] as? [String: Any])
        XCTAssertEqual(services["error_areas"] as? [String], ["reading", "assessment", "storage"])
        let text = try XCTUnwrap(String(data: report.jsonData(), encoding: .utf8))
        for forbidden in ["error_message", "url", "recorded_reference", "last_read", "bookmarks", "filename", "defaults"] {
            XCTAssertFalse(text.contains("\"\(forbidden)\""))
        }
    }

    func testPreviewEncodingIsDeterministicAndKeepsStatusValues() throws {
        let report = makeReport()
        XCTAssertEqual(try report.jsonData(), try report.jsonData())
        let root = try object(report)
        let audio = try XCTUnwrap(root["audio"] as? [String: Any])
        XCTAssertEqual(audio["playback"] as? String, "paused")
        XCTAssertEqual(audio["allows_cellular_audio"] as? Bool, false)
        XCTAssertEqual(audio["download_active"] as? Bool, true)
        let practice = try XCTUnwrap(root["practice"] as? [String: Any])
        XCTAssertEqual(practice["state"] as? String, "requesting_permission")
        XCTAssertEqual(practice["has_temporary_take"] as? Bool, true)
    }

    private func makeReport(version: String? = "0.1.0", build: String? = "53",
                            storage: DiagnosticsReport.Storage = .unavailable,
                            errors: [DiagnosticsReport.ErrorArea] = []) -> DiagnosticsReport {
        DiagnosticsReport(
            appVersion: version, appBuild: build,
            systemVersion: .init(majorVersion: 18, minorVersion: 5, patchVersion: 0),
            audio: .init(playback: .paused, allowsCellularAudio: false, downloadActive: true),
            practice: .init(state: .requestingPermission, hasTemporaryTake: true),
            services: .init(readingLoading: false, experimentalAssessmentAvailable: false,
                            assessmentRunning: false, errorAreas: errors),
            storage: storage
        )
    }

    private func object(_ report: DiagnosticsReport) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: report.jsonData()) as? [String: Any])
    }
}
