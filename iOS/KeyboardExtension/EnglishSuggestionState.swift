import Foundation
import KeyboardPreferences

enum SuggestionKind: Equatable, Sendable {
    case dictionary
    case english
    case keepRaw
    case japanese
}

struct SuggestionItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let replacementText: String
    let deleteCount: Int
    let kind: SuggestionKind

    init(
        title: String,
        replacementText: String,
        deleteCount: Int,
        kind: SuggestionKind
    ) {
        self.id = "\(kind)-\(deleteCount)-\(replacementText)"
        self.title = title
        self.replacementText = replacementText
        self.deleteCount = deleteCount
        self.kind = kind
    }
}

@MainActor
final class EnglishSuggestionState: ObservableObject {
    private(set) var displayMode: CompositionDisplayMode = KeyboardSettingsStore.readCompositionDisplayMode()
    private(set) var previewTitle: String?
    private(set) var items: [SuggestionItem] = []
    var onSelect: ((SuggestionItem) -> Void)?

    var isEmpty: Bool {
        previewTitle == nil && items.isEmpty
    }

    func select(_ item: SuggestionItem) {
        onSelect?(item)
    }

    func update(
        displayMode: CompositionDisplayMode,
        previewTitle: String?,
        items: [SuggestionItem]
    ) {
        guard self.displayMode != displayMode ||
              self.previewTitle != previewTitle ||
              self.items != items else {
            return
        }
        objectWillChange.send()
        self.displayMode = displayMode
        self.previewTitle = previewTitle
        self.items = items
    }

    func clear() {
        update(displayMode: displayMode, previewTitle: nil, items: [])
    }
}
