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
        let targetIsVisible = waitUntilVerseStartsNearTop(verse)
        XCTAssertTrue(targetIsVisible, "A jump must reveal the verse's beginning near the top of the reader")
        attachScreenshot("Reader-Baqara-255")
        app.tabBars.buttons["Idag"].tap()
        let progress = app.descendants(matching: .any).matching(identifier: "home.dailyProgress").firstMatch
        XCTAssertEqual(progress.value as? String, "0 av 3 verser lästa", "Navigation must not award reading credit")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Koranen"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Koranen"].tap()
        XCTAssertTrue(waitUntilVerseStartsNearTop(verse), "The saved verse beginning must appear near the top after relaunch")
        // Selecting the same saved position must still execute a jump, and a
        // later explicit reading action must replace that position on return.
        app.buttons["Läsinställningar"].tap()
        app.buttons["reader.jump.present"].tap()
        XCTAssertTrue(number.waitForExistence(timeout: 5))
        number.tap()
        number.typeText("255")
        open.tap()
        XCTAssertTrue(waitUntilVerseStartsNearTop(verse))
        let markRead = app.buttons["reader.markRead.2.256"]
        scrollTo(markRead)
        XCTAssertTrue(markRead.isEnabled)
        markRead.tap()
        app.tabBars.buttons["Idag"].tap()
        XCTAssertEqual(progress.value as? String, "1 av 3 verser lästa")
        app.tabBars.buttons["Koranen"].tap()
        let laterVerse = app.staticTexts["reader.verse.2.256"]
        XCTAssertTrue(waitUntilVerseStartsNearTop(laterVerse), "A later read must replace the previous jump position near the top on tab return")
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
        XCTAssertEqual(markRead.label, "Markera vers 1 som läst")
        XCTAssertGreaterThanOrEqual(markRead.frame.height, 44)
        let bookmark = app.buttons["reader.bookmark.1.1"]
        scrollFullyIntoView(bookmark)
        XCTAssertEqual(bookmark.label, "Spara bokmärke")
        XCTAssertGreaterThanOrEqual(bookmark.frame.height, 44)
        bookmark.tap()
        XCTAssertEqual(bookmark.label, "Ta bort bokmärke")
        let tafsir = app.buttons["reader.tafsir.1.1"]
        scrollFullyIntoView(tafsir)
        XCTAssertGreaterThanOrEqual(tafsir.frame.height, 44)
        XCTAssertGreaterThanOrEqual(tafsir.frame.minX, 0)
        XCTAssertLessThanOrEqual(tafsir.frame.maxX, app.frame.width)
        scrollFullyIntoView(markRead)
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

    func testNextSurahSavesPositionWithoutReadingCreditAndEndsAtAnNas() {
        app.tabBars.buttons["Koranen"].tap()
        // An older position in the destination must not win over this explicit
        // request to start the next sura at its first verse.
        app.buttons["Välj sura"].tap()
        var search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("114")
        let nas = app.buttons["surah.select.114"]
        XCTAssertTrue(nas.waitForExistence(timeout: 5))
        nas.tap()
        app.tabBars.buttons["Idag"].tap()
        XCTAssertTrue(app.staticTexts["Sura 114 · vers 1"].waitForExistence(timeout: 5),
                      "Before a first reading mark, the home card must describe the selected sura it will actually open")
        app.buttons["home.continue"].tap()
        app.buttons["Läsinställningar"].tap()
        app.buttons["reader.jump.present"].tap()
        let number = app.textFields["reader.jump.number"]
        XCTAssertTrue(number.waitForExistence(timeout: 5))
        number.tap()
        number.typeText("5")
        app.buttons["reader.jump.open"].tap()
        // At the end of a short sura, List clamps to its natural content edge.
        // Verify this seed position is actually visible; the explicit next-sura
        // destination below must still align at the top and replace this seed.
        XCTAssertTrue(waitUntilControlIsFullyVisible(app.buttons["reader.markRead.114.5"]))
        app.buttons["Välj sura"].tap()
        search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("113")
        let falaq = app.buttons["surah.select.113"]
        XCTAssertTrue(falaq.waitForExistence(timeout: 5))
        falaq.tap()
        let next = app.buttons["reader.nextSurah.114"]
        scrollTo(next)
        next.tap()
        let firstVerse = app.buttons["reader.markRead.114.1"]
        XCTAssertTrue(firstVerse.waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntilVerseStartsNearTop(app.staticTexts["reader.verse.114.1"]))
        XCTAssertTrue(firstVerse.isEnabled)
        XCTAssertFalse(app.buttons["reader.markRead.113.1"].exists)
        attachScreenshot("Reader-next-surah-An-Nas")
        app.tabBars.buttons["Idag"].tap()
        let progress = app.descendants(matching: .any).matching(identifier: "home.dailyProgress").firstMatch
        XCTAssertEqual(progress.value as? String, "0 av 3 verser lästa")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Koranen"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Koranen"].tap()
        XCTAssertTrue(firstVerse.waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntilVerseStartsNearTop(app.staticTexts["reader.verse.114.1"]))
        XCTAssertTrue(firstVerse.isEnabled)
        let lastVerse = app.buttons["reader.markRead.114.6"]
        scrollTo(lastVerse)
        XCTAssertFalse(app.buttons["reader.nextSurah.115"].exists, "The final sura must not offer an invalid next chapter")
        XCTAssertTrue(lastVerse.isEnabled)
    }

    func testDarkAppearanceKeepsReaderAndHomeUsable() {
        app.tabBars.buttons["Mitt"].tap()
        let appearance = app.buttons["settings.appearance"]
        scrollFullyIntoView(appearance)
        appearance.tap()
        let dark = app.buttons["Mörkt"]
        XCTAssertTrue(dark.waitForExistence(timeout: 5))
        dark.tap()
        app.tabBars.buttons["Idag"].tap()
        let continueReading = app.buttons["home.continue"]
        XCTAssertTrue(continueReading.waitForExistence(timeout: 10))
        XCTAssertTrue(continueReading.isHittable, "The main reading action should be easy to reach on the home screen")
        attachScreenshot("Home-dark-appearance")
        continueReading.tap()
        let markRead = app.buttons["reader.markRead.1.1"]
        XCTAssertTrue(markRead.waitForExistence(timeout: 5))
        XCTAssertTrue(markRead.isEnabled)
        app.buttons["reader.bookmark.1.1"].tap()
        markRead.tap()
        XCTAssertFalse(markRead.isEnabled)
        attachScreenshot("Reader-dark-appearance")
        app.tabBars.buttons["Idag"].tap()
        let progress = app.descendants(matching: .any).matching(identifier: "home.dailyProgress").firstMatch
        XCTAssertEqual(progress.value as? String, "1 av 3 verser lästa")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Mitt"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Mitt"].tap()
        scrollFullyIntoView(appearance)
        XCTAssertTrue(appearance.label.contains("Mörkt") || (appearance.value as? String)?.contains("Mörkt") == true,
                      "The selected night appearance must survive a real relaunch")
    }

    func testArabicTextSizeSelectionPersistsWithoutReadingCredit() {
        app.tabBars.buttons["Mitt"].tap()
        let openSizes = app.buttons["settings.arabicTextSize.present"]
        scrollTo(openSizes)
        openSizes.tap()
        let standard = app.buttons["settings.arabicTextSize.standard"]
        let extraLarge = app.buttons["settings.arabicTextSize.extraLarge"]
        XCTAssertTrue(standard.waitForExistence(timeout: 5))
        XCTAssertEqual(standard.value as? String, "Vald")
        XCTAssertTrue(extraLarge.isHittable)
        extraLarge.tap()
        XCTAssertEqual(extraLarge.value as? String, "Vald")
        XCTAssertEqual(standard.value as? String ?? "", "")
        attachScreenshot("Settings-Arabic-size-preview")
        app.tabBars.buttons["Koranen"].tap()
        let markRead = app.buttons["reader.markRead.1.1"]
        scrollFullyIntoView(markRead)
        XCTAssertTrue(markRead.isEnabled)
        attachScreenshot("Reader-extra-large-Arabic-size")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Mitt"].waitForExistence(timeout: 10))
        let progress = app.descendants(matching: .any).matching(identifier: "home.dailyProgress").firstMatch
        XCTAssertEqual(progress.value as? String, "0 av 3 verser lästa")
        app.tabBars.buttons["Mitt"].tap()
        scrollTo(openSizes)
        openSizes.tap()
        XCTAssertTrue(extraLarge.waitForExistence(timeout: 5))
        XCTAssertEqual(extraLarge.value as? String, "Vald", "The chosen base size must survive a real relaunch")
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitUntilVerseStartsNearTop(_ element: XCUIElement) -> Bool {
        let readerBar = app.navigationBars["Koranen"]
        let tabBar = app.tabBars.firstMatch
        let visible = NSPredicate { candidate, _ in
            guard let candidate = candidate as? XCUIElement,
                  readerBar.exists, tabBar.exists,
                  candidate.exists else { return false }
            let top = readerBar.frame.maxY
            let bottom = tabBar.frame.minY
            let upperLimit = top + min(150, (bottom - top) / 4)
            let frame = candidate.frame
            guard !frame.isEmpty, frame.minY.isFinite, frame.maxY.isFinite,
                  frame.minY >= top, frame.maxY <= upperLimit else { return false }
            return candidate.isHittable
        }
        let expectation = XCTNSPredicateExpectation(predicate: visible, object: element)
        let ready = XCTWaiter.wait(for: [expectation], timeout: 5) == .completed
        if !ready {
            attachScreenshot("Reader-position-not-visible")
            let target = element.exists ? "Target frame: \(element.frame)\n\(element.debugDescription)" : "Target does not exist"
            let bounds: String
            if readerBar.exists && tabBar.exists {
                let top = readerBar.frame.maxY
                let upperLimit = top + min(150, (tabBar.frame.minY - top) / 4)
                bounds = "Expected entire badge between y=\(top) and y=\(upperLimit)."
            } else {
                bounds = "Reader navigation bar or tab bar is missing."
            }
            let diagnostic = XCTAttachment(string: "\(bounds)\n\(target)\n\(app.debugDescription)")
            diagnostic.name = "Reader-target-frame-and-hierarchy"
            diagnostic.lifetime = .keepAlways
            add(diagnostic)
        }
        return ready
    }

    private func waitUntilControlIsFullyVisible(_ element: XCUIElement) -> Bool {
        let visible = NSPredicate { candidate, _ in
            guard let candidate = candidate as? XCUIElement, candidate.exists,
                  self.app.navigationBars.firstMatch.exists, self.app.tabBars.firstMatch.exists else { return false }
            let frame = candidate.frame
            guard !frame.isEmpty, frame.minY.isFinite, frame.maxY.isFinite,
                  frame.minY >= self.app.navigationBars.firstMatch.frame.maxY,
                  frame.maxY <= self.app.tabBars.firstMatch.frame.minY else { return false }
            return candidate.isHittable
        }
        return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: visible, object: element)], timeout: 5) == .completed
    }

    private func scrollTo(_ element: XCUIElement) {
        for _ in 0..<6 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable)
    }

    private func scrollFullyIntoView(_ element: XCUIElement) {
        var movesContentUp = true
        for _ in 0..<10 {
            let top = app.navigationBars.firstMatch.frame.maxY
            let bottom = app.tabBars.firstMatch.frame.minY
            let maximumStep = (bottom - top) * 0.4
            var distance = maximumStep
            if element.exists {
                let frame = element.frame
                if element.isHittable && frame.minY >= top && frame.maxY <= bottom { return }
                if !frame.isEmpty, frame.minY.isFinite, frame.maxY.isFinite {
                    movesContentUp = frame.minY >= top
                    let remaining = movesContentUp ? frame.maxY - bottom : top - frame.minY
                    distance = min(maximumStep, max(24, remaining + 12))
                }
            }
            // A whole-screen flick can skip the complete control on a compact
            // iPhone at accessibility XXXL. Move only the missing distance and
            // retain direction if List temporarily recycles the target cell.
            let middle = (top + bottom) / 2
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: app.frame.width / 2, dy: middle))
            let end = origin.withOffset(CGVector(dx: app.frame.width / 2,
                                                dy: middle + (movesContentUp ? -distance : distance)))
            start.press(forDuration: 0.1, thenDragTo: end)
        }
        XCTAssertTrue(element.exists && element.isHittable)
        XCTAssertGreaterThanOrEqual(element.frame.minY, app.navigationBars.firstMatch.frame.maxY)
        XCTAssertLessThanOrEqual(element.frame.maxY, app.tabBars.firstMatch.frame.minY)
    }
}
