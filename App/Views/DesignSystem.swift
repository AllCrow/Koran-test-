import SwiftUI
import UIKit
import QuranCore

@MainActor
enum Palette {
    static let background = Color(uiColor: .systemGroupedBackground)
    static let paper = Color(uiColor: .secondarySystemGroupedBackground)
    static let green = Color(light: UIColor(red: 0.12, green: 0.34, blue: 0.27, alpha: 1),
                             dark: UIColor(red: 0.51, green: 0.80, blue: 0.65, alpha: 1))
    static let gold = Color(light: UIColor(red: 0.52, green: 0.36, blue: 0.08, alpha: 1),
                            dark: UIColor(red: 0.91, green: 0.75, blue: 0.39, alpha: 1))

    private static let tajweedColors: [TajweedRule: Color] = Dictionary(
        uniqueKeysWithValues: TajweedRule.allCases.map { ($0, makeTajweedColor($0)) }
    )

    static func tajweed(_ rule: TajweedRule) -> Color {
        tajweedColors[rule] ?? .primary
    }

    private static func makeTajweedColor(_ rule: TajweedRule) -> Color {
        if [.hamzatWasl, .silent, .lamShamsiyyah, .idghamMutajanisayn, .idghamMutaqaribayn].contains(rule) {
            return .secondary
        }
        let hex = UInt32(rule.colorHex, radix: 16) ?? 0
        let source = UIColor(red: CGFloat((hex >> 16) & 255) / 255,
                             green: CGFloat((hex >> 8) & 255) / 255,
                             blue: CGFloat(hex & 255) / 255, alpha: 1)
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        source.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        // Retain the source hue while keeping the letters legible on both backgrounds.
        return Color(light: UIColor(hue: hue, saturation: saturation, brightness: min(brightness, 0.65), alpha: 1),
                     dark: UIColor(hue: hue, saturation: min(saturation, 0.55), brightness: max(brightness, 0.95), alpha: 1))
    }
}

extension Color {
    @MainActor fileprivate init(light: UIColor, dark: UIColor) {
        self.init(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light })
    }
}

@MainActor
struct Card<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.paper, in: RoundedRectangle(cornerRadius: 24))
    }
}

@MainActor
struct SectionLabel: View {
    let title: String
    var body: some View {
        Text(title).font(.headline).padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

@MainActor
struct PrimaryButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.headline)
                .frame(maxWidth: .infinity).padding(.vertical, 15)
        }
        .buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle(radius: 16))
    }
}

@MainActor
struct ErrorBanner: View {
    let message: String
    var body: some View {
        Label(message, systemImage: "exclamationmark.circle")
            .font(.callout).foregroundStyle(.red).padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.red.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
            .accessibilityLabel("Meddelande: \(message)")
    }
}

struct ArabicTextPreparation {
    let spans: [TajweedSpan]?
    let plainText: String?
    var usesFallback: Bool { spans == nil }
}

/// Reuse annotation work across playback/progress updates. Byte keys deliberately
/// distinguish canonically equivalent strings so source spelling is never reused
/// from another edition. Only a bounded set of recently displayed verses stays.
@MainActor
final class ArabicTextPreparationCache {
    static let shared = ArabicTextPreparationCache()
    private let capacity: Int
    private var entries: [Data: ArabicTextPreparation] = [:]
    private var recentKeys: [Data] = []
    var entryCount: Int { entries.count }

    init(capacity: Int = 64) { self.capacity = max(1, capacity) }

    func preparation(for source: String) -> ArabicTextPreparation {
        let key = Data(source.utf8)
        if let cached = entries[key] {
            touch(key)
            return cached
        }
        let spans = TajweedParser.parse(source)
        let invalid = spans.isEmpty || spans.contains { $0.text.contains("[") || $0.text.contains("]") }
        let prepared = ArabicTextPreparation(
            spans: invalid ? nil : spans,
            plainText: invalid ? nil : spans.map(\.text).joined()
        )
        entries[key] = prepared
        touch(key)
        while recentKeys.count > capacity {
            entries.removeValue(forKey: recentKeys.removeFirst())
        }
        return prepared
    }

    private func touch(_ key: Data) {
        recentKeys.removeAll { $0 == key }
        recentKeys.append(key)
    }
}

@MainActor
struct ArabicText: View {
    let text: String
    let tajweed: String?
    let colored: Bool

    var body: some View {
        let prepared = colored ? tajweed.map { ArabicTextPreparationCache.shared.preparation(for: $0) } : nil
        let safeSpans = prepared?.spans
        let spokenText = prepared?.plainText ?? text
        VStack(alignment: .trailing, spacing: 10) {
            rendered(safeSpans)
            .font(.custom("AmiriQuran-Regular", size: 30, relativeTo: .title))
            .lineSpacing(15)
            // In an explicit RTL environment, semantic leading is the right edge.
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .rightToLeft)
            .accessibilityLabel(spokenText)
            .accessibilityRepresentation {
                ArabicAccessibilityLabel(text: spokenText)
            }
            .textSelection(.enabled)
            if prepared?.usesFallback == true {
                Text("Tajweedfärger är inte tillgängliga för den här versen.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func rendered(_ spans: [TajweedSpan]?) -> Text {
        guard let spans else { return Text(text) }
        return spans.reduce(Text("")) { accumulated, span in
            accumulated + Text(span.text).foregroundColor(ruleColor(span.rule))
        }
    }

    private func ruleColor(_ rule: TajweedRule?) -> Color {
        rule.map(Palette.tajweed) ?? .primary
    }
}

/// SwiftUI's visible text remains selectable; VoiceOver gets an explicit Arabic language.
@MainActor
struct ArabicAccessibilityLabel: UIViewRepresentable {
    let text: String
    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.isAccessibilityElement = true
        label.accessibilityLanguage = "ar"
        label.accessibilityTraits = .staticText
        return label
    }
    func updateUIView(_ label: UILabel, context: Context) {
        label.text = text
        label.accessibilityLabel = text
    }
}

@MainActor
struct TajweedLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tajweedfärger").font(.headline)
            ForEach(TajweedRule.allCases) { rule in
                HStack(spacing: 10) {
                    Image(systemName: "circle.fill").foregroundStyle(Palette.tajweed(rule)).accessibilityHidden(true)
                    Text(rule.displayName)
                }
            }
            Text("Färgerna är läshjälp. De bedömer inte ditt uttal.").foregroundStyle(.secondary)
        }.font(.caption).padding(.vertical, 6)
    }
}
