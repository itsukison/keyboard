import XCTest
@testable import KeyboardCore

/// Regression coverage for the trigram + beam-search classifier upgrade.
/// Covers the colloquial-English failures that motivated the rewrite
/// ("wanna" → わんあ) plus a few common JA romaji and mixed-run baselines.
final class BilingualSpanDetectorTrigramTests: XCTestCase {
    private let detector = BilingualSpanDetector()

    private func kinds(of raw: String) -> [SpanKind] {
        detector.detect(raw).map(\.kind)
    }

    private func first(of raw: String) -> SpanKind? {
        detector.detect(raw).first?.kind
    }

    // MARK: - Colloquial English (the primary motivating bug)

    func testWannaIsEnglish() {
        XCTAssertEqual(first(of: "wanna"), .english)
    }

    func testGonnaIsEnglish() {
        XCTAssertEqual(first(of: "gonna"), .english)
    }

    func testKindaIsEnglish() {
        XCTAssertEqual(first(of: "kinda"), .english)
    }

    func testDunnoIsEnglish() {
        XCTAssertEqual(first(of: "dunno"), .english)
    }

    func testImmaIsEnglish() {
        XCTAssertEqual(first(of: "imma"), .english)
    }

    // MARK: - Japanese romaji baselines (must not regress)

    func testHashiIsJapanese() {
        XCTAssertEqual(first(of: "hashi"), .japanese)
    }

    func testKorekaraIsJapanese() {
        XCTAssertEqual(first(of: "korekara"), .japanese)
    }

    func testKyouIsJapanese() {
        XCTAssertEqual(first(of: "kyou"), .japanese)
    }

    func testWatashiIsJapanese() {
        XCTAssertEqual(first(of: "watashi"), .japanese)
    }

    func testOhayouIsJapanese() {
        XCTAssertEqual(first(of: "ohayou"), .japanese)
    }

    // MARK: - English baselines

    func testMeetingIsEnglish() {
        XCTAssertEqual(first(of: "meeting"), .english)
    }

    func testTheIsEnglish() {
        XCTAssertEqual(first(of: "the"), .english)
    }

    // MARK: - No-space mixed runs

    func testKyouNoMeetingHaMixedRun() {
        let spans = detector.detect("kyounomeetingha3jini")
        let kinds = spans.map(\.kind)
        // Expect at least one JA span and an EN span ("meeting").
        XCTAssertTrue(kinds.contains(.japanese))
        XCTAssertTrue(spans.contains { $0.raw.contains("meeting") && $0.kind == .english })
    }

    func testFullJapaneseRunWithEmbeddedEnglishVowelClustersStaysJapanese() {
        // "hashiwowatarumaenitaberu" — the "wo" particle plus "wataru" etc.
        // The beam used to chop "wo" + "at" out as English; switch penalty
        // and length-scaled dict bonus should keep this all-JA.
        let spans = detector.detect("hashiwowatarumaenitaberu")
        XCTAssertTrue(spans.allSatisfy { $0.kind == .japanese },
            "got spans=\(spans.map { "\($0.kind.rawValue):\($0.raw)" })")
    }

    func testBilingualClauseSegmentsEnglishWords() {
        let spans = detector.detect("korekara we can get in the car")
        let englishRaws = spans.filter { $0.kind == .english }.map(\.raw)
        XCTAssertTrue(englishRaws.contains(where: { $0.contains("we") }))
        XCTAssertTrue(englishRaws.contains(where: { $0.contains("car") }))
    }

    // MARK: - Structural rule: no within-word language mixing absent a strong EN dict word

    func testTypeIsEnglishSinglePiece() {
        // "type" is not in the embedded EN dict but is not kana-decomposable.
        // It MUST classify as a single EN span — never split into "ty"+"pe"
        // (which would yield "tyぺ"). Within a whitespace token, language must
        // be homogeneous unless a known dictionary word is embedded.
        let spans = detector.detect("type")
        XCTAssertEqual(spans.count, 1, "got spans=\(spans.map { "\($0.kind.rawValue):\($0.raw)" })")
        XCTAssertEqual(spans.first?.kind, .english)
        XCTAssertEqual(spans.first?.raw, "type")
    }

    func testCodeIsEnglishSinglePiece() {
        let spans = detector.detect("code")
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans.first?.kind, .english)
    }

    func testSingleWhitespaceTokenStaysHomogeneousUnlessDictMatch() {
        // Sanity sweep: short words must produce exactly one span each,
        // covering both classes.
        for (word, expected) in [
            ("type", SpanKind.english),
            ("kyou", .japanese),
            ("wanna", .english),
            ("hashi", .japanese),
            ("ohayou", .japanese),
            ("nice", .english),
            ("school", .english),
        ] {
            let spans = detector.detect(word)
            XCTAssertEqual(spans.count, 1, "word=\(word) got \(spans.map { "\($0.kind.rawValue):\($0.raw)" })")
            XCTAssertEqual(spans.first?.kind, expected, "word=\(word)")
        }
    }

    func testLongNoSpaceRunDefaultsJapanese() {
        // No-space runs of 8+ chars without an embedded EN dict match are
        // virtually always Japanese romaji.
        let spans = detector.detect("hashiwowatarumaenitaberu")
        XCTAssertTrue(spans.allSatisfy { $0.kind == .japanese })
    }

    // MARK: - Single-char fallthrough

    func testSingleCharILeavesPriorPathIntact() {
        // The trigram contribution is gated to length >= 3, so single-char
        // tokens still respect the existing prior-based behavior.
        let neutral = detector.detect("i").first?.kind
        XCTAssertEqual(neutral, .japanese)
        let withEnPrior = detector.detect(
            "i",
            documentPrior: LanguagePrior(jaBias: 0, enBias: 0.9)
        ).first?.kind
        XCTAssertEqual(withEnPrior, .english)
    }
}
