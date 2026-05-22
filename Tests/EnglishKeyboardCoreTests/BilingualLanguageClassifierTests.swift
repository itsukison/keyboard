import XCTest
@testable import EnglishKeyboardCore

final class BilingualLanguageClassifierTests: XCTestCase {
    private let classifier = BilingualLanguageClassifier()

    func testJapaneseLongRomajiIsJapanese() {
        XCTAssertEqual(classifier.likelyLanguage(of: "hashiwowatarumaenitaberu"), .japanese)
    }

    func testKnownEnglishWordsStayEnglish() {
        XCTAssertEqual(classifier.likelyLanguage(of: "meeting"), .english)
        XCTAssertEqual(classifier.likelyLanguage(of: "language"), .english)
        XCTAssertEqual(classifier.likelyLanguage(of: "type"), .english)
        XCTAssertEqual(classifier.likelyLanguage(of: "like"), .english)
        XCTAssertEqual(classifier.likelyLanguage(of: "arrive"), .english)
    }

    func testColloquialEnglishStaysEnglish() {
        XCTAssertEqual(classifier.likelyLanguage(of: "wanna"), .english)
        XCTAssertEqual(classifier.likelyLanguage(of: "gonna"), .english)
    }

    func testNoSpaceMixedRunSplitsKnownEnglishWord() {
        let spans = classifier.spans(in: "kyounomeetingha3jini")
        XCTAssertEqual(spans.map(\.raw), ["kyouno", "meeting", "ha3jini"])
        XCTAssertEqual(spans.map(\.language), [.japanese, .english, .japanese])
        XCTAssertEqual(spans[0].kana, "きょうの")
        XCTAssertEqual(spans[2].kana, "は3じに")
    }

    func testShortEnglishWordsAreProtectedWithoutJapaneseContext() {
        XCTAssertEqual(classifier.likelyLanguage(of: "we"), .english)
        XCTAssertEqual(classifier.likelyLanguage(of: "to"), .english)
        XCTAssertEqual(classifier.likelyLanguage(of: "no"), .english)
    }

    func testJapaneseContextCanPullAmbiguousParticle() {
        XCTAssertEqual(classifier.likelyLanguage(of: "no", contextBefore: "今日"), .japanese)
    }

    func testSpaceAfterJapaneseScriptStartsEnglishIsland() {
        XCTAssertEqual(classifier.likelyLanguage(of: "go", contextBefore: "一緒に "), .english)
        XCTAssertEqual(classifier.likelyLanguage(of: "to", contextBefore: "一緒に go "), .english)
        XCTAssertEqual(classifier.likelyLanguage(of: "no", contextBefore: "今日は "), .english)
    }

    func testRawRomajiContextCanProtectStandaloneEnglish() {
        let spans = classifier.spans(in: "we", contextBefore: "korekara ")

        XCTAssertEqual(spans.map(\.raw), ["we"])
        XCTAssertEqual(spans.map(\.language), [.english])
    }

    func testRawRomajiJapaneseContextCanPullParticle() {
        let spans = classifier.spans(in: "no", contextBefore: "watashi ")

        XCTAssertEqual(spans.map(\.raw), ["no"])
        XCTAssertEqual(spans.map(\.language), [.japanese])
        XCTAssertEqual(spans.first?.kana, "の")
    }

    func testRawEnglishContextKeepsParticleEnglish() {
        let spans = classifier.spans(in: "no", contextBefore: "I have ")

        XCTAssertEqual(spans.map(\.raw), ["no"])
        XCTAssertEqual(spans.map(\.language), [.english])
    }

    func testContextWindowReturnsOnlyActiveMixedRunSpans() {
        let spans = classifier.spans(in: "kyounomeetingha3jini", contextBefore: "ashita ")

        XCTAssertEqual(spans.map(\.raw), ["kyouno", "meeting", "ha3jini"])
        XCTAssertEqual(spans.map(\.language), [.japanese, .english, .japanese])
        XCTAssertEqual(spans.first?.kana, "きょうの")
    }

    func testConvertedJapaneseContextWithSpaceProtectsEnglishIntent() {
        let spans = classifier.spans(in: "no", contextBefore: "今日は ")

        XCTAssertEqual(spans.map(\.raw), ["no"])
        XCTAssertEqual(spans.map(\.language), [.english])
        XCTAssertNil(spans.first?.kana)
    }

    func testJapaneseHeavyClassifierAvoidsShortEmbeddedEnglishFalseSplit() {
        let classifier = BilingualLanguageClassifier(embeddedEnglishMinimumWordLength: 5)
        let spans = classifier.spans(in: "gohandoko")

        XCTAssertEqual(spans.map(\.raw), ["gohandoko"])
        XCTAssertEqual(spans.map(\.language), [.japanese])
    }
}
