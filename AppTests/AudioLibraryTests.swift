import Combine
import Foundation
import QuranCore
import XCTest
@testable import Sakina

/// Native file-admission tests with isolated storage and no network or audio session.
/// Synthetic MPEG headers exercise structural validation, not playable recitation.
@MainActor
final class AudioLibraryTests: XCTestCase {
    func testSavedAudioIsIsolatedByVerseSurahAndReciter() throws {
        let root = try temporaryDirectory()
        let first = try reference(1)
        let otherSurah = try reference(1, surah: 112)
        let saved = try save(mpegFrames(), reference: first, reciter: .alafasy, root: root)
        let library = AudioLibrary(directory: root)

        XCTAssertEqual(library.localURL(for: first, reciter: .alafasy), saved)
        XCTAssertNil(library.localURL(for: try reference(2), reciter: .alafasy))
        XCTAssertNil(library.localURL(for: first, reciter: .husary))
        XCTAssertNil(library.localURL(for: otherSurah, reciter: .alafasy))
        XCTAssertEqual(library.downloadedVerseCount(surahID: 1, reciter: .alafasy), 1)
        XCTAssertEqual(library.downloadedVerseCount(surahID: 1, reciter: .minshawi), 0)
    }

    func testErrorPagesAndIncompleteAudioAreUnavailableOffline() throws {
        let root = try temporaryDirectory()
        try save(Data(repeating: 0x3C, count: 900), reference: reference(1), root: root)
        try save(Data(mpegFrames().prefix(417)), reference: reference(2), root: root)
        try save(Data([0xFF, 0xFB, 0x90, 0x64]), reference: reference(3), root: root)
        let library = AudioLibrary(directory: root)

        for number in 1...3 {
            XCTAssertNil(library.localURL(for: try reference(number), reciter: .alafasy))
        }
        XCTAssertEqual(library.downloadedVerseCount(surahID: 1, reciter: .alafasy), 0)
    }

    func testID3MetadataIsAcceptedButInvalidTagSizeIsRejected() throws {
        let root = try temporaryDirectory()
        let id3 = Data([0x49, 0x44, 0x33, 0x04, 0, 0, 0, 0, 0, 0])
        try save(id3 + mpegFrames(), reference: reference(1), root: root)
        var invalidTag = id3
        invalidTag[9] = 0x80 // ID3 sizes must use seven-bit synchsafe bytes.
        try save(invalidTag + mpegFrames(), reference: reference(2), root: root)
        let library = AudioLibrary(directory: root)

        XCTAssertNotNil(library.localURL(for: try reference(1), reciter: .alafasy))
        XCTAssertNil(library.localURL(for: try reference(2), reciter: .alafasy))
        XCTAssertEqual(library.downloadedVerseCount(surahID: 1, reciter: .alafasy), 1)
    }

    func testChangedFileIsRevalidatedEvenWhenItsLengthIsUnchanged() throws {
        let root = try temporaryDirectory()
        let verse = try reference(1)
        let audio = mpegFrames()
        let saved = try save(audio, reference: verse, root: root)
        let manager = FileManager.default
        try manager.setAttributes([.modificationDate: Date(timeIntervalSince1970: 100)], ofItemAtPath: saved.path)
        let library = AudioLibrary(directory: root)
        XCTAssertNotNil(library.localURL(for: verse, reciter: .alafasy))

        try Data(repeating: 0, count: audio.count).write(to: saved)
        try manager.setAttributes([.modificationDate: Date(timeIntervalSince1970: 200)], ofItemAtPath: saved.path)
        XCTAssertNil(library.localURL(for: verse, reciter: .alafasy))
        XCTAssertEqual(library.downloadedVerseCount(surahID: 1, reciter: .alafasy), 0)

        try audio.write(to: saved)
        try manager.setAttributes([.modificationDate: Date(timeIntervalSince1970: 300)], ofItemAtPath: saved.path)
        XCTAssertNotNil(library.localURL(for: verse, reciter: .alafasy))
    }

    func testSavedFilesAreAvailableToANewLibraryInstance() throws {
        let root = try temporaryDirectory()
        let verse = try reference(1)
        try save(mpegFrames(), reference: verse, reciter: .husary, root: root)
        var library: AudioLibrary? = AudioLibrary(directory: root)
        XCTAssertEqual(library?.downloadedVerseCount(surahID: 1, reciter: .husary), 1)
        library = nil

        let restored = AudioLibrary(directory: root)
        XCTAssertNotNil(restored.localURL(for: verse, reciter: .husary))
        XCTAssertEqual(restored.downloadedVerseCount(surahID: 1, reciter: .husary), 1)
    }

    func testDeletingOneSelectionPreservesOtherSavedAudio() throws {
        let root = try temporaryDirectory()
        let first = try reference(1)
        let otherSurah = try reference(1, surah: 112)
        try save(mpegFrames(), reference: first, root: root)
        try save(mpegFrames(), reference: first, reciter: .husary, root: root)
        try save(mpegFrames(), reference: otherSurah, root: root)
        let library = AudioLibrary(directory: root)
        XCTAssertNotNil(library.localURL(for: first, reciter: .alafasy)) // Prime validation cache.

        library.deleteSurah(chapter(), reciter: .alafasy)

        XCTAssertNil(library.localURL(for: first, reciter: .alafasy))
        XCTAssertEqual(library.downloadedVerseCount(surahID: 1, reciter: .alafasy), 0)
        XCTAssertNotNil(library.localURL(for: first, reciter: .husary))
        XCTAssertNotNil(library.localURL(for: otherSurah, reciter: .alafasy))
        XCTAssertNil(library.errorMessage)
        library.deleteSurah(chapter(), reciter: .alafasy) // An already removed selection is safe.
        XCTAssertNil(library.errorMessage)
    }

    func testUnusableStorageDoesNotStartADownload() throws {
        let root = try temporaryDirectory().appendingPathComponent("not-a-directory")
        try Data([0]).write(to: root)
        let library = AudioLibrary(directory: root)
        XCTAssertNotNil(library.errorMessage)

        library.beginDownload(chapter(), reciter: .alafasy)

        XCTAssertNil(library.downloadingSurahID)
        XCTAssertNil(library.downloadingReciter)
        XCTAssertEqual(library.total, 0)
        XCTAssertNil(library.localURL(for: try reference(1), reciter: .alafasy))
        XCTAssertNotNil(library.errorMessage)
    }

    func testExplicitRetryRecoversStorageWithoutRecreatingTheLibrary() async throws {
        let root = try temporaryDirectory().appendingPathComponent("temporarily-blocked")
        try Data([0]).write(to: root)
        let transport = DownloadStub(directory: try temporaryDirectory(), body: mpegFrames())
        let library = AudioLibrary(directory: root, download: transport.download)
        XCTAssertNotNil(library.errorMessage)

        library.beginDownload(chapter(), reciter: .minshawi)
        XCTAssertTrue(transport.requests.isEmpty)
        XCTAssertNil(library.downloadingSurahID)
        XCTAssertNotNil(library.errorMessage)

        // Represent storage becoming usable after the user resolves its cause.
        // Retry the same live instance, rather than hiding recovery in a restart.
        try FileManager.default.removeItem(at: root)
        library.beginDownload(chapter(), reciter: .minshawi)
        await waitForDownloadToFinish(library)

        XCTAssertEqual(transport.requests.count, 7)
        XCTAssertEqual(library.completed, 7)
        XCTAssertEqual(library.progress, 1)
        XCTAssertNil(library.errorMessage)
        let restored = AudioLibrary(directory: root)
        XCTAssertEqual(restored.downloadedVerseCount(surahID: 1, reciter: .minshawi), 7)
        XCTAssertNotNil(restored.localURL(for: try reference(1), reciter: .minshawi))
        XCTAssertEqual(try root.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
        XCTAssertTrue(transport.createdFiles.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
    }

    func testCancellationBeforeTheOwnedJobStartsMakesNoRequest() async throws {
        let root = try temporaryDirectory()
        let transport = DownloadStub(directory: try temporaryDirectory(), body: mpegFrames())
        let library = AudioLibrary(directory: root, download: transport.download)

        library.beginDownload(chapter(), reciter: .alafasy)
        library.cancelDownload()
        await waitForDownloadToFinish(library)

        XCTAssertTrue(transport.requests.isEmpty)
        XCTAssertEqual(library.completed, 0)
        XCTAssertNil(library.errorMessage)
        XCTAssertEqual(library.downloadedVerseCount(surahID: 1, reciter: .alafasy), 0)
    }

    func testResumeFetchesOnlyMissingVersesAndUsesExactReciterURLs() async throws {
        let root = try temporaryDirectory()
        try save(mpegFrames(), reference: reference(1), reciter: .husary, root: root)
        try save(mpegFrames(), reference: reference(2), reciter: .husary, root: root)
        let transport = DownloadStub(directory: try temporaryDirectory(), body: mpegFrames())
        let library = AudioLibrary(directory: root, download: transport.download)

        library.beginDownload(chapter(), reciter: .husary)
        XCTAssertEqual(library.completed, 2)
        await waitForDownloadToFinish(library)

        let expected = try (3...7).map { Reciter.husary.audioURL(for: try reference($0)) }
        XCTAssertEqual(transport.requests.compactMap(\.url), expected)
        XCTAssertTrue(transport.requests.allSatisfy { $0.httpMethod == "GET" && !$0.httpShouldHandleCookies && $0.httpBody == nil })
        XCTAssertEqual(library.completed, 7)
        XCTAssertEqual(library.progress, 1)
        XCTAssertEqual(library.downloadedVerseCount(surahID: 1, reciter: .husary), 7)
        XCTAssertEqual(library.downloadedVerseCount(surahID: 1, reciter: .alafasy), 0)
        XCTAssertTrue(transport.createdFiles.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })

        library.beginDownload(chapter(), reciter: .husary)
        await waitForDownloadToFinish(library)
        XCTAssertEqual(transport.requests.count, 5, "A completed sura must not be fetched again")
    }

    func testInterruptedDownloadRetainsCompletedVersesAndCanResume() async throws {
        let root = try temporaryDirectory()
        let transport = DownloadStub(directory: try temporaryDirectory(), body: mpegFrames())
        transport.failureOnCall = 3
        transport.failure = URLError(.networkConnectionLost)
        let library = AudioLibrary(directory: root, download: transport.download)
        library.beginDownload(chapter(), reciter: .minshawi)
        await waitForDownloadToFinish(library)

        XCTAssertEqual(library.completed, 2)
        XCTAssertEqual(library.downloadedVerseCount(surahID: 1, reciter: .minshawi), 2)
        XCTAssertTrue(try XCTUnwrap(library.errorMessage).contains("anslutningen"))
        transport.failureOnCall = nil
        transport.failure = nil
        library.beginDownload(chapter(), reciter: .minshawi)
        await waitForDownloadToFinish(library)

        let expectedNumbers = [1, 2, 3, 3, 4, 5, 6, 7]
        let expected = try expectedNumbers.map { Reciter.minshawi.audioURL(for: try reference($0)) }
        XCTAssertEqual(transport.requests.compactMap(\.url), expected)
        XCTAssertEqual(library.completed, 7)
        XCTAssertNil(library.errorMessage)
    }

    func testResumeRepairsCorruptAudioWithoutReplacingCompletedVerses() async throws {
        let root = try temporaryDirectory()
        let corruptFile = try save(Data(repeating: 0x3C, count: 900), reference: reference(1), root: root)
        let retainedFile = try save(mpegFrames(), reference: reference(2), root: root)
        let retainedDate = Date(timeIntervalSince1970: 12_345)
        try FileManager.default.setAttributes([.modificationDate: retainedDate], ofItemAtPath: retainedFile.path)
        let retainedBytes = try Data(contentsOf: retainedFile)
        let transport = DownloadStub(directory: try temporaryDirectory(), body: mpegFrames())
        let library = AudioLibrary(directory: root, download: transport.download)
        XCTAssertNil(library.localURL(for: try reference(1), reciter: .alafasy))
        XCTAssertNotNil(library.localURL(for: try reference(2), reciter: .alafasy))

        library.beginDownload(chapter(), reciter: .alafasy)
        await waitForDownloadToFinish(library)

        let expectedNumbers = [1, 3, 4, 5, 6, 7]
        let expected = try expectedNumbers.map { Reciter.alafasy.audioURL(for: try reference($0)) }
        XCTAssertEqual(transport.requests.compactMap(\.url), expected)
        XCTAssertEqual(try Data(contentsOf: corruptFile), mpegFrames())
        XCTAssertEqual(try Data(contentsOf: retainedFile), retainedBytes)
        let retainedAttributes = try FileManager.default.attributesOfItem(atPath: retainedFile.path)
        XCTAssertEqual(retainedAttributes[.modificationDate] as? Date, retainedDate)
        XCTAssertEqual(library.completed, 7)
        XCTAssertNil(library.errorMessage)
        let restored = AudioLibrary(directory: root)
        XCTAssertEqual(restored.downloadedVerseCount(surahID: 1, reciter: .alafasy), 7)
        XCTAssertNotNil(restored.localURL(for: try reference(1), reciter: .alafasy))
        XCTAssertTrue(transport.createdFiles.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
    }

    func testRejectedResponsesLeaveNoStoredOrTemporaryAudio() async throws {
        for kind in DownloadStub.InvalidResponse.allCases {
            let root = try temporaryDirectory()
            let transport = DownloadStub(directory: try temporaryDirectory(), body: mpegFrames())
            transport.invalidResponse = kind
            let library = AudioLibrary(directory: root, download: transport.download)
            library.beginDownload(chapter(), reciter: .alafasy)
            await waitForDownloadToFinish(library)

            XCTAssertEqual(transport.requests.count, 1, "Stop at the first rejected response: \(kind)")
            XCTAssertEqual(library.completed, 0)
            XCTAssertEqual(library.downloadedVerseCount(surahID: 1, reciter: .alafasy), 0)
            XCTAssertNotNil(library.errorMessage)
            XCTAssertTrue(transport.createdFiles.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) }, "Remove the temporary file: \(kind)")
        }
    }

    func testCancelledResponseCannotInstallAudioAfterItArrives() async throws {
        let root = try temporaryDirectory()
        let transport = DownloadStub(directory: try temporaryDirectory(), body: mpegFrames())
        let started = expectation(description: "Transport is awaiting its response")
        transport.pauseFirstResponse = true
        transport.onRequest = { started.fulfill() }
        let library = AudioLibrary(directory: root, download: transport.download)
        defer { library.cancelDownload(); transport.resumeResponse() }
        library.beginDownload(chapter(), reciter: .alafasy)
        await fulfillment(of: [started], timeout: 2)

        library.cancelDownload()
        transport.resumeResponse()
        await waitForDownloadToFinish(library)

        XCTAssertEqual(transport.requests.count, 1)
        XCTAssertEqual(library.completed, 0)
        XCTAssertNil(library.errorMessage)
        XCTAssertNil(library.localURL(for: try reference(1), reciter: .alafasy))
        XCTAssertTrue(transport.createdFiles.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
    }

    func testDeletedJobWithLateResponseCannotChangeANewerDownload() async throws {
        let root = try temporaryDirectory()
        let transport = DownloadStub(directory: try temporaryDirectory(), body: mpegFrames())
        transport.pausedCalls = [1, 2]
        let oldStarted = expectation(description: "Old reciter request is held")
        let newStarted = expectation(description: "New reciter request is held")
        let oldFileCreated = expectation(description: "Cancelled transport still returns its owned file")
        var lateFile: URL?
        transport.onRequest = { [weak transport] in
            if transport?.requests.count == 1 { oldStarted.fulfill() }
            if transport?.requests.count == 2 { newStarted.fulfill() }
        }
        transport.onFileCreated = { call, file in
            if call == 1 {
                lateFile = file
                oldFileCreated.fulfill()
            }
        }
        let library = AudioLibrary(directory: root, download: transport.download)
        defer {
            library.cancelDownload()
            transport.resumeResponse()
            transport.resumeResponse(call: 2)
        }
        library.beginDownload(chapter(), reciter: .alafasy)
        await fulfillment(of: [oldStarted], timeout: 2)

        library.deleteSurah(chapter(), reciter: .alafasy)
        library.beginDownload(chapter(), reciter: .husary)
        await fulfillment(of: [newStarted], timeout: 2)
        XCTAssertEqual(library.downloadingReciter, .husary)

        // This transport deliberately ignores Task cancellation, so the old
        // owner's actual cleanup must finish while the new request stays live.
        transport.resumeResponse()
        await fulfillment(of: [oldFileCreated], timeout: 2)
        let oldFile = try XCTUnwrap(lateFile)
        let cleaned = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            !FileManager.default.fileExists(atPath: oldFile.path)
        }, object: nil)
        await fulfillment(of: [cleaned], timeout: 2)
        XCTAssertEqual(library.downloadingSurahID, 1)
        XCTAssertEqual(library.downloadingReciter, .husary)
        XCTAssertEqual(library.completed, 0)
        XCTAssertNil(library.errorMessage)
        XCTAssertNil(library.localURL(for: try reference(1), reciter: .alafasy))

        transport.resumeResponse(call: 2)
        await waitForDownloadToFinish(library)
        let expected = [Reciter.alafasy.audioURL(for: try reference(1))]
            + (try (1...7).map { Reciter.husary.audioURL(for: try reference($0)) })
        XCTAssertEqual(transport.requests.compactMap(\.url), expected)
        XCTAssertEqual(library.completed, 7)
        XCTAssertEqual(library.downloadedVerseCount(surahID: 1, reciter: .alafasy), 0)
        XCTAssertEqual(library.downloadedVerseCount(surahID: 1, reciter: .husary), 7)
        XCTAssertNil(library.errorMessage)
        XCTAssertTrue(transport.createdFiles.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
    }

    func testStorageFailuresGiveStorageRecoveryInsteadOfNetworkAdvice() async throws {
        let noSpace = NSError(domain: NSURLErrorDomain, code: URLError.cannotWriteToFile.rawValue,
                              userInfo: [NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: Int(POSIXErrorCode.ENOSPC.rawValue))])
        let cases: [(Error, String)] = [(noSpace, "lagringsutrymme"), (CocoaError(.fileWriteNoPermission), "kunde inte sparas")]
        for (error, message) in cases {
            let root = try temporaryDirectory()
            let transport = DownloadStub(directory: try temporaryDirectory(), body: mpegFrames())
            transport.failure = error
            let library = AudioLibrary(directory: root, download: transport.download)
            library.beginDownload(chapter(), reciter: .alafasy)
            await waitForDownloadToFinish(library)

            let actual = try XCTUnwrap(library.errorMessage)
            XCTAssertTrue(actual.contains(message), actual)
            XCTAssertFalse(actual.contains("anslutning"), actual)
            XCTAssertEqual(library.completed, 0)
        }
    }

    func testWiFiOnlyDownloadMarksEveryRequestAndKeepsExistingAudio() async throws {
        let root = try temporaryDirectory()
        let existing = try save(mpegFrames(), reference: reference(1), reciter: .husary, root: root)
        let before = try Data(contentsOf: existing)
        let transport = DownloadStub(directory: try temporaryDirectory(), body: mpegFrames())
        let library = AudioLibrary(directory: root, download: transport.download)
        library.setAllowsCellularAccess(false)

        library.beginDownload(chapter(), reciter: .husary)
        await waitForDownloadToFinish(library)

        XCTAssertEqual(transport.requests.count, 6)
        XCTAssertTrue(transport.requests.allSatisfy { !$0.allowsCellularAccess })
        XCTAssertEqual(try Data(contentsOf: existing), before)
        XCTAssertEqual(library.completed, 7)
        XCTAssertNil(library.errorMessage)
    }

    func testChangingNetworkChoiceCancelsAnOldResponseBeforeNewRequestsUseTheChoice() async throws {
        let root = try temporaryDirectory()
        let started = expectation(description: "A request using the old network choice is held")
        let transport = DownloadStub(directory: try temporaryDirectory(), body: mpegFrames())
        transport.pauseFirstResponse = true
        transport.onRequest = { started.fulfill() }
        let library = AudioLibrary(directory: root, download: transport.download)
        defer { library.cancelDownload(); transport.resumeResponse() }
        library.beginDownload(chapter(), reciter: .alafasy)
        await fulfillment(of: [started], timeout: 2)
        XCTAssertTrue(try XCTUnwrap(transport.requests.first).allowsCellularAccess)

        library.setAllowsCellularAccess(false)
        transport.resumeResponse()
        await waitForDownloadToFinish(library)
        XCTAssertEqual(library.completed, 0)
        XCTAssertNil(library.errorMessage)
        XCTAssertNil(library.localURL(for: try reference(1), reciter: .alafasy))
        XCTAssertTrue(transport.createdFiles.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })

        library.beginDownload(chapter(), reciter: .alafasy)
        await waitForDownloadToFinish(library)
        XCTAssertEqual(transport.requests.count, 8)
        XCTAssertTrue(transport.requests.dropFirst().allSatisfy { !$0.allowsCellularAccess })
        XCTAssertEqual(library.completed, 7)
        XCTAssertNil(library.errorMessage)
    }

    func testExplicitDownloadRecoversARemovedStorageRootAndItsBackupExclusion() async throws {
        let root = try temporaryDirectory()
        let transport = DownloadStub(directory: try temporaryDirectory(), body: mpegFrames())
        let library = AudioLibrary(directory: root, download: transport.download)
        try FileManager.default.removeItem(at: root)

        library.beginDownload(chapter(), reciter: .minshawi)
        await waitForDownloadToFinish(library)

        XCTAssertEqual(library.completed, 7)
        XCTAssertEqual(transport.requests.count, 7)
        XCTAssertNil(library.errorMessage)
        XCTAssertEqual(try root.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
        XCTAssertEqual(AudioLibrary(directory: root).downloadedVerseCount(surahID: 1, reciter: .minshawi), 7)
    }

    private func waitForDownloadToFinish(_ library: AudioLibrary) async {
        guard library.downloadingSurahID != nil else { return }
        let finished = expectation(description: "Foreground download has finished")
        let subscription = library.$downloadingSurahID.dropFirst().first(where: { $0 == nil })
            .sink { _ in finished.fulfill() }
        defer { subscription.cancel() }
        await fulfillment(of: [finished], timeout: 3)
        XCTAssertNil(library.downloadingSurahID)
        XCTAssertNil(library.downloadingReciter)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("sakina.audio-tests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory
    }

    private func reference(_ number: Int, surah: Int = 1) throws -> AyahReference {
        try XCTUnwrap(AyahReference(surahID: surah, ayahNumber: number))
    }

    private func chapter() -> Surah {
        Surah(id: 1, name: "test", englishName: "test", englishNameTranslation: "test",
              numberOfAyahs: 7, revelationType: "test")
    }

    @discardableResult
    private func save(_ data: Data, reference: AyahReference, reciter: Reciter = .alafasy, root: URL) throws -> URL {
        let folder = root.appendingPathComponent(reciter.rawValue, isDirectory: true)
            .appendingPathComponent(String(format: "%03d", reference.surahID), isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent(String(format: "%03d%03d.mp3", reference.surahID, reference.ayahNumber))
        try data.write(to: file)
        return file
    }

    private func mpegFrames() -> Data {
        // Two complete MPEG-1 Layer III frame lengths at 128 kbps / 44.1 kHz.
        var frame = Data(repeating: 0, count: 417)
        frame.replaceSubrange(0..<4, with: [0xFF, 0xFB, 0x90, 0x64])
        return frame + frame
    }
}

/// Models only HTTP delivery. AudioLibrary still executes its real admission,
/// move, cancellation and count logic; these synthetic bytes are not playback.
@MainActor
private final class DownloadStub {
    enum InvalidResponse: CaseIterable, Equatable { case status, mimeType, length, nonHTTP, oversized }
    private let directory: URL
    private let body: Data
    private var pausedResponses: [Int: CheckedContinuation<Void, Never>] = [:]
    private var resumedCalls: Set<Int> = []
    var requests: [URLRequest] = []
    var createdFiles: [URL] = []
    var invalidResponse: InvalidResponse?
    var failure: Error?
    var failureOnCall: Int?
    var pauseFirstResponse = false
    var pausedCalls: Set<Int> = []
    var onRequest: (() -> Void)?
    var onFileCreated: ((Int, URL) -> Void)?

    init(directory: URL, body: Data) {
        self.directory = directory
        self.body = body
    }

    var download: AudioLibrary.Download {
        { [self] request, _ in
            requests.append(request)
            let call = requests.count
            if ((pauseFirstResponse && call == 1) || pausedCalls.contains(call)) && !resumedCalls.contains(call) {
                await withCheckedContinuation { continuation in
                    pausedResponses[call] = continuation
                    onRequest?()
                }
            }
            if let failure, failureOnCall == nil || failureOnCall == call { throw failure }
            let file = directory.appendingPathComponent(UUID().uuidString)
            try body.write(to: file)
            createdFiles.append(file)
            onFileCreated?(call, file)
            if invalidResponse == .oversized {
                let handle = try FileHandle(forWritingTo: file)
                defer { try? handle.close() }
                try handle.truncate(atOffset: 33 * 1_024 * 1_024)
            }
            let url = try XCTUnwrap(request.url)
            if invalidResponse == .nonHTTP {
                return (file, URLResponse(url: url, mimeType: "audio/mpeg", expectedContentLength: body.count, textEncodingName: nil))
            }
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url, statusCode: invalidResponse == .status ? 404 : 200, httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": invalidResponse == .mimeType ? "text/html" : "audio/mpeg",
                               "Content-Length": String(invalidResponse == .length ? body.count + 1 : body.count)]
            ))
            return (file, response)
        }
    }

    func resumeResponse(call: Int = 1) {
        resumedCalls.insert(call)
        let continuation = pausedResponses.removeValue(forKey: call)
        continuation?.resume()
    }
}
