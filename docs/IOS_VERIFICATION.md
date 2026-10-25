# Native iPhone-verifiering

Uppdaterat 2026-10-25. **Riktigt Xcode-bygge, 15 hostade tester och tre
UI-flöden har passerat** i GitHub Actions på macOS. Körningen använde
Xcode 16.4 och iPhone 16 Pro-simulator med iOS 18.5, arm64.
Den lokala Linuxmiljön saknar fortfarande Apple SDK;
Mac-resultaten kommer från de länkade CI-körningarna. **Ingen fysisk iPhone
eller signering är verifierad.** Aktuella resultat finns i [statusen](../STATUS.md).

## Automatiska prov på macOS

Det genererade Xcode-projektet har tre mål: `Sakina`, `SakinaTests` och
`SakinaUITests`. Schemat `Sakina` kopplar båda testmålen till appen.
`AppTests` omfattar läsdata, arabisk textberedning, ljudlagring, uppspelning
och inspelningens tillstånd. Filproven använder syntetiska MPEG-ramar och
injicerade nedladdningssvar. `OfflineMP3PlaybackTests` kompletterar dem med en
lokalt genererad, faktiskt avkodad MP3-ton och riktig AVPlayer-uppspelning.
PCM-proven använder genererade WAV-filer. Inga mänskliga inspelningar,
externa ljudförfrågningar eller mikrofonbehörigheter behövs för dessa prov.

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
iPhone-ID och sparar en `.xcresult` även om teststeget misslyckas. Flödet är
godkänt i användarens repo [AllCrow/Koran-test-](https://github.com/AllCrow/Koran-test-/actions/runs/40154414555),
kodcommit `a0b2e624406242f85af75e483854a09ce8265919`. Användaren har uttryckligen
godkänt publikt läge tills vidare. Native-resultat och simulatorapp finns som
CI-artefakter med sju dagars lagring. Simulatorappen kan inte installeras på en fysisk iPhone.

| Testgrupp | Avsikt |
| --- | --- |
| Tolv hostade AppStore-tester | Unika läsmarkeringar; persistens och återstart; kalender och systemklocka; måländring; bokmärken och tajweedval; korrupt data; bundlade kapitel; läsbackup, sammanfogning och avvisning av ogiltig import utan dataförlust. |
| Tretton hostade AudioLibrary-tester | Lokalt ljud per vers/sura/recitatör; avvisning av fel-/ofullständiga filer; omvalidering; återöppning och avgränsad radering; lagringsfel; avbrytning före start och under hämtning; återupptagning som bara begär saknade verser. Svaren är injicerade, inte riktiga nätverksnedladdningar. |
| Åtta ArabicTextPreparation-tester | Oförändrad UTF-8 och diakritik, felaktiga annoteringar, nästlade regler, begränsad cache, arabisk och latinsk surasökning samt separat validering av versnummer. |
| Sju RecitationPlayer-tester | Riktig AVPlayer med genererad PCM; uppskjuten laddning vid pausat recitatörsbyte; faktiskt versslut, nästa och sista vers; omförsök efter fel; gamla händelser; sparade val utan förladdning. Systemljudintegrationen är avstängd i denna grupp. |
| Nio PracticeRecorder-tester | Ägda temporärfiler, lagringsfel, avbrytning före och under behörighetsbegäran, sena behörighetssvar, saknad tagning och simulerade avbrotts-/hörlursnotiser. Behörighet och inspelning är injicerade; proven spelar inte in från mikrofonen. |
| Sju OfflineMP3Playback-tester, samlad omkörning återstår | Riktig MP3-avkodning och AVPlayer-händelser med genererad ton; alla recitatörers lokala filval; paus/återstart och sparade val; faktisk versslutshändelse och sista vers; övning av en vers; simulerade avbrotts-/hörlursnotiser; gamla händelser efter nytt suraval; ospelbar lokal fil utan markering. |
| Fem UI-flöden, samlad omkörning återstår | Läsmarkering och återstart; sparat bokmärke; tom, arabisk och latinsk surasökning; direkt vershopp med validering och bevarad läsposition utan läskredit; största textstorlek, tajweedreglage och åtkomliga backupknappar. |

UI-testerna använder en egen `UserDefaults`-suite per test. Endast Debug-byggen
accepterar det avgränsade testargumentet. Tester raderar inte normala läsdata,
kontaktar ingen analystjänst och ber inte om mikrofonbehörighet. Den godkända
UI-körningen matar in arabiska siffror, öppnar sura 112, kontrollerar att den
föregående surans kontroller har ersatts och markerar/bokmärker 112:1. Den
sparade bokmärkesreferensen verifieras också i inställningarna. Proven
kontrollerar inte mikrofon, ljudrutter eller fysisk energiförbrukning.

## Manuella prov på iPhone

Notera appens commit, iPhone-modell och iOS-version tillsammans med resultat.
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

Personlig signering och installation återstår enligt
[installationsguiden](PERSONAL_IPHONE_INSTALL.md). TestFlight är ett alternativ,
inte den prioriterade personliga vägen. Ett lyckat simulatorprov ersätter inte
ljudrutter, mikrofon, energimätning eller arabisk återgivning på fysisk enhet.
