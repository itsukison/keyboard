# Bilingual Keyboard — Agent Handoff

Last updated: 2026-05-08

## What this project is

A custom iOS keyboard for Japanese–English bilinguals that lets the user type
mixed romaji sentences (e.g. `kyounomeetingha3jini` or `korekara we can get in the car`)
without manually toggling between language modes. The keyboard auto-detects
which spans are Japanese romaji (→ kana → kanji) and which are English, and
commits a single mixed-language string to the host text field.

Conversion engine: [AzooKeyKanaKanjiConverter](https://github.com/azooKey/AzooKeyKanaKanjiConverter)
with the optional **Zenzai v3** neural reranker (GGUF weight, llama.cpp,
SwiftyMarisa C++ dependency).

## Where we are right now

- ✅ Milestone 1: macOS CLI harness (`KanaKanjiHarness`) validates AzooKey + Zenzai end-to-end.
- ✅ Milestone 2: iOS keyboard extension scaffolded — UIKit-based QWERTY/numbers/symbols
  pages, candidate strip, IME-style live conversion. **Builds clean** under Xcode
  26.4.1 / Swift 6 for both `BilingualKeyboard` (container app) and
  `KeyboardExtension` targets.
- ✅ Successfully ran on iOS Simulator. User confirmed "mainly working".
- ✅ This session's fixes:
  - **IME-style live insertion** — typed romaji is now inserted into the host
    text field immediately so the user can see what they typed. On commit
    (space / return / candidate tap), we `deleteBackward(buffer.count)` then
    insert the converted text. iOS keyboard extensions have **no
    `setMarkedText` API**, so this delete-and-replace pattern is the standard
    (azooKey / Gboard use the same approach).
  - **Key visual feedback** — `KeyButton.isHighlighted` override toggles
    background color on press; modifier keys (shift / ⌫ / return / page-switch)
    use a muted gray, character keys white, mimicking the native keyboard.
    Added light haptic feedback via `UIImpactFeedbackGenerator`.
  - **Bilingual span detection rewrite** — old detector had a 30-word
    dictionary, no uppercase signal, and indiscriminately ran embedded-English
    matching on every token, so words like "computer" or "Hello" were being
    converted to kana/kanji. New detector:
    1. Dictionary expanded to ~250 common words.
    2. Per-token English heuristic: `looksLikeWholeEnglishWord(token)` returns
       true if the token contains uppercase, hits the dictionary, **or has
       romaji-syllable coverage < 70%**.
    3. Only when a token looks Japanese do we fall back to embedded-English
       splitting (for the `kyounomeeting...` no-space case).

## Architecture (1-minute overview)

```
KeyboardCore (SwiftPM library, root /)
├── BilingualSpanDetector  — splits raw input into JP / EN spans
├── Romaji                 — romaji → kana table + greedy parser
├── KanaKanjiAdapter       — wraps AzooKey's KanaKanjiConverter, optional Zenzai
└── InputController        — orchestrates detection + conversion, owns leftSideContext

KanaKanjiHarness (executable target) — CLI smoke test, useful for fast iteration

iOS/
├── Container/             — SwiftUI host app (instructions screen)
└── KeyboardExtension/     — UIInputViewController-based keyboard
    ├── KeyboardViewController.swift   — entry point, key handling, commit logic
    └── Views/
        ├── KeyboardView.swift         — QWERTY / numbers / symbols pages, KeyButton
        └── CandidateBar.swift         — preview label + scrolling candidate strip

project.yml                — XcodeGen spec; regenerate .xcodeproj via `xcodegen`
weights/                   — gitignored; drop zenz-v3-small-Q5_K_M.gguf here
```

### Conversion pipeline (per keystroke)

1. `KeyboardViewController.handle(.character(ch))` appends `ch` to `buffer`,
   inserts `ch` to the host text field, schedules a debounced (30ms) conversion.
2. `InputController.convert(buffer)` calls `BilingualSpanDetector.detect(buffer)`,
   then for each Japanese span runs `KanaKanjiAdapter.convert(...)` with the
   running `leftSideContext` (Japanese-only — English is intentionally excluded
   because Zenzai is monolingual JP and EN tokens degrade picks).
3. Result `LiveConversion { spans, conversions }` is rendered:
   - `CandidateBar` shows `preview` (joined string) + first-span candidates.
4. On commit, `deleteBackward(buffer.count)` then `insertText(preview)`. Japanese
   parts get appended to `leftSideContext` for next-turn context.

## Build / run

```bash
# Regenerate Xcode project after editing project.yml
xcodegen

# CLI harness (fastest feedback loop, no simulator)
swift run KanaKanjiHarness "kyou no meeting" --zenzai --weight weights/zenz-v3-small-Q5_K_M.gguf --out /tmp/out.json

# iOS build
xcodebuild -project BilingualKeyboard.xcodeproj -scheme KeyboardExtension \
  -destination 'generic/platform=iOS Simulator' build

# Or open in Xcode and Run.
```

The user has Xcode 26.4.1 + iOS 16+ simulators downloaded. Signing team is set
manually in Xcode (not in project.yml).

## Critical settings to know

- **C++ interop is required** for SwiftyMarisa (transitive dep of AzooKey under
  the Zenzai trait). `project.yml` sets:
  ```yaml
  SWIFT_CXX_INTEROPERABILITY_MODE: default
  CLANG_CXX_LANGUAGE_STANDARD: "gnu++17"
  CLANG_CXX_LIBRARY: libc++
  OTHER_SWIFT_FLAGS: -cxx-interoperability-mode=default -Xcc -std=gnu++17
  ```
  All four are needed — the `OTHER_SWIFT_FLAGS` line in particular was
  load-bearing for getting Clang's dependency scanner to find `<cstdio>` when
  compiling marisa-trie headers transitively.
- `Package.swift` declares `traits: ["Zenzai"]` on the AzooKey dep and
  `.interoperabilityMode(.Cxx)` on both `KeyboardCore` and `KanaKanjiHarness`
  swiftSettings.
- Zenzai `inferenceLimit: 5` (anything lower forces fallback before a kanji is
  found).

## Known limitations / likely next tasks

1. **Conversion quality is context-starved at sentence start.** Zenzai relies on
   `leftSideContext`, which is empty for the first phrase. Picks improve as the
   user keeps typing. Possible mitigation: warm with the host's
   `documentContextBeforeInput`.
2. **Candidate bar shows only the *first* Japanese span's candidates.**
   Multi-span ambiguity resolution is v0 — tapping a candidate replaces the
   first span only. If the user wants to disambiguate later spans, that flow
   doesn't exist yet.
3. **No long-press repeat, no popup magnifier on key press.** Native keyboards
   have these; we don't. `UIImpactFeedbackGenerator` covers haptics only.
4. **No memory pressure handling.** iOS keyboard extensions have a ~70-90 MB
   cap. Zenzai weight is 69 MB before runtime allocs. First launch on a real
   device may OOM — needs measurement. Right now Zenzai is bundled
   *unconditionally* if the .gguf is present in the extension's resources;
   consider gating by device class or making it a user toggle in the container
   app.
5. **Detector heuristic is still imperfect.** Coverage threshold (70%) is a
   guess. Expect false positives on rare romaji clusters and false negatives on
   English words that happen to parse as romaji (e.g. "kana"). Telemetry +
   hand-curated corrections would help.
6. **`textDidChange` reset is coarse.** It only resets context when the host
   field is fully empty. Cursor-move detection would be better — should diff
   `documentContextBeforeInput` against expected.
7. **Shift is sticky-toggle, not auto-revert.** A native keyboard reverts shift
   after one character; ours stays shifted until tapped again. Easy fix in
   `KeyboardView.toggleShift` / `rebuild`.

## Open questions for the user

- Do they want the bilingual detector to be tunable (e.g. an "always English"
  mode toggle), or stay fully automatic?
- Should the candidate bar show candidates for *all* Japanese spans
  (segmented), not just the first?
- Is Zenzai required for v1 ship, or is dictionary-only acceptable to keep
  binary size down?

## Pointers

- Web prototype reference behavior: see `README.md` for the original spec.
- AzooKey docs: https://github.com/azooKey/AzooKeyKanaKanjiConverter
- Zenzai weights: https://huggingface.co/Miwa-Keita/zenz-v3-small-gguf
