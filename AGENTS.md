# Working on Sakina

This is an iPhone-first SwiftUI app (iOS 17+) with portable Swift packages and an
experimental Python recitation backend. Preserve the user's full requirements
in `KRAV.md`, actual verification in `STATUS.md`, and all source history.

The user owns only an iPhone and wants cloud Mac builds and a personal native
installation. This Linux environment has no Xcode or physical iPhone. Never
describe syntax checks or Linux tests as a verified native build. Do not claim
Tarteel parity or low heat without the corresponding measurements.

Latest clarification: the user wants a local personal installation and explicitly
REJECTED a Safari/PWA rewrite. Preserve the native app. A separate CI job prepares
an unsigned physical-iPhone IPA for subsequent personal signing; this is distinct
from the simulator artifact and cannot be installed by tapping it in Files.
SideStore with an ordinary Apple account is a possible free route if a computer
can be borrowed for initial setup/recovery. That computer availability is not yet
confirmed. See `docs/PERSONAL_IPHONE_INSTALL.md`; no signing or device install is
verified, and never request passwords or pairing files in chat.

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
The scheme also contains hosted `AppTests` and `AppUITests`; use an actual
available iPhone simulator destination with `xcodebuild test`. See `STATUS.md`
for the exact latest tested source, run and counts. Mac CI uses Xcode16.4 and
an iOS18.5 simulator. Native suites cover AppStore, AudioLibrary, PracticeRecorder,
RecitationPlayer and text/search/navigation. Audio validation uses synthetic MPEG
frames; PCM player tests perform real muted playback of generated local WAVs.
OfflineMP3PlaybackTests also decode and play a generated quiet MP3 through
AudioLibrary with the system session enabled. Both use generated test content,
not reciter recordings. Combined main run 40165021106 passed 56 hosted tests
and five UI flows, including the four stronger near-top position assertions.
The resulting 2:255 image was inspected. See STATUS.md for the exact source.
Controlled download responses and permission callbacks do not establish real
network transfer, physical microphone behavior, audio routes or device energy.
The parent accessibility identifier had masked child buttons; do not put an
identifier on the entire verse Card again. Verse scroll IDs must include sura
and ayah, and the verse group must refresh when its sura changes. See
`docs/IOS_VERIFICATION.md` and current `STATUS.md`. Keep native and portable
results separate. UI tests use an isolated, Debug-only defaults suite. Debug
must keep `ONLY_ACTIVE_ARCH=YES` to match packages for a concrete simulator.

At accessibility XXXL, a SwiftUI labelled Toggle can expose the full row as its
switch frame. UI tests must reveal the full row and tap the actual trailing
control, retaining the value-change and relaunch assertions. Do not replace a
failing interaction with a defaults injection. Direct verse jumps use global
references, change reading position only, and must never award reading credit.
After a jump, later explicit reading/listening must win over the old bookmark.
Long variable-height suras exposed inaccurate prefix estimates in LazyVStack:
the real simulator landed at 2:203/240 for requested 2:255. Semantic targets
eventually exposed the right badge at the bottom while the previous verse
filled the screen. The reader now uses reusable native List rows with matching
global String data/row IDs and ScrollViewReader commands after dismissal.
Keep continuous reading and cell reuse. The four long-jump/relaunch/repeat/later
position assertions require the entire target badge near the viewport's top
within five seconds; mere existence or hittability is insufficient. Inspect
the resulting screenshots as well as test results. Actual latest verification
is recorded in STATUS.md; do not describe an unrun change as verified.

Apple requirements checked 2026-10-25 require Xcode26+/iOS26 SDK for App Store
Connect uploads since 2026-04-28. The verified Xcode16.4/iOS18.5 build is not
upload acceptance proof. Personal signing remains the current priority.

Reading backup import is additive and validated before mutation. Keep its
bounded file read, security-scoped/coordinated access and stale-request guard.
Never include voice, downloaded audio or credentials in the export. The owner
can retrieve successfully tested device packages from a GitHub release DRAFT;
the workflow must preserve `--draft` and require all verification jobs first.
An unsigned IPA still requires personal signing and device provisioning.

Practice and reading share chapter selection, so hidden practice callbacks must
never delete a valid take or stop the reader's audio. Preserve the take's exact
reference and Basmala choice on tab changes. Only explicit practice selection or
recording/deletion actions can replace it. Foreground downloads and own-voice
playback/recording stop on background; recitation can continue with native controls.

The user created `AllCrow/Koran-test-` and explicitly authorized it to remain
PUBLIC for now on 2026-10-25, overriding the earlier private-only instruction
for this repository. The designated remote is
`https://github.com/AllCrow/Koran-test-.git`. Preserve all existing Git history.
Verify remote commits and actual CI outcomes before claiming upload/build success.
The previous attempt to create private `AllCrow/koran-ios` was denied (403),
and changing repository visibility is also denied to this integration. A later
switch to private must be performed by the owner or an authorized connection.
