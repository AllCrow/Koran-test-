import Combine
import CoreFoundation
import Foundation

/// A local choice for recitation audio. Reading and saved audio need no network.
@MainActor
final class AudioNetworkPreferences: ObservableObject {
    private static let storageKey = "sakina.audio.cellularAllowed.v1"
    @Published private(set) var allowsCellularAudio: Bool
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Existing installations keep their previous ability to stream audio.
        // Reject non-Boolean values instead of coercing a malformed preference.
        if let value = defaults.object(forKey: Self.storageKey) as? NSNumber,
           CFGetTypeID(value) == CFBooleanGetTypeID() {
            allowsCellularAudio = value.boolValue
        } else {
            allowsCellularAudio = true
        }
    }

    func setAllowsCellularAudio(_ allowed: Bool) {
        guard allowsCellularAudio != allowed else { return }
        defaults.set(allowed, forKey: Self.storageKey)
        allowsCellularAudio = allowed
    }
}
