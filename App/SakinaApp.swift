import Foundation
import SwiftUI

@main
@MainActor
struct SakinaApp: App {
    @StateObject private var store = AppStore(defaults: SakinaApp.readingDefaults)
    @StateObject private var player = SakinaApp.makePlayer()
    @StateObject private var recorder = PracticeRecorder()
    @StateObject private var audioLibrary = SakinaApp.recitationLibrary
    @StateObject private var assessment = RecitationAssessmentStore()
    @StateObject private var audioNetwork = AudioNetworkPreferences(defaults: SakinaApp.readingDefaults)
    @Environment(\.scenePhase) private var scenePhase

    private static var readingDefaults: UserDefaults {
        #if DEBUG
        // Native UI tests use their own persistent suite. They can test a real
        // relaunch without clearing or changing anyone's normal reading data.
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--ui-test-suite"),
           arguments.indices.contains(index + 1),
           arguments[index + 1].hasPrefix("sakina.uitests."),
           let defaults = UserDefaults(suiteName: arguments[index + 1]) { return defaults }
        #endif
        return .standard
    }

    private static let recitationLibrary: AudioLibrary = {
        #if DEBUG
        if let suite = uiTestSuite { return UITestAudioFixture.makeLibrary(suite: suite) }
        #endif
        return .shared
    }()

    private static func makePlayer() -> RecitationPlayer {
        #if DEBUG
        if let suite = uiTestSuite {
            return UITestAudioFixture.makePlayer(library: recitationLibrary, defaults: readingDefaults, suite: suite)
        }
        #endif
        return RecitationPlayer(audioLibrary: recitationLibrary, defaults: readingDefaults)
    }

    #if DEBUG
    private static var uiTestSuite: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--ui-test-suite"),
              arguments.indices.contains(index + 1),
              arguments[index + 1].hasPrefix("sakina.uitests.") else { return nil }
        return arguments[index + 1]
    }
    #endif

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(player)
                .environmentObject(recorder)
                .environmentObject(audioLibrary)
                .environmentObject(assessment)
                .environmentObject(audioNetwork)
                .environment(\.quranTextSize, CGFloat(store.arabicTextSize.pointSize))
                .preferredColorScheme(store.appearance == .system ? nil : (store.appearance == .dark ? .dark : .light))
                .tint(Palette.green)
                .task {
                    applyAudioNetworkChoice()
                    await store.load()
                }
                .onChange(of: audioNetwork.allowsCellularAudio) { _, _ in applyAudioNetworkChoice() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.refreshDay() }
                    if phase == .background {
                        recorder.stopAll()
                        assessment.cancel()
                        audioLibrary.cancelDownload()
                        audioLibrary.cancelInventoryScan()
                    }
                }
        }
    }

    private func applyAudioNetworkChoice() {
        audioLibrary.setAllowsCellularAccess(audioNetwork.allowsCellularAudio)
        player.setAllowsCellularAccess(audioNetwork.allowsCellularAudio)
    }
}

@MainActor
struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var player: RecitationPlayer
    @EnvironmentObject private var recorder: PracticeRecorder
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView {
                    if let reference = store.lastRead {
                        recorder.stopAll()
                        if player.requestedReference?.surahID != reference.surahID { player.stop() }
                        Task { await store.openSurah(reference.surahID) }
                    }
                    selectedTab = 1
                }
            }
                .tabItem { Label("Idag", systemImage: "sun.max") }.tag(0)
            NavigationStack { ReaderView() }
                .tabItem { Label("Koranen", systemImage: "book") }.tag(1)
            NavigationStack { PracticeView() }
                .tabItem { Label("Öva", systemImage: "waveform") }.tag(2)
            NavigationStack { SettingsView() }
                .tabItem { Label("Mitt", systemImage: "person.crop.circle") }.tag(3)
        }
    }
}
