import EnglishKeyboardCore
import KeyboardPreferences

struct JapaneseSuggestionComputation: Sendable {
    let context: String
    let displayMode: CompositionDisplayMode
    let items: [SuggestionItem]
    let keepRawSuggestion: BilingualSuggestion?
}

actor JapaneseSuggestionWorker {
    private let composer = BilingualComposer(converter: AzooKeyJapaneseConverter())

    func suggestions(
        beforeInput context: String,
        displayMode: CompositionDisplayMode
    ) -> JapaneseSuggestionComputation {
        let set = composer.suggestionSet(beforeInput: context)
        var items = set.japanese.map {
            SuggestionItem(
                title: $0.replacementText,
                replacementText: $0.replacementText,
                deleteCount: $0.deleteCount,
                kind: $0.kind == .dictionary ? .dictionary : .japanese
            )
        }
        if displayMode.isJapaneseHeavy,
           let keepRaw = set.keepRaw,
           !items.isEmpty {
            items.insert(SuggestionItem(
                title: keepRaw.replacementText,
                replacementText: keepRaw.replacementText,
                deleteCount: keepRaw.deleteCount,
                kind: .keepRaw
            ), at: 0)
        }
        return JapaneseSuggestionComputation(
            context: context,
            displayMode: displayMode,
            items: items,
            keepRawSuggestion: set.keepRaw
        )
    }
}
