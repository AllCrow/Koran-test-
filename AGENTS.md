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
can be borrowed for initial setup/recovery. The user expects access to a computer later; the computer platform is not yet
confirmed. See `docs/PERSONAL_IPHONE_INSTALL.md`; no signing or device install is
verified, and never request passwords or pairing files in chat.

## Latest offline-quality verification

Main run 40192974053 passed on e1bb2625136277beb8f4eab78f17576acc3d56e5: 96 hosted and eight UI cases
on each of three simulator configurations, 85 portable Mac cases per variant
and 57 backend cases, including 21 evaluation tool cases. These are 104 unique
native/UI cases and 312 executions. Draft personal-build-53-1 is independently
checked. See STATUS.md and docs/OFFLINE_QUALITY_2026-10-25.md. Actual PR checkout
6897dba0e03072d18c79e14a74d165d5c219232b has the same complete Git tree as this main source.

Keep downloads explicit and foreground-only. A failed storage setup must allow
a later explicit retry in the same library. Prepare protection/identity before
publication at the final verse filename; no fallible metadata step follows that
move. Preserve completed bytes on failure. Cancellation and stale generation
checks must prevent old responses from installing files or clearing newer jobs.

Revalidate the current tafsir root before filesystem access and after network
suspension. Recover a removed root without restarting the repository; never use
a replacement symlink for reads, recency writes or pruning. Keep 64 entries,
4MiB total/128KiB per disk entry, exact source text and valid online fallback.

backend.evaluation is an offline development tool, not a production analysis
dependency. Exact kind/category/scalar matching and one-to-one assignment measure
indication localization only. Pending/inconclusive cases are not truth; synthetic
fixtures never publish quality metrics. Retain reference/model/audio binding,
bounded strict JSON, missing/abstention denominators and null results without
adjudicated material. Never infer Tarteel parity from the tool's tests.

Historical main51 passed on c907121e59eab81ae8848e2ca0311ab54f2aa6ec with
91 hosted/eight UI, 82 Mac and 36 backend cases. Its separate actual EveryAyah
source audit was not rerun against the current changed AudioLibrary. Keep that
audit as historical evidence, outside new 104/312 counts and current-source
claims. Older builds and all source history remain preserved.

Keep chapter loads transactional. Cancellation preserves the last settled chapter,
selection, error and saved bytes. A stale request must not clear newer progress.
Retain a valid immutable index after Task cancellation checks even if a newer
chapter generation superseded cold start; only chapter/progress settlement is
generation-dependent. Preserve real failed targets for explicit retry.

Reading imports must serialize and bound BOTH proposed persisted state and export
before publishing or writing. Retain the default4MiB limit and zero-mutation
rejection. The lower internal budget seam exercises the same admission/read/write
paths for exact-boundary native tests; never raise the production bound in tests.

Media-service loss must quiesce the native player immediately, invalidate old
callbacks and keep exact selection. Do not construct/load replacement media until
reset, and never resume automatically. Simulated notifications do not establish
physical-device audio, microphone or energy behavior.

Native MP3 interruption probes must observe before commands and prove positive
current native rate plus playing before each interruption, including after
explicit resume. KVO is a wakeup to inspect current getters on the actor, not
a buffered acknowledgement. Keep2s, real3sMP3, noEOF, clock<2.5, native0+paused,
same-item/asset and explicit-resume requirements; retain bounded failure traces.
Read reader-position bounds/target from one coherent native snapshot, retaining
5s, full finite bounds, unique exact reference/label and foreground. The separate
fresh-application-object alternative is preserved history, not adopted code.

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

`docs/CONTENT_RIGHTS.md` separates explicit text grants from unresolved tafsir/
EveryAyah rights. The opt-in `scripts/audit_recitation_sources.py` downloads
only its fixed public references, verifies publisher checksums and decodes whole
files locally. It does not run in the app or normal CI. Keep audio out of Git.
Its Linux evidence does not establish iOS playback, religious correctness,
rights clearance or word timings. Do not transfer AlQuran Cloud's audio grant
to EveryAyah's different files. Do not classify 112:2's model indication from
successful MP3 decoding alone.

## Checks

### Parallel work and a stable delivery candidate

Stage new app, test and workflow work on feature branches while the current
native verification finishes. Read its actual results before integrating a new
candidate into main. Repeated small main pushes have cancelled runs 35–38
before a complete result; keep independent implementation/review moving on a
branch instead of continually replacing the candidate under test. A reproduced
failure in that candidate is a concrete reason to replace it with a fix.
The user already authorized continued work and integration; this does not
require routine owner confirmation. Preserve already-integrated work and all
history. Do not reset main to enforce the process. For a result-only Markdown
commit, verify that executable/test/build inputs match the tested source and
avoid starting an unnecessary native rerun. Cancelled obsolete runs are neither
passing evidence nor an instruction to rerun old code.

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
for the exact latest tested source, run and counts. Mac CI selects Xcode26.2/
iOS18.5 on iPhone16Pro, Xcode16.4/iOS18.5 on compact iPhoneSE3, and
Xcode26.2/iOS26.2 on iPhone16e. The first job specifically verifies a build
linked to the current SDK on the earlier operating-system runtime.
The physical unsigned package uses Xcode26.2. Configuration is not a passing run;
read the actual jobs/results before claiming compatibility. Native suites cover AppStore, AudioLibrary, PracticeRecorder,
RecitationPlayer and text/search/navigation. Audio validation uses synthetic MPEG
frames; PCM player tests perform real muted playback of generated local WAVs.
OfflineMP3PlaybackTests also decode and play a generated quiet MP3 through
AudioLibrary with the system session enabled. Both use generated test content,
not reciter recordings. The verified PR candidate passed 80 hosted tests and
eight UI flows on each of three simulator variants, with 82 portable Mac tests
and 36 backend tests. Main run 40176707574 passed all six jobs for the
byte-identical integrated source 8cd977c4f2063e51784cc0b7c3fbca75b1760ec3,
including the gated owner draft personal-build-46-1. Read STATUS.md for
precise evidence and remaining physical-device limits. Do not reuse the older 56 + five historical counts.
The five AudioDownloadTransportTests exercise actual URLSessionDownloadTask over
loopback HTTP, including advertised/chunked over-limit bodies that remain open.
Keep the delegate bridge, lock order and temporary-file ownership: the earlier
async per-task delegate did not receive live progress and failed both size tests.
Loopback HTTP does not establish external TLS/EveryAyah content or physical-device
network behavior. Permission callbacks do not establish physical microphone
behavior, audio routes or device energy.
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
within five seconds, horizontally contained, with the app in the foreground.
For this read-only badge use geometry and exact global identity; iOS26 may
report no activation point for readable noninteractive text. Interactive controls
still require hittability and real taps. Mere existence is insufficient. Inspect
the resulting screenshots as well as test results. Actual latest verification
is recorded in STATUS.md; do not describe an unrun change as verified.

Apple requirements checked 2026-10-25 require Xcode26+/iOS26 SDK for App Store
Connect uploads since 2026-04-28. Successful SDK26.2 builds are not upload
acceptance proof. Personal signing remains the current priority.

ArabicText's selectable base size comes from EnvironmentValues.quranTextSize;
retain Dynamic Type scaling. Persist a raw optional size string so old reading
states and unknown future choices do not discard progress. Reading-data imports
must preserve the current text size and system/light/dark appearance choice.
The night UI test must select the real persisted appearance setting: the earlier
AppleInterfaceStyle launch argument produced light screenshots despite passing.
Inspect real screenshots before claiming dark rendering. Primary button text
uses Palette.onGreen, contrasting with both light and dark brand fills.
Tajweed display hues have cached variants
for light/dark and Increased Contrast; do not edit the source colorHex values.

Tafsir caches only recently opened, validated explanations: 64 entries, 4MiB
total, 128KiB per versioned file. Revalidate source/edition/global/reference on
disk reads, preserve raw UTF-8, keep IO off the UI actor, and exclude this cache
from backups. Never follow cache symlinks, including metadata/recency writes.
This does not make the full tafsir available offline. New explanations need
internet. Cache failure must not suppress a valid online explanation.

Detailed reading marks retain at most seven civil labels, with today taking
priority and nearby future labels retained through backward clock/timezone
corrections. Future labels never count toward today's goal. Recent history uses
earned completion and known unique marks, not today's goal applied to the past.

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

Native AVPlayer pause intent must survive late rate/timeControlStatus changes.
Observe both with current-item/generation guards; pause only if native rate is
nonzero to avoid callback loops. Tests must wake on the main queue and re-read
current native getters, rather than assert against a cached CombineLatest pair.
Keep both actual MP3 interruption/route checks and the dedicated late-native-
start WAV regression, bounded latency, no-EOF, same-resource and explicit-resume
assertions. Do not replace native engine checks with published application flags.

PR7 merged as d6d73e5 after run40176541522 passed on cba9f3e. All three
variants executed 80 hosted and eight UI cases, with 82 portable cases;
36 backend cases and both builds passed. Actual checkout53719af has the same
tree as cba9f3e; merged executable/test/build/workflow inputs match it, with
Markdown-only differences. HostedTests.xcresult and UITestResults.xcresult
were both inspected in artifact12593107496. Preserve the hosted-success gate
before UI and both result bundles. Main46's owner draft remains the tested
app package; the workflow change does not alter its application code.

Later PR8 is merged as c907121. CI50 on 0d85b19 actually passed 91 hosted
and eight UI cases on each of all three variants, 82 portable cases per Mac,
36 backend cases and both builds. Actual checkout7d29ca2 and mainc907121
have the same tree188fe37. The coherent native-snapshot position helper
preserves all five-second bounds and real interactive controls. MP3 probes
observe before commands, establish real native playback and retain the
two-second pause/no-EOF/same-item requirements. Do not revert to stale
application handles, app-only playing flags or cached KVO tuples.

The separate opt-in real-source workflow passed three cases on iPhone16e/
iOS26.2: 12 actual EveryAyah files downloaded and fully decoded; pinned112:2
played locally to native EOF for each reciter. Read docs/LIVE_RECITATION_AUDIT.md
and its saved JSON evidence. Verification/EveryAyahLiveSourceTests.swift stays
outside AppTests; staging adds it only in the isolated audit checkout, so
normal CI remains deterministic. No audio is attached or committed. This is
one simulator configuration, no physical/offline-radio/rights/expert proof.
Main51 subsequently passed all six jobs and saved the verified owner draft51.
Read STATUS.md for that actual result; build46 remains historical.
The independently downloaded build51 artifact, all three release assets and
239 packaged source resources are bound in docs/evidence/delivery-51-2026-10-25.json.
These checks establish package provenance, not personal signing or physical behavior.
