import SwiftUI
import QuranPractice

@MainActor
struct AssessmentFeedbackView: View {
    let response: RecitationAssessment
    @State private var visibleIssueCount = 20

    var body: some View {
        Card {
            Label("Återkoppling · testversion", systemImage: "waveform")
                .font(.headline).foregroundStyle(Palette.green).accessibilityAddTraits(.isHeader)
            Text("Sura \(response.reference.surahID) · vers \(response.reference.ayahNumber)")
                .font(.caption).foregroundStyle(.secondary).padding(.top, 6)
            Text(response.message).font(.callout).padding(.top, 10)
            if response.status == .assessed {
                highlightedText.padding(.vertical, 18)
                Text("Analysens referenstext · Hafs")
                    .font(.caption).foregroundStyle(.secondary)
                if response.issues.isEmpty {
                    Text("Inga avvikelser upptäcktes av modellen. Det är inte ett intyg på att recitationen är korrekt.")
                        .font(.footnote).foregroundStyle(.secondary).padding(.top, 12)
                }
                // Detail excerpts scan whole graphemes. Bound initial layout
                // work even when a long verse has many model indications.
                ForEach(Array(response.issues.prefix(visibleIssueCount).enumerated()), id: \.offset) { index, issue in
                    Divider().padding(.vertical, 12)
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)").font(.caption.weight(.semibold))
                            .frame(width: 25, height: 25)
                            .background(Palette.gold.opacity(0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 5) {
                            Text(label(issue.kind)).font(.subheadline.weight(.semibold))
                            Text(issue.message).font(.callout).foregroundStyle(.secondary)
                            if let excerpt = referenceExcerpt(for: issue) {
                                Text("I referenstexten:").font(.caption).foregroundStyle(.secondary)
                                Text(excerpt)
                                    .font(.custom("AmiriQuran-Regular", size: 24, relativeTo: .title3))
                                    .lineSpacing(10).multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .environment(\.layoutDirection, .rightToLeft)
                                    .accessibilityRepresentation { ArabicAccessibilityLabel(text: excerpt) }
                                    .textSelection(.enabled)
                            } else if issue.category == .insert {
                                Text("Modellen indikerar ett möjligt extra ljud. Det ljudet har ingen egen plats i referenstexten.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if visibleIssueCount < response.issues.count {
                    Button("Visa fler indikationer (\(response.issues.count - visibleIssueCount) kvar)") {
                        visibleIssueCount = min(response.issues.count, visibleIssueCount + 20)
                    }.font(.callout).frame(minHeight: 44).padding(.top, 12)
                }
                DisclosureGroup("Vilken läsning används?") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(response.assumptions, id: \.self) { Text($0).font(.caption) }
                    }.foregroundStyle(.secondary).padding(.top, 8)
                }.font(.footnote).padding(.top, 16)
            }
        }
        .onChange(of: response) { _, _ in visibleIssueCount = 20 }
    }

    private var highlightedText: some View {
        let spans = FeedbackHighlighter.spans(text: response.referenceText, issues: response.issues)
        let text = spans.reduce(Text("")) { result, span in
            result + Text(span.text).foregroundColor(span.isHighlighted ? Palette.gold : .primary)
                .underline(span.isHighlighted, color: Palette.gold)
        }
        return text
            .font(.custom("AmiriQuran-Regular", size: 30, relativeTo: .title))
            .lineSpacing(15).multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .rightToLeft)
            .accessibilityLabel(response.referenceText)
            .accessibilityRepresentation { ArabicAccessibilityLabel(text: response.referenceText) }
            .textSelection(.enabled)
    }

    private func referenceExcerpt(for issue: AssessmentIssue) -> String? {
        // Use the same whole-grapheme expansion as the highlighted reference;
        // never split an Arabic letter from its combining marks for this label.
        let spans = FeedbackHighlighter.spans(text: response.referenceText, issues: [issue])
        let excerpt = spans.filter(\.isHighlighted).map(\.text).joined()
        return excerpt.isEmpty ? nil : excerpt
    }

    private func label(_ kind: AssessmentIssue.Kind) -> String {
        switch kind {
        case .tajweed: return "Kontrollera tajweed"
        case .normal: return "Kontrollera ljud eller ord"
        case .tashkeel: return "Kontrollera vokalljud"
        }
    }
}
