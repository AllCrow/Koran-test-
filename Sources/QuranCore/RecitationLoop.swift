import Foundation

/// A finite repetition of one canonical, same-surah verse interval.
public struct RecitationLoop: Hashable, Sendable {
    public let surahID: Int
    public let startVerse: Int
    public let endVerse: Int
    public let cycles: Int
    public let pauseSeconds: Int

    public init?(surahID: Int, startVerse: Int, endVerse: Int, cycles: Int, pauseSeconds: Int) {
        guard AyahReference(surahID: surahID, ayahNumber: startVerse) != nil,
              AyahReference(surahID: surahID, ayahNumber: endVerse) != nil,
              startVerse <= endVerse, (1...20).contains(cycles), (0...15).contains(pauseSeconds) else { return nil }
        self.surahID = surahID
        self.startVerse = startVerse
        self.endVerse = endVerse
        self.cycles = cycles
        self.pauseSeconds = pauseSeconds
    }

    public var firstReference: AyahReference {
        // The initializer establishes both canonical bounds.
        AyahReference(surahID: surahID, ayahNumber: startVerse)!
    }

    /// Called only after the current recording's real end event. Nil denotes
    /// either an invalid position or the finite interval's final completion.
    public func next(after reference: AyahReference, cycle: Int) -> RecitationLoopPosition? {
        guard reference.surahID == surahID, (startVerse...endVerse).contains(reference.ayahNumber),
              (1...cycles).contains(cycle) else { return nil }
        if reference.ayahNumber < endVerse {
            return RecitationLoopPosition(
                reference: AyahReference(surahID: surahID, ayahNumber: reference.ayahNumber + 1)!, cycle: cycle
            )
        }
        guard cycle < cycles else { return nil }
        return RecitationLoopPosition(reference: firstReference, cycle: cycle + 1)
    }
}

public struct RecitationLoopPosition: Hashable, Sendable {
    public let reference: AyahReference
    public let cycle: Int
}
