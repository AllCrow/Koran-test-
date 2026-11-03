# Återgranskning av läsförbättringarnas PR-körning 73

Granskad 2026-11-03 från Windows. Detta bevarar observerade resultat från
den tidigare molnkörningen; det är ingen ny lokal Xcode- eller iPhone-körning.

## Källa och körning

- [PR #15](https://github.com/AllCrow/Koran-test-/pull/15).
- [Körning 40440076201, nummer 73, försök 1](https://github.com/AllCrow/Koran-test-/actions/runs/40440076201), avslutad med `success` 2026-10-27 03:13:56 UTC.
- Kandidat: `32f09bb709897400930a8ad2956e138bff4c2bc8`.
- Faktisk PR-checkout: `52c99c1a8f23afcebe9edc95f9a81ffdb4ddb14a`.
- Båda har komplett Git-träd `6b585620301ce6272c4fd4383cc100d07c94aaa4`; kontrollerat med `git rev-parse` och tom fullträdsdiff.

## Lästa originalresultat

| Jobb | Resultat |
| --- | --- |
| [121978058138, iPhone16Pro / iOS18.5 / Xcode26.2](https://github.com/AllCrow/Koran-test-/actions/runs/40440076201/job/121978058138) | 150 hostade +19 UI, noll fel; 106 portabla Mac-fall; simulatorbygg och projekt-/innehållskontroller godkända. |
| [121978058212, iPhone16e / iOS26.2 / Xcode26.2](https://github.com/AllCrow/Koran-test-/actions/runs/40440076201/job/121978058212) | 150 hostade +19 UI, noll fel; 106 portabla Mac-fall; simulatorbygg och projekt-/innehållskontroller godkända. |
| [121978058257, iPhoneSE3 / iOS18.5 / Xcode16.4](https://github.com/AllCrow/Koran-test-/actions/runs/40440076201/job/121978058257) | 150 hostade +19 UI, noll fel; 106 portabla Mac-fall; simulatorbygg och projekt-/innehållskontroller godkända. |
| [121978057897, backend](https://github.com/AllCrow/Koran-test-/actions/runs/40440076201/job/121978057897) | `Ran 57 tests`, `OK`; installation från Ubuntus officiella spegel och ffmpeg-avkodning passerade. |
| [121978058143, iPhoneOS-paket](https://github.com/AllCrow/Koran-test-/actions/runs/40440076201/job/121978058143) | Releasebygg och paketeringskontroll godkända; osignerad IPA skapad. |

169 unika native/UI-fall ger507 exekveringar över tre konfigurationer.
De19 UI-fallen består av tolv oförändrade äldre fall och sju nya läsflöden.
106/106-raderna hör till den portabla XCTest-sviten; den efterföljande
Swift Testing-raden med noll fall är en separat tom testmotor.
Inga markörer för omstart efter oväntat avslut hittades i de tre loggarna.

iOS26-loggen har168 obrutna individuella passrader. Det återstående fallet,
`RecitationPlayerTests.testMediaServicesLossWhileStoppedDefersNewSelectionsUntilReset`,
har sin passrad delad av ett native-stderrmeddelande vid02:51:25 UTC.
Båda ursprungliga fragmenten finns kvar i råloggen. Svitsummeringen anger
150 hostade fall, noll fel, och det efterföljande UI-jobbet körde19/19.
Ingen rålogg har reparerats för att få ett matchande antal.

## Loggidentitet

Originalens loggsvar är sparade lokalt under `work/pr15-review/`, utanför
Git. SHA256 för de faktiskt sparade filerna:

| Jobb | SHA256 |
| --- | --- |
| 121978058138 | `d41b4104977183098cd21e1182999a1839d7096600e3278f82f8deddcb252e00` |
| 121978058212 | `e0aa4906a47a08507b51cec66a493f00fd1d81c04f9a6fa0742e49bf5a1f0e95` |
| 121978058257 | `30c02488d803d5452b5f3d74c801dbd616b809ae3acb245d6e83f9b651302cf8` |
| 121978057897 | `b0518c7da51c10336add08c2727dbd48bb46333bcef35d23569e8a8d003bc487` |
| 121978058143 | `85aacf3e5dc40c93e6c13747f9ce1f269474c60b6852b814db0f2cbd7c514bbf` |

## Granskning och gränser

Källgranskningen omfattade läsarens native-radregistrering och generations-
skydd, fördröjd positionslagring och företräde för uttryckliga val,
avbruten/begränsad sökning, exakt källtext i sökträffar, rapportens Unicode-
och exportschema samt verkliga UI-interaktioner och befintliga tidsbudgetar.
Ingen blockerande källändring identifierades. Korpus, ljudtjänster och äldre
UI-testfiler är byteidentiska med huvudgrenens version.

Körningens artifacts-lista var tom vid återkontrollen. Sjudagarsbilagorna
är utgångna; IPA, xcresult och skärmbilder har inte hämtats eller visuellt
granskats på nytt. Inget paket-SHA eller ny självständig paketkontroll
påstås för bygge73. `save-personal-download` var `skipped` enligt PR-villkoret.
En ny huvudkörning ska ge färska bilagor och ett ägarutkast efter integration.

Personlig signering/installation, fysisk mikrofon/radio, Filer-leverantörer,
VoiceOver och energi återstår. Analys är avstängd; ingen ny inferens,
sakkunnig kvalitetsbedömning eller Tarteel-paritet följer av resultaten.
De tidigare underkända körningarna bevaras i STATUS.md.
