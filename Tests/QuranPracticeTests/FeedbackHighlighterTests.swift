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

    private func issue(_ start: Int, _ end: Int, category: AssessmentIssue.Category = .replace) -> AssessmentIssue {
        AssessmentIssue(kind: .tajweed, category: category, startScalar: start, endScalar: end, expected: "", observed: "", message: "")
    }
}
