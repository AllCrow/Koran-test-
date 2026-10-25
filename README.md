# Sakina – koranapp för iPhone

Pågående native-app i SwiftUI för **iOS 17 eller senare**. Sakina är arbetsnamnet. Målet är en lugn koranapp med låg värme- och batteribelastning, uppmuntrande läsning och utan obligatorisk månadsprenumeration.

Utvecklingen fortsätter självständigt enligt användarens senaste instruktion. Koden, kraven och verifieringsläget bevaras i projektet. Appen är ännu inte en signerad, fysiskt enhetstestad eller publicerad produkt.

## Nuvarande funktioner

- Alla **114 suror och 6 236 ayat** lokalt, uppdelade per sura, med valbar tajweedvisning.
- Bundlad **Amiri Quran**-font med ursprunglig OFL-licens och verifierade filhashar.
- Tre recitatörer: Mishary Rashid al-Afasy, Mahmoud Khalil al-Husary och Muhammad Siddiq al-Minshawi.
- En ljudfil per vers. Versmarkering och versbyte följer AVPlayer-händelser; låsskärmskontroller och sparade ljudval är implementerade.
- Uttryckliga ljudnedladdningar per sura och recitatör; spelaren föredrar sparat lokalt ljud. Inget recitationsljud är förpaketerat.
- Tafsir al-Muyassar på arabiska, hämtad online med källangivelse.
- Lokala bokmärken, läsposition, dagligt läsmål och en uppmuntrande streak.
- Surasökning med arabiska siffror och vanliga latinska stavningar samt direkt **Gå till vers** i läsmenyn.
- Export och återställning av lokal läsdata via Filer, med sammanfogning av bokmärken och läsdagar.
- Lokal inspelning och återlyssning för övning, med bevarad tagning och tydliga val före ersättning/radering.
- En integrerad **experimentell analysväg** med separat Muaalem-backend, typad iOS-klient och återkopplingsvy. Den är **avstängd som standard** och har ingen konfigurerad serveradress.

Läsning och tajweeddata fungerar utan nätverk. Ljud behöver hämtas först för att kunna spelas offline; tafsir kräver nät. Kontrollerad nedladdning och uppspelning provas i simulatorn; verkligt nät, mikrofon och ljudrutter behöver fortfarande provas på fysisk iPhone.

**Tarteel-kvalitetsmålet är inte uppnått eller verifierat.** Analysvägen ger inga övergripande uttalsbetyg och laddar inte automatiskt upp inspelningar. Ingen publik analystjänst är driftsatt. Verklig CPU-inferens har körts genom API:t, senast med 35 indata: 33 referensklipp från al-Fatiha och al-Ikhlas med tre recitatörer samt annan-vers- och tystnadskontroller. 32 referensklipp gav inga indikationer; en indikation i al-Afasys 112:2 behöver sakkunnig källklippsgranskning och är inte klassificerad som rätt eller fel. Detta är funktionsprov utan uppmätt generell träffsäkerhet. Se [resultaten](docs/MODEL_SMOKE_RESULTS.md).

Se [kraven](KRAV.md), [aktuell status](STATUS.md), [modellundersökningen](docs/RECITATION_RESEARCH.md) och [backendens installations- och driftguide](backend/README.md).

## Installera för personligt bruk

Molnets Mac bygger appen. Den färdiga iPhone-filen kan därefter signeras personligt med en lånad **Mac eller Windows-dator** för första SideStore-installationen. Du behöver inget betalt Developer-medlemskap för den vägen. Enbart iPhone räcker inte för grundinstallationen. En simulatorartefakt kan **inte** installeras på en fysisk iPhone.

För **privat installation** finns en riktig, osignerad iPhoneOS/arm64-IPA från molnbygget. Den behöver personlig signering innan den kan installeras. [SideStore-guiden](docs/PERSONAL_IPHONE_INSTALL.md) beskriver hämtning, gratis signering med vanligt Apple-konto och [det första provet på telefonen](docs/FIRST_IPHONE_TEST.md). Förnyelse behövs normalt före sju dagar, och en dator kan behövas igen vid återställning. Ingen faktisk SideStore-installation är ännu verifierad.

Användaren har uttryckligen valt att behålla iPhone-appen och avstått från Safari/PWA. Om en dator inte går att låna behövs en signerande distributör. För TestFlight-alternativet krävs Apple Developer-medlemskap hos den som publicerar; testaren behöver inget eget betalt medlemskap. Inga Apple-uppgifter eller signeringsnycklar ingår i Git.

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

Apples [aktuella uppladdningskrav](https://developer.apple.com/news/upcoming-requirements/),
kontrollerade 2026-10-25, kräver sedan 28 april 2026 **Xcode 26+ och iOS 26 SDK**
för App Store Connect. CI-proven med Xcode16.4/iOS18.5 bevisar därför inte
att en TestFlight-/App Store-uppladdning accepteras. Den vägen kräver ett nytt
bygge och verifiering samt distributionens signering. Minsta körversion iOS17
är en annan inställning än bygg-SDK:n. Den personliga installationsvägen
beskrivs i [SideStore-guiden](docs/PERSONAL_IPHONE_INSTALL.md).

[Den samlade Mac-körningen](https://github.com/AllCrow/Koran-test-/actions/runs/40164031500)
passerar **67 portabla Swift-tester, 32 backendtester och 61 native-prov**:
56 hostade iOS-prov och alla fem UI-flöden. Sju nya MP3-prov använder riktig
avkodning och AVPlayer med en genererad ton. Långt vershopp och återställning
passerar också med de ursprungliga kraven på exakt vers och läskredit.

Verifieringen omfattar riktiga Xcode-byggen för simulator och fysisk iPhone, portabla Swift-tester, hostade native-prov, UI-flöden och backendtester med riktig ljudavkodning. **Exakt testad källversion, antal och utfall finns i [STATUS.md](STATUS.md).** Ett verkligt CPU-modellprov och lokala Docker-startkontroller har genomförts separat. Fysisk iPhone-provning, personlig signering och energimätning återstår. Se även [native-provens omfattning](docs/IOS_VERIFICATION.md).

## Struktur

| Sökväg | Innehåll |
| --- | --- |
| `App/` | SwiftUI, lokal appstatus, AVPlayer, ljudnedladdningar och inspelning |
| `Sources/QuranCore/` | Versreferenser, tajweedparser, textpresentation och streak |
| `Sources/QuranData/` | Koran- och tafsirrepositoryer |
| `Sources/QuranPractice/` | Analyskontrakt, klient, Unicode-markering och separat referensutgåva |
| `Tests/` | Portabla tester för de tre biblioteken |
| `AppTests/`, `AppUITests/` | Native-prov av läsdata, ljud, inspelningslivstid, textberedning och UI-flöden |
| `App/Resources/Quran/` | Källtext, originalögonblicksbilder och notiser |
| `App/Resources/Fonts/` | Amiri Quran och ursprunglig licens/proveniens |
| `backend/` | Valbar experimentell Muaalem-tjänst, beroendepinnar och kontrakttester |
| `docs/RECITATION_RESEARCH.md` | Modellkandidater, publicerad utvärdering och genomförda referenskontroller |
| `scripts/` | Import, export, innehålls-/resurskontroller och projektgenerering |
| `.github/workflows/ios.yml` | Mac-tester, simulatorbygge, fysisk iPhone-IPA och bevarande som releaseutkast |

## Experimentell analys och integritet

Standardinställningarna i `App/Info.plist` är `SAKINA_ENABLE_EXPERIMENTAL_ANALYSIS=false` och en tom `SAKINA_ANALYSIS_URL`. Lokal inspelning och återlyssning fungerar oberoende av analystjänsten. För en aktiverad experimentell byggversion behövs en nåbar HTTPS-tjänst och en uttrycklig analysåtgärd som skickar inspelningen. Se [backendguiden](backend/README.md). Vikter och serverhemligheter ska hållas utanför Git.

Återkopplingen använder en separat, verifierad övningsutgåva på cirka **2,01 MB**. Backend och app validerar samma text. Dess Unicode-positioner flyttas inte till läsvyns andra koranutgåva. Referensernas fonemkompatibilitet är kontrollerad för alla 6 236 ayat; det bevisar inte att modellen rättar människors uttal korrekt.

Läsdata och lokala övningsinspelningar sparas på telefonen. EveryAyah och AlQuran Cloud ser de förfrågningar som behövs för ljud respektive tafsir. Appen har inga konton, betalflöden, annonser eller analys-SDK:er.

## Källor, REA och bevarande

Korantextens proveniens och hashmanifest finns i [CONTENT_SOURCES.json](CONTENT_SOURCES.json) och [textnotiserna](App/Resources/Quran/NOTICE.txt). Fontens källa och licens finns i [fontnotisen](App/Resources/Fonts/SOURCE.md). Rättigheter för ljuddistribution och övrigt externt innehåll behöver slutföras före offentlig release.

[REA](https://github.com/morluto/rea) finns separat och har faktiskt inspekterat Muaalems hämtade viktfil: 816 F32-tensorer, 605 754 251 deklarerade element och verifierad fullfilshash. Se [REA-evidensen](docs/REA_MODEL_INSPECTION.md). Det är inget beroende i appen. Tarteels app eller servrar har inte analyserats. Modellvikterna ligger i en extern cache och ingår inte i Git eller iPhone-appen.

Användaren har skapat [AllCrow/Koran-test-](https://github.com/AllCrow/Koran-test-) och uttryckligen godkänt att repot är **publikt tills vidare**. Det ersätter det tidigare önskemålet om privat lagring för den aktuella uppladdningen. Ändring av synlighet nekas fortfarande integrationen (403) och behöver göras av ägaren. All lokal Git-historik bevaras. Faktisk uppladdning, byggresultat och återstående releasekrav redovisas i [STATUS.md](STATUS.md).
