import XCTest
@testable import EnglishKeyboardCore

final class AutoPunctuationResolverTests: XCTestCase {
    func testEnglishWordUsesEnglishPunctuation() {
        XCTAssertEqual(AutoPunctuationResolver.punctuationSet(beforeInput: "meeting"), .english)
    }

    func testJapaneseTextUsesJapanesePunctuation() {
        XCTAssertEqual(AutoPunctuationResolver.punctuationSet(beforeInput: "今日は"), .japanese)
    }

    func testJapaneseRomajiUsesJapanesePunctuation() {
        XCTAssertEqual(AutoPunctuationResolver.punctuationSet(beforeInput: "kyouha"), .japanese)
    }

    func testMixedTextEndingInEnglishUsesEnglishPunctuation() {
        XCTAssertEqual(AutoPunctuationResolver.punctuationSet(beforeInput: "今日のmeeting"), .english)
    }

    func testMixedRomajiEndingInJapaneseUsesJapanesePunctuation() {
        XCTAssertEqual(AutoPunctuationResolver.punctuationSet(beforeInput: "kyounomeetingha3jini"), .japanese)
    }

    func testEnglishAfterJapaneseSpaceUsesEnglishPunctuation() {
        XCTAssertEqual(AutoPunctuationResolver.punctuationSet(beforeInput: "一緒に go"), .english)
    }
}
