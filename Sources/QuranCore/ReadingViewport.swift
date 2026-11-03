import Foundation

/// A measured verse row in the reader viewport's vertical coordinate space.
/// This is geometry only: selecting a position never grants reading credit.
public struct ReadingVerseFrame: Equatable, Sendable {
    public let reference: AyahReference
    public let minY: Double
    public let maxY: Double

    public init(reference: AyahReference, minY: Double, maxY: Double) {
        self.reference = reference
        self.minY = minY
        self.maxY = maxY
    }
}

public enum ReadingViewport {
    /// Select the first substantially visible verse, including a tall verse
    /// whose beginning has scrolled above the viewport. A trailing sliver of
    /// the previous row must not conceal the user's next reading position.
    ///
    /// Callers own user-scroll intent and stale navigation guards; prefetched
    /// and old-chapter rows cannot by themselves establish a reading position.
    public static func leadingReference(in frames: [ReadingVerseFrame],
                                        surahID: Int, height: Double) -> AyahReference? {
        guard (1...AyahReference.ayahCounts.count).contains(surahID),
              height.isFinite, height > 0 else { return nil }
        var leading: ReadingVerseFrame?
        for frame in frames {
            guard frame.reference.surahID == surahID,
                  frame.minY.isFinite, frame.maxY.isFinite,
                  frame.maxY > frame.minY else { continue }
            let rowHeight = frame.maxY - frame.minY
            guard rowHeight.isFinite else { continue }
            let visibleHeight = min(frame.maxY, height) - max(frame.minY, 0)
            // For a short row or viewport require its whole available height.
            // Normal verse rows need at least 24 points, never just one pixel.
            guard visibleHeight >= min(24, min(rowHeight, height)) else { continue }
            if let current = leading {
                if frame.minY < current.minY ||
                    (frame.minY == current.minY && frame.reference.ayahNumber < current.reference.ayahNumber) {
                    leading = frame
                }
            } else {
                leading = frame
            }
        }
        return leading?.reference
    }
}
