# Sakina – utvecklingsstatus

Uppdaterat **2026-10-25**. Native-app för personligt iPhone-prov, iOS 17+.
Ljud, inspelningslivstid, offlinefiler, läsdata och textberedning har härdats.
Direkt vershopp och säkerhetskopiering av läsdata är tillagda.
**Långt vershopp och samtliga 61 native-prov har passerat Mac-CI.** Personlig signering,
fysisk installation och en offentlig apprelease är inte verifierade.

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

Huvudgrenens arbete är integrerat med bevarad Git-historik. UI-proven hittade
ett långt hopp som landade kring 2:239 i stället för 2:255. Rättningen i
`7657e3a` binder kapitlet före LazyVStack så att varje vers exponeras direkt
som scrollTargetLayout-mål. Samma strikta UI-krav och femsekundersgräns
passerar nu: exakt målvers, återstart, upprepat hopp, senare läsposition och
korrekt läskredit. Äldre misslyckade körningar är inte releasegodkännanden.

## Aktuell källversion och verifiering

[Den samlade körningen 40164031500](https://github.com/AllCrow/Koran-test-/actions/runs/40164031500)
är **completed/success** på branchkälla
**09e2239ee561bbb20487506ede1ddf939dd64a42**. GitHubs faktiska PR-checkout
är **35a26792f457828306e420607f73e33aa4b6c045**; den är hämtad och dess
kompletta filträd är byteidentiskt med branchkällan. Jobbloggar och
artefakternas head-SHA har lästs. Den efterföljande integrationen av huvudgrenens
dokumentation och denna resultatuppdatering ändrar bara Markdown, ingen
appkod, testkod eller bygginställning. Ingen ny Mac-körning påstås för dokumentationen.
Mac-miljön använder Xcode 16.4 och iPhone 16 Pro/iOS 18.5-simulator, arm64.

| Kontroll | Observerat resultat | Omfattning |
| --- | --- | --- |
| Fysiskt iPhone-bygge | **Godkänt** | Release, iPhoneOS/arm64. Enhetsbygge innebär inte enhetsprov eller signering. |
| Simulatorbygge | **Godkänt** | Riktig Apple SDK, SwiftUI, AVFoundation och lokala paket. |
| Portabla Swift-tester | **67 macOS / 65 Linux passerade** | 23 kärn-, 19 data- och 23 gemensamma övningsprov samt två Darwin-prov av stor respons och avbruten överföring. Linux storlekskontroll sker efter buffring; ingen hård överföringsgräns påstås där. |
| Hostade native-/UI-prov | **61 av 61 passerade** | 56 hostade prov och samtliga fem UI-flöden, noll fel. Långt vershopp, återstart och senare läsposition passerar. |
| Backendtester | **32 passerade** | Riktig ffmpeg-avkodning av M4A/AAC/WAV, kontrakt, referenser, gränser och avbrytning. ResourceWarning som fel. Ingen akustisk kvalitetsmätning. |
| Koran/övningsreferenser/font | **Godkända** | 114 suror, 6 236 referenser, exakt källtext, hashmanifest och fonem-/fontkontroller. Ingen arabisk lästext ändrad. |
| Xcode-projekt | **Deterministiskt** | 14 appfiler, sex hostade testfiler, en UI-testfil och tre lokala bibliotek. |
| Beständig ägarnedladdning | **Verifierat releaseutkast för bygge 23** | Main-körning 40163850515 är success. Utkastet personal-build-23-1 har isDraft=true och källmål 7657e3a. Ingen publik apprelease. |
| Fysisk iPhone/signering/energi | **Inte provat** | Mikrofon, verkligt nät/offlineljud, ljudrutter, filväljare, värme och batteri återstår. |

Native-sviterna består av 12 AppStore-, 13 AudioLibrary-, nio PracticeRecorder-,
sju RecitationPlayer-, sju OfflineMP3Playback- och åtta text-/sök-/vershoppsprov.
Spelarproven använder genererade PCM-WAV- och MP3-filer. Kontrollerad
transport och behörighetsbesked ersätter inte fysisk mikrofon eller verklig
EveryAyah-nedladdning. UI-flöden provar läsmarkering, bokmärken, surasökning,
2:255/återstart/senare läsposition samt största tillgänglighetstext och
beständigt tajweedval. [Omfattning](docs/IOS_VERIFICATION.md) och
[evidens](docs/evidence/readiness-verification-2026-10-25.md).

CI-artefakter för den samlade körningen lagras till 2026-11-01:
native-resultat **12587593518**, skärmbilder **12587248929**,
simulatorapp **12587324023** och fysisk osignerad IPA **12588100162**.
Simulatorappen går inte att installera på fysisk iPhone.

Den separat hämtade IPA:n från samma körning är **0.1.0 (24)**,
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

En riktig osignerad **iPhoneOS/arm64-IPA, version 0.1.0 (23)** är byggd och hämtad:

- Fil: Sakina-iPhone-unsigned.ipa, **3 104 771 byte**, iOS **17.0+**.
- SHA256: **e9d1a927d131656e92f91eaffc8aacc8dbb41d4bb277eaf259323b572c1d911e**.
- Artefakt: Sakina-iPhone-personal-unsigned, ID **12586829932**,
  i [körning 40163850515](https://github.com/AllCrow/Koran-test-/actions/runs/40163850515).

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
  och arabiska namn/siffror utan ändrad källtext.
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
