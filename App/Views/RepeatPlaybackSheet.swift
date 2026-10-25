import QuranCore
import SwiftUI

@MainActor
struct RepeatPlaybackSheet: View {
    let surah: Surah
    @EnvironmentObject private var player: RecitationPlayer
    @EnvironmentObject private var recorder: PracticeRecorder
    @Environment(\.dismiss) private var dismiss
    @State private var firstVerse: Int
    @State private var lastVerse: Int
    @State private var cycles = 3
    @State private var pauseSeconds = 3

    init(surah: Surah, initialVerse: Int) {
        self.surah = surah
        let initial = min(max(1, initialVerse), max(1, surah.numberOfAyahs))
        _firstVerse = State(initialValue: initial)
        _lastVerse = State(initialValue: initial)
    }

    private var configuration: RecitationLoop? {
        RecitationLoop(surahID: surah.id, startVerse: firstVerse, endVerse: lastVerse,
                       cycles: cycles, pauseSeconds: pauseSeconds)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Verser att öva") {
                    Text(surah.englishName).font(.headline)
                    Picker("Från vers", selection: Binding(get: { firstVerse }, set: { first in
                        firstVerse = first
                        if lastVerse < first { lastVerse = first }
                    })) {
                        ForEach(1...max(1, surah.numberOfAyahs), id: \.self) { number in
                            Text("Vers \(number)").tag(number)
                                .accessibilityIdentifier("repeat.start.option.\(number)")
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("repeat.start")
                    .accessibilityValue("Vers \(firstVerse)")
                    Picker("Till vers", selection: $lastVerse) {
                        ForEach(firstVerse...max(firstVerse, surah.numberOfAyahs), id: \.self) { number in
                            Text("Vers \(number)").tag(number)
                                .accessibilityIdentifier("repeat.end.option.\(number)")
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("repeat.end")
                    .accessibilityValue("Vers \(lastVerse)")
                }
                Section {
                    Stepper(value: $cycles, in: 1...20) {
                        LabeledContent("Antal varv", value: "\(cycles)")
                    }
                    .accessibilityLabel("Antal varv")
                    .accessibilityValue("\(cycles)")
                    .accessibilityIdentifier("repeat.cycles")
                    Picker("Paus mellan verserna", selection: $pauseSeconds) {
                        Text("Ingen paus").tag(0).accessibilityIdentifier("repeat.pause.option.0")
                        ForEach(1...15, id: \.self) { seconds in
                            Text("\(seconds) sekunder").tag(seconds)
                                .accessibilityIdentifier("repeat.pause.option.\(seconds)")
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("repeat.pause")
                    .accessibilityValue(pauseSeconds == 0 ? "Ingen paus" : "\(pauseSeconds) sekunder")
                } footer: {
                    Text("Ett varv spelar hela intervallet. Använd pausen för att recitera själv. Repetitionen stannar efter det antal varv du väljer.")
                }
                Section {
                    Button {
                        guard let configuration else { return }
                        recorder.stopAll()
                        player.playRepeatedly(configuration)
                        dismiss()
                    } label: {
                        Label("Starta repetition", systemImage: "repeat")
                            .frame(minHeight: 44)
                    }
                    .foregroundStyle(Palette.green)
                    .disabled(configuration == nil)
                    .accessibilityIdentifier("repeat.startButton")
                }
            }
            .navigationTitle("Repetera verser")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Stäng") { dismiss() } }
            }
        }
        .presentationDetents([.large])
    }
}
