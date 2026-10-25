# Sakina – utvecklingsstatus

Uppdaterat **2026-10-25**. Native-app för iPhone, **iOS 17+**.

**Automatisk tajweedbedömning är fortsatt experimentell och avstängd. Ingen
analysserver är konfigurerad och Tarteel-kvalitetsmålet är inte uppfyllt.**

## Senaste fortsättningsrunda

- Samlat ljudbibliotek med kontrollerad lagring, avskilda skadade filer och radering per sura/recitatör. Sparat ljud öppnar rätt text och binds till sin lokala fil även vid nytt försök.
- Ändlig repetition av ett versintervall, 1–20 omgångar och 0–15 sekunders paus, driven av verkligt versslut.
- Sparat nätval för mobildata eller Wi-Fi-krav på nytt ljud; sparat ljud fungerar lokalt.
- Ordnad övningskö med högst 200 verser, omstart och additiva läskopior utan automatisk läskredit.
- Uppdateringsprov med frysta äldre format och en frivillig felsökningsrapport att granska före export.

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

Se [användning och provgränser](docs/LIBRARY_REPETITION_2026-10-25.md) samt
[installationsguiden](docs/PERSONAL_IPHONE_INSTALL.md). Bygge53:s separata
EveryAyah-prov bevaras som historiskt underlag för den då körda källan.

## Historiskt bygge 53

Offlineomgången är **godkänd i [huvudkörning 53](https://github.com/AllCrow/Koran-test-/actions/runs/40192974053)**:
**96 hostade + åtta UI-fall per simulator**, **85 separata portabla Mac-fall**
och **57 backendfall**, varav **21 utvärderingsverktygsprov**. Alla sex jobb
passerade, inklusive det osignerade iPhone-bygget och sparandet av ägarutkastet.
Det är **104 unika native-/UI-fall och 312 exekveringar över tre varianter**.

- Ljudlagring kan återhämtas vid uttryckligt återförsök i samma appsession.
- Färdiga verser bevaras vid fel; trasiga versfiler repareras och sena svar får inte påverka ett nyare jobb.
- Tafsircachen återhämtar en borttagen mapp och avvisar ersättande länkar även efter nätväntan.
- Ett separat [verktyg för tajweedutvärdering](docs/TAJWEED_EVALUATION.md) kan jämföra modellindikationer med sakkunnigas bedömningar. Det ogranskade arkivfallet får fortsatt inga kvalitetsmått.

Källa: `e1bb2625136277beb8f4eab78f17576acc3d56e5`. Faktisk PR-checkout `6897dba0e03072d18c79e14a74d165d5c219232b` har samma
Git-träd `4a769740e82380a90c0b63fc04fe172ffd893fad`. [Ändringar och provgränser](docs/OFFLINE_QUALITY_2026-10-25.md)
och [leveransbevis](docs/evidence/offline-quality-delivery-53-2026-10-25.json) anger exakt omfattning.

Den riktade [källåterkontrollen](https://github.com/AllCrow/Koran-test-/actions/runs/40194584222)
är nu också **godkänd på samma nya källa**: tre befintliga fall på iPhone16e/
iOS26.2, tolv riktiga filer avkodade och lokal 112:2 till native-slut för
varje recitatör utan fallback eller ny nedladdning. Kod-/manifesthashar och
alla originalbilagor är kontrollerade i
[det nya källbeviset](docs/evidence/live-recitation-native-recovery-2026-10-25.json).
De tre fallen är separata från 104/312 och ersätter ingen fysisk provning.

En andra oberoende kontroll av slutloggar, tre 2:255-bilder, IPA/rapport,
källguide, alla 239 resurser och den ogranskade utvärderingens reproducerbara
metadata/resultat finns i [det kompletterande leveransbeviset](docs/evidence/delivery-53-2026-10-25.json).
Originalrösten var inte tillgänglig för denna andra kontroll; dess tidigare
bytekontroll intygas inte på nytt.

Det historiska paketet är **0.1.0 (53)**, **3 271 185 byte**,
iPhoneOS/arm64, minsta iOS17.0 och bygg-SDK26.2. IPA SHA256:
`159cbb58cde06dca919b956b8a4b918339c7d79ec1266de1a31682a404c2c6eb`.
Releaseutkast **423396167**, tagg **personal-build-53-1**, är verifierat
mot rätt källa och samtliga tre nedladdade filers storlekar och SHA256.
Hämta under [Releases](https://github.com/AllCrow/Koran-test-/releases), inloggad
som **AllCrow**, och följ [installationsguiden](docs/PERSONAL_IPHONE_INSTALL.md).
Personlig signering och fysisk iPhone-provning återstår; automatisk analys är av.

## Historiskt bygge 51

Fortsättningsrundan är **godkänd i huvudkörning 51**: **91 hostade + åtta UI-prov på var och en av tre simulatorer**, samt **82 portabla Swift-prov per Mac-variant och 36 backendprov**. **Personligt bygge 51** är sparat som ägaråtkomligt releaseutkast. Personlig signering och fysisk iPhone-provning återstår.

- Förlorad iOS-ljudtjänst stoppar motorn direkt; återställning kräver uttrycklig uppspelning.
- Sammanfogade läskopior kontrolleras före mutation så att en för stor union lämnar läsdata orörd.
- Avbrutna och gamla suraladdningar kan inte ersätta nyare läsning; kallstartens katalog bevaras.

Källa: `c907121e59eab81ae8848e2ca0311ab54f2aa6ec`. [Godkänd huvudkörning](https://github.com/AllCrow/Koran-test-/actions/runs/40186048325).
Det är **99 unika native-/UI-fall och 297 exekveringar över tre varianter**.
Den tidigare 80-provssviten är utökad med elva hostade regressioner.
[Fullständigt underlag](docs/CONTINUED_STABILITY_2026-10-25.md) beskriver källkedja, prov och gränser.

Ett separat [native-källprov](docs/LIVE_RECITATION_AUDIT.md) passerade dessutom
tre fall på iPhone16e/iOS26.2: tolv riktiga EveryAyah-filer hämtades och
avkodades, och en hashkontrollerad lokal 112:2 spelades till native-slut för
varje recitatör utan fallback. De tre opt-in-fallen räknas inte in i 99/297.
Detta är det historiska underlaget för bygge51. Återkontrollen mot bygge53:s
ändrade AudioLibrary är en separat ny körning, redovisad ovan.

Det historiska paketet är **0.1.0 (51)**, **3 269 813 byte**,
iPhoneOS/arm64, minsta iOS 17.0 och SDK 26.2. IPA SHA256:
`279803799a1f3d72626c42ab7e7a651e3859cb528a80625e0c5ef26de5e6854b`.
Releaseutkast **423341980**, tagg **personal-build-51-1**, är verifierat
med rätt källa, asset-storlekar och SHA256. Hämta det under
[Releases](https://github.com/AllCrow/Koran-test-/releases), inloggad som **AllCrow**.
Följ [personlig installation](docs/PERSONAL_IPHONE_INSTALL.md).
Oberoende paketkontroll matchar samtliga tre releasefiler samt alla 239
paketerade källresurser (118 koran-, tre font-/licens- och 118 övningsfiler).
Jobb, filhashar och uttryckliga provgränser finns i
[leveransbeviset för bygge 51](docs/evidence/delivery-51-2026-10-25.json).

## Bevarad verifiering av bygge 46

[PR #6:s körning 44](https://github.com/AllCrow/Koran-test-/actions/runs/40175540017)
har passerat alla tre simulatorvarianter, backendjobbet och det osignerade
iPhone-bygget. Källkandidaten är
`35114317d7faa690fcd6fee641e88eaa6eccc4cb`; GitHubs faktiska PR-checkout är
`8ded616d03e3ca0a512b1979580d0730d78dfdb3`.

| Simulator | Byggverktyg / Mac | Observerat resultat i körning 44 och 46 |
| --- | --- | --- |
| iPhone 16 Pro / iOS 18.5 | Xcode 26.2 / macOS 15 | **80 hostade + 8 UI-prov och 82 portabla Swift-prov: godkända** |
| iPhone SE (3:e generationen) / iOS 18.5 | Xcode 16.4 / macOS 15 | **80 hostade + 8 UI-prov och 82 portabla Swift-prov: godkända** |
| iPhone 16e / iOS 26.2 | Xcode 26.2 / macOS 26 | **80 hostade + 8 UI-prov och 82 portabla Swift-prov: godkända** |

Det är **88 unika native-/UI-prov**, utförda på tre varianter:
**264 godkända native-provexekveringar**. De hostade sviterna består av
23 AppStore-, 11 text-/färgprov, fem HTTP-transport-, 13 AudioLibrary-, sju
MP3-, 11 inspelnings- och tio spelarprov. Det är inte 264 olika testfall.
De portabla proven är separata från native-proven.

Backendjobbet passerade **36 prov**, inklusive riktig ffmpeg-avkodning av
M4A/AAC/WAV; `ResourceWarning` behandlas som fel. Innehålls-, referens-,
font- och projektkontroller passerade också. De **80 Linux-Swift-proven**
kördes tidigare på `1eb0b9688657b73e107a3065b21da99f9585d82d`; deras portabla
indata är byteidentiska med den aktuella källan. macOS har dessutom två
Darwin-specifika överföringsprov, vilket ger 82.

Arbetet är integrerat med bevarad historik på huvudgrenen:
`8cd977c4f2063e51784cc0b7c3fbca75b1760ec3`.
Kandidaten, PR-checkouten och huvudgrenens integration har **byteidentiska
Git-filträd**. [Huvudgrenens körning 46](https://github.com/AllCrow/Koran-test-/actions/runs/40176707574)
är **avslutad med godkänt utfall i alla sex jobb**, inklusive samtliga tre
native-varianter och sparandet av ägarnedladdningen. Antalen ovan har
verifierats även i huvudkörningens faktiska loggar. Exakta loggar och
paketkontroller redovisas i
[verifieringsunderlaget](docs/evidence/premium-readiness-2026-10-25.md).

## Förbättringar som nu ingår

- **Läskomfort:** fyra sparade arabiska textstorlekar med källtrogen
  förhandsvisning, Dynamic Type och val mellan att följa iPhone, ljust eller
  mörkt läge. Tajweedfärgernas numeriska kontrast mot läspapperet provas till
  minst 4,5:1, och minst 7:1 vid ökad kontrast. Huvudknappens text och
  symboler provas också. Fysisk återgivning och VoiceOver återstår.
- **Läsvana:** sju civila läsdagar, faktiska unika markeringar och intjänade
  dagsmål. Datum och läsdata bevaras bättre vid tidszonsbyten och korrigerad
  systemklocka; saknade versdetaljer ger inga påhittade antal.
- **Navigation:** kontinuerlig läsning i återanvända native-celler, direkt
  vershopp och nästa sura utan läskredit. Navigationen slutar vid an-Nas.
  Långa versers början placeras nära toppen även vid uppspelning.
- **Tafsir:** tidigare öppnade al-Muyassar-förklaringar kan läsas efter
  omstart utan nät. Den validerade cachen prioriterar nyligen öppnade poster:
  högst 64, totalt 4 MiB och 128 KiB per fil. Skadade eller felrefererade
  poster visas inte. Nya förklaringar behöver internet; ingen fullständig
  offline-tafsir eller svensk tafsir ingår.
- **Nedladdning:** riktiga URLSession-download tasks med avbrytning från
  nedladdningsdelegaten före en för stor överförings slut. Färdiga verser
  bevaras vid fel och återupptagning hämtar saknade verser. Fem loopback-prov
  använder verklig lokal HTTP och avkodningsbara MP3-filer. De provar inte
  extern TLS, EveryAyah eller rättigheterna till imaminspelningarna.
- **Ljud:** omstart av iOS ljudtjänst förnyar spelaren, behåller valet och
  kräver uttrycklig återupptagning. Sena native-händelser får inte återstarta
  ljudet när användarens senaste avsikt är paus. Proven inväntar verklig
  AVPlayer-KVO på huvudkön och kontrollerar även motorns aktuella tillstånd;
  en publicerad appflagga ensam räcker inte.
- **Övning och läsdata:** synlig inspelningstid upp till en minut med
  uppdatering en gång per sekund endast under en aktiv tagning. Fördröjd
  mikrofonbehörighet och ljudavbrott hanteras utan automatisk inspelningsstart.
  Bokmärken och läshistorik kan exporteras/importeras via Filer, validerat
  och utan dubblering. Exporten innehåller inte röst, ljud eller inställningar.

De fyra långa positionsfallen kräver rätt global versreferens, hela
läsbadgen nära toppen och inom läsytans bredd samt appen i förgrunden inom
fem sekunder. Badgen är en läsetikett. Interaktiva kontroller måste fortsatt
vara nåbara och användas med verkliga tryck. Koranens arabiska lästext är
oförändrad. [Provens omfattning](docs/IOS_VERIFICATION.md).

## Bevarat paket 46 och gemensam installationsväg

**Bygge 46 är byggt, hämtat och oberoende paketkontrollerat efter
huvudkörningens samtliga godkända verifieringsjobb:**

- `Sakina-iPhone-unsigned.ipa`, **0.1.0 (46)**, **3 257 522 byte**.
- SHA256: `c9844553d63bd8bfa1917472614f118062f6ed33f10ddfa69e77a507f64d5d6f`.
- CI-artefakt **12593165562**, källa **8cd977c4f2063e51784cc0b7c3fbca75b1760ec3**.
- iPhoneOS, arm64 Mach-O, minsta iOS **17.0**, bygg-SDK **26.2**.
- Alla **115 koran-JSON-filer, fonten och 118 övningsresurser** matchar
  källfilerna exakt. Inga provisioneringsprofiler, testpaket eller externa
  biblioteksbinärer ingår. Analysflaggan är avstängd och serveradressen tom.

Paketets yttre artefakt-ZIP har SHA256
`d6b279db457815d392d77c0e93f3b09feea853dab01c9a3af7923293b52ac6a7`.
Releaseutkast **423266346**, tagg **personal-build-46-1**, är bekräftat
med `draft=true`, `prerelease=true` och rätt källcommit. Dess IPA, byggrapport
och installationsguide har jämförts mot de hämtade filernas storlek och
SHA256; samtliga matchar. Hämta **Sakina – privat testbygge 46** under
[Releases](https://github.com/AllCrow/Koran-test-/releases), inloggad som
**AllCrow**. Utkastet är inte offentligt publicerat. Tidigare paket och
resultat bevaras i historiken.

En osignerad IPA kan inte installeras genom att trycka på den i Filer.
[SideStore-guiden](docs/PERSONAL_IPHONE_INSTALL.md) beskriver en personlig
gratisväg med vanligt Apple-konto och **Mac eller Windows** för första
installationen. Användaren har för närvarande bara iPhone och väntar på
datoråtkomst. Förnyelse behövs normalt före sju dagar med Wi-Fi och
LocalDevVPN; en dator kan behövas igen vid återställning. Ingen signering
eller SideStore-installation är provad. Safari/PWA har uttryckligen valts bort.

[Det första telefonprovet](docs/FIRST_IPHONE_TEST.md) omfattar läsning och
textstorlek, tre recitatörer, nedladdat ljud i flygplansläge, återöppnad
tafsircache, egen tagning och läskopia via Filer. **Fysisk mikrofon, nät,
headset/Bluetooth, samtal, filproviders, VoiceOver, temperatur och batteri
återstår.** Ingen låg värme eller färdig fysisk stabilitet påstås från
simulatorresultaten.

Ett aktuellt bygg-SDK godkänner inte i sig en Apple-distribution. Signering
och faktisk App Store Connect-/TestFlight-uppladdning är inte verifierade.
Minsta körversion iOS 17 är en annan inställning än bygg-SDK:n. Inget betalt
Developer-medlemskap krävs för den personliga vägen; TestFlight kräver en
signerande utgivare.

## Spårbar kontroll av riktiga recitationer

Den 25 oktober kontrollerades EveryAyahs egna kataloger mot appens exakta
recitatörsmappar och versindex: alla **6 236 kanoniska filnamn** listas
för var och en av de tre recitatörerna. **15 hela MP3-filer** (1:1,
2:255, 9:1, 112:2 och 114:6 för alla tre) hade HTTP 200, korrekt
Content-Length, matchande utgivar-MD5 och lyckad helfilsavkodning med
ffmpeg till PCM. Separata SHA256 binder svar, ljud och avkodningsresultat.
Inga ljudfiler lades i Git och inga nya modellanrop gjordes.

[Käll-/villkorsrapporten](docs/CONTENT_RIGHTS.md) och dess två JSON-underlag
anger faktiska resultat och kvarvarande rättighetsglapp. Ett nytt manuellt
kontrollverktyg körs inte av appen eller normal CI. Detta är Linux-/HTTPS-/
ffmpeg-bevis, inte URLSession/AVPlayer eller fysisk iPhone-verifiering av
imaminspelningarna. Katalogtäckning bevisar inte korrekt ljud i samtliga
6 236 filer. Det tidigare al-Afasy-fallet 112:2 är fortfarande inte
sakkunnigt avgjort. EveryAyah-/tafsirvillkor och Tarteel-kvalitet är öppna.
Denna källgranskning ändrar inte det godkända appbygget 46.

Ett senare **separat native-källprov** har passerat på
iPhone16e/iOS26.2/Xcode26.2: tolv riktiga EveryAyah-filer hämtades och
avkodades via appens standardnedladdare och `AVAudioFile`. Hashkontrollerad
112:2 spelades från återöppnad lokal lagring till faktiskt native-EOF för
alla tre recitatörer, utan fallback. [Lästa loggar och resultatbilagor](docs/LIVE_RECITATION_AUDIT.md).
Det är tre ytterligare opt-in-fall, skilda från ordinarie host-/UI-matris.
Fysisk radio/offlineväxling, hörsel-/klippgränsgranskning och ljudrättigheter
är fortfarande oprövade eller öppna; tajweedindikationen för112:2 är inte avgjord.

## Automatisk tajweedhjälp och REA

Standardbygget har `SAKINA_ENABLE_EXPERIMENTAL_ANALYSIS=false` och tom
`SAKINA_ANALYSIS_URL`. Lokal inspelning och återlyssning är implementerade,
men ingen automatisk uttalslärare är levererad. Analys kräver ett separat
aktiverat testbygge, konfigurerad tjänst och uttrycklig uppladdningsåtgärd.
Läsning startar ingen tung lokal modell.

Det tidigare verkliga CPU-provet omfattade **35 indata**: 33 referensklipp
från två suror och tre recitatörer, annan vers och tystnad. 32 referensklipp
gav noll indikationer; al-Afasy 112:2 gav en indikation som fortfarande är
ogranskad av sakkunnig. Ett nytt CPU-/API-prov omfattar **18 klipp från sex
ytterligare suror med alla tre recitatörer**. Alla returnerade `assessed`
med noll presenterade indikationer. Detta är funktionsprov; noll indikationer
mäter inte korrekthet eller missade elevfel. Expertetiketter, generell
noggrannhet, full sifat-bedömning och Tarteel-jämförelse saknas.
[Resultat och begränsningar](docs/MODEL_SMOKE_RESULTS.md),
[de 18 nya svaren med hash- och källmetadata](docs/evidence/model-expanded-smoke-2026-10-25.json).

Modellrevisionen är fixerad till
`01a1ef9fbe40d144ef845101e89ff924aed3fef5` med quran-muaalem 0.2.2 och
quran-transcript 0.6.4. Modellvikter och ljudprov ligger utanför Git och
iPhone-paketet. [REA-inspektionen](docs/REA_MODEL_INSPECTION.md) verifierar
modellartefakten, inte akustisk kvalitet. Tarteels app eller servrar har
inte analyserats.

## Bevarande och återstående produktkrav

All kod, [kravlistan](KRAV.md) och Git-historik bevaras i
[AllCrow/Koran-test-](https://github.com/AllCrow/Koran-test-). Användaren har
uttryckligen godkänt **publikt tills vidare**, vilket ersätter det tidigare
privatkravet för detta repo. En senare privatändring behöver utföras av
ägaren; integrationen har nekats den åtgärden. Inga signeringsnycklar,
Apple-lösenord, parkopplingsfiler, modellvikter eller röstinspelningar ska
läggas i Git.

Läsning och tajweed finns lokalt utan konto, annonser eller obligatoriskt
abonnemang. Nytt ljud och ny tafsir kontaktar EveryAyah respektive AlQuran
Cloud; sparat innehåll används lokalt. Tafsircachen utesluts från systemets
säkerhetskopiering. Serverinferens och distribution kan ändå ha driftkostnader.
Textens [proveniens](CONTENT_SOURCES.json) och fontlicens bevaras;
ljudrättigheter och övriga villkor inför offentlig release är inte avslutade.

Före en färdig produkt återstår personlig installation, fysiska funktions-/energi-/
tillgänglighetsprov, sakkunnig recitationsutvärdering som styrker
kvalitetsanspråken samt vald distribution och innehållsrättigheter.
[PR #7](https://github.com/AllCrow/Koran-test-/pull/7) är mergad som
`d6d73e50af564758e92713981adbb089232cf77a` efter
[godkänd körning 45](https://github.com/AllCrow/Koran-test-/actions/runs/40176541522).
Den bygger testmålen en gång och kör hostade tjänster före UI, så ett
tjänstefel stoppar jobbet innan de långsammare UI-flödena. Alla tre varianter
utförde fortfarande 80 hostade och åtta UI-prov samt 82 portabla Swift-prov;
36 backendprov och båda byggena passerade. Båda resultatbundlarna finns
återkontrollerade i artefakt12593107496. Faktisk checkout53719af och
branchcba9f3e har identiska filträd. Publicerad app-/test-/bygg-/workflowkod
matchar den godkända källan; skillnaderna är Markdown. Den redan godkända
ägarnedladdningen46 är oförändrad. Ingen extra tung körning begärdes för
identiska verifierade indata.
Den parallella dokumentationscommitten `fbf1dca` och dess status bevaras
i historiken.

Tidigare fullständiga statusar och felsökningsbelägg finns i
[denna omgångs historik](docs/STATUS_HISTORY_PREMIUM_2026-10-25.md)
och [den äldre historiken](docs/STATUS_HISTORY_2026-10-25.md).


## Ny förbättringsrunda 2026-10-25: läsplats, textsökning och källor

Implementationen tillför lokal arabisk verstextsökning, sparad versposition efter
manuell bläddring, ett uttryckligt alternativ för att spara läsplats och en
versbunden granskningsrapport med lokal förhandsvisning/export. Läsning tilldelas
inte kredit genom navigering eller bläddring. Ingen svensk översättning eller
ljudtidsposition har tillkommit.

Lokalt har verifiering av båda koranutgåvorna, övningsreferenser och appresurser
passerat, liksom 57 backendtester. Swift och Xcode saknas i denna Linuxmiljö.
De nya Swift- och native-/UI-fallen är ännu inte körda; tidigare bygge63:s
resultat gäller den tidigare källan. Faktiska CI-resultat ska läggas till efter
att körningen avslutats. Se docs/READING_IMPROVEMENTS_2026-10-25.md.

Första PR-körningen 40222790505 på 4ee3aa0 avvisades vid kompilering av
ReaderView: för stort SwiftUI-typkontrolluttryck dolde även ett felaktigt
recitatörsnamn i rapportkopplingen. Inga native-/UI-resultat godkänns från
den körningen. Läsvyn har delats upp och kopplingen använder nu spelarens
selectedReciter. Den tidigare körningen 40222772710 ersattes och avbröts
när kravdokumentationen färdigställdes; den räknas inte som godkänd.

Den följande PR-körningen 40223278849 på b4dcd1e byggde både iPhoneOS-paket
och simulatorappar. Native-gaten hittade en Unicode-regression i rapportens
beskrivning: iOS trimmade U+FEFF. Testet behålls; exporten bevarar nu hela
inmatningen och använder trimning endast för att identifiera tom text.
Inga UI-fall godkänns från den körningen; den är inte en godkänd leverans.

PR-körning 40223934384 på eff9e59 hittade samma rapportprov trots att
inmatningen nu bevaras. Den räknas inte som godkänd. Nästa kandidat behåller
originalassertionen och kontrollerar även inmatningens byte och JSONDecoder,
samt en separat kontroll med systemets JSONEncoder/JSONSerialization. U+FEFF
exporteras som JSON-Unicode-escape för entydig läsning över Foundation-versioner.
Detta gäller rapportbeskrivningen; koranresurserna ändras inte.

Körning 40224518157 på 4243917 isolerade felet: både kompakt iOS18 och
iPhone16Pro körde 143 hostade fall med ett enda fel i JSONSerialization-
assertionen. Inmatningens byte, JSON-Unicode-escapen och strikt JSONDecoder-
återläsning passerade. Kontrollraden var raw input marker=true, encoded literal
marker=true, Foundation-decoded marker=false. Förlusten sker alltså i Darwins
JSONSerialization, även vid en giltig Unicode-escape. Nästa kandidat använder
JSONDecoder som byte-orakel och behåller exakta UTF-8-kravet; JSONSerialization
används fortsatt för oberoende kontroll av schema/källor/referenser. Detta
rättar provmetoden utifrån native-bevis och godkänner inte den fallerade körningen.

PR-körning 40225286761 på 8899735 avslutades underkänd. Kompakt iOS18
passerade 143 hostade fall men hade fyra UI-fel: ett äldre tabbyte nådde inte
läsfliken, två nya prov valde Menys icke klickbara omslag och ett nytt prov
krävde onödig pixelprecision efter verklig rullning. iOS26 passerade samtliga
143 hostade fall; dess individuella UI-rader visar 17 godkända och ett fel i
samma rullningshjälpare. En rapporterad runner-omstart gör att dessa inte
redovisas som en ren godkänd UI-svit. Sökning, exakt träff/omstart, källor,
rapport vid XXXL och uttrycklig läsplats har faktisk godkänd iOS26-evidens.
iPhone16Pro missade ett äldre inventeringsprovs START-registrering inom
10 sekunder (143 fall, ett fel); senare faser kördes inte i det provet.

Nästa kandidat behåller alla äldre testklasser och tidsbudgetar. De nya
UI-proven väljer endast den referensbundna Menys unika, synliga, faktiskt
klickbara native-knapp inom samma 44-punktsram. Rullning måste fortfarande
ske på riktigt, målversen ligga helt nära toppen inom fem sekunder och rätt
vers överleva omstart utan läskredit. Hjälparens oavsiktliga pixelkrav
anpassas till observerad beröringsmarginal. Läsvyn mäter också höjd och
safe-area-marginaler tillsammans så att rader bakom navigations-, flik-
eller uppspelningsfält inte väljs som synlig läsplats. Nollmarginaler behåller
tidigare geometri. Korantexten och ljud-/inventeringskoden är oförändrade.
