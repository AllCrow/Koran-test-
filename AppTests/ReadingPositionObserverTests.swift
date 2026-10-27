import Combine
import QuranCore
import SwiftUI
import UIKit
import XCTest
@testable import Sakina

@MainActor
final class ReadingPositionObserverTests: XCTestCase {
    private struct Fixture {
        let window: UIWindow
        let scroll: UIScrollView
        let observer: ReadingPositionObserver
    }

    private func fixture() -> Fixture {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        let controller = UIViewController()
        window.rootViewController = controller
        let scroll = UIScrollView(frame: CGRect(x: 10, y: 20, width: 300, height: 400))
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.contentInset = UIEdgeInsets(top: 40, left: 0, bottom: 30, right: 0)
        scroll.contentSize = CGSize(width: 300, height: 2_000)
        scroll.contentOffset = CGPoint(x: 0, y: -40)
        controller.view.addSubview(scroll)
        window.isHidden = false
        window.layoutIfNeeded()
        let observer = ReadingPositionObserver()
        observer.activate(surahID: 2)
        addTeardownBlock {
            await MainActor.run {
                observer.deactivate()
                window.isHidden = true
            }
        }
        return Fixture(window: window, scroll: scroll, observer: observer)
    }

    private func probe(_ verse: Int, surah: Int = 2, y: CGFloat = 0,
                       fixture: Fixture) throws -> ReadingPositionProbeView {
        let view = ReadingPositionProbeView(frame: CGRect(x: 0, y: y, width: 300, height: 200))
        view.configure(reference: try XCTUnwrap(AyahReference(surahID: surah, ayahNumber: verse)), observer: fixture.observer)
        fixture.scroll.addSubview(view)
        view.setNeedsLayout()
        view.layoutIfNeeded()
        return view
    }

    func testNativeCoordinatesExcludeAdjustedInsetsAndProgrammaticOffsetsNeverGrantIntent() async throws {
        let fixture = fixture()
        let initial = expectation(description: "Measured actual mounted row")
        let moved = expectation(description: "Observed native programmatic offset")
        var initialSnapshot: ReadingPositionObserver.Snapshot?
        var movedSnapshot: ReadingPositionObserver.Snapshot?
        var intentEvents = 0
        let subscription = fixture.observer.snapshots.sink { snapshot in
            if snapshot.userDragBegan { intentEvents += 1 }
            guard let first = snapshot.frames.first(where: { $0.reference.ayahNumber == 1 }) else { return }
            if abs(first.minY) < 0.001, initialSnapshot == nil {
                initialSnapshot = snapshot
                initial.fulfill()
            }
            if abs(first.minY + 140) < 0.001, movedSnapshot == nil {
                movedSnapshot = snapshot
                moved.fulfill()
            }
        }
        let first = try probe(1, fixture: fixture)
        let second = try probe(2, y: 216, fixture: fixture)
        await fulfillment(of: [initial], timeout: 2)
        let initialValue = try XCTUnwrap(initialSnapshot)
        XCTAssertEqual(initialValue.height, 330, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(initialValue.frames.first).maxY, 200, accuracy: 0.001)

        // The adjusted viewport stays at global y60...390 while the content
        // moves. A programmatic jump must never masquerade as a native drag.
        fixture.scroll.setContentOffset(CGPoint(x: 0, y: 100), animated: false)
        await fulfillment(of: [moved], timeout: 2)
        let movedValue = try XCTUnwrap(movedSnapshot)
        XCTAssertEqual(movedValue.height, 330, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(movedValue.frames.first).maxY, 60, accuracy: 0.001)
        XCTAssertEqual(intentEvents, 0)
        XCTAssertFalse(movedValue.userDragBegan)
        withExtendedLifetime((fixture.window, subscription, first, second)) {}
    }

    func testRowsInsideHiddenReusedContainersAreExcludedAndCanBecomeVisibleAgain() async throws {
        let fixture = fixture()
        let mounted = expectation(description: "Both rows are actually mounted")
        let hidden = expectation(description: "Hidden ancestor invalidates only its row")
        let visibleAgain = expectation(description: "Unhidden native row becomes measurable again")
        let firstReference = try XCTUnwrap(AyahReference(surahID: 2, ayahNumber: 1))
        let secondReference = try XCTUnwrap(AyahReference(surahID: 2, ayahNumber: 2))
        var phase = 0
        var initiallySeen = false
        var hiddenSeen = false
        var visibleSeen = false
        let subscription = fixture.observer.snapshots.sink { snapshot in
            XCTAssertFalse(snapshot.userDragBegan)
            let references = Set(snapshot.frames.map(\.reference))
            if phase == 0, references == [firstReference, secondReference], !initiallySeen {
                initiallySeen = true
                mounted.fulfill()
            } else if phase == 1, references == [firstReference], !hiddenSeen {
                hiddenSeen = true
                hidden.fulfill()
            } else if phase == 2, references == [firstReference, secondReference], !visibleSeen {
                visibleSeen = true
                visibleAgain.fulfill()
            }
        }
        let first = try probe(1, fixture: fixture)
        let container = UIView(frame: CGRect(x: 0, y: 216, width: 300, height: 200))
        let second = ReadingPositionProbeView(frame: container.bounds)
        second.configure(reference: secondReference, observer: fixture.observer)
        fixture.scroll.addSubview(container)
        container.addSubview(second)
        second.setNeedsLayout()
        second.layoutIfNeeded()
        await fulfillment(of: [mounted], timeout: 2)
        phase = 1
        container.isHidden = true
        fixture.scroll.contentOffset = CGPoint(x: 0, y: 0)
        await fulfillment(of: [hidden], timeout: 2)
        phase = 2
        container.isHidden = false
        fixture.scroll.contentOffset = CGPoint(x: 0, y: 10)
        await fulfillment(of: [visibleAgain], timeout: 2)
        XCTAssertTrue(initiallySeen && hiddenSeen && visibleSeen)
        withExtendedLifetime((fixture.window, subscription, first, second, container)) {}
    }

    func testDetachedRowsDisappearFromTheNextCoherentSnapshot() async throws {
        let fixture = fixture()
        let mounted = expectation(description: "Mounted row registered")
        let removed = expectation(description: "Detached row invalidated")
        var hadMounted = false
        var detachedSnapshot: ReadingPositionObserver.Snapshot?
        let subscription = fixture.observer.snapshots.sink { snapshot in
            if !hadMounted, snapshot.frames.count == 1 {
                hadMounted = true
                mounted.fulfill()
            } else if hadMounted, snapshot.frames.isEmpty, detachedSnapshot == nil {
                detachedSnapshot = snapshot
                removed.fulfill()
            }
        }
        let view = try probe(1, fixture: fixture)
        await fulfillment(of: [mounted], timeout: 2)
        view.removeFromSuperview()
        await fulfillment(of: [removed], timeout: 2)
        XCTAssertFalse(try XCTUnwrap(detachedSnapshot).userDragBegan)
        withExtendedLifetime((fixture.window, subscription, view)) {}
    }

    func testChapterReplacementRejectsStaleRowRegistrationsAndOldOffsetCallbacks() async throws {
        let fixture = fixture()
        let firstMounted = expectation(description: "Original chapter mounted")
        let newMounted = expectation(description: "New chapter mounted without stale rows")
        var oldSeen = false
        var newSnapshot: ReadingPositionObserver.Snapshot?
        var afterReplacement = false
        var staleAfterReplacement = false
        let subscription = fixture.observer.snapshots.sink { snapshot in
            if !oldSeen, snapshot.frames.contains(where: { $0.reference.surahID == 2 }) {
                oldSeen = true
                firstMounted.fulfill()
            }
            if afterReplacement, snapshot.frames.contains(where: { $0.reference.surahID == 2 }) {
                staleAfterReplacement = true
            }
            if snapshot.frames.contains(where: { $0.reference.surahID == 3 }), newSnapshot == nil {
                newSnapshot = snapshot
                newMounted.fulfill()
            }
            XCTAssertFalse(snapshot.userDragBegan)
        }
        let old = try probe(1, fixture: fixture)
        await fulfillment(of: [firstMounted], timeout: 2)
        // Queue a genuine native offset notification immediately before
        // replacing its lifecycle generation; that callback must be rejected.
        fixture.scroll.contentOffset = CGPoint(x: 0, y: 30)
        afterReplacement = true
        fixture.observer.activate(surahID: 3)
        old.configure(reference: try XCTUnwrap(AyahReference(surahID: 2, ayahNumber: 1)), observer: fixture.observer)
        let new = try probe(1, surah: 3, fixture: fixture)
        await fulfillment(of: [newMounted], timeout: 2)
        XCTAssertFalse(staleAfterReplacement)
        XCTAssertEqual(try XCTUnwrap(newSnapshot).frames.map(\.reference.surahID), [3])
        withExtendedLifetime((fixture.window, subscription, old, new)) {}
    }

    func testDeactivationRejectsAlreadyQueuedRegistrationAndOffsetWork() async throws {
        let fixture = fixture()
        let drained = expectation(description: "Queued main-loop work drained")
        var receivedAfterDeactivation = 0
        var deactivated = false
        let subscription = fixture.observer.snapshots.sink { _ in
            if deactivated { receivedAfterDeactivation += 1 }
        }
        let view = try probe(1, fixture: fixture)
        fixture.scroll.contentOffset = CGPoint(x: 0, y: 90)
        fixture.observer.deactivate()
        deactivated = true
        // Bounded queue drainage, not a timing assertion or a fake pan event.
        DispatchQueue.main.async {
            DispatchQueue.main.async { drained.fulfill() }
        }
        await fulfillment(of: [drained], timeout: 2)
        XCTAssertEqual(receivedAfterDeactivation, 0)
        withExtendedLifetime((fixture.window, subscription, view)) {}
    }

    func testActualSwiftUIListCellsRegisterTheirNativeScrollAncestorAndWholeVerseFrame() async throws {
        let observer = ReadingPositionObserver()
        observer.activate(surahID: 2)
        let references = try (1...4).map { try XCTUnwrap(AyahReference(surahID: 2, ayahNumber: $0)) }
        let firstReference = try XCTUnwrap(references.first)
        let measured = expectation(description: "Actual SwiftUI List row registered through its native hierarchy")
        var measuredSnapshot: ReadingPositionObserver.Snapshot?
        let subscription = observer.snapshots.sink { snapshot in
            guard measuredSnapshot == nil, snapshot.height.isFinite, snapshot.height > 0,
                  let first = snapshot.frames.first(where: { $0.reference == firstReference }),
                  first.minY.isFinite, first.maxY.isFinite,
                  first.minY >= 0, first.maxY <= snapshot.height,
                  first.maxY - first.minY >= 199 else { return }
            measuredSnapshot = snapshot
            measured.fulfill()
        }
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        let host = UIHostingController(rootView: ReadingPositionListFixture(references: references, observer: observer))
        window.rootViewController = host
        window.isHidden = false
        window.setNeedsLayout()
        window.layoutIfNeeded()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        addTeardownBlock {
            await MainActor.run {
                observer.deactivate()
                window.isHidden = true
                window.rootViewController = nil
            }
        }

        await fulfillment(of: [measured], timeout: 5)
        let snapshot = try XCTUnwrap(measuredSnapshot)
        let first = try XCTUnwrap(snapshot.frames.first(where: { $0.reference == firstReference }))
        XCTAssertEqual(first.reference, firstReference)
        XCTAssertGreaterThan(snapshot.height, 0)
        XCTAssertEqual(first.maxY - first.minY, 200, accuracy: 0.5,
                       "The probe must measure the whole row content, not a badge or estimated scroll offset")
        XCTAssertFalse(snapshot.userDragBegan, "Mounting an actual List must not create user scroll intent")
        XCTAssertEqual(ReadingViewport.leadingReference(in: snapshot.frames, surahID: 2, height: snapshot.height), firstReference)
        withExtendedLifetime((window, host, subscription)) {}
    }

    func testChapterAnchorBindsBeforeAnyVerseExistsWithoutFabricatingAReadingPosition() async throws {
        let fixture = fixture()
        let anchored = expectation(description: "Binding-only chapter heading registered")
        let offsetDrained = expectation(description: "Programmatic anchor-only offset drained")
        let verseJoined = expectation(description: "A real verse joins the already bound native source")
        let secondReference = try XCTUnwrap(AyahReference(surahID: 2, ayahNumber: 2))
        var anchorSnapshot: ReadingPositionObserver.Snapshot?
        var joinedSnapshot: ReadingPositionObserver.Snapshot?
        var fabricatedVerse = false
        var intentEvents = 0
        var hasVerse = false
        let subscription = fixture.observer.snapshots.sink { snapshot in
            if snapshot.userDragBegan { intentEvents += 1 }
            if !hasVerse, !snapshot.frames.isEmpty { fabricatedVerse = true }
            if snapshot.height == 330, snapshot.frames.isEmpty, anchorSnapshot == nil {
                anchorSnapshot = snapshot
                anchored.fulfill()
            }
            if snapshot.frames.contains(where: { $0.reference == secondReference }), joinedSnapshot == nil {
                joinedSnapshot = snapshot
                verseJoined.fulfill()
            }
        }
        let anchor = ReadingPositionProbeView(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
        anchor.configureAnchor(surahID: 2, observer: fixture.observer)
        fixture.scroll.addSubview(anchor)
        anchor.setNeedsLayout()
        anchor.layoutIfNeeded()
        await fulfillment(of: [anchored], timeout: 2)
        XCTAssertNil(ReadingViewport.leadingReference(in: try XCTUnwrap(anchorSnapshot).frames, surahID: 2, height: 330),
                     "A chapter heading must never be represented as verse one")

        fixture.scroll.setContentOffset(CGPoint(x: 0, y: 150), animated: false)
        DispatchQueue.main.async {
            DispatchQueue.main.async { offsetDrained.fulfill() }
        }
        await fulfillment(of: [offsetDrained], timeout: 2)
        XCTAssertFalse(fabricatedVerse)
        XCTAssertEqual(intentEvents, 0, "An anchor-only programmatic offset must not grant user intent")

        hasVerse = true
        let verse = try probe(2, y: 216, fixture: fixture)
        await fulfillment(of: [verseJoined], timeout: 2)
        let snapshot = try XCTUnwrap(joinedSnapshot)
        XCTAssertEqual(snapshot.frames.map(\.reference), [secondReference])
        XCTAssertEqual(try XCTUnwrap(snapshot.frames.first).minY, 26, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(snapshot.frames.first).maxY, 226, accuracy: 0.001)
        XCTAssertEqual(ReadingViewport.leadingReference(in: snapshot.frames, surahID: 2, height: snapshot.height), secondReference)
        XCTAssertEqual(intentEvents, 0)
        withExtendedLifetime((fixture.window, subscription, anchor, verse)) {}
    }
}

@MainActor
private struct ReadingPositionListFixture: View {
    let references: [AyahReference]
    let observer: ReadingPositionObserver

    var body: some View {
        NavigationStack {
            List {
                ForEach(references) { reference in
                    Text("Vers \(reference.id)")
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .background(ReadingPositionProbe(reference: reference, observer: observer))
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .id(reference.id)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Koranen")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
