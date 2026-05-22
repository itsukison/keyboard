import KeyboardPreferences
import SwiftUI
import UIKit

private enum DictionarySearchField: Hashable {
    case query
}

private enum PhraseSort: String, CaseIterable, Hashable {
    case all
    case recent
    case alpha

    var title: String {
        switch self {
        case .all: return "All"
        case .recent: return "Recent"
        case .alpha: return "A–Z"
        }
    }
}

struct DictionaryScreen: View {
    @EnvironmentObject private var session: UserSession
    @State private var entries = UserDictionaryStore.readEntries()
    @State private var query = ""
    @State private var sort: PhraseSort = .all
    @State private var isSearchExpanded = false
    @State private var editorPayload: DictionaryEditorPayload?
    @State private var pendingDelete: UserDictionaryEntry?
    @State private var isSyncing = false
    @State private var errorMessage: String?
    @FocusState private var searchFocused: DictionarySearchField?

    private var filteredEntries: [UserDictionaryEntry] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let base: [UserDictionaryEntry]
        switch sort {
        case .all, .alpha:
            base = entries.sorted { lhs, rhs in
                lhs.sourceText.localizedCaseInsensitiveCompare(rhs.sourceText) == .orderedAscending
            }
        case .recent:
            base = entries.sorted { lhs, rhs in
                lhs.updatedAt > rhs.updatedAt
            }
        }
        guard !trimmedQuery.isEmpty else { return base }
        return base.filter {
            $0.sourceText.localizedCaseInsensitiveContains(trimmedQuery)
                || $0.replacementText.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                AppColor.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    PhrasesHeader(
                        title: "Phrases",
                        isSearchExpanded: isSearchExpanded,
                        toggleSearch: toggleSearch
                    )
                    .padding(.horizontal, BikeyMetrics.Sizing.screenHorizontalInset)
                    .padding(.top, BikeyMetrics.Spacing.s)

                    if isSearchExpanded {
                        PhrasesSearchBar(text: $query, focused: $searchFocused)
                            .padding(.horizontal, BikeyMetrics.Sizing.screenHorizontalInset)
                            .padding(.top, BikeyMetrics.Spacing.m)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    PhrasesSortPills(selection: $sort)
                        .padding(.horizontal, BikeyMetrics.Sizing.screenHorizontalInset)
                        .padding(.top, BikeyMetrics.Spacing.m)

                    if let errorMessage {
                        PhrasesNotice(
                            text: errorMessage,
                            systemName: "exclamationmark.circle",
                            tint: AppColor.purple
                        )
                        .padding(.horizontal, BikeyMetrics.Sizing.screenHorizontalInset)
                        .padding(.top, BikeyMetrics.Spacing.s)
                    }

                    entryList
                        .padding(.top, BikeyMetrics.Spacing.m)
                }

                PhrasesFloatingActionButton {
                    editorPayload = DictionaryEditorPayload(entry: nil)
                }
                .padding(.trailing, BikeyMetrics.Sizing.screenHorizontalInset)
                .padding(.bottom, BikeyMetrics.Sizing.tabBarHeight + 18)
            }
            .navigationBarHidden(true)
            .bikeyKeyboardToolbar { searchFocused = nil }
            .editorSheet(item: $editorPayload) { payload in
                DictionaryEntryEditor(
                    entry: payload.entry,
                    onSave: { sourceText, replacementText in
                        await saveEntry(
                            id: payload.entry?.id,
                            sourceText: sourceText,
                            replacementText: replacementText
                        )
                    },
                    onDelete: payload.entry.map { entry in
                        {
                            editorPayload = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                pendingDelete = entry
                            }
                        }
                    }
                )
            }
            .confirmationDialog(
                "Delete phrase?",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    guard let entry = pendingDelete else { return }
                    pendingDelete = nil
                    Task { await deleteEntry(entry) }
                }
                Button("Cancel", role: .cancel) {
                    pendingDelete = nil
                }
            }
            .task {
                await refreshEntries()
            }
            .onChange(of: session.profile) { _ in
                entries = UserDictionaryStore.readEntries()
            }
        }
    }

    @ViewBuilder
    private var entryList: some View {
        if filteredEntries.isEmpty {
            ScrollView(.vertical, showsIndicators: false) {
                PhrasesEmptyState(hasQuery: !query.isEmpty)
                    .padding(.horizontal, BikeyMetrics.Sizing.screenHorizontalInset)
                    .padding(.top, BikeyMetrics.Spacing.l)
                Spacer(minLength: BikeyMetrics.Sizing.tabBarHeight + 80)
            }
            .scrollDismissesKeyboard(.interactively)
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                PhrasesCard(
                    entries: filteredEntries,
                    onTap: { entry in
                        editorPayload = DictionaryEditorPayload(entry: entry)
                    },
                    onDelete: { entry in
                        pendingDelete = entry
                    }
                )
                .padding(.horizontal, BikeyMetrics.Sizing.screenHorizontalInset)
                .padding(.bottom, BikeyMetrics.Sizing.tabBarHeight + 80)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func toggleSearch() {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
            if isSearchExpanded {
                isSearchExpanded = false
                searchFocused = nil
                query = ""
            } else {
                isSearchExpanded = true
            }
        }
        if isSearchExpanded {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                searchFocused = .query
            }
        }
    }

    private func refreshEntries() async {
        entries = UserDictionaryStore.readEntries()
        guard session.profile != nil else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await session.refreshUserDictionaryCache()
            entries = UserDictionaryStore.readEntries()
            errorMessage = nil
        } catch {
            errorMessage = "Could not sync phrases."
        }
    }

    private func saveEntry(id: UUID?, sourceText: String, replacementText: String) async -> String? {
        let trimmedSource = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReplacement = replacementText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSource.isEmpty, !trimmedReplacement.isEmpty else {
            let message = "Source and replacement are required."
            errorMessage = message
            return message
        }
        let sourceKey = UserDictionaryStore.normalizedSourceKey(trimmedSource)
        guard !entries.contains(where: { $0.id != id && $0.sourceKey == sourceKey }) else {
            let message = "That source is already saved."
            errorMessage = message
            return message
        }
        guard let profile = session.profile else {
            let message = "Sign in to edit your phrases."
            errorMessage = message
            return message
        }

        isSyncing = true
        defer { isSyncing = false }
        do {
            if let id {
                try await UserDictionaryRemoteStore.updateEntry(
                    id: id,
                    sourceText: trimmedSource,
                    replacementText: trimmedReplacement,
                    userId: profile.id
                )
            } else {
                try await UserDictionaryRemoteStore.insertEntry(
                    sourceText: trimmedSource,
                    replacementText: trimmedReplacement,
                    userId: profile.id
                )
            }
            try await session.refreshUserDictionaryCache()
            entries = UserDictionaryStore.readEntries()
            editorPayload = nil
            errorMessage = nil
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            return nil
        } catch {
            let message = "Could not save phrase."
            errorMessage = message
            return message
        }
    }

    private func deleteEntry(_ entry: UserDictionaryEntry) async {
        guard let profile = session.profile else {
            errorMessage = "Sign in to edit your phrases."
            return
        }
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await UserDictionaryRemoteStore.deleteEntry(id: entry.id, userId: profile.id)
            try await session.refreshUserDictionaryCache()
            entries = UserDictionaryStore.readEntries()
            errorMessage = nil
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } catch {
            errorMessage = "Could not delete phrase."
        }
    }
}

private struct DictionaryEditorPayload: Identifiable {
    let id = UUID()
    let entry: UserDictionaryEntry?
}

// MARK: - Header

private struct PhrasesHeader: View {
    let title: String
    let isSearchExpanded: Bool
    let toggleSearch: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .bikeyFont(20, weight: .medium, relativeTo: .title3)
                .foregroundStyle(AppColor.ink)
                .frame(maxWidth: .infinity)

            HStack {
                Spacer()
                Button(action: toggleSearch) {
                    Image(systemName: isSearchExpanded ? "xmark" : "magnifyingglass")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColor.ink)
                        .frame(width: 40, height: 40)
                        .background(.white, in: Circle())
                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSearchExpanded ? "Close search" : "Search phrases")
            }
        }
        .frame(height: 44)
    }
}

// MARK: - Search bar (expanded)

private struct PhrasesSearchBar: View {
    @Binding var text: String
    var focused: FocusState<DictionarySearchField?>.Binding

    private var isFocused: Bool { focused.wrappedValue == .query }

    var body: some View {
        HStack(spacing: BikeyMetrics.Spacing.s) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(AppColor.softText)

            TextField("Search phrases", text: $text)
                .focused(focused, equals: .query)
                .bikeyFont(15, weight: .regular, relativeTo: .body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .foregroundStyle(AppColor.ink)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(AppColor.softText)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
                .transition(.opacity)
            }
        }
        .padding(.horizontal, BikeyMetrics.Spacing.m)
        .frame(minHeight: 44)
        .background(.white, in: Capsule())
        .shadow(color: .black.opacity(isFocused ? 0.06 : 0.03), radius: 8, x: 0, y: 3)
        .animation(.easeInOut(duration: 0.18), value: text.isEmpty)
    }
}

// MARK: - Sort pills

private struct PhrasesSortPills: View {
    @Binding var selection: PhraseSort

    var body: some View {
        HStack(spacing: BikeyMetrics.Spacing.s) {
            ForEach(PhraseSort.allCases, id: \.self) { sort in
                SortPill(
                    title: sort.title,
                    isSelected: selection == sort
                ) {
                    guard selection != sort else { return }
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        selection = sort
                    }
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }
            }
            Spacer(minLength: 0)
        }
    }
}

private struct SortPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .bikeyFont(14, weight: isSelected ? .medium : .regular, relativeTo: .subheadline)
                .foregroundStyle(isSelected ? .white : AppColor.ink)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(isSelected ? AppColor.charcoalAction : Color.white.opacity(0.96))
                )
                .overlay(
                    Capsule().stroke(
                        isSelected ? Color.clear : AppColor.rule.opacity(0.35),
                        lineWidth: 0.6
                    )
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - List card

private struct PhrasesCard: View {
    let entries: [UserDictionaryEntry]
    let onTap: (UserDictionaryEntry) -> Void
    let onDelete: (UserDictionaryEntry) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                PhraseRow(entry: entry, onTap: { onTap(entry) }, onDelete: { onDelete(entry) })

                if index < entries.count - 1 {
                    Rectangle()
                        .fill(AppColor.rule.opacity(0.35))
                        .frame(height: 0.5)
                        .padding(.leading, BikeyMetrics.Spacing.m + 4)
                }
            }
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 6)
    }
}

private struct PhraseRow: View {
    let entry: UserDictionaryEntry
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.sourceText)
                    .bikeyFont(17, weight: .medium, relativeTo: .body)
                    .foregroundStyle(AppColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppColor.softText)
                        .padding(.top, 2)

                    Text(entry.replacementText)
                        .bikeyFont(14, weight: .regular, relativeTo: .footnote)
                        .foregroundStyle(AppColor.muted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .minimumScaleFactor(0.84)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, BikeyMetrics.Spacing.m + 4)
            .padding(.vertical, BikeyMetrics.Spacing.m - 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(PhraseRowButtonStyle())
        .contextMenu {
            Button("Edit", systemImage: "pencil", action: onTap)
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
        .accessibilityLabel("\(entry.sourceText) becomes \(entry.replacementText)")
    }
}

private struct PhraseRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed
                    ? AppColor.lavender.opacity(0.45)
                    : Color.clear
            )
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

// MARK: - Floating action button

private struct PhrasesFloatingActionButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(AppColor.charcoalAction, in: Circle())
                .shadow(color: .black.opacity(0.22), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add phrase")
    }
}

// MARK: - Notice + Empty state

private struct PhrasesNotice: View {
    let text: String
    let systemName: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .bikeyFont(12, weight: .regular, relativeTo: .footnote)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .frame(minHeight: 34)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct PhrasesEmptyState: View {
    let hasQuery: Bool

    var body: some View {
        VStack(spacing: BikeyMetrics.Spacing.m) {
            Circle()
                .fill(AppColor.lavender.opacity(0.5))
                .frame(width: 64, height: 64)
                .overlay {
                    Image(systemName: hasQuery ? "magnifyingglass" : "text.book.closed")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(AppColor.purple.opacity(0.74))
                }

            VStack(spacing: 6) {
                Text(hasQuery ? "No matches" : "No phrases yet")
                    .bikeyFont(16, weight: .medium, relativeTo: .body)
                    .foregroundStyle(AppColor.ink)

                Text(hasQuery
                     ? "Try another source or replacement."
                     : "Tap the + button to save your first phrase.")
                    .bikeyFont(13, weight: .regular, relativeTo: .footnote)
                    .foregroundStyle(AppColor.muted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.84)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BikeyMetrics.Spacing.xl)
        .padding(.horizontal, BikeyMetrics.Spacing.l)
        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 6)
    }
}

// MARK: - Editor bottom sheet

private enum EditorField: Hashable {
    case source
    case replacement
}

private let sourceCharLimit = 32
private let replacementCharLimit = 80

private struct DictionaryEntryEditor: View {
    let entry: UserDictionaryEntry?
    let onSave: (String, String) async -> String?
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var sourceText: String
    @State private var replacementText: String
    @State private var isSaving = false
    @State private var validationMessage: String?
    @FocusState private var focusedField: EditorField?

    init(
        entry: UserDictionaryEntry?,
        onSave: @escaping (String, String) async -> String?,
        onDelete: (() -> Void)?
    ) {
        self.entry = entry
        self.onSave = onSave
        self.onDelete = onDelete
        _sourceText = State(initialValue: entry?.sourceText ?? "")
        _replacementText = State(initialValue: entry?.replacementText ?? "")
    }

    private var canSave: Bool {
        !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !replacementText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && sourceText.count <= sourceCharLimit
            && replacementText.count <= replacementCharLimit
    }

    var body: some View {
        VStack(spacing: 0) {
            EditorTopBar(
                cancelAction: { dismiss() },
                saveAction: {
                    Task {
                        guard !isSaving, canSave else { return }
                        isSaving = true
                        validationMessage = await onSave(sourceText, replacementText)
                        isSaving = false
                    }
                },
                isSaveEnabled: canSave && !isSaving,
                isSaving: isSaving
            )
            .padding(.horizontal, BikeyMetrics.Spacing.m)
            .padding(.top, BikeyMetrics.Spacing.m)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: BikeyMetrics.Spacing.l) {
                    EditorLabeledField(
                        label: "Source",
                        placeholder: "kyounomeetingha3jini",
                        text: $sourceText,
                        field: .source,
                        focused: $focusedField,
                        charLimit: sourceCharLimit,
                        submitLabel: .next,
                        onSubmit: { focusedField = .replacement }
                    )

                    EditorLabeledField(
                        label: "Replacement",
                        placeholder: "今日のmeetingは3時に",
                        text: $replacementText,
                        field: .replacement,
                        focused: $focusedField,
                        charLimit: replacementCharLimit,
                        submitLabel: .done,
                        onSubmit: { focusedField = nil }
                    )

                    if let validationMessage {
                        PhrasesNotice(
                            text: validationMessage,
                            systemName: "exclamationmark.circle",
                            tint: AppColor.purple
                        )
                    }

                    if let onDelete {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .regular))
                                Text("Delete phrase")
                                    .bikeyFont(14, weight: .medium, relativeTo: .body)
                            }
                            .foregroundStyle(AppColor.purple)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(.white, in: Capsule())
                            .overlay(
                                Capsule().stroke(AppColor.rule.opacity(0.4), lineWidth: 0.6)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.top, BikeyMetrics.Spacing.s)
                    }
                }
                .padding(.horizontal, BikeyMetrics.Spacing.l)
                .padding(.top, BikeyMetrics.Spacing.xl)
                .padding(.bottom, BikeyMetrics.Spacing.l)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(AppColor.background.ignoresSafeArea())
        .bikeyKeyboardToolbar { focusedField = nil }
        .onAppear {
            if entry == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    focusedField = .source
                }
            }
        }
    }
}

private struct EditorTopBar: View {
    let cancelAction: () -> Void
    let saveAction: () -> Void
    let isSaveEnabled: Bool
    let isSaving: Bool

    var body: some View {
        HStack {
            Button(action: cancelAction) {
                Text("Cancel")
                    .bikeyFont(15, weight: .regular, relativeTo: .body)
                    .foregroundStyle(AppColor.ink)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.white, in: Capsule())
                    .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: saveAction) {
                ZStack {
                    if isSaving {
                        ProgressView()
                            .tint(AppColor.ink)
                            .scaleEffect(0.8)
                    } else {
                        Text("Save")
                            .bikeyFont(15, weight: .medium, relativeTo: .body)
                            .foregroundStyle(isSaveEnabled ? AppColor.ink : AppColor.softText)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                .background(.white, in: Capsule())
                .shadow(color: .black.opacity(isSaveEnabled ? 0.05 : 0.02), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(!isSaveEnabled)
        }
    }
}

private struct EditorLabeledField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let field: EditorField
    var focused: FocusState<EditorField?>.Binding
    let charLimit: Int
    var submitLabel: SubmitLabel = .return
    var onSubmit: (() -> Void)? = nil

    private var isFocused: Bool { focused.wrappedValue == field }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .bikeyFont(13, weight: .regular, relativeTo: .footnote)
                .foregroundStyle(AppColor.muted)

            HStack(alignment: .center, spacing: 8) {
                TextField(placeholder, text: $text)
                    .focused(focused, equals: field)
                    .bikeyFont(16, weight: .regular, relativeTo: .body)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(submitLabel)
                    .foregroundStyle(AppColor.ink)
                    .onSubmit { onSubmit?() }
                    .onChange(of: text) { newValue in
                        if newValue.count > charLimit {
                            text = String(newValue.prefix(charLimit))
                        }
                    }

                Text("\(text.count)/\(charLimit)")
                    .bikeyFont(12, weight: .regular, relativeTo: .caption)
                    .foregroundStyle(AppColor.softText)
                    .monospacedDigit()
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 52)
            .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isFocused ? AppColor.ink.opacity(0.18) : AppColor.rule.opacity(0.25),
                        lineWidth: isFocused ? 1 : 0.6
                    )
            )
            .animation(.easeInOut(duration: 0.18), value: isFocused)
            .contentShape(Rectangle())
            .onTapGesture { focused.wrappedValue = field }
        }
    }
}

private extension View {
    func editorSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        self.sheet(item: item) { value in
            content(value)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(32)
                .presentationBackground(AppColor.background)
        }
    }
}
