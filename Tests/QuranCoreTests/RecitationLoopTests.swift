import XCTest
@testable import QuranCore

final class RecitationLoopTests: XCTestCase {
    func testFiniteIntervalAdvancesEveryVerseAndCycleWithoutEscapingItsBounds() throws {
        let loop = try XCTUnwrap(RecitationLoop(surahID: 2, startVerse: 254, endVerse: 256, cycles: 2, pauseSeconds: 3))
        var reference = loop.firstReference
        var cycle = 1
        var observed = ["\(cycle):\(reference.id)"]
        while let next = loop.next(after: reference, cycle: cycle) {
            reference = next.reference
            cycle = next.cycle
            observed.append("\(cycle):\(reference.id)")
        }
        XCTAssertEqual(observed, ["1:2:254", "1:2:255", "1:2:256", "2:2:254", "2:2:255", "2:2:256"])
    }

    func testOneVerseCanRepeatAndStopsAtItsDeclaredFiniteCount() throws {
        let loop = try XCTUnwrap(RecitationLoop(surahID: 114, startVerse: 6, endVerse: 6, cycles: 20, pauseSeconds: 15))
        for cycle in 1..<20 {
            let next = try XCTUnwrap(loop.next(after: loop.firstReference, cycle: cycle))
            XCTAssertEqual(next.reference, loop.firstReference)
            XCTAssertEqual(next.cycle, cycle + 1)
        }
        XCTAssertNil(loop.next(after: loop.firstReference, cycle: 20))
    }

    func testReversedOutOfCanonAndUnboundedConfigurationsAreRejected() {
        let inputs = [(0, 1, 1, 1, 0), (115, 1, 1, 1, 0), (1, 0, 1, 1, 0), (1, 1, 8, 1, 0),
                      (1, 3, 2, 1, 0), (1, 1, 2, 0, 0), (1, 1, 2, 21, 0), (1, 1, 2, 1, -1), (1, 1, 2, 1, 16)]
        for (surah, first, last, cycles, pause) in inputs {
            XCTAssertNil(RecitationLoop(surahID: surah, startVerse: first, endVerse: last, cycles: cycles, pauseSeconds: pause))
        }
    }

    func testForeignPositionsAndInvalidCycleCannotStartAnExtraPass() throws {
        let loop = try XCTUnwrap(RecitationLoop(surahID: 1, startVerse: 2, endVerse: 3, cycles: 2, pauseSeconds: 0))
        XCTAssertNil(loop.next(after: try XCTUnwrap(AyahReference(surahID: 2, ayahNumber: 2)), cycle: 1))
        XCTAssertNil(loop.next(after: try XCTUnwrap(AyahReference(surahID: 1, ayahNumber: 1)), cycle: 1))
        XCTAssertNil(loop.next(after: try XCTUnwrap(AyahReference(surahID: 1, ayahNumber: 4)), cycle: 1))
        XCTAssertNil(loop.next(after: loop.firstReference, cycle: 0))
        XCTAssertNil(loop.next(after: loop.firstReference, cycle: 3))
    }
}
