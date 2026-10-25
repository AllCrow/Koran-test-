import XCTest

/// No network, microphone, model, account or signing secrets are needed.
/// These are native simulator checks; source-level checks do not run them.
@MainActor
final class ReadingFlowTests: XCTestCase {
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

    func testOnlyManualReadingCountsAndSurvivesRelaunch() {
        let progress = app.descendants(matching: .any).matching(identifier: "home.dailyProgress").firstMatch
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertEqual(progress.value as? String, "0 av 3 verser lästa")
        app.tabBars.buttons["Koranen"].tap()
        let markRead = app.buttons["reader.markRead.1.1"]
        XCTAssertTrue(markRead.waitForExistence(timeout: 5))
        XCTAssertTrue(markRead.isEnabled, "Opening the reader must not complete a verse")
        attachScreenshot("Reader-Al-Fatiha")
        markRead.tap()
        XCTAssertFalse(markRead.isEnabled)
        app.tabBars.buttons["Idag"].tap()
        XCTAssertEqual(progress.value as? String, "1 av 3 verser lästa")
        attachScreenshot("Home-reading-progress")
        app.terminate()
        app.launch()
        let restored = app.descendants(matching: .any).matching(identifier: "home.dailyProgress").firstMatch
        XCTAssertTrue(restored.waitForExistence(timeout: 10))
        XCTAssertEqual(restored.value as? String, "1 av 3 verser lästa")
        app.tabBars.buttons["Koranen"].tap()
        XCTAssertTrue(markRead.waitForExistence(timeout: 5))
        XCTAssertFalse(markRead.isEnabled)
    }

    func testBookmarkSurvivesRelaunchAndOpensItsVerse() {
        app.tabBars.buttons["Koranen"].tap()
        let bookmark = app.buttons["reader.bookmark.1.1"]
        XCTAssertTrue(bookmark.waitForExistence(timeout: 5))
        bookmark.tap()
        XCTAssertEqual(bookmark.label, "Ta bort bokmärke")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Mitt"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Mitt"].tap()
        let saved = app.buttons["settings.bookmark.1.1"]
        scrollTo(saved)
        saved.tap()
        XCTAssertTrue(bookmark.waitForExistence(timeout: 5))
        XCTAssertEqual(bookmark.label, "Ta bort bokmärke")
    }

    func testSurahSearchSupportsArabicIndicNumbersAndEmptyResults() {
        app.tabBars.buttons["Koranen"].tap()
        let choose = app.buttons["Välj sura"]
        XCTAssertTrue(choose.waitForExistence(timeout: 5))
        choose.tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("zzznomatch")
        XCTAssertTrue(app.staticTexts["Ingen sura hittades"].waitForExistence(timeout: 5))
        // Select all characters through the keyboard-independent clear action.
        let clear = search.buttons.firstMatch
        XCTAssertTrue(clear.exists)
        clear.tap()
        search.typeText("الفاتحة")
        XCTAssertTrue(app.buttons["surah.select.1"].waitForExistence(timeout: 5))
        clear.tap()
        search.typeText("Fatiha")
        XCTAssertTrue(app.buttons["surah.select.1"].waitForExistence(timeout: 5))
        clear.tap()
        search.typeText("Ikhlas")
        XCTAssertTrue(app.buttons["surah.select.112"].waitForExistence(timeout: 5))
        clear.tap()
        search.typeText("١١٢")
        let surah = app.buttons["surah.select.112"]
        XCTAssertTrue(surah.waitForExistence(timeout: 5))
        surah.tap()
        XCTAssertTrue(app.staticTexts["reader.chapter.112"].waitForExistence(timeout: 5))
        let markRead = app.buttons["reader.markRead.112.1"]
        XCTAssertTrue(markRead.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["reader.markRead.1.1"].exists, "The previous chapter's controls must be replaced")
        XCTAssertTrue(markRead.isEnabled)
        markRead.tap()
        XCTAssertFalse(markRead.isEnabled)
        app.buttons["reader.bookmark.112.1"].tap()
        attachScreenshot("Reader-Al-Ikhlas")
        app.tabBars.buttons["Mitt"].tap()
        scrollTo(app.buttons["settings.bookmark.112.1"])
        XCTAssertFalse(app.buttons["settings.bookmark.1.1"].exists, "The action must save the chosen sura's verse")
    }

    func testDirectVerseJumpValidatesArabicInputAndRestoresPositionWithoutReadingCredit() {
        app.tabBars.buttons["Koranen"].tap()
        app.buttons["Välj sura"].tap()
        let baqara = app.buttons["surah.select.2"]
        XCTAssertTrue(baqara.waitForExistence(timeout: 5))
        baqara.tap()
        XCTAssertTrue(app.staticTexts["reader.chapter.2"].waitForExistence(timeout: 5))
        app.buttons["Läsinställningar"].tap()
        app.buttons["reader.jump.present"].tap()
        let number = app.textFields["reader.jump.number"]
        XCTAssertTrue(number.waitForExistence(timeout: 5))
        number.tap()
        number.typeText("٢٨٧")
        let open = app.buttons["reader.jump.open"]
        XCTAssertFalse(open.isEnabled, "A verse beyond Al-Baqara's 286 verses must not open")
        number.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3) + "٢٥٥")
        XCTAssertTrue(open.isEnabled)
        open.tap()
        let verse = app.staticTexts["reader.verse.2.255"]
        let targetIsVisible = waitUntilHittable(verse)
        XCTAssertTrue(targetIsVisible, "A jump must reveal the target's global verse identity")
        attachScreenshot("Reader-Baqara-255")
        app.tabBars.buttons["Idag"].tap()
        let progress = app.descendants(matching: .any).matching(identifier: "home.dailyProgress").firstMatch
        XCTAssertEqual(progress.value as? String, "0 av 3 verser lästa", "Navigation must not award reading credit")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Koranen"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Koranen"].tap()
        XCTAssertTrue(waitUntilHittable(verse), "The saved verse position must survive relaunch")
        // Selecting the same saved position must still execute a jump, and a
        // later explicit reading action must replace that position on return.
        app.buttons["Läsinställningar"].tap()
        app.buttons["reader.jump.present"].tap()
        XCTAssertTrue(number.waitForExistence(timeout: 5))
        number.tap()
        number.typeText("255")
        open.tap()
        XCTAssertTrue(waitUntilHittable(verse))
        let markRead = app.buttons["reader.markRead.2.256"]
        scrollTo(markRead)
        XCTAssertTrue(markRead.isEnabled)
        markRead.tap()
        app.tabBars.buttons["Idag"].tap()
        XCTAssertEqual(progress.value as? String, "1 av 3 verser lästa")
        app.tabBars.buttons["Koranen"].tap()
        let laterVerse = app.staticTexts["reader.verse.2.256"]
        XCTAssertTrue(waitUntilHittable(laterVerse), "A later read must replace the previous jump position on tab return")
    }

    func testLargeTextReadingAndLocalPreferencesRemainUsable() {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Koranen"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Koranen"].tap()
        let markRead = app.buttons["reader.markRead.1.1"]
        scrollTo(markRead)
        XCTAssertTrue(markRead.isEnabled)
        attachScreenshot("Reader-large-accessibility-text")
        markRead.tap()
        XCTAssertFalse(markRead.isEnabled)
        app.tabBars.buttons["Mitt"].tap()
        let tajweed = app.switches["settings.tajweed"]
        scrollFullyIntoView(tajweed)
        XCTAssertEqual(tajweed.value as? String, "1")
        attachScreenshot("Settings-large-switch-target")
        // SwiftUI exposes a labelled switch's whole row as its accessibility
        // frame. Tap the trailing control after the row is fully on screen.
        tajweed.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(tajweed.value as? String, "0")
        let export = app.buttons["settings.backup.export"]
        scrollTo(export)
        XCTAssertTrue(export.isEnabled)
        let importBackup = app.buttons["settings.backup.import"]
        scrollTo(importBackup)
        XCTAssertTrue(importBackup.isEnabled)
        attachScreenshot("Settings-local-reading-backup")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Mitt"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Mitt"].tap()
        scrollFullyIntoView(tajweed)
        XCTAssertEqual(tajweed.value as? String, "0", "The reading preference must survive a real app relaunch")
        app.tabBars.buttons["Koranen"].tap()
        scrollTo(markRead)
        XCTAssertFalse(markRead.isEnabled)
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitUntilHittable(_ element: XCUIElement) -> Bool {
        let visible = NSPredicate(format: "exists == true AND hittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: visible, object: element)
        let ready = XCTWaiter.wait(for: [expectation], timeout: 5) == .completed
        if !ready {
            attachScreenshot("Reader-position-not-visible")
            let target = element.exists ? "Target frame: \(element.frame)\n\(element.debugDescription)" : "Target does not exist"
            let diagnostic = XCTAttachment(string: "\(target)\n\(app.debugDescription)")
            diagnostic.name = "Reader-target-frame-and-hierarchy"
            diagnostic.lifetime = .keepAlways
            add(diagnostic)
        }
        return ready
    }

    private func scrollTo(_ element: XCUIElement) {
        for _ in 0..<6 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable)
    }

    private func scrollFullyIntoView(_ element: XCUIElement) {
        for _ in 0..<10 {
            let top = app.navigationBars.firstMatch.frame.maxY
            let bottom = app.tabBars.firstMatch.frame.minY
            if element.exists {
                let frame = element.frame
                if element.isHittable && frame.minY >= top && frame.maxY <= bottom { return }
                if !frame.isEmpty && frame.minY < top { app.swipeDown() } else { app.swipeUp() }
            } else {
                app.swipeUp()
            }
        }
        XCTAssertTrue(element.exists && element.isHittable)
        XCTAssertGreaterThanOrEqual(element.frame.minY, app.navigationBars.firstMatch.frame.maxY)
        XCTAssertLessThanOrEqual(element.frame.maxY, app.tabBars.firstMatch.frame.minY)
    }
}
