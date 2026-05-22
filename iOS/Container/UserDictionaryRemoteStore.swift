import Foundation
import KeyboardPreferences

enum UserDictionaryRemoteStore {
    static func fetchEntries(for userId: UUID) async throws -> [UserDictionaryEntry] {
        let rows: [Row] = try await supabase
            .from("user_dictionary_entries")
            .select("id, user_id, source_text, replacement_text, created_at, updated_at")
            .eq("user_id", value: userId)
            .order("updated_at", ascending: false)
            .execute()
            .value

        return rows.map(\.entry)
    }

    static func insertEntry(
        sourceText: String,
        replacementText: String,
        userId: UUID
    ) async throws {
        let row = InsertRow(
            user_id: userId,
            source_text: sourceText,
            replacement_text: replacementText
        )
        try await supabase
            .from("user_dictionary_entries")
            .insert(row)
            .execute()
    }

    static func updateEntry(
        id: UUID,
        sourceText: String,
        replacementText: String,
        userId: UUID
    ) async throws {
        let row = UpdateRow(
            source_text: sourceText,
            replacement_text: replacementText
        )
        try await supabase
            .from("user_dictionary_entries")
            .update(row)
            .eq("id", value: id)
            .eq("user_id", value: userId)
            .execute()
    }

    static func deleteEntry(id: UUID, userId: UUID) async throws {
        try await supabase
            .from("user_dictionary_entries")
            .delete()
            .eq("id", value: id)
            .eq("user_id", value: userId)
            .execute()
    }
}

private struct Row: Decodable {
    let id: UUID
    let user_id: UUID
    let source_text: String
    let replacement_text: String
    let created_at: Date
    let updated_at: Date

    var entry: UserDictionaryEntry {
        UserDictionaryEntry(
            id: id,
            userId: user_id,
            sourceText: source_text,
            replacementText: replacement_text,
            createdAt: created_at,
            updatedAt: updated_at
        )
    }
}

private struct InsertRow: Encodable {
    let user_id: UUID
    let source_text: String
    let replacement_text: String
}

private struct UpdateRow: Encodable {
    let source_text: String
    let replacement_text: String
}
