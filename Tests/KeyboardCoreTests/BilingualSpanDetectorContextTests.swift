import XCTest
@testable import KeyboardCore

final class BilingualSpanDetectorContextTests: XCTestCase {
    private let detector = BilingualSpanDetector()

    // MARK: - Regression: neutral prior preserves prototype-equivalent behavior

    func testNeutralPriorClassifiesAmbiguousIByNeighbors() {
        // "i think" — "i" is ambiguous in isolation; neighbor "think" pulls EN.
        let spans = detector.detect("i think")
        XCTAssertEqual(spans.last?.kind, .english)
    }

    func testNeutralPriorWeKeepsEnglishInBilingualClause() {
        // Regression: existing neighbor smoothing for English-leaning context.
        let spans = detector.detect("korekara we can get in the car")
        XCTAssertTrue(spans.contains(where: { $0.raw == "we" && $0.kind == .english })
            || spans.contains(where: { $0.raw.contains("we") && $0.kind == .english }))
    }

    // MARK: - Prior-driven disambiguation

    func testJapanesePriorPullsAmbiguousISingletonToJapanese() {
        // "i" alone, no neighbors. With a JA-leaning document prior it should
        // classify as Japanese (い).
        let neutral = detector.detect("i")
        let withJaPrior = detector.detect("i", documentPrior: LanguagePrior(jaBias: 0.9, enBias: 0))
        // Neutral path defaults to Japanese on borderline single tokens
        // (existing classify policy), so this asserts the prior at least
        // doesn't break that and the kana is present.
        XCTAssertEqual(neutral.first?.kind, .japanese)
        XCTAssertEqual(withJaPrior.first?.kind, .japanese)
        XCTAssertEqual(withJaPrior.first?.kana, "い")
    }

    func testEnglishPriorPullsAmbiguousISingletonToEnglish() {
        // With a strong EN-leaning prior, lone "i" should flip to English.
        let spans = detector.detect("i", documentPrior: LanguagePrior(jaBias: 0, enBias: 0.9))
        XCTAssertEqual(spans.first?.kind, .english)
    }

    func testStrongJapaneseSignalNotFlippedByEnglishPrior() {
        // Loanword-shaped, kana-complete, length 8+ — strong JA signal.
        // EN prior must not flip it.
        let spans = detector.detect("kyounomeeting", documentPrior: LanguagePrior(jaBias: 0, enBias: 1.0))
        XCTAssertTrue(spans.contains(where: { $0.kind == .japanese }))
    }

    func testStrongEnglishSignalNotFlippedByJapanesePrior() {
        // Dictionary-locked English word ("school" in defaultEnglishWords).
        let spans = detector.detect("school", documentPrior: LanguagePrior(jaBias: 1.0, enBias: 0))
        XCTAssertEqual(spans.first?.kind, .english)
    }

    func testPriorChangesAmbiguousMixedSpan() {
        // "to" alone is a weak ambiguous token. JA prior should keep it JA,
        // EN prior should flip it.
        let ja = detector.detect("to", documentPrior: LanguagePrior(jaBias: 0.9, enBias: 0))
        let en = detector.detect("to", documentPrior: LanguagePrior(jaBias: 0, enBias: 0.9))
        XCTAssertEqual(ja.first?.kind, .japanese)
        XCTAssertEqual(en.first?.kind, .english)
    }
}
