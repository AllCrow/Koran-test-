import Foundation

public struct FeedbackSpan: Hashable, Sendable {
    public let text: String
    public let isHighlighted: Bool
}

public enum FeedbackHighlighter {
    /// Expands model scalar ranges to whole graphemes, keeping Arabic marks attached.
    /// Insertion-only feedback has no source character and is deliberately not colored.
    public static func spans(text: String, issues: [AssessmentIssue]) -> [FeedbackSpan] {
        let scalarCount = text.unicodeScalars.count
        let sorted = issues.compactMap { issue -> Range<Int>? in
            guard issue.category != .insert,
                  issue.startScalar >= 0, issue.endScalar <= scalarCount,
                  issue.startScalar < issue.endScalar else { return nil }
            return issue.startScalar..<issue.endScalar
        }.sorted { lhs, rhs in
            lhs.lowerBound == rhs.lowerBound ? lhs.upperBound < rhs.upperBound : lhs.lowerBound < rhs.lowerBound
        }
        var ranges: [Range<Int>] = []
        for range in sorted {
            if let last = ranges.last, range.lowerBound <= last.upperBound {
                ranges[ranges.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
            } else { ranges.append(range) }
        }
        guard !ranges.isEmpty else {
            return text.isEmpty ? [] : [FeedbackSpan(text: text, isHighlighted: false)]
        }

        var result: [FeedbackSpan] = []
        var scalarStart = 0
        var rangeIndex = 0
        var pendingText = ""
        var pendingHighlight = false
        // Append into one uniquely owned buffer until the style changes. Building
        // `last.text + fragment` per grapheme copies an ever-growing span for
        // long verses or references without any highlighted characters.
        func flush() {
            guard !pendingText.isEmpty else { return }
            result.append(FeedbackSpan(text: pendingText, isHighlighted: pendingHighlight))
            pendingText = ""
        }
        for character in text {
            let fragment = String(character)
            let scalarEnd = scalarStart + fragment.unicodeScalars.count
            while rangeIndex < ranges.count, ranges[rangeIndex].upperBound <= scalarStart { rangeIndex += 1 }
            let highlighted = rangeIndex < ranges.count && ranges[rangeIndex].lowerBound < scalarEnd
            if !pendingText.isEmpty && pendingHighlight != highlighted {
                flush()
            }
            pendingHighlight = highlighted
            pendingText.append(contentsOf: fragment)
            scalarStart = scalarEnd
        }
        flush()
        return result
    }
}
