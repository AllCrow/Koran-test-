import Combine
import Foundation
import XCTest
@testable import Sakina

@MainActor
final class AudioNetworkPreferencesTests: XCTestCase {
    func testLegacyInstallationAllowsAudioAndWifiChoiceSurvivesRelaunch() throws {
        let defaults = try isolatedDefaults()
        defaults.set(Data([1, 2, 3]), forKey: "sakina.reading-state.v1")
        let preferences = AudioNetworkPreferences(defaults: defaults)
        XCTAssertTrue(preferences.allowsCellularAudio)
        preferences.setAllowsCellularAudio(false)
        XCTAssertFalse(AudioNetworkPreferences(defaults: defaults).allowsCellularAudio)
        XCTAssertEqual(defaults.data(forKey: "sakina.reading-state.v1"), Data([1, 2, 3]))
        preferences.setAllowsCellularAudio(true)
        XCTAssertTrue(AudioNetworkPreferences(defaults: defaults).allowsCellularAudio)
    }

    func testMalformedPreferenceDoesNotCoerceANumberOrStringIntoANetworkChoice() throws {
        let malformedValues: [Any] = [0, 1, "false", ["enabled": false]]
        for value in malformedValues {
            let defaults = try isolatedDefaults()
            defaults.set(value, forKey: "sakina.audio.cellularAllowed.v1")
            XCTAssertTrue(AudioNetworkPreferences(defaults: defaults).allowsCellularAudio)
        }
    }

    private func isolatedDefaults() throws -> UserDefaults {
        let suite = "sakina.network-tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return defaults
    }
}
