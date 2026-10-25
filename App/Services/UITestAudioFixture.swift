#if DEBUG
import AVFoundation
import Foundation
import QuranCore

/// Only an explicitly named UI-test suite can reach these synthetic local files.
/// Release builds contain neither this type nor a fallback to a test source.
@MainActor
enum UITestAudioFixture {
    static func makeLibrary(suite: String) -> AudioLibrary {
        let root = checkedRoot(suite: suite)
        let recitations = root.appendingPathComponent("Recitations", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: recitations, withIntermediateDirectories: true)
            if ProcessInfo.processInfo.arguments.contains("--ui-test-audio-fixture") {
                try seedInventoryIfNeeded(at: root, recitations: recitations)
            }
        } catch {
            preconditionFailure("The isolated UI-test audio fixture could not be prepared.")
        }
        return AudioLibrary(directory: recitations, download: { _, _ in
            // Accidental download actions must fail locally, never contact an imam service.
            throw URLError(.notConnectedToInternet)
        })
    }

    static func makePlayer(library: AudioLibrary, defaults: UserDefaults, suite: String) -> RecitationPlayer {
        let root = checkedRoot(suite: suite)
        let wave = root.appendingPathComponent("ui-playback.wav", isDirectory: false)
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: wave.path) {
                try quietWave().write(to: wave, options: .atomic)
            }
        } catch {
            preconditionFailure("The isolated UI-test playback fixture could not be prepared.")
        }
        // These UI flows exercise actual controls and the native player. Real
        // MP3 admission, decoding and loop EOF behavior have separate native tests.
        // Every reference resolves to this local WAV, including an unsaved verse.
        _ = library
        let native = AVPlayer()
        native.isMuted = true
        return RecitationPlayer(player: native, audioURL: { _, _ in wave },
                                defaults: defaults, integratesWithSystemAudio: false,
                                makeReplacementPlayer: {
                                    let replacement = AVPlayer()
                                    replacement.isMuted = true
                                    return replacement
                                }, makePlayerItem: { _, _ in
                                    // Pinned offline-source routes also use the
                                    // same playable local fixture. Inventory's
                                    // tiny structural MP3s are not sound proof.
                                    AVPlayerItem(url: wave)
                                })
    }

    private static func checkedRoot(suite: String) -> URL {
        let arguments = ProcessInfo.processInfo.arguments
        guard suite.hasPrefix("sakina.uitests."), suite.utf8.count <= 120,
              suite.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0)
                  || (97...122).contains($0) || $0 == 45 || $0 == 46 }),
              let index = arguments.firstIndex(of: "--ui-test-suite"),
              arguments.indices.contains(index + 1), arguments[index + 1] == suite else {
            preconditionFailure("Synthetic UI audio requires an explicit isolated test suite.")
        }
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("SakinaUITests", isDirectory: true)
            .appendingPathComponent(suite, isDirectory: true)
    }

    private static func seedInventoryIfNeeded(at root: URL, recitations: URL) throws {
        let marker = root.appendingPathComponent(".inventory-seeded-v1")
        guard !FileManager.default.fileExists(atPath: marker.path) else { return }
        let selections: [(Reciter, Int, Int)] = [(.alafasy, 1, 1), (.alafasy, 1, 2), (.husary, 112, 1)]
        var frame = Data(repeating: 0, count: 417)
        frame.replaceSubrange(0..<4, with: [0xFF, 0xFB, 0x90, 0x64])
        let structuralMP3 = frame + frame
        for (reciter, surah, verse) in selections {
            let folder = recitations.appendingPathComponent(reciter.rawValue, isDirectory: true)
                .appendingPathComponent(String(format: "%03d", surah), isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let file = folder.appendingPathComponent(String(format: "%03d%03d.mp3", surah, verse))
            if !FileManager.default.fileExists(atPath: file.path) {
                try structuralMP3.write(to: file, options: .atomic)
            }
        }
        // A real relaunch must retain a user's deletion instead of reseeding it.
        try Data("synthetic-inventory-v1".utf8).write(to: marker, options: .atomic)
    }

    private static func quietWave() -> Data {
        let sampleRate = 8_000
        let frames = sampleRate * 8
        let pcmBytes = frames * 2
        var data = Data()
        data.reserveCapacity(44 + pcmBytes)
        data.append(contentsOf: "RIFF".utf8)
        append(UInt32(36 + pcmBytes), to: &data)
        data.append(contentsOf: "WAVEfmt ".utf8)
        append(UInt32(16), to: &data)
        append(UInt16(1), to: &data) // Linear PCM.
        append(UInt16(1), to: &data) // Mono.
        append(UInt32(sampleRate), to: &data)
        append(UInt32(sampleRate * 2), to: &data)
        append(UInt16(2), to: &data)
        append(UInt16(16), to: &data)
        data.append(contentsOf: "data".utf8)
        append(UInt32(pcmBytes), to: &data)
        for frame in 0..<frames {
            // Quiet synthetic square wave, never a voice or external recording.
            append(UInt16(bitPattern: Int16((frame / 32).isMultiple(of: 2) ? 8 : -8)), to: &data)
        }
        return data
    }

    private static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }
}
#endif
