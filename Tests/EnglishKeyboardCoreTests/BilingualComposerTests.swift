import XCTest
@testable import EnglishKeyboardCore

final class BilingualComposerTests: XCTestCase {
    func testJapaneseTokenProducesCommitReplacement() {
        let composer = BilingualComposer(converter: MockJapaneseConverter(mapping: [
            "はしをわたるまえにたべる": ["橋を渡る前に食べる"],
        ]))

        let commit = composer.commitForSpace(beforeInput: "hashiwowatarumaenitaberu")

        XCTAssertEqual(commit?.rawToken, "hashiwowatarumaenitaberu")
        XCTAssertEqual(commit?.replacementText, "橋を渡る前に食べる")
        XCTAssertEqual(commit?.deleteCount, "hashiwowatarumaenitaberu".count)
    }

    func testEnglishTokenDoesNotProduceCommitReplacement() {
        let composer = BilingualComposer(converter: MockJapaneseConverter(mapping: [:]))

        XCTAssertNil(composer.commitForSpace(beforeInput: "meeting"))
    }

    func testMixedRunPreservesEnglishSpan() {
        let composer = BilingualComposer(converter: MockJapaneseConverter(mapping: [
            "きょうの": ["今日の"],
            "は3じに": ["は3時に"],
        ]))

        let commit = composer.commitForSpace(beforeInput: "kyounomeetingha3jini")

        XCTAssertEqual(commit?.replacementText, "今日のmeetingは3時に")
        XCTAssertEqual(commit?.spans.map(\.language), [.japanese, .english, .japanese])
    }

    func testJapaneseSuggestionsExposeCandidates() {
        let composer = BilingualComposer(converter: MockJapaneseConverter(mapping: [
            "はし": ["橋", "箸", "端", "はし"],
        ]))

        let suggestions = composer.suggestions(beforeInput: "hashi")

        XCTAssertEqual(suggestions.map(\.replacementText), ["橋", "箸", "端", "はし"])
        XCTAssertEqual(suggestions.map(\.deleteCount), Array(repeating: "hashi".count, count: 4))
    }

    func testMixedSuggestionsPreviewWholeReplacement() {
        let composer = BilingualComposer(converter: MockJapaneseConverter(mapping: [
            "きょうの": ["今日の", "きょうの"],
            "は3じに": ["は3時に"],
        ]))

        let suggestions = composer.suggestions(beforeInput: "kyounomeetingha3jini")

        XCTAssertEqual(suggestions.map(\.replacementText), [
            "今日のmeetingは3時に",
            "きょうのmeetingは3時に",
        ])
    }

    func testEnglishTokenHasNoJapaneseSuggestions() {
        let composer = BilingualComposer(converter: MockJapaneseConverter(mapping: [:]))

        XCTAssertTrue(composer.suggestions(beforeInput: "meeting").isEmpty)
    }
}

private final class MockJapaneseConverter: JapaneseCandidateConverting {
    let mapping: [String: [String]]

    init(mapping: [String: [String]]) {
        self.mapping = mapping
    }

    func convert(_ input: JapaneseConversionInput) -> JapaneseConversionResult {
        JapaneseConversionResult(input: input, candidates: mapping[input.kana] ?? [input.kana])
    }
}
