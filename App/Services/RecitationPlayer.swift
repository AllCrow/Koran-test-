import AVFoundation
import Combine
import Foundation
import MediaPlayer
import QuranCore

/// One player for all recitations. Verse changes follow player events, never a timer.
@MainActor
final class RecitationPlayer: ObservableObject {
    /// The verse whose audio has actually started, retained while it is paused.
    @Published private(set) var activeReference: AyahReference?
    /// The selected verse, including one whose audio is still loading.
    @Published private(set) var requestedReference: AyahReference?
    @Published private(set) var selectedReciter: Reciter = .alafasy
    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = false
    @Published private(set) var errorMessage: String?
    @Published var autoplay = true {
        didSet {
            if autoplay != oldValue { defaults.set(autoplay, forKey: Self.autoplayPreferenceKey) }
        }
    }

    private static let reciterPreferenceKey = "sakina.audio.reciter.v1"
    private static let autoplayPreferenceKey = "sakina.audio.autoplay.v1"
    private let defaults: UserDefaults
    private let player: AVPlayer
    private let audioLibrary: AudioLibrary
    private let streamingURL: (AyahReference, Reciter) -> URL
    private let audioSession = AVAudioSession.sharedInstance()
    private var chapterVerseCount = 0
    private var wantsToPlay = false
    private var allowsAutoplay = true
    private var hasReachedEnd = false
    private var generation = UUID()
    private var itemStatusObservation: NSKeyValueObservation?
    private var playbackObservation: NSKeyValueObservation?
    private var itemNotifications: [NSObjectProtocol] = []
    private var interruptionNotification: NSObjectProtocol?
    private var routeNotification: NSObjectProtocol?
    private var ownsAudioSession = false
    private var remoteCommandTargets: [(MPRemoteCommand, Any)] = []

    init(audioLibrary: AudioLibrary? = nil, defaults: UserDefaults = .standard,
         player: AVPlayer? = nil,
         streamingURL: @escaping (AyahReference, Reciter) -> URL = { reference, reciter in reciter.audioURL(for: reference) }) {
        self.defaults = defaults
        self.audioLibrary = audioLibrary ?? .shared
        self.player = player ?? AVPlayer()
        self.streamingURL = streamingURL
        selectedReciter = defaults.string(forKey: Self.reciterPreferenceKey).flatMap(Reciter.init(rawValue:)) ?? .alafasy
        autoplay = defaults.object(forKey: Self.autoplayPreferenceKey) as? Bool ?? true
        self.player.automaticallyWaitsToMinimizeStalling = true
        configureRemoteCommands()

        interruptionNotification = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] notification in
            let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard rawType == AVAudioSession.InterruptionType.began.rawValue else { return }
            MainActor.assumeIsolated {
                // A phone call or other interruption must not restart recitation unexpectedly.
                // This observer is already delivered on .main; avoid leaving a pause
                // task queued across stop(), recording, and a new playback session.
                self?.pause()
            }
        }

        routeNotification = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] notification in
            let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            MainActor.assumeIsolated {
                guard let self else { return }
                if rawReason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
                    self.pause()
                } else if rawReason == AVAudioSession.RouteChangeReason.categoryChange.rawValue,
                          self.audioSession.category != .playback {
                    // The microphone may now own the shared session. A later
                    // cleanup of an old recitation must not deactivate it.
                    self.ownsAudioSession = false
                    self.stop()
                }
            }
        }
    }

    deinit {
        itemStatusObservation?.invalidate()
        playbackObservation?.invalidate()
        for token in itemNotifications {
            NotificationCenter.default.removeObserver(token)
        }
        if let token = interruptionNotification {
            NotificationCenter.default.removeObserver(token)
        }
        if let token = routeNotification {
            NotificationCenter.default.removeObserver(token)
        }
        player.pause()
        player.replaceCurrentItem(with: nil)
        for (command, target) in remoteCommandTargets { command.removeTarget(target) }
    }

    func play(reference: AyahReference, chapterVerseCount: Int) {
        startSession(reference: reference, chapterVerseCount: chapterVerseCount, allowsAutoplay: true)
    }

    /// Play one reference verse for practice without changing the user's autoplay setting.
    func playOnce(reference: AyahReference, chapterVerseCount: Int) {
        startSession(reference: reference, chapterVerseCount: chapterVerseCount, allowsAutoplay: false)
    }

    private func startSession(reference: AyahReference, chapterVerseCount: Int, allowsAutoplay: Bool) {
        guard chapterVerseCount >= reference.ayahNumber,
              AyahReference(surahID: reference.surahID, ayahNumber: chapterVerseCount) != nil else {
            errorMessage = "Den valda versen kunde inte spelas. Öppna suran igen och försök på nytt."
            return
        }
        self.chapterVerseCount = chapterVerseCount
        self.allowsAutoplay = allowsAutoplay
        load(reference: reference, shouldPlay: true)
    }

    func pause() {
        wantsToPlay = false
        player.pause()
        isPlaying = false
        isBuffering = false
        deactivateOwnedAudioSession()
        updateNowPlaying()
    }

    func resume() {
        guard let reference = requestedReference else { return }
        if hasReachedEnd || errorMessage != nil || player.currentItem?.status == .failed || player.currentItem == nil {
            load(reference: reference, shouldPlay: true)
            return
        }

        do {
            try activateAudioSession()
            errorMessage = nil
            wantsToPlay = true
            isBuffering = player.currentItem?.status != .readyToPlay
            player.play()
            updateNowPlaying()
        } catch {
            reportFailure("Det gick inte att starta ljudet. Försök igen.")
        }
    }

    func stop() {
        generation = UUID()
        removeItemObservers()
        wantsToPlay = false
        allowsAutoplay = true
        hasReachedEnd = false
        player.pause()
        player.replaceCurrentItem(with: nil)
        requestedReference = nil
        activeReference = nil
        isPlaying = false
        isBuffering = false
        errorMessage = nil
        chapterVerseCount = 0
        deactivateOwnedAudioSession()
        updateNowPlaying()
    }

    func selectReciter(_ reciter: Reciter) {
        guard selectedReciter != reciter else { return }
        let shouldPlay = wantsToPlay
        selectedReciter = reciter
        defaults.set(reciter.rawValue, forKey: Self.reciterPreferenceKey)
        if let reference = requestedReference {
            // Each recording has its own duration. Start this verse from its beginning.
            load(reference: reference, shouldPlay: shouldPlay)
        }
    }

    func next() {
        guard let reference = requestedReference,
              reference.ayahNumber < chapterVerseCount,
              let nextReference = AyahReference(
                surahID: reference.surahID,
                ayahNumber: reference.ayahNumber + 1
              ) else { return }
        load(reference: nextReference, shouldPlay: true)
    }

    func previous() {
        guard let reference = requestedReference,
              reference.ayahNumber > 1,
              let previousReference = AyahReference(
                surahID: reference.surahID,
                ayahNumber: reference.ayahNumber - 1
              ) else { return }
        load(reference: previousReference, shouldPlay: true)
    }

    private func load(reference: AyahReference, shouldPlay: Bool) {
        generation = UUID()
        let itemGeneration = generation
        removeItemObservers()
        player.pause()
        activeReference = nil
        requestedReference = reference
        wantsToPlay = shouldPlay
        hasReachedEnd = false
        isPlaying = false
        isBuffering = shouldPlay
        errorMessage = nil
        updateNowPlaying()

        let url = audioLibrary.localURL(for: reference, reciter: selectedReciter)
            ?? streamingURL(reference, selectedReciter)
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)

        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self, weak item] _, _ in
            Task { @MainActor [weak self, weak item] in
                guard let self, let item,
                      self.isCurrent(item, generation: itemGeneration) else { return }
                if item.status == .failed {
                    self.reportFailure("Recitationen kunde inte hämtas. Kontrollera anslutningen och försök igen.")
                } else {
                    self.updatePlaybackState(item: item, reference: reference)
                }
            }
        }

        playbackObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self, weak item] _, _ in
            Task { @MainActor [weak self, weak item] in
                guard let self, let item,
                      self.isCurrent(item, generation: itemGeneration) else { return }
                // Read the current state here so an already-queued KVO callback cannot
                // overwrite a newer playback state after a pause or reciter change.
                self.updatePlaybackState(item: item, reference: reference)
            }
        }

        itemNotifications.append(NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self, weak item] _ in
            Task { @MainActor [weak self, weak item] in
                guard let self, let item,
                      self.isCurrent(item, generation: itemGeneration) else { return }
                let shouldAdvance = self.autoplay && self.allowsAutoplay && self.wantsToPlay
                self.wantsToPlay = false
                self.hasReachedEnd = true
                self.isPlaying = false
                self.isBuffering = false
                if shouldAdvance && reference.ayahNumber < self.chapterVerseCount {
                    self.next()
                } else {
                    self.deactivateOwnedAudioSession()
                    self.updateNowPlaying()
                }
            }
        })

        itemNotifications.append(NotificationCenter.default.addObserver(
            forName: AVPlayerItem.failedToPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self, weak item] _ in
            Task { @MainActor [weak self, weak item] in
                guard let self, let item,
                      self.isCurrent(item, generation: itemGeneration) else { return }
                self.reportFailure("Ljudet avbröts. Kontrollera anslutningen och tryck på spela för att försöka igen.")
            }
        })

        if shouldPlay {
            do {
                try activateAudioSession()
                player.play()
            } catch {
                reportFailure("Det gick inte att aktivera ljuduppspelningen. Försök igen.")
            }
        } else {
            deactivateOwnedAudioSession()
        }
    }

    private func isCurrent(_ item: AVPlayerItem, generation: UUID) -> Bool {
        self.generation == generation && player.currentItem === item
    }

    private func updatePlaybackState(item: AVPlayerItem, reference: AyahReference) {
        guard item.status != .failed else { return }
        switch player.timeControlStatus {
        case .playing:
            // Never highlight a verse from an estimate of its duration.
            activeReference = reference
            isPlaying = wantsToPlay
            isBuffering = false
        case .waitingToPlayAtSpecifiedRate:
            isPlaying = false
            isBuffering = wantsToPlay
        case .paused:
            isPlaying = false
            isBuffering = wantsToPlay && item.status == .unknown
        @unknown default:
            isPlaying = false
            isBuffering = false
        }
        updateNowPlaying()
    }

    private func activateAudioSession() throws {
        // Recording practice can change the shared audio session's category.
        try audioSession.setCategory(.playback, mode: .default)
        try audioSession.setActive(true)
        ownsAudioSession = true
    }

    private func reportFailure(_ message: String) {
        wantsToPlay = false
        player.pause()
        isPlaying = false
        isBuffering = false
        errorMessage = message
        deactivateOwnedAudioSession()
        updateNowPlaying()
    }

    private func deactivateOwnedAudioSession() {
        guard ownsAudioSession else { return }
        ownsAudioSession = false
        guard audioSession.category == .playback else { return }
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Native lock-screen and headphone controls follow this player's current
    /// selection. No duration estimates, time observers or polling are needed.
    private func configureRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()
        addRemoteTarget(commands.playCommand) { $0.resume() }
        addRemoteTarget(commands.pauseCommand) { $0.pause() }
        addRemoteTarget(commands.togglePlayPauseCommand) { player in
            if player.isPlaying || player.isBuffering { player.pause() }
            else { player.resume() }
        }
        addRemoteTarget(commands.stopCommand) { $0.stop() }
        addRemoteTarget(commands.nextTrackCommand) { player in
            guard player.allowsAutoplay else { return }
            player.next()
        }
        addRemoteTarget(commands.previousTrackCommand) { player in
            guard player.allowsAutoplay else { return }
            player.previous()
        }
        updateNowPlaying()
    }

    private func addRemoteTarget(
        _ command: MPRemoteCommand,
        action: @escaping @MainActor (RecitationPlayer) -> Void
    ) {
        let target = command.addTarget { [weak self] _ in
            // MediaPlayer may invoke a command off the main thread. Recheck
            // selection on the actor so a queued action cannot revive a take
            // after stop() or after recording has claimed the audio session.
            Task { @MainActor [weak self] in
                guard let self, self.requestedReference != nil else { return }
                action(self)
            }
            return .success
        }
        remoteCommandTargets.append((command, target))
    }

    private func updateNowPlaying() {
        let commands = MPRemoteCommandCenter.shared()
        let hasSelection = requestedReference != nil
        commands.playCommand.isEnabled = hasSelection && !wantsToPlay
        commands.pauseCommand.isEnabled = hasSelection && wantsToPlay
        commands.togglePlayPauseCommand.isEnabled = hasSelection
        commands.stopCommand.isEnabled = hasSelection
        // A practice recording remains attached to its one chosen verse, even
        // when a headset has next/previous buttons.
        commands.nextTrackCommand.isEnabled = allowsAutoplay && (requestedReference.map { $0.ayahNumber < chapterVerseCount } ?? false)
        commands.previousTrackCommand.isEnabled = allowsAutoplay && (requestedReference.map { $0.ayahNumber > 1 } ?? false)

        guard let reference = requestedReference else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        // Metadata describes the selected recording. The reading view still
        // highlights only activeReference, set when actual playback begins.
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: "Sura \(reference.surahID) · Vers \(reference.ayahNumber)",
            MPMediaItemPropertyArtist: selectedReciter.displayName,
            MPMediaItemPropertyAlbumTitle: "Sakina · Koranen",
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]
    }

    private func removeItemObservers() {
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        playbackObservation?.invalidate()
        playbackObservation = nil
        for token in itemNotifications {
            NotificationCenter.default.removeObserver(token)
        }
        itemNotifications.removeAll()
    }
}
