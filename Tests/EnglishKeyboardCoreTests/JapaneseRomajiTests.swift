import XCTest
@testable import EnglishKeyboardCore

final class JapaneseRomajiTests: XCTestCase {
    func testCoreRomajiMappings() {
        XCTAssertEqual(JapaneseRomaji.toKana("kyou"), "きょう")
        XCTAssertEqual(JapaneseRomaji.toKana("hashi"), "はし")
        XCTAssertEqual(JapaneseRomaji.toKana("3jini"), "3じに")
        XCTAssertEqual(JapaneseRomaji.toKana("n'a"), "んあ")
        XCTAssertEqual(JapaneseRomaji.toKana("gakkou"), "がっこう")
    }

    func testIncompleteRomajiIsReported() {
        let parse = JapaneseRomaji.parse("str")
        XCTAssertFalse(parse.isComplete)
    }
}
