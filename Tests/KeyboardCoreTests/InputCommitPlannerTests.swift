import XCTest
@testable import KeyboardCore

final class InputCommitPlannerTests: XCTestCase {
    func testFastRawAppendSequencePreservesEveryCharacter() {
        assertAppending("aaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    }

    func testMixedSentenceAppendSequencesPreserveEveryCharacter() {
        assertAppending("kyouno meeting ha 3ji")
        assertAppending("ashita no yotei wo kakunin shitai")
        assertAppending("watashi ha nihongo to english wo kirikaezu ni nyuuryoku shitai")
    }

    func testRepeatedPhraseAppendSequencesPreserveEveryCharacter() {
        assertAppending("kakikukeko kakikukeko kakikukeko")
        assertAppending("kyounomeetingha3ji kyounomeetingha3ji")
    }

    func testStaleCandidateCommitPreservesSuffixTypedAfterSnapshot() {
        let plan = InputCommitPlanner.replacement(
            buffer: "kyounomeeting",
            snapshot: "kyouno",
            preview: "今日の"
        )

        XCTAssertEqual(plan?.deleteCount, "kyounomeeting".count)
        XCTAssertEqual(plan?.preview, "今日の")
        XCTAssertEqual(plan?.suffix, "meeting")
        XCTAssertEqual(plan?.insertedText, "今日のmeeting")
        XCTAssertEqual(plan?.nextBuffer, "meeting")
    }

    func testCurrentBufferCommitHasNoSuffixAndClearsBuffer() {
        let input = "ashita no yotei wo kakunin shitai"
        let plan = InputCommitPlanner.replacement(
            buffer: input,
            snapshot: input,
            preview: "明日の予定を確認したい"
        )

        XCTAssertEqual(plan?.deleteCount, input.count)
        XCTAssertEqual(plan?.suffix, "")
        XCTAssertEqual(plan?.insertedText, "明日の予定を確認したい")
        XCTAssertEqual(plan?.nextBuffer, "")
    }

    func testSnapshotMismatchAbortsCommitToPreserveRawInput() {
        let plan = InputCommitPlanner.replacement(
            buffer: "watashiha",
            snapshot: "ashita",
            preview: "明日"
        )

        XCTAssertNil(plan)
    }

    func testGraphemeDeleteCountUsesUserVisibleCharacters() {
        let plan = InputCommitPlanner.replacement(
            buffer: "e\u{301}kana",
            snapshot: "e\u{301}kana",
            preview: "絵かな"
        )

        XCTAssertEqual(plan?.deleteCount, 5)
        XCTAssertEqual(plan?.insertedText, "絵かな")
    }

    func testFastTypingCommitSimulationNeverDropsSuffixes() {
        var host = ""
        var buffer = ""
        let input = Array("kyounomeetingha3jini")

        for (idx, character) in input.enumerated() {
            buffer.append(character)
            host.append(character)

            guard idx == 4 else { continue }
            let plan = InputCommitPlanner.replacement(
                buffer: buffer,
                snapshot: "kyoun",
                preview: "きょうん"
            )
            XCTAssertNotNil(plan)
            host.removeLast(plan?.deleteCount ?? 0)
            host.append(plan?.insertedText ?? "")
            buffer = plan?.nextBuffer ?? buffer
        }

        XCTAssertTrue(host.hasSuffix(buffer))
        XCTAssertEqual(buffer, "omeetingha3jini")
        XCTAssertEqual(host, "きょうんomeetingha3jini")
    }

    private func assertAppending(_ input: String, file: StaticString = #filePath, line: UInt = #line) {
        var buffer = ""
        var mutationCount = 0

        for character in input {
            let previous = buffer
            buffer.append(character)
            mutationCount += 1

            XCTAssertEqual(buffer, previous + String(character), file: file, line: line)
            XCTAssertEqual(buffer.count, mutationCount, file: file, line: line)
        }

        XCTAssertEqual(buffer, input, file: file, line: line)
        XCTAssertEqual(mutationCount, input.count, file: file, line: line)
    }
}
