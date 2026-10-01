# Bikey

Bikey is an experimental bilingual iOS keyboard for people who constantly switch between Japanese and English.

I built it because my own typing often looks like this:

```text
kyounomeetingha3jini
korekara we can get in the car
```

A normal keyboard expects me to decide which language I am typing *before* I type it. Bikey tries to make that decision itself.

It detects Japanese romaji and English inside the same stream, converts only the Japanese spans into kana/kanji, and leaves the English alone.

## The idea

For a bilingual user, language switching is not always a conscious action.

You can be thinking in Japanese, insert an English noun, go back to Japanese, and then finish the sentence in English. Reaching for the globe key every time is a tiny interaction, but it happens constantly.

Bikey treats the raw input as a segmentation problem instead:

```text
raw keystrokes
      ↓
Japanese / English span detection
      ↓
Japanese spans → romaji → kana → kanji
English spans  → preserved
      ↓
one mixed-language sentence
```

## Why this got technically interesting

The hard case is not a clean sentence with spaces. It is deciding what something like:

```text
kyounomeetingha3jini
```

actually contains.

A naive rule-based detector breaks quickly because valid Japanese romaji and English share a lot of character patterns. A fully statistical splitter can also become too aggressive and split real English words into pieces that happen to look Japanese.

The current detector combines several signals:

- character-trigram language scores,
- kana parseability,
- common English word matches,
- Japanese particles and romaji patterns,
- impossible/rare consonant clusters,
- nearby-token context,
- a small document-level language prior.

For long no-space runs, a beam segmenter searches possible boundaries instead of greedily committing to the first plausible split.

## Example

```text
Input:
korekara we can get in the car

Detected:
[korekara] [we can get in the car]

Converted:
これから we can get in the car
```

The goal is not to perfectly classify language in the abstract. It is to make the keyboard behave the way a bilingual person expected when they typed the sentence.

## Architecture

```text
Sources/KeyboardCore/
├── BilingualSpanDetector   # Japanese / English classification
├── BeamSegmenter           # no-space segmentation
├── TrigramScorer           # lightweight language model
├── Romaji                  # romaji → kana
├── KanaKanjiAdapter        # AzooKey conversion
└── InputController         # live keyboard state

iOS/                        # keyboard extension + container app
tools/build-trigrams/       # builds the character-trigram model
Tests/                      # detector and conversion tests
```

There is also a small browser prototype in the repo for testing segmentation behavior without rebuilding the iOS extension.

## Trigram model

The language model here is deliberately small.

A build tool reads curated Japanese-romaji and English seed corpora and emits character-trigram probabilities used by both the Swift keyboard and the browser prototype.

```bash
swift run TrigramBuilder
```

This is not intended to be a general-purpose language model. It is just enough statistical signal to make ambiguous keyboard input easier to classify while keeping inference tiny and local.

## Running it

Generate the Xcode project:

```bash
xcodegen generate
open BilingualKeyboard.xcodeproj
```

You can also run the Swift package tests and conversion harness independently from the iOS app.

For quick experiments, open `index.html` and try inputs such as:

```text
hashiwowatarumaenitaberu
kyounomeetingha3jini
watashihaashitanomeetingniiku
korekara we can get in the car
```

---

Bikey is one of those projects where a very small UX annoyance led me surprisingly deep into language detection, tokenization, IME behavior, and search. I like it because the intelligence is mostly invisible when it works: you just type the sentence you were already thinking.
