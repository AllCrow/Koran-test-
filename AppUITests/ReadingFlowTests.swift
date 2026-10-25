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
        markRead.tap()
        XCTAssertFalse(markRead.isEnabled)
        app.tabBars.buttons["Idag"].tap()
        XCTAssertEqual(progress.value as? String, "1 av 3 verser lästa")
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
        app.tabBars.buttons["Mitt"].tap()
        scrollTo(app.buttons["settings.bookmark.112.1"])
        XCTAssertFalse(app.buttons["settings.bookmark.1.1"].exists, "The action must save the chosen sura's verse")
    }

    private func scrollTo(_ element: XCUIElement) {
        for _ in 0..<6 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable)
    }
}
