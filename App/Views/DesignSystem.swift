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
        uniqueKeysWithValues: TajweedRule.allCases.map { ($0, Color(uiColor: makeTajweedColor($0))) }
    )

    static func tajweed(_ rule: TajweedRule) -> Color {
        tajweedColors[rule] ?? .primary
    }

    private static func makeTajweedColor(_ rule: TajweedRule) -> UIColor {
        let hex = UInt32(rule.colorHex, radix: 16) ?? 0
        let source = UIColor(red: CGFloat((hex >> 16) & 255) / 255,
                             green: CGFloat((hex >> 8) & 255) / 255,
                             blue: CGFloat(hex & 255) / 255, alpha: 1)
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        source.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        let isNeutral = saturation == 0
        let light = readableTajweedColor(hue: hue, saturation: saturation,
                                        brightness: min(brightness, 0.65), style: .light, contrast: .normal)
        let dark = readableTajweedColor(hue: hue, saturation: min(saturation, 0.55),
                                       brightness: isNeutral ? 0.62 : max(brightness, 0.95), style: .dark, contrast: .normal)
        let strongLight = readableTajweedColor(hue: hue, saturation: saturation,
                                              brightness: min(brightness, 0.65), style: .light, contrast: .high)
        let strongDark = readableTajweedColor(hue: hue, saturation: min(saturation, 0.55),
                                             brightness: isNeutral ? 0.62 : max(brightness, 0.95), style: .dark, contrast: .high)
        // Compute the four variants once. Resolving a colour while scrolling
        // only selects a prepared value; it does not repeat contrast work.
        return UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return traits.accessibilityContrast == .high ? strongDark : dark
            }
            return traits.accessibilityContrast == .high ? strongLight : light
        }
    }

    /// Retain the source hue, including neutral annotation letters. Small
    /// diacritics remain readable even though the containing Arabic text uses
    /// a large font. Increased Contrast receives the stronger 7:1 variant.
    private static func readableTajweedColor(hue: CGFloat, saturation: CGFloat, brightness: CGFloat,
                                             style: UIUserInterfaceStyle, contrast: UIAccessibilityContrast) -> UIColor {
        let traits = UITraitCollection(traitsFrom: [UITraitCollection(userInterfaceStyle: style),
                                                   UITraitCollection(accessibilityContrast: contrast)])
        let background = UIColor.secondarySystemGroupedBackground.resolvedColor(with: traits)
        let minimum = contrast == .high ? 7.05 : 4.55
        func color(_ saturation: CGFloat, _ brightness: CGFloat) -> UIColor {
            UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1)
        }
        let original = color(saturation, brightness)
        guard contrastRatio(original, background) < minimum else { return original }

        if style == .light {
            var lower: CGFloat = 0
            var upper = brightness
            var best = color(saturation, lower)
            for _ in 0..<18 {
                let candidate = (lower + upper) / 2
                let value = color(saturation, candidate)
                if contrastRatio(value, background) >= minimum {
                    lower = candidate
                    best = value
                } else { upper = candidate }
            }
            return best
        }

        let brightest = color(saturation, 1)
        if contrastRatio(brightest, background) >= minimum {
            var lower = brightness
            var upper: CGFloat = 1
            var best = brightest
            for _ in 0..<18 {
                let candidate = (lower + upper) / 2
                let value = color(saturation, candidate)
                if contrastRatio(value, background) >= minimum {
                    upper = candidate
                    best = value
                } else { lower = candidate }
            }
            return best
        }

        // Deep blue/red hues may need a lighter pastel to reach 7:1 on dark
        // paper. Reduce saturation only after brightness reaches its limit.
        var lower: CGFloat = 0
        var upper = saturation
        var best = color(lower, 1)
        for _ in 0..<18 {
            let candidate = (lower + upper) / 2
            let value = color(candidate, 1)
            if contrastRatio(value, background) >= minimum {
                lower = candidate
                best = value
            } else { upper = candidate }
        }
        return best
    }

    private static func contrastRatio(_ foreground: UIColor, _ background: UIColor) -> Double {
        func luminance(_ color: UIColor) -> Double {
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return 0 }
            func linear(_ value: CGFloat) -> Double {
                let value = Double(value)
                return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        }
        let first = luminance(foreground), second = luminance(background)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
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
        Label {
            Text(message).foregroundStyle(.primary)
        } icon: {
            Image(systemName: "exclamationmark.circle").foregroundStyle(.red)
        }
            .font(.callout).padding()
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
