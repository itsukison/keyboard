# Keyboard Conversion Prototype

This workspace contains two layers:

- `index.html` / `app.js` / `styles.css`: browser UX simulator for bilingual romaji detection, no-space mixed-run segmentation, and candidate UI.
- `Package.swift` / `Sources/KanaKanjiHarness`: SwiftPM harness for validating AzooKeyKanaKanjiConverter as the real iOS kana-kanji engine.

## Run the Browser Prototype

Open `index.html` in a browser. Useful cases:

- `hashiwowatarumaenitaberu`
- `kyounomeetingha3jini`
- `watashihaashitanomeetingniiku`
- `korekara we can get in the car`

## Run the Native Harness

```sh
swift run KanaKanjiHarness
```

You can also pass custom cases:

```sh
swift run KanaKanjiHarness kyounomeetingha3jini hashi hana kaeru
```

The harness prints JSON containing:

- detected spans
- kana sent to AzooKey
- top candidates
- main candidate
- cold-start latency
- per-request latency

## Current Native Build Note

SwiftPM successfully fetched `AzooKeyKanaKanjiConverter`, but this machine's installed Command Line Tools SDK is missing `CoreFoundation/CFStringTokenizer.h`, so native compilation cannot complete until the Apple toolchain is repaired or full Xcode is installed/selected.
# keyboard
