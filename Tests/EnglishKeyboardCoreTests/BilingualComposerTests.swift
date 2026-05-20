import XCTest
import KeyboardPreferences
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
        XCTAssertEqual(suggestions.map(\.kind), [.japanese, .japanese, .japanese, .japanese])
        XCTAssertEqual(suggestions.map(\.deleteCount), Array(repeating: "hashi".count, count: 4))
    }

    func testSuggestionSetSharesSingleConversionForKeepRawAndCandidates() {
        let converter = MockJapaneseConverter(mapping: [
            "はし": ["橋", "箸"],
        ])
        let composer = BilingualComposer(converter: converter)

        let set = composer.suggestionSet(beforeInput: "hashi")

        XCTAssertEqual(set.keepRaw?.replacementText, "hashi")
        XCTAssertEqual(set.japanese.map(\.replacementText), ["橋", "箸"])
        XCTAssertEqual(converter.convertCallCount, 1)
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

    func testKeepRawSuggestionIsOfferedSeparatelyForConvertibleEnglishLookingWord() {
        let classifier = BilingualLanguageClassifier(englishWords: [])
        let composer = BilingualComposer(
            classifier: classifier,
            converter: MockJapaneseConverter(mapping: [
                "ぃけ": ["ぃけ", "ィケ"],
            ])
        )

        let suggestions = composer.suggestions(beforeInput: "like")
        let keepRaw = composer.keepRawSuggestion(beforeInput: "like")

        XCTAssertEqual(suggestions.map(\.replacementText), ["ぃけ", "ィケ"])
        XCTAssertEqual(keepRaw?.replacementText, "like")
        XCTAssertEqual(keepRaw?.kind, .keepRaw)
    }

    func testEnglishTokenHasNoJapaneseSuggestions() {
        let composer = BilingualComposer(converter: MockJapaneseConverter(mapping: [:]))

        XCTAssertTrue(composer.suggestions(beforeInput: "meeting").isEmpty)
    }

    func testEnglishHeavyDisplayModeDoesNotProduceToolbarPreview() {
        let composer = BilingualComposer(converter: MockJapaneseConverter(mapping: [:]))

        XCTAssertNil(composer.displayPreview(beforeInput: "korekara", displayMode: .balancedRaw))
    }

    func testJapaneseHeavyPreviewPreservesEmbeddedEnglish() {
        let composer = BilingualComposer(converter: MockJapaneseConverter(mapping: [:]))

        XCTAssertEqual(
            composer.displayPreview(beforeInput: "kyounomeetingha3jini", displayMode: .japaneseHeavyKana),
            "きょうのmeetingは3じに"
        )
    }
}

private final class MockJapaneseConverter: JapaneseCandidateConverting {
    let mapping: [String: [String]]
    private(set) var convertCallCount = 0

    init(mapping: [String: [String]]) {
        self.mapping = mapping
    }

    func convert(_ input: JapaneseConversionInput) -> JapaneseConversionResult {
        convertCallCount += 1
        return JapaneseConversionResult(input: input, candidates: mapping[input.kana] ?? [input.kana])
    }
}
