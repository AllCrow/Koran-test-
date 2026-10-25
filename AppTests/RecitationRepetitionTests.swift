import AVFoundation
import Combine
import Foundation
import QuranCore
import XCTest
@testable import Sakina

/// Native end events from generated local PCM drive every repetition test.
/// The remote-policy case substitutes only item construction, preventing an
/// external request while still exercising the real engine and policy handoff.
@MainActor
final class RecitationRepetitionTests: XCTestCase {
    func testNativeEOFRepeatsOnlyTheIntervalAndStopsAtTheDeclaredCycleCount() async throws {
        let audio = try wave(seconds: 0.35)
        var requests: [AyahReference] = []
        let rig = try makePlayer { reference, _ in requests.append(reference); return audio }
        defer { rig.service.stop() }
        rig.service.autoplay = false
        let configuration = try loop(first: 2, last: 3, cycles: 2)
        let finished = expectation(description: "The second interval completes through native EOF")
        let token = rig.service.$repetitionComplete.first(where: { $0 }).sink { _ in finished.fulfill() }
        defer { token.cancel() }

        rig.service.playRepeatedly(configuration)
        await fulfillment(of: [finished], timeout: 12)

        XCTAssertEqual(requests, try [2, 3, 2, 3].map(reference))
        XCTAssertEqual(rig.service.repetition, configuration)
        XCTAssertEqual(rig.service.repetitionCycle, 2)
        XCTAssertEqual(rig.service.requestedReference, try reference(3))
        XCTAssertEqual(rig.service.activeReference, try reference(3))
        XCTAssertTrue(rig.service.hasFinishedVerse)
        XCTAssertFalse(rig.service.isPlaying)
        XCTAssertFalse(rig.service.isBuffering)
        XCTAssertFalse(rig.service.isWaitingBetweenVerses)
        XCTAssertFalse(rig.service.autoplay, "Repetition must not rewrite the normal autoplay preference")
        XCTAssertGreaterThan(rig.engine.currentTime().seconds, 0.25)
        XCTAssertNil(rig.service.errorMessage)
    }

    func testExplicitPlayAfterCompletionRestartsTheWholeIntervalAtCycleOne() async throws {
        let short = try wave(seconds: 0.35)
        let long = try wave(seconds: 8)
        var requests: [AyahReference] = []
        let rig = try makePlayer { verse, _ in
            requests.append(verse)
            return requests.count <= 2 ? short : long
        }
        defer { rig.service.stop() }
        let finished = expectation(description: "One finite two-verse interval finishes")
        let finishToken = rig.service.$repetitionComplete.first(where: { $0 }).sink { _ in finished.fulfill() }
        defer { finishToken.cancel() }
        rig.service.playRepeatedly(try loop(first: 2, last: 3, cycles: 1))
        await fulfillment(of: [finished], timeout: 12)
        XCTAssertEqual(requests, try [2, 3].map(reference))

        let first = try reference(2)
        let began = expectation(description: "An explicit replay begins the first verse again")
        let token = rig.service.$activeReference.first(where: { $0 == first })
            .sink { _ in began.fulfill() }
        defer { token.cancel() }
        rig.service.resume()
        await fulfillment(of: [began], timeout: 12)

        XCTAssertEqual(requests, try [2, 3, 2].map(reference))
        XCTAssertEqual(rig.service.repetitionCycle, 1)
        XCTAssertFalse(rig.service.repetitionComplete)
        XCTAssertGreaterThan(rig.engine.rate, 0)
        XCTAssertEqual(rig.engine.timeControlStatus, .playing)
    }

    func testDefaultPauseWaitsAfterRealEOFBeforeStartingTheNextRecording() async throws {
        let audio = try wave(seconds: 0.35)
        var requestedAt: [TimeInterval] = []
        var firstEndedAt: TimeInterval?
        let rig = try makePlayer { _, _ in
            requestedAt.append(ProcessInfo.processInfo.systemUptime)
            return audio
        }
        defer { rig.service.stop() }
        let finished = expectation(description: "The real one-second gap and second EOF finish")
        let finishToken = rig.service.$repetitionComplete.first(where: { $0 }).sink { _ in finished.fulfill() }
        defer { finishToken.cancel() }
        let endToken = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification, object: nil, queue: .main
        ) { notification in
            MainActor.assumeIsolated {
                guard firstEndedAt == nil, let item = notification.object as? AVPlayerItem,
                      rig.engine.currentItem === item else { return }
                firstEndedAt = ProcessInfo.processInfo.systemUptime
            }
        }
        defer { NotificationCenter.default.removeObserver(endToken) }
        rig.service.playRepeatedly(try loop(first: 2, last: 3, cycles: 1, pause: 1))
        await fulfillment(of: [finished], timeout: 12)

        XCTAssertEqual(requestedAt.count, 2)
        let secondRequestedAt = try XCTUnwrap(requestedAt.dropFirst().first)
        XCTAssertGreaterThanOrEqual(secondRequestedAt - (try XCTUnwrap(firstEndedAt)), 0.8,
                                    "The gap starts at native EOF, not an estimated verse duration")
    }

    func testPauseDuringGapCancelsOldWaitAndExplicitResumeUsesThePendingVerse() async throws {
        let gate = RepetitionDelayGate()
        let arrived = expectation(description: "The first real EOF reaches its controlled gap")
        let returned = expectation(description: "The old noncooperative wait returns after resume")
        gate.onWait = { arrived.fulfill() }
        gate.onReturn = { returned.fulfill() }
        let short = try wave(seconds: 0.35)
        let long = try wave(seconds: 8)
        var requests: [AyahReference] = []
        let rig = try makePlayer(wait: { try await gate.wait($0) }) { verse, _ in
            requests.append(verse)
            return verse.ayahNumber == 2 ? short : long
        }
        defer { rig.service.stop(); gate.release() }
        rig.service.playRepeatedly(try loop(first: 2, last: 3, cycles: 2, pause: 3))
        await fulfillment(of: [arrived], timeout: 12)
        let endedItem = try XCTUnwrap(rig.engine.currentItem)
        XCTAssertEqual(gate.seconds, [3])
        XCTAssertTrue(rig.service.isWaitingBetweenVerses)
        XCTAssertEqual(requests, [try reference(2)])

        rig.service.pause()
        XCTAssertFalse(rig.service.isWaitingBetweenVerses)
        XCTAssertEqual(rig.engine.rate, 0)
        let next = try reference(3)
        let began = expectation(description: "Explicit play starts the exact pending next verse")
        let token = rig.service.$activeReference.first(where: { $0 == next }).sink { _ in began.fulfill() }
        defer { token.cancel() }
        NotificationCenter.default.post(name: AVPlayerItem.didPlayToEndTimeNotification, object: endedItem)
        NotificationCenter.default.post(name: AVPlayerItem.failedToPlayToEndTimeNotification, object: endedItem)
        rig.service.resume()
        await fulfillment(of: [began], timeout: 12)
        gate.release()
        await fulfillment(of: [returned], timeout: 2)

        XCTAssertEqual(requests, try [2, 3].map(reference))
        XCTAssertEqual(rig.service.requestedReference, next)
        XCTAssertEqual(rig.service.repetitionCycle, 1)
        XCTAssertFalse(rig.service.isWaitingBetweenVerses)
        XCTAssertGreaterThan(rig.engine.rate, 0)
        XCTAssertNil(rig.service.errorMessage)
    }

    func testStopAndNewPracticePlayDiscardTheOldGapAndStaleEvents() async throws {
        let gate = RepetitionDelayGate()
        let arrived = expectation(description: "Old loop reaches a gap after real EOF")
        let returned = expectation(description: "Cancelled old wait still returns its continuation")
        gate.onWait = { arrived.fulfill() }
        gate.onReturn = { returned.fulfill() }
        let short = try wave(seconds: 0.35)
        let long = try wave(seconds: 8)
        var requests: [AyahReference] = []
        let rig = try makePlayer(wait: { try await gate.wait($0) }) { verse, _ in
            requests.append(verse)
            return verse.ayahNumber == 2 ? short : long
        }
        defer { rig.service.stop(); gate.release() }
        rig.service.playRepeatedly(try loop(first: 2, last: 3, cycles: 2, pause: 3))
        await fulfillment(of: [arrived], timeout: 12)
        let ended = try XCTUnwrap(rig.engine.currentItem)
        rig.service.stop()
        let target = try reference(5)
        let began = expectation(description: "A new single practice verse actually starts")
        let token = rig.service.$activeReference.first(where: { $0 == target }).sink { _ in began.fulfill() }
        defer { token.cancel() }
        NotificationCenter.default.post(name: AVPlayerItem.didPlayToEndTimeNotification, object: ended)
        NotificationCenter.default.post(name: AVPlayerItem.failedToPlayToEndTimeNotification, object: ended)
        rig.service.playOnce(reference: target, chapterVerseCount: 7)
        await fulfillment(of: [began], timeout: 12)
        gate.release()
        await fulfillment(of: [returned], timeout: 2)

        XCTAssertEqual(requests, try [2, 5].map(reference))
        XCTAssertNil(rig.service.repetition)
        XCTAssertEqual(rig.service.repetitionCycle, 0)
        XCTAssertFalse(rig.service.isWaitingBetweenVerses)
        XCTAssertEqual(rig.service.requestedReference, target)
        XCTAssertGreaterThan(rig.engine.rate, 0)
        XCTAssertNil(rig.service.errorMessage)
    }

    func testReciterChangeDuringGapSelectsPendingVerseWithoutFetchingUntilPlay() async throws {
        let gate = RepetitionDelayGate()
        let arrived = expectation(description: "The initial reciter finishes the first verse")
        let returned = expectation(description: "Its old gap returns after the reciter changes")
        gate.onWait = { arrived.fulfill() }
        gate.onReturn = { returned.fulfill() }
        let short = try wave(seconds: 0.35)
        let long = try wave(seconds: 8)
        var requests: [(AyahReference, Reciter)] = []
        let rig = try makePlayer(wait: { try await gate.wait($0) }) { verse, reciter in
            requests.append((verse, reciter))
            return verse.ayahNumber == 2 ? short : long
        }
        defer { rig.service.stop(); gate.release() }
        rig.service.playRepeatedly(try loop(first: 2, last: 3, cycles: 2, pause: 3))
        await fulfillment(of: [arrived], timeout: 12)
        rig.service.selectReciter(.husary)
        XCTAssertEqual(rig.service.requestedReference, try reference(3))
        XCTAssertNil(rig.engine.currentItem)
        XCTAssertEqual(requests.count, 1)
        XCTAssertFalse(rig.service.isWaitingBetweenVerses)
        gate.release()
        await fulfillment(of: [returned], timeout: 2)
        XCTAssertEqual(requests.count, 1, "The old reciter's delay cannot fetch a new recording")

        let target = try reference(3)
        let began = expectation(description: "The explicit action plays the selected new reciter")
        let token = rig.service.$activeReference.first(where: { $0 == target }).sink { _ in began.fulfill() }
        defer { token.cancel() }
        rig.service.resume()
        await fulfillment(of: [began], timeout: 12)
        XCTAssertEqual(requests.map(\.0), try [2, 3].map(reference))
        XCTAssertEqual(requests.map(\.1), [.alafasy, .husary])
        XCTAssertEqual(rig.service.repetitionCycle, 1)
        XCTAssertNil(rig.service.errorMessage)
    }

    func testMediaLossAndResetDuringGapRequireExplicitPlayOfPendingVerse() async throws {
        let gate = RepetitionDelayGate()
        let arrived = expectation(description: "The original engine reaches its first gap")
        let returned = expectation(description: "Old service's wait returns after reset")
        gate.onWait = { arrived.fulfill() }
        gate.onReturn = { returned.fulfill() }
        let short = try wave(seconds: 0.35)
        let long = try wave(seconds: 8)
        let original = AVPlayer()
        let replacement = AVPlayer()
        original.isMuted = true
        replacement.isMuted = true
        var requests: [AyahReference] = []
        let service = RecitationPlayer(
            player: original, audioURL: { verse, _ in requests.append(verse); return verse.ayahNumber == 2 ? short : long },
            defaults: try defaults(), integratesWithSystemAudio: false,
            makeReplacementPlayer: { replacement }, waitBetweenVerses: { try await gate.wait($0) }
        )
        defer { service.stop(); gate.release() }
        service.playRepeatedly(try loop(first: 2, last: 3, cycles: 2, pause: 3))
        await fulfillment(of: [arrived], timeout: 12)
        NotificationCenter.default.post(name: AVAudioSession.mediaServicesWereLostNotification,
                                        object: AVAudioSession.sharedInstance())
        service.resume()
        XCTAssertEqual(requests, [try reference(2)])
        XCTAssertNil(original.currentItem)
        NotificationCenter.default.post(name: AVAudioSession.mediaServicesWereResetNotification,
                                        object: AVAudioSession.sharedInstance())
        gate.release()
        await fulfillment(of: [returned], timeout: 2)
        XCTAssertNil(replacement.currentItem, "Service reset and stale delay must not resume audio")
        XCTAssertEqual(requests, [try reference(2)])

        let target = try reference(3)
        let began = expectation(description: "Explicit resume uses the exact next verse on the replacement engine")
        let token = service.$activeReference.first(where: { $0 == target }).sink { _ in began.fulfill() }
        defer { token.cancel() }
        service.resume()
        await fulfillment(of: [began], timeout: 12)
        XCTAssertEqual(requests, try [2, 3].map(reference))
        XCTAssertEqual(service.repetitionCycle, 1)
        XCTAssertGreaterThan(replacement.rate, 0)
        XCTAssertNil(service.errorMessage)
    }

    func testManualNextAndPreviousStayWithinTheRepetitionInterval() throws {
        let audio = try wave(seconds: 8)
        var requests: [AyahReference] = []
        let rig = try makePlayer { verse, _ in requests.append(verse); return audio }
        defer { rig.service.stop() }
        let configuration = try loop(first: 2, last: 3, cycles: 2)
        rig.service.playRepeatedly(configuration)
        rig.service.previous()
        rig.service.next()
        rig.service.next()
        rig.service.previous()
        rig.service.previous()

        XCTAssertEqual(requests, try [2, 3, 2].map(reference))
        XCTAssertEqual(rig.service.repetition, configuration)
        XCTAssertEqual(rig.service.repetitionCycle, 1)
        XCTAssertFalse(rig.service.repetitionComplete)
    }

    func testChangedNetworkPolicyDetachesRemoteSourceAndPassesNewRuleOnExplicitResume() async throws {
        let localAudio = try wave(seconds: 8)
        let remote = try XCTUnwrap(URL(string: "https://example.invalid/recitation.mp3"))
        let engine = AVPlayer()
        engine.isMuted = true
        var options: [Bool] = []
        let service = RecitationPlayer(
            player: engine, audioURL: { _, _ in remote }, defaults: try defaults(), integratesWithSystemAudio: false,
            makePlayerItem: { source, allowsCellular in
                XCTAssertEqual(source, remote)
                options.append(allowsCellular)
                return AVPlayerItem(url: localAudio)
            }
        )
        defer { service.stop() }
        let target = try reference(2)
        let began = expectation(description: "A real local stand-in engine starts for the declared remote request")
        let token = service.$activeReference.first(where: { $0 == target }).sink { _ in began.fulfill() }
        defer { token.cancel() }
        service.playOnce(reference: target, chapterVerseCount: 7)
        await fulfillment(of: [began], timeout: 12)
        XCTAssertGreaterThan(engine.rate, 0)
        service.setAllowsCellularAccess(false)

        XCTAssertEqual(options, [true])
        XCTAssertNil(engine.currentItem)
        XCTAssertEqual(engine.rate, 0)
        XCTAssertEqual(service.requestedReference, target)
        XCTAssertFalse(service.isPlaying)
        XCTAssertFalse(service.isBuffering)
        let resumed = expectation(description: "Only explicit resume constructs the source with cellular disabled")
        let resumeToken = service.$isPlaying.first(where: { $0 }).sink { _ in resumed.fulfill() }
        defer { resumeToken.cancel() }
        service.resume()
        await fulfillment(of: [resumed], timeout: 12)

        XCTAssertEqual(options, [true, false])
        XCTAssertGreaterThan(engine.rate, 0)
        XCTAssertEqual(engine.timeControlStatus, .playing)
        XCTAssertNil(service.errorMessage)
    }

    func testNetworkPolicyChangeDoesNotInterruptAnAlreadyPlayingLocalFile() async throws {
        let audio = try wave(seconds: 8)
        var requests = 0
        let rig = try makePlayer { _, _ in requests += 1; return audio }
        defer { rig.service.stop() }
        let target = try reference(2)
        let began = expectation(description: "The downloaded/local asset actually plays")
        let token = rig.service.$activeReference.first(where: { $0 == target }).sink { _ in began.fulfill() }
        defer { token.cancel() }
        rig.service.playOnce(reference: target, chapterVerseCount: 7)
        await fulfillment(of: [began], timeout: 12)
        let item = try XCTUnwrap(rig.engine.currentItem)
        rig.service.setAllowsCellularAccess(false)

        XCTAssertEqual(requests, 1)
        XCTAssertTrue(rig.engine.currentItem === item)
        XCTAssertGreaterThan(rig.engine.rate, 0)
        XCTAssertEqual(rig.engine.timeControlStatus, .playing)
        XCTAssertTrue(rig.service.isPlaying)
        XCTAssertNil(rig.service.errorMessage)
    }

    func testSavedMP3SessionPinsItsExactFileAndMissingFileRetryNeverFallsBackToProvider() async throws {
        let data = try XCTUnwrap(GeneratedMP3Fixture.data)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("sakina.pinned-mp3.\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let saved = directory.appendingPathComponent("112002.mp3")
        try data.write(to: saved)
        let engine = AVPlayer()
        engine.isMuted = true
        var providerRequests: [AyahReference] = []
        let service = RecitationPlayer(
            player: engine, audioURL: { reference, _ in
                providerRequests.append(reference)
                XCTFail("A pinned saved-audio session must never resolve through the ordinary source provider")
                return directory.appendingPathComponent("forbidden-fallback.mp3")
            }, defaults: try defaults(), integratesWithSystemAudio: true
        )
        defer { service.stop() }
        let target = try XCTUnwrap(AyahReference(surahID: 112, ayahNumber: 2))
        let began = expectation(description: "The default AVURLAsset factory actually plays the saved MP3")
        let beganToken = Publishers.Merge(
            engine.publisher(for: \.rate, options: [.initial, .new]).map { _ in () },
            engine.publisher(for: \.timeControlStatus, options: [.initial, .new]).map { _ in () }
        )
            .receive(on: DispatchQueue.main)
            .first(where: { _ in
                MainActor.assumeIsolated {
                    engine.rate > 0 && engine.timeControlStatus == .playing
                        && (engine.currentItem?.asset as? AVURLAsset)?.url == saved
                }
            })
            .sink { _ in began.fulfill() }
        defer { beganToken.cancel() }
        let savedToken = try XCTUnwrap(service.playSavedOnce(reference: target, chapterVerseCount: 4,
                                                            reciter: .minshawi, localURL: saved))
        await fulfillment(of: [began], timeout: 12)

        XCTAssertGreaterThan(engine.rate, 0)
        XCTAssertEqual(engine.timeControlStatus, .playing)
        XCTAssertEqual((engine.currentItem?.asset as? AVURLAsset)?.url, saved)
        XCTAssertEqual(service.requestedReference, target)
        XCTAssertEqual(service.activeReference, target)
        XCTAssertEqual(service.selectedReciter, .minshawi)
        XCTAssertTrue(providerRequests.isEmpty)
        XCTAssertTrue(service.autoplay, "A single saved verse must not rewrite the user's autoplay preference")
        service.stopSavedSession(UUID())
        XCTAssertGreaterThan(engine.rate, 0, "An unrelated owner must not stop the playing saved session")
        XCTAssertEqual(service.requestedReference, target)
        service.pause()

        // Capture a second valid file, then remove it before constructing its
        // native asset. This models a stored file vanishing after admission,
        // without depending on whether the first asset retains an open handle.
        let vanished = directory.appendingPathComponent("vanished-112002.mp3")
        try data.write(to: vanished)
        XCTAssertEqual(try Data(contentsOf: vanished), data)
        try FileManager.default.removeItem(at: vanished)
        let failed = expectation(description: "A vanished pinned file fails locally")
        let failedToken = service.$errorMessage.compactMap { $0 }.first().sink { _ in failed.fulfill() }
        defer { failedToken.cancel() }
        let vanishedToken = try XCTUnwrap(service.playSavedOnce(reference: target, chapterVerseCount: 4,
                                                               reciter: .minshawi, localURL: vanished))
        XCTAssertNotEqual(vanishedToken, savedToken)
        await fulfillment(of: [failed], timeout: 12)
        let failedItem = try XCTUnwrap(engine.currentItem)
        XCTAssertEqual((failedItem.asset as? AVURLAsset)?.url, vanished)
        XCTAssertTrue(providerRequests.isEmpty)
        XCTAssertTrue(service.errorMessage?.contains("sparade ljudet") == true)
        service.stopSavedSession(savedToken)
        XCTAssertEqual(service.requestedReference, target, "An older route with the same verse and reciter does not own this session")
        XCTAssertTrue(engine.currentItem === failedItem)

        let retryFailed = expectation(description: "Explicit retry attempts the same missing file without streaming")
        let retryToken = service.$errorMessage.dropFirst().compactMap { $0 }.first().sink { _ in retryFailed.fulfill() }
        defer { retryToken.cancel() }
        service.resume()
        await fulfillment(of: [retryFailed], timeout: 12)

        XCTAssertFalse(engine.currentItem === failedItem, "Retry must construct a new native attempt")
        XCTAssertEqual((engine.currentItem?.asset as? AVURLAsset)?.url, vanished)
        XCTAssertEqual(service.requestedReference, target)
        XCTAssertEqual(service.selectedReciter, .minshawi)
        XCTAssertTrue(providerRequests.isEmpty)
        XCTAssertFalse(service.isPlaying)
        XCTAssertFalse(service.isBuffering)
        service.stopSavedSession(vanishedToken)
        XCTAssertNil(service.requestedReference, "The current owner token survives local retry and can stop its session")
        XCTAssertNil(engine.currentItem)
    }

    private func makePlayer(wait: @escaping RecitationPlayer.RepetitionDelay = { try await Task.sleep(for: .seconds($0)) },
                            source: @escaping RecitationPlayer.AudioURLProvider)
        throws -> (service: RecitationPlayer, engine: AVPlayer) {
        let engine = AVPlayer()
        engine.isMuted = true
        return (RecitationPlayer(player: engine, audioURL: source, defaults: try defaults(),
                                 integratesWithSystemAudio: false, waitBetweenVerses: wait), engine)
    }

    private func loop(first: Int, last: Int, cycles: Int, pause: Int = 0) throws -> RecitationLoop {
        try XCTUnwrap(RecitationLoop(surahID: 1, startVerse: first, endVerse: last, cycles: cycles, pauseSeconds: pause))
    }

    private func reference(_ number: Int) throws -> AyahReference {
        try XCTUnwrap(AyahReference(surahID: 1, ayahNumber: number))
    }

    private func defaults() throws -> UserDefaults {
        let name = "sakina.repetition-tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    private func wave(seconds: Double) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("sakina.repetition-tests.\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let count = UInt32(seconds * 16_000) * 2
        var data = Data("RIFF".utf8)
        func append<T: FixedWidthInteger>(_ number: T) {
            var little = number.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        append(UInt32(36) + count)
        data.append(contentsOf: "WAVEfmt ".utf8)
        append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
        append(UInt32(16_000)); append(UInt32(32_000)); append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: "data".utf8)
        append(count)
        data.append(Data(repeating: 0, count: Int(count)))
        let url = directory.appendingPathComponent("silence.wav")
        try data.write(to: url)
        return url
    }
}

/// Deliberately ignores Task cancellation so stale delay ownership is exercised.
@MainActor
private final class RepetitionDelayGate {
    private var continuation: CheckedContinuation<Void, Error>?
    private(set) var seconds: [Int] = []
    var onWait: (() -> Void)?
    var onReturn: (() -> Void)?

    func wait(_ duration: Int) async throws {
        seconds.append(duration)
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            onWait?()
        }
        onReturn?()
    }

    func release() {
        let pending = continuation
        continuation = nil
        pending?.resume()
    }
}
