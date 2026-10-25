import AVFoundation
import Combine
import Foundation
import QuranCore
import XCTest
@testable import Sakina

/// Exercises the real AVPlayer with generated local PCM, never a network URL,
/// microphone, human recording or a claim about reciter/MP3 audio quality.
@MainActor
final class RecitationPlayerTests: XCTestCase {
    func testLateNativePlayCannotOverrideAnExplicitPause() async throws {
        let source = try wave(seconds: 8)
        let rig = try makePlayer { _, _ in source }
        defer { rig.service.stop() }
        let verse = try reference(1)
        let began = expectation(description: "The generated local verse really starts")
        let start = rig.service.$activeReference.first(where: { $0 == verse })
            .sink { _ in began.fulfill() }
        defer { start.cancel() }
        rig.service.play(reference: verse, chapterVerseCount: 7)
        await fulfillment(of: [began], timeout: 12)

        rig.service.pause()
        // Model a delayed native start/rate transition after the app has
        // already accepted the user's pause. Keep the real eight-second WAV;
        // reaching EOF cannot satisfy the two-second acknowledgement.
        rig.engine.play()
        let paused = expectation(description: "The controller rejects a late native play")
        let acknowledgement = rig.engine.publisher(for: \.rate, options: [.initial, .new])
            .first(where: { $0 == 0 }).sink { _ in paused.fulfill() }
        defer { acknowledgement.cancel() }
        await fulfillment(of: [paused], timeout: 2)

        XCTAssertEqual(rig.engine.rate, 0)
        XCTAssertFalse(rig.service.isPlaying)
        XCTAssertFalse(rig.service.isBuffering)
        XCTAssertFalse(rig.service.hasFinishedVerse)
        XCTAssertLessThan(rig.engine.currentTime().seconds, 4)
        XCTAssertEqual(rig.service.requestedReference, verse)
        XCTAssertEqual(rig.service.activeReference, verse)
        XCTAssertNil(rig.service.errorMessage)
    }

    func testPausedReciterChangeDefersLoadingUntilExplicitResume() throws {
        let source = try wave(seconds: 8)
        var requests: [Reciter] = []
        let rig = try makePlayer { _, reciter in requests.append(reciter); return source }
        defer { rig.service.stop() }
        let verse = try reference(1)

        rig.service.play(reference: verse, chapterVerseCount: 7)
        rig.service.pause()
        rig.service.selectReciter(.husary)

        XCTAssertEqual(requests, [.alafasy])
        XCTAssertNil(rig.engine.currentItem, "A paused reciter selection must not load another asset")
        XCTAssertEqual(rig.service.requestedReference, verse)
        XCTAssertEqual(rig.service.selectedReciter, .husary)
        XCTAssertFalse(rig.service.isBuffering)
        XCTAssertFalse(rig.service.isPlaying)

        rig.service.resume()
        XCTAssertEqual(requests, [.alafasy, .husary])
        XCTAssertNotNil(rig.engine.currentItem)
        XCTAssertEqual(rig.service.requestedReference, verse)
    }

    func testRealPlaybackStartsAndNaturalEndAdvancesToTheExactNextVerse() async throws {
        let short = try wave(seconds: 0.8)
        let long = try wave(seconds: 8)
        let first = try reference(1)
        let second = try reference(2)
        var requests: [AyahReference] = []
        let rig = try makePlayer { verse, _ in
            requests.append(verse)
            return verse == first ? short : long
        }
        defer { rig.service.stop() }
        let began = expectation(description: "Actual playback highlights the first verse")
        let advanced = expectation(description: "The end event selects the next verse")
        let startSubscription = rig.service.$activeReference.first(where: { $0 == first }).sink { _ in began.fulfill() }
        let nextSubscription = rig.service.$requestedReference.first(where: { $0 == second }).sink { _ in advanced.fulfill() }
        defer { startSubscription.cancel(); nextSubscription.cancel() }

        rig.service.play(reference: first, chapterVerseCount: 7)
        await fulfillment(of: [began, advanced], timeout: 12)

        XCTAssertEqual(rig.service.requestedReference, second)
        XCTAssertEqual(requests, [first, second])
        XCTAssertEqual((rig.engine.currentItem?.asset as? AVURLAsset)?.url, long)
        XCTAssertNil(rig.service.errorMessage)
    }

    func testPracticeNaturalEndStopsAfterOneVerseWithoutChangingAutoplayPreference() async throws {
        let source = try wave(seconds: 0.6)
        let verse = try reference(3)
        var requestCount = 0
        let rig = try makePlayer { _, _ in requestCount += 1; return source }
        defer { rig.service.stop() }
        rig.service.autoplay = true
        let finished = expectation(description: "One practice verse finishes")
        let subscription = afterNaturalEnd(of: rig.service, fulfill: finished)
        defer { subscription.cancel() }
        rig.service.playOnce(reference: verse, chapterVerseCount: 7)
        await fulfillment(of: [finished], timeout: 12)

        XCTAssertTrue(rig.service.autoplay)
        XCTAssertEqual(rig.service.requestedReference, verse)
        XCTAssertEqual(rig.service.activeReference, verse)
        XCTAssertEqual(requestCount, 1)
        XCTAssertFalse(rig.service.isPlaying)
        XCTAssertFalse(rig.service.isBuffering)
        XCTAssertGreaterThan(rig.engine.currentTime().seconds, 0.4)
    }

    func testLastVerseNaturalEndDoesNotRequestANonexistentVerse() async throws {
        let source = try wave(seconds: 0.6)
        let last = try reference(7)
        var requests: [AyahReference] = []
        let rig = try makePlayer { verse, _ in requests.append(verse); return source }
        defer { rig.service.stop() }
        let finished = expectation(description: "The chapter's last verse finishes")
        let subscription = afterNaturalEnd(of: rig.service, fulfill: finished)
        defer { subscription.cancel() }
        rig.service.play(reference: last, chapterVerseCount: 7)
        await fulfillment(of: [finished], timeout: 12)
        rig.service.next()

        XCTAssertEqual(requests, [last])
        XCTAssertEqual(rig.service.requestedReference, last)
        XCTAssertFalse(rig.service.isPlaying)
        XCTAssertFalse(rig.service.isBuffering)
    }

    func testInvalidLocalAudioGivesOfflineRecoveryAndCanRetryAReplacement() async throws {
        let invalid = try directory().appendingPathComponent("invalid.wav")
        try Data(repeating: 0, count: 64).write(to: invalid)
        let valid = try wave(seconds: 8)
        let verse = try reference(1)
        var useInvalid = true
        let rig = try makePlayer { _, _ in useInvalid ? invalid : valid }
        defer { rig.service.stop() }
        let failed = expectation(description: "An invalid local asset reports an error")
        let failureSubscription = rig.service.$errorMessage.compactMap { $0 }.first().sink { _ in failed.fulfill() }
        defer { failureSubscription.cancel() }

        rig.service.playOnce(reference: verse, chapterVerseCount: 7)
        await fulfillment(of: [failed], timeout: 12)

        XCTAssertTrue(rig.service.errorMessage?.contains("sparade ljudet") == true)
        XCTAssertEqual(rig.service.requestedReference, verse)
        XCTAssertNil(rig.service.activeReference)
        XCTAssertFalse(rig.service.isPlaying)
        XCTAssertFalse(rig.service.isBuffering)

        useInvalid = false
        let restarted = expectation(description: "An explicit retry plays the replacement local asset")
        let startSubscription = rig.service.$activeReference.first(where: { $0 == verse }).sink { _ in restarted.fulfill() }
        defer { startSubscription.cancel() }
        rig.service.resume()
        await fulfillment(of: [restarted], timeout: 12)

        XCTAssertNil(rig.service.errorMessage)
        XCTAssertEqual((rig.engine.currentItem?.asset as? AVURLAsset)?.url, valid)
        XCTAssertEqual(rig.service.requestedReference, verse)
    }

    func testLateCompletionAndFailureFromReplacedItemCannotChangeTheNewVerse() async throws {
        let source = try wave(seconds: 8)
        let first = try reference(1)
        let replacement = try reference(4)
        var requests: [AyahReference] = []
        let rig = try makePlayer { verse, _ in requests.append(verse); return source }
        defer { rig.service.stop() }
        rig.service.play(reference: first, chapterVerseCount: 7)
        let oldItem = try XCTUnwrap(rig.engine.currentItem)
        // Queue the old end callback, then replace its item before its actor
        // task can run. A generation/item check must discard the stale event.
        NotificationCenter.default.post(name: AVPlayerItem.didPlayToEndTimeNotification, object: oldItem)
        let began = expectation(description: "The explicitly selected replacement starts")
        let subscription = rig.service.$activeReference.first(where: { $0 == replacement }).sink { _ in began.fulfill() }
        defer { subscription.cancel() }
        rig.service.play(reference: replacement, chapterVerseCount: 7)
        NotificationCenter.default.post(name: AVPlayerItem.failedToPlayToEndTimeNotification, object: oldItem)
        await fulfillment(of: [began], timeout: 12)

        XCTAssertEqual(requests, [first, replacement])
        XCTAssertEqual(rig.service.requestedReference, replacement)
        XCTAssertEqual(rig.service.activeReference, replacement)
        XCTAssertNil(rig.service.errorMessage)
    }

    func testMediaServicesResetKeepsSelectionAndRebuildsOnlyOnExplicitResume() async throws {
        let source = try wave(seconds: 8)
        let verse = try reference(4)
        let original = AVPlayer()
        original.isMuted = true
        let replacement = AVPlayer()
        replacement.isMuted = true
        var requests: [AyahReference] = []
        var replacementCount = 0
        let service = RecitationPlayer(
            player: original, audioURL: { reference, _ in requests.append(reference); return source },
            defaults: try isolatedDefaults(), integratesWithSystemAudio: false,
            makeReplacementPlayer: { replacementCount += 1; return replacement }
        )
        defer { service.stop() }
        service.selectReciter(.minshawi)
        service.autoplay = false
        let began = expectation(description: "The original player starts the selected verse")
        let beganSubscription = service.$activeReference.first(where: { $0 == verse }).sink { _ in began.fulfill() }
        defer { beganSubscription.cancel() }
        service.playOnce(reference: verse, chapterVerseCount: 7)
        await fulfillment(of: [began], timeout: 12)
        let oldItem = try XCTUnwrap(original.currentItem)

        NotificationCenter.default.post(name: AVAudioSession.mediaServicesWereResetNotification,
                                        object: AVAudioSession.sharedInstance())

        XCTAssertEqual(replacementCount, 1)
        XCTAssertNil(original.currentItem)
        XCTAssertNil(replacement.currentItem, "Resetting audio must not silently reload or restart a recording")
        XCTAssertEqual(requests, [verse])
        XCTAssertEqual(service.requestedReference, verse)
        XCTAssertEqual(service.selectedReciter, .minshawi)
        XCTAssertFalse(service.autoplay)
        XCTAssertNil(service.activeReference)
        XCTAssertFalse(service.isPlaying)
        XCTAssertFalse(service.isBuffering)
        XCTAssertTrue(try XCTUnwrap(service.errorMessage).contains("ljudtjänst"))

        let resumed = expectation(description: "An explicit play action starts the rebuilt player")
        let resumedSubscription = service.$activeReference.first(where: { $0 == verse }).sink { _ in resumed.fulfill() }
        defer { resumedSubscription.cancel() }
        service.resume()
        // Old callbacks cannot finish or fail the replacement item.
        NotificationCenter.default.post(name: AVPlayerItem.didPlayToEndTimeNotification, object: oldItem)
        NotificationCenter.default.post(name: AVPlayerItem.failedToPlayToEndTimeNotification, object: oldItem)
        await fulfillment(of: [resumed], timeout: 12)

        XCTAssertEqual(requests, [verse, verse])
        XCTAssertEqual(service.requestedReference, verse)
        XCTAssertEqual(service.activeReference, verse)
        XCTAssertNotNil(replacement.currentItem)
        XCTAssertNil(service.errorMessage)
    }

    func testMediaServicesResetWhileStoppedDoesNotRequestAudioOrInventAnError() throws {
        let source = try wave(seconds: 1)
        let original = AVPlayer()
        let replacement = AVPlayer()
        var requestCount = 0
        var replacementCount = 0
        let service = RecitationPlayer(
            player: original, audioURL: { _, _ in requestCount += 1; return source },
            defaults: try isolatedDefaults(), integratesWithSystemAudio: false,
            makeReplacementPlayer: { replacementCount += 1; return replacement }
        )
        defer { service.stop() }

        NotificationCenter.default.post(name: AVAudioSession.mediaServicesWereResetNotification,
                                        object: AVAudioSession.sharedInstance())

        XCTAssertEqual(replacementCount, 1)
        XCTAssertEqual(requestCount, 0)
        XCTAssertNil(original.currentItem)
        XCTAssertNil(replacement.currentItem)
        XCTAssertNil(service.requestedReference)
        XCTAssertNil(service.activeReference)
        XCTAssertNil(service.errorMessage)
        XCTAssertFalse(service.isPlaying)
        XCTAssertFalse(service.isBuffering)
    }

    func testSavedAudioPreferencesRestoreWithoutCreatingAnAsset() throws {
        let defaults = try isolatedDefaults()
        let engine = AVPlayer()
        var requests = 0
        let source = try wave(seconds: 1)
        let first = RecitationPlayer(player: engine, audioURL: { _, _ in requests += 1; return source },
                                     defaults: defaults, integratesWithSystemAudio: false)
        first.selectReciter(.minshawi)
        first.autoplay = false
        first.stop()
        let restoredEngine = AVPlayer()
        let restored = RecitationPlayer(player: restoredEngine, audioURL: { _, _ in requests += 1; return source },
                                        defaults: defaults, integratesWithSystemAudio: false)
        defer { restored.stop() }

        XCTAssertEqual(restored.selectedReciter, .minshawi)
        XCTAssertFalse(restored.autoplay)
        XCTAssertEqual(requests, 0)
        XCTAssertNil(restoredEngine.currentItem)
        XCTAssertNil(restored.requestedReference)
        XCTAssertFalse(restored.isPlaying)
    }

    private func makePlayer(source: @escaping RecitationPlayer.AudioURLProvider) throws
        -> (service: RecitationPlayer, engine: AVPlayer) {
        let engine = AVPlayer()
        engine.isMuted = true
        return (RecitationPlayer(player: engine, audioURL: source, defaults: try isolatedDefaults(),
                                 integratesWithSystemAudio: false), engine)
    }

    private func afterNaturalEnd(of player: RecitationPlayer, fulfill expectation: XCTestExpectation) -> AnyCancellable {
        // A paused KVO update can arrive before the natural-end handler. Wait
        // for the controller to process that end, rather than guessing queue
        // order or sleeping for an arbitrary amount of time.
        player.$isPlaying.filter { [weak player] playing in
            !playing && player?.hasFinishedVerse == true
        }.first().sink { _ in expectation.fulfill() }
    }

    private func isolatedDefaults() throws -> UserDefaults {
        let name = "sakina.playback-tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    private func reference(_ number: Int) throws -> AyahReference {
        try XCTUnwrap(AyahReference(surahID: 1, ayahNumber: number))
    }

    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sakina.playback-tests.\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func wave(seconds: Double) throws -> URL {
        let frames = Int(seconds * 16_000)
        let byteCount = UInt32(frames * 2)
        var data = Data("RIFF".utf8)
        func append<T: FixedWidthInteger>(_ value: T) {
            var littleEndian = value.littleEndian
            withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
        }
        append(UInt32(36) + byteCount)
        data.append(contentsOf: "WAVEfmt ".utf8)
        append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
        append(UInt32(16_000)); append(UInt32(32_000))
        append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: "data".utf8)
        append(byteCount)
        data.append(Data(repeating: 0, count: Int(byteCount)))
        let url = try directory().appendingPathComponent("silence.wav")
        try data.write(to: url)
        return url
    }
}
