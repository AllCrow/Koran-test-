# Native iPhone-verifiering

Uppdaterat 2026-10-25. Native-byggen och tester körs i GitHub Actions på en
riktig Mac med Apple SDK. **Exakt källversion, antal och senaste utfall finns i
[statusen](../STATUS.md).** Den lokala Linuxmiljön saknar Apple SDK och ersätter
inte dessa prov. **Ingen fysisk iPhone eller personlig signering är verifierad.**

## Automatiska prov på macOS

Det genererade Xcode-projektet har tre mål: `Sakina`, `SakinaTests` och
`SakinaUITests`. Schemat `Sakina` kopplar båda testmålen till appen.
De hostade proven använder isolerade inställningar, temporära filer, kontrollerad
transport och egna korta PCM-/MP3-ljud. Inga privata inspelningar eller hämtade
recitationsfiler ingår i testerna eller repot.

På en Mac med Xcode och en installerad iPhone-simulator:

```sh
python3 scripts/generate_project.py
xcodebuild -project Sakina.xcodeproj -scheme Sakina -showdestinations
xcodebuild -project Sakina.xcodeproj -scheme Sakina \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -parallel-testing-enabled NO -resultBundlePath TestResults.xcresult \
  CODE_SIGNING_ALLOWED=NO test
```

Välj ett faktiskt tillgängligt simulatornamn från det första kommandot.
[GitHub Actions-flödet](../.github/workflows/ios.yml) väljer ett tillgängligt
iPhone-ID och sparar en `.xcresult` samt exporterade testbilagor även om teststeget
misslyckas. Användaren har uttryckligen godkänt publikt repoläge tills vidare.
Native-resultat, skärmbilder och simulatorapp har sju dagars CI-lagring.
Simulatorappen kan inte installeras på en fysisk iPhone. Ett separat jobb bygger
en osignerad fysisk iPhone-IPA; efter alla godkända jobb bevaras den som ett
ägaråtkomligt releaseutkast. Se [installationsguiden](PERSONAL_IPHONE_INSTALL.md).

| Testgrupp | Avsikt |
| --- | --- |
| AppStore | Unika uttryckliga läsmarkeringar, återstart, kalender-/systemklockebyten, måländring, bokmärken, tajweedval och korrupt sparad data. Export/import återställer och sammanfogar läsdata idempotent; ogiltiga eller för stora filer ändrar inga data. |
| AudioLibrary | Vers/sura/recitatör, MPEG-/ID3-validering, diskåteröppning, avgränsad radering, felaktig lagring och lagringsfel. Kontrollerad nedladdning provar exakt URL, fortsättning efter avbrott, avbrytning, sena svar, HTTP/MIME/storleksfel och städning av temporära filer. |
| RecitationPlayer | Riktig AVPlayer-uppspelning av egna korta PCM-WAV-filer: start, naturligt slut, automatisk nästa vers, surans sista vers och enstaka övningsvers. Även trasig lokal fil/återförsök, sena händelser, sparade inställningar och uppskjuten laddning vid pausat recitatörsbyte. |
| OfflineMP3Playback | Sju prov av verklig MP3-till-PCM-avkodning och AVPlayer med AudioLibrary:s lokala filval för alla tre recitatörer, aktiverad systemljudsession, paus/återstart, naturligt versslut/autospelning, enstaka övningsvers, simulerade avbrotts-/hörlursnotiser, gamla händelser och en ospelbar fil. En genererad svag ton används, inga externa ljudförfrågningar eller röster. |
| AudioDownloadTransport (inväntar Mac-CI) | Riktiga URLSession-download tasks över loopback HTTP: tre recitatörers lagring och MP3-avkodning, återöppning från disk, HTTP-fel/återupptagning, avbruten kropp och storleksgränser från riktiga download-delegate-callbacks. Begärd HTTPS-adress återställs bara i testets svarsmetadata; extern TLS och verkligt recitationsinnehåll ingår inte. |
| PracticeRecorder | Fördröjd mikrofonbehörighet, avbrytning, sena besked, överlappande försök, ljudavbrott/hörlursnotiser, otillgänglig lagring och städning som bevarar andra filer. Inget prov spelar in från simulatorns mikrofon. |
| Textberedning och sökning | Exakta UTF-8-sekvenser även för kanoniskt likvärdiga strängar, nästlade tajweedregler, säker fallback och begränsad cache. Arabisk tangentbordssökning, alternativa latinska vokalstavningar och validering av vershoppets siffror/intervall. |
| UI-flöden | Läsmarkering och återstart, beständigt bokmärke, surasökning och korrekta kontrollreferenser efter surabyte. Hopp till 2:255 med arabiska siffror, ingen navigationskredit, återstart och senare läsposition. Största tillgänglighetstext, tajweedval som sparas och synliga backupkontroller. |

UI-testerna använder en egen `UserDefaults`-suite per test. Endast Debug-byggen
accepterar det avgränsade testargumentet. Tester raderar inte normala läsdata,
kontaktar ingen analystjänst och ber inte om mikrofonbehörighet. Den godkända
UI-körningen matar in arabiska siffror, öppnar sura 112, kontrollerar att den
föregående surans kontroller har ersatts och markerar/bokmärker 112:1. Den
sparade bokmärkesreferensen verifieras också i inställningarna. Proven
kontrollerar inte fysisk mikrofon, ljudrutter eller energiförbrukning. Ljudproven
visar faktisk uppspelning av genererade WAV-/MP3-filer i simulatorn, inte avkodningskvalitet för
alla imaminspelningar. Transportproven använder kontrollerade svar och bevisar
inte verklig nedladdning/offlineuppspelning på telefonen. Systemets filväljare
och externa filproviders för backup behöver också ett manuellt prov.

[Körning 40165021106](https://github.com/AllCrow/Koran-test-/actions/runs/40165021106)
passerar alla **56 hostade prov och fem UI-flöden** på källversion
`1ba557c3d6bed990504789caa2d01398d897e263`. Native List visar hela versbadgen
nära toppen inom fem sekunder i de fyra positionsfallen. Bilden för 2:255
visar även versens första textrader, utan föregående vers i skärmen. Exakt
källa, paket och historisk MP3-baslinje dokumenteras i [STATUS.md](../STATUS.md).

Apples [uppladdningskrav](https://developer.apple.com/news/upcoming-requirements/)
kontrollerades 2026-10-25: App Store Connect kräver Xcode26+/iOS26 SDK sedan
28 april 2026. Simulatorproven med Xcode16.4/iOS18.5 ersätter inte ett sådant
bygge inför eventuell TestFlight-/App Store-distribution. Minsta stödda iOS17
är en annan inställning än bygg-SDK:n. Personlig installation på aktuell
fysisk telefon behöver fortfarande provas.

## Manuella prov på iPhone

För användarens första pass finns en [kort provguide](FIRST_IPHONE_TEST.md).
Notera appens version/byggnummer, commit, iPhone-modell och iOS-version tillsammans med resultat.
Varje rad återstår tills den faktiskt har körts.

| Område | Prova och kontrollera |
| --- | --- |
| Arabisk text | Högerkant, diakritik, långa verser, Basmala i 95/97, mörkt läge, största tillgänglighetstext och VoiceOver. Växla tajweed utan att förlora bokstäver. |
| Tre recitatörer | Kontrollera rätt ljud för samma vers, buffring, paus/återstart, recitatörsbyte, sista versen och automatisk nästa vers. Basmala i ett ljudklipp får inte beskrivas som verifierad ordsynkning. |
| Ljudavbrott | Låsskärmens spelknappar, headsetknappar, telefonsamtal, hörlursurkoppling och växling mellan förebild, mikrofon och egen återlyssning. Ingen oväntad återstart efter avbrott. |
| Offline | Ladda ned, avbryt, återuppta, lägg appen i bakgrunden och återvänd. Färdiga verser ska bevaras. Spela dem i flygplansläge; radera ljudet under pågående uppspelning. |
| Egen tagning | Spela in en annan vers än senast lästa, med valt Basmala-alternativ. Bläddra till en annan sura i läsaren och återvänd. Tagning, vers och frasval ska finnas kvar. Avbryt och bekräfta därefter byte/radering. |
| Mikrofonens livstid | Tillåt mikrofonen efter att övningsvyn redan lämnats. Inspelning får inte börja därifrån. Lås telefonen under inspelning/egen återlyssning; båda ska avslutas. |
| Läsprogression | Samma vers räknas en gång per lokal dag. Prova måländring, återstart, midnatt samt byte av tid/tidszon. Ett intjänat läsdygn ska inte tas bort när målet höjs. |
| Vershopp och backup | Hopp till en lång vers med västerländska/arabiska siffror, återstart och senare läsposition. Exportera i Filer och importera samma fil utan dubblering. Prova avbrytning i filväljaren och en ogiltig fil. Separat kopia före avinstallation; röst och ljud ingår inte. |
| Tafsir | Rätt vers och källa, nätbortfall, återförsök, snabb stängning/återöppning och ingen kvarhängande laddningsindikator. |
| Experimentell analys | Standardbygget ska ha analys avstängd. I en separat aktiverad testversion: uttrycklig uppladdning, avbrytning, fel/tystnad och återkoppling i exakt modellreferens. Ingen automatisk poäng eller uppladdning. |

## Energi och värme

Inga energimått eller temperaturer är uppmätta i detta projekt. Källkodens
händelsestyrda spelare och frånvaro av lokal modellinferens räcker inte för
att godkänna värmekravet.

Mät separat läsning offline, sparad recitation med låst skärm,
ljudnedladdning och lokal inspelning på fysisk iPhone. Använd samma enhet,
ljusstyrka, batterinivå, omgivning och nätförhållanden; mät utan laddning.
Spara varaktighet, CPU/minne, energispår och systemets termiska tillstånd
från ett faktiskt enhetsprov. Kontrollera även längre sessioner och en äldre
stödd iPhone. Instruments-profiler kräver en lämplig Mac/enhetsanslutning.
Subjektiv värme och batteriprocent är kompletterande observationer, inte
precisa temperatur- eller energimått.

Personlig signering och installation återstår enligt [guiden](PERSONAL_IPHONE_INSTALL.md).
TestFlight är ett alternativ. Ett lyckat simulatorprov ersätter inte
ljudrutter, mikrofon, energimätning eller arabisk återgivning på fysisk enhet.
