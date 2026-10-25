import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import QuranCore

public struct TafsirEntry: Hashable, Sendable {
    public let text: String
    public let sourceName: String
    /// ISO language identifier; this source is Arabic, not a Swedish tafsir.
    public let language: String
}

public actor TafsirRepository {
    public static let maximumResponseBytes = 1024 * 1024
    public enum TafsirError: LocalizedError, Equatable {
        case unavailable
        case unexpectedContent

        public var errorDescription: String? {
            switch self {
            case .unavailable:
                return "Tafsiren kunde inte hämtas. Kontrollera din internetanslutning och försök igen."
            case .unexpectedContent:
                return "Källan svarade med en annan text än den valda versens tafsir. Försök igen senare."
            }
        }
    }

    private struct Envelope: Decodable {
        let code: Int
        let data: Payload
    }

    private struct Payload: Decodable {
        struct SurahNumber: Decodable { let number: Int }
        struct Edition: Decodable {
            let identifier: String
            let language: String
            let format: String
            let type: String
        }
        let number: Int
        let numberInSurah: Int
        let surah: SurahNumber
        let text: String
        let edition: Edition
    }

    private var entries: [AyahReference: TafsirEntry] = [:]
    private var recentReferences: [AyahReference] = []
    private let cacheLimit = 64
    private let session: URLSession

    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        session = URLSession(configuration: configuration)
    }

    public init(session: URLSession) {
        self.session = session
    }

    public func tafsir(for reference: AyahReference) async throws -> TafsirEntry {
        try Task.checkCancellation()
        if let entry = entries[reference] {
            touch(reference)
            return entry
        }
        let address = "https://api.alquran.cloud/v1/ayah/\(reference.surahID):\(reference.ayahNumber)/ar.muyassar"
        guard let url = URL(string: address) else { throw TafsirError.unavailable }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await receiveResponse(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as TafsirError {
            throw error
        } catch {
            throw TafsirError.unavailable
        }
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw TafsirError.unavailable
        }
        guard data.count <= Self.maximumResponseBytes,
              response.expectedContentLength <= Int64(Self.maximumResponseBytes) else {
            throw TafsirError.unexpectedContent
        }
        guard let result = try? JSONDecoder().decode(Envelope.self, from: data),
              result.code == 200,
              result.data.surah.number == reference.surahID,
              result.data.numberInSurah == reference.ayahNumber,
              result.data.number == AyahReference.ayahCounts.prefix(reference.surahID - 1).reduce(0, +) + reference.ayahNumber,
              result.data.edition.identifier == "ar.muyassar",
              result.data.edition.language == "ar",
              result.data.edition.format == "text",
              result.data.edition.type == "tafsir",
              !result.data.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TafsirError.unexpectedContent
        }
        // This edition is delivered as plain Arabic text. Keep the source intact;
        // do not paraphrase it or invent an explanation if the request fails.
        let entry = TafsirEntry(text: result.data.text, sourceName: "al-Muyassar", language: "ar")
        entries[reference] = entry
        touch(reference)
        while recentReferences.count > cacheLimit {
            entries.removeValue(forKey: recentReferences.removeFirst())
        }
        return entry
    }

    private func receiveResponse(for request: URLRequest) async throws -> (Data, URLResponse) {
        #if canImport(Darwin)
        let (bytes, response) = try await session.bytes(for: request)
        let dataTask = bytes.task
        defer { dataTask.cancel() }
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return (Data(), response) }
            guard response.expectedContentLength <= Int64(Self.maximumResponseBytes) else {
                throw TafsirError.unexpectedContent
            }
            var data = Data()
            data.reserveCapacity(Int(max(0, min(response.expectedContentLength, Int64(Self.maximumResponseBytes)))))
            for try await byte in bytes {
                if data.count.isMultiple(of: 4096) { try Task.checkCancellation() }
                guard data.count < Self.maximumResponseBytes else { throw TafsirError.unexpectedContent }
                data.append(byte)
            }
            try Task.checkCancellation()
            return (data, response)
        } onCancel: {
            dataTask.cancel()
        }
        #else
        return try await session.data(for: request)
        #endif
    }

    private func touch(_ reference: AyahReference) {
        recentReferences.removeAll { $0 == reference }
        recentReferences.append(reference)
    }
}
