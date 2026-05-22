# Autocorrect, Classification, and Context Logic

This note documents the current English/Japanese classification and autocorrect flow, plus the edge-case fix added for `arrive` and `一緒に go to`.

## What Changed

The latest fix separates two different problems that looked similar on the surface:

- Common English words that are kana-complete, such as `arrive`, should stay English when typed as standalone alphabet words.
- A literal space after already-converted Japanese text should be treated as strong intent to start an English island, so `一緒に go to` should not become `一緒に ご と`.

Implemented changes:

- Added `arrive` to `BilingualSpanDetector.defaultEnglishWords`.
- Added `arrive`, `arrives`, `arrived`, and `arriving` to `tools/build-trigrams/data/en-words.txt`.
- Regenerated `Sources/KeyboardCore/Resources/trigrams.json` and `trigrams-data.js`.
- Added `BilingualLanguageClassifier.hasPostJapaneseEnglishIsland(before:)`, which detects actual Japanese script followed by a space and ASCII word context.
- Added classifier and composer tests for `arrive`, `一緒に go`, `一緒に go to`, and the guardrail `watashi no`.

Important distinction:

- `watashi no` is raw romaji context, so it still uses the normal Japanese/English smoothing rules and can become `の`.
- `今日は no` or `一緒に go` has actual Japanese script plus a typed space, so the next exact English word is protected as English.

## Language Classification Pipeline

The core detector is `BilingualSpanDetector` in `Sources/KeyboardCore`.

The main invariant is:

- One whitespace-delimited token usually represents one language.
- The only internal split is at a known embedded English dictionary word of sufficient length, for cases like `kyounomeetingha3jini`.
- Pure trigram-only internal splits are intentionally forbidden because they create artifacts like `type -> ty + pe`.

For each piece, the detector scores Japanese and English:

- Embedded English dictionary matches get a strong English boost and cannot be flipped by smoothing.
- Trigram scoring runs for tokens of length 3 or more. Positive trigram diff helps Japanese; negative diff helps English.
- Kana-complete tokens receive Japanese points.
- Kana-incomplete tokens receive English points.
- Long kana-complete tokens of length 8 or more receive a Japanese long-run prior unless they are exact English hits.
- Exact English dictionary hits receive English points. For length 4 or more, the English boost is intentionally strong enough to beat many kana-complete readings.
- Uppercase, apostrophes, impossible Japanese consonant clusters, and English suffixes such as `ing`, `ed`, `ly` can increase the English score.
- Japanese particles, Japanese-looking bigrams, strong Japanese verb endings, loanword hints, and doubled consonants can increase the Japanese score.

Final classification defaults to Japanese unless English wins clearly:

- English only wins when `ja - en <= -1.1` and `en >= 1.4`.
- This keeps the keyboard Japanese-friendly on ambiguous romaji.

## Context-Aware Logic

The app-facing wrapper is `BilingualLanguageClassifier` in `Sources/EnglishKeyboardCore`.

It adds context around the core detector in four ways:

1. Empty-context prior

When there is no context, the wrapper passes a mild English prior. This helps standalone short English tokens such as `to`, `we`, and `no`.

2. Document prior

The wrapper scans the last 80 characters of `contextBefore`:

- At least 2 Japanese scalars gives a Japanese prior.
- At least 8 ASCII letters gives an English prior.
- Otherwise the prior is neutral.

This prior only nudges ambiguous detector tokens. It should not override strong exact dictionary hits or strong kana signals.

3. Raw context window

The wrapper collects up to 2 trailing convertible words from the context, where convertible means ASCII letters, numbers, apostrophe, or hyphen.

It then detects the window plus the active token, and returns only the active token's spans. This lets examples like `korekara we` use `korekara` as context while still deleting/replacing only `we`.

4. Post-Japanese English island

Before running the detector, the wrapper checks:

- The active token is an exact English word.
- The latest Japanese scalar in `contextBefore` is followed by at least one whitespace character.
- Everything after that Japanese scalar is whitespace or ASCII word context.

If all are true, the token is returned as English immediately.

This handles:

- `一緒に ` + `go` -> English
- `一緒に go ` + `to` -> English
- `今日は ` + `no` -> English

It does not handle raw romaji as an English island:

- `watashi ` + `no` still goes through normal smoothing and can be Japanese.

There is also a narrow protection rule for short standalone English words:

- `be`, `he`, `me`, and `we` are protected when context-window detection would otherwise classify them as Japanese, as long as they are exact English words.

## Composer and UI Flow

`BilingualComposer` is the conversion layer used by the keyboard UI.

On space or suggestion refresh:

- It finds the trailing convertible token.
- It checks user dictionary entries first.
- It passes the token and `contextBeforeToken` into `BilingualLanguageClassifier`.
- If no Japanese span exists, it returns no Japanese commit or Japanese suggestions.
- If Japanese spans exist, it converts each Japanese span from kana to candidates.
- English spans are preserved verbatim inside mixed replacements.
- Japanese conversion receives `japaneseOnlySuffix(from:)` as left-side context, which strips the recent context down to Japanese kana/kanji scalars.

Display preview uses a separate Japanese-heavy classifier with embedded English minimum length 5. This avoids aggressive short English splits in preview while still showing live kana for likely Japanese.

In `KeyboardViewController`:

- `handleSpaceAction()` first attempts Japanese commit in Japanese-heavy mode.
- It then checks double-space period.
- It then attempts normal Japanese commit.
- It finally applies native English autocorrect if there is a valid top correction.
- If none of those apply, it inserts a literal space.

Suggestion refresh:

- Skips all autocorrect work if autocorrection is disabled, there is selected text, or the user just confirmed Keep.
- Computes the Japanese-heavy preview title.
- Requests Japanese suggestions if a Japanese span is detected or Japanese-heavy preview exists.
- Otherwise falls back to English suggestions from `UITextChecker`.

## English Autocorrect Gate

Native English autocorrect uses `UITextChecker` plus `EnglishAutocorrectGate`.

Eligibility comes from `NativeKeyboardPolicy`:

- Autocorrection is allowed for prose and web search.
- It is disabled for URL, email, numeric, and phone contexts.

For English correction:

- The trailing English word is ASCII letters plus apostrophe or hyphen.
- `UITextChecker` decides whether it is misspelled.
- The supplementary user lexicon can mark a word valid.
- Guesses and completions are deduped and shown as suggestions.
- A top correction is automatically applied only if the typed word is invalid, capitalization is not manually intentional, and edit distance is within the gate.

Edit distance gate:

- Typed length less than 6 allows distance 1.
- Typed length 6 or more allows distance 2.
- Adjacent transposition counts as one edit.

Manual capitalization gate:

- If the user typed uppercase manually, autocorrection is suppressed.
- Auto-capitalization at sentence or word starts does not count as manual capitalization.

Double-space period:

- Only applies when autocorrection is allowed.
- Requires exactly one trailing space after an ASCII letter or number.
- Suppressed after sentence terminators, newlines, and already-double spaces.

## Edge-Case Principles

When adding future fixes, prefer adding the narrowest signal at the right layer:

- Word commonness belongs in the English word list and trigram seed corpus.
- Explicit user spacing after actual Japanese script belongs in `BilingualLanguageClassifier`, because it is host-context intent rather than romaji evidence.
- Kana parsing behavior belongs in `BilingualSpanDetector`.
- English typo correction belongs in `KeyboardViewController` and `EnglishAutocorrectGate`.
- User dictionary overrides should remain above automatic classification.

Avoid globally weakening kana-complete Japanese scoring. It protects core Japanese behavior such as `hashi`, `korekara`, `kyou`, and long no-space Japanese romaji runs.
