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
    public static let maximumCachedEntries = 64
    public static let maximumCachedBytes = 4 * 1024 * 1024
    public static let maximumCachedEntryBytes = 128 * 1024
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

    /// Keep the original JSON bytes so disk reads use exactly the same source,
    /// edition and reference checks as a fresh response. Never cache a decoded
    /// explanation under a caller-supplied source name or an arbitrary URL.
    private struct CachedResponse: Codable {
        let version: Int
        let source: String
        let response: Data
    }

    private struct CachedFile {
        let url: URL
        let reference: AyahReference
        let size: Int
        let accessedAt: Date
    }

    private static let cacheSource = "https://api.alquran.cloud/ar.muyassar"

    private var entries: [AyahReference: TafsirEntry] = [:]
    private var recentReferences: [AyahReference] = []
    private let session: URLSession
    private let cacheDirectory: URL?
    private var diskCacheReady = false
    private var diskAccessTimes: [AyahReference: Date] = [:]

    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        session = URLSession(configuration: configuration)
        cacheDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Sakina", isDirectory: true)
            .appendingPathComponent("TafsirCache-v1", isDirectory: true)
    }

    /// Injected transports do not touch the user's cache unless a directory is
    /// explicitly supplied. Tests and development clients can disable it with nil.
    public init(session: URLSession, cacheDirectory: URL? = nil) {
        self.session = session
        self.cacheDirectory = cacheDirectory
    }

    public func tafsir(for reference: AyahReference) async throws -> TafsirEntry {
        try Task.checkCancellation()
        prepareDiskCacheIfNeeded()
        if let entry = entries[reference] {
            try Task.checkCancellation()
            touch(reference)
            touchDiskEntry(reference)
            return entry
        }
        if let entry = readDiskEntry(for: reference) {
            try Task.checkCancellation()
            remember(entry, for: reference)
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
              response.expectedContentLength <= Int64(Self.maximumResponseBytes),
              Self.isJSONResponse(response) else {
            throw TafsirError.unexpectedContent
        }
        let entry = try Self.decodeEntry(from: data, for: reference)
        try Task.checkCancellation()
        writeDiskEntry(data, for: reference)
        remember(entry, for: reference)
        return entry
    }

    private static func decodeEntry(from data: Data, for reference: AyahReference) throws -> TafsirEntry {
        guard data.count <= Self.maximumResponseBytes else { throw TafsirError.unexpectedContent }
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
        return TafsirEntry(text: result.data.text, sourceName: "al-Muyassar", language: "ar")
    }

    private func remember(_ entry: TafsirEntry, for reference: AyahReference) {
        entries[reference] = entry
        touch(reference)
        while recentReferences.count > Self.maximumCachedEntries {
            let evicted = recentReferences.removeFirst()
            entries.removeValue(forKey: evicted)
            diskAccessTimes.removeValue(forKey: evicted)
        }
    }

    private func receiveResponse(for request: URLRequest) async throws -> (Data, URLResponse) {
        #if canImport(Darwin)
        let (bytes, response) = try await session.bytes(for: request)
        let dataTask = bytes.task
        defer { dataTask.cancel() }
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return (Data(), response) }
            guard response.expectedContentLength <= Int64(Self.maximumResponseBytes),
                  Self.isJSONResponse(response) else {
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

    private static func isJSONResponse(_ response: URLResponse) -> Bool {
        guard let mime = response.mimeType?.lowercased() else { return false }
        return mime == "application/json" || (mime.hasPrefix("application/") && mime.hasSuffix("+json"))
    }

    private func cacheURL(for reference: AyahReference) -> URL? {
        cacheDirectory?.appendingPathComponent(String(format: "%03d-%03d.json", reference.surahID, reference.ayahNumber))
    }

    /// All filesystem work is isolated to this actor, away from SwiftUI's main
    /// actor. Cache failures are never a reason to suppress a valid online text.
    private func prepareDiskCacheIfNeeded() {
        guard var directory = cacheDirectory else { return }
        // The cache may disappear during a long app session. A replacement
        // symlink must never inherit the trust of the original directory.
        if diskCacheReady {
            if cacheDirectoryIsSafe() { return }
            diskCacheReady = false
            diskAccessTimes.removeAll()
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            guard cacheDirectoryIsSafe() else { return }
            #if canImport(Darwin)
            var backupValues = URLResourceValues()
            backupValues.isExcludedFromBackup = true
            try directory.setResourceValues(backupValues)
            #endif
            #if os(iOS)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                                                 ofItemAtPath: directory.path)
            #endif
            diskCacheReady = true
            pruneDiskCache()
        } catch {
            diskCacheReady = false
        }
    }

    /// Inspect the current path rather than trusting a prior setup or URL
    /// metadata. FileManager reports the link itself, without following it.
    private func cacheDirectoryIsSafe() -> Bool {
        guard let directory = cacheDirectory,
              let attributes = try? FileManager.default.attributesOfItem(atPath: directory.path),
              attributes[.type] as? FileAttributeType == .typeDirectory else { return false }
        return true
    }

    private func readDiskEntry(for reference: AyahReference) -> TafsirEntry? {
        guard diskCacheReady, cacheDirectoryIsSafe(), let url = cacheURL(for: reference),
              let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              values.isRegularFile == true, values.isSymbolicLink != true else { return nil }
        do {
            guard let size = values.fileSize, size > 0, size <= Self.maximumCachedEntryBytes else {
                throw TafsirError.unexpectedContent
            }
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            // Bound the actual read as well as the size hint in case the file
            // changes between metadata lookup and opening it.
            let data = try handle.read(upToCount: Self.maximumCachedEntryBytes + 1) ?? Data()
            guard data.count <= Self.maximumCachedEntryBytes,
                  let stored = try? JSONDecoder().decode(CachedResponse.self, from: data),
                  stored.version == 1, stored.source == Self.cacheSource else {
                throw TafsirError.unexpectedContent
            }
            let entry = try Self.decodeEntry(from: stored.response, for: reference)
            touchDiskEntry(reference)
            return entry
        } catch {
            // A damaged cache is recoverable. Only this reference's own cache
            // filename is removed; unrelated files are never opened or deleted.
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }

    private func writeDiskEntry(_ response: Data, for reference: AyahReference) {
        // A network request suspends this actor; storage may have changed while
        // it was in flight, even if setup succeeded when the request began.
        prepareDiskCacheIfNeeded()
        guard diskCacheReady, cacheDirectoryIsSafe(), let url = cacheURL(for: reference),
              let encoded = try? JSONEncoder().encode(CachedResponse(version: 1, source: Self.cacheSource, response: response)),
              encoded.count <= Self.maximumCachedEntryBytes else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
                  values.isRegularFile == true, values.isSymbolicLink != true else { return }
        }
        do {
            try encoded.write(to: url, options: .atomic)
            #if os(iOS)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                                                 ofItemAtPath: url.path)
            #endif
            diskAccessTimes[reference] = Date()
            pruneDiskCache()
        } catch {
            // Reading remains available when storage is full or protected.
        }
    }

    private func touchDiskEntry(_ reference: AyahReference) {
        guard diskCacheReady, cacheDirectoryIsSafe(), let url = cacheURL(for: reference) else { return }
        let date = Date()
        // Repeated openings from RAM need no repeated filesystem writes. Keep
        // recency reasonably fresh during long sessions, at most once a minute.
        if let previous = diskAccessTimes[reference], date.timeIntervalSince(previous) < 60 { return }
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
              values.isRegularFile == true, values.isSymbolicLink != true else { return }
        do {
            try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
            diskAccessTimes[reference] = date
        } catch { }
    }

    private func pruneDiskCache() {
        guard diskCacheReady, cacheDirectoryIsSafe(), let directory = cacheDirectory,
              let urls = try? FileManager.default.contentsOfDirectory(at: directory,
                  includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey],
                  options: [.skipsHiddenFiles]) else { return }
        var files: [CachedFile] = []
        for url in urls {
            guard let reference = Self.cachedReference(from: url.lastPathComponent),
                  let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]),
                  values.isRegularFile == true, values.isSymbolicLink != true,
                  let size = values.fileSize else { continue }
            guard size > 0, size <= Self.maximumCachedEntryBytes else {
                try? FileManager.default.removeItem(at: url)
                continue
            }
            files.append(CachedFile(url: url, reference: reference, size: size,
                                    accessedAt: values.contentModificationDate ?? .distantPast))
        }
        files.sort {
            if $0.accessedAt != $1.accessedAt { return $0.accessedAt > $1.accessedAt }
            return $0.url.lastPathComponent < $1.url.lastPathComponent
        }
        var keptCount = 0
        var keptBytes = 0
        for file in files {
            if keptCount < Self.maximumCachedEntries && keptBytes + file.size <= Self.maximumCachedBytes {
                keptCount += 1
                keptBytes += file.size
            } else {
                try? FileManager.default.removeItem(at: file.url)
                diskAccessTimes.removeValue(forKey: file.reference)
            }
        }
    }

    private static func cachedReference(from filename: String) -> AyahReference? {
        let bytes = Array(filename.utf8)
        guard bytes.count == 12, bytes[3] == 45,
              Array(bytes[7...]) == Array(".json".utf8),
              bytes[0..<3].allSatisfy({ (48...57).contains($0) }),
              bytes[4..<7].allSatisfy({ (48...57).contains($0) }),
              let surah = Int(String(decoding: bytes[0..<3], as: UTF8.self)),
              let ayah = Int(String(decoding: bytes[4..<7], as: UTF8.self)) else { return nil }
        return AyahReference(surahID: surah, ayahNumber: ayah)
    }
}
