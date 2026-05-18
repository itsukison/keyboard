import KeyboardKit
import SwiftUI

struct EnglishKeyboardView: View {
    let services: Keyboard.Services
    @ObservedObject var suggestions: EnglishSuggestionState

    var body: some View {
        KeyboardView(
            layout: nil,
            services: services,
            buttonContent: { $0.view },
            buttonView: { $0.view },
            collapsedView: { $0.view },
            emojiKeyboard: { $0.view },
            toolbar: { _ in
                EnglishSuggestionToolbar(suggestions: suggestions)
            }
        )
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
