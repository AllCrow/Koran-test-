# Sakina – koranapp för iPhone

Pågående native-app i SwiftUI för **iOS 17 eller senare**. Sakina är arbetsnamnet. Målet är en lugn koranapp med låg värme- och batteribelastning, uppmuntrande läsning och utan obligatorisk månadsprenumeration.

Utvecklingen fortsätter självständigt enligt användarens senaste instruktion om ytterligare stabilisering och en genomarbetad premiumkänsla inför det första dator-/iPhone-provet. Koden, kraven och verifieringsläget bevaras i projektet. Appen är ännu inte en signerad, fysiskt enhetstestad eller publicerad produkt.

## Nuvarande funktioner

- Alla **114 suror och 6 236 ayat** lokalt, uppdelade per sura, med valbar tajweedvisning.
- Bundlad **Amiri Quran**-font med ursprunglig OFL-licens och verifierade filhashar.
- Fyra sparade arabiska textstorlekar, med förhandsvisning från den bundlade korantexten. Valet gäller läsning, tafsir och övning tillsammans med iPhones Dynamic Type.
- Sparat val mellan ljust läge, mörkt läge och att följa iPhone, med anpassad textkontrast.
- Tre recitatörer: Mishary Rashid al-Afasy, Mahmoud Khalil al-Husary och Muhammad Siddiq al-Minshawi.
- En ljudfil per vers. Versmarkering och versbyte följer AVPlayer-händelser; låsskärmskontroller och sparade ljudval är implementerade.
- Uttryckliga ljudnedladdningar per sura och recitatör; spelaren föredrar sparat lokalt ljud. Inget recitationsljud är förpaketerat.
- Tafsir al-Muyassar på arabiska med källangivelse. Tidigare öppnade förklaringar kan sparas lokalt för senare offlinebruk i en begränsad och validerad cache.
- Lokala bokmärken, läsposition, dagligt läsmål, en uppmuntrande streak och en översikt över de senaste sju läsdagarna.
- Surasökning med arabiska siffror och vanliga latinska stavningar samt direkt **Gå till vers** i läsmenyn.
- Export och återställning av lokal läsdata via Filer, med sammanfogning av bokmärken och läsdagar.
- Lokal inspelning och återlyssning för övning, med bevarad tagning, synlig inspelningstid upp till en minut och tydliga val före ersättning/radering.
- Återhämtning när iOS ljudtjänst startas om: recitationsvalet behålls och uppspelning återupptas först efter en uttrycklig åtgärd.
- En integrerad **experimentell analysväg** med separat Muaalem-backend, typad iOS-klient och återkopplingsvy. Den är **avstängd som standard** och har ingen konfigurerad serveradress.

Läsning och tajweeddata fungerar utan nätverk. Ljud behöver hämtas först för att kunna spelas offline. Ny tafsir kräver nät; lokalt sparade förklaringar kan öppnas även efter appstart utan nät. Cachen prioriterar nyligen öppnade förklaringar och omfattar högst 64 poster, 4 MiB totalt och 128 KiB per sparad post. Hela tafsiren är inte paketerad för offlinebruk. Ljudproven omfattar kontrollerad transport och riktiga URLSession-överföringar över lokal HTTP; nät och ljud på fysisk iPhone återstår.

**Tarteel-kvalitetsmålet är inte uppnått eller verifierat.** Analysvägen ger inga övergripande uttalsbetyg och laddar inte automatiskt upp inspelningar. Ingen publik analystjänst är driftsatt. Verklig CPU-inferens har körts genom API:t, senast med 35 indata: 33 referensklipp från al-Fatiha och al-Ikhlas med tre recitatörer samt annan-vers- och tystnadskontroller. 32 referensklipp gav inga indikationer; en indikation i al-Afasys 112:2 behöver sakkunnig källklippsgranskning och är inte klassificerad som rätt eller fel. Detta är funktionsprov utan uppmätt generell träffsäkerhet. Se [resultaten](docs/MODEL_SMOKE_RESULTS.md).

Se [kraven](KRAV.md), [aktuell status](STATUS.md), [modellundersökningen](docs/RECITATION_RESEARCH.md) och [backendens installations- och driftguide](backend/README.md).

## Installera för personligt bruk

Molnets Mac bygger appen. Den färdiga iPhone-filen kan därefter signeras personligt med en lånad **Mac eller Windows-dator** för första SideStore-installationen. Du behöver inget betalt Developer-medlemskap för den vägen. Enbart iPhone räcker inte för grundinstallationen. En simulatorartefakt kan **inte** installeras på en fysisk iPhone.

För **privat installation** finns en riktig, osignerad iPhoneOS/arm64-IPA från molnbygget. Den behöver personlig signering innan den kan installeras. [SideStore-guiden](docs/PERSONAL_IPHONE_INSTALL.md) beskriver hämtning, gratis signering med vanligt Apple-konto och [det första provet på telefonen](docs/FIRST_IPHONE_TEST.md). Förnyelse behövs normalt före sju dagar, och en dator kan behövas igen vid återställning. Ingen faktisk SideStore-installation är ännu verifierad.

Användaren har uttryckligen valt att behålla iPhone-appen och avstått från Safari/PWA. Om en dator inte går att låna behövs en signerande distributör. För TestFlight-alternativet krävs Apple Developer-medlemskap hos den som publicerar; testaren behöver inget eget betalt medlemskap. Inga Apple-uppgifter eller signeringsnycklar ingår i Git.

## Bygga och kontrollera

På en Mac med **Xcode 26.2**: öppna `Sakina.xcodeproj`, välj schemat `Sakina` och en tillgänglig iPhone-simulator. En separat kompatibilitetskontroll använder Xcode 16.4. Det lokala Swift-paketet innehåller biblioteken `QuranCore`, `QuranData` och `QuranPractice`. För en fysisk iPhone behövs eget team, bundle-ID och signering.

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
för App Store Connect. Det aktuella CI-flödet bygger den personliga IPA:n med
Xcode 26.2 och iOS 26.2 SDK. Det kör också tre simulatorvarianter: iOS 18.5 på
iPhone 16 Pro byggd med Xcode 26.2, iOS 18.5 på iPhone SE (3:e generationen)
med Xcode 16.4, samt iOS 26.2 på iPhone 16e med Xcode 26.2. Därmed provas
även en app byggd med den aktuella SDK:n på en äldre iOS-körmiljö.
Konfigurerade jobb eller ett lyckat osignerat bygge bevisar inte att en
TestFlight-/App Store-uppladdning accepteras. Signering och faktisk uppladdning
behöver fortfarande verifieras. Minsta körversion iOS 17 är en annan
inställning än bygg-SDK:n. Den personliga installationsvägen
beskrivs i [SideStore-guiden](docs/PERSONAL_IPHONE_INSTALL.md).

**Aktuell verifiering:** [Mac-körning40175540017](https://github.com/AllCrow/Koran-test-/actions/runs/40175540017)
passerar **82 portabla Swift-prov,36 backendprov och80 hostade + 8 UI per
simulatorvariant** på iPhone SE3/iOS18.5/Xcode16.4, iPhone 16 Pro/iOS18.5/Xcode 26.2
och iPhone 16e/iOS 26.2/Xcode 26.2. Båda byggena är godkända. App-/test-/byggkällan
i mergad main 8cd977c är byteidentisk med godkänd branch 3511431 och faktisk
Apple-checkout 8ded616d. Nytt pausskydd och ett verkligt sen-start-regressionstest
passerar; alla fyra strikta femsekundersprov av versposition är kvar.
Bilderna av 2:255 har granskats på alla tre varianter. Se [STATUS.md](STATUS.md)
för exakta källor, paket, historik och kvarvarande färdigkriterier.

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

Läsdata och lokala övningsinspelningar sparas på telefonen. Tidigare öppnad tafsir kan också sparas i appens privata lagring; den begränsade cachen utesluts från systemets säkerhetskopiering. EveryAyah och AlQuran Cloud ser de förfrågningar som behövs för nytt ljud respektive ny tafsir. Appen har inga konton, betalflöden, annonser eller analys-SDK:er.

## Källor, REA och bevarande

Korantextens proveniens och hashmanifest finns i [CONTENT_SOURCES.json](CONTENT_SOURCES.json) och [textnotiserna](App/Resources/Quran/NOTICE.txt). Fontens källa och licens finns i [fontnotisen](App/Resources/Fonts/SOURCE.md). Rättigheter för ljuddistribution och övrigt externt innehåll behöver slutföras före offentlig release.

[REA](https://github.com/morluto/rea) finns separat och har faktiskt inspekterat Muaalems hämtade viktfil: 816 F32-tensorer, 605 754 251 deklarerade element och verifierad fullfilshash. Se [REA-evidensen](docs/REA_MODEL_INSPECTION.md). Det är inget beroende i appen. Tarteels app eller servrar har inte analyserats. Modellvikterna ligger i en extern cache och ingår inte i Git eller iPhone-appen.

Användaren har skapat [AllCrow/Koran-test-](https://github.com/AllCrow/Koran-test-) och uttryckligen godkänt att repot är **publikt tills vidare**. Det ersätter det tidigare önskemålet om privat lagring för den aktuella uppladdningen. Ändring av synlighet nekas fortfarande integrationen (403) och behöver göras av ägaren. All lokal Git-historik bevaras. Faktisk uppladdning, byggresultat och återstående releasekrav redovisas i [STATUS.md](STATUS.md).
