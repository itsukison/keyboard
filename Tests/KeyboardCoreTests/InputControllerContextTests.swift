import XCTest
@testable import KeyboardCore

final class InputControllerContextTests: XCTestCase {
    /// `recentCommittedTail` retains both JA and EN, in commit order, capped.
    func testRecentCommittedTailRetainsJapaneseAndEnglish() {
        let controller = InputController(
            adapter: KanaKanjiAdapter(zenzaiWeightURL: nil),
            useZenzai: false
        )
        controller.commit(japanese: "今日は")
        controller.commitEnglish(" meeting")
        controller.commit(japanese: "に出る")

        XCTAssertEqual(controller.recentCommittedTail, "今日は meetingに出る")
        // `leftSideContext` is JA-only — English must NOT appear.
        XCTAssertEqual(controller.leftSideContext, "今日はに出る")
    }

    func testRecentCommittedTailCapsAtLimit() {
        let controller = InputController(
            adapter: KanaKanjiAdapter(zenzaiWeightURL: nil),
            useZenzai: false
        )
        let longPiece = String(repeating: "a", count: 300)
        controller.commitEnglish(longPiece)
        XCTAssertEqual(controller.recentCommittedTail.count, 200)
        XCTAssertTrue(controller.recentCommittedTail.allSatisfy { $0 == "a" })
    }

    func testResetClearsBothContexts() {
        let controller = InputController(
            adapter: KanaKanjiAdapter(zenzaiWeightURL: nil),
            useZenzai: false
        )
        controller.commit(japanese: "あ")
        controller.commitEnglish("hello")
        controller.reset()
        XCTAssertEqual(controller.leftSideContext, "")
        XCTAssertEqual(controller.recentCommittedTail, "")
    }
}
