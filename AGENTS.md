# Working on Sakina

This is an iPhone-first SwiftUI app (iOS 17+) with portable Swift packages and an
experimental Python recitation backend. Preserve the user's full requirements
in `KRAV.md`, actual verification in `STATUS.md`, and all source history.

The user owns only an iPhone and wants cloud Mac builds and eventual TestFlight
installation. This Linux environment has no Xcode or physical iPhone. Never
describe syntax checks or Linux tests as a verified native build. Do not claim
Tarteel parity or low heat without the corresponding measurements.

## Ownership and data

- `QuranCore`: validated references, calendar streaks, lossless tajweed parsing.
- `QuranData`: lazy canonical content and attributed tafsir retrieval.
- `QuranPractice`: strict assessment contracts and a separate pinned reference edition.
- `App`: SwiftUI, native audio and local persistence. One recitation AVPlayer.
- `backend`: experimental real Muaalem inference. Disabled in the normal app.

Keep reading text byte-for-byte. Never normalize Arabic used for display or
transfer model offsets onto a different text edition. Search normalization is
allowed on copies only. The Quran source has nested annotations and two Basmala
prefixes; unknown annotations fall back to the canonical reading edition.

All analysis is user-triggered. Do not upload recordings automatically. Keep
API credentials, signing material, cached weights and voice recordings out of Git.
The app must not require a monthly subscription. Server inference and Apple
distribution can still have operating costs; do not promise otherwise.

## Checks

```sh
swift test
python3 scripts/verify_content.py
python3 scripts/export_practice_references.py --verify
python3 scripts/verify_assets.py
python3 scripts/generate_project.py
python -W error::ResourceWarning -m unittest discover -s backend/tests -v
```

Backend tests require `backend/requirements-test.txt` and ffmpeg, without the
large model. Real inference requires the separate pinned dependencies and model
download described in `backend/README.md`. Contract tests with an injected
engine do not establish acoustic quality. Never put model weights in this repo.

On a Mac run `xcodebuild -project Sakina.xcodeproj -scheme Sakina -destination
'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`. Regenerate the
project whenever App Swift files or resource groups change. Local package products
are wired by `scripts/generate_project.py`; no external Swift dependencies.

Intended remote: private `AllCrow/koran-ios`. Creation was denied by the GitHub
integration (403) on 2026-10-24; do not claim upload success without checking the
remote's actual visibility and commit. Do not substitute an unrelated repository
or make source public. Preserve local Git commits and source backups meanwhile.
