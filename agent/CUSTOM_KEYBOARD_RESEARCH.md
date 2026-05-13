# Custom Keyboard Research Notes

Date: 2026-05-09  
Scope: Apple custom-keyboard APIs, native keyboard behavior expectations, and open-source keyboard implementations that can inform the current bilingual romaji/Japanese prototype.

## Executive Summary

Our current implementation already follows a good minimum-latency rule: character keys insert raw text into the host immediately, and conversion runs asynchronously against snapshots. The two biggest risks now are state desynchronization and native-feel gaps.

The best pattern to borrow is not a bigger UI framework; it is a stricter input pipeline:

1. Put every host text mutation behind one display/proxy manager.
2. Track expected edits before/after each `UITextDocumentProxy` operation.
3. Treat `textWillChange` / `textDidChange` as reconciliation callbacks, not just reset hooks.
4. Batch action chains so conversion/candidate refresh happens once per logical gesture.
5. Make layout and behavior depend on `textDocumentProxy` traits: keyboard type, return key type, text content type, selected text, input mode switch key requirement, and surrounding context.

For this repo, the concrete follow-up would be to evolve `KeyboardViewController` toward an azooKey-like `DisplayedTextManager` plus `ExpectedEditTracker`, then layer native behaviors such as key popups, audio clicks, callout/alternate keys, double-space period, trait-specific layouts, and better candidate interaction.

## Current Prototype Observations

Relevant local files:

- `/Users/itsuki/Desktop/keyboard/iOS/KeyboardExtension/KeyboardViewController.swift`
- `/Users/itsuki/Desktop/keyboard/iOS/KeyboardExtension/Views/KeyboardView.swift`
- `/Users/itsuki/Desktop/keyboard/iOS/KeyboardExtension/Views/CandidateBar.swift`
- `/Users/itsuki/Desktop/keyboard/Sources/KeyboardCore/InputController.swift`
- `/Users/itsuki/Desktop/keyboard/Sources/KeyboardCore/InputCommitPlanner.swift`

Strengths:

- Character, space, and backspace fire on `.touchDown`, which is correct for perceived keyboard latency.
- Raw text is inserted immediately, so typing is not blocked by conversion.
- Async conversion is snapshot-based, and stale results are skipped.
- Commit planning preserves a post-snapshot suffix, which directly addresses fast-typing input loss.
- Backspace repeat exists.
- Candidate selection already uses the same snapshot/prefix invariant as normal commit.

Gaps:

- `textDidChange` only resets on empty context. It does not reconcile cursor movement, selection, external deletion, host autocorrection, undo, or app-driven text changes.
- `KeyboardViewController` directly owns both composition state and host proxy mutations. That makes it hard to prove “every key reached the host exactly once.”
- The commit path deletes `buffer.count` one scalar at a time. That can be wrong for nontrivial composed characters and may be slower than a diff-based display manager.
- Candidate bar rebuilds every candidate button on every update. This is fine for a prototype, but under fast typing it can become part of perceived lag.
- There is no key popup/callout, native input click support, autocapitalization, double-space period, smart punctuation, trait-specific key sets, or locale/return-key-specific layout.
- No use of `needsInputModeSwitchKey` / `handleInputModeList(from:with:)`, so the globe key is not fully native when long-pressed.

## Apple Docs: Constraints And Must-Haves

Sources:

- Apple `UIInputViewController`: https://developer.apple.com/documentation/uikit/uiinputviewcontroller
- Apple `UITextDocumentProxy`: https://developer.apple.com/documentation/uikit/uitextdocumentproxy
- Apple `UITextInputTraits`: https://developer.apple.com/documentation/uikit/uitextinputtraits
- Apple `UITextInteraction`: https://developer.apple.com/documentation/uikit/uitextinteraction
- Apple handling text interactions in custom keyboards: https://developer.apple.com/documentation/uikit/handling-text-interactions-in-custom-keyboards
- Apple custom keyboard guide archive: https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html
- Apple `UIInputViewAudioFeedback`: https://developer.apple.com/documentation/uikit/uiinputviewaudiofeedback
- Apple HIG text input/keyboards: https://developer.apple.com/design/human-interface-guidelines/keyboards

Key API facts:

- A keyboard extension is a `UIInputViewController`; it cannot draw above the top edge of its primary view. This matters for native-style key popups: the popup must fit inside the keyboard view or be simulated with an internal overlay.
- The host text field is reached through `textDocumentProxy`; insertion/deletion/cursor adjustment must go through the proxy.
- `textDocumentProxy` exposes traits and context: `keyboardType`, `returnKeyType`, `textContentType`, `documentContextBeforeInput`, `documentContextAfterInput`, and `selectedText`.
- `UITextDocumentProxy` also has marked-text APIs (`setMarkedText` and `unmarkText`) for active input sessions. These are worth prototyping for IME feel, but host-app behavior must be tested carefully.
- Apple expects custom keyboards to support obvious system behaviors: next keyboard switching, appropriate keyboard type, auto-capitalization, caps lock, double-space period, and probably suggestions when relevant.
- The extension can request open access, but doing so changes user trust and access boundaries. Our `RequestsOpenAccess: false` is the right default.
- Secure text fields and phone pad/name-phone fields can replace custom keyboards with the system keyboard. The product must handle being unavailable in those contexts.
- `UITextInteraction` is mainly relevant as a reminder that the host owns selection and text interaction. The keyboard should observe proxy context changes and reconcile; it should not assume the cursor remains at the text tail.

## Open-Source And Reference Implementations

### azooKey

Sources:

- Repository: https://github.com/azooKey/azooKey
- Keyboard controller: https://github.com/azooKey/azooKey/blob/main/Keyboard/Display/KeyboardViewController.swift
- Action manager: https://github.com/azooKey/azooKey/blob/main/Keyboard/Display/KeyboardActionManager.swift
- Input manager: https://github.com/azooKey/azooKey/blob/main/Keyboard/Display/InputManager.swift
- Displayed text manager: https://github.com/azooKey/azooKey/blob/main/AzooKeyCore/Sources/KeyboardExtensionUtils/DisplayedTextManager.swift
- Expected edit tracker: https://github.com/azooKey/azooKey/blob/main/AzooKeyCore/Sources/KeyboardExtensionUtils/ExpectedEditTracker.swift
- Memory leak note: https://github.com/azooKey/azooKey/blob/main/docs/view_controller_memory_leak.md

Borrowable patterns:

- `KeyboardActionManager` is the only path from UI gesture to input mutation. It batches related actions and only refreshes results once at the end of an action block.
- `InputManager` owns composition, live conversion, prediction, selected text, and surrounding-text reconciliation. The controller mostly forwards lifecycle and proxy events.
- `DisplayedTextManager` wraps every `insertText`, `deleteBackward`, `adjustTextPosition`, marked-text update, and composition display update.
- `ExpectedEditTracker` stores expected before/after states for edits caused by the keyboard, so later `textDidChange` callbacks can be consumed instead of misread as external user actions.
- azooKey records `textWillChange` context, then compares it with `textDidChange` context. It classifies selection, cursor movement, cut, undo, jumped cursor, and no-op callbacks.
- It uses `needsInputModeSwitchKey` and `handleInputModeList(from:with:)` for native keyboard switching behavior.
- It supports `UIInputViewAudioFeedback` by making the input view opt into input clicks.
- It treats keyboard height, orientation, iPad floating sizes, and iOS-version behavior as dynamic state instead of constants.
- It keeps some heavy/shared state static because keyboard view controllers can be retained per host context and may accumulate.

Licensing/caution:

- azooKey is a strong source of architecture ideas and, where license-compatible, small utility patterns. We should not copy large subsystems blindly; our problem is bilingual romaji composition, not a full Japanese keyboard clone.

### KeyboardKit

Sources:

- Repository: https://github.com/KeyboardKit/KeyboardKit
- Documentation: https://docs.keyboardkit.com
- Demo controller: https://github.com/KeyboardKit/KeyboardKit/blob/main/Demo/Keyboard/KeyboardViewController.swift
- Demo action handler: https://github.com/KeyboardKit/KeyboardKit/blob/main/Demo/Keyboard/Services/DemoActionHandler.swift

Borrowable patterns:

- KeyboardKit’s public surface highlights the right product checklist: actions, autocomplete, callouts, feedback, layout, localization, proxy helpers, status, styling, and themes.
- It models keyboard state separately from view rendering. The UI is a projection of controller state, not the source of truth.
- Spacebar long press for cursor movement is a native-feeling interaction worth considering later.
- Feedback is centrally configured rather than sprinkled in every button.

Licensing/caution:

- Current KeyboardKit distribution is not an open codebase to copy from directly. Use it as a feature checklist and API-design reference, or evaluate it as a dependency only if its license/commercial model fits.

### TastyImitationKeyboard / Older Native-Look Keyboards

Sources:

- https://github.com/archagon/tasty-imitation-keyboard

Borrowable patterns:

- Older native-look keyboard clones are useful for visual metrics, key shapes, shadows, row offsets, and popup-callout geometry.
- Treat these as UI references only. Many pre-SwiftUI/pre-modern-iOS assumptions are stale.

## Recommendations For This Project

### 1. Add A Displayed Text Manager

Create a new keyboard-extension layer, probably local to `iOS/KeyboardExtension`, with responsibilities similar to azooKey’s `DisplayedTextManager`:

- Wrap `textDocumentProxy.insertText`, `deleteBackward`, and `adjustTextPosition`.
- Record observed `{left, selected, right}` before and after each keyboard-caused edit.
- Track `textChangedCount`.
- Provide methods like `insertRawCharacter`, `replaceComposition(snapshot:preview:suffix:)`, `deleteBackwardFromComposition`, `moveCursor`, and `clearComposition`.

Expected effect:

- Reduces dropped-key and double-insert bugs because all proxy mutations go through one audited surface.
- Gives us a place to handle UTF-16 offsets, grapheme clusters, cursor movement, and host quirks.

### 2. Add Expected Edit Reconciliation

Implement a small `ExpectedEditTracker` inspired by azooKey:

- On every proxy edit, record the before/after context when available.
- In `textWillChange`, save the current context.
- In `textDidChange`, compare the previous and current context.
- If the change matches an expected edit, consume it.
- If not, classify it as external cursor move, selection, cut/delete, undo, submission, or host replacement.

Expected effect:

- Prevents our internal `buffer` from surviving after the user moves the cursor or host text changes.
- Prevents conversion commits from deleting text after the cursor moved.
- Gives us deterministic logs for the hardest bugs.

### 3. Keep The Immediate Insert, But Move Conversion Off The Tap Path

Character tap path should remain:

1. Append to internal composition.
2. Insert raw character into host immediately.
3. Schedule conversion.
4. Return to the run loop.

But conversion scheduling should be improved:

- Keep the 30 ms debounce only for candidate refresh.
- Never run heavy conversion synchronously on the main actor unless committing.
- Prewarm `KanaKanjiAdapter` in `viewDidLoad` or first idle frame.
- Consider an actor or serial queue for conversion so cancellation is explicit and stale results cannot overwrite newer state.
- Cache the last conversion by raw snapshot and left-side context.

### 4. Diff Composition Display Instead Of Full Delete/Replace Where Possible

For live conversion updates, azooKey computes the common prefix between old displayed composition and new displayed composition, deletes only the changed suffix, inserts the new suffix, and restores cursor position.

Our commit currently does full delete/insert, which is acceptable on confirmation. For live preview or marked composition, prefer diff updates:

- old displayed text: raw or previous conversion
- new displayed text: latest conversion preview
- common prefix
- delete old suffix
- insert new suffix
- move cursor to intended composition position

Expected effect:

- Less host churn, fewer text-change callbacks, lower perceived lag.

### 5. Decide Whether To Use Marked Text

The current comment says keyboard extensions have no `setMarkedText`, but `UITextDocumentProxy` supports marked text APIs in modern UIKit. azooKey has a setting to use marked text, while retaining a non-marked fallback.

Recommendation:

- Prototype marked text behind a feature flag.
- Keep raw-insert fallback because host behavior can vary.
- Test in Notes, Messages, Safari search, UITextField, UITextView, and secure/phone contexts.

Expected effect:

- More native IME behavior when it works.
- Potentially less delete/reinsert churn.

Risk:

- Marked text behavior may be inconsistent across host apps. This must be guarded and tested heavily.

### 6. Native Keyboard Feel Checklist

Implement these in roughly this order:

- Use `needsInputModeSwitchKey` to hide/show globe as appropriate.
- Use `handleInputModeList(from:with:)` on globe long press.
- Add `UIInputViewAudioFeedback` support for system input clicks.
- Reuse haptic generators instead of creating a new `UIImpactFeedbackGenerator` on every tap.
- Add key popup/callout overlay for character keys.
- Add long-press alternates for punctuation, vowels, hyphen/long-vowel, symbols, and possibly kana forms.
- Add double-space period for English contexts, but suppress in Japanese composition.
- Add autocapitalization based on `autocapitalizationType`, sentence boundary, and text content type.
- Change return key label/action based on `returnKeyType`.
- Change layout for `.URL`, `.emailAddress`, `.numberPad`, `.decimalPad`, `.phonePad`, `.webSearch`.
- Add smart quote/dash behavior only where text traits permit.
- Make delete repeat accelerate after the first repeat window, closer to native behavior.

### 7. Candidate Bar Improvements

Short-term:

- Do not rebuild all buttons if candidates are identical.
- Add a stable default candidate cell.
- Distinguish preview/current conversion from alternatives.
- Preserve scroll position only when candidate set is same; reset on new composition.

Medium-term:

- Add candidate paging or a full candidate panel.
- Support selecting candidates for later Japanese spans, not only the first Japanese span.
- Add post-composition predictions after commit.
- Integrate English suggestions into the same candidate model instead of a separate boolean.

### 8. Trait-Aware Behavior

On `textDidChange` and `viewDidAppear`, read:

- `textDocumentProxy.keyboardType`
- `textDocumentProxy.returnKeyType`
- `textDocumentProxy.textContentType`
- `textDocumentProxy.autocapitalizationType`
- `textDocumentProxy.autocorrectionType`
- `textDocumentProxy.enablesReturnKeyAutomatically`

Use these to choose layout, candidate policy, autocorrect policy, return key behavior, and whether Japanese conversion should be active. For example, URLs/emails should reduce Japanese conversion aggressiveness and expose `.`, `/`, `@`, `.com`, and ASCII-friendly keys.

### 9. Observability

Keep the existing `KEYBOARD_DEBUG_LOG` path, but add structured counters:

- raw key down sequence number
- proxy edit sequence number
- conversion request id
- conversion snapshot
- buffer after key
- host tail before/after proxy edit
- expected-edit match/miss
- time from touchDown to proxy insert
- time from snapshot to candidate render

This gives us proof for “typed N keys, host received N keys” and makes dropped input reproducible.

### 10. Memory And Lifecycle

Keyboard extensions have tight memory limits and controllers may be created per host context. Borrow azooKey’s caution:

- Keep heavy engines lazily loaded and shared only where safe.
- Release model/dictionary memory on memory warning or keyboard disappearance if needed.
- Avoid retaining controller instances from closures, timers, tasks, or static state.
- Cancel conversion tasks in `viewWillDisappear`.
- In debug builds, log controller init/deinit counts.

## Suggested Implementation Plan

Phase 1: Reliability

- Add `ObservedTextState` and `ExpectedEditTracker`.
- Add `DisplayedTextManager` around `UITextDocumentProxy`.
- Route all insert/delete/commit paths through it.
- Expand tests around fast typing, stale conversion, suffix preservation, backspace repeat, cursor movement, and external text changes.

Phase 2: Native Behavior

- Add audio clicks, reusable haptic generator, globe long-press menu, return-key labels, trait-aware layouts, and double-space/autocap behavior.
- Add key popup overlay.
- Tune key metrics against screenshots of the native keyboard.

Phase 3: IME Quality

- Prototype marked text.
- Add multi-span candidate selection.
- Improve candidate bar reuse and scrolling.
- Add post-commit prediction and better English/Japanese mixed candidate policy.

## Highest-Value Borrow For The Next Coding Pass

Build these three small pieces first:

1. `ObservedTextState(left:center:right:)`
2. `ExpectedEditTracker`
3. `DisplayedTextManager`

Then simplify `KeyboardViewController` so it becomes an action coordinator instead of the owner of every host mutation. This is the cleanest path to fixing lag/dropped inputs without losing the current prototype’s good immediate-insert feel.
