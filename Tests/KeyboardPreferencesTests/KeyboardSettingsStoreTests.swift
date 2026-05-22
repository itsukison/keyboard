import XCTest
@testable import KeyboardPreferences

final class KeyboardSettingsStoreTests: XCTestCase {
    func testRoundTripsCompositionDisplayMode() {
        let suiteName = "KeyboardSettingsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        KeyboardSettingsStore.writeCompositionDisplayMode(.japaneseHeavyKana, defaults: defaults)

        XCTAssertEqual(KeyboardSettingsStore.readCompositionDisplayMode(defaults: defaults), .japaneseHeavyKana)
    }

    func testInvalidRawValueFallsBackToBalancedRaw() {
        let suiteName = "KeyboardSettingsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("broken", forKey: KeyboardSettingsStore.compositionDisplayModeKey)

        XCTAssertEqual(KeyboardSettingsStore.readCompositionDisplayMode(defaults: defaults), .balancedRaw)
    }

    func testUserDictionaryEntriesRoundTrip() {
        let suiteName = "KeyboardSettingsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let entry = makeEntry(source: "aware", replacement: "aware")

        UserDictionaryStore.writeEntries([entry], defaults: defaults)

        XCTAssertEqual(UserDictionaryStore.readEntries(defaults: defaults), [entry])
    }

    func testInvalidUserDictionaryDataFallsBackToEmpty() {
        let suiteName = "KeyboardSettingsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data("broken".utf8), forKey: KeyboardSettingsStore.userDictionaryEntriesKey)

        XCTAssertEqual(UserDictionaryStore.readEntries(defaults: defaults), [])
    }

    func testUserDictionaryLookupNormalizesWhitespaceAndCase() {
        let entry = makeEntry(source: " aware ", replacement: "哀れ")

        XCTAssertEqual(
            UserDictionaryStore.lookupEntry(for: "AWARE", in: [entry])?.replacementText,
            "哀れ"
        )
    }

    func testUserDictionaryUpsertReplacesDuplicateSource() {
        let suiteName = "KeyboardSettingsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        UserDictionaryStore.writeEntries([
            makeEntry(source: "Aware", replacement: "aware"),
        ], defaults: defaults)
        let updated = makeEntry(source: " aware ", replacement: "哀れ")

        UserDictionaryStore.upsertEntry(updated, defaults: defaults)

        XCTAssertEqual(UserDictionaryStore.readEntries(defaults: defaults), [updated])
    }

    func testUserDictionaryDeleteRemovesEntryByID() {
        let suiteName = "KeyboardSettingsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let first = makeEntry(source: "aware", replacement: "aware")
        let second = makeEntry(source: "hashi", replacement: "橋")
        UserDictionaryStore.writeEntries([first, second], defaults: defaults)

        UserDictionaryStore.deleteEntry(id: first.id, defaults: defaults)

        XCTAssertEqual(UserDictionaryStore.readEntries(defaults: defaults), [second])
    }

    private func makeEntry(source: String, replacement: String) -> UserDictionaryEntry {
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
