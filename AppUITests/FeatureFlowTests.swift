import Foundation
import XCTest

/// Actual UI interactions with isolated, explicitly Debug-only local audio.
/// No network, microphone, account, signing material or private recording is used.
@MainActor
final class FeatureFlowTests: XCTestCase {
    private var app: XCUIApplication!
    private var suite: String!

    override func setUp() async throws {
        await MainActor.run {
            continueAfterFailure = false
            suite = "sakina.uitests.\(UUID().uuidString)"
            app = XCUIApplication()
            app.launchArguments = ["--ui-test-suite", suite, "-AppleLanguages", "(sv)", "-AppleLocale", "sv_SE"]
            if name.contains("testSavedAudioLibrary") {
                app.launchArguments.append("--ui-test-audio-fixture")
            }
            app.launch()
            XCTAssertTrue(app.tabBars.buttons["Mitt"].waitForExistence(timeout: 10))
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            app?.terminate()
            app = nil
        }
    }

    func testWifiAudioChoicePersistsAndDiagnosticPreviewContainsOnlyStatus() throws {
        app.tabBars.buttons["Mitt"].tap()
        let choice = app.switches["settings.audioCellular"]
        scrollFullyIntoView(choice)
        XCTAssertEqual(choice.value as? String, "1")
        // SwiftUI can expose the labelled row as the switch frame. Operate the
        // trailing real control after the entire row is within the viewport.
        choice.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertTrue(waitForValue("0", on: choice))
        relaunch()
        app.tabBars.buttons["Mitt"].tap()
        let restored = app.switches["settings.audioCellular"]
        scrollFullyIntoView(restored)
        XCTAssertEqual(restored.value as? String, "0", "The explicit Wi-Fi choice must survive relaunch")

        openSettingsLink("settings.diagnostics")
        let create = app.buttons["diagnostics.create"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        XCTAssertEqual(create.label, "Skapa rapport", "A report must be created only by the explicit action")
        XCTAssertFalse(element("diagnostics.preview").exists, "Opening support must not create a report")
        tapContent(create)
        let disclosure = app.buttons["Visa hela rapporten"]
        tapContent(disclosure)
        let preview = element("diagnostics.preview")
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        // This is a potentially tall, read-only JSON label. The disclosure and
        // export remain real fully visible controls; its complete label is parsed.
        let payload = try XCTUnwrap(preview.label.data(using: .utf8))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])
        XCTAssertEqual(Set(json.keys), Set(["schema_version", "app_version", "app_build", "platform",
            "device_family", "system_version", "audio", "practice", "services", "storage"]))
        let audio = try XCTUnwrap(json["audio"] as? [String: Any])
        XCTAssertEqual(audio["allows_cellular_audio"] as? Bool, false)
        let serialized = preview.label
        for forbidden in ["surahID", "ayahNumber", "lastRead", "bookmarks", "file://", "http://", "https://", "api_key"] {
            XCTAssertFalse(serialized.contains(forbidden), "Status reports must not expose \(forbidden)")
        }
        attachScreenshot("Diagnostics-reviewed-status-only")
        let export = app.buttons["diagnostics.export"]
        scrollFullyIntoView(export)
        XCTAssertTrue(export.isEnabled, "The reviewed report must be offered for an explicit Files export")
        // The device's Files provider and actual external sharing remain physical checks.
        assertNoReadingCredit()
    }

    func testPracticeQueueSurvivesRelaunchAndManualRemovalWithoutReadingCredit() {
        app.tabBars.buttons["Koranen"].tap()
        let badge = element("reader.verse.1.1")
        XCTAssertTrue(badge.waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntilReadableBadgeIsInsideReader("reader.verse.1.1"))
        // The badge is read-only text. iOS26 can omit its accessibility
        // activation point although its complete frame is visible. Long-press
        // that verified point to operate the card's actual context menu.
        badge.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 1.1)
        let enqueue = app.buttons["reader.practiceQueue.1.1"]
        XCTAssertTrue(enqueue.waitForExistence(timeout: 5))
        XCTAssertTrue(enqueue.isHittable)
        enqueue.tap()
        assertNoReadingCredit()

        app.tabBars.buttons["Mitt"].tap()
        openSettingsLink("settings.practiceQueue")
        let row = app.buttons["queue.select.1.1"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        tapContent(row)
        XCTAssertTrue(app.staticTexts["practice.reference.1.1"].waitForExistence(timeout: 5),
                      "Choosing a queued verse must open that exact practice reference")
        attachScreenshot("Practice-queued-reference")
        let back = app.navigationBars["Öva"].buttons.firstMatch
        XCTAssertTrue(back.exists && back.isHittable)
        back.tap()
        XCTAssertTrue(app.buttons["queue.select.1.1"].waitForExistence(timeout: 5))

        relaunch()
        app.tabBars.buttons["Mitt"].tap()
        openSettingsLink("settings.practiceQueue")
        XCTAssertTrue(app.buttons["queue.select.1.1"].waitForExistence(timeout: 5))
        tapContent(app.buttons["queue.remove.1.1"])
        XCTAssertTrue(app.staticTexts["Din övningskö är tom"].waitForExistence(timeout: 5))
        attachScreenshot("Practice-queue-removed")
        assertNoReadingCredit()
    }

    func testRepetitionRangeConfigurationStartsPausesAndStopsFromRealControls() {
        app.tabBars.buttons["Koranen"].tap()
        let settings = app.buttons["Läsinställningar"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        let present = app.buttons["reader.repeat.present"]
        XCTAssertTrue(present.waitForExistence(timeout: 5))
        present.tap()
        XCTAssertTrue(app.navigationBars["Repetera verser"].waitForExistence(timeout: 5))

        // Raising the start must also raise the end; an inverted range must
        // never be selectable or passed to the actual start action.
        chooseRepeatOption(picker: "repeat.start", option: "repeat.start.option.3", label: "Vers 3")
        XCTAssertTrue(waitForValue("Vers 3", on: app.buttons["repeat.start"]))
        let end = app.buttons["repeat.end"]
        XCTAssertTrue(waitForValue("Vers 3", on: end))
        tapContent(end)
        XCTAssertFalse(app.buttons["repeat.end.option.2"].exists)
        XCTAssertFalse(app.buttons["Vers 2"].exists, "An end before the chosen start must not be offered")
        tapMenuOption(identifier: "repeat.end.option.3", label: "Vers 3")
        chooseRepeatOption(picker: "repeat.start", option: "repeat.start.option.1", label: "Vers 1")
        XCTAssertTrue(waitForValue("Vers 1", on: app.buttons["repeat.start"]))
        chooseRepeatOption(picker: "repeat.end", option: "repeat.end.option.2", label: "Vers 2")
        XCTAssertTrue(waitForValue("Vers 2", on: app.buttons["repeat.end"]))
        let cycles = app.steppers["repeat.cycles"]
        scrollFullyIntoView(cycles)
        XCTAssertEqual(cycles.value as? String, "3")
        cycles.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).tap()
        XCTAssertTrue(waitForValue("4", on: cycles))
        chooseRepeatOption(picker: "repeat.pause", option: "repeat.pause.option.0", label: "Ingen paus")
        XCTAssertTrue(waitForValue("Ingen paus", on: app.buttons["repeat.pause"]))
        attachScreenshot("Repetition-validated-range")
        let start = app.buttons["repeat.startButton"]
        scrollFullyIntoView(start)
        XCTAssertTrue(start.isEnabled)
        start.tap()

        let summary = element("reader.repeat.status")
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertTrue(summary.label.contains("Vers 1:1–2"))
        XCTAssertTrue(summary.label.contains("av 4"), "The native session must retain the chosen finite cycle count")
        let toggle = app.buttons["reader.playback.toggle"]
        XCTAssertTrue(waitForLabel("Pausa", on: toggle))
        XCTAssertTrue(toggle.isHittable)
        toggle.tap()
        XCTAssertTrue(waitForLabel("Spela", on: toggle), "Pause must require an explicit resume")
        attachScreenshot("Repetition-paused-native-session")
        let stop = app.buttons["reader.playback.stop"]
        XCTAssertTrue(stop.exists && stop.isHittable)
        stop.tap()
        XCTAssertTrue(waitUntilAbsent(element("reader.repeat.status")))
        XCTAssertFalse(app.buttons["reader.playback.toggle"].exists)
        assertNoReadingCredit()
    }

    func testSavedAudioLibraryShowsExactUsageAndDeletionPersistsAcrossRelaunch() {
        app.tabBars.buttons["Mitt"].tap()
        openSettingsLink("settings.audioLibrary")
        let bytes = element("downloads.inventory.bytes")
        scrollFullyIntoView(bytes)
        XCTAssertTrue(waitForValue("2502 byte", on: bytes))
        let fatiha = app.buttons["downloads.saved.1.alafasy"]
        scrollFullyIntoView(fatiha)
        XCTAssertEqual(ungroupedAccessibilityValue(fatiha.value), "2 av 7 verser, 1668 byte")
        let ikhlas = app.buttons["downloads.saved.112.husary"]
        scrollFullyIntoView(ikhlas)
        XCTAssertEqual(ungroupedAccessibilityValue(ikhlas.value), "1 av 4 verser, 834 byte")
        attachScreenshot("Audio-library-exact-saved-selections")
        ikhlas.tap()
        let selectedSurah = app.buttons["downloads.surah"]
        scrollFullyIntoView(selectedSurah)
        XCTAssertEqual(selectedSurah.value as? String, "Al-Ikhlaas")
        let selectedReciter = app.buttons["downloads.reciter"]
        XCTAssertTrue(selectedReciter.label.contains("Mahmoud al-Husary")
            || (selectedReciter.value as? String)?.contains("Mahmoud al-Husary") == true)
        let selectedCount = element("downloads.selection.count")
        scrollFullyIntoView(selectedCount)
        XCTAssertEqual(selectedCount.value as? String, "1 av 4 verser")
        tapContent(app.buttons["downloads.saved.play"])
        XCTAssertTrue(element("reader.verse.112.1").waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntilReadableBadgeIsInsideReader("reader.verse.112.1"),
                      "Saved playback must reveal the matching verse text")
        let playingReciter = app.buttons["Byt recitatör"]
        XCTAssertTrue(playingReciter.waitForExistence(timeout: 5))
        XCTAssertEqual(playingReciter.value as? String, "Mahmoud al-Husary")
        let stop = app.buttons["reader.playback.stop"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        XCTAssertTrue(stop.isHittable)
        attachScreenshot("Audio-library-matching-text-and-controls")
        let next = app.buttons["Nästa vers"]
        XCTAssertTrue(next.exists && next.isEnabled && next.isHittable)
        next.tap()
        XCTAssertTrue(element("reader.verse.112.2").waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntilReadableBadgeIsInsideReader("reader.verse.112.2"))
        app.tabBars.buttons["Idag"].tap()
        app.tabBars.buttons["Mitt"].tap()
        XCTAssertTrue(waitUntilReadableBadgeIsInsideReader("reader.verse.112.2"),
                      "Returning to saved playback must retain the newer verse position")
        attachScreenshot("Audio-library-next-verse-restores-on-return")
        let returnedStop = app.buttons["reader.playback.stop"]
        XCTAssertTrue(returnedStop.exists && returnedStop.isHittable)
        returnedStop.tap()
        XCTAssertTrue(waitUntilAbsent(app.buttons["reader.playback.stop"]))
        returnFromDownloadedReader()
        XCTAssertEqual(app.buttons["downloads.surah"].value as? String, "Al-Ikhlaas",
                       "Returning from playback must retain the exact library selection")
        tapContent(app.buttons["downloads.delete.present"])
        let confirm = app.buttons["downloads.delete.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertTrue(confirm.isHittable)
        confirm.tap()
        scrollFullyIntoView(element("downloads.inventory.bytes"))
        XCTAssertTrue(waitForValue("1668 byte", on: element("downloads.inventory.bytes")))
        scrollFullyIntoView(app.buttons["downloads.saved.1.alafasy"])
        XCTAssertFalse(app.buttons["downloads.saved.112.husary"].exists)
        XCTAssertEqual(ungroupedAccessibilityValue(app.buttons["downloads.saved.1.alafasy"].value),
                       "2 av 7 verser, 1668 byte")

        relaunch()
        app.tabBars.buttons["Mitt"].tap()
        openSettingsLink("settings.audioLibrary")
        scrollFullyIntoView(element("downloads.inventory.bytes"))
        XCTAssertTrue(waitForValue("1668 byte", on: element("downloads.inventory.bytes")))
        scrollFullyIntoView(app.buttons["downloads.saved.1.alafasy"])
        XCTAssertFalse(app.buttons["downloads.saved.112.husary"].exists,
                       "A relaunch must not recreate files deleted through the actual confirmation")
        attachScreenshot("Audio-library-deletion-survives-relaunch")
        assertNoReadingCredit()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func relaunch() {
        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Mitt"].waitForExistence(timeout: 10))
    }

    private func openSettingsLink(_ identifier: String) {
        tapContent(app.buttons[identifier])
    }

    private func returnFromDownloadedReader() {
        let bar = app.navigationBars["Koranen"]
        let candidates = [bar.buttons["Ljud offline"], bar.buttons["Tillbaka"], bar.buttons["Back"]]
        guard let back = candidates.first(where: { $0.exists }) else {
            attachScreenshot("Audio-library-reader-back-control-missing")
            XCTFail("Downloaded playback must provide a real back control to Ljud offline")
            return
        }
        XCTAssertTrue(back.isHittable)
        back.tap()
        XCTAssertTrue(app.navigationBars["Ljud offline"].waitForExistence(timeout: 5))
    }

    private func chooseRepeatOption(picker: String, option: String, label: String) {
        tapContent(app.buttons[picker])
        tapMenuOption(identifier: option, label: label)
    }

    private func tapMenuOption(identifier: String, label: String) {
        let identified = app.buttons[identifier]
        let option = identified.exists ? identified : app.buttons[label]
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        XCTAssertTrue(option.isHittable)
        option.tap()
    }

    private func waitUntilReadableBadgeIsInsideReader(_ identifier: String) -> Bool {
        let parts = identifier.split(separator: ".")
        guard parts.count == 4, parts[0] == "reader", parts[1] == "verse" else { return false }
        let expectedLabel = "\(parts[2]):\(parts[3])"
        var observation = "No coherent reader snapshot was available."
        let visible = NSPredicate { _, _ in
            guard let snapshot = try? self.app.snapshot() else { return false }
            var pending: [any XCUIElementSnapshot] = [snapshot]
            var badges: [any XCUIElementSnapshot] = []
            var readerBar: (any XCUIElementSnapshot)?
            var tabBar: (any XCUIElementSnapshot)?
            var window: (any XCUIElementSnapshot)?
            while let node = pending.popLast() {
                if node.identifier == identifier { badges.append(node) }
                if node.elementType == .navigationBar && node.identifier == "Koranen" { readerBar = node }
                if node.elementType == .tabBar { tabBar = node }
                if node.elementType == .window && !node.frame.isEmpty { window = node }
                pending.append(contentsOf: node.children)
            }
            observation = "Snapshot contains \(badges.count) matches for \(identifier)."
            guard badges.count == 1, let badge = badges.first,
                  let readerBar, let tabBar, let window,
                  !readerBar.frame.isEmpty, !tabBar.frame.isEmpty,
                  tabBar.frame.minY > readerBar.frame.maxY else { return false }
            let frame = badge.frame
            observation = "Target \(badge.identifier), label \(badge.label), frame \(frame); reader \(readerBar.frame), tab \(tabBar.frame), window \(window.frame)."
            guard !frame.isEmpty, frame.minX.isFinite, frame.maxX.isFinite,
                  frame.minY.isFinite, frame.maxY.isFinite,
                  frame.minX >= window.frame.minX, frame.maxX <= window.frame.maxX,
                  frame.minY >= readerBar.frame.maxY, frame.maxY <= tabBar.frame.minY else { return false }
            return self.app.state == .runningForeground && badge.label == expectedLabel
        }
        let ready = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: visible, object: nil)], timeout: 5) == .completed
        if !ready {
            attachScreenshot("Feature-read-only-badge-not-visible")
            let diagnostic = XCTAttachment(string: "\(observation)\n\(app.debugDescription)")
            diagnostic.name = "Feature-read-only-badge-frame-and-hierarchy"
            diagnostic.lifetime = .keepAlways
            add(diagnostic)
        }
        return ready
    }

    private func assertNoReadingCredit() {
        app.tabBars.buttons["Idag"].tap()
        let progress = element("home.dailyProgress")
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertEqual(progress.value as? String, "0 av 3 verser lästa")
    }

    private func waitForValue(_ expected: String, on element: XCUIElement) -> Bool {
        let predicate = NSPredicate { candidate, _ in
            guard let candidate = candidate as? XCUIElement, candidate.exists else { return false }
            return self.ungroupedAccessibilityValue(candidate.value) == expected
        }
        return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: 5) == .completed
    }

    private func ungroupedAccessibilityValue(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let scalars = Array(value.unicodeScalars)
        var result = ""
        for (index, scalar) in scalars.enumerated() {
            // Swedish AX values can group digits as "2\u{00A0}502 byte".
            // Remove only NBSP/narrow-NBSP between decimal digits. Quantities,
            // units, ordinary spaces and every other character remain exact.
            if [0x00A0, 0x202F].contains(scalar.value), index > 0, index + 1 < scalars.count,
               CharacterSet.decimalDigits.contains(scalars[index - 1]),
               CharacterSet.decimalDigits.contains(scalars[index + 1]) { continue }
            result.unicodeScalars.append(scalar)
        }
        return result
    }

    private func waitForLabel(_ expected: String, on element: XCUIElement) -> Bool {
        let predicate = NSPredicate { candidate, _ in
            guard let candidate = candidate as? XCUIElement, candidate.exists else { return false }
            return candidate.label == expected
        }
        return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: 5) == .completed
    }

    private func waitUntilAbsent(_ element: XCUIElement) -> Bool {
        let predicate = NSPredicate { candidate, _ in (candidate as? XCUIElement)?.exists == false }
        return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: 5) == .completed
    }

    private func tapContent(_ element: XCUIElement) {
        scrollFullyIntoView(element)
        element.tap()
    }

    private func scrollFullyIntoView(_ element: XCUIElement) {
        var direction: CGFloat = 1
        for _ in 0..<12 {
            let bars = app.navigationBars.allElementsBoundByIndex.filter { $0.exists && !$0.frame.isEmpty }
            let top = bars.map { $0.frame.maxY }.max() ?? app.frame.minY
            let tab = app.tabBars.firstMatch
            let bottom = tab.exists && tab.isHittable ? tab.frame.minY : app.frame.maxY - 12
            guard bottom > top else { break }
            let maximumDrag = (bottom - top) * 0.4
            var drag = direction * maximumDrag
            if element.exists {
                let frame = element.frame
                if !frame.isEmpty, frame.minY.isFinite, frame.maxY.isFinite {
                    if frame.minY >= top && frame.maxY <= bottom {
                        // A menu can publish its new value before its dismissal
                        // animation stops covering the next control. Geometry
                        // alone is not permission to tap through that overlay.
                        let ready = NSPredicate { candidate, _ in
                            guard let control = candidate as? XCUIElement,
                                  control.exists, control.isHittable else { return false }
                            let current = control.frame
                            return !current.isEmpty && current.minY.isFinite && current.maxY.isFinite
                                && current.minY >= top && current.maxY <= bottom
                        }
                        if XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ready, object: element)],
                                          timeout: 5) == .completed { return }
                        break
                    }
                    let overflow = frame.minY < top ? frame.minY - top - 8 : frame.maxY - bottom + 8
                    direction = overflow < 0 ? -1 : 1
                    drag = direction * min(maximumDrag, max(24, abs(overflow)))
                }
            }
            let center = (top + bottom) / 2
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: app.frame.width / 2, dy: center + drag / 2))
            let end = origin.withOffset(CGVector(dx: app.frame.width / 2, dy: center - drag / 2))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        attachScreenshot("Feature-control-not-fully-visible")
        let diagnostic = XCTAttachment(string: "Target: \(element.debugDescription)\n\(app.debugDescription)")
        diagnostic.name = "Feature-control-frame-and-hierarchy"
        diagnostic.lifetime = .keepAlways
        add(diagnostic)
        XCTAssertTrue(element.exists && element.isHittable)
        XCTFail("The complete control did not enter the content viewport")
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
