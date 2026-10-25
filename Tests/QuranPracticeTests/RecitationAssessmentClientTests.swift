import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
import QuranCore
@testable import QuranPractice

final class RecitationAssessmentClientTests: XCTestCase {
    private let ayah = Ayah(id: 2, surahID: 1, numberInSurah: 2, text: "ٱلْحَمْدُ لِلَّهِ")
    private let audio = Data([0, 0, 0, 24] + Array("ftypM4A ".utf8))
    private var session: URLSession!
    private var practiceText = ""

    override func setUpWithError() throws {
        try super.setUpWithError()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AssessmentURLProtocol.self]
        session = URLSession(configuration: configuration)
        AssessmentURLProtocol.setHandler(nil)
        let repositoryRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let path = repositoryRoot.appendingPathComponent("Sources/QuranPractice/Resources/PracticeReferences/001.json")
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
        let verses = try XCTUnwrap(object["ayahs"] as? [[String: Any]])
        practiceText = try XCTUnwrap(verses.first(where: { $0["ayah_number"] as? Int == 2 })?["text"] as? String)
    }

    override func tearDown() {
        session.invalidateAndCancel()
        session = nil
        AssessmentURLProtocol.setHandler(nil)
        super.tearDown()
    }

    func testRequestUsesExactReferenceAndConstantFilename() async throws {
        let response = try payload()
        AssessmentURLProtocol.setHandler { request in
            XCTAssertEqual(request.url?.absoluteString, "https://analysis.example.test/base/v1/assess")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            let body = Self.requestBody(request)
            let text = String(decoding: body, as: UTF8.self)
            XCTAssertTrue(text.contains("name=\"surah_id\"\r\n\r\n1\r\n"))
            XCTAssertTrue(text.contains("name=\"ayah_number\"\r\n\r\n2\r\n"))
            XCTAssertTrue(text.contains("name=\"include_basmala\"\r\n\r\nfalse\r\n"))
            XCTAssertTrue(text.contains("filename=\"recitation.m4a\""))
            XCTAssertFalse(text.contains("/workspace"))
            XCTAssertEqual(request.httpShouldHandleCookies, false)
            return (200, response, [:])
        }
        let result = try await client().assess(audioData: audio, ayah: ayah)
        XCTAssertEqual(result.status, .assessed)
        XCTAssertEqual(result.referenceText.unicodeScalars.count, practiceText.unicodeScalars.count)
    }

    func testWAVSignatureAcceptedAndMismatchedFormatRejectedWithoutRequest() async throws {
        AssessmentURLProtocol.setHandler { _ in XCTFail("Invalid audio must not be uploaded"); return (200, Data(), [:]) }
        do {
            _ = try await client().assess(audioData: Data("not audio".utf8), ayah: ayah)
            XCTFail("Expected invalid recording")
        } catch { XCTAssertEqual(error as? AssessmentError, .invalidRecording) }
        let wave = Data(Array("RIFF".utf8) + [0, 0, 0, 0] + Array("WAVE".utf8))
        let response = try payload()
        AssessmentURLProtocol.setHandler { request in
            XCTAssertTrue(String(decoding: Self.requestBody(request), as: UTF8.self).contains("audio/wav"))
            return (200, response, [:])
        }
        let waveResult = try await client().assess(audioData: wave, format: .wav, ayah: ayah)
        XCTAssertEqual(waveResult.status, .assessed)
    }

    func testUnavailableCannotCarryCorrections() async throws {
        var object = payloadObject()
        object["status"] = "unavailable"
        object["issues"] = []
        serve(try JSONSerialization.data(withJSONObject: object))
        let result = try await client().assess(audioData: audio, ayah: ayah)
        XCTAssertEqual(result.status, .unavailable)
        XCTAssertTrue(result.issues.isEmpty)
        object["issues"] = [issue(start: 0, end: 1)]
        try await assertInvalid(object)
    }

    func testRejectsWrongVerseEditionAndScalarOffset() async throws {
        var object = payloadObject()
        object["reference"] = ["surah_id": 1, "ayah_number": 3]
        try await assertInvalid(object)
        object = payloadObject()
        object["reference_text"] = "الحمد لله"
        try await assertInvalid(object)
        object = payloadObject()
        object["reference_scalar_offset"] = 1
        try await assertInvalid(object)
        object = payloadObject()
        object["include_basmala"] = true
        try await assertInvalid(object)
        object = payloadObject()
        object["reference_source"] = "quran-uthmani"
        try await assertInvalid(object)
    }

    func testRejectsUnknownSchemaStatusEngineAndNonExperimentalClaims() async throws {
        for (key, value) in [("schema_version", 2 as Any), ("status", "perfect" as Any), ("experimental", false as Any), ("model_revision", "mutable-main" as Any)] {
            var object = payloadObject()
            object[key] = value
            try await assertInvalid(object)
        }
        serve(Data("not-json".utf8))
        do { _ = try await client().assess(audioData: audio, ayah: ayah); XCTFail("Expected invalid response") }
        catch { XCTAssertEqual(error as? AssessmentError, .invalidResponse) }
    }

    func testOffsetsUseUnicodeScalarsAndAllowInsertionAtEnd() async throws {
        let count = practiceText.unicodeScalars.count
        XCTAssertGreaterThan(count, practiceText.count)
        var object = payloadObject()
        object["issues"] = [issue(start: count - 1, end: count), issue(start: count, end: count, category: "insert")]
        serve(try JSONSerialization.data(withJSONObject: object))
        let result = try await client().assess(audioData: audio, ayah: ayah)
        XCTAssertEqual(result.issues.count, 2)
        for badIssue in [issue(start: -1, end: 1), issue(start: 0, end: count + 1), issue(start: 2, end: 1), issue(start: 1, end: 1)] {
            object["issues"] = [badIssue]
            try await assertInvalid(object)
        }
    }

    func testNoOpAndEmptyDifferencesAreRejected() async throws {
        for value in ["ب", ""] {
            var object = payloadObject()
            var invalidIssue = issue(start: 0, end: 1)
            invalidIssue["expected"] = value
            invalidIssue["observed"] = value
            object["issues"] = [invalidIssue]
            try await assertInvalid(object)
        }
    }

    func testDuplicateFeedbackIdentitiesAreRejected() async throws {
        var first = issue(start: 0, end: 1)
        first["expected"] = "أ"
        first["observed"] = "ب"
        var equivalent = first
        equivalent["expected"] = "ا\u{0654}"
        equivalent["message"] = "Another row with the same Swift identity."
        XCTAssertEqual("أ", "ا\u{0654}")
        XCTAssertFalse("أ".utf8.elementsEqual("ا\u{0654}".utf8))
        for second in [first, equivalent] {
            var object = payloadObject()
            object["issues"] = [first, second]
            try await assertInvalid(object)
        }
    }

    func testDistinctScalarSpellingsInOneIssueAreNotNormalizedAway() async throws {
        var object = payloadObject()
        var difference = issue(start: 0, end: 1)
        difference["expected"] = "أ"
        difference["observed"] = "ا\u{0654}"
        object["issues"] = [difference]
        serve(try JSONSerialization.data(withJSONObject: object))
        let received = try await client().assess(audioData: audio, ayah: ayah)
        let receivedIssue = try XCTUnwrap(received.issues.first)
        XCTAssertTrue(receivedIssue.expected.utf8.elementsEqual("أ".utf8))
        XCTAssertTrue(receivedIssue.observed.utf8.elementsEqual("ا\u{0654}".utf8))
    }

    func testPracticeBasmalaCompositionAndBOMPreserveExactScalarOffsets() {
        let firstReference = AyahReference(surahID: 1, ayahNumber: 1)!
        XCTAssertEqual(AssessmentText(text: "\u{FEFF}بِسْمِ", reference: firstReference, includeBasmala: false).text, "بِسْمِ")
        XCTAssertEqual(AssessmentText(text: "\u{FEFF}بِسْمِ", reference: firstReference, includeBasmala: false).scalarOffset, 1)
        let basmala = "بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ"
        let reference = AyahReference(surahID: 95, ayahNumber: 1)!
        let without = AssessmentText(text: "وَٱلتِّينِ", basmala: basmala, reference: reference, includeBasmala: false)
        XCTAssertEqual(without.text, "وَٱلتِّينِ")
        XCTAssertEqual(without.scalarOffset, 0)
        let combined = AssessmentText(text: "وَٱلتِّينِ", basmala: basmala, reference: reference, includeBasmala: true)
        XCTAssertEqual(combined.text, basmala + " وَٱلتِّينِ")
        XCTAssertEqual(combined.scalarOffset, 0)
        let nonOpening = AyahReference(surahID: 95, ayahNumber: 2)!
        XCTAssertEqual(AssessmentText(text: "وَطُورِ سِينِينَ", basmala: basmala, reference: nonOpening, includeBasmala: true).text, "وَطُورِ سِينِينَ")
    }

    func testOversizedAudioIsRejectedBeforeNetworkAndResponseSizeIsBounded() async throws {
        AssessmentURLProtocol.setHandler { _ in XCTFail("Oversized audio must not be uploaded"); return (200, Data(), [:]) }
        do {
            _ = try await client().assess(audioData: Data(repeating: 0, count: RecitationAssessmentClient.maximumRecordingBytes + 1), ayah: ayah)
            XCTFail("Expected size rejection")
        } catch { XCTAssertEqual(error as? AssessmentError, .recordingTooLarge) }
        serve(Data(repeating: 32, count: RecitationAssessmentClient.maximumResponseBytes + 1))
        do { _ = try await client().assess(audioData: audio, ayah: ayah); XCTFail("Expected size rejection") }
        catch { XCTAssertEqual(error as? AssessmentError, .responseTooLarge) }
        let response = try payload()
        AssessmentURLProtocol.setHandler { _ in (200, response, ["Content-Length": "99999999"]) }
        do { _ = try await client().assess(audioData: audio, ayah: ayah); XCTFail("Expected advertised size rejection") }
        catch { XCTAssertEqual(error as? AssessmentError, .responseTooLarge) }
    }

    func testResponseExactlyAtTheSizeLimitStillValidates() async throws {
        var response = try payload()
        let remaining = RecitationAssessmentClient.maximumResponseBytes - response.count
        XCTAssertGreaterThan(remaining, 0)
        // JSON trailing whitespace is valid. This checks the receive loop's
        // boundary without changing its exact reference text or response schema.
        response.append(Data(repeating: 32, count: remaining))
        serve(response)
        let assessment = try await client().assess(audioData: audio, ayah: ayah)
        XCTAssertEqual(assessment.status, .assessed)
        XCTAssertTrue(assessment.referenceText.utf8.elementsEqual(practiceText.utf8))
    }

    func testServerFailuresDoNotExposeBodiesOrInventAssessment() async throws {
        for (status, expected) in [(401, AssessmentError.serviceUnavailable), (413, .recordingTooLarge), (415, .invalidRecording), (422, .invalidReference), (429, .rateLimited), (503, .serviceUnavailable)] {
            AssessmentURLProtocol.setHandler { _ in (status, Data("private server diagnostics".utf8), [:]) }
            do { _ = try await client().assess(audioData: audio, ayah: ayah); XCTFail("Expected HTTP failure") }
            catch { XCTAssertEqual(error as? AssessmentError, expected); XCTAssertFalse(error.localizedDescription.contains("private")) }
        }
    }

    func testInvalidGlobalReferenceDoesNotUpload() async throws {
        AssessmentURLProtocol.setHandler { _ in XCTFail("Invalid reference must not upload"); return (200, Data(), [:]) }
        let wrong = Ayah(id: 999, surahID: 1, numberInSurah: 2, text: ayah.text)
        do { _ = try await client().assess(audioData: audio, ayah: wrong); XCTFail("Expected invalid reference") }
        catch { XCTAssertEqual(error as? AssessmentError, .invalidReference) }
    }

    func testInsecureAndCredentialBearingURLsRequireRejection() throws {
        for address in ["http://example.test", "http://localhost", "https://user:secret@example.test", "https://example.test?secret=1", "https://example.test#fragment"] {
            XCTAssertThrowsError(try RecitationAssessmentClient(baseURL: URL(string: address)!, session: session))
        }
        XCTAssertNoThrow(try RecitationAssessmentClient(baseURL: URL(string: "http://localhost:8000")!, session: session, allowInsecureLocalhost: true))
        XCTAssertThrowsError(try RecitationAssessmentClient(baseURL: URL(string: "http://example.test")!, session: session, allowInsecureLocalhost: true))
    }

    func testCancelledTaskDoesNotBecomeUserFacingNetworkFailure() async throws {
        AssessmentURLProtocol.setHandler { _ in throw URLError(.cancelled) }
        do { _ = try await client().assess(audioData: audio, ayah: ayah); XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
    }

    func testAlreadyCancelledAnalysisNeverUploadsRecording() async throws {
        AssessmentURLProtocol.setHandler { _ in
            XCTFail("A cancelled analysis must not send voice data")
            return (200, Data(), [:])
        }
        let client = try client()
        let audio = self.audio
        let ayah = self.ayah
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await client.assess(audioData: audio, ayah: ayah)
        }
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testRecordedPythonModelResponsesPassSwiftContractAndPreserveFeedbackText() async throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let evidenceURL = root.appendingPathComponent("docs/evidence/model-smoke-2026-10-24.json")
        let evidence = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: evidenceURL)) as? [String: Any])
        let clips = try XCTUnwrap(evidence["clips"] as? [[String: Any]])
        XCTAssertEqual(clips.count, 5)
        let chapter = try JSONDecoder().decode(QuranChapter.self, from: Data(contentsOf: root.appendingPathComponent("App/Resources/Quran/001.json")))
        let selectedAyah = try XCTUnwrap(chapter.ayahs.first { $0.numberInSurah == 1 })
        // Only the container signature is needed for mocked HTTP. This fixture
        // test does not load audio, repeat model inference or evaluate accuracy.
        let wave = Data(Array("RIFF".utf8) + [0, 0, 0, 0] + Array("WAVE".utf8))
        for clip in clips {
            let object = try XCTUnwrap(clip["assessment"] as? [String: Any])
            let response = try JSONSerialization.data(withJSONObject: object)
            let expected = try JSONDecoder().decode(RecitationAssessment.self, from: response)
            XCTAssertEqual(expected.reference.surahID, selectedAyah.surahID)
            XCTAssertEqual(expected.reference.ayahNumber, selectedAyah.numberInSurah)
            XCTAssertEqual(expected.modelRevision, evidence["model_revision"] as? String)
            AssessmentURLProtocol.setHandler { request in
                XCTAssertTrue(String(decoding: Self.requestBody(request), as: UTF8.self).contains("Content-Type: audio/wav"))
                return (200, response, [:])
            }
            let received = try await client().assess(audioData: wave, format: .wav, ayah: selectedAyah, includeBasmala: expected.includeBasmala)
            XCTAssertEqual(received, expected)
            let spans = FeedbackHighlighter.spans(text: received.referenceText, issues: received.issues)
            XCTAssertTrue(spans.map(\.text).joined().unicodeScalars.elementsEqual(received.referenceText.unicodeScalars))
        }
    }

    func testExtendedRecordedModelResponsesKeepExactReferenceAndIssueContracts() async throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let evidenceURL = root.appendingPathComponent("docs/evidence/model-baseline-2026-10-24.json")
        let evidence = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: evidenceURL)) as? [String: Any])
        let clips = try XCTUnwrap(evidence["clips"] as? [[String: Any]])
        XCTAssertEqual(clips.count, 35)
        let wave = Data(Array("RIFF".utf8) + [0, 0, 0, 0] + Array("WAVE".utf8))
        var chapters: [Int: QuranChapter] = [:]
        for clip in clips {
            let object = try XCTUnwrap(clip["assessment"] as? [String: Any])
            let response = try JSONSerialization.data(withJSONObject: object)
            let previous = try JSONDecoder().decode(RecitationAssessment.self, from: response)
            let surahID = previous.reference.surahID
            if chapters[surahID] == nil {
                let filename = String(format: "%03d.json", surahID)
                chapters[surahID] = try JSONDecoder().decode(QuranChapter.self, from: Data(contentsOf: root.appendingPathComponent("App/Resources/Quran/\(filename)")))
            }
            let ayah = try XCTUnwrap(chapters[surahID]?.ayahs.first { $0.numberInSurah == previous.reference.ayahNumber })
            serve(response)
            // Replay saved responses only. This test neither runs the acoustic
            // model nor classifies its indications as correct or incorrect.
            let received = try await client().assess(audioData: wave, format: .wav, ayah: ayah, includeBasmala: previous.includeBasmala)
            XCTAssertEqual(received, previous)
            XCTAssertTrue(received.referenceText.utf8.elementsEqual(previous.referenceText.utf8))
        }
    }

    private func client() throws -> RecitationAssessmentClient {
        try RecitationAssessmentClient(baseURL: URL(string: "https://analysis.example.test/base")!, session: session)
    }

    private func issue(start: Int, end: Int, category: String = "replace") -> [String: Any] {
        ["kind": "tajweed", "category": category, "start_scalar": start, "end_scalar": end, "expected": "a", "observed": "b", "message": "Modellen hittade en möjlig avvikelse."]
    }

    private func payloadObject() -> [String: Any] {
        ["schema_version": 1, "status": "assessed", "experimental": true, "engine": "quran-muaalem", "engine_version": "0.2.2",
         "model": RecitationAssessmentClient.supportedModel, "model_revision": RecitationAssessmentClient.supportedRevision,
         "reference": ["surah_id": ayah.surahID, "ayah_number": ayah.numberInSurah], "reference_source": PracticeReferenceRepository.source, "reference_text": practiceText,
         "reference_scalar_offset": 0, "include_basmala": false, "issues": [], "message": "Experimentell återkoppling.", "assumptions": ["Hafs"]]
    }

    private func payload() throws -> Data { try JSONSerialization.data(withJSONObject: payloadObject()) }

    private func serve(_ data: Data) { AssessmentURLProtocol.setHandler { _ in (200, data, [:]) } }

    private func assertInvalid(_ object: [String: Any], file: StaticString = #filePath, line: UInt = #line) async throws {
        serve(try JSONSerialization.data(withJSONObject: object))
        do { _ = try await client().assess(audioData: audio, ayah: ayah); XCTFail("Expected invalid response", file: file, line: line) }
        catch { XCTAssertEqual(error as? AssessmentError, .invalidResponse, file: file, line: line) }
    }

    private static func requestBody(_ request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

private final class AssessmentURLProtocol: URLProtocol {
    typealias Handler = (URLRequest) throws -> (Int, Data, [String: String])
    private static let lock = NSLock()
    private static var handler: Handler?

    static func setHandler(_ value: Handler?) {
        lock.lock(); defer { lock.unlock() }
        handler = value
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock()
        let action = Self.handler
        Self.lock.unlock()
        guard let action else { client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse)); return }
        do {
            let (status, data, headers) = try action(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() { }
}
