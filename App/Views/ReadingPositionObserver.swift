import Combine
import SwiftUI
import UIKit
import QuranCore

/// Observes the reader's existing native scroll view without replacing its
/// delegate or installing another recognizer. Native pan beginnings are the
/// only events that establish fresh user scrolling intent.
@MainActor
final class ReadingPositionObserver: ObservableObject {
    struct Snapshot: Equatable {
        let frames: [ReadingVerseFrame]
        let height: Double
        let userDragBegan: Bool
    }

    let snapshots = PassthroughSubject<Snapshot, Never>()

    private struct Registration {
        weak var view: ReadingPositionProbeView?
        let reference: AyahReference?
        let bindingSurahID: Int
    }

    private var activeSurahID: Int?
    fileprivate private(set) var generation = UUID()
    private var registrations: [UUID: Registration] = [:]
    private weak var scrollView: UIScrollView?
    private var offsetObservation: NSKeyValueObservation?
    private let panTarget = ReadingPositionPanTarget()
    private var bindingID = UUID()
    private var snapshotScheduled = false
    private var pendingUserDragBegan = false
    private var lastSnapshot: Snapshot?

    init() { panTarget.owner = self }

    deinit {
        offsetObservation?.invalidate()
        let target = panTarget
        let scroll = scrollView
        // UIKit cleanup stays on its actor even if the last owner releases
        // this object from another context. The target holds its owner weakly.
        DispatchQueue.main.async { [weak scroll, target] in
            scroll?.panGestureRecognizer.removeTarget(target, action: #selector(ReadingPositionPanTarget.changed(_:)))
        }
    }

    func activate(surahID: Int?) {
        let valid = surahID.flatMap { (1...AyahReference.ayahCounts.count).contains($0) ? $0 : nil }
        guard activeSurahID != valid else { return }
        reset()
        activeSurahID = valid
        if valid != nil { scheduleSnapshot() }
    }

    func deactivate() {
        reset()
        activeSurahID = nil
    }

    /// An explicit reader action revokes a pan event still queued for the next
    /// main-loop delivery. Later content-offset callbacks never restore it.
    func discardPendingUserDrag() { pendingUserDragBegan = false }

    private func reset() {
        generation = UUID()
        detachScrollView()
        registrations.removeAll()
        snapshotScheduled = false
        pendingUserDragBegan = false
        lastSnapshot = nil
    }

    fileprivate func register(_ view: ReadingPositionProbeView, reference: AyahReference?, bindingSurahID: Int,
                              token: UUID, generation expectedGeneration: UUID) {
        guard generation == expectedGeneration, activeSurahID == bindingSurahID,
              view.observer === self, view.registrationToken == token,
              view.reference == reference, view.bindingSurahID == bindingSurahID,
              reference == nil || reference?.surahID == bindingSurahID,
              view.window != nil,
              Self.nearestScrollView(to: view) != nil else { return }
        registrations[token] = Registration(view: view, reference: reference, bindingSurahID: bindingSurahID)
        reconcileScrollView(preferred: Self.nearestScrollView(to: view))
        scheduleSnapshot()
    }

    fileprivate func unregister(token: UUID) {
        guard registrations.removeValue(forKey: token) != nil else { return }
        reconcileScrollView()
        scheduleSnapshot()
    }

    fileprivate static func nearestScrollView(to view: UIView) -> UIScrollView? {
        var ancestor = view.superview
        while let candidate = ancestor {
            if let scroll = candidate as? UIScrollView { return scroll }
            ancestor = candidate.superview
        }
        return nil
    }

    private func validView(for token: UUID, registration: Registration) -> ReadingPositionProbeView? {
        guard let view = registration.view, view.observer === self,
              view.registrationToken == token, view.reference == registration.reference,
              view.bindingSurahID == registration.bindingSurahID,
              registration.bindingSurahID == activeSurahID,
              view.window != nil else { return nil }
        return view
    }

    private func reconcileScrollView(preferred: UIScrollView? = nil) {
        registrations = registrations.filter { validView(for: $0.key, registration: $0.value) != nil }
        let candidates = registrations.sorted { $0.key.uuidString < $1.key.uuidString }.compactMap { token, registration in
            validView(for: token, registration: registration).flatMap { view in
                Self.isVisibleInHierarchy(view) ? Self.nearestScrollView(to: view) : nil
            }
        }
        let chosen: UIScrollView?
        if let preferred, candidates.contains(where: { $0 === preferred }) {
            chosen = preferred
        } else if let current = scrollView, candidates.contains(where: { $0 === current }) {
            chosen = current
        } else {
            chosen = candidates.first
        }
        guard chosen !== scrollView else { return }
        detachScrollView()
        guard let chosen, chosen.window != nil else { return }
        scrollView = chosen
        let expectedBinding = bindingID
        let expectedGeneration = generation
        chosen.panGestureRecognizer.addTarget(panTarget, action: #selector(ReadingPositionPanTarget.changed(_:)))
        offsetObservation = chosen.observe(\.contentOffset, options: [.new]) { [weak self, weak chosen] _, _ in
            // UIKit normally changes contentOffset on main. The bridge also
            // rejects a delayed callback after a chapter/window replacement.
            Task { @MainActor [weak self, weak chosen] in
                guard let self, let chosen, self.generation == expectedGeneration,
                      self.bindingID == expectedBinding, self.scrollView === chosen else { return }
                self.scheduleSnapshot()
            }
        }
    }

    private func detachScrollView() {
        offsetObservation?.invalidate()
        offsetObservation = nil
        scrollView?.panGestureRecognizer.removeTarget(panTarget, action: #selector(ReadingPositionPanTarget.changed(_:)))
        scrollView = nil
        bindingID = UUID()
        pendingUserDragBegan = false
    }

    fileprivate func panChanged(_ gesture: UIPanGestureRecognizer) {
        guard gesture.state == .began, let scroll = scrollView,
              gesture === scroll.panGestureRecognizer, gesture.view === scroll,
              scroll.window != nil, activeSurahID != nil else { return }
        scheduleSnapshot(userDragBegan: true)
    }

    private func scheduleSnapshot(userDragBegan: Bool = false) {
        guard activeSurahID != nil else { return }
        pendingUserDragBegan = pendingUserDragBegan || userDragBegan
        guard !snapshotScheduled else { return }
        snapshotScheduled = true
        let expectedGeneration = generation
        DispatchQueue.main.async { [weak self] in
            guard let self, self.generation == expectedGeneration else { return }
            self.snapshotScheduled = false
            self.reconcileScrollView()
            let userDragBegan = self.pendingUserDragBegan
            self.pendingUserDragBegan = false
            let snapshot = self.snapshot(userDragBegan: userDragBegan)
            // updateUIView/layout can re-register an unchanged row. Do not
            // turn that lifecycle callback into a publication/render cycle.
            guard snapshot != self.lastSnapshot else { return }
            self.lastSnapshot = snapshot
            self.snapshots.send(snapshot)
        }
    }

    private func snapshot(userDragBegan: Bool) -> Snapshot {
        guard let scroll = scrollView, let window = scroll.window,
              !window.isHidden, Self.isVisibleInHierarchy(scroll) else {
            return Snapshot(frames: [], height: 0, userDragBegan: false)
        }
        let viewport = scroll.convert(scroll.bounds.inset(by: scroll.adjustedContentInset), to: window)
        guard Self.isFiniteNonempty(viewport) else {
            return Snapshot(frames: [], height: 0, userDragBegan: false)
        }
        var frames: [ReadingVerseFrame] = []
        for (token, registration) in registrations {
            // Chapter anchors bind the native source before any verse cell is
            // visible. They never masquerade as a Quran verse or reading place.
            guard let reference = registration.reference,
                  let view = validView(for: token, registration: registration),
                  Self.isVisibleInHierarchy(view), view.window === window, view.isDescendant(of: scroll),
                  Self.nearestScrollView(to: view) === scroll else { continue }
            let frame = view.convert(view.bounds, to: window)
            guard Self.isFiniteNonempty(frame) else { continue }
            frames.append(ReadingVerseFrame(reference: reference,
                                           minY: Double(frame.minY - viewport.minY),
                                           maxY: Double(frame.maxY - viewport.minY)))
        }
        frames.sort {
            $0.minY == $1.minY ? $0.reference.ayahNumber < $1.reference.ayahNumber : $0.minY < $1.minY
        }
        return Snapshot(frames: frames, height: Double(viewport.height), userDragBegan: userDragBegan)
    }

    private static func isVisibleInHierarchy(_ view: UIView) -> Bool {
        var ancestor: UIView? = view
        while let current = ancestor {
            if current.isHidden || current.alpha <= 0.01 { return false }
            ancestor = current.superview
        }
        return view.window != nil
    }

    private static func isFiniteNonempty(_ frame: CGRect) -> Bool {
        !frame.isEmpty && frame.minX.isFinite && frame.maxX.isFinite
            && frame.minY.isFinite && frame.maxY.isFinite
            && frame.width.isFinite && frame.height.isFinite
    }
}

@MainActor
private final class ReadingPositionPanTarget: NSObject {
    weak var owner: ReadingPositionObserver?
    @objc func changed(_ gesture: UIPanGestureRecognizer) { owner?.panChanged(gesture) }
}

@MainActor
struct ReadingPositionProbe: UIViewRepresentable {
    let reference: AyahReference
    let observer: ReadingPositionObserver

    func makeUIView(context: Context) -> ReadingPositionProbeView {
        let view = ReadingPositionProbeView()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        view.accessibilityElementsHidden = true
        view.backgroundColor = .clear
        view.configure(reference: reference, observer: observer)
        return view
    }

    func updateUIView(_ view: ReadingPositionProbeView, context: Context) {
        view.configure(reference: reference, observer: observer)
    }

    static func dismantleUIView(_ view: ReadingPositionProbeView, coordinator: ()) { view.disconnect() }
}

/// A binding-only chapter heading probe keeps the native pan source available
/// when large text fills the viewport before List mounts its first verse cell.
@MainActor
struct ReadingPositionAnchor: UIViewRepresentable {
    let surahID: Int
    let observer: ReadingPositionObserver

    func makeUIView(context: Context) -> ReadingPositionProbeView {
        let view = ReadingPositionProbeView()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        view.accessibilityElementsHidden = true
        view.backgroundColor = .clear
        view.configureAnchor(surahID: surahID, observer: observer)
        return view
    }

    func updateUIView(_ view: ReadingPositionProbeView, context: Context) {
        view.configureAnchor(surahID: surahID, observer: observer)
    }

    static func dismantleUIView(_ view: ReadingPositionProbeView, coordinator: ()) { view.disconnect() }
}

@MainActor
final class ReadingPositionProbeView: UIView {
    fileprivate weak var observer: ReadingPositionObserver?
    fileprivate private(set) var reference: AyahReference?
    fileprivate private(set) var bindingSurahID: Int?
    fileprivate private(set) var registrationToken = UUID()
    private var registrationScheduled = false

    func configure(reference: AyahReference, observer: ReadingPositionObserver) {
        configure(reference: reference, bindingSurahID: reference.surahID, observer: observer)
    }

    func configureAnchor(surahID: Int, observer: ReadingPositionObserver) {
        guard (1...AyahReference.ayahCounts.count).contains(surahID) else { disconnect(); return }
        configure(reference: nil, bindingSurahID: surahID, observer: observer)
    }

    private func configure(reference: AyahReference?, bindingSurahID: Int, observer: ReadingPositionObserver) {
        if self.observer !== observer || self.reference != reference || self.bindingSurahID != bindingSurahID {
            disconnect()
            self.reference = reference
            self.bindingSurahID = bindingSurahID
            self.observer = observer
        }
        scheduleRegistration()
    }

    func disconnect() {
        observer?.unregister(token: registrationToken)
        observer = nil
        reference = nil
        bindingSurahID = nil
        registrationToken = UUID()
        registrationScheduled = false
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { observer?.unregister(token: registrationToken) }
        else { scheduleRegistration() }
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if superview == nil { observer?.unregister(token: registrationToken) }
        else { scheduleRegistration() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scheduleRegistration()
    }

    private func scheduleRegistration() {
        guard !registrationScheduled, let observer, let bindingSurahID else { return }
        registrationScheduled = true
        let configuredReference = reference
        let token = registrationToken
        let generation = observer.generation
        DispatchQueue.main.async { [weak self, weak observer] in
            guard let self, let observer, self.registrationToken == token else { return }
            self.registrationScheduled = false
            guard observer.generation == generation else { return }
            observer.register(self, reference: configuredReference, bindingSurahID: bindingSurahID,
                              token: token, generation: generation)
        }
    }
}
