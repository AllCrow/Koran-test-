import AVFoundation
import Combine
import Foundation
import QuranCore

/// A single local practice take. There is deliberately no upload or AI score.
@MainActor
final class PracticeRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    typealias PermissionRequester = (@escaping @Sendable (Bool) -> Void) -> Void

    @Published private(set) var isRecording = false
    @Published private(set) var isPlaying = false
    @Published private(set) var isRequestingPermission = false
    @Published private(set) var hasRecording = false
    @Published private(set) var recordedReference: AyahReference?
    @Published private(set) var recordedIncludesBasmala = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var permissionDenied = false

    enum RecordingDataError: LocalizedError {
        case missingRecording
        case tooLarge

        var errorDescription: String? {
            switch self {
            case .missingRecording:
                return "Inspelningen kunde inte läsas. Spela in en ny tagning och försök igen."
            case .tooLarge:
                return "Inspelningen är för stor. Spela in en kortare tagning och försök igen."
            }
        }
    }

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var recordingURL: URL?
    private var permissionRequestID = UUID()
    private var permissionTask: Task<Void, Never>?
    private let directory: URL
    private let requestPermission: PermissionRequester
    private let notifications: NotificationCenter
    private var ownedSessionCategory: AVAudioSession.Category?
    private var interruptionToken: NSObjectProtocol?
    private var routeToken: NSObjectProtocol?

    override convenience init() {
        self.init(
            directory: FileManager.default.temporaryDirectory.appendingPathComponent("SakinaPractice", isDirectory: true),
            requestPermission: { completion in AVAudioApplication.requestRecordPermission(completionHandler: completion) }
        )
    }

    /// Storage and the permission callback can be isolated without opening the
    /// microphone. The production initializer always uses the system request.
    init(directory: URL, notifications: NotificationCenter = .default,
         requestPermission: @escaping PermissionRequester) {
        self.directory = directory
        self.notifications = notifications
        self.requestPermission = requestPermission
        super.init()
        // Takes are temporary and cannot be reopened after app restart.
        if prepareDirectory(),
           let files = try? FileManager.default.contentsOfDirectory(
               at: directory, includingPropertiesForKeys: [.isRegularFileKey]
           ) {
            for file in files where file.pathExtension == "m4a" && UUID(uuidString: file.deletingPathExtension().lastPathComponent) != nil {
                guard (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
                try? FileManager.default.removeItem(at: file)
            }
        }
        interruptionToken = notifications.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            if type == AVAudioSession.InterruptionType.began.rawValue {
                MainActor.assumeIsolated { self?.stopAll() }
            }
        }
        routeToken = notifications.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: AVAudioSession.sharedInstance(), queue: .main
        ) { [weak self] notification in
            let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
                // Do not continue a private take through the speaker or switch
                // microphones silently when headphones are disconnected.
                MainActor.assumeIsolated { self?.stopAll() }
            } else if reason == AVAudioSession.RouteChangeReason.categoryChange.rawValue {
                MainActor.assumeIsolated {
                    guard let self, let category = self.ownedSessionCategory,
                          AVAudioSession.sharedInstance().category != category else { return }
                    // Another player has claimed the shared audio session.
                    // Stop our own work without deactivating its new category.
                    self.ownedSessionCategory = nil
                    self.stopAll()
                }
            }
        }
    }

    deinit {
        permissionTask?.cancel()
        if let interruptionToken { notifications.removeObserver(interruptionToken) }
        if let routeToken { notifications.removeObserver(routeToken) }
        recorder?.stop()
        player?.stop()
        if let recordingURL { try? FileManager.default.removeItem(at: recordingURL) }
    }

    /// Reserve the request synchronously with the button action. A subsequent
    /// screen exit can cancel it even before the permission task gets CPU time.
    func beginRecording(reference: AyahReference, includeBasmala: Bool = false) {
        guard !isRecording, !isRequestingPermission else { return }
        guard prepareDirectory() else { return }
        stopPlayback()
        errorMessage = nil
        permissionDenied = false
        let requestID = UUID()
        permissionRequestID = requestID
        isRequestingPermission = true
        permissionTask = Task { [weak self] in
            guard let self else { return }
            await self.requestPermissionAndStart(reference: reference, includeBasmala: includeBasmala, requestID: requestID)
        }
    }

    private func requestPermissionAndStart(reference: AyahReference, includeBasmala: Bool, requestID: UUID) async {
        defer {
            if permissionRequestID == requestID {
                permissionTask = nil
                isRequestingPermission = false
            }
        }
        guard permissionRequestID == requestID, isRequestingPermission, !Task.isCancelled else { return }
        let allowed = await withCheckedContinuation { continuation in
            requestPermission { continuation.resume(returning: $0) }
        }
        guard permissionRequestID == requestID, !Task.isCancelled else { return }
        guard allowed else {
            permissionDenied = true
            errorMessage = "Tillåt mikrofonen i Inställningar för att spela in din recitation."
            return
        }
        let url = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            ownedSessionCategory = .playAndRecord
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 64_000,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let nextRecorder = try AVAudioRecorder(url: url, settings: settings)
            nextRecorder.delegate = self
            guard nextRecorder.prepareToRecord(), nextRecorder.record(forDuration: 60) else {
                throw CocoaError(.fileWriteUnknown)
            }
            if let recordingURL, FileManager.default.fileExists(atPath: recordingURL.path) {
                do { try FileManager.default.removeItem(at: recordingURL) }
                catch {
                    // Keep the existing take reachable if its deletion fails.
                    nextRecorder.stop()
                    throw error
                }
            }
            recorder = nextRecorder
            recordingURL = url
            recordedReference = reference
            recordedIncludesBasmala = includeBasmala && reference.ayahNumber == 1 && ![1, 9].contains(reference.surahID)
            hasRecording = false
            isRecording = true
            try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
        } catch {
            try? FileManager.default.removeItem(at: url)
            errorMessage = "Inspelningen kunde inte startas. Kontrollera mikrofonen och försök igen."
            deactivateSession()
        }
    }

    func finishRecordingIfNeeded() {
        // Also invalidate a permission request if the user leaves the screen.
        permissionRequestID = UUID()
        permissionTask?.cancel()
        permissionTask = nil
        isRequestingPermission = false
        guard isRecording, let recorder else { return }
        recorder.stop()
        isRecording = false
        hasRecording = validFileExists()
        if !hasRecording { errorMessage = "Inspelningen blev för kort eller kunde inte sparas. Försök igen." }
        self.recorder = nil
        deactivateSession()
    }

    func playRecording() {
        guard !isRecording, !isRequestingPermission, !isPlaying, hasRecording, let recordingURL else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            ownedSessionCategory = .playback
            let newPlayer = try AVAudioPlayer(contentsOf: recordingURL)
            newPlayer.delegate = self
            guard newPlayer.play() else { throw CocoaError(.fileReadUnknown) }
            player = newPlayer
            isPlaying = true
            errorMessage = nil
        } catch {
            errorMessage = "Inspelningen kunde inte spelas. Spela in en ny tagning och försök igen."
            isPlaying = false
            deactivateSession()
        }
    }

    func stopPlayback() {
        guard player != nil else { return }
        player?.stop()
        player = nil
        isPlaying = false
        deactivateSession()
    }

    func stopAll() {
        finishRecordingIfNeeded()
        stopPlayback()
    }

    @discardableResult
    func deleteRecording() -> Bool {
        stopAll()
        if let recordingURL, FileManager.default.fileExists(atPath: recordingURL.path) {
            do { try FileManager.default.removeItem(at: recordingURL) }
            catch {
                errorMessage = "Inspelningen kunde inte raderas. Försök igen."
                return false
            }
        }
        recordingURL = nil
        recordedReference = nil
        recordedIncludesBasmala = false
        hasRecording = false
        errorMessage = nil
        return true
    }

    /// Copy the finished local take for an explicit user-requested assessment.
    /// No network request is made here and no mapped file can change underneath a caller.
    func recordingData() throws -> Data {
        guard !isRecording, !isRequestingPermission, hasRecording, recordedReference != nil, let recordingURL else {
            throw RecordingDataError.missingRecording
        }
        let maximumBytes = 8 * 1_024 * 1_024
        guard let values = try? recordingURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
              values.isRegularFile == true, let byteCount = values.fileSize, byteCount > 0 else {
            throw RecordingDataError.missingRecording
        }
        guard byteCount <= maximumBytes else { throw RecordingDataError.tooLarge }
        let data: Data
        do { data = try Data(contentsOf: recordingURL) }
        catch { throw RecordingDataError.missingRecording }
        guard !data.isEmpty else { throw RecordingDataError.missingRecording }
        guard data.count <= maximumBytes else { throw RecordingDataError.tooLarge }
        return data
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor [weak self, weak recorder] in
            guard let self, let recorder, self.recorder === recorder else { return }
            self.isRecording = false
            self.hasRecording = flag && self.validFileExists()
            self.recorder = nil
            if !flag { self.errorMessage = "Inspelningen avbröts. Försök igen med en ny tagning." }
            self.deactivateSession()
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self, weak player] in
            guard let self, let player, self.player === player else { return }
            self.player = nil
            self.isPlaying = false
            self.deactivateSession()
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor [weak self, weak recorder] in
            guard let self, let recorder, self.recorder === recorder else { return }
            self.recorder = nil
            self.isRecording = false
            self.hasRecording = false
            self.errorMessage = "Inspelningen kunde inte sparas. Försök igen med en ny tagning."
            self.deactivateSession()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self, weak player] in
            guard let self, let player, self.player === player else { return }
            self.player = nil
            self.isPlaying = false
            self.errorMessage = "Inspelningen kunde inte spelas. Spela in en ny tagning."
            self.deactivateSession()
        }
    }

    private func validFileExists() -> Bool {
        guard let recordingURL,
              let values = try? recordingURL.resourceValues(forKeys: [.fileSizeKey]) else { return false }
        guard (values.fileSize ?? 0) > 0,
              let audio = try? AVAudioPlayer(contentsOf: recordingURL) else { return false }
        return audio.duration >= 0.1
    }

    private func deactivateSession() {
        guard let category = ownedSessionCategory else { return }
        ownedSessionCategory = nil
        let session = AVAudioSession.sharedInstance()
        guard session.category == category else { return }
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    @discardableResult
    private func prepareDirectory() -> Bool {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return true
        } catch {
            errorMessage = "Sparplatsen för inspelningen är inte tillgänglig. Försök starta om appen."
            return false
        }
    }
}
