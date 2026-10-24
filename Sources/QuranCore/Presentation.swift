import Foundation

/// Presentation-only extraction of an opening Basmala from the Uthmani edition.
/// The original `Ayah.text` remains verbatim, including its source orthography.
public enum QuranPresentation {
    private static let recognizedPrefixes = [
        "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ ",
        "بِّسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ "
    ]

    public static func basmala(for chapter: QuranChapter) -> String? {
        guard let firstAyah = chapter.ayahs.first(where: {
            $0.surahID == chapter.surah.id && $0.numberInSurah == 1
        }) else { return nil }
        return basmala(for: firstAyah)
    }

    public static func basmala(for ayah: Ayah) -> String? {
        splitOpening(ayah)?.header
    }

    public static func verseText(_ ayah: Ayah) -> String {
        splitOpening(ayah)?.verse ?? ayah.text
    }

    private static func splitOpening(_ ayah: Ayah) -> (header: String, verse: String)? {
        guard ayah.numberInSurah == 1, ayah.surahID != 1, ayah.surahID != 9 else { return nil }
        let source = ayah.text.unicodeScalars
        for prefix in recognizedPrefixes {
            let prefixScalars = prefix.unicodeScalars
            guard source.starts(with: prefixScalars) else { continue }
            // Slice the source scalars, rather than reconstructing a header or
            // using canonical-equivalence matching on composed characters.
            let header = String(String.UnicodeScalarView(source.prefix(prefixScalars.count - 1)))
            let verse = String(String.UnicodeScalarView(source.dropFirst(prefixScalars.count)))
            return (header, verse)
        }
        return nil
    }
}
