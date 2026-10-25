import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import QuranCore

/// Sends audio only following an explicit practice action. No retries or audio persistence.
public actor RecitationAssessmentClient {
    public static let maximumRecordingBytes = 8 * 1024 * 1024
    public static let maximumResponseBytes = 1024 * 1024
    public static let supportedModel = "obadx/muaalem-model-v3_2"
    public static let supportedRevision = "01a1ef9fbe40d144ef845101e89ff924aed3fef5"

    private let session: URLSession
    private let endpoint: URL
    private let references: PracticeReferenceRepository
    private let redirectBlocker = RedirectBlocker()

    public init(baseURL: URL, session: URLSession? = nil, allowInsecureLocalhost: Bool = false,
                references: PracticeReferenceRepository = PracticeReferenceRepository()) throws {
        guard let parts = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
              let host = parts.host, !host.isEmpty,
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
              parts.scheme == "https" || (allowInsecureLocalhost && parts.scheme == "http" && ["localhost", "127.0.0.1", "::1"].contains(host)) else {
            throw AssessmentError.invalidServiceURL
        }
        endpoint = baseURL.appendingPathComponent("v1").appendingPathComponent("assess")
        if let session { self.session = session }
        else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil
            configuration.httpCookieStorage = nil
            configuration.httpShouldSetCookies = false
            configuration.timeoutIntervalForRequest = 90
            configuration.timeoutIntervalForResource = 120
            self.session = URLSession(configuration: configuration)
        }
        self.references = references
    }

    public func assess(audioData: Data, format: RecordingFormat = .m4a, ayah: Ayah, includeBasmala: Bool = false) async throws -> RecitationAssessment {
        try Task.checkCancellation()
        guard let reference = ayah.reference,
              ayah.id == AyahReference.ayahCounts.prefix(reference.surahID - 1).reduce(0, +) + reference.ayahNumber,
              !ayah.text.isEmpty else { throw AssessmentError.invalidReference }
        guard audioData.count <= Self.maximumRecordingBytes else { throw AssessmentError.recordingTooLarge }
        guard format.matches(audioData) else { throw AssessmentError.invalidRecording }
        let expectedText = try await references.text(for: reference, includeBasmala: includeBasmala)
        try Task.checkCancellation()

        let boundary = "Sakina-\(UUID().uuidString)"
        var body = Data()
        func append(_ text: String) { body.append(contentsOf: text.utf8) }
        for (name, value) in [("surah_id", String(reference.surahID)), ("ayah_number", String(reference.ayahNumber)), ("include_basmala", includeBasmala ? "true" : "false")] {
            append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
        }
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"audio\"; filename=\"recitation.\(format.rawValue)\"\r\nContent-Type: \(format.mimeType)\r\n\r\n")
        body.append(audioData)
        append("\r\n--\(boundary)--\r\n")
        var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 90)
        request.httpMethod = "POST"
        request.httpShouldHandleCookies = false
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body

        let data: Data
        let response: URLResponse
        do {
            try Task.checkCancellation()
            (data, response) = try await session.data(for: request, delegate: redirectBlocker)
        } catch is CancellationError { throw CancellationError() }
        catch let error as URLError where error.code == .cancelled { throw CancellationError() }
        catch { throw AssessmentError.networkUnavailable }
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw AssessmentError.invalidResponse }
        switch http.statusCode {
        case 200: break
        case 413: throw AssessmentError.recordingTooLarge
        case 415: throw AssessmentError.invalidRecording
        case 422: throw AssessmentError.invalidReference
        case 429: throw AssessmentError.rateLimited
        default: throw AssessmentError.serviceUnavailable
        }
        guard data.count <= Self.maximumResponseBytes,
              http.expectedContentLength <= Int64(Self.maximumResponseBytes) else { throw AssessmentError.responseTooLarge }
        guard let assessment = try? JSONDecoder().decode(RecitationAssessment.self, from: data) else {
            throw AssessmentError.invalidResponse
        }
        try Self.validate(assessment, reference: reference, expectedText: expectedText, includeBasmala: includeBasmala)
        return assessment
    }

    private static func validate(_ result: RecitationAssessment, reference: AyahReference, expectedText: AssessmentText, includeBasmala: Bool) throws {
        guard result.schemaVersion == 1, result.experimental,
              result.engine == "quran-muaalem", result.engineVersion == "0.2.2",
              result.model == supportedModel, result.modelRevision == supportedRevision,
              result.reference.surahID == reference.surahID,
              result.reference.ayahNumber == reference.ayahNumber,
              result.referenceSource == PracticeReferenceRepository.source,
              result.includeBasmala == includeBasmala,
              result.referenceScalarOffset == expectedText.scalarOffset,
              result.referenceText.utf8.elementsEqual(expectedText.text.utf8),
              result.status == .assessed || result.issues.isEmpty else { throw AssessmentError.invalidResponse }

        let count = result.referenceText.unicodeScalars.count
        guard result.issues.allSatisfy({ issue in
            issue.startScalar >= 0 && issue.endScalar <= count && issue.startScalar <= issue.endScalar &&
                (issue.category == .insert || issue.startScalar < issue.endScalar)
        }) else { throw AssessmentError.invalidResponse }
    }
}

/// An audio POST must not be replayed to a redirect destination.
private final class RedirectBlocker: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
