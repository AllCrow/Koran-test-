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
