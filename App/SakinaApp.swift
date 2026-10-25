import Foundation
import SwiftUI

@main
@MainActor
struct SakinaApp: App {
    @StateObject private var store = AppStore(defaults: SakinaApp.readingDefaults)
    @StateObject private var player = RecitationPlayer(defaults: SakinaApp.readingDefaults)
    @StateObject private var recorder = PracticeRecorder()
    @StateObject private var audioLibrary = AudioLibrary.shared
    @StateObject private var assessment = RecitationAssessmentStore()
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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(player)
                .environmentObject(recorder)
                .environmentObject(audioLibrary)
                .environmentObject(assessment)
                .environment(\.quranTextSize, CGFloat(store.arabicTextSize.pointSize))
                .preferredColorScheme(store.appearance == .system ? nil : (store.appearance == .dark ? .dark : .light))
                .tint(Palette.green)
                .task { await store.load() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.refreshDay() }
                    if phase == .background {
                        recorder.stopAll()
                        assessment.cancel()
                        audioLibrary.cancelDownload()
                    }
                }
        }
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
