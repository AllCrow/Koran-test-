import Foundation
import XCTest

/// Real native interactions with isolated local reading state. Search is offline;
/// these flows never send reports, recordings or reading history to a service.
@MainActor
final class ReadingImprovementsTests: XCTestCase {
    private var app: XCUIApplication!
    private var suite: String!

    override func setUp() async throws {
        await MainActor.run {
            continueAfterFailure = false
            suite = "sakina.uitests.\(UUID().uuidString)"
            app = XCUIApplication()
            app.launchArguments = ["--ui-test-suite", suite, "-AppleLanguages", "(sv)", "-AppleLocale", "sv_SE"]
            app.launch()
            XCTAssertTrue(app.tabBars.buttons["Koranen"].waitForExistence(timeout: 10))
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            app?.terminate()
            app = nil
        }
    }

    func testOfflineArabicSearchOpensExactVerseAndRestoresWithoutReadingCredit() {
        app.tabBars.buttons["Koranen"].tap()
        openVerseSearch()
        let query = element("reader.search.query")
        XCTAssertTrue(query.waitForExistence(timeout: 5))
        query.tap()
        query.typeText("قل هو الله احد")
        let result = app.buttons["reader.search.result.112.1"]
        XCTAssertTrue(result.waitForExistence(timeout: 5), "An unvocalized Arabic query must find the canonical verse")
        scrollFullyIntoView(result)
        XCTAssertTrue(result.isEnabled)
        attachScreenshot("Search-unvocalized-Arabic-Al-Ikhlas")
        result.tap()
        XCTAssertTrue(waitUntilVerseStartsNearTop("reader.verse.112.1"), "The chosen result must open the exact verse beginning")
        assertNoReadingCredit()
        relaunch()
        app.buttons["home.continue"].tap()
        XCTAssertTrue(waitUntilVerseStartsNearTop("reader.verse.112.1"), "A selected search result must survive a real relaunch")
        assertNoReadingCredit()
    }

    func testClearingSearchRemovesOldResultsAndNonmatchStaysEmpty() {
        app.tabBars.buttons["Koranen"].tap()
        openVerseSearch()
        let query = element("reader.search.query")
        XCTAssertTrue(query.waitForExistence(timeout: 5))
        query.tap()
        query.typeText("قل هو الله احد")
        let result = app.buttons["reader.search.result.112.1"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        let clear = app.buttons["reader.search.clear"]
        XCTAssertTrue(clear.exists && clear.isHittable)
        clear.tap()
        XCTAssertTrue(element("reader.search.empty").waitForExistence(timeout: 5))
        XCTAssertFalse(result.exists, "Clearing the query must remove the old selectable result")
        query.tap()
        query.typeText("ظظظظظظظظ")
        XCTAssertTrue(element("reader.search.noResults").waitForExistence(timeout: 5))
        XCTAssertFalse(result.exists, "An old successful query must never overwrite a later nonmatch")
        attachScreenshot("Search-empty-Arabic-results")
    }

    func testManualScrollingSavesVisibleVerseWithoutReadingCredit() {
        app.tabBars.buttons["Koranen"].tap()
        app.buttons["Välj sura"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("2")
        let chapter = app.buttons["surah.select.2"]
        XCTAssertTrue(chapter.waitForExistence(timeout: 5))
        chapter.tap()
        XCTAssertTrue(app.staticTexts["reader.chapter.2"].waitForExistence(timeout: 5))

        // Real slow drags place the second verse near the viewport's top. No
        // jump, listening or Mark as read action supplies the saved position.
        XCTAssertTrue(dragVerseNearTop("reader.verse.2.2"))
        XCTAssertTrue(waitUntilVerseStartsNearTop("reader.verse.2.2"))
        attachScreenshot("Reader-manual-scroll-position")
        app.tabBars.buttons["Idag"].tap()
        let position = element("home.readingPosition")
        let correctPosition = NSPredicate { _, _ in
            position.exists && position.label == "Sura 2 · vers 2"
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: correctPosition, object: nil)], timeout: 5), .completed,
                       "Only the manually reached verse should become the saved reading position")
        assertNoReadingCredit()
        relaunch()
        app.buttons["home.continue"].tap()
        XCTAssertTrue(waitUntilVerseStartsNearTop("reader.verse.2.2"), "Ordinary reading must resume at the saved visible verse after relaunch")
        assertNoReadingCredit()
    }

    func testSourceScreenDistinguishesReadingTajweedAndTafsirEditions() {
        app.tabBars.buttons["Mitt"].tap()
        let sources = app.buttons["settings.sources"]
        scrollFullyIntoView(sources)
        sources.tap()
        let reading = element("sources.readingEdition")
        XCTAssertTrue(reading.waitForExistence(timeout: 5))
        XCTAssertTrue(reading.label.contains("quran-uthmani"))
        let tajweed = element("sources.tajweedEdition")
        revealText(tajweed)
        XCTAssertTrue(tajweed.label.contains("quran-tajweed"))
        let tafsir = element("sources.tafsirEdition")
        revealText(tafsir)
        XCTAssertTrue(tafsir.label.contains("ar.muyassar"))
        attachScreenshot("Sources-distinct-tafsir-edition")
    }

    func testExplicitSaveReadingPositionIsAnOperableAlternativeWithoutReadingCredit() {
        app.tabBars.buttons["Koranen"].tap()
        let options = app.buttons["reader.verseOptions.1.3"]
        // Reach the later verse with real scrolling. Its accessible menu lets
        // the user choose that exact verse even when another row is at the top.
        let menuControl = scrollFullyIntoView(options)
        XCTAssertGreaterThanOrEqual(options.frame.width, 44)
        XCTAssertGreaterThanOrEqual(options.frame.height, 44)
        menuControl.tap()
        let save = app.buttons["reader.savePosition.1.3"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertTrue(save.isEnabled && save.isHittable)
        save.tap()
        app.tabBars.buttons["Idag"].tap()
        let position = element("home.readingPosition")
        let correctPosition = NSPredicate { _, _ in
            position.exists && position.label == "Sura 1 · vers 3"
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: correctPosition, object: nil)], timeout: 5), .completed,
                       "The explicit verse action must win over an older passive scroll candidate")
        assertNoReadingCredit()
        attachScreenshot("Home-explicit-reading-position")
        relaunch()
        app.buttons["home.continue"].tap()
        XCTAssertTrue(waitUntilVerseStartsNearTop("reader.verse.1.3"))
        assertNoReadingCredit()
    }

    func testContentReportRequiresExplicitPreviewAtAccessibilityTextSize() throws {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Koranen"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Koranen"].tap()
        let options = app.buttons["reader.verseOptions.1.1"]
        let menuControl = scrollFullyIntoView(options)
        XCTAssertGreaterThanOrEqual(options.frame.height, 44)
        menuControl.tap()
        let reportAction = app.buttons["reader.report.1.1"]
        XCTAssertTrue(reportAction.waitForExistence(timeout: 5))
        XCTAssertTrue(reportAction.isHittable)
        reportAction.tap()
        let reference = element("contentIssue.reference")
        XCTAssertTrue(reference.waitForExistence(timeout: 5))
        XCTAssertEqual(reference.label, "Sura 1 · vers 1")
        XCTAssertFalse(element("contentIssue.report").exists, "Opening a verse report must not create or send one")

        let description = app.textViews["contentIssue.description"]
        scrollFullyIntoView(description)
        description.tap()
        description.typeText("Kontrollera visningen av den här versen.")
        let done = app.buttons["contentIssue.keyboardDone"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(done.isHittable)
        done.tap()
        let create = app.buttons["contentIssue.preview"]
        scrollFullyIntoView(create)
        XCTAssertGreaterThanOrEqual(create.frame.height, 44)
        create.tap()
        let preview = element("contentIssue.report")
        revealText(preview)
        let data = try XCTUnwrap(preview.label.data(using: .utf8))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(json.keys), Set(["schema_version", "reference", "topic", "reading_edition",
                                            "tajweed_edition", "tajweed_enabled", "related_source", "description"]))
        let exactReference = try XCTUnwrap(json["reference"] as? [String: Any])
        XCTAssertEqual(exactReference["surahID"] as? Int, 1)
        XCTAssertEqual(exactReference["ayahNumber"] as? Int, 1)
        XCTAssertEqual(json["reading_edition"] as? String, "quran-uthmani")
        XCTAssertEqual(json["description"] as? String, "Kontrollera visningen av den här versen.")
        for forbidden in ["lastRead", "bookmarks", "file://", "api_key", "recording"] {
            XCTAssertFalse(preview.label.contains(forbidden), "A verse report must not collect \(forbidden)")
        }
        let export = app.buttons["contentIssue.export"]
        scrollFullyIntoView(export)
        XCTAssertTrue(export.isEnabled)
        XCTAssertGreaterThanOrEqual(export.frame.height, 44)
        attachScreenshot("Content-report-reviewed-at-accessibility-size")
        // Actual Files export and external sharing are intentionally left to
        // the user. The real export control must be visible and operable.
        let close = app.buttons["Stäng"]
        XCTAssertTrue(close.isHittable)
        close.tap()
        assertNoReadingCredit()
    }

    private func openVerseSearch() {
        let menu = app.buttons["Läsinställningar"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()
        let present = app.buttons["reader.search.present"]
        XCTAssertTrue(present.waitForExistence(timeout: 5))
        XCTAssertTrue(present.isHittable)
        present.tap()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func relaunch() {
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["home.continue"].waitForExistence(timeout: 10))
    }

    private func assertNoReadingCredit() {
        app.tabBars.buttons["Idag"].tap()
        let progress = element("home.dailyProgress")
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertEqual(progress.value as? String, "0 av 3 verser lästa")
    }

    private struct ReaderObservation {
        let top: CGFloat
        let bottom: CGFloat
        let window: CGRect
        let badge: CGRect?
    }

    /// One coherent native snapshot binds identity, reference, geometry, bars
    /// and window. Read-only badges need visibility, not an activation point.
    private func readerObservation(_ identifier: String) -> ReaderObservation? {
        guard let snapshot = try? app.snapshot() else { return nil }
        var pending: [any XCUIElementSnapshot] = [snapshot]
        var badges: [any XCUIElementSnapshot] = []
        var navigation: (any XCUIElementSnapshot)?
        var tabs: (any XCUIElementSnapshot)?
        var window: (any XCUIElementSnapshot)?
        while let node = pending.popLast() {
            if node.elementType == .staticText && node.identifier == identifier { badges.append(node) }
            if node.elementType == .navigationBar && node.identifier == "Koranen" { navigation = node }
            if node.elementType == .tabBar { tabs = node }
            if node.elementType == .window && !node.frame.isEmpty { window = node }
            pending.append(contentsOf: node.children)
        }
        guard let navigation, let tabs, let window,
              !navigation.frame.isEmpty, !tabs.frame.isEmpty,
              navigation.frame.maxY.isFinite, tabs.frame.minY.isFinite,
              tabs.frame.minY > navigation.frame.maxY,
              badges.count <= 1, app.state == .runningForeground else { return nil }
        let parts = identifier.split(separator: ".")
        guard parts.count == 4, parts[0] == "reader", parts[1] == "verse" else { return nil }
        let expected = "\(parts[2]):\(parts[3])"
        let badge = badges.first
        guard badge == nil || badge?.label == expected else { return nil }
        return ReaderObservation(top: navigation.frame.maxY, bottom: tabs.frame.minY,
                                 window: window.frame, badge: badge?.frame)
    }

    private func waitUntilVerseStartsNearTop(_ identifier: String) -> Bool {
        var last = "No coherent reader snapshot"
        let predicate = NSPredicate { _, _ in
            guard let observation = self.readerObservation(identifier), let frame = observation.badge else { return false }
            let upperLimit = observation.top + min(150, (observation.bottom - observation.top) / 4)
            last = "\(identifier): \(frame); allowed y=\(observation.top)...\(upperLimit), window=\(observation.window)"
            return self.finite(frame) && frame.minY >= observation.top && frame.maxY <= upperLimit
                && frame.minX >= observation.window.minX && frame.maxX <= observation.window.maxX
        }
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: 5) == .completed
        if !result { diagnostic("Reader-position-not-visible", details: last) }
        return result
    }

    private func dragVerseNearTop(_ identifier: String) -> Bool {
        var performedDrag = false
        for _ in 0..<12 {
            guard let observation = readerObservation(identifier) else { return false }
            let height = observation.bottom - observation.top
            let desired = observation.top + 32
            var delta = height * 0.4
            if let frame = observation.badge, finite(frame) {
                delta = frame.minY - desired
                let upperLimit = observation.top + min(150, height / 4)
                let fullyNearTop = frame.minY >= observation.top && frame.maxY <= upperLimit
                    && frame.minX >= observation.window.minX && frame.maxX <= observation.window.maxX
                // UIKit's drag slop can consume the last few points of a
                // small correction. The actual contract is the complete
                // badge near the top, followed by exact saved-reference and
                // relaunch checks; a sub-8pt alignment is not that contract.
                if performedDrag && fullyNearTop && abs(delta) <= 24 { return true }
            }
            if !performedDrag && abs(delta) < 24 { delta = 32 }
            let drag = min(height * 0.4, max(-height * 0.4, delta))
            let center = (observation.top + observation.bottom) / 2
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: observation.window.midX, dy: center + drag / 2))
            let end = origin.withOffset(CGVector(dx: observation.window.midX, dy: center - drag / 2))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
            performedDrag = true
        }
        diagnostic("Reader-manual-position-not-reached", details: identifier)
        return false
    }

    private func finite(_ frame: CGRect) -> Bool {
        !frame.isEmpty && frame.minX.isFinite && frame.maxX.isFinite && frame.minY.isFinite && frame.maxY.isFinite
    }

    private func revealText(_ text: XCUIElement) {
        for _ in 0..<12 {
            // Long source explanations and a full JSON preview can exceed the
            // viewport at Dynamic Type sizes. Read their full native label;
            // every actionable control still uses full-frame checks below.
            let viewport = contentViewport()
            if text.exists, finite(text.frame), text.frame.maxY > viewport.top,
               text.frame.minY < viewport.bottom { return }
            app.swipeUp()
        }
        diagnostic("New-reading-text-not-visible", details: text.debugDescription)
        XCTFail("The requested source or preview text must be present")
    }

    @discardableResult
    private func scrollFullyIntoView(_ control: XCUIElement) -> XCUIElement {
        var direction: CGFloat = 1
        for _ in 0..<12 {
            let viewport = contentViewport()
            let top = viewport.top
            let bottom = viewport.bottom
            let maximum = (bottom - top) * 0.35
            var drag = direction * maximum
            if control.exists, finite(control.frame) {
                let frame = control.frame
                if frame.minY >= top && frame.maxY <= bottom {
                    let target = operableControl(for: control, frame: frame)
                    XCTAssertTrue(target.isHittable)
                    XCTAssertGreaterThanOrEqual(frame.minX, app.frame.minX)
                    XCTAssertLessThanOrEqual(frame.maxX, app.frame.maxX)
                    return target
                }
                let overflow = frame.minY < top ? frame.minY - top - 8 : frame.maxY - bottom + 8
                direction = overflow < 0 ? -1 : 1
                drag = direction * min(maximum, max(24, abs(overflow)))
            }
            let center = (top + bottom) / 2
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: app.frame.midX, dy: center + drag / 2))
                .press(forDuration: 0.05,
                       thenDragTo: origin.withOffset(CGVector(dx: app.frame.midX, dy: center - drag / 2)),
                       withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        diagnostic("New-reading-control-not-visible", details: control.debugDescription)
        XCTFail("The actual control must be fully visible and operable")
        return control
    }

    private func operableControl(for control: XCUIElement, frame: CGRect) -> XCUIElement {
        if control.isHittable { return control }
        let parts = control.identifier.split(separator: ".")
        guard parts.count == 4, parts[0] == "reader", parts[1] == "verseOptions",
              let surah = Int(parts[2]), let verse = Int(parts[3]),
              control.label == "Versalternativ för \(surah):\(verse)",
              frame.width >= 44, frame.height >= 44 else { return control }
        // SwiftUI Menu exposes a reference-labelled wrapper and its actual
        // native button at the same bounds. Resolve only that wrapper's unique
        // child, retaining full geometry and a real hittable-button tap.
        let buttons = control.descendants(matching: .button)
        guard buttons.count == 1 else { return control }
        let button = buttons.element(boundBy: 0)
        let childFrame = button.frame
        guard finite(childFrame), abs(childFrame.minX - frame.minX) <= 0.5,
              abs(childFrame.minY - frame.minY) <= 0.5,
              abs(childFrame.width - frame.width) <= 0.5,
              abs(childFrame.height - frame.height) <= 0.5,
              button.isHittable else { return control }
        return button
    }

    private func contentViewport() -> (top: CGFloat, bottom: CGFloat) {
        var top = app.navigationBars.firstMatch.frame.maxY
        // A page-sheet's navigation bar can sit below the presenting reader's
        // bar. Use the active screen's bar for real control visibility checks.
        for title in ["Granska innehåll", "Sök i verser", "Källor och textutgåvor"] {
            let bar = app.navigationBars[title]
            if bar.exists, !bar.frame.isEmpty { top = bar.frame.maxY; break }
        }
        let contentBottom = app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame.minY : app.frame.maxY
        let bottom = app.keyboards.firstMatch.exists ? min(contentBottom, app.keyboards.firstMatch.frame.minY) : contentBottom
        return (top, bottom)
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func diagnostic(_ name: String, details: String) {
        attachScreenshot(name)
        let attachment = XCTAttachment(string: "\(details)\n\(app.debugDescription)")
        attachment.name = name + "-hierarchy"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
