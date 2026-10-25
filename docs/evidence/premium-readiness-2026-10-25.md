# Verifieringsunderlag – premiumrundan 2026-10-25

Detta underlag skiljer automatisk verifiering från kvarvarande telefon- och
recitationsprov. Senaste samlade produktstatus finns i [STATUS.md](../../STATUS.md).

## Källkedja och faktiska körningar

- Slutkandidat: `35114317d7faa690fcd6fee641e88eaa6eccc4cb`.
- [PR #6](https://github.com/AllCrow/Koran-test-/pull/6), faktisk PR-checkout:
  `8ded616d03e3ca0a512b1979580d0730d78dfdb3`.
- [PR-körning 44](https://github.com/AllCrow/Koran-test-/actions/runs/40175540017):
  alla tre native-jobb, backend och osignerat iPhone-bygge godkända.
- Integration på `main`: `8cd977c4f2063e51784cc0b7c3fbca75b1760ec3`.
  Alla tre commitversionerna har exakt samma Git-träd:
  `bb29ae36fce16da46c05b35535f30257adab2152`.
- [Huvudkörning 46](https://github.com/AllCrow/Koran-test-/actions/runs/40176707574):
  **avslutad med godkänt utfall i alla sex jobb**. De tre native-loggarna
  bekräftar 80 hostade + åtta UI-prov utan fel och 82 portabla prov vardera.
  Paket-, backend- och releaseutkastjobben passerade också.

Verifieringskällan ovan innehåller appen, testerna, resurserna, backend,
byggskripten, Swift-paketet och CI-flödet. Efterföljande resultatdokumentation
ska bara ändra Markdown; kod-/test-/byggindata jämförs mot den testade källan
före leverans. Befintlig Git-historik och tidigare arbetsgrenar bevaras.

## Provmatris

| Variant | Faktisk konfiguration | PR 44 | Main 46 |
| --- | --- | --- | --- |
| ios18 | macOS 15, Xcode 26.2, iPhone 16 Pro / iOS 18.5 | Godkänd | Godkänd |
| ios18-compact | macOS 15, Xcode 16.4, iPhone SE (3:e generationen) / iOS 18.5 | Godkänd | Godkänd |
| ios26 | macOS 26, Xcode 26.2, iPhone 16e / iOS 26.2 | Godkänd | Godkänd |

Varje godkänd simulatorvariant utförde **80 hostade XCTest-prov och åtta
UI-flöden**, samt separat **82 portabla Swift-prov**. Det är 88 unika native-
och UI-testfall som körs tre gånger, inte 264 olika fall. De 80 hostade är
23 AppStore-, 11 text-/färg-, fem HTTP-transport-, 13 AudioLibrary-, sju
MP3-, 11 inspelnings- och tio spelarprov.

Backendjobbet i huvudkörning 46 passerade **36 prov** med riktig ffmpeg-
avkodning; `ResourceWarning` är ett fel. Modellinferens ingår inte i dessa
kontraktsprov. Koran-/övnings-/fontkontroller och jämförelse av det
återskapade Xcode-projektet ingår i varje native-jobb. Den tidigare
Linux-körningen passerade **80 portabla Swift-prov** på `1eb0b9688657b73e107a3065b21da99f9585d82d`;
`Sources`, `Tests` och `Package.swift` är byteidentiska med slutkällan.
macOS har två extra Darwin-specifika transportprov.

## Reproducerade fel och hur proven behåller sin betydelse

- **För stora nätöverföringar:** två riktiga loopback-prov misslyckades när
  async-downloadvägens per-task-delegat inte fick live-progress. Den
  integrerade URLSessionDownloadTask-bryggan tar emot sessionsdelegatens
  callbacks och avbryter överstora annonserade och chunkade kroppar innan
  servern avslutar svaret. Proven använder verklig lokal HTTP och riktiga
  MP3-byte, utan externa röster. De bevisar inte TLS/EveryAyah på en telefon.
- **Sena ljudhändelser efter paus:** faktisk AVPlayer kunde återgå till
  rate 1 trots senaste pausavsikt. Spelaren bevakar rate och timeControlStatus
  med item-/generationskontroll och pausar motorn när senaste avsikten är
  paus. Ett separat åtta sekunders WAV-prov framtvingar sen native-uppspelning
  och kräver rate 0, `.paused`, samma ljudresurs, inget naturligt slut och
  fungerande uttrycklig återupptagning.
- **Asynkrona provkvittensers ordning:** tidigare MP3-prov kunde läsa ett
  cachat CombineLatest-par i stället för motorns aktuella värden. Slutproven
  väcks på huvudkön och läser då aktuell native rate och timeControlStatus.
  De behåller tidsgränserna och kraven på motor, ljudklocka och uteblivet EOF;
  en publicerad appflagga räcker inte.
- **Stor text på liten skärm:** symmetriska drag med 40 procent av läsytan
  ersätter helskärmsfling som kunde kasta förbi en kontroll. Faktiska tryck,
  hittability, värdeändring, läsreferens och återstart kontrolleras fortfarande.
- **Mörkt läge:** ett tidigare launchargument gav ljusa skärmbilder trots
  godkänt prov. Appen har nu ett riktigt sparat system-/ljust-/mörktval;
  UI-provet väljer Mörkt och återstartar. De nya faktiska bilderna är mörka.
- **Lång vers och iOS 26:s läsetikett:** en oberoende granskning av det
  misslyckade 2:255-provets PNG och AX-träd visade hela rätta badgen på
  `(40,129,55,26.333)` inom det avsedda toppintervallet 101–251 på en
  390×844-skärm. Versens början syntes, utan tangentbord eller dialog.
  Systemets glasyta fanns i AX-trädet; orsaken är inte bevisad som cellhöjd.
  Det korrigerade provet kräver rätt global referens, appen i förgrunden och
  hela etiketten både vertikalt och horisontellt nära toppen inom fem
  sekunder. En läsetikett behöver ingen aktiveringspunkt. Alla interaktiva
  kontroller kräver fortsatt hittability och riktiga tryck.

Avbrutna, ersatta körningar räknas inte som godkännanden. Den starkare
alternativa testdiagnostiken på `codex/native-state-trace-alternative`
bevaras separat men är inte antagen eller verifierad produktkod.

## Oberoende kontroll av iPhone-paketet

Huvudkörning 46:s paketjobb `121118831572` passerade. Artefakt
`12593165562`, `Sakina-iPhone-personal-unsigned`, hämtades via GitHub och
kontrollerades oberoende mot källan:

| Uppgift | Resultat |
| --- | --- |
| Appversion / byggnummer | 0.1.0 (46) |
| IPA-storlek | 3 257 522 byte |
| IPA SHA256 | `c9844553d63bd8bfa1917472614f118062f6ed33f10ddfa69e77a507f64d5d6f` |
| Yttre artefakt-ZIP SHA256 | `d6b279db457815d392d77c0e93f3b09feea853dab01c9a3af7923293b52ac6a7` |
| Byggverktyg | Xcode 26.2 / 17C52, iPhoneOS 26.2 SDK |
| Binär | arm64 Mach-O, iOS-plattform; load command min iOS 17.0.0, SDK 26.2.0 |
| Bundle-ID före personlig signering | `org.example.Sakina` |
| Källresurser | 115 koran-JSON-filer, font och 118 övningsresurser byteidentiska |
| Analys | Flagga av, serveradress tom |

ZIP-integritet, appstruktur, plist och binärens plattform/arkitektur jämfördes.
Inga provisioneringsprofiler, testpaket eller externa biblioteksbinärer ingår.
Detta är inte ett signerings-, installations- eller fysisk-iPhone-prov.

**Releaseutkast 423266346 är bekräftat**, tagg `personal-build-46-1`,
`draft=true`, `prerelease=true`, målcommit exakt som den testade källan.
Release-IPA:ns storlek och SHA256 matchar tabellen. Även byggrapportens och
installationsguidens asset-digests matchar de hämtade filerna.
Arbetsflödet skapade det först efter alla godkända verifieringsjobb.
Stabil ingång är [Releases](https://github.com/AllCrow/Koran-test-/releases),
inloggad som AllCrow. Utkastet har inte publicerats.

## Granskade skärmbilder och bevarande

Huvudkörningens ios18-bilder hämtades med artefakt `12592397770`, SHA256
`f2e005b61ffc0292a8815c93f7b7fef78e718c42f4dedea080222b0318227b35`.
Följande exporter granskades visuellt mot testmanifestet:

- `BC6F5FAA-86B4-4598-902B-71DB570A3D73.png`: verkligt mörkt hem,
  fullt synlig Öppna Koranen-knapp och läsbar text mot mintgrönt.
- `6ADEECA9-DDBB-4258-8A29-15AF69FEEB0B.png`: största tillgänglighetstext,
  radbrutna läshandlingar inom skärmens bredd och läsbar nästa versreferens.
- `E82056ED-84A0-4EBF-B8C6-35B81035F72A.png`: 2:255-badge nära toppen
  och koranversens första rader, utan föregående vers på skärmen.

Även huvudkörningens faktiska iOS 26- och kompakta bilder granskades:
2:255 börjar vid toppen, mörkt hem är mörkt, hela startknappen är synlig
och den kompakta största-textvyn behåller handlingarna inom skärmens bredd.
Bild-ZIP-digests: iOS 26
`14b9d46e3fe35b7971d1c84a5ebd9c53295889bf12b7c07386949071f5ec6dd4`,
kompakt iOS 18
`15cdf7729c7492715a30ad46686e7a00e5ec7c842461e0a7abaccb15f415a6b7`.

Byggena har kvar icke-blockerande deprekeringsnotiser för
`allowBluetooth` och `UITraitCollection.init(traitsFrom:)` med den nya SDK:n.
Inga kompilerings- eller testfel förekom i slutkörningen.

Råloggar, exporterade bildartefakter, paketets metadata och den oberoende
paketrapporten bevaras tillsammans med källarkiv och ett komplett Git-bundle
i arbetsytans slutbackup. CI:s tillfälliga artefakter har sju dagars lagring;
releaseutkastet är den avsedda varaktiga ägarnedladdningen. Inga privata
röstinspelningar, modellvikter eller Apple-/parkopplingsuppgifter ingår.

## Verkligt modellprov och återstående gränser

Det separata utökade CPU-provet använde **18 hela offentliga referensklipp**:
2:1, 9:1, 95:1, 97:1, 113:1 och 114:1 med tre recitatörer. M4A/AAC-inmatningen
var 3,417–19,618 sekunder, utan klippning eller införda uttalsfel. Den fixerade
Muaalem-modellen returnerade `assessed` och noll presenterade indikationer för
alla 18. Två CPU-trådar, 1,976 sekunders modellinläsning, medianinferens
3,3945 sekunder och processens topp-RSS 3 334,6 MiB avser Linuxservern.
Detta är inte telefonmått. Svar, källor och hashvärden finns i
[modellunderlaget](model-expanded-smoke-2026-10-25.json).

Proven saknar lärarmärkta elevfel och verifierar inte uttalsnoggrannhet,
full sifat-bedömning, Basmala-/waqfjustering eller Tarteel-likvärdighet.
Det tidigare 35-indataprovet redovisas separat i
[modellresultaten](../MODEL_SMOKE_RESULTS.md), inklusive en ogranskad indikation.
Standardappen har automatisk analys avstängd och ingen analystjänst.

Personlig signering/installation, mikrofon, externa ljudrutter, riktiga
nät-/offlinefall, Filer-providers, VoiceOver och värme/batteri måste provas
på fysisk iPhone enligt [telefonprovet](../FIRST_IPHONE_TEST.md).
En lyckad simulator eller osignerad binär styrker inte dessa krav.
