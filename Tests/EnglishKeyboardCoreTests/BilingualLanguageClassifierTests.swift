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
}
