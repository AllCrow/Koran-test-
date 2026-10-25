import Combine
import Foundation
import QuranCore
import QuranData
import XCTest
@testable import Sakina

/// A cancelled screen restoration must not replace reading that continued later.
/// The loader deliberately ignores cancellation until the test returns a result.
@MainActor
final class ChapterLoadingTests: XCTestCase {
    private enum TestFailure: LocalizedError {
        case unavailable
        var errorDescription: String? { "Kontrollerat laddningsfel" }
    }

    @MainActor
    private final class ControlledLoader {
        struct Request {
            let chapterID: Int
            var continuation: CheckedContinuation<QuranChapter, Error>?
        }

        private(set) var requests: [Request] = []
        var requested: ((Int) -> Void)?

        func load(_ id: Int) async throws -> QuranChapter {
            try await withCheckedThrowingContinuation { continuation in
                requests.append(Request(chapterID: id, continuation: continuation))
                requested?(id)
            }
        }

        func complete(_ index: Int, with result: Result<QuranChapter, Error>) {
            guard requests.indices.contains(index), let continuation = requests[index].continuation else {
                XCTFail("The controlled request must be completed exactly once")
                return
            }
            requests[index].continuation = nil
            continuation.resume(with: result)
        }
    }

    private struct Fixture {
        let store: AppStore
        let storage: UserDefaults
        let loader: ControlledLoader
        let first: QuranChapter
        let second: QuranChapter
        let third: QuranChapter
    }

    private func fixture() async throws -> Fixture {
        let repository = QuranRepository()
        let first = try await repository.loadChapter(id: 1)
        let second = try await repository.loadChapter(id: 2)
        let third = try await repository.loadChapter(id: 3)
        let name = "sakina.chapter-loading.tests.\(UUID().uuidString)"
        let storage = try XCTUnwrap(UserDefaults(suiteName: name))
        addTeardownBlock { storage.removePersistentDomain(forName: name) }
        let loader = ControlledLoader()
        let store = AppStore(repository: repository, defaults: storage, chapterLoader: { id in
            if id == 1 { return first }
            return try await loader.load(id)
        })
        await store.load()
        store.markRead(try XCTUnwrap(AyahReference(surahID: 1, ayahNumber: 1)))
        XCTAssertEqual(store.chapter, first)
        XCTAssertNotNil(storage.data(forKey: "sakina.reading-state.v1"))
        return Fixture(store: store, storage: storage, loader: loader,
                       first: first, second: second, third: third)
    }

    func testAlreadyCancelledOpenHasNoMutationOrLoaderRequest() async throws {
        let fixture = try await fixture()
        let before = fixture.storage.data(forKey: "sakina.reading-state.v1")
        // Inherit this actor: cancellation is set before the task gets a turn.
        let task = Task { await fixture.store.openSurah(2) }
        task.cancel()
        await task.value
        XCTAssertTrue(fixture.loader.requests.isEmpty)
        XCTAssertEqual(fixture.store.selectedSurahID, 1)
        XCTAssertEqual(fixture.store.chapter, fixture.first)
        XCTAssertFalse(fixture.store.isLoading)
        XCTAssertNil(fixture.store.errorMessage)
        XCTAssertEqual(fixture.storage.data(forKey: "sakina.reading-state.v1"), before)
    }

    func testAlreadyCancelledInitialLoadDoesNotPublishIndexOrProgress() async throws {
        let fixture = try await fixture()
        let store = AppStore(defaults: fixture.storage)
        let before = fixture.storage.data(forKey: "sakina.reading-state.v1")
        let task = Task { await store.load() }
        task.cancel()
        await task.value
        XCTAssertNil(store.index)
        XCTAssertNil(store.chapter)
        XCTAssertEqual(store.selectedSurahID, 1)
        XCTAssertFalse(store.isLoading)
        XCTAssertNil(store.errorMessage)
        XCTAssertEqual(fixture.storage.data(forKey: "sakina.reading-state.v1"), before)
    }

    func testCancellationClearsLoadingWithoutWaitingForLoaderAndPreservesSavedBytes() async throws {
        let fixture = try await fixture()
        let before = fixture.storage.data(forKey: "sakina.reading-state.v1")
        let started = expectation(description: "The replacement chapter is being loaded")
        fixture.loader.requested = { id in XCTAssertEqual(id, 2); started.fulfill() }
        let task = Task { await fixture.store.openSurah(2) }
        await fulfillment(of: [started], timeout: 2)
        XCTAssertTrue(fixture.store.isLoading)
        XCTAssertEqual(fixture.store.selectedSurahID, 1)
        XCTAssertEqual(fixture.store.chapter, fixture.first)
        XCTAssertEqual(fixture.storage.data(forKey: "sakina.reading-state.v1"), before)

        let stopped = expectation(description: "Cancellation promptly ends the visible loading state")
        let subscription = fixture.store.$isLoading.dropFirst().first(where: { !$0 }).sink { _ in stopped.fulfill() }
        task.cancel()
        await fulfillment(of: [stopped], timeout: 2)
        subscription.cancel()
        XCTAssertEqual(fixture.store.selectedSurahID, 1)
        XCTAssertEqual(fixture.store.chapter, fixture.first)
        XCTAssertNil(fixture.store.errorMessage)
        XCTAssertEqual(fixture.storage.data(forKey: "sakina.reading-state.v1"), before)

        // A non-cooperative load eventually succeeds after the screen has left.
        fixture.loader.complete(0, with: .success(fixture.second))
        await task.value
        XCTAssertFalse(fixture.store.isLoading)
        XCTAssertEqual(fixture.store.chapter, fixture.first)
        XCTAssertEqual(fixture.storage.data(forKey: "sakina.reading-state.v1"), before)
    }

    func testCancelledLateSuccessOrFailureCannotReplaceNewerCommittedSelection() async throws {
        for oldResultSucceeds in [true, false] {
            let fixture = try await fixture()
            let olderStarted = expectation(description: "The older load starts")
            fixture.loader.requested = { id in XCTAssertEqual(id, 2); olderStarted.fulfill() }
            let older = Task { await fixture.store.openSurah(2) }
            await fulfillment(of: [olderStarted], timeout: 2)

            let newerStarted = expectation(description: "The newer load starts")
            fixture.loader.requested = { id in XCTAssertEqual(id, 3); newerStarted.fulfill() }
            let newer = Task { await fixture.store.openSurah(3) }
            await fulfillment(of: [newerStarted], timeout: 2)
            fixture.loader.complete(1, with: .success(fixture.third))
            await newer.value
            let committed = fixture.storage.data(forKey: "sakina.reading-state.v1")
            XCTAssertEqual(fixture.store.selectedSurahID, 3)
            XCTAssertEqual(fixture.store.chapter, fixture.third)

            older.cancel()
            fixture.loader.complete(0, with: oldResultSucceeds
                ? .success(fixture.second) : .failure(TestFailure.unavailable))
            await older.value
            XCTAssertEqual(fixture.store.selectedSurahID, 3)
            XCTAssertEqual(fixture.store.chapter, fixture.third)
            XCTAssertFalse(fixture.store.isLoading)
            XCTAssertNil(fixture.store.errorMessage)
            XCTAssertEqual(fixture.storage.data(forKey: "sakina.reading-state.v1"), committed)
        }
    }

    func testCancelledOlderLoadDoesNotClearNewerLoadingOrPublishLateResults() async throws {
        for oldResultSucceeds in [true, false] {
            let fixture = try await fixture()
            let before = fixture.storage.data(forKey: "sakina.reading-state.v1")
            let olderStarted = expectation(description: "The older load starts")
            fixture.loader.requested = { _ in olderStarted.fulfill() }
            let older = Task { await fixture.store.openSurah(2) }
            await fulfillment(of: [olderStarted], timeout: 2)
            let newerStarted = expectation(description: "The newer load starts")
            fixture.loader.requested = { _ in newerStarted.fulfill() }
            let newer = Task { await fixture.store.openSurah(3) }
            await fulfillment(of: [newerStarted], timeout: 2)

            older.cancel()
            fixture.loader.complete(0, with: oldResultSucceeds
                ? .success(fixture.second) : .failure(TestFailure.unavailable))
            await older.value
            XCTAssertTrue(fixture.store.isLoading, "The newer request is still pending")
            XCTAssertEqual(fixture.store.selectedSurahID, 1)
            XCTAssertEqual(fixture.store.chapter, fixture.first)
            XCTAssertNil(fixture.store.errorMessage)
            XCTAssertEqual(fixture.storage.data(forKey: "sakina.reading-state.v1"), before)

            fixture.loader.complete(1, with: .success(fixture.third))
            await newer.value
            XCTAssertFalse(fixture.store.isLoading)
            XCTAssertEqual(fixture.store.selectedSurahID, 3)
            XCTAssertEqual(fixture.store.chapter, fixture.third)
        }
    }

    func testFailureKeepsRetryTargetAndCancelledReplacementKeepsPriorError() async throws {
        let fixture = try await fixture()
        let failedStarted = expectation(description: "The selected chapter starts loading")
        fixture.loader.requested = { id in XCTAssertEqual(id, 2); failedStarted.fulfill() }
        let failed = Task { await fixture.store.openSurah(2) }
        await fulfillment(of: [failedStarted], timeout: 2)
        fixture.loader.complete(0, with: .failure(TestFailure.unavailable))
        await failed.value
        XCTAssertEqual(fixture.store.selectedSurahID, 2)
        XCTAssertNil(fixture.store.chapter)
        XCTAssertFalse(fixture.store.isLoading)
        XCTAssertEqual(fixture.store.errorMessage, TestFailure.unavailable.localizedDescription)
        let failedState = fixture.storage.data(forKey: "sakina.reading-state.v1")

        let replacementStarted = expectation(description: "Another chapter starts loading")
        fixture.loader.requested = { id in XCTAssertEqual(id, 3); replacementStarted.fulfill() }
        let replacement = Task { await fixture.store.openSurah(3) }
        await fulfillment(of: [replacementStarted], timeout: 2)
        XCTAssertEqual(fixture.store.selectedSurahID, 2)
        XCTAssertNil(fixture.store.chapter)
        XCTAssertEqual(fixture.store.errorMessage, TestFailure.unavailable.localizedDescription)
        let cancelled = expectation(description: "The replacement is visibly cancelled")
        let subscription = fixture.store.$isLoading.dropFirst().first(where: { !$0 }).sink { _ in cancelled.fulfill() }
        replacement.cancel()
        await fulfillment(of: [cancelled], timeout: 2)
        subscription.cancel()
        fixture.loader.complete(1, with: .success(fixture.third))
        await replacement.value
        XCTAssertEqual(fixture.storage.data(forKey: "sakina.reading-state.v1"), failedState)

        let retryStarted = expectation(description: "Retry uses the actual failed target")
        fixture.loader.requested = { id in XCTAssertEqual(id, 2); retryStarted.fulfill() }
        let retry = Task { await fixture.store.load() }
        await fulfillment(of: [retryStarted], timeout: 2)
        XCTAssertEqual(fixture.store.errorMessage, TestFailure.unavailable.localizedDescription)
        fixture.loader.complete(2, with: .success(fixture.second))
        await retry.value
        XCTAssertEqual(fixture.store.selectedSurahID, 2)
        XCTAssertEqual(fixture.store.chapter, fixture.second)
        XCTAssertNil(fixture.store.errorMessage)
        XCTAssertFalse(fixture.store.isLoading)
    }
}
