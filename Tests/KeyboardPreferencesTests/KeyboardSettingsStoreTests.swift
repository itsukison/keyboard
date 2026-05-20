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
}
