import Foundation

public enum CompositionDisplayMode: String, Codable, Sendable, CaseIterable {
    case balancedRaw
    case japaneseHeavyKana

    public var isJapaneseHeavy: Bool {
        self == .japaneseHeavyKana
    }
}

public enum KeyboardStyle: String, Codable, Sendable, CaseIterable {
    case standard
    case japaneseRomaji

    public var showsLongVowelKey: Bool {
        self == .japaneseRomaji
    }
}

public enum KeyboardSettingsStore {
    public static let appGroupIdentifier = "group.com.core7.bikey"
    public static let compositionDisplayModeKey = "compositionDisplayMode"
    public static let keyboardStyleKey = "keyboardStyle"
    public static let conversionPreferenceEntriesKey = "conversionPreferenceEntries"
    public static let userDictionaryEntriesKey = "userDictionaryEntries"
    public static let hapticsEnabledKey = "hapticsEnabled"

    public static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    public static func readCompositionDisplayMode(defaults: UserDefaults? = sharedDefaults) -> CompositionDisplayMode {
        guard let raw = defaults?.string(forKey: compositionDisplayModeKey),
              let mode = CompositionDisplayMode(rawValue: raw) else {
            return .balancedRaw
        }
        return mode
    }

    public static func writeCompositionDisplayMode(
        _ mode: CompositionDisplayMode,
        defaults: UserDefaults? = sharedDefaults
    ) {
        defaults?.set(mode.rawValue, forKey: compositionDisplayModeKey)
    }

    public static func readKeyboardStyle(defaults: UserDefaults? = sharedDefaults) -> KeyboardStyle {
        if let raw = defaults?.string(forKey: keyboardStyleKey) {
            return KeyboardStyle(rawValue: raw) ?? .standard
        }

        guard let rawMode = defaults?.string(forKey: compositionDisplayModeKey),
              let mode = CompositionDisplayMode(rawValue: rawMode) else {
            return .standard
        }

        let migratedStyle: KeyboardStyle = mode.isJapaneseHeavy ? .japaneseRomaji : .standard
        writeKeyboardStyle(migratedStyle, defaults: defaults)
        return migratedStyle
    }

    public static func writeKeyboardStyle(
        _ style: KeyboardStyle,
        defaults: UserDefaults? = sharedDefaults
    ) {
        defaults?.set(style.rawValue, forKey: keyboardStyleKey)
    }

    public static func readHapticsEnabled(defaults: UserDefaults? = sharedDefaults) -> Bool {
        defaults?.bool(forKey: hapticsEnabledKey) ?? false
    }

    public static func writeHapticsEnabled(
        _ enabled: Bool,
        defaults: UserDefaults? = sharedDefaults
    ) {
        defaults?.set(enabled, forKey: hapticsEnabledKey)
    }
}

public struct UserDictionaryEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let userId: UUID
    public let sourceText: String
    public let replacementText: String
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID,
        userId: UUID,
        sourceText: String,
        replacementText: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.sourceText = sourceText
        self.replacementText = replacementText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var sourceKey: String {
        UserDictionaryStore.normalizedSourceKey(sourceText)
    }
}

public enum UserDictionaryStore {
    public static func normalizedSourceKey(_ source: String) -> String {
        source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    public static func readEntries(defaults: UserDefaults? = KeyboardSettingsStore.sharedDefaults) -> [UserDictionaryEntry] {
        guard let data = defaults?.data(forKey: KeyboardSettingsStore.userDictionaryEntriesKey) else {
            return []
        }
        return (try? JSONDecoder().decode([UserDictionaryEntry].self, from: data)) ?? []
    }

    public static func writeEntries(
        _ entries: [UserDictionaryEntry],
        defaults: UserDefaults? = KeyboardSettingsStore.sharedDefaults
    ) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults?.set(data, forKey: KeyboardSettingsStore.userDictionaryEntriesKey)
    }

    public static func lookupEntry(
        for source: String,
        in entries: [UserDictionaryEntry] = readEntries()
    ) -> UserDictionaryEntry? {
        let key = normalizedSourceKey(source)
        guard !key.isEmpty else { return nil }
        return entries.first { $0.sourceKey == key }
    }

    public static func upsertEntry(
        _ entry: UserDictionaryEntry,
        defaults: UserDefaults? = KeyboardSettingsStore.sharedDefaults
    ) {
        var entries = readEntries(defaults: defaults)
        let key = entry.sourceKey
        if let index = entries.firstIndex(where: { $0.sourceKey == key }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
        writeEntries(entries, defaults: defaults)
    }

    public static func deleteEntry(
        id: UUID,
        defaults: UserDefaults? = KeyboardSettingsStore.sharedDefaults
    ) {
        let entries = readEntries(defaults: defaults).filter { $0.id != id }
        writeEntries(entries, defaults: defaults)
    }
}
