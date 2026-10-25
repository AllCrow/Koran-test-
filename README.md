# Sakina – koranapp för iPhone

Pågående native-app i SwiftUI för **iOS 17 eller senare**. Sakina är arbetsnamnet. Målet är en lugn koranapp med låg värme- och batteribelastning, uppmuntrande läsning och utan obligatorisk månadsprenumeration.

Utvecklingen fortsätter självständigt enligt användarens senaste instruktion. Koden, kraven och verifieringsläget bevaras i projektet. Appen är ännu inte en signerad, enhetstestad eller publicerad produkt.

## Nuvarande funktioner

- Alla **114 suror och 6 236 ayat** lokalt, uppdelade per sura, med valbar tajweedvisning.
- Bundlad **Amiri Quran**-font med ursprunglig OFL-licens och verifierade filhashar.
- Tre recitatörer: Mishary Rashid al-Afasy, Mahmoud Khalil al-Husary och Muhammad Siddiq al-Minshawi.
- En ljudfil per vers. Versmarkering och versbyte följer AVPlayer-händelser; låsskärmskontroller och sparade ljudval är implementerade.
- Uttryckliga ljudnedladdningar per sura och recitatör; spelaren föredrar sparat lokalt ljud. Inget recitationsljud är förpaketerat.
- Tafsir al-Muyassar på arabiska, hämtad online med källangivelse.
- Lokala bokmärken, läsposition, dagligt läsmål och en uppmuntrande streak.
- Lokal inspelning och återlyssning för övning, med bevarad tagning och tydliga val före ersättning/radering.
- En integrerad **experimentell analysväg** med separat Muaalem-backend, typad iOS-klient och återkopplingsvy. Den är **avstängd som standard** och har ingen konfigurerad serveradress.

Läsning och tajweeddata fungerar utan nätverk. Ljud behöver hämtas först för att kunna spelas offline; tafsir kräver nät. Den native ljudnedladdningen och uppspelningen har ännu inte provats på iPhone.

**Tarteel-kvalitetsmålet är inte uppnått eller verifierat.** Analysvägen ger inga övergripande uttalsbetyg och laddar inte automatiskt upp inspelningar. Ingen publik analystjänst är driftsatt. Verklig CPU-inferens har körts genom API:t, senast med 35 indata: 33 referensklipp från al-Fatiha och al-Ikhlas med tre recitatörer samt annan-vers- och tystnadskontroller. 32 referensklipp gav inga indikationer; en indikation i al-Afasys 112:2 behöver sakkunnig källklippsgranskning och är inte klassificerad som rätt eller fel. Detta är funktionsprov utan uppmätt generell träffsäkerhet. Se [resultaten](docs/MODEL_SMOKE_RESULTS.md).

Se [kraven](KRAV.md), [aktuell status](STATUS.md), [modellundersökningen](docs/RECITATION_RESEARCH.md) och [backendens installations- och driftguide](backend/README.md).

## Provköra med bara iPhone

Du behöver inte äga en Mac, men appen behöver byggas och signeras i en macOS-miljö. Ett GitHub Actions-flöde för tester och osignerat simulatorbygge är förberett; inget lyckat Xcode-bygge är ännu bekräftat. En simulatorartefakt kan **inte** installeras på en fysisk iPhone.

Distributionsvägen är en betrodd molnbaserad Mac, Apple Developer-medlemskap, App Store Connect och korrekt signering, därefter TestFlight. Dessa delar är ännu inte färdiga. Inga Apple-uppgifter eller signeringsnycklar ingår i Git. Eventuella Apple- och byggkostnader är projektets distributionskostnader, inte en obligatorisk månadsavgift för appens användare.

## Bygga och kontrollera

På en Mac med Xcode 16 eller senare: öppna `Sakina.xcodeproj`, välj schemat `Sakina` och en iPhone-simulator. Det lokala Swift-paketet innehåller biblioteken `QuranCore`, `QuranData` och `QuranPractice`. För en fysisk iPhone behövs eget team, bundle-ID och signering.

```sh
swift test
python3 scripts/verify_content.py
python3 scripts/export_practice_references.py --verify
python3 scripts/verify_assets.py
xcodebuild -project Sakina.xcodeproj -scheme Sakina \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Efter tillägg av Swift-filer eller resurser: kör `python3 scripts/generate_project.py` och checka in det uppdaterade projektet. Generatorn kräver bara Python 3.

**Verifierat hittills:** 61 portabla Swift-tester passerar: 22 för kärnlogik, 18 för data och 21 för analyskontrakt/referenser. Backendens 28 tester passerar, inklusive riktig M4A/AAC-/WAV-avkodning, upprepad avbrytning och avgränsade madd arid-varianter. Ett verkligt CPU-prov och lokala Docker-startkontroller har också genomförts. Åtta hostade iOS-tester och tre UI-flöden är förberedda men **inte körda**. Inget av detta ersätter ett Xcode-bygge eller en fysisk iPhone-körning. Se [STATUS.md](STATUS.md) och [native-proven](docs/IOS_VERIFICATION.md).

## Struktur

| Sökväg | Innehåll |
| --- | --- |
| `App/` | SwiftUI, lokal appstatus, AVPlayer, ljudnedladdningar och inspelning |
| `Sources/QuranCore/` | Versreferenser, tajweedparser, textpresentation och streak |
| `Sources/QuranData/` | Koran- och tafsirrepositoryer |
| `Sources/QuranPractice/` | Analyskontrakt, klient, Unicode-markering och separat referensutgåva |
| `Tests/` | Portabla tester för de tre biblioteken |
| `AppTests/`, `AppUITests/` | Förberedda native-tester av sparad läsprogression och läsflöden |
| `App/Resources/Quran/` | Källtext, originalögonblicksbilder och notiser |
| `App/Resources/Fonts/` | Amiri Quran och ursprunglig licens/proveniens |
| `backend/` | Valbar experimentell Muaalem-tjänst, beroendepinnar och kontrakttester |
| `docs/RECITATION_RESEARCH.md` | Modellkandidater, publicerad utvärdering och genomförda referenskontroller |
| `scripts/` | Import, export, innehålls-/resurskontroller och projektgenerering |
| `.github/workflows/ios.yml` | Förberett macOS-test- och simulatorbygge |

## Experimentell analys och integritet

Standardinställningarna i `App/Info.plist` är `SAKINA_ENABLE_EXPERIMENTAL_ANALYSIS=false` och en tom `SAKINA_ANALYSIS_URL`. Lokal inspelning och återlyssning fungerar oberoende av analystjänsten. För en aktiverad experimentell byggversion behövs en nåbar HTTPS-tjänst och en uttrycklig analysåtgärd som skickar inspelningen. Se [backendguiden](backend/README.md). Vikter och serverhemligheter ska hållas utanför Git.

Återkopplingen använder en separat, verifierad övningsutgåva på cirka **2,01 MB**. Backend och app validerar samma text. Dess Unicode-positioner flyttas inte till läsvyns andra koranutgåva. Referensernas fonemkompatibilitet är kontrollerad för alla 6 236 ayat; det bevisar inte att modellen rättar människors uttal korrekt.

Läsdata och lokala övningsinspelningar sparas på telefonen. EveryAyah och AlQuran Cloud ser de förfrågningar som behövs för ljud respektive tafsir. Appen har inga konton, betalflöden, annonser eller analys-SDK:er.

## Källor, REA och bevarande

Korantextens proveniens och hashmanifest finns i [CONTENT_SOURCES.json](CONTENT_SOURCES.json) och [textnotiserna](App/Resources/Quran/NOTICE.txt). Fontens källa och licens finns i [fontnotisen](App/Resources/Fonts/SOURCE.md). Rättigheter för ljuddistribution och övrigt externt innehåll behöver slutföras före offentlig release.

[REA](https://github.com/morluto/rea) finns separat och har faktiskt inspekterat Muaalems hämtade viktfil: 816 F32-tensorer, 605 754 251 deklarerade element och verifierad fullfilshash. Se [REA-evidensen](docs/REA_MODEL_INSPECTION.md). Det är inget beroende i appen. Tarteels app eller servrar har inte analyserats. Modellvikterna ligger i en extern cache och ingår inte i Git eller iPhone-appen.

Ett separat **privat repo under AllCrow** är begärt. Skapandet nekades av GitHub-integrationen med HTTP 403; ingen lyckad uppladdning är bekräftad. Arbetet är bevarat lokalt i Git medan utvecklingen fortsätter. Aktuella hinder, testresultat och återstående releasekrav finns i [STATUS.md](STATUS.md).
