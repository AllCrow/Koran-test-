import AVFoundation
import Combine
import Foundation
import MediaPlayer
import QuranCore

/// One player for all recitations. Native end events drive verse advancement;
/// optional gaps suspend one task without estimating duration or polling.
@MainActor
final class RecitationPlayer: ObservableObject {
    typealias AudioURLProvider = @MainActor (AyahReference, Reciter) -> URL
    typealias PlayerItemFactory = @MainActor (URL, Bool) -> AVPlayerItem
    typealias RepetitionDelay = @MainActor @Sendable (Int) async throws -> Void

    /// The verse whose audio has actually started, retained while it is paused.
    @Published private(set) var activeReference: AyahReference?
    /// The selected verse, including one whose audio is still loading.
    @Published private(set) var requestedReference: AyahReference?
    @Published private(set) var selectedReciter: Reciter = .alafasy
    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var repetition: RecitationLoop?
    @Published private(set) var repetitionCycle = 0
    @Published private(set) var isWaitingBetweenVerses = false
    @Published private(set) var repetitionComplete = false
    @Published var autoplay = true {
        didSet {
            if autoplay != oldValue { defaults.set(autoplay, forKey: Self.autoplayPreferenceKey) }
        }
    }

    /// Distinguishes a completed verse from a user pause; resume restarts a
    /// completed verse. Other published playback changes invalidate the UI.
    var hasFinishedVerse: Bool { hasReachedEnd }

    private static let reciterPreferenceKey = "sakina.audio.reciter.v1"
    private static let autoplayPreferenceKey = "sakina.audio.autoplay.v1"
    private let defaults: UserDefaults
    private var player: AVPlayer
    private let makeReplacementPlayer: @MainActor () -> AVPlayer
    private let audioURL: AudioURLProvider
    private let makePlayerItem: PlayerItemFactory
    private let waitBetweenVerses: RepetitionDelay
    private var allowsCellularAccess = true
    private var currentSourceURL: URL?
    private var pendingRepetition: RecitationLoopPosition?
    private var repetitionDelayTask: Task<Void, Never>?
    private var repetitionDelayGeneration = UUID()
    private let integratesWithSystemAudio: Bool
    private let audioSession = AVAudioSession.sharedInstance()
    private var chapterVerseCount = 0
    private var wantsToPlay = false
    private var allowsAutoplay = true
    private var hasReachedEnd = false
    private var generation = UUID()
    private var itemStatusObservation: NSKeyValueObservation?
    private var playbackObservation: NSKeyValueObservation?
    private var rateObservation: NSKeyValueObservation?
    private var itemNotifications: [NSObjectProtocol] = []
    private var interruptionNotification: NSObjectProtocol?
    private var routeNotification: NSObjectProtocol?
    private var mediaServiceNotifications: [NSObjectProtocol] = []
    private var mediaServicesAvailable = true
    private var ownsAudioSession = false
    private var remoteCommandTargets: [(MPRemoteCommand, Any)] = []

    convenience init(audioLibrary: AudioLibrary? = nil, defaults: UserDefaults = .standard) {
        let library = audioLibrary ?? .shared
        self.init(player: AVPlayer(), audioURL: { reference, reciter in
            library.localURL(for: reference, reciter: reciter) ?? reciter.audioURL(for: reference)
        }, defaults: defaults, integratesWithSystemAudio: true)
    }

    /// An injected local source allows native tests to exercise the real player
    /// without network access or changing the app's global audio controls.
    init(player: AVPlayer, audioURL: @escaping AudioURLProvider,
         defaults: UserDefaults, integratesWithSystemAudio: Bool,
         makeReplacementPlayer: @escaping @MainActor () -> AVPlayer = { AVPlayer() },
         makePlayerItem: @escaping PlayerItemFactory = { url, allowsCellular in
             AVPlayerItem(asset: AVURLAsset(url: url, options: [AVURLAssetAllowsCellularAccessKey: allowsCellular]))
         },
         waitBetweenVerses: @escaping RepetitionDelay = { seconds in
             try await Task.sleep(for: .seconds(seconds))
         }) {
        self.defaults = defaults
        self.player = player
        self.makeReplacementPlayer = makeReplacementPlayer
        self.audioURL = audioURL
        self.makePlayerItem = makePlayerItem
        self.waitBetweenVerses = waitBetweenVerses
        self.integratesWithSystemAudio = integratesWithSystemAudio
        selectedReciter = defaults.string(forKey: Self.reciterPreferenceKey).flatMap(Reciter.init(rawValue:)) ?? .alafasy
        autoplay = defaults.object(forKey: Self.autoplayPreferenceKey) as? Bool ?? true
        player.automaticallyWaitsToMinimizeStalling = true
        // AVPlayer's media objects must be rebuilt if iOS restarts its audio
        // services, including when a controlled player does not own the session.
        for name in [AVAudioSession.mediaServicesWereLostNotification, AVAudioSession.mediaServicesWereResetNotification] {
            mediaServiceNotifications.append(NotificationCenter.default.addObserver(
                forName: name, object: audioSession, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    if name == AVAudioSession.mediaServicesWereLostNotification {
                        self?.handleMediaServicesLoss()
                    } else {
                        self?.recoverAfterMediaServicesReset()
                    }
                }
            })
        }
        guard integratesWithSystemAudio else { return }
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
                          self.audioSession.category != .playback,
                          self.player.currentItem != nil {
                    // The microphone may now own the shared session. A later
                    // cleanup of an old recitation must not deactivate it.
                    self.ownsAudioSession = false
                    self.stop()
                }
            }
        }
    }

    deinit {
        repetitionDelayTask?.cancel()
        itemStatusObservation?.invalidate()
        playbackObservation?.invalidate()
        rateObservation?.invalidate()
        for token in itemNotifications {
            NotificationCenter.default.removeObserver(token)
        }
        if let token = interruptionNotification {
            NotificationCenter.default.removeObserver(token)
        }
        if let token = routeNotification {
            NotificationCenter.default.removeObserver(token)
        }
        for token in mediaServiceNotifications {
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

    func playRepeatedly(_ loop: RecitationLoop) {
        clearRepetition()
        repetition = loop
        repetitionCycle = 1
        startSession(reference: loop.firstReference,
                     chapterVerseCount: AyahReference.ayahCounts[loop.surahID - 1],
                     allowsAutoplay: false, preservingRepetition: true)
    }

    private func startSession(reference: AyahReference, chapterVerseCount: Int, allowsAutoplay: Bool,
                              preservingRepetition: Bool = false) {
        guard chapterVerseCount >= reference.ayahNumber,
              AyahReference(surahID: reference.surahID, ayahNumber: chapterVerseCount) != nil else {
            errorMessage = "Den valda versen kunde inte spelas. Öppna suran igen och försök på nytt."
            return
        }
        if !preservingRepetition { clearRepetition() }
        self.chapterVerseCount = chapterVerseCount
        self.allowsAutoplay = allowsAutoplay
        load(reference: reference, shouldPlay: true)
    }

    func pause() {
        cancelRepetitionDelay(keepingTransition: true)
        wantsToPlay = false
        player.pause()
        isPlaying = false
        isBuffering = false
        deactivateOwnedAudioSession()
        updateNowPlaying()
    }

    func resume() {
        guard let reference = requestedReference else { return }
        guard mediaServicesAvailable else {
            errorMessage = Self.mediaServicesUnavailableMessage
            return
        }
        if let loop = repetition, repetitionComplete {
            playRepeatedly(loop)
            return
        }
        if pendingRepetition != nil {
            cancelRepetitionDelay(keepingTransition: true)
            advancePendingRepetition()
            return
        }
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
        clearRepetition()
        generation = UUID()
        removeItemObservers()
        wantsToPlay = false
        allowsAutoplay = true
        hasReachedEnd = false
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentSourceURL = nil
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
        let pending = pendingRepetition
        cancelRepetitionDelay(keepingTransition: false)
        selectedReciter = reciter
        defaults.set(reciter.rawValue, forKey: Self.reciterPreferenceKey)
        if let pending {
            // A new recording must not inherit the old reciter's waiting task.
            // Keep the exact pending verse, but fetch it only after explicit play.
            repetitionCycle = pending.cycle
            load(reference: pending.reference, shouldPlay: false)
        } else if let reference = requestedReference {
            // Each recording has its own duration. Start this verse from its beginning.
            load(reference: reference, shouldPlay: shouldPlay)
        }
    }

    func next() {
        guard let reference = requestedReference,
              reference.ayahNumber < (repetition?.endVerse ?? chapterVerseCount),
              let nextReference = AyahReference(
                surahID: reference.surahID,
                ayahNumber: reference.ayahNumber + 1
              ) else { return }
        cancelRepetitionDelay(keepingTransition: false)
        repetitionComplete = false
        load(reference: nextReference, shouldPlay: true)
    }

    func previous() {
        guard let reference = requestedReference,
              reference.ayahNumber > (repetition?.startVerse ?? 1),
              let previousReference = AyahReference(
                surahID: reference.surahID,
                ayahNumber: reference.ayahNumber - 1
              ) else { return }
        cancelRepetitionDelay(keepingTransition: false)
        repetitionComplete = false
        load(reference: previousReference, shouldPlay: true)
    }

    /// A changed policy applies to future assets. An existing remote asset is
    /// detached immediately so it cannot keep transferring under the old rule.
    /// Already-playing local audio needs no interruption or replacement.
    func setAllowsCellularAccess(_ allowed: Bool) {
        guard allowsCellularAccess != allowed else { return }
        allowsCellularAccess = allowed
        if pendingRepetition != nil { pause() }
        guard let url = currentSourceURL, !url.isFileURL else { return }
        pause()
        generation = UUID()
        removeItemObservers()
        player.replaceCurrentItem(with: nil)
        currentSourceURL = nil
        activeReference = nil
        errorMessage = "Ljudets nätval ändrades. Tryck på spela för att fortsätta med det nya valet."
        updateNowPlaying()
    }

    private func load(reference: AyahReference, shouldPlay: Bool) {
        cancelRepetitionDelay(keepingTransition: false)
        generation = UUID()
        let itemGeneration = generation
        removeItemObservers()
        player.pause()
        currentSourceURL = nil
        activeReference = nil
        requestedReference = reference
        wantsToPlay = shouldPlay
        hasReachedEnd = false
        isPlaying = false
        isBuffering = shouldPlay
        errorMessage = nil
        guard mediaServicesAvailable else {
            wantsToPlay = false
            isBuffering = false
            errorMessage = Self.mediaServicesUnavailableMessage
            updateNowPlaying()
            return
        }
        updateNowPlaying()

        guard shouldPlay else {
            // Replacing an item can start asset loading even while AVPlayer is
            // paused. Keep the new reciter/verse selection without fetching or
            // decoding anything until the user explicitly resumes playback.
            player.replaceCurrentItem(with: nil)
            deactivateOwnedAudioSession()
            return
        }

        let url = audioURL(reference, selectedReciter)
        currentSourceURL = url
        let item = makePlayerItem(url, allowsCellularAccess)
        player.replaceCurrentItem(with: item)

        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self, weak item] _, _ in
            Task { @MainActor [weak self, weak item] in
                guard let self, let item,
                      self.isCurrent(item, generation: itemGeneration) else { return }
                if item.status == .failed {
                    guard !self.hasReachedEnd else { return }
                    self.reportFailure(url.isFileURL
                        ? "Det sparade ljudet kunde inte spelas. Radera och ladda ned suran igen under Ljud offline."
                        : "Recitationen kunde inte hämtas. Kontrollera anslutningen och försök igen.")
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

        rateObservation = player.observe(\.rate, options: [.initial, .new]) { [weak self, weak item] _, _ in
            // A late native play acknowledgement can change rate without a new
            // time-control state. Resolve it on the actor, after the AVPlayer
            // setter returns, and enforce the latest explicit user intent.
            Task { @MainActor [weak self, weak item] in
                guard let self, let item,
                      self.isCurrent(item, generation: itemGeneration) else { return }
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
                      self.isCurrent(item, generation: itemGeneration), !self.hasReachedEnd else { return }
                let shouldAdvance = self.autoplay && self.allowsAutoplay && self.wantsToPlay
                let shouldRepeat = self.repetition != nil && self.wantsToPlay
                self.wantsToPlay = false
                self.hasReachedEnd = true
                self.isPlaying = false
                self.isBuffering = false
                if shouldRepeat, let loop = self.repetition {
                    if let next = loop.next(after: reference, cycle: self.repetitionCycle) {
                        self.pendingRepetition = next
                        if loop.pauseSeconds == 0 {
                            self.advancePendingRepetition()
                        } else {
                            self.scheduleRepetitionTransition(after: loop.pauseSeconds)
                        }
                    } else {
                        self.repetitionComplete = true
                        self.deactivateOwnedAudioSession()
                        self.updateNowPlaying()
                    }
                } else if shouldAdvance && reference.ayahNumber < self.chapterVerseCount {
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
                      self.isCurrent(item, generation: itemGeneration), !self.hasReachedEnd else { return }
                self.reportFailure(url.isFileURL
                    ? "Det sparade ljudet avbröts. Radera och ladda ned suran igen under Ljud offline."
                    : "Ljudet avbröts. Kontrollera anslutningen och tryck på spela för att försöka igen.")
            }
        })

        do {
            try activateAudioSession()
            player.play()
        } catch {
            reportFailure("Det gick inte att aktivera ljuduppspelningen. Försök igen.")
        }
    }

    private static let mediaServicesUnavailableMessage =
        "Telefonens ljudtjänst är tillfälligt otillgänglig. Vänta tills den har startats om och tryck sedan på spela."

    private func clearRepetition() {
        cancelRepetitionDelay(keepingTransition: false)
        repetition = nil
        repetitionCycle = 0
        repetitionComplete = false
    }

    private func cancelRepetitionDelay(keepingTransition: Bool) {
        repetitionDelayGeneration = UUID()
        repetitionDelayTask?.cancel()
        repetitionDelayTask = nil
        isWaitingBetweenVerses = false
        if !keepingTransition { pendingRepetition = nil }
    }

    private func advancePendingRepetition() {
        guard repetition != nil, let next = pendingRepetition else { return }
        pendingRepetition = nil
        repetitionCycle = next.cycle
        load(reference: next.reference, shouldPlay: true)
    }

    /// One suspendable delay exists only between actual native end events.
    /// It neither polls the player nor estimates a recitation's duration.
    private func scheduleRepetitionTransition(after seconds: Int) {
        cancelRepetitionDelay(keepingTransition: true)
        let taskID = repetitionDelayGeneration
        let wait = waitBetweenVerses
        wantsToPlay = true
        isWaitingBetweenVerses = true
        updateNowPlaying()
        repetitionDelayTask = Task { @MainActor [weak self] in
            do {
                try Task.checkCancellation()
                try await wait(seconds)
                try Task.checkCancellation()
                guard let self, self.repetitionDelayGeneration == taskID,
                      self.wantsToPlay, self.mediaServicesAvailable else { return }
                self.repetitionDelayTask = nil
                self.isWaitingBetweenVerses = false
                self.advancePendingRepetition()
            } catch {
                guard let self, self.repetitionDelayGeneration == taskID else { return }
                self.repetitionDelayTask = nil
                self.isWaitingBetweenVerses = false
                self.reportFailure("Repetitionen pausades. Tryck på spela för att fortsätta med nästa vers.")
            }
        }
    }

    private func handleMediaServicesLoss() {
        guard mediaServicesAvailable else { return }
        mediaServicesAvailable = false
        cancelRepetitionDelay(keepingTransition: true)
        // The lost service can leave old media state and callbacks behind.
        // Quiesce immediately, keep the user's selection, and wait for reset
        // before constructing or activating replacement audio objects.
        generation = UUID()
        removeItemObservers()
        wantsToPlay = false
        ownsAudioSession = false
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentSourceURL = nil
        hasReachedEnd = false
        activeReference = nil
        isPlaying = false
        isBuffering = false
        errorMessage = requestedReference == nil ? nil : Self.mediaServicesUnavailableMessage
        updateNowPlaying()
    }

    private func recoverAfterMediaServicesReset() {
        // Audio services invalidated the old player and session. Invalidate
        // queued item callbacks before discarding either, retain the user's
        // exact selection, and require an explicit play action to resume.
        mediaServicesAvailable = true
        cancelRepetitionDelay(keepingTransition: true)
        generation = UUID()
        removeItemObservers()
        wantsToPlay = false
        ownsAudioSession = false
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentSourceURL = nil
        player = makeReplacementPlayer()
        player.automaticallyWaitsToMinimizeStalling = true
        hasReachedEnd = false
        activeReference = nil
        isPlaying = false
        isBuffering = false
        errorMessage = requestedReference == nil ? nil
            : "Telefonens ljudtjänst startades om. Tryck på spela för att fortsätta."
        updateNowPlaying()
    }

    private func isCurrent(_ item: AVPlayerItem, generation: UUID) -> Bool {
        self.generation == generation && player.currentItem === item
    }

    private func updatePlaybackState(item: AVPlayerItem, reference: AyahReference) {
        guard wantsToPlay else {
            // AVFoundation can acknowledge an earlier play after a pause or
            // headphone interruption. Publishing a paused flag is insufficient:
            // enforce that intent on the actual engine too. A zero rate needs
            // no further setter, avoiding a pause/KVO feedback loop.
            if player.rate != 0 { player.pause() }
            isPlaying = false
            isBuffering = false
            updateNowPlaying()
            return
        }
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
        guard integratesWithSystemAudio else { return }
        // Recording practice can change the shared audio session's category.
        try audioSession.setCategory(.playback, mode: .default)
        try audioSession.setActive(true)
        ownsAudioSession = true
    }

    private func reportFailure(_ message: String) {
        cancelRepetitionDelay(keepingTransition: true)
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
            if player.isPlaying || player.isBuffering || player.isWaitingBetweenVerses { player.pause() }
            else { player.resume() }
        }
        addRemoteTarget(commands.stopCommand) { $0.stop() }
        addRemoteTarget(commands.nextTrackCommand) { player in
            guard player.allowsAutoplay || player.repetition != nil else { return }
            player.next()
        }
        addRemoteTarget(commands.previousTrackCommand) { player in
            guard player.allowsAutoplay || player.repetition != nil else { return }
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
        guard integratesWithSystemAudio else { return }
        let commands = MPRemoteCommandCenter.shared()
        let hasSelection = requestedReference != nil
        commands.playCommand.isEnabled = hasSelection && !wantsToPlay
        commands.pauseCommand.isEnabled = hasSelection && wantsToPlay
        commands.togglePlayPauseCommand.isEnabled = hasSelection
        commands.stopCommand.isEnabled = hasSelection
        // A practice recording remains attached to its one chosen verse, even
        // when a headset has next/previous buttons.
        commands.nextTrackCommand.isEnabled = (allowsAutoplay || repetition != nil)
            && (requestedReference.map { $0.ayahNumber < (repetition?.endVerse ?? chapterVerseCount) } ?? false)
        commands.previousTrackCommand.isEnabled = (allowsAutoplay || repetition != nil)
            && (requestedReference.map { $0.ayahNumber > (repetition?.startVerse ?? 1) } ?? false)

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
        rateObservation?.invalidate()
        rateObservation = nil
        for token in itemNotifications {
            NotificationCenter.default.removeObserver(token)
        }
        itemNotifications.removeAll()
    }
}
