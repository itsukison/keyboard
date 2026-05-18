import Foundation
import KeyboardKit

extension KeyboardApp {
    static var englishMVP: KeyboardApp {
        .init(
            name: "Bikey",
            licenseKey: nil,
            appGroupId: nil,
            locales: [Locale(identifier: "en")],
            autocomplete: .init(nextWordPredictionRequest: nil),
            deepLinks: nil,
            keyboardSettingsKeyPrefix: "BikeyKeyboardMVP"
        )
    }
}
