import Foundation
import QuranCore

/// One exact sura/reciter selection already stored on this phone.
struct AudioDownloadEntry: Equatable, Identifiable, Sendable {
    let surahID: Int
    let reciter: Reciter
    let verseCount: Int
    let totalVerses: Int
    /// Logical size of every canonical regular MP3, including damaged files.
    let bytes: Int64
    let validBytes: Int64
    let storedVerseCount: Int
    /// Zero when this selection contains no admitted verse yet.
    let firstAvailableVerse: Int

    init(surahID: Int, reciter: Reciter, verseCount: Int, totalVerses: Int,
         bytes: Int64, firstAvailableVerse: Int,
         validBytes: Int64? = nil, storedVerseCount: Int? = nil) {
        self.surahID = surahID
        self.reciter = reciter
        self.verseCount = verseCount
        self.totalVerses = totalVerses
        self.bytes = bytes
        self.validBytes = validBytes ?? bytes
        self.storedVerseCount = storedVerseCount ?? verseCount
        self.firstAvailableVerse = firstAvailableVerse
    }

    var damagedVerseCount: Int { max(0, storedVerseCount - verseCount) }
    var id: String { "\(reciter.rawValue):\(surahID)" }
    var isComplete: Bool { verseCount == totalVerses }
}

/// Shared by foreground admission, playback lookup and the background inventory.
/// This validates a bounded MP3 prefix, not a recording's full acoustic content.
enum AudioStoredFile {
    static let maximumBytes: Int64 = 32 * 1_024 * 1_024

    struct Identity: Equatable, Sendable {
        let bytes: Int64
        let modified: Date
    }

    enum ValidationError: Error { case invalidAudio }

    static func isDirectory(_ url: URL) -> Bool {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.type]) as? FileAttributeType == .typeDirectory
    }

    static func identity(at url: URL) throws -> Identity {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let bytes = attributes[.size] as? NSNumber,
              let modified = attributes[.modificationDate] as? Date else {
            throw ValidationError.invalidAudio
        }
        return Identity(bytes: bytes.int64Value, modified: modified)
    }

    /// Check two consecutive MPEG Layer III frames, allowing an ID3v2 tag first.
    /// Reads at most ten tag-header bytes and 8 KiB of the audio prefix.
    static func validateMP3(at url: URL, identity: Identity) throws {
        guard (128...maximumBytes).contains(identity.bytes) else { throw ValidationError.invalidAudio }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let header = [UInt8](try handle.read(upToCount: 10) ?? Data())
        guard header.count == 10 else { throw ValidationError.invalidAudio }
        var offset = 0
        if Array(header.prefix(3)) == [0x49, 0x44, 0x33] {
            guard (2...4).contains(header[3]), header[6...9].allSatisfy({ $0 < 128 }) else {
                throw ValidationError.invalidAudio
            }
            let tagSize = header[6...9].reduce(0) { ($0 << 7) | Int($1) }
            let footerSize = header[3] == 4 && header[5] & 0x10 != 0 ? 10 : 0
            offset = 10 + tagSize + footerSize
        }
        guard Int64(offset + 8) <= identity.bytes else { throw ValidationError.invalidAudio }
        try handle.seek(toOffset: UInt64(offset))
        let bytes = [UInt8](try handle.read(upToCount: 8_192) ?? Data())
        guard bytes.count >= 8 else { throw ValidationError.invalidAudio }
        for start in 0..<min(4_096, bytes.count - 7) {
            guard let length = frameLength(bytes, at: start),
                  start + length + 4 <= bytes.count,
                  let nextLength = frameLength(bytes, at: start + length),
                  Int64(offset + start + length + nextLength) <= identity.bytes,
                  bytes[start + 1] & 0x1E == bytes[start + length + 1] & 0x1E,
                  bytes[start + 2] & 0x0C == bytes[start + length + 2] & 0x0C else { continue }
            return
        }
        throw ValidationError.invalidAudio
    }

    private static func frameLength(_ bytes: [UInt8], at start: Int) -> Int? {
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
}

/// No recursion or network. Only the three known reciters and 114 known suras
/// are considered; each shallow directory walk has a finite entry budget.
enum AudioStorageInventory {
    enum ScanError: Error { case unavailable }

    static func canonicalVerse(in filename: String, surahID: Int) -> Int? {
        guard filename.utf8.count == 10, filename.hasSuffix(".mp3"),
              let number = Int(filename.dropFirst(3).prefix(3)),
              AyahReference(surahID: surahID, ayahNumber: number) != nil,
              filename == String(format: "%03d%03d.mp3", surahID, number) else { return nil }
        return number
    }

    private enum DirectoryKind: Equatable { case directory, missing, other }

    private static func directoryKind(at url: URL) throws -> DirectoryKind {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.type] as? FileAttributeType == .typeDirectory ? .directory : .other
        } catch let error as CocoaError where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile {
            return .missing
        } catch {
            throw ScanError.unavailable
        }
    }

    private static func storedIdentity(at url: URL) throws -> AudioStoredFile.Identity? {
        do { return try AudioStoredFile.identity(at: url) }
        catch AudioStoredFile.ValidationError.invalidAudio { return nil }
        catch let error as CocoaError where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile { return nil }
        catch { throw ScanError.unavailable }
    }

    static func scan(at root: URL) throws -> [AudioDownloadEntry] {
        try Task.checkCancellation()
        switch try directoryKind(at: root) {
        case .directory: break
        case .missing: return []
        case .other: throw ScanError.unavailable
        }
        var result: [AudioDownloadEntry] = []
        var allStoredBytes: Int64 = 0
        for reciter in Reciter.allCases {
            try Task.checkCancellation()
            let reciterFolder = root.appendingPathComponent(reciter.rawValue, isDirectory: true)
            guard try directoryKind(at: reciterFolder) == .directory else { continue }
            for (index, total) in AyahReference.ayahCounts.enumerated() {
                try Task.checkCancellation()
                let surahID = index + 1
                let folder = reciterFolder.appendingPathComponent(String(format: "%03d", surahID), isDirectory: true)
                guard try directoryKind(at: folder) == .directory else { continue }
                var count = 0
                var storedCount = 0
                var bytes: Int64 = 0
                var validBytes: Int64 = 0
                var firstVerse = 0
                var encounteredError = false
                guard let files = FileManager.default.enumerator(at: folder,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants, .skipsPackageDescendants],
                    errorHandler: { _, _ in encounteredError = true; return false }) else {
                    throw ScanError.unavailable
                }
                var examined = 0
                while let url = files.nextObject() as? URL {
                    try Task.checkCancellation()
                    examined += 1
                    // Legacy folders contain at most one file per verse. Stop
                    // a malformed directory without allocating an unbounded list.
                    guard examined <= total + 64 else { throw ScanError.unavailable }
                    guard let number = canonicalVerse(in: url.lastPathComponent, surahID: surahID),
                          let identity = try storedIdentity(at: url), identity.bytes >= 0 else { continue }
                    let valid = (try? AudioStoredFile.validateMP3(at: url, identity: identity)) != nil
                    // Do not publish bytes from a file replaced while it was read.
                    guard try storedIdentity(at: url) == identity else { continue }
                    let (nextBytes, overflow) = bytes.addingReportingOverflow(identity.bytes)
                    let (globalBytes, globalOverflow) = allStoredBytes.addingReportingOverflow(identity.bytes)
                    guard !overflow, !globalOverflow else { throw ScanError.unavailable }
                    allStoredBytes = globalBytes
                    storedCount += 1
                    bytes = nextBytes
                    if valid {
                        count += 1
                        validBytes += identity.bytes
                        if firstVerse == 0 || number < firstVerse { firstVerse = number }
                    }
                }
                if encounteredError { throw ScanError.unavailable }
                if storedCount > 0 {
                    result.append(AudioDownloadEntry(surahID: surahID, reciter: reciter,
                        verseCount: count, totalVerses: total, bytes: bytes,
                        firstAvailableVerse: firstVerse, validBytes: validBytes,
                        storedVerseCount: storedCount))
                }
            }
        }
        try Task.checkCancellation()
        return result.sorted {
            if $0.surahID != $1.surahID { return $0.surahID < $1.surahID }
            return $0.reciter.rawValue < $1.reciter.rawValue
        }
    }
}
