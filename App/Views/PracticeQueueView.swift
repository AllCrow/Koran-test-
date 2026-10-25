import QuranCore
import SwiftUI

/// A manual intention to practise. Opening and removing entries grants no credit.
@MainActor
struct PracticeQueueView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var player: RecitationPlayer
    @EnvironmentObject private var recorder: PracticeRecorder
    @EnvironmentObject private var assessment: RecitationAssessmentStore
    @State private var destination: AyahReference?
    @State private var pendingReference: AyahReference?
    @State private var queueError: String?

    var body: some View {
        List {
            Section {
                Text("Spara verser med Öva igen. Välj en vers när du vill öva och ta bort den när du känner dig redo.")
                    .font(.callout).foregroundStyle(.secondary)
                LabeledContent("Verser i kön", value: "\(store.practiceQueue.count) av \(AppStore.maximumPracticeQueueCount)")
            }
            if store.practiceQueue.isEmpty {
                ContentUnavailableView("Din övningskö är tom", systemImage: "text.badge.plus",
                    description: Text("Välj Öva igen vid en vers för att lägga den här."))
            } else {
                Section("Välj en vers") {
                    ForEach(store.practiceQueue) { reference in
                        HStack(alignment: .center, spacing: 12) {
                            Button {
                                requestOpening(reference)
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(surahName(reference)).foregroundStyle(.primary)
                                        Text("Vers \(reference.surahID):\(reference.ayahNumber)")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 8)
                                    Image(systemName: "chevron.right")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(selectionLocked)
                            .accessibilityLabel("Öva \(surahName(reference)), vers \(reference.ayahNumber)")
                            .accessibilityIdentifier("queue.select.\(reference.surahID).\(reference.ayahNumber)")
                            Button(role: .destructive) {
                                remove(reference)
                            } label: {
                                Image(systemName: "minus.circle")
                                    .frame(minWidth: 44, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Ta bort vers \(reference.surahID):\(reference.ayahNumber) ur övningskön")
                            .accessibilityIdentifier("queue.remove.\(reference.surahID).\(reference.ayahNumber)")
                        }
                    }
                }
            }
            if let error = recorder.errorMessage {
                Section { ErrorBanner(message: error) }
            }
            Section {
                Text("Kön är personlig och sparas på din iPhone samt i dina läskopior. Att öppna eller ta bort en vers räknas inte som läsning.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Min övningskö")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $destination) { reference in
            PracticeView(initialReference: reference)
        }
        .confirmationDialog("Byta vers och radera tagningen?", isPresented: Binding(
            get: { pendingReference != nil },
            set: { if !$0 { pendingReference = nil } }
        ), titleVisibility: .visible) {
            Button("Byt vers och radera tagningen", role: .destructive) {
                guard let reference = pendingReference else { return }
                pendingReference = nil
                guard !selectionLocked, store.practiceQueue.contains(reference) else { return }
                if !recorder.hasRecording || recorder.recordedReference == reference || recorder.deleteRecording() {
                    open(reference)
                }
            }
            Button("Behåll tagningen", role: .cancel) { pendingReference = nil }
        } message: {
            Text("Du har en tillfällig inspelning för en annan vers. Den tas bort om du väljer den nya versen.")
        }
        .alert("Övningskön kunde inte ändras", isPresented: Binding(
            get: { queueError != nil },
            set: { if !$0 { queueError = nil } }
        )) {
            Button("OK", role: .cancel) { queueError = nil }
        } message: {
            if let queueError { Text(queueError) }
        }
    }

    private var selectionLocked: Bool {
        recorder.isRecording || recorder.isRequestingPermission || assessment.isAssessing
    }

    private func requestOpening(_ reference: AyahReference) {
        guard !selectionLocked, store.practiceQueue.contains(reference) else { return }
        if recorder.hasRecording && recorder.recordedReference != reference {
            pendingReference = reference
        } else {
            open(reference)
        }
    }

    private func open(_ reference: AyahReference) {
        guard !selectionLocked, store.practiceQueue.contains(reference) else { return }
        recorder.stopAll()
        assessment.reset()
        player.stop()
        destination = reference
    }

    private func remove(_ reference: AyahReference) {
        guard !store.removeFromPracticeQueue(reference) else { return }
        queueError = "Ändringen kunde inte sparas. Din tidigare övningskö finns kvar. Försök igen."
    }

    private func surahName(_ reference: AyahReference) -> String {
        store.index?.surahs.first { $0.id == reference.surahID }?.englishName ?? "Sura \(reference.surahID)"
    }
}
