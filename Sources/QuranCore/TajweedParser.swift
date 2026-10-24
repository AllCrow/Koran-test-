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
    /// Parses `[h:123[ٱ]` and `[n[ـٰ]` without using grapheme offsets.
    /// Malformed and unknown annotations are preserved literally, never discarded.
    public static func parse(_ source: String) -> [TajweedSpan] {
        let scalars = Array(source.unicodeScalars)
        var spans: [TajweedSpan] = []
        var plain = ""
        var index = 0

        func scalarString(_ range: Range<Int>) -> String {
            String(String.UnicodeScalarView(scalars[range]))
        }
        func flushPlain() {
            guard !plain.isEmpty else { return }
            spans.append(TajweedSpan(text: plain))
            plain = ""
        }

        while index < scalars.count {
            guard scalars[index] == "[", index + 2 < scalars.count,
                  (97...122).contains(scalars[index + 1].value) else {
                plain.unicodeScalars.append(scalars[index])
                index += 1
                continue
            }
            var headerEnd = index + 2
            if scalars[headerEnd] == ":" {
                headerEnd += 1
                let digitsStart = headerEnd
                while headerEnd < scalars.count, (48...57).contains(scalars[headerEnd].value) {
                    headerEnd += 1
                }
                guard headerEnd > digitsStart else {
                    plain.unicodeScalars.append(scalars[index])
                    index += 1
                    continue
                }
            }
            guard headerEnd < scalars.count, scalars[headerEnd] == "[" else {
                plain.unicodeScalars.append(scalars[index])
                index += 1
                continue
            }
            var end = headerEnd + 1
            while end < scalars.count, scalars[end] != "]", scalars[end] != "[" { end += 1 }
            guard end < scalars.count, scalars[end] == "]" else {
                // Do not partially interpret a broken or nested annotation.
                plain += scalarString(index..<scalars.count)
                index = scalars.count
                continue
            }
            if let rule = TajweedRule(rawValue: String(scalars[index + 1])) {
                flushPlain()
                let content = scalarString((headerEnd + 1)..<end)
                if !content.isEmpty { spans.append(TajweedSpan(text: content, rule: rule)) }
            } else {
                plain += scalarString(index..<(end + 1))
            }
            index = end + 1
        }
        flushPlain()
        return spans
    }

    public static func plainText(_ source: String) -> String {
        parse(source).map(\.text).joined()
    }
}
