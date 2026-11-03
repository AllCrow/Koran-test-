import XCTest
@testable import QuranCore

final class ReadingViewportTests: XCTestCase {
    private func frame(_ verse: Int, _ minY: Double, _ maxY: Double,
                       surah: Int = 2) -> ReadingVerseFrame {
        ReadingVerseFrame(reference: AyahReference(surahID: surah, ayahNumber: verse)!,
                          minY: minY, maxY: maxY)
    }

    func testTallVerseRemainsThePositionWhileItsBeginningIsAboveTheViewport() {
        let tall = frame(255, -900, 300)
        let next = frame(256, 316, 600)
        XCTAssertEqual(ReadingViewport.leadingReference(in: [next, tall], surahID: 2, height: 500), tall.reference)
    }

    func testPreviousVerseSliverDoesNotOverrideTheNextVisibleVerse() {
        let previous = frame(254, -400, 1)
        let next = frame(255, 17, 600)
        XCTAssertEqual(ReadingViewport.leadingReference(in: [previous, next], surahID: 2, height: 500), next.reference)
    }

    func testExactMinimumIntersectionRetainsTheCurrentVerse() {
        let current = frame(254, -400, 24)
        let next = frame(255, 40, 600)
        XCTAssertEqual(ReadingViewport.leadingReference(in: [next, current], surahID: 2, height: 500), current.reference)
    }

    func testFullyOffscreenPrefetchedRowsAndViewportBoundaryTouchesAreIgnored() {
        let frames = [frame(1, -200, -16), frame(2, -100, 0),
                      frame(5, 500, 700), frame(6, 716, 1000)]
        XCTAssertNil(ReadingViewport.leadingReference(in: frames, surahID: 2, height: 500))
    }

    func testOldChapterGeometryCannotReplaceTheCurrentChapterPosition() {
        let old = frame(1, -10, 100, surah: 1)
        let current = frame(3, 116, 600)
        XCTAssertEqual(ReadingViewport.leadingReference(in: [old, current], surahID: 2, height: 500), current.reference)
        XCTAssertNil(ReadingViewport.leadingReference(in: [old], surahID: 2, height: 500))
    }

    func testInvalidNonfiniteReversedZeroAndOverflowingFramesAreIgnored() {
        let invalid = [frame(1, .nan, 100), frame(2, 0, .nan),
                       frame(3, -.infinity, 100), frame(4, 0, .infinity),
                       frame(5, 40, 20), frame(6, 20, 20),
                       frame(7, -Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude)]
        XCTAssertNil(ReadingViewport.leadingReference(in: invalid, surahID: 2, height: 500))
        let valid = frame(8, 60, 400)
        XCTAssertEqual(ReadingViewport.leadingReference(in: invalid + [valid], surahID: 2, height: 500), valid.reference)
    }

    func testOverlappingFramesHaveDeterministicGeometricThenVerseOrdering() {
        let first = frame(2, 20, 300)
        let later = frame(3, 20, 300)
        let lower = frame(1, 40, 350)
        for frames in [[first, later, lower], [lower, later, first], [later, first, lower]] {
            XCTAssertEqual(ReadingViewport.leadingReference(in: frames, surahID: 2, height: 500), first.reference)
        }
    }

    func testShortRowsRequireFullVisibilityAndTinyViewportsRemainUsable() {
        let short = frame(1, 8, 20)
        let clipped = frame(2, -2, 10)
        XCTAssertEqual(ReadingViewport.leadingReference(in: [clipped, short], surahID: 2, height: 500), short.reference)
        let tall = frame(3, -100, 400)
        XCTAssertEqual(ReadingViewport.leadingReference(in: [tall], surahID: 2, height: 10), tall.reference)
    }

    func testInvalidViewportsAndChaptersNeverSelectAPosition() {
        let rows = [frame(1, 0, 100)]
        for height in [0, -1, Double.nan, Double.infinity, -Double.infinity] {
            XCTAssertNil(ReadingViewport.leadingReference(in: rows, surahID: 2, height: height))
        }
        for surah in [0, 115] {
            XCTAssertNil(ReadingViewport.leadingReference(in: rows, surahID: surah, height: 500))
        }
        XCTAssertNil(ReadingViewport.leadingReference(in: [], surahID: 2, height: 500))
    }
}
