import Foundation

enum SuggestionKind: Equatable {
    case english
    case japanese
}

struct SuggestionItem: Identifiable, Equatable {
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
    @Published var items: [SuggestionItem] = []
    var onSelect: ((SuggestionItem) -> Void)?

    var isEmpty: Bool {
        items.isEmpty
    }

    func select(_ item: SuggestionItem) {
        onSelect?(item)
    }

    func clear() {
        items = []
    }
}
