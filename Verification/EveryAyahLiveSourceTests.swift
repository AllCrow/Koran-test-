import AVFoundation
import Combine
import CryptoKit
import Foundation
import QuranCore
import QuranData
import UIKit
import XCTest
@testable import Sakina

/// Opt-in external-source audit, staged into a temporary CI checkout only.
/// Public reciter audio, no microphone/model/user recording, no audio attachments.
/// Not part of AppTests or the regular deterministic test matrix.
@MainActor
final class EveryAyahLiveSourceTests: XCTestCase {
    private let sourceCommit = "__SOURCE_COMMIT__"
    private let sourceManifestSHA256 = "__MANIFEST_SHA256__"
    private let sourceCodeSHA256 = "__CODE_SHA256_JSON__"
    private let expected: [Reciter: (sha256: String, bytes: Int)] = [
        .alafasy: ("__ALAFASY_SHA256__", __ALAFASY_BYTES__),
        .husary: ("__HUSARY_SHA256__", __HUSARY_BYTES__),
        .minshawi: ("__MINSHAWI_SHA256__", __MINSHAWI_BYTES__)
    ]

    func testAlafasyRealDownloadOfflineDecodeAndPlayback() async throws { try await verify(.alafasy) }
    func testHusaryRealDownloadOfflineDecodeAndPlayback() async throws { try await verify(.husary) }
    func testMinshawiRealDownloadOfflineDecodeAndPlayback() async throws { try await verify(.minshawi) }

    private enum AuditError: LocalizedError {
        case failed(String)
        var errorDescription: String? {
            switch self { case let .failed(message): return message }
        }
    }

    private func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw AuditError.failed(message) }
    }

    private func verify(_ reciter: Reciter) async throws {
        let reference = try XCTUnwrap(AyahReference(surahID: 112, ayahNumber: 2))
        let expectedFile = try XCTUnwrap(expected[reciter])
        var proof: [String: Any] = [
            "schema_version": 1, "status": "failed", "source_commit": sourceCommit,
            "ios_version": UIDevice.current.systemVersion, "device_kind": UIDevice.current.model,
            "source_manifest_sha256": sourceManifestSHA256, "source_code_sha256_json": sourceCodeSHA256,
            "app_reciter": reciter.rawValue, "app_directory": reciter.directoryName,
            "selected_reference": "112:2", "selected_source_url": reciter.audioURL(for: reference).absoluteString,
            "expected_mp3_sha256": expectedFile.sha256, "expected_mp3_bytes": expectedFile.bytes,
            "scope": "Real default AudioLibrary HTTPS download, fresh local lookup, native PCM decode and muted AVPlayer EOF on simulator",
            "physical_iphone_tested": false, "microphone_used": false, "model_invoked": false,
            "human_content_adjudication": false, "rights_cleared": false
        ]
        defer {
            if let data = try? JSONSerialization.data(withJSONObject: proof, options: [.prettyPrinted, .sortedKeys]) {
                let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                attachment.name = "Sakina-real-source-proof-\(reciter.rawValue)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
        do {
            try require(Bundle.main.object(forInfoDictionaryKey: "SAKINA_ENABLE_EXPERIMENTAL_ANALYSIS") as? Bool == false
                        && Bundle.main.object(forInfoDictionaryKey: "SAKINA_ANALYSIS_URL") as? String == "",
                        "The opt-in source audit requires the normal disabled-analysis app")
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("sakina-live-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: root) }
            let chapter = try await QuranRepository().loadChapter(id: 112)
            // No transport seam or response rewriting: the app's default native
            // downloader contacts the actual configured HTTPS addresses.
            let library = AudioLibrary(directory: root)
            defer { library.cancelDownload() }
            let completed = expectation(description: "Real public sura download completes")
            var downloadSettled = false
            let downloadToken = library.$downloadingSurahID.dropFirst().filter { $0 == nil }
                .receive(on: DispatchQueue.main).first().sink { _ in
                    downloadSettled = true
                    completed.fulfill()
                }
            defer { downloadToken.cancel() }
            let started = ProcessInfo.processInfo.systemUptime
            library.beginDownload(chapter.surah, reciter: reciter)
            await fulfillment(of: [completed], timeout: 120)
            proof["download_seconds"] = ProcessInfo.processInfo.systemUptime - started
            proof["download_error"] = library.errorMessage ?? ""
            try require(downloadSettled, "Real download did not settle within its budget")
            try require(library.errorMessage == nil && library.completed == 4 && library.total == 4,
                        "Native download failed or did not retain all four source verses: \(library.errorMessage ?? "incomplete")")

            // Reopen the disk inventory through a new library instance. Its
            // download seam refuses transport, so this phase cannot redownload.
            var unexpectedDownloads = 0
            let reopened = AudioLibrary(directory: root, download: { _, _ in
                unexpectedDownloads += 1
                throw URLError(.notConnectedToInternet)
            })
            try require(reopened.downloadedVerseCount(surahID: 112, reciter: reciter) == 4,
                        "Fresh native inventory did not validate four cached files")
            var decoded: [[String: Any]] = []
            for number in 1...4 {
                let current = try XCTUnwrap(AyahReference(surahID: 112, ayahNumber: number))
                let url = try XCTUnwrap(reopened.localURL(for: current, reciter: reciter))
                let raw = try Data(contentsOf: url)
                let digest = SHA256.hash(data: raw).map { String(format: "%02x", $0) }.joined()
                if current == reference {
                    try require(raw.count == expectedFile.bytes && digest == expectedFile.sha256,
                                "Native source bytes differ from the pinned whole-file audit")
                    proof["actual_mp3_sha256"] = digest
                    proof["actual_mp3_bytes"] = raw.count
                }
                let audio = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
                let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: audio.processingFormat, frameCapacity: 4096))
                var frames: AVAudioFramePosition = 0
                var peak: Float = 0
                while audio.framePosition < audio.length {
                    try audio.read(into: buffer)
                    try require(buffer.frameLength > 0, "Native decoder stopped before EOF")
                    frames += AVAudioFramePosition(buffer.frameLength)
                    let channels = try XCTUnwrap(buffer.floatChannelData)
                    for channel in 0..<Int(buffer.format.channelCount) {
                        for offset in 0..<Int(buffer.frameLength) { peak = max(peak, abs(channels[channel][offset])) }
                    }
                }
                try require(frames > 0 && frames == audio.length && peak > 0 && peak.isFinite,
                            "Whole native PCM decode was empty, incomplete or digital silence")
                decoded.append(["reference": "112:\(number)", "source_url": reciter.audioURL(for: current).absoluteString,
                                "mp3_bytes": raw.count, "mp3_sha256": digest, "decoded_pcm_frames": frames,
                                "sample_rate": audio.processingFormat.sampleRate,
                                "channels": audio.processingFormat.channelCount, "nonzero_peak": peak])
            }
            proof["native_decoded_files"] = decoded

            let suite = "sakina.live-audit.\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let engine = AVPlayer()
            engine.isMuted = true
            var selections: [String] = []
            var fallbackAttempts = 0
            // The same AudioLibrary localURL selection used by the production
            // convenience initializer, with an inspectable real native engine.
            let player = RecitationPlayer(player: engine, audioURL: { verse, selectedReciter in
                selections.append("\(selectedReciter.rawValue)/\(verse.surahID):\(verse.ayahNumber)")
                if let local = reopened.localURL(for: verse, reciter: selectedReciter) { return local }
                fallbackAttempts += 1
                return root.appendingPathComponent("missing-local-source.mp3")
            }, defaults: defaults, integratesWithSystemAudio: true)
            defer { player.stop() }
            player.selectReciter(reciter)
            let playing = expectation(description: "Real downloaded MP3 has positive native rate and playing status")
            var observedNativePlayback = false
            let playToken = engine.publisher(for: \.rate, options: [.new])
                .merge(with: engine.publisher(for: \.timeControlStatus, options: [.new]).map { _ in engine.rate })
                .receive(on: DispatchQueue.main)
                .first(where: { _ in engine.rate > 0 && engine.timeControlStatus == .playing })
                .sink { _ in observedNativePlayback = true; playing.fulfill() }
            defer { playToken.cancel() }
            let ended = expectation(description: "Real downloaded MP3 reaches native EOF")
            var observedNativeEnd = false
            let endToken = NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification)
                .receive(on: DispatchQueue.main)
                .filter { notification in
                    guard let endedItem = notification.object as? AVPlayerItem else { return false }
                    return endedItem === engine.currentItem
                }.first()
                .sink { _ in observedNativeEnd = true; ended.fulfill() }
            defer { endToken.cancel() }
            let controllerEnded = expectation(description: "The app completes the same selected verse")
            let stateToken = player.$isPlaying.filter { !$0 && player.hasFinishedVerse }.first()
                .sink { _ in controllerEnded.fulfill() }
            defer { stateToken.cancel() }
            player.playOnce(reference: reference, chapterVerseCount: 4)
            let item = try XCTUnwrap(engine.currentItem)
            let local = try XCTUnwrap(reopened.localURL(for: reference, reciter: reciter))
            try require((item.asset as? AVURLAsset)?.url == local && local.isFileURL,
                        "AVPlayer did not select the exact validated local source")
            await fulfillment(of: [playing], timeout: 12)
            await fulfillment(of: [ended, controllerEnded], timeout: 20)
            try require(observedNativePlayback && observedNativeEnd && player.hasFinishedVerse,
                        "Actual native playback/EOF was not established")
            try require(player.activeReference == reference && player.requestedReference == reference,
                        "Text reference did not remain attached to the played verse")
            try require(engine.currentItem === item && engine.rate == 0 && player.errorMessage == nil,
                        "Native completion did not preserve the same paused item")
            try require(unexpectedDownloads == 0 && fallbackAttempts == 0
                        && selections == ["\(reciter.rawValue)/112:2"], "Offline playback attempted another source")
            proof["actual_native_playback_observed"] = observedNativePlayback
            proof["actual_native_end_observed"] = observedNativeEnd
            proof["same_native_item_at_end"] = true
            proof["selected_native_asset_is_local_file"] = true
            proof["audio_source_selections"] = selections
            proof["unexpected_offline_downloads"] = unexpectedDownloads
            proof["fallback_attempts"] = fallbackAttempts
            proof["status"] = "passed"
        } catch {
            proof["failure"] = error.localizedDescription
            throw error
        }
    }
}
