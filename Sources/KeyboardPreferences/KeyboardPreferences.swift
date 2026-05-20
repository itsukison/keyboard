import Foundation

public enum CompositionDisplayMode: String, Codable, Sendable, CaseIterable {
    case balancedRaw
    case japaneseHeavyKana

    public var isJapaneseHeavy: Bool {
        self == .japaneseHeavyKana
    }
}

public enum KeyboardSettingsStore {
    public static let appGroupIdentifier = "group.com.core7.bikey"
    public static let compositionDisplayModeKey = "compositionDisplayMode"

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
}
