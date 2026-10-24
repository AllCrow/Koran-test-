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
            guard issue.startScalar >= 0, issue.endScalar <= scalarCount,
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

        var result: [FeedbackSpan] = []
        var scalarStart = 0
        var rangeIndex = 0
        for character in text {
            let fragment = String(character)
            let scalarEnd = scalarStart + fragment.unicodeScalars.count
            while rangeIndex < ranges.count, ranges[rangeIndex].upperBound <= scalarStart { rangeIndex += 1 }
            let highlighted = rangeIndex < ranges.count && ranges[rangeIndex].lowerBound < scalarEnd
            if let last = result.last, last.isHighlighted == highlighted {
                result[result.count - 1] = FeedbackSpan(text: last.text + fragment, isHighlighted: highlighted)
            } else {
                result.append(FeedbackSpan(text: fragment, isHighlighted: highlighted))
            }
            scalarStart = scalarEnd
        }
        return result
    }
}
