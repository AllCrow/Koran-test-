import Foundation
import QuranCore
import SwiftUI
import UIKit
import XCTest
@testable import Sakina

@MainActor
final class ArabicTextPreparationTests: XCTestCase {
    func testPrimaryActionTextRemainsReadableAgainstItsFillInEveryAppearance() throws {
        for style in [UIUserInterfaceStyle.light, .dark] {
            for contrast in [UIAccessibilityContrast.normal, .high] {
                let traits = UITraitCollection(traitsFrom: [UITraitCollection(userInterfaceStyle: style),
                                                           UITraitCollection(accessibilityContrast: contrast)])
                var foreground = UIColor.clear
                var background = UIColor.clear
                traits.performAsCurrent {
                    foreground = UIColor(Palette.onGreen).resolvedColor(with: traits)
                    background = UIColor(Palette.green).resolvedColor(with: traits)
                }
                XCTAssertGreaterThanOrEqual(try contrastRatio(foreground, background), 4.5,
                                            "Primary text and icons must retain contrast in style \(style.rawValue), contrast \(contrast.rawValue)")
            }
        }
    }

    func testTajweedLettersRemainReadableOnLightAndDarkPaper() throws {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(traitsFrom: [UITraitCollection(userInterfaceStyle: style),
                                                       UITraitCollection(accessibilityContrast: .normal)])
            for rule in TajweedRule.allCases {
                let (foreground, background) = resolvedColors(rule, traits: traits)
                XCTAssertGreaterThanOrEqual(try contrastRatio(foreground, background), 4.5,
                                            "\(rule.rawValue) must retain contrast on \(style.rawValue) paper")
            }
        }
    }

    func testIncreasedContrastPreservesTajweedHuesAndReachesStrongerThreshold() throws {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(traitsFrom: [UITraitCollection(userInterfaceStyle: style),
                                                       UITraitCollection(accessibilityContrast: .high)])
            for rule in TajweedRule.allCases {
                let (foreground, background) = resolvedColors(rule, traits: traits)
                XCTAssertGreaterThanOrEqual(try contrastRatio(foreground, background), 7,
                                            "\(rule.rawValue) must support Increased Contrast on \(style.rawValue) paper")
                let hex = try XCTUnwrap(UInt32(rule.colorHex, radix: 16))
                let source = UIColor(red: CGFloat((hex >> 16) & 255) / 255,
                                     green: CGFloat((hex >> 8) & 255) / 255,
                                     blue: CGFloat(hex & 255) / 255, alpha: 1)
                var originalHue: CGFloat = 0, originalSaturation: CGFloat = 0
                var actualHue: CGFloat = 0, actualSaturation: CGFloat = 0
                XCTAssertTrue(source.getHue(&originalHue, saturation: &originalSaturation, brightness: nil, alpha: nil))
                XCTAssertTrue(foreground.getHue(&actualHue, saturation: &actualSaturation, brightness: nil, alpha: nil))
                if originalSaturation == 0 {
                    XCTAssertEqual(actualSaturation, 0, accuracy: 0.001, "Neutral annotation letters must remain neutral")
                } else {
                    let distance = abs(originalHue - actualHue)
                    XCTAssertLessThan(min(distance, 1 - distance), 0.001, "The source rule's hue must remain recognizable")
                }
            }
        }
    }

    private func resolvedColors(_ rule: TajweedRule, traits: UITraitCollection) -> (UIColor, UIColor) {
        var foreground = UIColor.clear
        var background = UIColor.clear
        traits.performAsCurrent {
            foreground = UIColor(Palette.tajweed(rule)).resolvedColor(with: traits)
            background = UIColor(Palette.paper).resolvedColor(with: traits)
        }
        return (foreground, background)
    }

    private func contrastRatio(_ first: UIColor, _ second: UIColor) throws -> Double {
        func luminance(_ color: UIColor) throws -> Double {
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
                XCTFail("The resolved display colour must expose RGB components")
                throw CocoaError(.coderInvalidValue)
            }
            XCTAssertEqual(alpha, 1, accuracy: 0.001)
            let components = [red, green, blue].map { component -> Double in
                let value = Double(component)
                return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return zip(components, [0.2126, 0.7152, 0.0722]).reduce(0) { $0 + $1.0 * $1.1 }
        }
        let firstLuminance = try luminance(first), secondLuminance = try luminance(second)
        return (max(firstLuminance, secondLuminance) + 0.05) / (min(firstLuminance, secondLuminance) + 0.05)
    }

    func testCanonicalEquivalentSourcesRetainTheirOwnExactUTF8() throws {
        let composed = "[g[أ]"
        let decomposed = "[g[ا\u{0654}]"
        XCTAssertEqual(composed, decomposed, "Swift strings compare canonical equivalents equally")
        XCTAssertNotEqual(Array(composed.utf8), Array(decomposed.utf8))
        let cache = ArabicTextPreparationCache()
        let first = try XCTUnwrap(cache.preparation(for: composed).plainText)
        let second = try XCTUnwrap(cache.preparation(for: decomposed).plainText)
        XCTAssertEqual(Array(first.utf8), Array("أ".utf8))
        XCTAssertEqual(Array(second.utf8), Array("ا\u{0654}".utf8))
        XCTAssertEqual(cache.entryCount, 2)
        XCTAssertEqual(Array(try XCTUnwrap(cache.preparation(for: composed).plainText).utf8), Array(first.utf8))
    }

    func testMalformedOrEmptyAnnotationsRequestCanonicalFallback() {
        let cache = ArabicTextPreparationCache()
        for source in ["", "ٱفْتَرَ[ٮٰ]هُ", "[g[ن", "[x[ن]"] {
            let prepared = cache.preparation(for: source)
            XCTAssertTrue(prepared.usesFallback, source)
            XCTAssertNil(prepared.spans, source)
            XCTAssertNil(prepared.plainText, source)
        }
    }

    func testNestedRulesPreserveWholeScalarSequenceAndInnerPrecedence() throws {
        let prepared = ArabicTextPreparationCache().preparation(for: "[o[ُوٓ[s[اْ]‌ۚ]")
        XCTAssertFalse(prepared.usesFallback)
        XCTAssertEqual(Array(try XCTUnwrap(prepared.plainText).utf8), Array("ُوٓاْ‌ۚ".utf8))
        XCTAssertEqual(prepared.spans?.map(\.rule), [.maddObligatory, .silent, .maddObligatory])
    }

    func testLongReadingSessionRetainsOnlyConfiguredNumberOfPreparations() {
        let cache = ArabicTextPreparationCache(capacity: 2)
        for number in 1...1_000 {
            let source = "نَصٌّ \(number)"
            let prepared = cache.preparation(for: source)
            XCTAssertEqual(Array(prepared.plainText?.utf8 ?? "".utf8), Array(source.utf8))
            XCTAssertLessThanOrEqual(cache.entryCount, 2)
        }
        XCTAssertEqual(cache.entryCount, 2)
    }

    func testSearchUsesKeyboardArabicWithoutChangingSourceNames() {
        let name = "سُورَةُ ٱلْفَاتِحَةِ"
        let fatiha = Surah(id: 1, name: name, englishName: "Al-Faatiha", englishNameTranslation: "The Opening", numberOfAyahs: 7, revelationType: "Meccan")
        let index = SurahSearchIndex(surahs: [fatiha])
        for query in ["الفاتحة", "ٱلفاتحة", "الفَاتِحَة", "  AL FAATIHA  ", "Fatiha", "Faatiha", "Faaatiha", "opening", "١", "۱"] {
            XCTAssertEqual(index.matching(query).map(\.id), [1], query)
        }
        XCTAssertTrue(index.matching("zzznomatch").isEmpty)
        XCTAssertTrue(index.matching("Fattiha").isEmpty, "Consonants must not be collapsed as transliterated long vowels")
        XCTAssertEqual(Array(index.surahs[0].name.utf8), Array(name.utf8))
        XCTAssertEqual(Array(index.surahs[0].englishName.utf8), Array("Al-Faatiha".utf8))
    }

    func testSearchRebuildDoesNotKeepResultsFromPreviousMetadata() {
        let fatiha = Surah(id: 1, name: "الفاتحة", englishName: "Al-Faatiha", englishNameTranslation: "The Opening", numberOfAyahs: 7, revelationType: "Meccan")
        let ikhlas = Surah(id: 112, name: "الإخلاص", englishName: "Al-Ikhlaas", englishNameTranslation: "Sincerity", numberOfAyahs: 4, revelationType: "Meccan")
        let index = SurahSearchIndex(surahs: [fatiha, ikhlas])
        XCTAssertEqual(index.matching("الاخلاص").map(\.id), [112])
        XCTAssertEqual(index.matching("١١٢").map(\.id), [112])
        for query in ["Ikhlas", "Ikhlaas", "al ikhlas"] {
            XCTAssertEqual(index.matching(query).map(\.id), [112], query)
        }
        let replaced = SurahSearchIndex(surahs: [ikhlas])
        XCTAssertTrue(replaced.matching("opening").isEmpty)
        XCTAssertEqual(replaced.matching("  ").map(\.id), [112])
    }

    func testVerseJumpAcceptsKeyboardNumeralsWithinCurrentSurah() {
        for input in ["255", "٢٥٥", "۲۵۵", "２５５", " ٢٥٥\n", "000255"] {
            XCTAssertEqual(VerseJumpInput.number(from: input, maximum: 286), 255, input)
        }
        XCTAssertEqual(VerseJumpInput.number(from: "1", maximum: 7), 1)
        XCTAssertEqual(VerseJumpInput.number(from: "٧", maximum: 7), 7)
    }

    func testVerseJumpRejectsOutOfRangeOrNonDecimalInput() {
        for input in ["", " ", "0", "٠", "287", "٢٨٧", "-1", "+1", "2:255", "2.5", "٢٫٥", "2 55", "²", "Ⅷ", "255verser", "99999999999999999999"] {
            XCTAssertNil(VerseJumpInput.number(from: input, maximum: 286), input)
        }
        XCTAssertNil(VerseJumpInput.number(from: "1", maximum: 0))
        XCTAssertNil(VerseJumpInput.number(from: "1", maximum: -1))
    }
}
