import KeyboardKit

final class EnglishActionHandler: KeyboardAction.StandardActionHandler {
    private weak var englishController: KeyboardViewController?

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
        if gesture == .release, action == .space {
            Task { @MainActor [weak englishController] in
                englishController?.handleSpaceAction()
            }
            return
        }

        super.handle(gesture, on: action)

        switch gesture {
        case .release, .repeatPress:
            Task { @MainActor [weak englishController] in
                englishController?.refreshSuggestionsAfterInput()
            }
        default:
            break
        }
    }
}
