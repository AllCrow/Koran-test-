import AVFoundation
import Combine
import Foundation
import QuranCore
import XCTest
@testable import Sakina

/// Real AVFoundation playback of a generated tone, never a recording or a network URL.
/// Notifications are simulated; these tests do not establish physical audio-route behavior.
@MainActor
final class OfflineMP3PlaybackTests: XCTestCase {
    func testSavedMP3DecodesAndEveryReciterUsesItsOwnOfflineFile() async throws {
        let verse = try reference(1)
        let context = try fixture(references: [verse])
        defer { context.player.stop() }
        let file = try AVAudioFile(forReading: context.url(for: verse, reciter: .alafasy))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 4_096))
        try file.read(into: buffer)
        XCTAssertGreaterThan(buffer.frameLength, 0, "The fixture must actually decode to PCM")
        XCTAssertEqual(file.fileFormat.sampleRate, 44_100)

        for reciter in Reciter.allCases {
            context.player.selectReciter(reciter)
            context.player.playOnce(reference: verse, chapterVerseCount: 7)
            await waitFor(context.player.$activeReference, matching: { $0 == verse })
            XCTAssertTrue(context.player.isPlaying)
            XCTAssertFalse(context.player.isBuffering)
            XCTAssertNil(context.player.errorMessage)
            XCTAssertEqual(assetURL(context.engine), context.url(for: verse, reciter: reciter))
            context.player.stop()
        }
        XCTAssertTrue(context.fallbacks.references.isEmpty)
    }

    func testPauseResumeStopAndPreferencesPreserveTheSelectedVerse() async throws {
        let verse = try reference(1)
        let context = try fixture(references: [verse])
        defer { context.player.stop() }
        let player = context.player
        player.selectReciter(.husary)
        player.autoplay = false
        player.playOnce(reference: verse, chapterVerseCount: 7)
        await waitFor(player.$activeReference, matching: { $0 == verse })

        player.pause()
        await waitForNativePause(context)
        XCTAssertFalse(player.isPlaying)
        XCTAssertFalse(player.isBuffering)
        XCTAssertEqual(player.activeReference, verse)
        XCTAssertEqual(context.engine.rate, 0)

        player.selectReciter(.minshawi)
        XCTAssertFalse(player.isPlaying, "Changing reciter while paused must not start audio")
        XCTAssertNil(player.activeReference, "A replacement recording is not active before playback")
        XCTAssertEqual(player.requestedReference, verse)
        XCTAssertNil(context.engine.currentItem, "A paused reciter change must not prefetch or decode audio")
        player.resume()
        await waitFor(player.$activeReference, matching: { $0 == verse })
        XCTAssertTrue(player.isPlaying)
        XCTAssertEqual(assetURL(context.engine), context.url(for: verse, reciter: .minshawi))

        player.stop()
        XCTAssertNil(player.requestedReference)
        XCTAssertNil(player.activeReference)
        XCTAssertFalse(player.isPlaying)
        XCTAssertFalse(player.isBuffering)
        XCTAssertNil(context.engine.currentItem)

        let restored = RecitationPlayer(player: AVPlayer(),
            audioURL: { _, _ in context.root.appendingPathComponent("unavailable.mp3") },
            defaults: context.defaults, integratesWithSystemAudio: true)
        defer { restored.stop() }
        XCTAssertEqual(restored.selectedReciter, .minshawi)
        XCTAssertFalse(restored.autoplay)
        XCTAssertTrue(context.fallbacks.references.isEmpty)
    }

    func testPracticePlaybackEndsWithoutAdvancingOrChangingAutoplaySetting() async throws {
        let verse = try reference(1)
        let context = try fixture(references: [verse])
        defer { context.player.stop() }
        context.player.playOnce(reference: verse, chapterVerseCount: 7)
        await waitFor(context.player.$activeReference, matching: { $0 == verse })
        XCTAssertTrue(context.player.isPlaying)
        await waitFor(context.player.$isPlaying, matching: { !$0 && context.player.hasFinishedVerse })

        XCTAssertGreaterThan(context.engine.currentTime().seconds, 2.5)
        XCTAssertEqual(context.player.requestedReference, verse)
        XCTAssertEqual(context.player.activeReference, verse)
        XCTAssertTrue(context.player.autoplay, "One-verse practice must not rewrite the reader's preference")
        XCTAssertFalse(context.player.isBuffering)
        XCTAssertNil(context.player.errorMessage)
        XCTAssertTrue(context.fallbacks.references.isEmpty)
    }

    func testAutoplayFollowsActualEndEventsAndStopsAtTheLastVerse() async throws {
        let first = try reference(2, surah: 108)
        let last = try reference(3, surah: 108)
        let context = try fixture(references: [first, last])
        defer { context.player.stop() }
        context.player.play(reference: first, chapterVerseCount: 3)
        await waitFor(context.player.$activeReference, matching: { $0 == first })
        XCTAssertEqual(assetURL(context.engine), context.url(for: first, reciter: .alafasy))
        await waitFor(context.player.$activeReference, matching: { $0 == last })
        XCTAssertEqual(context.player.requestedReference, last)
        XCTAssertEqual(assetURL(context.engine), context.url(for: last, reciter: .alafasy))
        XCTAssertTrue(context.player.isPlaying)
        await waitFor(context.player.$isPlaying, matching: { !$0 && context.player.hasFinishedVerse })
        XCTAssertEqual(context.player.requestedReference, last)
        XCTAssertEqual(context.player.activeReference, last)
        XCTAssertGreaterThan(context.engine.currentTime().seconds, 2.5)
        XCTAssertNil(context.player.errorMessage)
        XCTAssertTrue(context.fallbacks.references.isEmpty)
    }

    func testInterruptionAndHeadphoneRemovalNotificationsPauseTheCurrentVerse() async throws {
        let verse = try reference(1)
        let context = try fixture(references: [verse])
        defer { context.player.stop() }
        context.player.playOnce(reference: verse, chapterVerseCount: 7)
        await waitFor(context.player.$activeReference, matching: { $0 == verse })
        let session = AVAudioSession.sharedInstance()
        NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: session,
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue])
        await waitForNativePause(context)
        XCTAssertEqual(context.player.activeReference, verse)
        XCTAssertEqual(context.engine.rate, 0)

        context.player.resume()
        await waitFor(context.player.$isPlaying, matching: { $0 })
        NotificationCenter.default.post(name: AVAudioSession.routeChangeNotification, object: session,
            userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue])
        await waitForNativePause(context)
        XCTAssertEqual(context.player.requestedReference, verse)
        XCTAssertEqual(context.player.activeReference, verse)
        XCTAssertEqual(context.engine.rate, 0)
        XCTAssertNil(context.player.errorMessage)
        XCTAssertTrue(context.fallbacks.references.isEmpty)
    }

    func testQueuedOldItemEndCannotAdvanceTheNewSurah() async throws {
        let oldVerse = try reference(1)
        let newVerse = try reference(1, surah: 112)
        let context = try fixture(references: [oldVerse, newVerse])
        defer { context.player.stop() }
        context.player.play(reference: oldVerse, chapterVerseCount: 7)
        await waitFor(context.player.$activeReference, matching: { $0 == oldVerse })
        let oldItem = try XCTUnwrap(context.engine.currentItem)

        // Queue the old item's actor callback, then replace the selection before it runs.
        NotificationCenter.default.post(name: AVPlayerItem.didPlayToEndTimeNotification, object: oldItem)
        context.player.play(reference: newVerse, chapterVerseCount: 4)
        await waitFor(context.player.$activeReference, matching: { $0 == newVerse })

        XCTAssertEqual(context.player.requestedReference, newVerse)
        XCTAssertTrue(context.player.isPlaying)
        XCTAssertEqual(assetURL(context.engine), context.url(for: newVerse, reciter: .alafasy))
        XCTAssertNil(context.player.errorMessage)
        XCTAssertTrue(context.fallbacks.references.isEmpty)
    }

    func testUnreadableFileReportsFailureWithoutHighlightingAVerse() async throws {
        let verse = try reference(1)
        let context = try fixture(references: [], allowFallback: true)
        defer { context.player.stop() }
        context.player.play(reference: verse, chapterVerseCount: 7)
        await waitFor(context.player.$errorMessage, matching: { $0 != nil })

        XCTAssertEqual(context.fallbacks.references, [verse])
        XCTAssertTrue(try XCTUnwrap(assetURL(context.engine)).isFileURL)
        XCTAssertEqual(context.player.requestedReference, verse)
        XCTAssertNil(context.player.activeReference)
        XCTAssertFalse(context.player.isPlaying)
        XCTAssertFalse(context.player.isBuffering)
    }

    private func waitForNativePause(_ context: Fixture) async {
        // isPlaying can also become false while buffering. Observe the native
        // engine instead of assuming that a published UI flag settles its rate.
        let paused = expectation(description: "AVPlayer acknowledges the pause before the tone ends")
        let token = context.engine.publisher(for: \.rate, options: [.initial, .new])
            .first(where: { $0 == 0 }).sink { _ in paused.fulfill() }
        defer { token.cancel() }
        await fulfillment(of: [paused], timeout: 2)
        XCTAssertEqual(context.engine.rate, 0)
        XCTAssertFalse(context.player.isPlaying)
        XCTAssertFalse(context.player.hasFinishedVerse, "Natural completion must not satisfy a pause probe")
        XCTAssertLessThan(context.engine.currentTime().seconds, 2.5,
                          "The generated three-second tone must still have audio left after a pause")
    }

    private func waitFor<Value>(_ publisher: Published<Value>.Publisher,
                                matching predicate: @escaping (Value) -> Bool) async {
        let expected = expectation(description: "AVFoundation publishes the expected playback state")
        let token = publisher.first(where: predicate).sink { _ in expected.fulfill() }
        defer { token.cancel() }
        await fulfillment(of: [expected], timeout: 12)
    }

    private func reference(_ number: Int, surah: Int = 1) throws -> AyahReference {
        try XCTUnwrap(AyahReference(surahID: surah, ayahNumber: number))
    }

    private func assetURL(_ player: AVPlayer) -> URL? {
        (player.currentItem?.asset as? AVURLAsset)?.url
    }

    private final class FallbackLog {
        var references: [AyahReference] = []
    }

    private struct Fixture {
        let root: URL
        let library: AudioLibrary
        let defaults: UserDefaults
        let engine: AVPlayer
        let player: RecitationPlayer
        let fallbacks: FallbackLog

        func url(for reference: AyahReference, reciter: Reciter) -> URL {
            root.appendingPathComponent(reciter.rawValue, isDirectory: true)
                .appendingPathComponent(String(format: "%03d", reference.surahID), isDirectory: true)
                .appendingPathComponent(String(format: "%03d%03d.mp3", reference.surahID, reference.ayahNumber))
        }
    }

    private func fixture(references: [AyahReference], allowFallback: Bool = false) throws -> Fixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("sakina.playback-tests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let suite = "sakina.playback-tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let library = AudioLibrary(directory: root)
        let engine = AVPlayer()
        let fallbacks = FallbackLog()
        let player = RecitationPlayer(player: engine,
            audioURL: { reference, reciter in
                if let local = library.localURL(for: reference, reciter: reciter) { return local }
                fallbacks.references.append(reference)
                if !allowFallback { XCTFail("Saved playback unexpectedly requested a streaming fallback") }
                // Even a regression cannot contact an external service in these tests.
                return root.appendingPathComponent("unavailable.mp3")
            }, defaults: defaults, integratesWithSystemAudio: true)
        let context = Fixture(root: root, library: library, defaults: defaults, engine: engine,
                              player: player, fallbacks: fallbacks)
        let data = try XCTUnwrap(GeneratedMP3Fixture.data)
        for reference in references {
            for reciter in Reciter.allCases {
                let url = context.url(for: reference, reciter: reciter)
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: url)
                XCTAssertEqual(library.localURL(for: reference, reciter: reciter), url)
            }
        }
        return context
    }

}

/// Shared generated bytes for native playback and loopback transport probes.
enum GeneratedMP3Fixture {
    static var data: Data? { Data(base64Encoded: generatedTone, options: .ignoreUnknownCharacters) }

    // Generated 3-second, quiet 440 Hz tone; no voice or religious content.
    // ffmpeg -f lavfi -i sine=frequency=440:sample_rate=44100:duration=3
    //   -af volume=0.01 -ac 1 -codec:a libmp3lame -b:a 32k -map_metadata -1
    //   -fflags +bitexact -flags:a +bitexact -write_xing 0 -id3v2_version 0 tone.mp3
    // SHA256: 5beda8e24777a461f509e158fdeb766e3ede4b19d888535f433a17e684f00800
    private static let generatedTone = """
        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
        VVVV//sQxOaDxWwe5A37QkCGA50Bn2RNVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV
        VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVX/+xLE6YPFyCLcDf9iQLID28G/bEhVVVVVVVVVVVVVVVVVVVVVVVVVVVVV
        VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVX/+xDE5gPFCB7kDftC
        QKKEHAGvaEhVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV
        VVVVVVVVVVVVVVVVVVVVVf/7EsTnA8hIQQZMbSMAkoZgAYeY0VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV
        VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVQ==
        """
}
