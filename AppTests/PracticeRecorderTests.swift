import AVFoundation
import Combine
import Foundation
import QuranCore
import XCTest
@testable import Sakina

/// Lifecycle tests deliberately use denied/delayed permission callbacks. They
/// never ask for system permission, start a microphone or activate audio.
@MainActor
final class PracticeRecorderTests: XCTestCase {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sakina-recorder-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func reference(_ number: Int = 1) throws -> AyahReference {
        try XCTUnwrap(AyahReference(surahID: 1, ayahNumber: number))
    }

    func testInitializationRemovesOnlyOwnedStaleTakes() throws {
        let root = try directory()
        let stale = root.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        let unrelated = root.appendingPathComponent("notes.txt")
        let unknownAudio = root.appendingPathComponent("other.m4a")
        let nested = root.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        try Data("old temporary take".utf8).write(to: stale)
        try Data("keep".utf8).write(to: unrelated)
        try Data("not created by this recorder".utf8).write(to: unknownAudio)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let recorder = PracticeRecorder(directory: root, notifications: NotificationCenter()) { callback in
            XCTFail("Initialization must not request microphone permission")
            callback(false)
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unknownAudio.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: nested.path))
        XCTAssertFalse(recorder.hasRecording)
        XCTAssertNil(recorder.recordedReference)
    }

    func testUnavailableStorageDoesNotAskForMicrophonePermission() async throws {
        let root = try directory()
        let blockedDirectory = root.appendingPathComponent("storage-is-a-file")
        try Data("keep this file".utf8).write(to: blockedDirectory)
        let noPrompt = expectation(description: "No microphone request when storage is unavailable")
        noPrompt.isInverted = true
        let recorder = PracticeRecorder(directory: blockedDirectory, notifications: NotificationCenter()) { callback in
            noPrompt.fulfill()
            callback(false)
        }
        recorder.beginRecording(reference: try reference())
        await fulfillment(of: [noPrompt], timeout: 0.1)

        XCTAssertFalse(recorder.isRequestingPermission)
        XCTAssertFalse(recorder.isRecording)
        XCTAssertNotNil(recorder.errorMessage)
        XCTAssertEqual(try Data(contentsOf: blockedDirectory), Data("keep this file".utf8))
    }

    func testImmediateStopCancelsPermissionBeforeTheTaskStarts() async throws {
        let noPrompt = expectation(description: "An immediately abandoned take must not open permission")
        noPrompt.isInverted = true
        let recorder = PracticeRecorder(directory: try directory(), notifications: NotificationCenter()) { callback in
            noPrompt.fulfill()
            callback(false)
        }
        recorder.beginRecording(reference: try reference())
        XCTAssertTrue(recorder.isRequestingPermission, "The button action must reserve its state immediately")
        recorder.stopAll()
        await fulfillment(of: [noPrompt], timeout: 0.1)

        XCTAssertFalse(recorder.isRequestingPermission)
        XCTAssertFalse(recorder.isRecording)
        XCTAssertFalse(recorder.hasRecording)
        XCTAssertFalse(recorder.permissionDenied)
        XCTAssertNil(recorder.errorMessage)
    }

    func testLatePermissionDenialAfterLeavingDoesNotReplaceState() async throws {
        let requested = expectation(description: "Permission callback was captured")
        var completion: (@Sendable (Bool) -> Void)?
        let recorder = PracticeRecorder(directory: try directory(), notifications: NotificationCenter()) { callback in
            completion = callback
            requested.fulfill()
        }
        recorder.beginRecording(reference: try reference())
        await fulfillment(of: [requested], timeout: 2)
        recorder.stopAll()

        let noDenial = expectation(description: "An obsolete denial is ignored")
        noDenial.isInverted = true
        let subscription = recorder.$permissionDenied.dropFirst().filter { $0 }.sink { _ in noDenial.fulfill() }
        defer { subscription.cancel() }
        let reply = try XCTUnwrap(completion)
        reply(false)
        await fulfillment(of: [noDenial], timeout: 0.1)

        XCTAssertFalse(recorder.isRequestingPermission)
        XCTAssertFalse(recorder.isRecording)
        XCTAssertFalse(recorder.permissionDenied)
        XCTAssertNil(recorder.errorMessage)
        XCTAssertNil(recorder.recordedReference)
    }

    func testOldPermissionReplyCannotClearANewerRequest() async throws {
        let firstRequested = expectation(description: "First request entered the permission boundary")
        let secondRequested = expectation(description: "Second request entered the permission boundary")
        var completions: [@Sendable (Bool) -> Void] = []
        let recorder = PracticeRecorder(directory: try directory(), notifications: NotificationCenter()) { callback in
            completions.append(callback)
            if completions.count == 1 { firstRequested.fulfill() }
            else if completions.count == 2 { secondRequested.fulfill() }
            else { XCTFail("Unexpected additional permission request") }
        }
        recorder.beginRecording(reference: try reference())
        // Wait for the first request before invalidating it. Yielding alone is
        // not an assertion that the boundary has actually been reached.
        await fulfillment(of: [firstRequested], timeout: 2)
        recorder.stopAll()
        recorder.beginRecording(reference: try reference(2))
        await fulfillment(of: [secondRequested], timeout: 2)
        XCTAssertEqual(completions.count, 2)

        let remainsPending = expectation(description: "Old request must not dismiss the new permission state")
        remainsPending.isInverted = true
        let pending = recorder.$isRequestingPermission.dropFirst().filter { !$0 }.sink { _ in remainsPending.fulfill() }
        completions[0](false)
        await fulfillment(of: [remainsPending], timeout: 0.1)
        pending.cancel()
        XCTAssertTrue(recorder.isRequestingPermission)
        XCTAssertFalse(recorder.permissionDenied)
        XCTAssertNil(recorder.errorMessage)

        let denied = expectation(description: "The current denial completes the current request")
        let denial = recorder.$permissionDenied.filter { $0 }.first().sink { _ in denied.fulfill() }
        completions[1](false)
        await fulfillment(of: [denied], timeout: 2)
        denial.cancel()
        XCTAssertFalse(recorder.isRequestingPermission)
        XCTAssertTrue(recorder.permissionDenied)
        XCTAssertNotNil(recorder.errorMessage)
        XCTAssertFalse(recorder.hasRecording)
    }

    func testRepeatedBeginWhilePendingDoesNotCreateAnotherRequest() async throws {
        let requested = expectation(description: "One permission request")
        let noSecondRequest = expectation(description: "Repeated begin must not ask again")
        noSecondRequest.isInverted = true
        var callbacks: [@Sendable (Bool) -> Void] = []
        let recorder = PracticeRecorder(directory: try directory(), notifications: NotificationCenter()) { callback in
            callbacks.append(callback)
            if callbacks.count == 1 { requested.fulfill() }
            else {
                noSecondRequest.fulfill()
                callback(false)
            }
        }
        recorder.beginRecording(reference: try reference())
        await fulfillment(of: [requested], timeout: 2)
        recorder.beginRecording(reference: try reference(2))
        await fulfillment(of: [noSecondRequest], timeout: 0.1)
        XCTAssertEqual(callbacks.count, 1)
        XCTAssertTrue(recorder.isRequestingPermission)

        let denied = expectation(description: "The initial request is still current")
        let subscription = recorder.$permissionDenied.filter { $0 }.first().sink { _ in denied.fulfill() }
        callbacks[0](false)
        await fulfillment(of: [denied], timeout: 2)
        subscription.cancel()
        XCTAssertFalse(recorder.isRequestingPermission)
        XCTAssertFalse(recorder.isRecording)
    }

    func testMissingTakeCannotBeReplayedOrUploaded() throws {
        let recorder = PracticeRecorder(directory: try directory(), notifications: NotificationCenter()) { callback in
            XCTFail("A missing take must not request microphone permission")
            callback(false)
        }
        recorder.playRecording()
        XCTAssertFalse(recorder.isPlaying)
        XCTAssertEqual(recorder.elapsedRecordingTime, 0, "The recording clock is inactive without a take")
        XCTAssertThrowsError(try recorder.recordingData()) { error in
            guard case PracticeRecorder.RecordingDataError.missingRecording = error else {
                return XCTFail("Expected a missing recording error, got \(error)")
            }
        }
        XCTAssertTrue(recorder.deleteRecording())
        XCTAssertTrue(recorder.deleteRecording(), "Deleting an absent take is idempotent")
        XCTAssertFalse(recorder.hasRecording)
        XCTAssertNil(recorder.recordedReference)
    }

    func testInterruptionCancelsPendingMicrophonePermission() async throws {
        try await assertPendingPermissionCancelled(
            by: AVAudioSession.interruptionNotification,
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )
    }

    func testHeadphoneDisconnectCancelsPendingMicrophonePermission() async throws {
        try await assertPendingPermissionCancelled(
            by: AVAudioSession.routeChangeNotification,
            userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue]
        )
    }

    func testMediaServicesLossAndResetCancelPendingPermissionWithoutRestarting() async throws {
        try await assertPendingPermissionCancelled(
            by: AVAudioSession.mediaServicesWereLostNotification, userInfo: [:], thenReset: true
        )
    }

    func testMediaServicesResetCancelsPendingPermissionWithoutRestarting() async throws {
        try await assertPendingPermissionCancelled(by: AVAudioSession.mediaServicesWereResetNotification, userInfo: [:])
    }

    private func assertPendingPermissionCancelled(
        by name: Notification.Name, userInfo: [AnyHashable: Any], thenReset: Bool = false
    ) async throws {
        let notifications = NotificationCenter()
        let requested = expectation(description: "Permission callback reached before audio event")
        var completion: (@Sendable (Bool) -> Void)?
        let recorder = PracticeRecorder(directory: try directory(), notifications: notifications) { callback in
            completion = callback
            requested.fulfill()
        }
        recorder.beginRecording(reference: try reference())
        await fulfillment(of: [requested], timeout: 2)
        notifications.post(name: name, object: AVAudioSession.sharedInstance(), userInfo: userInfo)
        XCTAssertFalse(recorder.isRequestingPermission)
        XCTAssertFalse(recorder.isRecording)
        XCTAssertEqual(recorder.elapsedRecordingTime, 0, "An interrupted permission request must not leave a running clock")
        if thenReset {
            notifications.post(name: AVAudioSession.mediaServicesWereResetNotification, object: AVAudioSession.sharedInstance())
            XCTAssertFalse(recorder.isRequestingPermission)
            XCTAssertFalse(recorder.isRecording)
            XCTAssertFalse(recorder.hasRecording)
        }

        let noLateDenial = expectation(description: "Audio-event cancellation invalidates the permission result")
        noLateDenial.isInverted = true
        let subscription = recorder.$permissionDenied.dropFirst().filter { $0 }.sink { _ in noLateDenial.fulfill() }
        defer { subscription.cancel() }
        let reply = try XCTUnwrap(completion)
        reply(false)
        await fulfillment(of: [noLateDenial], timeout: 0.1)
        XCTAssertFalse(recorder.permissionDenied)
        XCTAssertNil(recorder.errorMessage)
        XCTAssertFalse(recorder.hasRecording)
    }
}
