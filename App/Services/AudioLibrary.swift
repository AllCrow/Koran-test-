import Combine
import Foundation
import QuranCore

/// Explicit, foreground downloads for personal offline listening. Nothing preloads.
@MainActor
final class AudioLibrary: ObservableObject {
    static let shared = AudioLibrary()

    @Published private(set) var completed = 0
    @Published private(set) var total = 0
    @Published private(set) var downloadingSurahID: Int?
    @Published private(set) var downloadingReciter: Reciter?
    @Published private(set) var errorMessage: String?

    var progress: Double { total > 0 ? Double(completed) / Double(total) : 0 }

    private let directory: URL?
    private let session: URLSession
    private let fileManager = FileManager.default
    private let maximumVerseBytes: Int64 = 32 * 1_024 * 1_024
    private var downloadTask: Task<Void, Never>?
    private var downloadID: UUID?
    private var validatedFiles: [URL: FileIdentity] = [:]

    init(directory: URL? = nil) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpMaximumConnectionsPerHost = 1
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 180
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration)

        do {
            var root: URL
            if let directory {
                root = directory
            } else {
                root = try FileManager.default.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                ).appendingPathComponent("Recitations", isDirectory: true)
            }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try root.setResourceValues(values)
            self.directory = root
        } catch {
            self.directory = nil
            errorMessage = "Det gick inte att skapa en sparplats för ljudet på telefonen."
        }
    }

    deinit {
        downloadTask?.cancel()
        session.invalidateAndCancel()
    }

    /// Returns only a file with a valid MP3 header, with its size and date unchanged.
    func localURL(for reference: AyahReference, reciter: Reciter) -> URL? {
        guard let url = fileURL(for: reference, reciter: reciter),
              let identity = try? fileIdentity(at: url),
              identity.bytes >= 128, identity.bytes <= maximumVerseBytes else { return nil }
        if validatedFiles[url] == identity { return url }
        guard (try? validateMP3(at: url, identity: identity)) != nil else {
            validatedFiles.removeValue(forKey: url)
            return nil
        }
        validatedFiles[url] = identity
        return url
    }

    func downloadedVerseCount(surahID: Int, reciter: Reciter) -> Int {
        guard (1...AyahReference.ayahCounts.count).contains(surahID),
              let folder = chapterDirectory(surahID: surahID, reciter: reciter),
              let files = try? fileManager.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
              ) else { return 0 }
        return files.reduce(into: 0) { count, file in
            guard file.pathExtension == "mp3" else { return }
            let stem = file.deletingPathExtension().lastPathComponent
            guard stem.count == 6, Int(stem.prefix(3)) == surahID,
                  let verse = Int(stem.suffix(3)),
                  let reference = AyahReference(surahID: surahID, ayahNumber: verse),
                  file.lastPathComponent == filename(for: reference),
                  localURL(for: reference, reciter: reciter) != nil else { return }
            count += 1
        }
    }

    /// Reserve the foreground job synchronously with the button action. A
    /// subsequent cancellation or selection change cannot leave an old request
    /// queued to start later. Completed verses survive cancellation and resume.
    func beginDownload(_ surah: Surah, reciter: Reciter) {
        guard downloadTask == nil else { return }
        guard directory != nil else {
            errorMessage = "Ljudets sparplats är inte tillgänglig. Försök starta om appen."
            return
        }
        guard (1...AyahReference.ayahCounts.count).contains(surah.id),
              surah.numberOfAyahs == AyahReference.ayahCounts[surah.id - 1] else {
            errorMessage = "Surans versuppgifter kunde inte verifieras."
            return
        }

        let id = UUID()
        downloadID = id
        downloadingSurahID = surah.id
        downloadingReciter = reciter
        completed = downloadedVerseCount(surahID: surah.id, reciter: reciter)
        total = surah.numberOfAyahs
        errorMessage = nil

        downloadTask = Task<Void, Never> { @MainActor [weak self] in
            guard let self else { return }
            await self.performDownload(surah, reciter: reciter, id: id)
        }
    }

    func cancelDownload() {
        downloadTask?.cancel()
    }

    /// The caller stops playback before deleting its files.
    func deleteSurah(_ surah: Surah, reciter: Reciter) {
        if downloadingSurahID == surah.id && downloadingReciter == reciter {
            cancelDownload()
            downloadID = nil
            downloadTask = nil
            downloadingSurahID = nil
            downloadingReciter = nil
            completed = 0
            total = 0
        }
        guard let folder = chapterDirectory(surahID: surah.id, reciter: reciter) else { return }
        do {
            if fileManager.fileExists(atPath: folder.path) {
                try fileManager.removeItem(at: folder)
            }
            validatedFiles = validatedFiles.filter { $0.key.deletingLastPathComponent() != folder }
            errorMessage = nil
            objectWillChange.send()
        } catch {
            errorMessage = "Det gick inte att ta bort det sparade ljudet. Försök igen."
        }
    }

    private func performDownload(_ surah: Surah, reciter: Reciter, id: UUID) async {
        defer {
            if downloadID == id {
                completed = downloadedVerseCount(surahID: surah.id, reciter: reciter)
                downloadID = nil
                downloadTask = nil
                downloadingSurahID = nil
                downloadingReciter = nil
            }
        }
        do {
            for number in 1...surah.numberOfAyahs {
                try Task.checkCancellation()
                guard downloadID == id else { throw CancellationError() }
                guard let reference = AyahReference(surahID: surah.id, ayahNumber: number) else {
                    throw AudioDownloadError.invalidReference
                }
                if localURL(for: reference, reciter: reciter) != nil { continue }
                try await downloadVerse(reference, reciter: reciter)
                try Task.checkCancellation()
                guard downloadID == id else { throw CancellationError() }
                completed += 1
            }
        } catch {
            if !Task.isCancelled && downloadID == id {
                errorMessage = message(for: error)
            }
        }
    }

    private func downloadVerse(_ reference: AyahReference, reciter: Reciter) async throws {
        var request = URLRequest(url: reciter.audioURL(for: reference))
        request.setValue("audio/mpeg, application/octet-stream;q=0.5", forHTTPHeaderField: "Accept")
        let limit = AudioDownloadLimit(maximumBytes: maximumVerseBytes)
        let result: (URL, URLResponse)
        do {
            result = try await session.download(for: request, delegate: limit)
        } catch {
            if limit.exceeded { throw AudioDownloadError.tooLarge }
            throw error
        }
        let (temporary, response) = result
        defer { try? fileManager.removeItem(at: temporary) }
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse,
              http.statusCode == 200, http.url?.scheme == "https" else {
            throw AudioDownloadError.invalidResponse
        }
        let allowedMIMETypes = ["audio/mpeg", "audio/mp3", "audio/x-mp3", "application/octet-stream", "application/binary"]
        guard let mime = http.mimeType?.lowercased(), allowedMIMETypes.contains(mime) else {
            throw AudioDownloadError.invalidAudio
        }
        let identity = try fileIdentity(at: temporary)
        guard identity.bytes <= maximumVerseBytes, !limit.exceeded else { throw AudioDownloadError.tooLarge }
        if http.expectedContentLength >= 0 && http.expectedContentLength != identity.bytes {
            throw AudioDownloadError.invalidAudio
        }
        try validateMP3(at: temporary, identity: identity)
        guard let destination = fileURL(for: reference, reciter: reciter) else {
            throw AudioDownloadError.storageUnavailable
        }
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Task.checkCancellation()

        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporary, backupItemName: nil, options: .usingNewMetadataOnly)
        } else {
            try fileManager.moveItem(at: temporary, to: destination)
        }
        // Downloaded audio stays available for playback while the phone is locked.
        try fileManager.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: destination.path)
        validatedFiles[destination] = try fileIdentity(at: destination)
    }

    private func chapterDirectory(surahID: Int, reciter: Reciter) -> URL? {
        directory?
            .appendingPathComponent(reciter.rawValue, isDirectory: true)
            .appendingPathComponent(String(format: "%03d", surahID), isDirectory: true)
    }

    private func fileURL(for reference: AyahReference, reciter: Reciter) -> URL? {
        chapterDirectory(surahID: reference.surahID, reciter: reciter)?
            .appendingPathComponent(filename(for: reference), isDirectory: false)
    }

    private func filename(for reference: AyahReference) -> String {
        String(format: "%03d%03d.mp3", reference.surahID, reference.ayahNumber)
    }

    private struct FileIdentity: Equatable {
        let bytes: Int64
        let modified: Date
    }

    private func fileIdentity(at url: URL) throws -> FileIdentity {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let bytes = attributes[.size] as? NSNumber,
              let modified = attributes[.modificationDate] as? Date else {
            throw AudioDownloadError.invalidAudio
        }
        return FileIdentity(bytes: bytes.int64Value, modified: modified)
    }

    /// Check two consecutive MPEG Layer III frames, allowing an ID3v2 tag first.
    /// This rejects error pages and partial headers without loading a whole verse.
    private func validateMP3(at url: URL, identity: FileIdentity) throws {
        guard (128...maximumVerseBytes).contains(identity.bytes) else { throw AudioDownloadError.invalidAudio }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let header = [UInt8](try handle.read(upToCount: 10) ?? Data())
        guard header.count == 10 else { throw AudioDownloadError.invalidAudio }
        var offset = 0
        if Array(header.prefix(3)) == [0x49, 0x44, 0x33] {
            guard (2...4).contains(header[3]), header[6...9].allSatisfy({ $0 < 128 }) else {
                throw AudioDownloadError.invalidAudio
            }
            let tagSize = header[6...9].reduce(0) { ($0 << 7) | Int($1) }
            let footerSize = header[3] == 4 && header[5] & 0x10 != 0 ? 10 : 0
            offset = 10 + tagSize + footerSize
        }
        guard Int64(offset + 8) <= identity.bytes else { throw AudioDownloadError.invalidAudio }
        try handle.seek(toOffset: UInt64(offset))
        let bytes = [UInt8](try handle.read(upToCount: 8_192) ?? Data())
        guard bytes.count >= 8 else { throw AudioDownloadError.invalidAudio }
        for start in 0..<min(4_096, bytes.count - 7) {
            guard let length = frameLength(bytes, at: start),
                  start + length + 4 <= bytes.count,
                  let nextLength = frameLength(bytes, at: start + length),
                  Int64(offset + start + length + nextLength) <= identity.bytes,
                  bytes[start + 1] & 0x1E == bytes[start + length + 1] & 0x1E,
                  bytes[start + 2] & 0x0C == bytes[start + length + 2] & 0x0C else { continue }
            return
        }
        throw AudioDownloadError.invalidAudio
    }

    private func frameLength(_ bytes: [UInt8], at start: Int) -> Int? {
        guard start >= 0, start + 4 <= bytes.count,
              bytes[start] == 0xFF, bytes[start + 1] & 0xE0 == 0xE0 else { return nil }
        let version = (bytes[start + 1] >> 3) & 3
        let layer = (bytes[start + 1] >> 1) & 3
        let bitrateIndex = Int(bytes[start + 2] >> 4)
        let sampleIndex = Int((bytes[start + 2] >> 2) & 3)
        guard version != 1, layer == 1, (1...14).contains(bitrateIndex), sampleIndex < 3,
              bytes[start + 3] & 3 != 2 else { return nil }
        let rates = version == 3
            ? [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320]
            : [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160]
        let divisor = version == 3 ? 1 : (version == 2 ? 2 : 4)
        let sampleRate = [44_100, 48_000, 32_000][sampleIndex] / divisor
        let padding = Int((bytes[start + 2] >> 1) & 1)
        return (version == 3 ? 144_000 : 72_000) * rates[bitrateIndex] / sampleRate + padding
    }

    private enum AudioDownloadError: Error {
        case invalidReference, invalidResponse, invalidAudio, tooLarge, storageUnavailable
    }

    private func message(for error: Error) -> String {
        if let downloadError = error as? AudioDownloadError {
            switch downloadError {
            case .tooLarge: return "En ljudfil var för stor för att sparas. Redan hämtade verser finns kvar."
            case .invalidResponse, .invalidAudio: return "Ljudkällan skickade ingen giltig MP3-fil. Redan hämtade verser finns kvar."
            case .invalidReference: return "Versen kunde inte verifieras."
            case .storageUnavailable: return "Ljudets sparplats är inte tillgänglig."
            }
        }
        if (error as? CocoaError)?.code == .fileWriteOutOfSpace {
            return "Telefonens lagringsutrymme räcker inte. Redan hämtade verser finns kvar."
        }
        return "Nedladdningen avbröts. Kontrollera anslutningen och försök igen. Redan hämtade verser finns kvar."
    }
}

/// Enforces a disk/network bound from download callbacks, without polling.
private final class AudioDownloadLimit: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let maximumBytes: Int64
    private let lock = NSLock()
    private var didExceed = false

    var exceeded: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didExceed
    }

    init(maximumBytes: Int64) { self.maximumBytes = maximumBytes }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesWritten > maximumBytes || totalBytesExpectedToWrite > maximumBytes else { return }
        lock.lock()
        didExceed = true
        lock.unlock()
        downloadTask.cancel()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
}
