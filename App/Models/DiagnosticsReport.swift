import Foundation

/// An explicit support snapshot. There is deliberately no raw error, URL,
/// reference, filename, user-defaults dump or recording input in this schema.
struct DiagnosticsReport: Encodable, Equatable, Sendable {
    enum PlaybackState: String, Encodable, Sendable {
        case idle, loading, playing, paused
    }

    enum PracticeState: String, Encodable, Sendable {
        case idle, requestingPermission = "requesting_permission", recording, playing
    }

    enum ErrorArea: String, CaseIterable, Encodable, Sendable {
        case reading, recitation, downloads, recording, assessment, storage
    }

    struct Audio: Encodable, Equatable, Sendable {
        let playback: PlaybackState
        let allowsCellularAudio: Bool
        let downloadActive: Bool

        enum CodingKeys: String, CodingKey {
            case playback, allowsCellularAudio = "allows_cellular_audio", downloadActive = "download_active"
        }
    }

    struct Practice: Encodable, Equatable, Sendable {
        let state: PracticeState
        let hasTemporaryTake: Bool

        enum CodingKeys: String, CodingKey {
            case state, hasTemporaryTake = "has_temporary_take"
        }
    }

    struct Services: Encodable, Equatable, Sendable {
        let readingLoading: Bool
        let experimentalAssessmentAvailable: Bool
        let assessmentRunning: Bool
        let errorAreas: [ErrorArea]

        init(readingLoading: Bool, experimentalAssessmentAvailable: Bool,
             assessmentRunning: Bool, errorAreas: [ErrorArea]) {
            self.readingLoading = readingLoading
            self.experimentalAssessmentAvailable = experimentalAssessmentAvailable
            self.assessmentRunning = assessmentRunning
            // Canonical order and no duplicates, even if two components flag
            // the same area. No underlying messages cross this boundary.
            self.errorAreas = ErrorArea.allCases.filter { errorAreas.contains($0) }
        }

        enum CodingKeys: String, CodingKey {
            case readingLoading = "reading_loading"
            case experimentalAssessmentAvailable = "experimental_assessment_available"
            case assessmentRunning = "assessment_running", errorAreas = "error_areas"
        }
    }

    struct Storage: Encodable, Equatable, Sendable {
        enum Status: String, Encodable, Sendable { case checked, unavailable, pending }
        let status: Status
        let savedSelections: Int?
        let audioBytes: Int64?

        static let unavailable = Storage(status: .unavailable)
        static let pending = Storage(status: .pending)

        init(savedSelections: Int, audioBytes: Int64) {
            let maximumBytes = Int64(6_236 * 3) * 32 * 1_024 * 1_024
            if (0...(114 * 3)).contains(savedSelections), (0...maximumBytes).contains(audioBytes) {
                status = .checked
                self.savedSelections = savedSelections
                self.audioBytes = audioBytes
            } else {
                status = .unavailable
                self.savedSelections = nil
                self.audioBytes = nil
            }
        }

        private init(status: Status) {
            self.status = status
            savedSelections = nil
            audioBytes = nil
        }

        enum CodingKeys: String, CodingKey {
            case status, savedSelections = "saved_selections", audioBytes = "audio_bytes"
        }
    }

    let schemaVersion = 1
    let appVersion: String
    let appBuild: String
    let platform = "iOS"
    let deviceFamily = "iPhone"
    let systemVersion: String
    let audio: Audio
    let practice: Practice
    let services: Services
    let storage: Storage

    init(appVersion: String?, appBuild: String?, systemVersion: OperatingSystemVersion,
         audio: Audio, practice: Practice, services: Services, storage: Storage) {
        self.appVersion = Self.version(appVersion, maximumComponents: 4)
        self.appBuild = Self.version(appBuild, maximumComponents: 1)
        let parts = [systemVersion.majorVersion, systemVersion.minorVersion, systemVersion.patchVersion]
        self.systemVersion = parts.allSatisfy { (0...999).contains($0) }
            ? parts.map(String.init).joined(separator: ".") : "unknown"
        self.audio = audio
        self.practice = practice
        self.services = services
        self.storage = storage
    }

    func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// Bundle metadata is controlled by the build, but it is still not a
    /// general string channel into a report that promises a strict allowlist.
    private static func version(_ value: String?, maximumComponents: Int) -> String {
        guard let value, !value.isEmpty, value.utf8.count <= 32,
              value.utf8.allSatisfy({ (48...57).contains($0) || $0 == 46 }) else { return "unknown" }
        let components = value.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...maximumComponents).contains(components.count),
              components.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 9 }) else { return "unknown" }
        return value
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version", appVersion = "app_version", appBuild = "app_build"
        case platform, deviceFamily = "device_family", systemVersion = "system_version"
        case audio, practice, services, storage
    }
}
