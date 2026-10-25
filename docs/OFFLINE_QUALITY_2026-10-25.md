# Offlineåterhämtning och tajweedutvärdering

Denna omgång följer användarens beslut att färdigställa de förbättringar som går
att verifiera i molnmiljön. Den tidigare godkända appen och hela Git-historiken
bevaras. Ingen fysisk iPhone eller sakkunnig tajweedgranskning finns tillgänglig.

## Avgränsade ändringar

- **Ljudlagring:** ett misslyckat skapande av lagringsmappen låser inte längre
  samma appsession. Ett uttryckligt nytt nedladdningsförsök försöker förbereda
  lagringen igen. Ingen automatisk återhämtning startar nättrafik.
- **Publicering av ljud:** filskydd och filidentitet förbereds före flytt eller
  ersättning till versens slutliga filnamn. Ingen fallibel metadataoperation
  återstår efter den flytten. Tidigare färdiga verser ska bevaras vid fel.
- **Tafsir:** en försvunnen cachemapp kan återskapas utan en ny repository-instans.
  Mappens aktuella typ kontrolleras vid diskåtkomst och efter nätverksväntan.
  En ersättande symbolisk länk används inte för läsning, skrivning eller
  kvotstädning. Giltig online-text visas även när cachen inte kan användas.
- **Tajweed:** ett separat [offlineverktyg](TAJWEED_EVALUATION.md) jämför deklarerade,
  sakkunnigt avgjorda fel med sparade modellindikationer. Det binder exakt
  ljudhash, referenstext och modellrevision. Ogranskade fall får inget resultat
  för träffsäkerhet. Matchningen mäter felklass och plats; den avgör inte att en
  föreslagen tajweedregel eller fonetisk rättning är korrekt.

Ingen lagringsmigration, ny molnsynk, automatisk uppladdning eller ändring av
korantext införs. MP3-kontrollen i appen är fortfarande en avgränsad strukturell
kontroll, inte en helfilsavkodning. Automatisk analys är avstängd i standardappen.

## Regressioner och verifiering

Tre nya AudioLibrary-fall provar återhämtad lagring i samma instans, reparation
av en trasig versfil med bevarade färdiga byte och sena svar från en transport
som avsiktligt ignorerar avbrytning. Två nya HTTP-fall använder riktiga
URLSession-download tasks över loopback: avbruten TCP-kropp efter giltiga
MP3-ramar samt radering följd av ett nytt recitatörsjobb medan gamla svar städas.

Tre nya portabla tafsirfall provar borttagen rot, ersättande länk med externa
filer som inte får ändras eller städas, och rotbyte under ett pågående nätsvar.
De två första regressionerna misslyckades mot den gamla implementationen.
Alla **83 portabla Linux-Swift-fall** passerade därefter i Swift6.0.3 med
avstängt containernät. Innehåll, källhashar, övningsreferenser, font, ikon och
reproducerbar projektgenerering passerade också.

## Godkänd native-källa och leverans

[PR-körningen](https://github.com/AllCrow/Koran-test-/actions/runs/40191800468) körde faktisk checkout
`6897dba0e03072d18c79e14a74d165d5c219232b`. Huvudkällan `e1bb2625136277beb8f4eab78f17576acc3d56e5` har byteidentiskt
komplett Git-träd `4a769740e82380a90c0b63fc04fe172ffd893fad`. Slutkontrollen bekräftar också att app-, test-,
resurs-, backend-, script- och workflow-indata matchar båda körda källorna
före denna dokumentationsuppdatering.

[Huvudkörning 53](https://github.com/AllCrow/Koran-test-/actions/runs/40192974053) har **alla sex jobb avslutade och godkända**.
Varje simulators rålogg visar **96 hostade och åtta UI-fall utan fel**,
samt separat **85 portabla Swift-fall**. De tre konfigurationerna utförde
samma individuella fall: Xcode26.2/iPhone16Pro/iOS18.5,
Xcode16.4/iPhoneSE3/iOS18.5 och Xcode26.2/iPhone16e/iOS26.2.
Det är **104 unika native-/UI-fall och 312 exekveringar** över matrisen.

Hostade grupper: 25 AppStore, 11 text/färg, sju HTTP-transport,
16 AudioLibrary, sju ChapterLoading, sju MP3, 11 inspelnings- och tolv
spelarfall. De fem nya fallen beskrivs ovan; alla åtta tidigare UI-flöden
och deras faktiska interaktions-/positionskrav är kvar.

Backendjobbet passerade **57 prov**, varav 21 gäller utvärderingsverktyget.
Det använder riktig ffmpeg-avkodning och behandlar ResourceWarning som fel.
Detta är kontrakts-/transport-/avkodningsbevis, ingen ny akustisk kvalitetsstudie.
Arkivfallet 112:2 har fortsatt `pending`, noll avgjorda fall och
`quality_metrics: null`. Dess ursprungliga ljudidentitet återkontrollerades
lokalt utan nytt modellanrop och utan ljud i Git.

### Personligt paket

- Version **0.1.0 (53)**, **3 271 185 byte**.
- IPA SHA256: `159cbb58cde06dca919b956b8a4b918339c7d79ec1266de1a31682a404c2c6eb`.
- Källa `e1bb2625136277beb8f4eab78f17576acc3d56e5`, artefakt **12599105394**.
- Yttre artefakt-ZIP SHA256: `fb1b14b7bf0240f21f93f1701292ceeef15105d7b8b57d10c2030027dd6afe40`.
- Oberoende Mach-O-/plistkontroll: iPhoneOS, arm64, minsta iOS17.0, SDK26.2.
- Alla 115 koran-JSON-filer, fonten och 118 övningsresurser matchar källan exakt.
- Analysflaggan är avstängd och serveradressen tom; inga profiler eller testpaket ingår.

Ägarutkast **423396167**, tagg `personal-build-53-1`, är bekräftat som
draft/prerelease på rätt källa. IPA, byggrapport och installationsguide
matchar GitHubs samtliga tre asset-digests och storlekar. Hämta under
[Releases](https://github.com/AllCrow/Koran-test-/releases), inloggad som AllCrow.
[Leveransbeviset](evidence/offline-quality-delivery-53-2026-10-25.json)
binder källor, jobb, logghashar, paket, ägarutkast och den ogranskade utvärderingen.

Bygge51, dess separata verkliga EveryAyah-prov och tidigare säkerhetskopior
bevaras som historiskt underlag. Källprovet är inte omkört med denna omgångs
ändrade AudioLibrary och ersätter inte den nya ordinarie sviten. Följ
[installationsguiden](PERSONAL_IPHONE_INSTALL.md) och
[provlistan](FIRST_IPHONE_TEST.md) för signering och första fysiska telefonprov.

## Kvarvarande gränser

Loopback HTTP provar inte extern TLS, faktisk EveryAyah-tillgänglighet eller
telefonens radioväxling. Simulatorer verifierar inte fysisk installation,
mikrofon, filskydd vid låst telefon, hörlurar, VoiceOver, värme eller batteri.
Filrotens typkontroller är återhämtningsskydd, ingen garanti mot alla samtidiga
POSIX-filsystembyten. Ingen generell noggrannhet, full sifat-bedömning eller
Tarteel-jämförelse påstås. Innehållsrättigheter inför offentlig release kvarstår.
