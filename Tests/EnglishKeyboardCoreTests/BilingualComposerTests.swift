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

    func testKanaCompleteEnglishTokenDoesNotProduceCommitReplacement() {
        let composer = BilingualComposer(converter: MockJapaneseConverter(mapping: [
            "あっりゔぇ": ["アッリヴェ"],
        ]))

        XCTAssertNil(composer.commitForSpace(beforeInput: "arrive"))
    }

    func testSpaceAfterJapaneseScriptDoesNotConvertEnglishToken() {
        let composer = BilingualComposer(converter: MockJapaneseConverter(mapping: [
            "ご": ["ご"],
        ]))

        XCTAssertNil(composer.commitForSpace(beforeInput: "一緒に go"))
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

    func testKeepRawSuggestionIsOfferedSeparatelyForConvertibleJapaneseWord() {
        let classifier = BilingualLanguageClassifier(englishWords: [])
        let composer = BilingualComposer(
            classifier: classifier,
            converter: MockJapaneseConverter(mapping: [
                "はし": ["橋", "箸"],
            ])
        )

        let suggestions = composer.suggestions(beforeInput: "hashi")
        let keepRaw = composer.keepRawSuggestion(beforeInput: "hashi")

        XCTAssertEqual(suggestions.map(\.replacementText), ["橋", "箸"])
        XCTAssertEqual(keepRaw?.replacementText, "hashi")
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

    func testContextWindowCommitDeletesOnlyActiveToken() {
        let composer = BilingualComposer(converter: MockJapaneseConverter(mapping: [
            "の": ["の"],
        ]))

        let commit = composer.commitForSpace(beforeInput: "watashi no")

        XCTAssertEqual(commit?.rawToken, "no")
        XCTAssertEqual(commit?.replacementText, "の")
        XCTAssertEqual(commit?.deleteCount, "no".count)
        XCTAssertEqual(commit?.spans.map(\.raw), ["no"])
    }

    func testJapaneseHeavyPreviewWithContextRendersOnlyActiveToken() {
        let composer = BilingualComposer(converter: MockJapaneseConverter(mapping: [:]))

        let preview = composer.displayPreview(beforeInput: "watashi no", displayMode: .japaneseHeavyKana)

        XCTAssertEqual(preview, "の")
    }

    func testJapaneseHeavyPreviewDoesNotConvertEnglishAfterJapaneseSpace() {
        let composer = BilingualComposer(converter: MockJapaneseConverter(mapping: [:]))

        let preview = composer.displayPreview(beforeInput: "一緒に go", displayMode: .japaneseHeavyKana)

        XCTAssertNil(preview)
    }

    func testDictionaryRawReplacementSuppressesJapaneseCommit() {
        let composer = BilingualComposer(
            converter: MockJapaneseConverter(mapping: [
                "あわれ": ["哀れ"],
            ]),
            dictionaryEntries: {
                [Self.dictionaryEntry(source: "aware", replacement: "aware")]
            }
        )

        let commit = composer.commitForSpace(beforeInput: "aware")

        XCTAssertEqual(commit?.kind, .dictionary)
        XCTAssertEqual(commit?.replacementText, "aware")
        XCTAssertEqual(commit?.deleteCount, "aware".count)
    }

    func testDictionaryReplacementIsFirstSuggestion() {
        let composer = BilingualComposer(
            converter: MockJapaneseConverter(mapping: [
                "あわれ": ["哀れ", "憐れ", "あわれ"],
            ]),
            dictionaryEntries: {
                [Self.dictionaryEntry(source: "aware", replacement: "aware")]
            }
        )

        let suggestions = composer.suggestions(beforeInput: "aware")

        XCTAssertEqual(suggestions.map(\.replacementText), ["aware", "哀れ", "憐れ", "あわれ"])
        XCTAssertEqual(suggestions.first?.kind, .dictionary)
    }

    func testDictionaryJapaneseReplacementCanOverrideEnglishClassification() {
        let composer = BilingualComposer(
            converter: MockJapaneseConverter(mapping: [:]),
            dictionaryEntries: {
                [Self.dictionaryEntry(source: "meeting", replacement: "ミーティング")]
            }
        )

        let suggestions = composer.suggestions(beforeInput: "meeting")
        let commit = composer.commitForSpace(beforeInput: "meeting")

        XCTAssertEqual(suggestions.map(\.replacementText), ["ミーティング"])
        XCTAssertEqual(commit?.replacementText, "ミーティング")
        XCTAssertEqual(commit?.kind, .dictionary)
    }

    func testDictionarySuggestionDedupesNormalCandidates() {
        let composer = BilingualComposer(
            converter: MockJapaneseConverter(mapping: [
                "あわれ": ["哀れ", "憐れ"],
            ]),
            dictionaryEntries: {
                [Self.dictionaryEntry(source: "aware", replacement: "哀れ")]
            }
        )

        let suggestions = composer.suggestions(beforeInput: "aware")

        XCTAssertEqual(suggestions.map(\.replacementText), ["哀れ", "憐れ"])
        XCTAssertEqual(suggestions.map(\.kind), [.dictionary, .japanese])
    }

    private static func dictionaryEntry(source: String, replacement: String) -> UserDictionaryEntry {
        UserDictionaryEntry(
            id: UUID(),
            userId: UUID(),
            sourceText: source,
            replacementText: replacement,
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 2)
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
