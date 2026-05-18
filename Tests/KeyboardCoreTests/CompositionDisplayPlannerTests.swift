import XCTest
@testable import KeyboardCore

final class CompositionDisplayPlannerTests: XCTestCase {
    func testLiveReplacementUsesDisplayedLength() {
        let plan = CompositionDisplayPlanner.liveReplacement(
            buffer: "dokotde",
            snapshot: "dokotde",
            displayedComposition: "dokotde",
            displayPreview: "どこtで"
        )

        XCTAssertEqual(plan?.deleteCount, "dokotde".count)
        XCTAssertEqual(plan?.replacementText, "どこtで")
        XCTAssertEqual(plan?.nextBuffer, "dokotde")
        XCTAssertEqual(plan?.nextDisplayedComposition, "どこtで")
    }

    func testLiveReplacementPreservesRawSuffixTypedAfterSnapshot() {
        let plan = CompositionDisplayPlanner.liveReplacement(
            buffer: "kyounome",
            snapshot: "kyouno",
            displayedComposition: "きょうのm",
            displayPreview: "きょうの"
        )

        XCTAssertEqual(plan?.deleteCount, 0)
        XCTAssertEqual(plan?.replacementText, "e")
        XCTAssertEqual(plan?.suffix, "me")
        XCTAssertEqual(plan?.nextDisplayedComposition, "きょうのme")
    }

    func testLiveReplacementHandlesKanaPrefixWithRawTypingSuffix() {
        let plan = CompositionDisplayPlanner.liveReplacement(
            buffer: "kana",
            snapshot: "kana",
            displayedComposition: "かna",
            displayPreview: "かな"
        )

        XCTAssertEqual(plan?.deleteCount, 2)
        XCTAssertEqual(plan?.replacementText, "な")
        XCTAssertEqual(plan?.nextDisplayedComposition, "かな")
    }

    func testCommitReplacementDeletesDisplayedCompositionAndKeepsSuffixRaw() {
        let plan = CompositionDisplayPlanner.commitReplacement(
            buffer: "kyounome",
            snapshot: "kyouno",
            displayedComposition: "きょうのme",
            commitPreview: "今日の"
        )

        XCTAssertEqual(plan?.deleteCount, "きょうのme".count)
        XCTAssertEqual(plan?.replacementText, "今日のme")
        XCTAssertEqual(plan?.nextBuffer, "me")
        XCTAssertEqual(plan?.nextDisplayedComposition, "me")
    }

    func testSnapshotMismatchAborts() {
        let live = CompositionDisplayPlanner.liveReplacement(
            buffer: "watashi",
            snapshot: "ashita",
            displayedComposition: "わたし",
            displayPreview: "あした"
        )
        let commit = CompositionDisplayPlanner.commitReplacement(
            buffer: "watashi",
            snapshot: "ashita",
            displayedComposition: "わたし",
            commitPreview: "明日"
        )

        XCTAssertNil(live)
        XCTAssertNil(commit)
    }

    func testReplacementKeepsSharedPrefixInHost() {
        let plan = CompositionDisplayPlanner.liveReplacement(
            buffer: "abcx",
            snapshot: "abcx",
            displayedComposition: "abc",
            displayPreview: "abcx"
        )

        XCTAssertEqual(plan?.deleteCount, 0)
        XCTAssertEqual(plan?.replacementText, "x")
        XCTAssertEqual(plan?.nextDisplayedComposition, "abcx")
    }

    func testReplacementDeletesOnlyChangedTailAfterSharedPrefix() {
        let plan = CompositionDisplayPlanner.commitReplacement(
            buffer: "abcdef",
            snapshot: "abcdef",
            displayedComposition: "abcdef",
            commitPreview: "abcXYZ"
        )

        XCTAssertEqual(plan?.deleteCount, 3)
        XCTAssertEqual(plan?.replacementText, "XYZ")
        XCTAssertEqual(plan?.nextDisplayedComposition, "")
    }
}
