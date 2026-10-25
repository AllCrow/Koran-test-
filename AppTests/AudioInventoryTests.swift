import Foundation
import QuranCore
import XCTest
@testable import Sakina

/// Real isolated filesystem snapshots. These MPEG prefixes test storage
/// admission and byte accounting, not reciter identity or full MP3 decoding.
@MainActor
final class AudioInventoryTests: XCTestCase {
    func testInventorySeparatesValidVersesFromDamagedOccupiedStorage() async throws {
        let root = try directory()
        let plain = frames()
        let tagged = Data([0x49, 0x44, 0x33, 0x04, 0, 0, 0, 0, 0, 0]) + plain
        try save(plain, surah: 1, verse: 2, reciter: .alafasy, root: root)
        try save(tagged, surah: 1, verse: 4, reciter: .alafasy, root: root)
        try save(Data(repeating: 0x3C, count: 900), surah: 1, verse: 6, reciter: .alafasy, root: root)
        for verse in 1...4 { try save(plain, surah: 112, verse: verse, reciter: .husary, root: root) }
        try save(Data(repeating: 0x3C, count: 4_096), surah: 114, verse: 1, reciter: .minshawi, root: root)
        try save(Data(), surah: 114, verse: 2, reciter: .minshawi, root: root)
        let oversized = try save(Data(), surah: 114, verse: 3, reciter: .minshawi, root: root)
        let handle = try FileHandle(forWritingTo: oversized)
        try handle.truncate(atOffset: 33 * 1_024 * 1_024)
        try handle.close()
        let folder = root.appendingPathComponent("alafasy/001")
        for name in ["001000.mp3", "001008.mp3", "000001.mp3", "1.mp3", "001005.MP3", "notes.txt"] {
            try plain.write(to: folder.appendingPathComponent(name))
        }
        let unknown = root.appendingPathComponent("unknown/001")
        try FileManager.default.createDirectory(at: unknown, withIntermediateDirectories: true)
        try plain.write(to: unknown.appendingPathComponent("001001.mp3"))
        let library = AudioLibrary(directory: root, download: { _, _ in
            XCTFail("Inspecting saved audio must not start a download")
            throw URLError(.notConnectedToInternet)
        })

        await library.refreshInventory()

        XCTAssertTrue(library.hasCurrentInventory)
        XCTAssertFalse(library.isScanning)
        XCTAssertNil(library.inventoryError)
        XCTAssertEqual(library.entries.count, 3)
        let first = try XCTUnwrap(library.entries.first { $0.id == "alafasy:1" })
        XCTAssertEqual(first.verseCount, 2)
        XCTAssertEqual(first.storedVerseCount, 3)
        XCTAssertEqual(first.damagedVerseCount, 1)
        XCTAssertEqual(first.totalVerses, 7)
        XCTAssertEqual(first.firstAvailableVerse, 2)
        XCTAssertEqual(first.validBytes, Int64(plain.count + tagged.count))
        XCTAssertEqual(first.bytes, Int64(plain.count + tagged.count + 900))
        XCTAssertFalse(first.isComplete)
        let complete = try XCTUnwrap(library.entries.first { $0.id == "husary:112" })
        XCTAssertTrue(complete.isComplete)
        XCTAssertEqual(complete.verseCount, 4)
        let damaged = try XCTUnwrap(library.entries.first { $0.id == "minshawi:114" })
        XCTAssertEqual(damaged.verseCount, 0)
        XCTAssertEqual(damaged.storedVerseCount, 3)
        XCTAssertEqual(damaged.bytes, 33 * 1_024 * 1_024 + 4_096)
        XCTAssertEqual(damaged.firstAvailableVerse, 0)
        XCTAssertEqual(damaged.validBytes, 0)
        XCTAssertFalse(damaged.isComplete)
        XCTAssertTrue(library.hasStoredAudio(surahID: 114, reciter: .minshawi))
        XCTAssertEqual(library.inventoryBytes, first.bytes + complete.bytes + damaged.bytes)
        XCTAssertEqual(library.entries.map(\.surahID), [1, 112, 114])

        library.deleteSurah(surah(114), reciter: .minshawi)
        XCTAssertFalse(library.hasStoredAudio(surahID: 114, reciter: .minshawi))
        XCTAssertEqual(library.entries.map(\.id), ["alafasy:1", "husary:112"])
        XCTAssertEqual(library.inventoryBytes, first.bytes + complete.bytes)
        XCTAssertNotNil(library.localURL(for: try reference(112, 1), reciter: .husary))
    }

    func testInventoryAndPlaybackNeverFollowSavedFileOrFolderSymlinks() async throws {
        let root = try directory()
        let outside = try directory()
        let bytes = frames()
        let source = outside.appendingPathComponent("source.mp3")
        try bytes.write(to: source)
        let folder = root.appendingPathComponent("alafasy/001")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: folder.appendingPathComponent("001001.mp3"), withDestinationURL: source)
        let outsideChapter = outside.appendingPathComponent("chapter")
        try FileManager.default.createDirectory(at: outsideChapter, withIntermediateDirectories: true)
        try bytes.write(to: outsideChapter.appendingPathComponent("112001.mp3"))
        try FileManager.default.createDirectory(at: root.appendingPathComponent("husary"), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("husary/112"), withDestinationURL: outsideChapter)
        let library = AudioLibrary(directory: root)

        await library.refreshInventory()

        XCTAssertTrue(library.hasCurrentInventory)
        XCTAssertTrue(library.entries.isEmpty)
        XCTAssertNil(library.localURL(for: try reference(1, 1), reciter: .alafasy))
        XCTAssertNil(library.localURL(for: try reference(112, 1), reciter: .husary))
        XCTAssertFalse(library.hasStoredAudio(surahID: 112, reciter: .husary))
        XCTAssertEqual(try Data(contentsOf: source), bytes)
        XCTAssertEqual(try Data(contentsOf: outsideChapter.appendingPathComponent("112001.mp3")), bytes)
    }

    func testDeletionRechecksReplacedRootAndReciterParentsBeforeRemovingAnything() async throws {
        for replaceRoot in [true, false] {
            let root = try directory()
            let outside = try directory()
            let audio = frames()
            try save(audio, surah: 1, verse: 1, reciter: .alafasy, root: root)
            let external = try save(audio, surah: 1, verse: 1, reciter: .alafasy, root: outside)
            let library = AudioLibrary(directory: root)
            await library.refreshInventory()
            XCTAssertTrue(library.hasCurrentInventory)
            let replaced = replaceRoot ? root : root.appendingPathComponent("alafasy")
            let target = replaceRoot ? outside : outside.appendingPathComponent("alafasy")
            try FileManager.default.removeItem(at: replaced)
            try FileManager.default.createSymbolicLink(at: replaced, withDestinationURL: target)

            library.deleteSurah(surah(1), reciter: .alafasy)

            XCTAssertEqual(try Data(contentsOf: external), audio)
            XCTAssertTrue(FileManager.default.fileExists(atPath: external.deletingLastPathComponent().path))
            XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: replaced.path)[.type] as? FileAttributeType, .typeSymbolicLink)
            XCTAssertNotNil(library.errorMessage)
            XCTAssertFalse(library.hasCurrentInventory)
        }
    }

    func testInventoryWorkerDoesNotRunItsFilesystemWorkOnTheUIThread() async throws {
        let root = try directory()
        try save(frames(), surah: 1, verse: 1, reciter: .minshawi, root: root)
        let threads = ScanThreadLog()
        let library = AudioLibrary(directory: root, inventoryScan: { url in
            let wasMain = Thread.isMainThread
            await threads.record(wasMain)
            return try AudioStorageInventory.scan(at: url)
        })

        await library.refreshInventory()

        let observed = await threads.values
        XCTAssertEqual(observed, [false])
        XCTAssertTrue(library.hasCurrentInventory)
        XCTAssertEqual(library.entries.first?.verseCount, 1)
    }

    func testCancelledInventoryCannotPublishItsNoncooperativeLateResult() async throws {
        let started = expectation(description: "An inventory response is held")
        let gate = ScanGate { _ in started.fulfill() }
        defer { Task { await gate.finishAll() } }
        let library = AudioLibrary(directory: try directory(), inventoryScan: { _ in try await gate.scan() })
        let job = Task { await library.refreshInventory() }
        await fulfillment(of: [started], timeout: 2)

        job.cancel()
        try await gate.complete(0, with: [entry()])
        await job.value

        XCTAssertTrue(library.entries.isEmpty)
        XCTAssertFalse(library.hasCurrentInventory)
        XCTAssertFalse(library.isScanning)
        XCTAssertNil(library.inventoryError)
    }

    func testOlderInventoryCompletionCannotReplaceANewerVerifiedSnapshot() async throws {
        let first = expectation(description: "First inventory is held")
        let second = expectation(description: "Replacement inventory is held")
        let gate = ScanGate { call in if call == 0 { first.fulfill() } else { second.fulfill() } }
        defer { Task { await gate.finishAll() } }
        let library = AudioLibrary(directory: try directory(), inventoryScan: { _ in try await gate.scan() })
        let oldJob = Task { await library.refreshInventory() }
        await fulfillment(of: [first], timeout: 2)
        let newJob = Task { await library.refreshInventory() }
        await fulfillment(of: [second], timeout: 2)
        let newest = entry(surah: 112, reciter: .husary)
        try await gate.complete(1, with: [newest])
        await newJob.value
        XCTAssertEqual(library.entries, [newest])
        XCTAssertTrue(library.hasCurrentInventory)

        try await gate.complete(0, with: [entry()])
        await oldJob.value

        XCTAssertEqual(library.entries, [newest])
        XCTAssertTrue(library.hasCurrentInventory)
        XCTAssertFalse(library.isScanning)
        XCTAssertNil(library.inventoryError)
    }

    func testDeletionInvalidatesAnOldScanAndPreservesOtherStoredSelections() async throws {
        let root = try directory()
        let audio = frames()
        let deleted = try save(audio, surah: 1, verse: 1, reciter: .alafasy, root: root)
        let retained = try save(audio, surah: 112, verse: 1, reciter: .husary, root: root)
        let oldSnapshot = try AudioStorageInventory.scan(at: root)
        let started = expectation(description: "Pre-deletion inventory remains in flight")
        let gate = ScanGate { _ in started.fulfill() }
        defer { Task { await gate.finishAll() } }
        let library = AudioLibrary(directory: root, inventoryScan: { _ in try await gate.scan() })
        let job = Task { await library.refreshInventory() }
        await fulfillment(of: [started], timeout: 2)

        library.deleteSurah(surah(1), reciter: .alafasy)
        try await gate.complete(0, with: oldSnapshot)
        await job.value

        XCTAssertTrue(library.entries.isEmpty, "A late result cannot resurrect removed audio")
        XCTAssertFalse(library.hasCurrentInventory)
        XCTAssertFalse(FileManager.default.fileExists(atPath: deleted.path))
        XCTAssertEqual(try Data(contentsOf: retained), audio)
        XCTAssertEqual(library.downloadedVerseCount(surahID: 112, reciter: .husary), 1)
        let reopened = AudioLibrary(directory: root)
        await reopened.refreshInventory()
        XCTAssertEqual(reopened.entries.map(\.id), ["husary:112"])
        XCTAssertEqual(reopened.inventoryBytes, Int64(audio.count))
    }

    func testFailedRefreshRetainsPreviousRowsButDoesNotReportThemAsVerified() async throws {
        let previous = entry()
        let outcomes = ScanOutcomeSequence(firstSnapshot: [previous])
        let library = AudioLibrary(directory: try directory(), inventoryScan: { _ in try await outcomes.scan() })
        // This case checks persistence across sequential outcomes. The separate
        // stale/cancellation cases retain their held responses and deadlines.
        await library.refreshInventory()
        XCTAssertEqual(library.entries, [previous])
        XCTAssertEqual(library.inventoryBytes, previous.bytes)
        XCTAssertTrue(library.hasCurrentInventory)
        XCTAssertFalse(library.isScanning)
        XCTAssertNil(library.inventoryError)

        await library.refreshInventory()

        let callCount = await outcomes.callCount
        XCTAssertEqual(callCount, 2)
        XCTAssertEqual(library.entries, [previous])
        XCTAssertEqual(library.inventoryBytes, previous.bytes)
        XCTAssertFalse(library.hasCurrentInventory)
        XCTAssertFalse(library.isScanning)
        XCTAssertNotNil(library.inventoryError)
    }

    func testMalformedDirectoryIsBoundedAndCannotLookLikeACompleteSnapshot() async throws {
        let root = try directory()
        let folder = root.appendingPathComponent("alafasy/114")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for number in 0..<80 { try Data([0]).write(to: folder.appendingPathComponent("extra-\(number).bin")) }
        let library = AudioLibrary(directory: root)

        await library.refreshInventory()

        XCTAssertFalse(library.hasCurrentInventory)
        XCTAssertTrue(library.entries.isEmpty)
        XCTAssertFalse(library.isScanning)
        XCTAssertNotNil(library.inventoryError)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path).count, 80)
    }

    func testOverflowingStorageSnapshotIsRejectedInsteadOfPublishingAWrongTotal() async throws {
        let root = try directory()
        let first = AudioDownloadEntry(surahID: 1, reciter: .alafasy, verseCount: 0,
            totalVerses: 7, bytes: .max, firstAvailableVerse: 0, validBytes: 0, storedVerseCount: 1)
        let second = AudioDownloadEntry(surahID: 112, reciter: .husary, verseCount: 0,
            totalVerses: 4, bytes: 1, firstAvailableVerse: 0, validBytes: 0, storedVerseCount: 1)
        let library = AudioLibrary(directory: root, inventoryScan: { _ in [first, second] })

        await library.refreshInventory()

        XCTAssertTrue(library.entries.isEmpty)
        XCTAssertEqual(library.inventoryBytes, 0)
        XCTAssertFalse(library.hasCurrentInventory)
        XCTAssertNotNil(library.inventoryError)
    }

    private func entry(surah: Int = 1, reciter: Reciter = .alafasy) -> AudioDownloadEntry {
        AudioDownloadEntry(surahID: surah, reciter: reciter, verseCount: 1,
            totalVerses: AyahReference.ayahCounts[surah - 1], bytes: Int64(frames().count), firstAvailableVerse: 1)
    }

    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sakina.inventory-tests.\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func reference(_ surah: Int, _ verse: Int) throws -> AyahReference {
        try XCTUnwrap(AyahReference(surahID: surah, ayahNumber: verse))
    }

    private func surah(_ id: Int) -> Surah {
        Surah(id: id, name: "test", englishName: "test", englishNameTranslation: "test",
              numberOfAyahs: AyahReference.ayahCounts[id - 1], revelationType: "test")
    }

    @discardableResult
    private func save(_ data: Data, surah: Int, verse: Int, reciter: Reciter, root: URL) throws -> URL {
        let folder = root.appendingPathComponent(reciter.rawValue).appendingPathComponent(String(format: "%03d", surah))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(String(format: "%03d%03d.mp3", surah, verse))
        try data.write(to: url)
        return url
    }

    private func frames() -> Data {
        var frame = Data(repeating: 0, count: 417)
        frame.replaceSubrange(0..<4, with: [0xFF, 0xFB, 0x90, 0x64])
        return frame + frame
    }
}

private actor ScanThreadLog {
    private(set) var values: [Bool] = []
    func record(_ value: Bool) { values.append(value) }
}

/// Immediate, ordered results still traverse the library's real detached worker.
private actor ScanOutcomeSequence {
    enum Failure: Error { case unavailable }
    private let firstSnapshot: [AudioDownloadEntry]
    private(set) var callCount = 0

    init(firstSnapshot: [AudioDownloadEntry]) { self.firstSnapshot = firstSnapshot }

    func scan() throws -> [AudioDownloadEntry] {
        callCount += 1
        if callCount == 1 { return firstSnapshot }
        throw Failure.unavailable
    }
}

/// Deliberately ignores cancellation to prove actual stale-result suppression.
private actor ScanGate {
    enum GateError: Error { case missingRequest, unavailable }
    private let onStart: @Sendable (Int) -> Void
    private var next = 0
    private var pending: [Int: CheckedContinuation<[AudioDownloadEntry], Error>] = [:]

    init(onStart: @escaping @Sendable (Int) -> Void) { self.onStart = onStart }

    func scan() async throws -> [AudioDownloadEntry] {
        let index = next
        next += 1
        return try await withCheckedThrowingContinuation { continuation in
            pending[index] = continuation
            onStart(index)
        }
    }

    func complete(_ index: Int, with entries: [AudioDownloadEntry]) throws {
        guard let continuation = pending.removeValue(forKey: index) else { throw GateError.missingRequest }
        continuation.resume(returning: entries)
    }

    func fail(_ index: Int) throws {
        guard let continuation = pending.removeValue(forKey: index) else { throw GateError.missingRequest }
        continuation.resume(throwing: GateError.unavailable)
    }

    func finishAll() {
        let values = Array(pending.values)
        pending.removeAll()
        for continuation in values { continuation.resume(throwing: CancellationError()) }
    }
}
