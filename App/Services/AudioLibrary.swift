import Combine
import Foundation
import QuranCore

/// Explicit, foreground downloads for personal offline listening. Nothing preloads.
@MainActor
final class AudioLibrary: ObservableObject {
    /// A narrow transport seam keeps disk admission and cancellation testable
    /// without reaching the recitation service. Production owns one URLSession.
    typealias Download = @MainActor @Sendable (URLRequest, any URLSessionTaskDelegate) async throws -> (URL, URLResponse)
    typealias InventoryScan = @Sendable (URL) async throws -> [AudioDownloadEntry]

    static let shared = AudioLibrary()

    @Published private(set) var completed = 0
    @Published private(set) var total = 0
    @Published private(set) var downloadingSurahID: Int?
    @Published private(set) var downloadingReciter: Reciter?
    @Published private(set) var errorMessage: String?
    @Published private(set) var entries: [AudioDownloadEntry] = []
    @Published private(set) var isScanning = false
    @Published private(set) var inventoryError: String?
    @Published private(set) var hasCurrentInventory = false

    @Published private(set) var inventoryBytes: Int64 = 0

    var progress: Double { total > 0 ? Double(completed) / Double(total) : 0 }

    private let configuredDirectory: URL?
    private var directory: URL?
    private let downloader: AudioFileDownloader
    private let downloadFile: Download
    private let fileManager = FileManager.default
    private let maximumVerseBytes = AudioStoredFile.maximumBytes
    private let inventoryScan: InventoryScan
    private var inventoryTask: Task<[AudioDownloadEntry], Error>?
    private var inventoryRequestID: UUID?
    private var inventoryMutationID = UUID()
    private var allowsCellularAccess = true
    private var downloadTask: Task<Void, Never>?
    private var downloadID: UUID?
    private var validatedFiles: [URL: FileIdentity] = [:]

    init(directory: URL? = nil, download: Download? = nil, inventoryScan: InventoryScan? = nil) {
        configuredDirectory = directory
        self.inventoryScan = inventoryScan ?? { root in try AudioStorageInventory.scan(at: root) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpMaximumConnectionsPerHost = 1
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 180
        configuration.waitsForConnectivity = false
        let networkDownloader = AudioFileDownloader(configuration: configuration)
        downloader = networkDownloader
        downloadFile = download ?? { request, delegate in
            try await networkDownloader.download(for: request, delegate: delegate)
        }

        do {
            self.directory = try Self.prepareStorage(at: directory)
        } catch {
            self.directory = nil
            errorMessage = "Det gick inte att skapa en sparplats för ljudet på telefonen."
        }
    }

    deinit {
        inventoryTask?.cancel()
        downloadTask?.cancel()
        downloader.invalidateAndCancel()
    }

    /// Returns only a file with a valid MP3 header, with its size and date unchanged.
    func localURL(for reference: AyahReference, reciter: Reciter) -> URL? {
        guard safeChapterDirectory(surahID: reference.surahID, reciter: reciter) != nil,
              let url = fileURL(for: reference, reciter: reciter) else { return nil }
        guard let identity = try? fileIdentity(at: url),
              identity.bytes >= 128, identity.bytes <= maximumVerseBytes else {
            validatedFiles.removeValue(forKey: url)
            return nil
        }
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
              let folder = safeChapterDirectory(surahID: surahID, reciter: reciter),
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

    /// A damaged selection must still offer a way to remove its occupied files.
    func hasStoredAudio(surahID: Int, reciter: Reciter) -> Bool {
        guard (1...AyahReference.ayahCounts.count).contains(surahID),
              let folder = safeChapterDirectory(surahID: surahID, reciter: reciter),
              let files = fileManager.enumerator(at: folder, includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants, .skipsPackageDescendants]) else { return false }
        var examined = 0
        while let url = files.nextObject() as? URL {
            examined += 1
            guard examined <= AyahReference.ayahCounts[surahID - 1] + 64 else { return false }
            if AudioStorageInventory.canonicalVerse(in: url.lastPathComponent, surahID: surahID) != nil,
               (try? fileIdentity(at: url)) != nil { return true }
        }
        return false
    }

    /// Explicitly refresh the library. The detached worker owns only immutable
    /// paths and sends a bounded snapshot back; it never performs network work.
    func refreshInventory() async {
        guard !Task.isCancelled else { return }
        inventoryTask?.cancel()
        let requestID = UUID()
        let mutationID = inventoryMutationID
        inventoryRequestID = requestID
        isScanning = true
        hasCurrentInventory = false
        inventoryError = nil
        defer {
            if inventoryRequestID == requestID {
                inventoryRequestID = nil
                inventoryTask = nil
                isScanning = false
            }
        }
        guard let root = directory else {
            inventoryError = "Ljudets sparplats är inte tillgänglig. Försök igen när lagringsutrymmet är tillgängligt."
            return
        }
        let scan = inventoryScan
        let task = Task.detached(priority: .utility) { try await scan(root) }
        inventoryTask = task
        do {
            let snapshot = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
            try Task.checkCancellation()
            guard inventoryRequestID == requestID, inventoryMutationID == mutationID else { return }
            let bytes = try Self.checkedInventoryBytes(snapshot)
            entries = snapshot
            inventoryBytes = bytes
            hasCurrentInventory = true
        } catch is CancellationError {
            // Cancellation or a newer filesystem mutation must not publish an
            // earlier snapshot, error, or completion over the current request.
        } catch {
            guard !Task.isCancelled, inventoryRequestID == requestID,
                  inventoryMutationID == mutationID else { return }
            inventoryError = "Det sparade ljudet kunde inte läsas just nu. Försök uppdatera listan."
        }
    }

    func cancelInventoryScan() {
        hasCurrentInventory = false
        inventoryRequestID = nil
        inventoryTask?.cancel()
        inventoryTask = nil
        if isScanning { isScanning = false }
    }

    /// Changing the choice is an explicit boundary: the current request stops,
    /// while every already committed verse remains available locally.
    func setAllowsCellularAccess(_ allowed: Bool) {
        guard allowsCellularAccess != allowed else { return }
        allowsCellularAccess = allowed
        cancelDownload()
    }

    private static func checkedInventoryBytes(_ snapshot: [AudioDownloadEntry]) throws -> Int64 {
        guard snapshot.count <= Reciter.allCases.count * AyahReference.ayahCounts.count else {
            throw AudioStorageInventory.ScanError.unavailable
        }
        var total: Int64 = 0
        for entry in snapshot {
            guard entry.bytes >= 0 else { throw AudioStorageInventory.ScanError.unavailable }
            let (next, overflow) = total.addingReportingOverflow(entry.bytes)
            guard !overflow else { throw AudioStorageInventory.ScanError.unavailable }
            total = next
        }
        return total
    }

    private func invalidateInventory() {
        inventoryMutationID = UUID()
        cancelInventoryScan()
    }

    /// Reserve the foreground job synchronously with the button action. A
    /// subsequent cancellation or selection change cannot leave an old request
    /// queued to start later. Completed verses survive cancellation and resume.
    func beginDownload(_ surah: Surah, reciter: Reciter) {
        guard downloadTask == nil else { return }
        do {
            // An explicit retry can also recover a root removed since setup.
            // Reapply backup exclusion before any newly created audio is saved.
            directory = try Self.prepareStorage(at: directory ?? configuredDirectory)
        } catch {
            errorMessage = "Ljudets sparplats är inte tillgänglig. Kontrollera lagringsutrymmet och försök igen."
            return
        }
        guard (1...AyahReference.ayahCounts.count).contains(surah.id),
              surah.numberOfAyahs == AyahReference.ayahCounts[surah.id - 1] else {
            errorMessage = "Surans versuppgifter kunde inte verifieras."
            return
        }

        invalidateInventory()
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
        invalidateInventory()
        do {
            let folder = try deletionFolder(surahID: surah.id, reciter: reciter)
            if let folder, fileManager.fileExists(atPath: folder.path) {
                try fileManager.removeItem(at: folder)
            }
            if let folder {
                validatedFiles = validatedFiles.filter { $0.key.deletingLastPathComponent() != folder }
            }
            let kept = entries.filter { $0.surahID != surah.id || $0.reciter != reciter }
            let keptBytes = try Self.checkedInventoryBytes(kept)
            entries = kept
            inventoryBytes = keptBytes
            inventoryError = nil
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
        request.httpMethod = "GET"
        request.httpShouldHandleCookies = false
        request.allowsCellularAccess = allowsCellularAccess
        request.setValue("audio/mpeg, application/octet-stream;q=0.5", forHTTPHeaderField: "Accept")
        let limit = AudioDownloadLimit(maximumBytes: maximumVerseBytes)
        let result: (URL, URLResponse)
        do {
            result = try await downloadFile(request, limit)
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
        try prepareChapterDirectory(surahID: reference.surahID, reciter: reciter)
        try Task.checkCancellation()

        // Prepare all required metadata before publishing the final filename.
        // A protection/attribute failure must not report an unsaved verse while
        // leaving that newly admitted verse installed behind the error.
        try fileManager.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: temporary.path)
        let installedIdentity = try fileIdentity(at: temporary)
        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporary, backupItemName: nil, options: .usingNewMetadataOnly)
        } else {
            try fileManager.moveItem(at: temporary, to: destination)
        }
        // The rename retains the prepared protection and file identity, so no
        // fallible operation remains after the verse is committed to storage.
        validatedFiles[destination] = installedIdentity
        invalidateInventory()
    }

    private static func prepareStorage(at requestedDirectory: URL?) throws -> URL {
        var root: URL
        if let requestedDirectory {
            root = requestedDirectory
        } else {
            root = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("Recitations", isDirectory: true)
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        guard AudioStoredFile.isDirectory(root) else { throw AudioDownloadError.storageUnavailable }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try root.setResourceValues(values)
        return root
    }

    private func chapterDirectory(surahID: Int, reciter: Reciter) -> URL? {
        directory?
            .appendingPathComponent(reciter.rawValue, isDirectory: true)
            .appendingPathComponent(String(format: "%03d", surahID), isDirectory: true)
    }

    /// Recheck parent components immediately before a destructive operation.
    /// A replaced root or reciter link must never route deletion elsewhere.
    private func deletionFolder(surahID: Int, reciter: Reciter) throws -> URL? {
        guard let root = directory else { throw AudioDownloadError.storageUnavailable }
        for url in [root, root.appendingPathComponent(reciter.rawValue, isDirectory: true)] {
            do {
                let attributes = try fileManager.attributesOfItem(atPath: url.path)
                guard attributes[.type] as? FileAttributeType == .typeDirectory else {
                    throw AudioDownloadError.storageUnavailable
                }
            } catch let error as CocoaError where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile {
                return nil // Already absent: there are no files to delete.
            }
        }
        return chapterDirectory(surahID: surahID, reciter: reciter)
    }

    private func safeChapterDirectory(surahID: Int, reciter: Reciter) -> URL? {
        guard let root = directory, AudioStoredFile.isDirectory(root) else { return nil }
        let reciterFolder = root.appendingPathComponent(reciter.rawValue, isDirectory: true)
        guard AudioStoredFile.isDirectory(reciterFolder),
              let folder = chapterDirectory(surahID: surahID, reciter: reciter),
              AudioStoredFile.isDirectory(folder) else { return nil }
        return folder
    }

    private func prepareChapterDirectory(surahID: Int, reciter: Reciter) throws {
        guard let root = directory, AudioStoredFile.isDirectory(root) else {
            throw AudioDownloadError.storageUnavailable
        }
        var folder = root
        for component in [reciter.rawValue, String(format: "%03d", surahID)] {
            folder.appendPathComponent(component, isDirectory: true)
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            guard AudioStoredFile.isDirectory(folder) else { throw AudioDownloadError.storageUnavailable }
        }
    }

    private func fileURL(for reference: AyahReference, reciter: Reciter) -> URL? {
        chapterDirectory(surahID: reference.surahID, reciter: reciter)?
            .appendingPathComponent(filename(for: reference), isDirectory: false)
    }

    private func filename(for reference: AyahReference) -> String {
        String(format: "%03d%03d.mp3", reference.surahID, reference.ayahNumber)
    }

    private typealias FileIdentity = AudioStoredFile.Identity

    private func fileIdentity(at url: URL) throws -> FileIdentity {
        do { return try AudioStoredFile.identity(at: url) }
        catch { throw AudioDownloadError.invalidAudio }
    }

    private func validateMP3(at url: URL, identity: FileIdentity) throws {
        do { try AudioStoredFile.validateMP3(at: url, identity: identity) }
        catch { throw AudioDownloadError.invalidAudio }
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
        if isOutOfSpace(error) {
            return "Telefonens lagringsutrymme räcker inte. Redan hämtade verser finns kvar."
        }
        let storageFailures: Set<URLError.Code> = [.cannotCreateFile, .cannotOpenFile, .cannotWriteToFile, .cannotMoveFile]
        if (error as NSError).domain == NSCocoaErrorDomain ||
            (error as? URLError).map({ storageFailures.contains($0.code) }) == true {
            return "Ljudfilen kunde inte sparas på telefonen. Kontrollera lagringsutrymmet och försök igen. Redan hämtade verser finns kvar."
        }
        return allowsCellularAccess
            ? "Nedladdningen avbröts. Kontrollera anslutningen och försök igen. Redan hämtade verser finns kvar."
            : "Nedladdningen avbröts. Kontrollera Wi-Fi och försök igen. Redan hämtade verser finns kvar."
    }

    /// URLSession wraps ENOSPC in a URL error; FileManager may use Cocoa's own
    /// out-of-space code. Preserve the same useful recovery message for both.
    private func isOutOfSpace(_ error: Error) -> Bool {
        var current: NSError? = error as NSError
        for _ in 0..<8 {
            guard let error = current else { break }
            if error.domain == NSCocoaErrorDomain && error.code == CocoaError.fileWriteOutOfSpace.rawValue ||
                error.domain == NSPOSIXErrorDomain && error.code == Int(POSIXErrorCode.ENOSPC.rawValue) {
                return true
            }
            current = error.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return false
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
