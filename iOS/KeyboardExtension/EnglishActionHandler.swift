import KeyboardKit

final class EnglishActionHandler: KeyboardAction.StandardActionHandler {
    private weak var englishController: KeyboardViewController?

    @MainActor
    init(controller: KeyboardViewController) {
        self.englishController = controller
        super.init(
            controller: controller,
            keyboardContext: controller.state.keyboardContext,
            keyboardBehavior: controller.services.keyboardBehavior,
            autocompleteContext: controller.state.autocompleteContext,
            autocompleteService: controller.services.autocompleteService,
            emojiContext: controller.state.emojiContext,
            feedbackContext: controller.state.feedbackContext,
            feedbackService: controller.services.feedbackService,
            keyboardAppContext: controller.state.keyboardAppContext,
            spacebarDragGestureHandler: controller.services.spacebarDragGestureHandler
        )
    }

    override func handle(_ gesture: Keyboard.Gesture, on action: KeyboardAction) {
        if gesture == .press {
            MainActor.assumeIsolated {
                HapticFeedback.shared.tap()
            }
        }

        if gesture == .release, action == .space {
            let controller = englishController
            MainActor.assumeIsolated {
                controller?.handleSpaceAction()
            }
            return
        }

        if gesture == .release, case .primary = action {
            let controller = englishController
            let handled = MainActor.assumeIsolated {
                controller?.handleReturnAction() == true
            }
            if handled { return }
        }

        super.handle(gesture, on: action)

        switch gesture {
        case .release, .repeatPress:
            let controller = englishController
            MainActor.assumeIsolated {
                controller?.scheduleSuggestionsRefreshAfterInput()
            }
        default:
            break
        }
    }
}
