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

    func testJapaneseSuggestionsUseLearnedPreferenceOrder() {
        let composer = BilingualComposer(
            converter: MockJapaneseConverter(mapping: [
                "はし": ["橋", "端", "箸"],
            ]),
            conversionPreferenceEntries: {
                [
                    ConversionPreferenceEntry(
                        scope: .japanese,
                        inputKey: "hashi",
                        candidateKey: "箸",
                        displayText: "箸",
                        acceptedCount: 2,
                        lastUsedAt: Date(timeIntervalSince1970: 10),
                        updatedAt: Date(timeIntervalSince1970: 10)
                    ),
                ]
            }
        )

        let suggestions = composer.suggestions(beforeInput: "hashi")
        let commit = composer.commitForSpace(beforeInput: "hashi")

        XCTAssertEqual(suggestions.map(\.replacementText), ["箸", "橋", "端"])
        XCTAssertEqual(commit?.replacementText, "箸")
    }

    func testRepeatedKeepRawSuppressesJapaneseSuggestionsAndCommit() {
        let composer = BilingualComposer(
            converter: MockJapaneseConverter(mapping: [
                "はし": ["橋", "端", "箸"],
            ]),
            conversionPreferenceEntries: {
                [
                    ConversionPreferenceEntry(
                        scope: .japanese,
                        inputKey: "hashi",
                        candidateKey: "hashi",
                        displayText: "hashi",
                        acceptedCount: 2,
                        lastUsedAt: Date(timeIntervalSince1970: 10),
                        updatedAt: Date(timeIntervalSince1970: 10)
                    ),
                ]
            }
        )

        XCTAssertTrue(composer.suggestions(beforeInput: "hashi").isEmpty)
        XCTAssertNil(composer.commitForSpace(beforeInput: "hashi"))
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

    func testMixedSuggestionsUseLearnedWholeReplacementOrder() {
        let composer = BilingualComposer(
            converter: MockJapaneseConverter(mapping: [
                "きょうの": ["今日の", "きょうの"],
                "は3じに": ["は3時に"],
            ]),
            conversionPreferenceEntries: {
                [
                    ConversionPreferenceEntry(
                        scope: .japanese,
                        inputKey: "kyounomeetingha3jini",
                        candidateKey: "きょうのmeetingは3時に",
                        displayText: "きょうのmeetingは3時に",
                        acceptedCount: 2,
                        lastUsedAt: Date(timeIntervalSince1970: 10),
                        updatedAt: Date(timeIntervalSince1970: 10)
                    ),
                ]
            }
        )

        let suggestions = composer.suggestions(beforeInput: "kyounomeetingha3jini")
        let commit = composer.commitForSpace(beforeInput: "kyounomeetingha3jini")

        XCTAssertEqual(suggestions.map(\.replacementText), [
            "きょうのmeetingは3時に",
            "今日のmeetingは3時に",
        ])
        XCTAssertEqual(commit?.replacementText, "きょうのmeetingは3時に")
    }

    func testLongJapaneseTakedoRunConvertsAsOneSpan() {
        let composer = BilingualComposer(converter: MockJapaneseConverter(mapping: [
            "けっこういいとおもったけど": ["結構いいと思ったけど"],
        ]))

        let suggestions = composer.suggestions(beforeInput: "kekkouiitoomottakedo")
        let commit = composer.commitForSpace(beforeInput: "kekkouiitoomottakedo")

        XCTAssertEqual(suggestions.map(\.replacementText), ["結構いいと思ったけど"])
        XCTAssertEqual(commit?.replacementText, "結構いいと思ったけど")
        XCTAssertEqual(commit?.spans.map(\.language), [.japanese])
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

    func testSearchUrlConvertibleTokensCanBeIdentifiedWithoutEnglishTypos() {
        XCTAssertTrue(BilingualComposer.containsJapaneseSpan(beforeInput: "kyou"))
        XCTAssertTrue(BilingualComposer.containsJapaneseSpan(beforeInput: "watashiha"))
        XCTAssertFalse(BilingualComposer.containsJapaneseSpan(beforeInput: "example.com"))
    }

    func testJapaneseEndingReplacementSuppressesSpaceAppend() {
        XCTAssertTrue(BilingualComposer.endsWithJapaneseText("橋を渡る前に食べる"))
        XCTAssertTrue(BilingualComposer.endsWithJapaneseText("今日のmeetingは3時に"))
        XCTAssertTrue(BilingualComposer.endsWithJapaneseText("ミーティング"))
        XCTAssertTrue(BilingualComposer.endsWithJapaneseText("今日は。"))
    }

    func testEnglishEndingReplacementKeepsSpaceAppend() {
        XCTAssertFalse(BilingualComposer.endsWithJapaneseText("meeting"))
        XCTAssertFalse(BilingualComposer.endsWithJapaneseText("今日のmeeting"))
        XCTAssertFalse(BilingualComposer.endsWithJapaneseText("aware"))
        XCTAssertFalse(BilingualComposer.endsWithJapaneseText("meeting。"))
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
