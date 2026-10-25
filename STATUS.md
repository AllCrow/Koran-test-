# Sakina – utvecklingsstatus

Uppdaterat **2026-10-25**. Native-app för personligt iPhone-prov, iOS 17+.
Ljud, inspelningslivstid, offlinefiler, läsdata och textberedning har härdats.
Direkt vershopp och säkerhetskopiering av läsdata är tillagda.
**Native-listläsaren, skärpta positionstester och samtliga 61 native-prov har passerat.** Personlig signering,
fysisk installation och en offentlig apprelease är inte verifierade.

## Aktuell samlad verifieringspunkt

PR6 samlar pausgrenarna med bevarad historik. Körning39:s iOS26-fel vid
återstart är dessutom visuellt utrett: hela badgen2:255 ligger vid y129–155,
inom provets y101–251, och versens början syns. Endast läsetikettens
`isHittable` är falsk på den höga native-cellen. Positionshjälparen behåller
alla fyra femsekunderskrav och hela badgen nära toppen, men kontrollerar
app i förgrunden och exakt etikett mot global versidentitet i stället för
textens tapppunkt. Alla interaktiva kontroller behåller hittability och
verkliga tryck. Ingen läsarkod ändras. **Den samlade kandidaten behöver ny CI.**

Kompaktjobbet i körning39 är nu **failure**: alla åtta UI-flöden passerar,
men MP3-provet för hörlursnotis ser rate1 igen efter att rate-KVO kvitterat0.
Det räcker alltså inte att skärpa väntan på appens flagga. Branch
`codex/preserve-explicit-audio-pause` provar nu ett produktionsskydd:
sena native rate-/tillståndshändelser ska åter pausa motorn när användarens
aktuella avsikt är paus. Ett nytt regressionstest använder riktig AVPlayer
och en åttasekunders genererad WAV, injicerar en sen native start efter paus
och kräver motorstopp inom två sekunder utan naturligt versslut. De befintliga
strikta MP3-proven är oförändrade. **Rättningen inväntar native CI.**

Senaste hämtade appkälla är `07088ba8130afbb8daedb52c9d2c2bb71853af85`.
Dess [huvudkörning 40171995960](https://github.com/AllCrow/Koran-test-/actions/runs/40171995960)
är ännu inte godkänd vid kontrollen 2026-10-25 kl07:17 UTC. Den bevarar
integrerade PR3/PR4, huvudgrenens slutliga precisa kompaktgester och
aktuell-SDK-provet på äldre iOS. Spelande långa verser får nu samma toppläge
för att inte dölja början av det som reciteras. Det är en ny kodändring som
behöver sitt faktiska resultat.

Huvudkörningarna 35–38 och den ersatta PR4-körningen36 har avbrutits när ny
källa integrerats. Inget samlat godkännande påstås för dem. Fortsatt oberoende
kodarbete ska ske på arbetsgrenar medan denna leveranskandidat verifieras;
en konstaterad defekt kan motivera en ny kandidat. Tidigare gröna resultat
nedan är historiska och ersätter inte den aktuella helkörningen.

## Pågående verifiering av faktisk nativepaus

Den integrerade PR-körningen
[40169525111](https://github.com/AllCrow/Koran-test-/actions/runs/40169525111)
på `8519f74303025bdc9f5a8549e6969566b617d652` är inte godkänd. iOS26-loggen
visar bland annat att MP3-provet för hörlursnotis såg AVPlayer-rate 1 efter
appens publicerade pausflagga. Flaggan kan också bli falsk vid buffring och
räcker inte som kvitto på att ljudmotorn har pausat.

Branch `codex/native-pause-event-verification` låter därför befintliga pausprov
invänta AVPlayers riktiga rate-KVO med en tvåsekundersgräns. Rate måste bli
noll och appen måste visa paus innan den tre sekunder långa tonen har tagit
slut; naturligt versslut får inte godkänna pausen. Ingen sömn, längre
tolvsekundersväntan, ljudersättning eller produktionsändring införs.
**Det skärpta provet inväntar native CI.** Det avgör ännu inte om den
observerade avvikelsen var en tidig avläsning eller ett produktionsfel.
Huvudgrenens senare läsar-/utseendeändringar och samtliga fyra strikta
kontroller av lång versposition bevaras.

Huvudgrenens [körning 40170146847](https://github.com/AllCrow/Koran-test-/actions/runs/40170146847)
på `f9c77d2889c01e7608d8b59d96235c1b0d5aaa64` passerar 79 hostade och åtta
UI-prov på iPhone16Pro/iOS18.5 och iPhone16e/iOS26.2. Den kompakta iPhoneSE3
passerar alla 79 hostade men faller i ett av åtta UI-prov: svephjälparen
passerar första versens läsknapp vid största tillgänglighetstext och tappar
sedan riktningen när List återanvänder cellen. Skärminspelningen har granskats:
knappen syns först delvis under tabbraden och nästa hela svep hamnar på vers2.
Den samlade körningen är därför **failure**, inte godkänd leverans.

Samma verifieringsbranch begränsar nu kontrollsökningens drag till det
återstående avståndet och högst 40 procent av läsytan. Riktningen bevaras
medan målcellen är återanvänd. Kraven på helt synlig, nåbar kontroll,
44-punkters mål och verkligt ändrat/sparat värde behålls. Ingen läsarkod eller
strikt verspositionskontroll ändras. De båda skärpta proven inväntar ny CI.

## Pågående verifiering av HTTP-nedladdning

Branch `codex/native-download-transport-verification` tillför fem hostade
`AudioDownloadTransportTests` med en server bunden till 127.0.0.1 och riktiga
URLSession-download tasks. Proven kontrollerar avkodningsbara sparade MP3-filer
för alla tre recitatörer, diskåteröppning, HTTP-fel/återupptagning, avbrytning av
ett öppet svar samt annonserad och okänd överföringsstorlek över gränsen.
Överstorleksproven lämnar kroppen ofullständig; nedladdningsdelegaten måste
avbryta före EOF för att de ska passera. Den befintliga genererade MP3-tonen
delas utan ändrade ljudbytes.

Testadaptern skickar bytes över lokal HTTP och återställer den begärda
HTTPS-adressen i svarens metadata så att AudioLibrary:s ordinarie
filantagning kan köras. Det är inte ett prov av extern TLS, EveryAyah,
innehållsrättigheter, fysisk mikrofon eller energi. Källtext, HTTPS-/ATS-policy
och uppladdningsbeteende ändras inte.

[Första körningen 40167394800](https://github.com/AllCrow/Koran-test-/actions/runs/40167394800)
klarade tre nya transportprov, men båda överstorleksfallen nådde nätverkstimeout
(-1001) i stället för storleksavbrott. Övriga hostade prov och alla fem UI-flöden
passerade. En native nedladdningsbrygga använder nu URLSessionDownloadTask med
sessionens download-delegate för progress/avbrytning. Den bevarar en hämtad
fil innan Foundations callback återvänder och äger fortsättning/avbrytning
med låsskydd. Appen använder samma brygga som den verkliga HTTP-testtransporten;
separat HTTPS-policy och befintlig filantagning är kvar.
[Körning 40168296979](https://github.com/AllCrow/Koran-test-/actions/runs/40168296979)
är **completed/success** på `9000a210e29789a51b3b69a67c478ef6c1228611`:
alla fem nya HTTP-prov, 61 hostade och fem UI-flöden (66 native), 67 portabla
Swift-prov och 32 backendprov samt båda byggena passerade. De två öppna
överstorleksfallen avbröts med storleksfel före EOF; okänd längd tog 0,197 s i
denna simulatorfixtur, vilket inte är en fysisk energi-/prestandamätning.

Huvudgrenens senare `1eb0b96` med läskomfort, ljudåterhämtning, tafsircache och
SDK-matris är därefter integrerad utan att skriva över något arbete.
**Den nya samlade versionen behöver nu verifieras på både iOS18.5/Xcode16.4
och iOS26.2/Xcode26.2 innan merge.** Den äldre gröna körningen godkänner
inte automatiskt de nya huvudgrensändringarna.

## MP3-verifiering och läsflöden

[PR #2](https://github.com/AllCrow/Koran-test-/pull/2), branch
`codex/native-audio-playback-verification`, tillför sju
`OfflineMP3PlaybackTests`. En lokalt genererad, svag 440 Hz-ton avkodas från
MP3 till PCM och spelas med riktig AVPlayer och aktiverad systemljudsession
genom AudioLibrary:s lokala filval för alla tre recitatörer. Proven omfattar
paus/återstart, naturligt versslut/autospelning, övning av en vers, simulerade
ljudnotiser, gamla händelser och en ospelbar fil. Ingen röst, mikrofon eller
extern ljudförfrågan används. De bevisar inte kvalitet eller rättigheter för
imaminspelningarna, riktig nättransport eller fysisk energi/ljudrutter.

Huvudgrenens och MP3-grenens arbete är integrerat med bevarad Git-historik.
Den första gröna vershoppssviten klarade rätt versnummer, återstart, upprepat
hopp, senare position och läskredit. Bildgranskningen visade dock 2:255 nära
nederkanten medan föregående vers fyllde skärmen. Läsaren använder därför nu
native List-celler och samma fyra kontroller kräver hela versbadgen nära
toppen inom fem sekunder. Inga godtyckliga sleeps eller längre timeout införs.
Den starkare verifieringen passerar nu och bilden visar 2:255 direkt under
navigationsfältet med versens början tydligt läsbar. Föregående vers syns inte.

## Aktuell källversion och verifiering

[Huvudgrenskörningen 40165021106](https://github.com/AllCrow/Koran-test-/actions/runs/40165021106)
är **completed/success** på exakt app-/testversion **1ba557c3d6bed990504789caa2d01398d897e263**.
Den förenar List-läsaren, skärpta positionstester och samtliga MP3-prov.
Alla fyra jobb är success. Senare ändringar av enbart Markdown ändrar inte
appkod, testkod eller bygginställningar.

**Tidigare verifierad MP3-baslinje:** [40164031500](https://github.com/AllCrow/Koran-test-/actions/runs/40164031500)
var **completed/success** på branchkälla
**09e2239ee561bbb20487506ede1ddf939dd64a42**. GitHubs faktiska PR-checkout
är **35a26792f457828306e420607f73e33aa4b6c045**; den är hämtad och dess
kompletta filträd är byteidentiskt med branchkällan. Jobbloggar och
artefakternas head-SHA har lästs. Detta bevarar MP3-grenens faktiska resultat;
den nyare List-läsaren har sin separat verifierade huvudgrenskörning ovan.
Mac-miljön använder Xcode 16.4 och iPhone 16 Pro/iOS 18.5-simulator, arm64.

| Kontroll | Observerat resultat | Omfattning |
| --- | --- | --- |
| Fysiskt iPhone-bygge | **Godkänt** | Release, iPhoneOS/arm64. Enhetsbygge innebär inte enhetsprov eller signering. |
| Simulatorbygge | **Godkänt** | Riktig Apple SDK, SwiftUI, AVFoundation och lokala paket. |
| Portabla Swift-tester | **67 macOS / 65 Linux passerade** | 23 kärn-, 19 data- och 23 gemensamma övningsprov samt två Darwin-prov av stor respons och avbruten överföring. Linux storlekskontroll sker efter buffring; ingen hård överföringsgräns påstås där. |
| Hostade native-/UI-prov | **61 av 61 passerade** | 56 hostade och fem UI-flöden. Versbörjan nära toppen inom fem sekunder vid hopp, återstart, upprepning och senare position; även visuellt kontrollerat. |
| Backendtester | **32 passerade** | Riktig ffmpeg-avkodning av M4A/AAC/WAV, kontrakt, referenser, gränser och avbrytning. ResourceWarning som fel. Ingen akustisk kvalitetsmätning. |
| Koran/övningsreferenser/font | **Godkända** | 114 suror, 6 236 referenser, exakt källtext, hashmanifest och fonem-/fontkontroller. Ingen arabisk lästext ändrad. |
| Xcode-projekt | **Deterministiskt** | 14 appfiler, sex hostade testfiler, en UI-testfil och tre lokala bibliotek. |
| Beständig ägarnedladdning | **Verifierat releaseutkast för bygge 26** | personal-build-26-1, isDraft=true, källmål 1ba557c. Uppladdad IPA-storlek och SHA256 matchar det återkontrollerade paketet. Ingen publik apprelease. |
| Fysisk iPhone/signering/energi | **Inte provat** | Mikrofon, verkligt nät/offlineljud, ljudrutter, filväljare, värme och batteri återstår. |

Native-sviterna består av 12 AppStore-, 13 AudioLibrary-, nio PracticeRecorder-,
sju RecitationPlayer-, sju OfflineMP3Playback- och åtta text-/sök-/vershoppsprov.
Spelarproven använder genererade PCM-WAV- och MP3-filer. Kontrollerad
transport och behörighetsbesked ersätter inte fysisk mikrofon eller verklig
EveryAyah-nedladdning. UI-flöden provar läsmarkering, bokmärken, surasökning,
2:255/återstart/senare läsposition samt största tillgänglighetstext och
beständigt tajweedval. [Omfattning](docs/IOS_VERIFICATION.md) och
[evidens](docs/evidence/readiness-verification-2026-10-25.md).

CI-artefakter för den aktuella körningen lagras till 2026-11-01:
native-resultat **12588860715**, skärmbilder **12588436510**,
simulatorapp **12588386763** och fysisk osignerad IPA **12588770110**.
Simulatorappen går inte att installera på fysisk iPhone.

**Historiskt MP3-paket:** den separat hämtade IPA:n från PR-körningen 40164031500 är **0.1.0 (24)**,
**3 104 771 byte**, SHA256
`45d4a0d433edf6b4ce7eb260529380d7192393179dac46ee7c92e47a6ea6129a`.
ZIP-integritet, iPhoneOS/arm64, iOS17-minimum, källrapport och frånvaro av
provisionerings-/testpaket har återkontrollerats. Byggrapportens källversion
är PR-checkouten ovan. Den är osignerad; ingen installation är utförd.

Apples [uppladdningskrav](https://developer.apple.com/news/upcoming-requirements/)
lästes 2026-10-25: App Store Connect kräver sedan 28 april 2026 **Xcode 26+
och iOS 26 SDK**. De verifierade proven med Xcode16.4/iOS18.5 godkänner inte
en sådan uppladdning. Nytt bygge och verifiering krävs inför eventuell
TestFlight-/App Store-distribution. Den personliga installationsvägen kvarstår.

## Installation när en dator finns

En riktig osignerad **iPhoneOS/arm64-IPA, version 0.1.0 (26)** är byggd och hämtad:

- Fil: Sakina-iPhone-unsigned.ipa, **3 108 088 byte**, iOS **17.0+**.
- SHA256: **39c86f27d566869783815576e615b42892b8f6277b0198b10c82a1c28325e480**.
- Artefakt: Sakina-iPhone-personal-unsigned, ID **12588770110**,
  i [körning 40165021106](https://github.com/AllCrow/Koran-test-/actions/runs/40165021106).
- Beständig hämtning: [releaseutkast för bygge 26](https://github.com/AllCrow/Koran-test-/releases).
  Logga in som AllCrow. Utkastet är verifierat opublicerat och bevarar IPA:n
  efter CI-artefakternas sjudagarsgräns.

Det hämtade paketets ZIP, plist, arm64 Mach-O, exekverbara rättigheter och
plattform **IOS** är återkontrollerade. Alla 115 koran-JSON-filer, fonten och
118 övningsresurser matchar källfilerna exakt. Inga testpaket, utvecklarprofiler
eller externa dylib/framework-binärer ingår. Den faktiska appfilen har analys
avstängd och tom serveradress. **IPA-filen är osignerad och installeras inte
genom ett tryck i Filer.**

[Installationsguiden](docs/PERSONAL_IPHONE_INSTALL.md) beskriver kostnadsfri
personlig signering med SideStore, vanligt Apple-konto och en lånad **Mac eller
Windows-dator** för grundinstallation. Datoråtkomst finns ännu inte nu.
Förnyelse behövs normalt före sju dagar, med Wi-Fi och LocalDevVPN; datorn kan
behövas igen vid återställning. Tre aktiva personligt signerade appar inklusive
SideStore är den vanliga gratisgränsen. Ingen faktisk SideStore-installation
är verifierad. Efteråt finns en [kort första provguide](docs/FIRST_IPHONE_TEST.md).
Användaren har valt att behålla native-appen och avstått från Safari/PWA.

## Förbättringar i den här omgången

- **Läsning:** begränsad cache för tajweedberedning med exakta UTF-8-nycklar,
  återanvända färger och förberedd sökindexering. Upprepade sparningar och
  omräkningar av streak undviks. Sökning hittar Fatiha/Faatiha, Ikhlas/Ikhlaas
  och arabiska namn/siffror utan ändrad källtext. Native-listceller återanvänds
  och ger exakt versbörjan vid långa hopp med bevarad sammanhängande sura.
- **Vershopp:** validerat nummerfält med arabiska/västerländska siffror i
  läsmenyn. Global versidentitet och sparad position utan läskredit.
  Senare uttrycklig läsning ersätter den gamla positionen.
- **Återställning:** export/import via Filer, helt validerad före sammanfogning.
  Bokmärken och läsdagar dedupliceras. Avgränsad filläsning, bekräftelse och
  skydd mot sena resultat. Ingen röst, nedladdat ljud eller inställningar ingår.
- **Uppspelning:** pausat recitatörsbyte laddar först vid återupptagning.
  Trasig lokal fil ger råd om radering/ny nedladdning. Riktiga AVPlayer-prov av
  naturligt slut, nästa vers och gamla händelser.
- **Inspelning:** lagringsfel före mikrofonfrågan, avbrytbara behörighetsförsök,
  egna filer städas avgränsat, ingen dubbel återlyssning och skyddat
  ljudsessionsägarskap.
- **Offline:** bara saknade verser hämtas för rätt recitatör. Färdiga filer
  bevaras vid fel. Sena avbrutna svar installeras inte. Lagringsbrist ger
  lagringsråd. HTTP/MIME/längd och temporär städning provas.
- **Nät/backend:** strömmande storleksgräns och avbrytning på Darwin.
  Återkopplingslistan visar 20 poster åt gången med hela markeringen bevarad.
  Backend skiljer högst 1 ms AAC-avkodningssvans från verkligt för långa
  60-sekundersklipp och avvisar ogiltiga nollbreddsändringar/korrupt referensdata.
- **Bygg:** versionsnummer per CI-bygge, fysisk plattformsverifiering,
  testskärmbilder och bevarande av godkända paket som releaseutkast.

## Funktionernas läge

| Del | Implementerat | Återstående kontroll |
| --- | --- | --- |
| Läsning | Alla 114 suror/6 236 ayat lokalt, Amiri Quran, valbar tajweed och vershopp. | Fysisk arabisk återgivning, VoiceOver och längre läspass. |
| Läsprogression | Position, bokmärken, mål, uppmuntrande streak och läskopia. Endast uttrycklig markering räknas. | Filväljare, ominstallation och verkliga kalenderbyten. |
| Recitation | al-Afasy, al-Husary och al-Minshawi, en fil per vers, händelsestyrd versmarkering och native kontroller. | Imaminspelningar, buffring, låsskärm, samtal och headset på fysisk iPhone. Ingen ordtidssynkning är implementerad. |
| Offlineljud | Uttrycklig sura-/recitatörsnedladdning, fortsättning och radering; lokal fil föredras. | Verklig nedladdning/avkodning i flygplansläge och ljudrättigheter. Inget ljud är förpaketerat. |
| Tafsir | al-Muyassar på arabiska online med källangivelse och validerad vers/edition. | Fysisk nät-/felhantering. Ingen svensk eller permanent offline-tafsir ingår. |
| Egen röst | Lokal tagning/återlyssning, högst 60 sekunder, vald vers och bevarat Basmala-val. | Mikrofon, ljudsessioner och verkliga avbrott. |
| Automatisk tajweedhjälp | Experimentell Muaalem-backend och native-klient, **avstängda i standardbygget**, ingen konfigurerad server. | Expertutvärdering, fler regler/sifat, drift och Tarteel-jämförelse. **Kvalitetskravet är inte levererat.** |
| Prestanda/kostnad | Händelsestyrda flöden och avgränsade cacher. Läsning startar ingen tung modell. Inget konto, annonser eller obligatoriskt abonnemang. | Värme, batteri och minne på fysisk iPhone. Serverdrift kan ha separat kostnad. |

## Modell, källor och bevarande

Ingen ny akustisk utvärdering har gjorts i denna omgång. Det tidigare
[verkliga CPU-/API-provet](docs/MODEL_SMOKE_RESULTS.md) omfattar 35 indata:
33 referensklipp från två suror/tre recitatörer, annan vers och tystnad.
32 referensklipp gav noll indikationer; al-Afasy 112:2 gav en indikation som
behöver sakkunnig granskning. Den är inte klassificerad som rätt eller fel.
Inga expertetiketter, generell noggrannhet eller Tarteel-paritet är styrkta.
Sifat-huvudena ger ännu ingen separat återkoppling och ingen liveföljning av
användarens ord ingår. Inspelning laddas bara upp efter uttrycklig analys i ett
separat aktiverat testbygge; standardbygget har ingen sådan tjänst.

Backend använder de fixerade utgåvorna quran-muaalem 0.2.2,
quran-transcript 0.6.4 och modellrevision 01a1ef9fbe40d144ef845101e89ff924aed3fef5.
Viktfilen på cirka 2,42 GB finns i extern utvecklingscache, inte i Git eller
iPhone-appen. [REA-inspektionen](docs/REA_MODEL_INSPECTION.md) verifierar
artefakt/hash/tensordeklarationer, inte akustisk kvalitet. Tarteels app och
servrar har inte analyserats. [Modellunderlag](docs/RECITATION_RESEARCH.md).

Koranens [proveniens](CONTENT_SOURCES.json), [textnotiser](App/Resources/Quran/NOTICE.txt),
[fontlicens](App/Resources/Fonts/SOURCE.md) och separata övningsutgåva bevaras.
Editioner har olika tecken/Basmala-gruppering; modellens Unicodepositioner
flyttas aldrig till läsvyns andra edition. **Ljudrättigheter och övriga
villkor för offentlig release är inte avslutade.**

All kod och tidigare Git-historik bevaras i
[AllCrow/Koran-test-](https://github.com/AllCrow/Koran-test-). Användaren har
uttryckligen godkänt **publikt tills vidare**, vilket ersätter det tidigare
privatkravet för detta repo. Ändring av synlighet nekas integrationen (403);
ägaren behöver utföra ett senare byte till privat. Inga Apple-lösenord,
parkopplingsfiler, serverhemligheter, signeringsnycklar eller modellvikter
ska checkas in.

[Den tidigare statusrapporten](docs/STATUS_HISTORY_2026-10-25.md) bevarar
tidigare byggkörningar, felrättningar, exakta modellmått och historisk
verifiering. Den tidigare Linux-evidensen ligger kvar oförändrad.
Föregående samlat gröna baslinje var
[körning 40156140923](https://github.com/AllCrow/Koran-test-/actions/runs/40156140923)
på bc3e54852ceee1adf26b3d0fa29740f3042bd204.
TestFlight är ett möjligt senare alternativ med en signerande utgivare;
testaren behöver inget eget betalt Developer-medlemskap.

## Vad som återstår före en färdig produkt

1. Personlig signering och det första fysiska provet enligt guiden.
2. Verklig läsning, ljud/textkoppling, nedladdning/offline, tafsir, mikrofon,
   ljudrutter och säkerhetskopiering på telefonen.
3. Uppmätt värme, batteri, minne och svarstid, även under längre pass.
4. Sakkunnig utvärdering av automatisk tajweedhjälp och en jämförelse som
   styrker Tarteel-målet. **Det målet är fortfarande inte uppfyllt.**
5. Slutförda innehållsrättigheter och vald distribution för en offentlig release.
