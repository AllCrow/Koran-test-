import XCTest
@testable import QuranPractice

final class FeedbackHighlighterTests: XCTestCase {
    func testArabicCombiningMarkHighlightsWholeLetterWithoutDetachingVowels() {
        let text = "بِسْمِ"
        let spans = FeedbackHighlighter.spans(text: text, issues: [issue(1, 2)])
        XCTAssertEqual(spans.count, 2)
        XCTAssertEqual(spans.first?.text, "بِ")
        XCTAssertEqual(spans.first?.isHighlighted, true)
        XCTAssertEqual(spans.last?.text, "سْمِ")
        XCTAssertEqual(spans.last?.isHighlighted, false)
        XCTAssertTrue(spans.map(\.text).joined().utf8.elementsEqual(text.utf8))
    }

    func testEmojiJoinerAndNonBMPScalarsAreNeverSplitAsUTF16Offsets() {
        let text = "بِ 👩🏽‍💻 𐀀 تَ"
        let source = Array(text.unicodeScalars)
        let joiner = source.firstIndex(of: "\u{200D}")!
        let nonBMP = source.firstIndex(of: "𐀀")!
        let spans = FeedbackHighlighter.spans(text: text, issues: [issue(joiner, joiner + 1), issue(nonBMP, nonBMP + 1)])
        let highlights = spans.filter(\.isHighlighted).map(\.text)
        XCTAssertEqual(highlights, ["👩🏽‍💻", "𐀀"])
        XCTAssertTrue(spans.map(\.text).joined().unicodeScalars.elementsEqual(text.unicodeScalars))
    }

    func testOverlappingRangesMergeAndInsertionsDoNotInventSourceHighlights() {
        let text = "بِسْمِ"
        let count = text.unicodeScalars.count
        let spans = FeedbackHighlighter.spans(text: text, issues: [issue(0, 3), issue(2, count), issue(count, count, category: .insert)])
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans.first?.text, text)
        XCTAssertEqual(spans.first?.isHighlighted, true)
        let insertion = FeedbackHighlighter.spans(text: text, issues: [issue(2, 2, category: .insert)])
        XCTAssertEqual(insertion.count, 1)
        XCTAssertEqual(insertion.first?.isHighlighted, false)
    }

    func testInvalidRangesAreIgnoredAndEmptyInputRemainsEmpty() {
        let text = "ٱللَّهِ"
        let spans = FeedbackHighlighter.spans(text: text, issues: [issue(-1, 2), issue(0, 999), issue(3, 2)])
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans.first?.isHighlighted, false)
        XCTAssertTrue(spans.map(\.text).joined().utf8.elementsEqual(text.utf8))
        XCTAssertTrue(FeedbackHighlighter.spans(text: "", issues: []).isEmpty)
    }

    func testAnchoredInsertionDoesNotColorAnExistingLetter() {
        // A model can anchor an inserted sound to a surrounding source span.
        // That sound has no expected source letter, so the indication belongs
        // in the feedback list without marking a letter as pronounced wrongly.
        let text = "بِسْمِ"
        let spans = FeedbackHighlighter.spans(text: text, issues: [issue(0, 2, category: .insert)])
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans.first?.isHighlighted, false)
        XCTAssertTrue(spans.map(\.text).joined().utf8.elementsEqual(text.utf8))
    }

    func testLongReferencesRetainExactGraphemesAndCoalesceStyles() {
        let beginning = String(repeating: "بِسْمِ ", count: 4_000)
        let highlighted = "👩🏽‍💻 ٱللَّهِ"
        let ending = String(repeating: " رَحْمَةٌ", count: 4_000)
        let text = beginning + highlighted + ending
        let start = beginning.unicodeScalars.count
        let end = start + highlighted.unicodeScalars.count
        let spans = FeedbackHighlighter.spans(text: text, issues: [issue(start, end), issue(start + 1, end - 1)])
        XCTAssertEqual(spans.count, 3)
        XCTAssertEqual(spans.map(\.text), [beginning, highlighted, ending])
        XCTAssertEqual(spans.map(\.isHighlighted), [false, true, false])
        XCTAssertTrue(spans.map(\.text).joined().utf8.elementsEqual(text.utf8))
        let plain = FeedbackHighlighter.spans(text: text, issues: [])
        XCTAssertEqual(plain.count, 1)
        XCTAssertEqual(plain.first?.text, text)
        XCTAssertEqual(plain.first?.isHighlighted, false)
    }

    private func issue(_ start: Int, _ end: Int, category: AssessmentIssue.Category = .replace) -> AssessmentIssue {
        AssessmentIssue(kind: .tajweed, category: category, startScalar: start, endScalar: end, expected: "", observed: "", message: "")
    }
}
