import KeyboardPreferences
import UIKit

@MainActor
final class HapticFeedback {
    static let shared = HapticFeedback()

    private let generator = UIImpactFeedbackGenerator(style: .light)
    private let defaults: UserDefaults? = KeyboardSettingsStore.sharedDefaults

    private init() {
        generator.prepare()
    }

    func tap() {
        guard defaults?.bool(forKey: KeyboardSettingsStore.hapticsEnabledKey) == true else { return }
        generator.impactOccurred()
        generator.prepare()
    }
}
