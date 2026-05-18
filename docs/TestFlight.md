# TestFlight Prep

Use this when creating the first external beta in App Store Connect.

## Build Settings To Confirm

- Bundle ID: `com.core7.bikey`
- Extension Bundle ID: `com.core7.bikey.KeyboardExtension`
- Team: `4KS6YS23KT`
- Version: `0.1`
- Build: increment `CFBundleVersion` every upload.
- Minimum iOS version: `16.4`
- Open Access: disabled. The keyboard performs conversion on device and does not request network access.

## Beta App Description

Bikey is a bilingual Japanese-English keyboard for people who type mixed romaji, Japanese, and English in the same sentence. It detects Japanese and English spans, converts Japanese romaji to kana/kanji candidates, and keeps English words as English without manual keyboard switching.

## What To Test

- Add Bikey from iOS Settings.
- Type mixed inputs such as `kyouno meeting ha 3ji`, `korekara we can get in the car`, and `hashiwowatarumaenitaberu`.
- Check whether Japanese and English spans are detected correctly.
- Try fast typing, backspace, space, return, candidate selection, shift, and keyboard switching.
- Send feedback for wrong conversions, dropped characters, keyboard crashes, slow candidate updates, or confusing UI.

## Beta Review Notes

This is a custom keyboard extension. Open Access is disabled, and conversion runs on device. The container app exists to introduce the keyboard and direct testers to enable it in Settings.

Suggested test steps:
1. Install the app through TestFlight.
2. Open the app once.
3. Go to Settings > General > Keyboard > Keyboards > Add New Keyboard.
4. Select Bikey.
5. Open Notes or Messages, switch to Bikey, and type mixed Japanese-English romaji examples.

## App Privacy Draft

- Data collection: none.
- Tracking: no.
- Open Access: no.
- Network use from keyboard: no.
- User-entered text processing: on device.
