import Combine
import Foundation
import QuranCore
import QuranPractice

/// Optional, disabled-by-default prototype. The normal app never uploads audio.
@MainActor
final class RecitationAssessmentStore: ObservableObject {
    @Published private(set) var isAssessing = false
    @Published private(set) var response: RecitationAssessment?
    @Published private(set) var errorMessage: String?

    var isAvailable: Bool { client != nil }
    private let client: RecitationAssessmentClient?
    private var currentRequestID = UUID()
    private var analysisTask: Task<Void, Never>?

    init(info: [String: Any] = Bundle.main.infoDictionary ?? [:]) {
        guard info["SAKINA_ENABLE_EXPERIMENTAL_ANALYSIS"] as? Bool == true,
              let address = info["SAKINA_ANALYSIS_URL"] as? String,
              let url = URL(string: address) else { client = nil; return }
        client = try? RecitationAssessmentClient(baseURL: url)
    }

    deinit { analysisTask?.cancel() }

    /// Reserve this take synchronously before the UI can change verse or leave.
    /// The owned task can then be cancelled even before its first execution.
    func beginAssessment(audioData: Data, ayah: Ayah, includeBasmala: Bool) {
        cancel()
        response = nil
        errorMessage = nil
        guard let client else {
            errorMessage = "Automatisk recitationshjälp är inte tillgänglig i den här versionen."
            return
        }
        let requestID = UUID()
        currentRequestID = requestID
        isAssessing = true
        analysisTask = Task { @MainActor [weak self] in
            do {
                try Task.checkCancellation()
                let result = try await client.assess(audioData: audioData, ayah: ayah, includeBasmala: includeBasmala)
                try Task.checkCancellation()
                guard let self, self.currentRequestID == requestID else { return }
                self.response = result
            } catch is CancellationError {
                // An abandoned take must not replace the next take's feedback.
            } catch {
                guard let self, self.currentRequestID == requestID else { return }
                self.errorMessage = error.localizedDescription
            }
            guard let self, self.currentRequestID == requestID else { return }
            self.analysisTask = nil
            self.isAssessing = false
        }
    }

    /// Compatibility for structured callers. UI button actions should call
    /// `beginAssessment` directly instead of putting it inside another Task.
    func assess(audioData: Data, ayah: Ayah, includeBasmala: Bool) async {
        guard !Task.isCancelled else { return }
        beginAssessment(audioData: audioData, ayah: ayah, includeBasmala: includeBasmala)
        guard let task = analysisTask else { return }
        await withTaskCancellationHandler {
            await task.value
        } onCancel: { task.cancel() }
    }

    func cancel() {
        currentRequestID = UUID()
        analysisTask?.cancel()
        analysisTask = nil
        isAssessing = false
    }

    func reset() {
        cancel()
        response = nil
        errorMessage = nil
    }
}
