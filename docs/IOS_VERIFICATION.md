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
`AppTests/AudioLibraryTests.swift` tillför sju prov av offlineljudets lokala
filhantering. Alla sju passerade tillsammans med samtliga läs- och UI-prov i
[körningen på a0b2e62](https://github.com/AllCrow/Koran-test-/actions/runs/40154414555).
De använder syntetiska MPEG-ramar och testar inte verklig avkodning eller ljudrutter.

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
| Åtta hostade AppStore-tester | Uttryckliga, unika läsmarkeringar; persistens och återstart; midnatt/DST; systemklockans förändringsnotis; måländring; bokmärken och tajweedval; beskärd detaljhistorik; korrupt sparad data; bundlade kapitel och ogiltigt suraval. |
| Sju hostade AudioLibrary-tester | Rätt lokalt ljud per vers/sura/recitatör; avvisning av fel-/ofullständiga filer och felaktig ID3-storlek; omvalidering av en ändrad fil; återöppning från disk; radering som bevarar andra suror/recitatörer; otillgänglig lagring utan nedladdningsstart. |
| Tre UI-flöden | Läsmarkering utan automatisk läskredit och återstart; sparat bokmärke som öppnar sin vers; tom sökning samt arabiska siffror i surasökning. |

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

Signering och TestFlight återstår. Ett lyckat simulatorprov ersätter inte
ljudrutter, mikrofon, energimätning eller arabisk återgivning på fysisk enhet.
