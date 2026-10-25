# Fortsatt stabilitetsarbete 2026-10-25

## Förtydligad native-kvittens i pausprovet

Körning 49 hittade ett för tidigt kvitterat pausläge i MP3-provets andra
avbrottsfas på iOS 26. Två rate-kontroller läste 1, medan status var paused;
provet tog 0,309 s och hade inte nått någon tidsgräns. Den tidigare
förutsättningen efter resume kontrollerade bara appens publicerade flagga.

Provet bevakar nu motorn före varje kommando och kräver positiv native-rate
och playing före avbrottet. KVO är endast väckning för nya aktuella getter-
kontroller på huvudaktorn. Samma tvåsekundersgräns, riktiga MP3-avkodning,
tresekunderston, uppspelningsklocka under 2,5 s med ljud kvar, inget naturligt slut och
slutliga rate0/paused-krav behålls. Samma item och ljudfil kontrolleras också.
De senaste 64 tillståndsobservationerna bifogas om kvittensen misslyckas.
Detta testbyte påstår inte att ett ihållande produktfel har bevisats eller
att en tidigare misslyckad körning har blivit godkänd. Det uppdaterade provet omfattas av slutresultaten nedan.

Användaren bad om fortsatt förbättringsarbete efter det godkända personliga
bygget 46. Det paketet och dess fullständiga historik/backup bevaras.

## Avgränsade rättningar

- **Förlorad ljudtjänst:** spelaren hanterar nu iOS-notisen om förlust direkt,
  stoppar den verkliga motorn, ogiltigförklarar gamla callbacks och behåller
  vers/recitatör. Nya medieobjekt väntar på reset. Ingen automatisk återstart;
  användaren måste uttryckligen spela igen efter återställningen.
- **Sammanfogad läskopia:** två var för sig giltiga filer kan få en union
  större än den sparade läsdatans gräns. Både den föreslagna sparade staten
  och exporten storlekskontrolleras före publicering eller skrivning. En för
  stor union lämnar minne och tidigare sparade byte orörda. Standardgränsen
  är fortsatt 4 MiB. Ett internt lägre budgetvärde provar den riktiga
  serialiseringsgränsen utan stora syntetiska fixturefiler.
- **Avbruten suraladdning:** en återställning från Öva får inte byta läsarens
  sura efter att vyn lämnats. Den senaste färdiga suran, valet och eventuellt
  fel behålls tills laddningen lyckas eller faktiskt misslyckas. Cancellation
  och sena svar kan inte skriva över ett nyare val eller släcka dess
  laddningsindikator. Ett verkligt fel behåller rätt mål för återförsök.
- **UIKit-underhåll:** färgkontrastens traitkombinationer använder API:t för
  iOS 17 och senare i stället för den deprekerade sammanslagningsinitieraren.
  Källa, färgtoner, text och kontrastkrav är oförändrade.

## Verifierade resultat

[PR-körning 40184479157](https://github.com/AllCrow/Koran-test-/actions/runs/40184479157)
godkändes för grenens `0d85b19426980c8f2c3c5ae46ac6a71458c11162`. Faktisk PR-checkout var
`7d29ca28190cb24171c6ebaf61c7a8d203d55a3b` med Git-träd `188fe37ce0dfb1d2eaee63e78427f68482e8480d`. Den inkluderar också
den redan integrerade fristående käll-/villkorsgranskningen. App-, test-,
resurs-, bygg- och workflow-indata matchar kandidaten; skillnaderna består
av dokumentation och det manuella källkontrollverktyget som inte körs i app
eller normal CI. Resultaten nedan gäller den faktiskt körda checkouten.
[Huvudkörning 51](https://github.com/AllCrow/Koran-test-/actions/runs/40186048325) godkändes också på `c907121e59eab81ae8848e2ca0311ab54f2aa6ec`.

Varje simulator utförde **91 hostade prov och åtta UI-flöden utan fel**,
samt separat **82 portabla Swift-prov**. Det är 99 unika native-/UI-fall
och 297 exekveringar över de tre konfigurationerna. Backendjobbet passerade
36 prov med ffmpeg och ResourceWarning som fel. Innehåll, font, referenser,
projektgenerering samt simulator- och osignerat iPhone-bygge passerade.

Hostade grupper: 25 AppStore, 11 text/färg, fem HTTP-transport, 13 AudioLibrary,
sju ChapterLoading, sju MP3, 11 inspelnings- och tolv spelarprov. De elva
nya fallen består av två import-, två ljudtjänst- och sju laddningsprov.
Kallstartsprovet täcker både katalogsvar efter ett nyare färdigt kapitel och
medan det nyare kapitlet väntar. Den första kandidaten ersattes efter denna
konkreta granskningsupptäckt; en ersatt körning är inget godkännande för slutkällan.

Även körning 48 hade ett kompakt UI-fel efter riktig återstart: den tidiga
AX-roten pekade på gamla PID38019, den senare rätta läsaren på PID39656.
Bild och senare diagnostik visar hela rätta 114:1-badgen vid y92–118,5 inom
y64–202,5. Det är inte bevis för att det ursprungliga tidsprovet passerade.
Den rättade harnessen läser rätt badge, navigering, tabbrad och fönster ur en
sammanhängande native-snapshot. Det undviker blandade fjärrfrågor och kräver
fortfarande en unik exakt vers, samma fullständiga geometri, förgrund och
femsekundersgräns. Alla åtta flöden och interaktiva kontrollkrav behålls.
Ett separat förslag med nya XCUIApplication-objekt vid omstart bevaras på
`codex/relaunch-process-harness-alternative` men är inte antagen produktkod.
De nya godkännandena ovan gäller den sammanhängande snapshot-harnessen.
Utvalda felbilder, AX-data och råloggen bevaras i slutbackupen.

Körning49 hittade därefter för tidig native-pauskvittens efter explicit resume:
rate1 lästes trots paused och två assertions misslyckades. Hela provet tog0,309s utan timeout.
Det förbättrade MP3-provet bevakar före kommandon och kräver riktig native-
uppspelning före avbrott; appens flagga ensam räcker inte. Alla tidigare
slutkrav och2s/3s/<2,5s/noEOF behålls, med samma item/fil och upp till64
observationer som feldiagnostik. Den gamla felloggen bevaras. Slutresultaten
ovan gäller den förbättrade kvittensen; ingen misslyckad körning räknas som grön.

Linux/Swift6-syntaxkontrollen var bara förkontroll. Resultaten ovan kommer från
faktiska Apple-SDK-byggen och native-körningar med Xcode26.2/iOS18.5 på
iPhone16Pro, Xcode16.4/iOS18.5 på iPhoneSE3 och Xcode26.2/iOS26.2 på iPhone16e.
Testmål byggs en gång; hostade prov måste passera före UI-flöden.

## Personligt paket och bevarande

Den separata [live-källgranskningen](LIVE_RECITATION_AUDIT.md) passerade tre
andra native-fall på en simulatorvariant: tolv riktiga filer avkodades och
lokal 112:2 spelades till faktiskt slut för alla tre recitatörer. Dess rålogg,
ZIP, tre originalbilagors hashvärden och bindning till aktuella kodhashar
kontrollerades separat. Den ändrar inte ordinarie testantal, appkod, byggprojekt
eller minsta iOS. De senare opt-in-filerna ingår i källbackupen och har egen
verifieringsproveniens; de körs inte av standardappen eller normal CI.

- Version **0.1.0 (51)**, **3269813 byte**.
- IPA SHA256: `279803799a1f3d72626c42ab7e7a651e3859cb528a80625e0c5ef26de5e6854b`.
- Yttre artefakt-ZIP SHA256: `0c38c04d9d018eedcbe198825f38e680e02357dc844f40dcb955ef1b2037c3a2`.
- Källa `c907121e59eab81ae8848e2ca0311ab54f2aa6ec`, artefakt **12596352350**.
- Oberoende Mach-O-/plistkontroll: arm64, iOS-plattform, min iOS17.0, SDK26.2.
- Alla 115 koran-JSON-filer, fonten och 118 övningsresurser är byteidentiska.
- Analysflagga av och serveradress tom; inga profiler, testpaket eller externa dylibs.

Ägarutkast **423341980**, tagg `personal-build-51-1`, är bekräftat som
draft/prerelease på rätt källa. IPA, byggrapport och installationsguide matchar
GitHubs asset-digests och storlekar. Hämta via
[Releases](https://github.com/AllCrow/Koran-test-/releases), inloggad som AllCrow.
Råloggar, tre bildartefakter och metadata bevaras med källarkiv och fullständigt
Git-bundle i arbetsytans slutbackup. Äldre bygge46/backup finns kvar.
Den oberoende kontrollen av samtliga tre releasefiler och 239 paketerade
källresurser finns i [leveransbeviset för bygge 51](evidence/delivery-51-2026-10-25.json).

Även den separata live-granskningens logg och metadata-ZIP bevaras i bevisarkivet.

## Kvarvarande provgränser

Ljudproven spelar en riktig genererad WAV i AVPlayer, men ljudtjänstnotiserna
är simulerade. Laddningsproven använder kontrollerade async-svar. Fysisk iPhone,
personlig signering/installation, mikrofon, externa ljudrutter, filproviders,
VoiceOver, temperatur och batteri återstår enligt
[telefonprovet](FIRST_IPHONE_TEST.md). Ingen fysisk stabilitet eller låg värme
påstås från simulatorerna. Automatisk tajweedanalys är fortfarande avstängd
utan serveradress och Tarteels kvalitetsmål är inte uppfyllt.
