import Foundation

/// Codes used by the Al Quran Cloud `quran-tajweed` edition.
/// These are display annotations, not an assessment of a person's recitation.
public enum TajweedRule: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case hamzatWasl = "h"
    case silent = "s"
    case lamShamsiyyah = "l"
    case maddNormal = "n"
    case maddPermissible = "p"
    case maddNecessary = "m"
    case qalqalah = "q"
    case maddObligatory = "o"
    case ikhfaShafawi = "c"
    case ikhfa = "f"
    case idghamShafawi = "w"
    case iqlab = "i"
    case idghamWithGhunnah = "a"
    case idghamWithoutGhunnah = "u"
    case idghamMutajanisayn = "d"
    case idghamMutaqaribayn = "b"
    case ghunnah = "g"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .hamzatWasl: return "Hamzat al-wasl"
        case .silent: return "Tyst bokstav"
        case .lamShamsiyyah: return "Lam shamsiyyah"
        case .maddNormal: return "Madd · naturlig förlängning"
        case .maddPermissible: return "Madd · tillåten förlängning"
        case .maddNecessary: return "Madd · nödvändig förlängning"
        case .qalqalah: return "Qalqalah"
        case .maddObligatory: return "Madd · obligatorisk förlängning"
        case .ikhfaShafawi: return "Ikhfa shafawi"
        case .ikhfa: return "Ikhfa"
        case .idghamShafawi: return "Idgham shafawi"
        case .iqlab: return "Iqlab"
        case .idghamWithGhunnah: return "Idgham med ghunnah"
        case .idghamWithoutGhunnah: return "Idgham utan ghunnah"
        case .idghamMutajanisayn: return "Idgham mutajanisayn"
        case .idghamMutaqaribayn: return "Idgham mutaqaribayn"
        case .ghunnah: return "Ghunnah"
        }
    }

    public var colorHex: String {
        switch self {
        case .hamzatWasl, .silent, .lamShamsiyyah: return "AAAAAA"
        case .maddNormal: return "537FFF"
        case .maddPermissible: return "4050FF"
        case .maddNecessary: return "000EBC"
        case .qalqalah: return "DD0008"
        case .maddObligatory: return "2144C1"
        case .ikhfaShafawi: return "D500B7"
        case .ikhfa: return "9400A8"
        case .idghamShafawi: return "58B800"
        case .iqlab: return "26BFFD"
        case .idghamWithGhunnah: return "169777"
        case .idghamWithoutGhunnah: return "169200"
        case .idghamMutajanisayn, .idghamMutaqaribayn: return "A1A1A1"
        case .ghunnah: return "FF7E1E"
        }
    }
}

public struct TajweedSpan: Hashable, Sendable {
    public let text: String
    public let rule: TajweedRule?

    public init(text: String, rule: TajweedRule? = nil) {
        self.text = text
        self.rule = rule
    }
}

public enum TajweedParser {
    /// Parses `[h:123[ٱ]`, `[n[ـٰ]` and nested annotations without
    /// grapheme offsets. Inner annotations take precedence over outer rules.
    /// Malformed and unknown annotations remain literal, never discarded.
    public static func parse(_ source: String) -> [TajweedSpan] {
        let scalars = Array(source.unicodeScalars)

        func scalarString(_ range: Range<Int>) -> String {
            String(String.UnicodeScalarView(scalars[range]))
        }
        func header(at start: Int) -> (rule: TajweedRule?, contentStart: Int)? {
            guard start + 2 < scalars.count, scalars[start] == "[",
                  (97...122).contains(scalars[start + 1].value) else { return nil }
            var end = start + 2
            if scalars[end] == ":" {
                end += 1
                let digitsStart = end
                while end < scalars.count, (48...57).contains(scalars[end].value) { end += 1 }
                guard end > digitsStart else { return nil }
            }
            guard end < scalars.count, scalars[end] == "[" else { return nil }
            return (TajweedRule(rawValue: String(scalars[start + 1])), end + 1)
        }
        func annotation(at start: Int, depth: Int = 0) -> (spans: [TajweedSpan], next: Int)? {
            // The bundled edition nests at most two rules. Bound recursion so
            // damaged or unexpectedly deep input falls back verbatim instead
            // of exhausting the stack while rendering a verse.
            guard depth < 64, let annotationHeader = header(at: start) else { return nil }
            var spans: [TajweedSpan] = []
            var plain = ""
            var index = annotationHeader.contentStart
            func flush() {
                guard !plain.isEmpty else { return }
                spans.append(TajweedSpan(text: plain, rule: annotationHeader.rule))
                plain = ""
            }
            while index < scalars.count {
                if scalars[index] == "]" {
                    if annotationHeader.rule == nil {
                        return ([TajweedSpan(text: scalarString(start..<(index + 1)))], index + 1)
                    }
                    flush()
                    return (spans, index + 1)
                }
                if scalars[index] == "[" {
                    guard let child = annotation(at: index, depth: depth + 1) else { return nil }
                    flush()
                    spans.append(contentsOf: child.spans)
                    index = child.next
                } else {
                    plain.unicodeScalars.append(scalars[index])
                    index += 1
                }
            }
            return nil
        }

        var result: [TajweedSpan] = []
        var plain = ""
        var index = 0
        func flush() {
            guard !plain.isEmpty else { return }
            result.append(TajweedSpan(text: plain))
            plain = ""
        }
        while index < scalars.count {
            if let token = annotation(at: index) {
                flush()
                result.append(contentsOf: token.spans)
                index = token.next
            } else if header(at: index) != nil {
                // An incomplete outer annotation must not be partly stripped.
                plain += scalarString(index..<scalars.count)
                index = scalars.count
            } else {
                plain.unicodeScalars.append(scalars[index])
                index += 1
            }
        }
        flush()
        return result
    }

    public static func plainText(_ source: String) -> String {
        parse(source).map(\.text).joined()
    }
}
