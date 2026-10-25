# Native iPhone-verifiering

Uppdaterat 2026-10-25. Native-byggen och tester körs i GitHub Actions på en
riktig Mac med Apple SDK. **Exakt källversion, antal och senaste utfall finns i
[statusen](../STATUS.md).** Den lokala Linuxmiljön saknar Apple SDK och ersätter
inte dessa prov. **Ingen fysisk iPhone eller personlig signering är verifierad.**

## Automatiska prov på macOS

Den samlade [körningen 40175540017](https://github.com/AllCrow/Koran-test-/actions/runs/40175540017)
passerar 80 hostade prov och åtta UI-flöden i var och en av följande tre
varianter, samt 82 portabla Swift-prov och 36 backendprov. Källan är
3511431, faktisk Apple-checkout 8ded616d och mergad main 8cd977c har samma
kompletta filträd. Jobbloggar, artefakternas head-SHA och alla tre bilder
av 2:255 har kontrollerats. Exakta versioner/paket och senare körningar
redovisas i [STATUS.md](../STATUS.md).

| Variant | Byggverktyg / simulator | Enhet |
| --- | --- | --- |
| ios18 | Xcode 26.2 / iOS 18.5 | iPhone 16 Pro |
| ios18-compact | Xcode 16.4 / iOS 18.5 | iPhone SE (3:e generationen) |
| ios26 | Xcode 26.2 / iOS 26.2 | iPhone 16e |

Varje variant kör innehållskontroller, portabla Swift-tester, projektkontroll,
simulatorbygge och de hostade native-/UI-proven. Den personliga osignerade
iPhone-IPA:n byggs separat med **Xcode 26.2 / iOS 26.2 SDK**. Minsta stödda
körversion för appen är fortsatt **iOS 17**.

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
| AppStore | Unika uttryckliga läsmarkeringar, återstart, kalender-/systemklockebyten, måländring, bokmärken, tajweedval och korrupt sparad data. Sju dagars historik med stabila civila datum, intjänade mål och inga påhittade versantal. Fyra textstorlekar, äldre/okända sparvärden och bevarat storleksval vid import. Export/import sammanfogar läsdata idempotent; ogiltiga eller för stora filer ändrar inga data. |
| AudioLibrary | Vers/sura/recitatör, MPEG-/ID3-validering, diskåteröppning, avgränsad radering, felaktig lagring och lagringsfel. Kontrollerad nedladdning provar exakt URL, fortsättning efter avbrott, avbrytning, sena svar, HTTP/MIME/storleksfel och städning av temporära filer. |
| RecitationPlayer | Riktig AVPlayer-uppspelning av egna korta PCM-WAV-filer: start, naturligt slut, automatisk nästa vers, surans sista vers och enstaka övningsvers. Även trasig lokal fil/återförsök, sena händelser, sparade inställningar och uppskjuten laddning vid pausat recitatörsbyte. Simulerad omstart av ljudtjänsten behåller valet, förnyar spelaren och kräver uttrycklig återupptagning. |
| OfflineMP3Playback | Sju prov av verklig MP3-till-PCM-avkodning och AVPlayer med AudioLibrary:s lokala filval för alla tre recitatörer, aktiverad systemljudsession, paus/återstart, naturligt versslut/autospelning, enstaka övningsvers, simulerade avbrotts-/hörlursnotiser, gamla händelser och en ospelbar fil. En genererad svag ton används, inga externa ljudförfrågningar eller röster. |
| AudioDownloadTransport | Fem prov från det integrerade arbetet i [PR #3](https://github.com/AllCrow/Koran-test-/pull/3): riktiga URLSession-download tasks över loopback HTTP. Tre recitatörers lagring och MP3-avkodning, återöppning från disk, HTTP-fel/återupptagning, avbruten kropp och storleksgränser från riktiga download-delegate-callbacks. Överstorleksproven kräver avbrytning före ett öppet svars slut. Begärd HTTPS-adress återställs bara i testets svarsmetadata; extern TLS och verkligt recitationsinnehåll ingår inte. |
| PracticeRecorder | Fördröjd mikrofonbehörighet, avbrytning, sena besked, överlappande försök, ljudavbrott/hörlursnotiser, otillgänglig lagring och städning som bevarar andra filer. Simulerad förlust/omstart av ljudtjänsten avbryter väntande behörighet utan automatisk inspelningsstart. Inget prov spelar in från simulatorns mikrofon eller verifierar den synliga minuträknaren mot en verklig tagning. |
| TafsirRepository (portabla prov) | Käll-/versvalidering, JSON-innehållstyp, bevarade arabiska UTF-8-byte och återöppning av diskcache utan nät. Fel utgåva/referens, skadade filer, lagringsfel, LRU, fil-/bytegränser och länkar provas i isolerade temporära kataloger. Provar ingen extern AlQuran Cloud-förbindelse eller fysisk flygplansläge-användning. |
| Textberedning och sökning | Exakta UTF-8-sekvenser även för kanoniskt likvärdiga strängar, nästlade tajweedregler, säker fallback och begränsad cache. Arabisk tangentbordssökning, alternativa latinska vokalstavningar och validering av vershoppets siffror/intervall. |
| UI-flöden | Läsmarkering och återstart, beständigt bokmärke, surasökning och korrekta kontrollreferenser efter surabyte. Hopp till 2:255 med arabiska siffror, ingen navigationskredit, återstart och senare läsposition. Största tillgänglighetstext, beständigt tajweed-/textstorleksval, veckohistorik och synliga backupkontroller. Även mörkt läge och nästa sura fram till an-Nas utan påhittad nästa sura eller läskredit. |

UI-testerna använder en egen `UserDefaults`-suite per test. Endast Debug-byggen
accepterar det avgränsade testargumentet. Tester raderar inte normala läsdata,
kontaktar ingen analystjänst och ber inte om mikrofonbehörighet. Den historiskt godkända
UI-körningen matar in arabiska siffror, öppnar sura 112, kontrollerar att den
föregående surans kontroller har ersatts och markerar/bokmärker 112:1. Den
sparade bokmärkesreferensen verifieras också i inställningarna. Proven
kontrollerar inte fysisk mikrofon, ljudrutter eller energiförbrukning. Ljudproven
omfattar faktisk uppspelning av genererade WAV-/MP3-filer i simulatorn, inte
avkodningskvalitet för alla imaminspelningar. Transportproven omfattar både
kontrollerade svar och riktiga lokala HTTP-överföringar, men bevisar inte
externa TLS-förbindelser eller nedladdning/offlineuppspelning på telefonen. Systemets filväljare
och externa filproviders för backup behöver också ett manuellt prov.

**Historisk baslinje:** [körning 40165021106](https://github.com/AllCrow/Koran-test-/actions/runs/40165021106)
passerar alla **56 hostade prov och fem UI-flöden** på källversion
`1ba557c3d6bed990504789caa2d01398d897e263`. Native List visar hela versbadgen
nära toppen inom fem sekunder i de fyra positionsfallen. Bilden för 2:255
visar även versens första textrader, utan föregående vers i skärmen. Exakt
källa, paket och historisk MP3-baslinje dokumenteras i [STATUS.md](../STATUS.md).
Det är utfallet före textstorlek, veckohistorik, beständig tafsircache,
ljudtjänståterhämtning och den nya HTTP-transporten. Antalen ska inte användas
som resultat för den aktuella källversionen eller den nya CI-matrisen.

Apples [uppladdningskrav](https://developer.apple.com/news/upcoming-requirements/)
kontrollerades 2026-10-25: App Store Connect kräver Xcode26+/iOS 26 SDK sedan
28 april 2026. Den nya konfigurationen använder Xcode 26.2/iOS 26.2 SDK för
iPhone-paketet och en av simulatorvarianterna. Ett lyckat osignerat bygge
eller simulatorprov ersätter inte signering och en faktisk godkänd
App Store Connect-uppladdning. Minsta stödda iOS 17 är en annan inställning
än bygg-SDK:n. Personlig installation på aktuell
fysisk telefon behöver fortfarande provas.

## Manuella prov på iPhone

För användarens första pass finns en [kort provguide](FIRST_IPHONE_TEST.md).
Notera appens version/byggnummer, commit, iPhone-modell och iOS-version tillsammans med resultat.
Varje rad återstår tills den faktiskt har körts.

| Område | Prova och kontrollera |
| --- | --- |
| Arabisk text | Högerkant, diakritik, långa verser, Basmala i 95/97, mörkt läge och VoiceOver. Prova alla fyra textstorlekar i läsning, tafsir och övning samt förhandsvisningen från 1:1. Återstart ska bevara valet. Kombinera med största tillgänglighetstext från iOS. Växla tajweed utan att förlora bokstäver. |
| Tre recitatörer | Kontrollera rätt ljud för samma vers, buffring, paus/återstart, recitatörsbyte, sista versen och automatisk nästa vers. Basmala i ett ljudklipp får inte beskrivas som verifierad ordsynkning. |
| Ljudavbrott | Låsskärmens spelknappar, headsetknappar, telefonsamtal, hörlursurkoppling och växling mellan förebild, mikrofon och egen återlyssning. Vid omstart av iOS ljudtjänst: samma vers-/recitatörsval, ingen oväntad återstart, uttryckligt återförsök och återkontroll av giltig lokal tagning. Simulerade notiser ersätter inte ett verkligt systemavbrott; markera ej provat om det inte inträffar. |
| Offline | Ladda ned, avbryt, återuppta, lägg appen i bakgrunden och återvänd. Färdiga verser ska bevaras. Spela dem i flygplansläge; radera ljudet under pågående uppspelning. |
| Egen tagning | Spela in en annan vers än senast lästa, med valt Basmala-alternativ. Kontrollera synligt förlopp och återstående tid, automatisk avslutning vid en minut och faktisk inspelad längd. Räknaren ska bara visas under inspelning. Mät även beteendet när inspelningen har avslutats; tomgångsenergi är inte verifierad på enheten. Bläddra till en annan sura i läsaren och återvänd. Tagning, vers och frasval ska finnas kvar. Avbryt och bekräfta därefter byte/radering. |
| Mikrofonens livstid | Tillåt mikrofonen efter att övningsvyn redan lämnats. Inspelning får inte börja därifrån. Lås telefonen under inspelning/egen återlyssning; båda ska avslutas. |
| Läsprogression | Samma vers räknas en gång per lokal dag. Prova måländring, återstart, midnatt samt byte av tid/tidszon. Ett intjänat läsdygn ska inte tas bort när målet höjs. Sjudagarsvyn ska visa rätt dag, prick för läsning och bock för intjänat mål, även efter återstart. Vid stor text ska historiken gå att läsa som en lista. |
| Vershopp och backup | Hopp till en lång vers med västerländska/arabiska siffror, återstart och senare läsposition. Exportera i Filer och importera samma fil utan dubblering. Prova avbrytning i filväljaren och en ogiltig fil. Separat kopia före avinstallation; röst och ljud ingår inte. |
| Tafsir | Hämta en förklaring online; kontrollera rätt vers och källa. Starta om appen i flygplansläge med Wi-Fi av och öppna samma förklaring från cache. En aldrig öppnad förklaring kräver nät och ska kunna försöka igen när nätet återkommer. Prova snabb stängning/återöppning och referensbyte utan gammal text eller kvarhängande laddningsindikator. Endast nyligen sparade förklaringar omfattas; högst 64 poster, 4 MiB totalt och 128 KiB per fil. |
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
