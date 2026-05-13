import XCTest
@testable import KeyboardCore

final class ExpectedEditTrackerTests: XCTestCase {
    func testConsumesSingleExpectedEdit() {
        var tracker = ExpectedEditTracker()
        let before = ObservedTextState(left: "kyo", center: "", right: "")
        let after = ObservedTextState(left: "kyou", center: "", right: "")

        tracker.record(before: before, after: after)

        XCTAssertEqual(tracker.consume(before: before, after: after), .matched(hasMoreEdits: false))
        XCTAssertEqual(tracker.consume(before: before, after: after), .noMatch)
    }

    func testConsumesChainedExpectedEditsAsOneObservedChange() {
        var tracker = ExpectedEditTracker()
        let start = ObservedTextState(left: "kyou", center: "", right: "")
        let deleted = ObservedTextState(left: "", center: "", right: "")
        let inserted = ObservedTextState(left: "今日", center: "", right: "")

        tracker.record(before: start, after: deleted)
        tracker.record(before: deleted, after: inserted)

        XCTAssertEqual(tracker.consume(before: start, after: inserted), .matched(hasMoreEdits: false))
    }

    func testReportsMoreEditsWhenChainContinuesFromObservedAfterState() {
        var tracker = ExpectedEditTracker()
        let start = ObservedTextState(left: "", center: "", right: "")
        let first = ObservedTextState(left: "a", center: "", right: "")
        let second = ObservedTextState(left: "ab", center: "", right: "")

        tracker.record(before: start, after: first)
        tracker.record(before: first, after: second)

        XCTAssertEqual(tracker.consume(before: start, after: first), .matched(hasMoreEdits: true))
        XCTAssertEqual(tracker.consume(before: first, after: second), .matched(hasMoreEdits: false))
    }

    func testDoesNotConsumeUnexpectedHostChange() {
        var tracker = ExpectedEditTracker()
        let before = ObservedTextState(left: "abc", center: "", right: "")
        let expected = ObservedTextState(left: "abcd", center: "", right: "")
        let hostChange = ObservedTextState(left: "ab", center: "", right: "c")

        tracker.record(before: before, after: expected)

        XCTAssertEqual(tracker.consume(before: before, after: hostChange), .noMatch)
    }

    func testConsumesLogicalRawInsert() {
        var tracker = ExpectedEditTracker()
        let before = ObservedTextState(left: "kyo", center: "", right: "")
        let after = ObservedTextState(left: "kyou", center: "", right: "")

        tracker.record(.insert("u"))

        XCTAssertEqual(tracker.consume(before: before, after: after), .matched(hasMoreEdits: false))
    }

    func testConsumesRepeatedFastLogicalInserts() {
        var tracker = ExpectedEditTracker(maxStoredEdits: 128)
        let before = ObservedTextState(left: "", center: "", right: "")
        let input = String(repeating: "a", count: 100)
        let after = ObservedTextState(left: input, center: "", right: "")

        for ch in input {
            tracker.record(.insert(String(ch)))
        }

        XCTAssertEqual(tracker.consume(before: before, after: after), .matched(hasMoreEdits: false))
    }

    func testLogicalEditsMustBeConsumedInOrder() {
        var tracker = ExpectedEditTracker()
        let before = ObservedTextState(left: "", center: "", right: "")
        let skippedFirstEdit = ObservedTextState(left: "b", center: "", right: "")

        tracker.record(.insert("a"))
        tracker.record(.insert("b"))

        XCTAssertEqual(tracker.consume(before: before, after: skippedFirstEdit), .noMatch)
    }

    func testConsumesLogicalBackspaceDuringComposition() {
        var tracker = ExpectedEditTracker()
        let before = ObservedTextState(left: "kyou", center: "", right: "")
        let after = ObservedTextState(left: "kyo", center: "", right: "")

        tracker.record(.deleteBackward)

        XCTAssertEqual(tracker.consume(before: before, after: after), .matched(hasMoreEdits: false))
    }

    func testConsumesLogicalCommitDeleteDeleteInsertChain() {
        var tracker = ExpectedEditTracker()
        let before = ObservedTextState(left: "kyou", center: "", right: "")
        let after = ObservedTextState(left: "今日", center: "", right: "")

        tracker.record([
            .deleteBackward,
            .deleteBackward,
            .deleteBackward,
            .deleteBackward,
            .insert("今日"),
        ])

        XCTAssertEqual(tracker.consume(before: before, after: after), .matched(hasMoreEdits: false))
    }
}
