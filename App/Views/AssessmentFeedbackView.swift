import SwiftUI
import QuranPractice

@MainActor
struct AssessmentFeedbackView: View {
    let response: RecitationAssessment

    var body: some View {
        Card {
            Label("Återkoppling · testversion", systemImage: "waveform")
                .font(.headline).foregroundStyle(Palette.green)
            Text(response.message).font(.callout).padding(.top, 10)
            if response.status == .assessed {
                highlightedText.padding(.vertical, 18)
                Text("Analysens referenstext · Hafs")
                    .font(.caption).foregroundStyle(.secondary)
                if response.issues.isEmpty {
                    Text("Inga avvikelser upptäcktes av modellen. Det är inte ett intyg på att recitationen är korrekt.")
                        .font(.footnote).foregroundStyle(.secondary).padding(.top, 12)
                }
                ForEach(Array(response.issues.enumerated()), id: \.offset) { index, issue in
                    Divider().padding(.vertical, 12)
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)").font(.caption.weight(.semibold))
                            .frame(width: 25, height: 25)
                            .background(Palette.gold.opacity(0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 5) {
                            Text(label(issue.kind)).font(.subheadline.weight(.semibold))
                            Text(issue.message).font(.callout).foregroundStyle(.secondary)
                        }
                    }
                }
                DisclosureGroup("Vilken läsning används?") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(response.assumptions, id: \.self) { Text($0).font(.caption) }
                    }.foregroundStyle(.secondary).padding(.top, 8)
                }.font(.footnote).padding(.top, 16)
            }
        }
    }

    private var highlightedText: some View {
        let spans = FeedbackHighlighter.spans(text: response.referenceText, issues: response.issues)
        let text = spans.reduce(Text("")) { result, span in
            result + Text(span.text).foregroundColor(span.isHighlighted ? Palette.gold : .primary)
                .underline(span.isHighlighted, color: Palette.gold)
        }
        return text
            .font(.custom("AmiriQuran-Regular", size: 30, relativeTo: .title))
            .lineSpacing(15).multilineTextAlignment(.trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .environment(\.layoutDirection, .rightToLeft)
            .accessibilityLabel(response.referenceText)
            .textSelection(.enabled)
    }

    private func label(_ kind: AssessmentIssue.Kind) -> String {
        switch kind {
        case .tajweed: return "Kontrollera tajweed"
        case .normal: return "Kontrollera ljud eller ord"
        case .tashkeel: return "Kontrollera vokalljud"
        }
    }
}
