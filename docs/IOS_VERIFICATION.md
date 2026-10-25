# Native iPhone-verifiering

Uppdaterat 2026-10-25. Native-byggen och tester körs i GitHub Actions på en
riktig Mac med Apple SDK. **Exakt källversion, antal och senaste utfall finns i
[statusen](../STATUS.md).** Den lokala Linuxmiljön saknar Apple SDK och ersätter
inte dessa prov. **Ingen fysisk iPhone eller personlig signering är verifierad.**

## Automatiska prov på macOS

[Huvudkörning 63](https://github.com/AllCrow/Koran-test-/actions/runs/40218507319) är **avslutad med alla sex jobb godkända**.
Varje simulator utförde **139 hostade + 12 UI-fall**, samt separat
**89 portabla Mac-fall**. Backendjobbet passerade **57 fall**, inklusive
21 befintliga utvärderingskontraktsprov. Det är **151 unika native-/UI-fall och
453 exekveringar** över tre konfigurationer.

Källa `dd0f159dbf60d5daa839bafd252dc80091cc18aa`, komplett Git-träd `b082e40e92f85cabd8d6bf66e7f1e228f9cccd1b`. Den hämtade
[PR-checkouten](https://github.com/AllCrow/Koran-test-/actions/runs/40216509406) `3da7cf46d0680815618ccfbe2401537b455d2a48` har samma hela träd.
[Leveransbeviset](evidence/library-delivery-63-2026-10-25.json) binder individuella passrader, råloggar,
källor, paket och ägarutkast.

Aktuellt paket är **0.1.0 (63)**, **3 491 616 byte**,
iPhoneOS/arm64, minsta iOS17.0 och SDK26.2. IPA SHA256:
`0bfb02ef8779662de7e99a47a43c60643483eaf7450c3ee4a1ff801a99dbea3f`.
Releaseutkast **423574403**, tagg **personal-build-63-1**, är draft/prerelease
på rätt källa. Alla tre assets matchar filstorlekar och SHA256. Hämta under
[Releases](https://github.com/AllCrow/Koran-test-/releases), inloggad som **AllCrow**.

Det separata [EveryAyah-provet](https://github.com/AllCrow/Koran-test-/actions/runs/40205401991) passerade tre
opt-in-fall på iPhone16e/iOS26.2: tolv riktiga filer, 855505 byte,
avkodade och lokal112:2 spelad till native-slut för alla tre recitatörer.
[Originalunderlaget och sex kodhashar](evidence/live-recitation-native-library-2026-10-25.json) binds till den
aktuella källans sex granskade ljud-/lagringsfiler. Körkällan är
`b7725676b6ea578a5be4daec98c784bffb8087b1`; detta är ingen ny körning av hela appen eller dess UI.
Rålogg, API-metadata, ZIP och tre ursprungliga JSON-bilagor är återkontrollerade.
Provet använder normal `playOnce`. Den nya bundna sessionsvägen
`playSavedOnce` täcks separat av det genererade MP3-provet i normalmatrisen.
De tre källfallen ingår inte i matrisens 151/453.

Personlig signering och fysisk installation, mobilradio, låsta repetitionspauser,
ljudrutter, Files-export, VoiceOver och energi återstår. Automatisk analys är av;
ingen ny akustisk noggrannhet eller Tarteel-jämförelse påstås.

Båda UI-klasserna körs: ReadingFlowTests (8)
och FeatureFlowTests (4). Nya flöden använder
riktiga reglage för bibliotekets ljud/textkoppling och radering, repetition,
övningskö och nätval/rapport.
Isolerad Debug-lagring och genererat lokalt ljud används, utan externa ljudanrop
eller mikrofon. Release bygger utan testhjälpen.
[Omgångens underlag](LIBRARY_REPETITION_2026-10-25.md).

**Historiskt bygge53 och dess separata källprov:**

Följande underlag gäller bygge53:s exakta ljudkod. Det är inte omkört som bevis
för denna omgångs nya bibliotek och repetitionsmotor.

Utöver normalmatrisen passerade det befintliga, separata EveryAyah-provet
åter mot bygge53:s ändrade ljudbibliotek i
[körning40194584222](https://github.com/AllCrow/Koran-test-/actions/runs/40194584222):
tre fall på iPhone16e/iOS26.2,12 riktiga filer och lokal native-uppspelning
av hashpinnad112:2 till slut för alla tre. Se
[källbeviset](evidence/live-recitation-native-recovery-2026-10-25.json).
Inga röster sparas i Git/artefakter; mikrofon, radio, fysisk ljudrutt och energi
provas inte. Fallen ändrar inte ordinarie96+8/104/312-antal.
Den [oberoende paket-/resultatkontrollen](evidence/delivery-53-2026-10-25.json)
kompletterar den parallella omgångens bevarade leveransbevis.

**Historisk källa `e1bb2625136277beb8f4eab78f17576acc3d56e5` passerar [huvudkörning 53](https://github.com/AllCrow/Koran-test-/actions/runs/40192974053)**
med **96 hostade + åtta UI-prov per variant**, 85 separata portabla Swift-prov
per Mac-variant och 57 backendprov, inklusive 21 utvärderingsverktygsprov.
Alla sex jobb och ägarutkastet är godkända. Fem nya hostade fall består av
tre AudioLibrary- och två verkliga loopback-HTTP-regressioner. Tre nya portabla
tafsirfall ingår i Mac-antalet. Det är 104 unika native-/UI-fall och
312 exekveringar över tre konfigurationer. Se
[omgångens underlag](OFFLINE_QUALITY_2026-10-25.md) och
[leveransbeviset](evidence/offline-quality-delivery-53-2026-10-25.json).

**Historiskt bygge51 och dess separata källprov:**

Det tidigare EveryAyah-provet är inte omkört med denna omgångs ändrade
AudioLibrary; det är historiskt underlag, skilt från dagens ordinarie svit.

**Historisk källa `c907121e59eab81ae8848e2ca0311ab54f2aa6ec` passerar [huvudkörning 51](https://github.com/AllCrow/Koran-test-/actions/runs/40186048325)**
med **91 hostade + åtta UI-prov per variant**, 82 separata portabla
Swift-prov per Mac-variant och 36 backendprov. Alla sex jobb inklusive
ägarutkastet är godkända. Elva nya native-regressioner täcker ljudtjänstförlust,
importgränser och avbrutna/överlappande laddningar. Se
[fortsättningsunderlaget](CONTINUED_STABILITY_2026-10-25.md).
[Det oberoende leveransbeviset](evidence/delivery-51-2026-10-25.json)
knyter jobben till releaseutkastets tre filer, IPA-hash och paketerade källresurser.

**Historisk baslinje för bygge 46:**

Den samlade kandidaten har passerat [PR-körning 44](https://github.com/AllCrow/Koran-test-/actions/runs/40175540017)
på alla tre varianter. Huvudgrenens byteidentiska källa
`8cd977c4f2063e51784cc0b7c3fbca75b1760ec3` passerade också
[slutkörning 46](https://github.com/AllCrow/Koran-test-/actions/runs/40176707574)
med alla sex jobb godkända, inklusive ägarnedladdningen.
Varje variant utförde **80 hostade + åtta UI-prov**, samt separat
**82 portabla Swift-prov**. Backendjobbet har **36 godkända prov**.
Exakta utfall finns i [STATUS.md](../STATUS.md) och
[verifieringsunderlaget](evidence/premium-readiness-2026-10-25.md).

| Variant | Byggverktyg / simulator | Enhet |
| --- | --- | --- |
| ios18 | Xcode 26.2 / iOS 18.5 | iPhone 16 Pro |
| ios18-compact | Xcode 16.4 / iOS 18.5 | iPhone SE (3:e generationen) |
| ios26 | Xcode 26.2 / iOS 26.2 | iPhone 16e |

Varje variant kör innehållskontroller, portabla Swift-tester, projektkontroll,
simulatorbygge och de hostade native-/UI-proven. Den personliga osignerade
iPhone-IPA:n byggs separat med **Xcode 26.2 / iOS 26.2 SDK**. Minsta stödda
körversion för appen är fortsatt **iOS 17**.

CI-konfigurationen bygger testmålen en gång för den valda simulatorn och
kör sedan de hostade tjänsteproven före UI-flödena med `test-without-building`.
Ett tjänstefel ska stoppa omgången före de långsammare UI-proven; samma
UI-svit krävs fortfarande för ett godkänt nativejobb. Resultatartefakten
bevarar `HostedTests.xcresult` och, när tjänsterna passerat,
`UITestResults.xcresult`. Skärmbilder exporteras från UI-resultatet, eller
från tjänsteresultatet om körningen stannade där.
[Körning45](https://github.com/AllCrow/Koran-test-/actions/runs/40176541522)
har verifierat denna konfiguration på samtliga tre varianter: 80 hostade
prov följs av åtta UI-flöden, alla godkända. Artefakt12593107496 har båda
kompletta resultatbundlarna. PR7 är integrerad somd6d73e5; app- och testkod
är samma som i det godkända personliga main-bygget46.

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
| AudioInventory | 10 fall: arbete utanför UI-tråden, användbara/skadade bytesummor, kanoniska filer, avgränsad radering, länkar, avbrytning och gamla resultat. Ingen full ljudavkodning eller fysisk energi verifieras. |
| RecitationRepetition | 11 fall: riktiga WAV-slut provar ändligt intervall, pauser, stopp/resume, gamla återanrop, recitatörsbyte och simulerad ljudtjänstförlust. Ett genererat MP3-prov spelar från en bunden lokal fil och avvisar saknad fil/nytt försök utan nätfallback. Item-fabriken provar nätval; fysisk radio och bakgrundssuspension provas inte. |
| AudioNetworkPreferences | 2 fall: äldre standardvärde, sparat Wi-Fi-val och felaktiga typer. Begärandenas policyflagga provas även i AudioLibrary. |
| DiagnosticsReport | 5 fall: vitlistat schema, säkra versioner, verklig/otillgänglig lagring, typade felområden och deterministisk förhandsvisning. Systemexport återstår på telefon. |
| UpgradeCompatibility | 4 fall med frysta äldre läs-/backupformat och ljudlayout; omstart, ny kö och inställningar utan påhittad läskredit eller nät. |
| AppStore | 33 fall, inklusive köordning, gammalt sparformat, additiv import och kapacitets-/byteavvisning utan publicering. Unika uttryckliga läsmarkeringar, återstart, kalender-/systemklockebyten, måländring, bokmärken, tajweedval och korrupt sparad data. Sju dagars historik med stabila civila datum, intjänade mål och inga påhittade versantal. Fyra textstorlekar, äldre/okända sparvärden och bevarat storleksval vid import. Export/import sammanfogar läsdata idempotent; ogiltiga eller för stora filer ändrar inga data. |
| ChapterLoading | Sju kontrollerade async-prov: föravbruten öppning/kallstart, prompt avbrytning med bibehållna sparade byte, sena lyckade/felaktiga resultat efter nyare färdig eller pågående laddning, korrekt återförsöksmål och bevarad katalog under överlappande kallstart. Loaders ignorerar avsiktligt cancellation tills provet svarar. |
| AudioLibrary | 19 fall, inklusive begärandepolicy för mobildata och bevarade filer vid ändrat val, inklusive nytt återförsök efter lagringsfel i samma instans, reparation av trasig vers med orörda färdiga byte samt sena svar efter radering/nytt jobb. Vers/sura/recitatör, MPEG-/ID3-validering, diskåteröppning, avgränsad radering, felaktig lagring och lagringsfel. Kontrollerad nedladdning provar exakt URL, fortsättning efter avbrott, avbrytning, sena svar, HTTP/MIME/storleksfel och städning av temporära filer. |
| RecitationPlayer | Riktig AVPlayer-uppspelning av egna korta PCM-WAV-filer: start, naturligt slut, automatisk nästa vers, surans sista vers och enstaka övningsvers. Även trasig lokal fil/återförsök, sena händelser, sparade inställningar och uppskjuten laddning vid pausat recitatörsbyte. Simulerad omstart av ljudtjänsten behåller valet, förnyar spelaren och kräver uttrycklig återupptagning. Ett separat långt WAV-prov framtvingar sen native-uppspelning efter paus och kräver riktig motorpaus utan naturligt slut samt fungerande uttrycklig återupptagning. |
| OfflineMP3Playback | Sju prov av verklig MP3-till-PCM-avkodning och AVPlayer med AudioLibrary:s lokala filval för alla tre recitatörer, aktiverad systemljudsession, paus/återstart, naturligt versslut/autospelning, enstaka övningsvers, simulerade avbrotts-/hörlursnotiser, gamla händelser och en ospelbar fil. En genererad svag ton används, inga externa ljudförfrågningar eller röster. |
| AudioDownloadTransport | Sju fall: två nya regressioner för en för tidigt avbruten kropp efter giltiga MP3-ramar och radering/nytt recitatörsjobb under riktig pågående överföring. De fem tidigare proven kommer från [PR #3](https://github.com/AllCrow/Koran-test-/pull/3): riktiga URLSession-download tasks över loopback HTTP. Tre recitatörers lagring och MP3-avkodning, återöppning från disk, HTTP-fel/återupptagning, avbruten kropp och storleksgränser från riktiga download-delegate-callbacks. Överstorleksproven kräver avbrytning före ett öppet svars slut. Begärd HTTPS-adress återställs bara i testets svarsmetadata; extern TLS och verkligt recitationsinnehåll ingår inte. |
| PracticeRecorder | Fördröjd mikrofonbehörighet, avbrytning, sena besked, överlappande försök, ljudavbrott/hörlursnotiser, otillgänglig lagring och städning som bevarar andra filer. Simulerad förlust/omstart av ljudtjänsten avbryter väntande behörighet utan automatisk inspelningsstart. Inget prov spelar in från simulatorns mikrofon eller verifierar den synliga minuträknaren mot en verklig tagning. |
| TafsirRepository (portabla prov) | 23 fall, inklusive borttagen cachemapp, ersättande rotlänk med skydd av externa filer och rotbyte under nätväntan. Käll-/versvalidering, JSON-innehållstyp, bevarade arabiska UTF-8-byte och återöppning av diskcache utan nät. Fel utgåva/referens, skadade filer, lagringsfel, LRU, fil-/bytegränser och länkar provas i isolerade temporära kataloger. Provar ingen extern AlQuran Cloud-förbindelse eller fysisk flygplansläge-användning. |
| Textberedning och sökning | Exakta UTF-8-sekvenser även för kanoniskt likvärdiga strängar, nästlade tajweedregler, säker fallback och begränsad cache. Arabisk tangentbordssökning, alternativa latinska vokalstavningar och validering av vershoppets siffror/intervall. |
| UI-flöden | 12 fall: bevarad läsning samt riktiga tryck för nätval, rapportförhandsvisning, övningskö, ändlig repetition, bibliotekets rätta ljud/text och radering. Läsmarkering och återstart, beständigt bokmärke, surasökning och korrekta kontrollreferenser efter surabyte. Hopp till 2:255 med arabiska siffror, ingen navigationskredit, återstart och senare läsposition. Största tillgänglighetstext, beständigt tajweed-/textstorleksval, veckohistorik och synliga backupkontroller. Även mörkt läge och nästa sura fram till an-Nas utan påhittad nästa sura eller läskredit. |

UI-testerna använder en egen `UserDefaults`-suite per test. Endast Debug-byggen
accepterar det avgränsade testargumentet. Tester raderar inte normala läsdata,
kontaktar ingen analystjänst och ber inte om mikrofonbehörighet. Den aktuellt godkända
PR-körningen matar in arabiska siffror, öppnar sura 112, kontrollerar att den
föregående surans kontroller har ersatts och markerar/bokmärker 112:1. Den
sparade bokmärkesreferensen verifieras också i inställningarna. Proven
kontrollerar inte fysisk mikrofon, ljudrutter eller energiförbrukning. Ljudproven
omfattar faktisk uppspelning av genererade WAV-/MP3-filer i simulatorn, inte
avkodningskvalitet för alla imaminspelningar. Transportproven omfattar både
kontrollerade svar och riktiga lokala HTTP-överföringar, men bevisar inte
externa TLS-förbindelser eller nedladdning/offlineuppspelning på telefonen. Systemets filväljare
och externa filproviders för backup behöver också ett manuellt prov.

De fyra långa positionsfallen kräver inom fem sekunder rätt global
versreferens, hela läsetiketten nära toppen och inom läsytans bredd samt appen
i förgrunden. Den icke-interaktiva etiketten behöver ingen aktiveringspunkt;
alla knappar och reglage kräver fortsatt hittability och verkliga tryck.
Skärmbilder granskas också: 2:255 ska visa första textraderna utan föregående
vers, och mörkt läge ska vara verkligt mörkt. Bakgrund och textkontrast
provas separat. Native ljudkvittens använder aktuella AVPlayer-värden på
huvudkön, inte enbart appflaggor eller ett cachat CombineLatest-par.

Den äldre baslinjens 56 hostade prov och fem UI-flöden redovisas i
[statushistoriken](STATUS_HISTORY_PREMIUM_2026-10-25.md). Den är inte resultat
för dagens utökade källa.

Apples [uppladdningskrav](https://developer.apple.com/news/upcoming-requirements/)
kontrollerades 2026-10-25: App Store Connect kräver Xcode26+/iOS26 SDK sedan
28 april 2026. Den nya konfigurationen använder Xcode26.2/iOS26.2 SDK för
iPhone-paketet och två av simulatorvarianterna. Ett lyckat osignerat bygge
eller simulatorprov ersätter inte signering och en faktisk godkänd
App Store Connect-uppladdning. Minsta stödda iOS17 är en annan inställning
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
