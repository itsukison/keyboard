import EnglishKeyboardCore
import KeyboardKit
import SwiftUI

struct EnglishKeyboardView: View {
    let services: Keyboard.Services
    @ObservedObject var keyboardContext: KeyboardContext
    @ObservedObject var suggestions: EnglishSuggestionState

    var body: some View {
        KeyboardView(
            layout: keyboardLayout,
            services: services,
            buttonContent: { params in
                if params.item.action == .nextKeyboard {
                    Image(systemName: "globe")
                        .font(.system(size: 22, weight: .regular))
                } else {
                    params.view
                }
            },
            buttonView: { $0.view },
            collapsedView: { $0.view },
            emojiKeyboard: { $0.view },
            toolbar: { _ in
                EnglishSuggestionToolbar(suggestions: suggestions)
            }
        )
    }

    private var keyboardLayout: KeyboardLayout {
        var layout = KeyboardLayout.standard(for: keyboardContext)

        guard keyboardContext.keyboardType.isAlphabetic else {
            if keyboardContext.keyboardType.isNumericOrSymbolic {
                layout.applyAutoPunctuation(suggestions.punctuationSet)
            }
            return layout
        }

        layout.insertInputModeSwitchKeyBeforeSpace()

        guard suggestions.keyboardStyle.showsLongVowelKey else {
            return layout
        }

        layout.insert(.character("ー"), withWidth: .input, after: .character("l"))
        layout.insert(.character("ー"), withWidth: .input, after: .character("L"))
        return layout
    }
}

private extension KeyboardLayout {
    mutating func insertInputModeSwitchKeyBeforeSpace() {
        remove(.nextKeyboard)
        tryInsertBottomRowAction(.nextKeyboard, before: .space)
    }

    mutating func applyAutoPunctuation(_ punctuation: AutoPunctuationSet) {
        replacePunctuationKey(english: ",", japanese: "、", replacement: punctuation.comma)
        replacePunctuationKey(english: ".", japanese: "。", replacement: punctuation.period)
        replacePunctuationKey(english: "?", japanese: "？", replacement: punctuation.questionMark)
        replacePunctuationKey(english: "!", japanese: "！", replacement: punctuation.exclamationMark)
    }

    mutating func replacePunctuationKey(english: String, japanese: String, replacement: String) {
        for current in [english, japanese] where current != replacement {
            let action = KeyboardAction.character(current)
            for rowIndex in itemRows.indices {
                for itemIndex in itemRows[rowIndex].indices where itemRows[rowIndex][itemIndex].action == action {
                    itemRows[rowIndex][itemIndex].action = .character(replacement)
                }
            }
        }
    }
}

private struct EnglishSuggestionToolbar: View {
    @ObservedObject var suggestions: EnglishSuggestionState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                if suggestions.isEmpty {
                    Text(" ")
                        .frame(height: 42)
                } else {
                    if let preview = suggestions.previewTitle {
                        Text(preview)
                            .font(.body)
                            .lineLimit(1)
                            .padding(.horizontal, 16)
                            .frame(height: 42)
                            .foregroundStyle(.primary)

                        if !suggestions.items.isEmpty {
                            Divider()
                                .frame(height: 22)
                        }
                    }

                    ForEach(suggestions.items) { item in
                        Button {
                            suggestions.select(item)
                        } label: {
                            Text(item.title)
                                .font(.body)
                                .lineLimit(1)
                                .padding(.horizontal, 16)
                                .frame(height: 42)
                        }
                        .buttonStyle(.plain)

                        Divider()
                            .frame(height: 22)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 42)
        .background(.thinMaterial)
    }
}
