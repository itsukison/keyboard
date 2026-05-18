# Bilingual Keyboard

A custom iOS keyboard that lets a Japanese-English bilingual user type mixed romaji sentences (e.g. `kyounomeetingha3jini`, `korekara we can get in the car`) without manually switching between language modes. The keyboard auto-detects which spans are Japanese (→ kana → kanji) and which are English, even inside a no-space chunk.

## Layers

- **`index.html` / `app.js` / `styles.css` / `trigrams-data.js`** — browser UX simulator for bilingual romaji detection, no-space mixed-run segmentation, and candidate UI. Shares the same trigram model file as the Swift library.
- **`Sources/KeyboardCore/`** — SwiftPM library: `BilingualSpanDetector`, `BeamSegmenter`, `TrigramScorer`, `Romaji`, `KanaKanjiAdapter` (AzooKey wrapper with optional Zenzai), `InputController` (running left-side context, live conversion). The bundled `Resources/trigrams.json` is a character-trigram language model used by the segmenter.
- **`Sources/KanaKanjiHarness/`** — CLI executable: validates `KeyboardCore` end-to-end and prints latency/candidate metrics.
- **`Sources/TrigramProbe/`** — debugging executable: dumps trigram log-probs, beam decisions, and detector spans for ad-hoc inputs.
- **`tools/build-trigrams/`** — `TrigramBuilder` executable. Reads `data/ja-romaji.txt` + `data/en-words.txt`, emits both `Sources/KeyboardCore/Resources/trigrams.json` and `trigrams-data.js`. Re-run with `swift run TrigramBuilder` when the seed corpora change.
- **`iOS/`** — UIKit keyboard extension + container app (Swift sources only; the Xcode project is generated from `project.yml` via XcodeGen).

## Language classifier (`BilingualSpanDetector`)

The detector layers three signals on top of one structural invariant:

**Structural invariant.** A single whitespace-delimited token represents one language. The only allowed internal split is at the boundary of a *known English dictionary word* of length ≥ 4 — the existing greedy `preSplit` scan. Pure trigram-driven splits inside a word are forbidden because they produce artefacts like `type → ty + pe → tyぺ`.

**Per-piece classification.** Once `preSplit` returns a piece, `score(piece:)` combines:
1. A character-trigram log-probability model (`TrigramScorer`) trained offline on a curated JA-romaji + EN seed corpus, scaled and added to the JA/EN running score. Skipped for tokens of length ≤ 2 where a single unseen trigram is too noisy.
2. The legacy heuristics: kana parseability, impossible-in-JA consonant clusters (`str`, `spl`, `ght`, …), particles, loanword hints, English contractions, capitalization, etc.
3. Neighbor smoothing in `smooth(tokens:)` — left/right 2-token window plus a document-level `LanguagePrior` for ambiguous tokens.

**Long-run prior.** Runs of ≥ 8 lowercase chars with no embedded EN dictionary match are virtually always Japanese romaji (`hashiwowatarumaenitaberu`, `watashihaashitano…`); the existing `if clean.count >= 8 && !englishHit { ja += 1.7 }` rule encodes this.

**Trigram corpus.** To extend the model, edit `tools/build-trigrams/data/*.txt` (one token per line, optional `\tweight` suffix) and re-run `swift run TrigramBuilder`. The output is ~75 KB and is bundled into the keyboard extension at compile time.

## Romaji table (`Romaji.swift`)

Covers the standard gojuuon + dakuten + handakuten + yoon rows plus Mozc/AzooKey-compatible extensions:
- Small characters via `x-` / `l-` prefix: `xa`/`la` → ぁ, `xi`/`li` → ぃ, `xtu`/`ltu`/`xtsu`/`ltsu` → っ, `xya`/`lya` → ゃ, `xwa`/`lwa` → ゎ, `xka`/`lka` → ヵ, `xke`/`lke` → ヶ, `xn` → ん
- v row: `va` → ゔぁ, `vu` → ゔ, `vya` → ゔゃ, etc.
- Foreign-sound extensions: `tsa`/`tsi`/`tse`/`tso`, `tha`/`thi`/…/`tho`, `dha`/…/`dho`, `twa`/…/`two`, `dwa`/…/`dwo`, `she`/`che`/`je`, `sye`/`zye`/`jye`/`cye`
- f / w / k / g / q extensions: `fwa`, `wha`, `kwa`, `gwa`, `qwa`, `kye`, `gye`, `wyi`, `wye`
- -e yoon: `nye`, `hye`, `bye`, `pye`, `mye`, `rye`

The matcher walks 4→3→2→1 chars per position so 4-char patterns like `xtsu` resolve correctly.

## AzooKey typo correction

`KanaKanjiAdapter` explicitly sets `needTypoCorrection: false` in `ConvertRequestOptions`. AzooKey's default direct-input typo table swaps dakuten pairs (ト ↔ ド, タ ↔ ダ, テ ↔ デ, …) which would re-introduce errors after our own romaji→kana conversion. Keep this disabled unless you start feeding raw `.roman2kana` keystrokes.

## Run the Browser Prototype

Open `index.html` in a browser. Useful cases:

- `hashiwowatarumaenitaberu`
- `kyounomeetingha3jini`
- `watashihaashitanomeetingniiku`
- `korekara we can get in the car`

## Run the Native Harness

AzooKey writes verbose debug logs to stdout, so the harness prefers writing its JSON report to a file via `--out`:

```sh
# Dictionary-only conversion (no neural reranker)
swift run KanaKanjiHarness --out /tmp/harness.json

# With Zenzai (neural reranker, context-aware) — requires the GGUF weight file
swift run KanaKanjiHarness --zenzai --out /tmp/harness.json
```

You can also pass custom cases:

```sh
swift run KanaKanjiHarness --zenzai --out /tmp/harness.json kyounomeetingha3jini hashi
```

Flags:
- `--out <path>`: write the JSON report to a file (avoids stdout interleaving with engine logs).
- `--zenzai`: enable Zenzai neural reranking with left-side context. Defaults to looking for `weights/zenz-v3-small-Q5_K_M.gguf`; override with `--weight <path>`.
- `--weight <path>`: path to the Zenzai GGUF model. Implies `--zenzai`-style usage when provided alongside `--zenzai`.

The report contains, per case:
- detected spans (JA/EN classification + kana for JA spans)
- kana sent to AzooKey, plus the running left-side context (`contextPassed`)
- top-N candidates (N = 10) and the chosen main candidate
- cold-start latency and per-request latency

### Performance (M-series Mac, debug build)

| Mode            | Cold start | Per-span latency |
|-----------------|-----------|------------------|
| Dictionary-only | ~30 ms    | 25–100 ms        |
| Zenzai (v3, GPU)| ~40 ms    | 90–400 ms        |

### Zenzai weights

The Zenzai trait pulls in `llama.cpp` (Metal/CUDA backend) and `SwiftyMarisa`. Download the model once:

```sh
mkdir -p weights
curl -L -o weights/zenz-v3-small-Q5_K_M.gguf \
  https://huggingface.co/Miwa-Keita/zenz-v3-small-gguf/resolve/main/ggml-model-Q5_K_M.gguf
```

`weights/*.gguf` is gitignored.

## Build the iOS Keyboard

The iOS keyboard extension and container app are defined in `iOS/` plus `project.yml`. The Xcode project itself is generated from those (and gitignored) — there is no committed `.xcodeproj`.

### One-time setup

1. **Install Xcode** (full Xcode from the Mac App Store, ~12 GB). Command Line Tools alone cannot build iOS targets. *This step requires you — there is no CLI bypass.*
2. **Install XcodeGen** (generates `BilingualKeyboard.xcodeproj` from `project.yml`):
   ```sh
   brew install xcodegen
   ```
3. (Optional but recommended for live conversion) Make sure `weights/zenz-v3-small-Q5_K_M.gguf` exists — see *Zenzai weights* above.

### Generate and open the project

```sh
xcodegen generate
open BilingualKeyboard.xcodeproj
```

In Xcode:
1. Select the `BilingualKeyboard` target → **Signing & Capabilities** → set your team. Repeat for the `KeyboardExtension` target.
2. Build & run on simulator or device.
3. On device/simulator: **Settings → General → Keyboard → Keyboards → Add New Keyboard…** → **Bikey**.
4. In any text field, tap the 🌐 globe icon to switch to it.

### Known limitations / TODOs

- **Memory budget.** iOS keyboard extensions are limited to ~70–90 MB. Loading AzooKey's default dictionary plus a 69 MB GGUF may exceed that on older devices. If the extension is killed by jetsam, use a smaller GGUF quant or fall back to dictionary-only on-device.
- **Open Access.** Disabled (`RequestsOpenAccess: false`). All conversion is on-device. Don't enable unless we add a feature that genuinely needs it (network, paste, etc.) — open access is a privacy red flag for users.
- **Document context.** v0 detects "fresh document" by checking if `documentContextBeforeInput` is empty. A real implementation should diff cursor moves and treat each new run separately for `leftSideContext`.
- **Candidate selection** currently only swaps the *first* Japanese span's main candidate. Multi-span resolution UI is a v1 feature.
