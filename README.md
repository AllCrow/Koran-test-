# Sakina – koranapp för iPhone

Pågående native-app i SwiftUI för **iOS 17 eller senare**. Sakina är arbetsnamnet. Målet är en lugn koranapp med låg värme- och batteribelastning, uppmuntrande läsning och utan obligatorisk månadsprenumeration.

Den utökade stabilitetsrundan förbättrar läskomfort, veckohistorik, offline-tafsir, nedladdningar och återhämtning vid ljudavbrott. Källkoden, kraven och verifieringsläget bevaras här. Appen behöver fortfarande personlig signering och provning på en fysisk iPhone.

## Nuvarande funktioner

- Alla **114 suror och 6 236 ayat** lokalt, uppdelade per sura, med valbar tajweedvisning.
- Bundlad **Amiri Quran**-font med ursprunglig OFL-licens och verifierade filhashar.
- Fyra sparade arabiska textstorlekar, med förhandsvisning från den bundlade korantexten. Valet gäller läsning, tafsir och övning tillsammans med iPhones Dynamic Type.
- Sparat val mellan ljust läge, mörkt läge och att följa iPhone, med anpassad textkontrast.
- Tre recitatörer: Mishary Rashid al-Afasy, Mahmoud Khalil al-Husary och Muhammad Siddiq al-Minshawi.
- En ljudfil per vers. Versmarkering och versbyte följer AVPlayer-händelser; låsskärmskontroller och sparade ljudval är implementerade.
- Uttryckliga ljudnedladdningar per sura och recitatör; spelaren föredrar sparat lokalt ljud. Inget recitationsljud är förpaketerat.
- Samlat ljudbibliotek med kontrollerad lagring, avskilda skadade filer och radering per sura/recitatör. Sparat ljud öppnar rätt text och binds till sin lokala fil även vid nytt försök.
- Ändlig repetition av ett versintervall, 1–20 omgångar och 0–15 sekunders paus, driven av verkligt versslut.
- Sparat nätval för mobildata eller Wi-Fi-krav på nytt ljud; sparat ljud fungerar lokalt.
- Ordnad övningskö med högst 200 verser, omstart och additiva läskopior utan automatisk läskredit.
- Uppdateringsprov med frysta äldre format och en frivillig felsökningsrapport att granska före export.
- Tafsir al-Muyassar på arabiska med källangivelse. Tidigare öppnade förklaringar kan sparas lokalt för senare offlinebruk i en begränsad och validerad cache.
- Lokala bokmärken, läsposition, dagligt läsmål, en uppmuntrande streak och en översikt över de senaste sju läsdagarna.
- Återupptagning på versnivå efter manuell rullning eller valet **Spara läsplats här**, utan automatisk läskredit. Ljudets sekundposition sparas inte.
- Surasökning med arabiska siffror och vanliga latinska stavningar samt direkt **Gå till vers** i läsmenyn.
- Separat offline-sökning i den arabiska verstexten med eller utan vokaltecken. Träffar visar källtexten och öppnar rätt vers; svensk översättning och translittererad verstext ingår inte.
- Samlad källvy med exakta textutgåvor, Hafs-numrering och tydligt skild tafsir. Vid varje vers kan användaren skapa, granska och själv exportera en lokal innehållsrapport utan automatisk sändning.
- Export och återställning av lokal läsdata via Filer, med sammanfogning av bokmärken och läsdagar.
- Lokal inspelning och återlyssning för övning, med bevarad tagning, synlig inspelningstid upp till en minut och tydliga val före ersättning/radering.
- Återhämtning när iOS ljudtjänst startas om: recitationsvalet behålls och uppspelning återupptas först efter en uttrycklig åtgärd.
- En integrerad **experimentell analysväg** med separat Muaalem-backend, typad iOS-klient och återkopplingsvy. Den är **avstängd som standard** och har ingen konfigurerad serveradress.

Den nya [läsförbättringsomgången](docs/READING_IMPROVEMENTS_2026-10-25.md)
är implementerad i källkoden. Dess native-verifiering pågår/återstår; tidigare
godkända byggresultat nedan godkänner inte automatiskt den nya koden.

Läsning och tajweeddata fungerar utan nätverk. Ljud behöver hämtas först för att kunna spelas offline. Ny tafsir kräver nät; lokalt sparade förklaringar kan öppnas även efter appstart utan nät. Cachen prioriterar nyligen öppnade förklaringar och omfattar högst 64 poster, 4 MiB totalt och 128 KiB per sparad post. Hela tafsiren är inte paketerad för offlinebruk. Ljudproven omfattar kontrollerad transport och riktiga URLSession-överföringar över lokal HTTP; nät och ljud på fysisk iPhone återstår.

**Tarteel-kvalitetsmålet är inte uppnått eller verifierat.** Analysvägen ger inga övergripande uttalsbetyg och laddar inte automatiskt upp inspelningar. Ingen publik analystjänst är driftsatt. Verklig CPU-inferens har körts genom API:t: ett tidigare prov med 35 indata och ett senare prov med **18 hela referensklipp från sex ytterligare suror**, med samtliga tre recitatörer. De 18 nya klippen gav inga presenterade indikationer. Ett tidigare fall i al-Afasys 112:2 behöver fortfarande sakkunnig granskning och har inte klassificerats som rätt eller fel. Proven mäter inte generell träffsäkerhet eller vilka elevfel som missas. Se [resultaten](docs/MODEL_SMOKE_RESULTS.md).

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
behöver fortfarande verifieras. Minsta körversion iOS17 är en annan
inställning än bygg-SDK:n. Den personliga installationsvägen
beskrivs i [SideStore-guiden](docs/PERSONAL_IPHONE_INSTALL.md).

**Aktuell verifiering:**

[Huvudkörning 63](https://github.com/AllCrow/Koran-test-/actions/runs/40218507319) är **avslutad med alla sex jobb godkända**.
Varje simulator utförde **139 hostade + 12 UI-fall**, samt separat
**89 portabla Mac-fall**. Backendjobbet passerade **57 fall**, inklusive
21 befintliga utvärderingskontraktsprov. Det är **151 unika native-/UI-fall och
453 exekveringar** över tre konfigurationer.

Källa `dd0f159dbf60d5daa839bafd252dc80091cc18aa`, komplett Git-träd `b082e40e92f85cabd8d6bf66e7f1e228f9cccd1b`. Den hämtade
[PR-checkouten](https://github.com/AllCrow/Koran-test-/actions/runs/40216509406) `3da7cf46d0680815618ccfbe2401537b455d2a48` har samma hela träd.
[Leveransbeviset](docs/evidence/library-delivery-63-2026-10-25.json) binder individuella passrader, råloggar,
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
[Originalunderlaget och sex kodhashar](docs/evidence/live-recitation-native-library-2026-10-25.json) binds till den
aktuella källans sex granskade ljud-/lagringsfiler. Körkällan är
`b7725676b6ea578a5be4daec98c784bffb8087b1`; detta är ingen ny körning av hela appen eller dess UI.
Rålogg, API-metadata, ZIP och tre ursprungliga JSON-bilagor är återkontrollerade.
Provet använder normal `playOnce`. Den nya bundna sessionsvägen
`playSavedOnce` täcks separat av det genererade MP3-provet i normalmatrisen.
De tre källfallen ingår inte i matrisens 151/453.

Personlig signering och fysisk installation, mobilradio, låsta repetitionspauser,
ljudrutter, Files-export, VoiceOver och energi återstår. Automatisk analys är av;
ingen ny akustisk noggrannhet eller Tarteel-jämförelse påstås.

[Omgångens underlag](docs/LIBRARY_REPETITION_2026-10-25.md) redovisar faktisk
simulatorverifiering. Bygge53:s separata [prov med riktiga recitationer](docs/LIVE_RECITATION_AUDIT.md)
är historiskt underlag för dess exakta källa, inte ett nytt prov av senare ändrad
ljudkod. Personlig installation beskrivs i [guiden](docs/PERSONAL_IPHONE_INSTALL.md).

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

[Innehålls- och ljudgranskningen](docs/CONTENT_RIGHTS.md) dokumenterar de
faktiskt lästa villkoren och de kvarvarande glappen för EveryAyah och tafsir.
Alla 6 236 versfilnamn listas för var och en av appens tre recitatörer.
Femton hela MP3-filer har matchat utgivarens checksummor och avkodats med
ffmpeg på Linux. Detta är källspårbarhet, inte native-uppspelning eller
sakkunnigt godkänd recitationskvalitet.

[REA](https://github.com/morluto/rea) finns separat och har faktiskt inspekterat Muaalems hämtade viktfil: 816 F32-tensorer, 605 754 251 deklarerade element och verifierad fullfilshash. Se [REA-evidensen](docs/REA_MODEL_INSPECTION.md). Det är inget beroende i appen. Tarteels app eller servrar har inte analyserats. Modellvikterna ligger i en extern cache och ingår inte i Git eller iPhone-appen.

Användaren har skapat [AllCrow/Koran-test-](https://github.com/AllCrow/Koran-test-) och uttryckligen godkänt att repot är **publikt tills vidare**. Det ersätter det tidigare önskemålet om privat lagring för den aktuella uppladdningen. Ändring av synlighet nekas fortfarande integrationen (403) och behöver göras av ägaren. All lokal Git-historik bevaras. Faktisk uppladdning, byggresultat och återstående releasekrav redovisas i [STATUS.md](STATUS.md).
