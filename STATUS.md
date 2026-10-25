# Sakina – utvecklingsstatus

Uppdaterat: **2026-10-25**. Den senaste omgången fokuserar på användarens begärda finjusteringar, granskning och bevarande. Detta är en utvecklingsversion i källkod; ingen signerad eller färdigtestad iPhone-release är publicerad. Produktkraven finns i [KRAV.md](KRAV.md).

## Pågående verifiering av ljudspelaren

Sju nya hostade prov i `AppTests/OfflineMP3PlaybackTests.swift` kompletterar
huvudgrenens PCM-prov med riktig MP3-avkodning, lokalt filval för alla tre
recitatörer och aktiverad systemljudsession. En lokalt genererad, svag 440 Hz-ton
i tre sekunder används; ingen röst eller religiöst innehåll ingår.

Proven kontrollerar även paus/återstart, versslut/autospelning, en vers i övning,
simulerade ljudavbrott, gamla händelser efter surabyte och ett ospelbart klipp.
De använder fil-URL:er även för felvägen och gör inga externa ljudförfrågningar.
De första sju MP3-proven passerade i [körning 40159654656](https://github.com/AllCrow/Koran-test-/actions/runs/40159654656),
källa `dffc0bb115812db66a02e93763b3a0eb37c97a4b`, med 18 äldre native-prov och
riktig iPhoneOS-paketering. Huvudgrenens förbättringar från `1c13b88` har därefter
integrerats utan att skriva över dem. Ett pausat recitatörsbyte ska nu behålla
valet utan att skapa eller hämta ett nytt ljudklipp före uttrycklig återstart.
I [den samlade körningen 40160437326](https://github.com/AllCrow/Koran-test-/actions/runs/40160437326) passerade därefter alla 54 hostade iOS-prov, men det nya UI-provet med största textstorleken missade tajweedreglagets faktiska tryckyta. Huvudgrenens rättning av reglagets testtryck och nya versnavigering från `4d65851` är integrerade. **Den samlade versionen behöver fortfarande en godkänd Mac-körning före merge.**
Fysisk installation, ljudrutter, mikrofon, källinspelningarnas innehåll och
energi/värme är fortfarande inte godkända genom dessa tonprov.

## Privat installation och fysisk iPhone-fil

Användaren vill behålla den riktiga iPhone-appen och har uttryckligen valt bort
Safari/PWA. [Körning 40156140923](https://github.com/AllCrow/Koran-test-/actions/runs/40156140923),
kodcommit `bc3e54852ceee1adf26b3d0fa29740f3042bd204`, har byggt **Release för
fysisk iPhoneOS/arm64** utan signeringsuppgifter. Alla tre jobb är `success`:
simulatorbygge och 18 native-prov, 61 portabla tester, 28 backendtester samt
det separata paketjobbet. `Sakina-iPhone-unsigned.ipa` är 3 003 282 byte, kräver iOS 17+ och
har SHA256 `54e5e62bb29e5f4a515ca928da50d0ed8d8922ad90cca065f5c4f6172fa6b995`.

Paketet är nedladdat och återkontrollerat lokalt: ZIP-integritet, plist,
arm64 Mach-O och plattform `IOS` (inte simulator) stämmer. Ingen utvecklarprofil
ingår. **Filen är osignerad och kan inte installeras genom ett tryck i Filer.**
Artefakten `Sakina-iPhone-personal-unsigned` har ID 12584129644 och sju dagars
CI-lagring; en lokal kopia och byggrapport är också bevarade.

[Installationsguiden](docs/PERSONAL_IPHONE_INSTALL.md) beskriver gratis personlig
signering med SideStore, vanligt Apple-konto och en lånad Mac/Windows-dator för
grundinstallation. Användarens tillgång till en lånad dator är ännu inte
bekräftad. Förnyelse behövs före sjudagarsgränsen och en dator kan behövas igen
vid problem. **Personlig signering, installation, mikrofon/ljud och energi på
användarens fysiska iPhone är fortfarande inte verifierade.**

## Projektledarens fortsatta verifiering

[Den samlade körningen 40154414555](https://github.com/AllCrow/Koran-test-/actions/runs/40154414555)
är **success** på källversion `a0b2e624406242f85af75e483854a09ce8265919`.
Appbygget, 61 portabla Swift-tester, 28 backendtester, **15 hostade iOS-prov och
alla tre UI-flöden** passerar. De hostade proven består av åtta AppStore- och
sju nya AudioLibrary-prov. Rättningarna från den parallella byggtråden är
integrerade med bevarad Git-historik.

De nya filproven kontrollerar isolering per vers/sura/recitatör, fel- och
ofullständiga filer, ID3-metadata, omvalidering efter filändring, återöppning från
disk, avgränsad radering och otillgänglig lagring. De använder egna temporära
filer och syntetiska MPEG-ramar, aldrig nätverk, mikrofon eller verkliga
inspelningar. De fastställer inte ljudets avkodningskvalitet eller energiförbrukning.

Lokalt passerar koran-, övningsreferens- och resurskontroller. Native-resultaten
kommer från riktig macOS-/iPhone-simulator, inte från den här Linuxmiljön.

## Senaste finjusteringar

- Ljudfältet har större tryckytor och bättre plats för stor text. Arabisk högerjustering och VoiceOver-rubriker är rättade; startsida och suraval har adaptiv layout.
- Låsskärms-/headsetkontroller och metadata för vald vers/recitatör är implementerade utan tidspollning. Recitatör och autospelning sparas mellan appstarter. Inspelningens ljudsession skyddas från gammal spelarstädning.
- En övningstagning och dess Basmala-val bevaras vid läsning av andra suror och återställs när övningen öppnas. Ersättning, radering och byte av övningsvers kräver uttryckligt val. Pågående mikrofonbehörighet kan inte samtidigt starta återlyssning eller analys.
- Hörlursurkoppling stoppar privat inspelning/återlyssning. När appen går till bakgrunden stoppas egen röst och förgrundsnedladdning; färdiga ljudfiler bevaras. Referensrecitation kan fortfarande fortsätta i bakgrunden.
- Tafsirens återförsök följer vyns livstid, och äldre avbrutna anrop kan inte skriva över ett nyare laddningstillstånd. Nedladdningar reserverar sitt jobb direkt för att undvika fördröjda starter efter avbrytning.
- Streakhistorik räknas konsekvent även i tidszoner med historiskt överhoppade datum. Systemets tids-/tidszonsändring uppdaterar dagens läsprogression utan polling. Modellens indikation om ett extra ljud färgar inte en befintlig bokstav.
- Backend avvisar spellistor och ofullständig PCM; dubbelt avbrutna HTTP-anrop behåller analysplatsen tills arbetstråden har avslutats.

**Det riktiga Apple SDK-bygget och samtliga 18 native-tester har passerat** i [GitHub Actions](https://github.com/AllCrow/Koran-test-/actions/runs/40154414555): åtta AppStore-tester, sju AudioLibrary-tester och tre UI-flöden på iPhone 16 Pro-simulator med iOS 18.5, arm64 och Xcode 16.4. UI-proven hittade först konflikter i tillgänglighetsidentifierare och radidentitet vid surabyte. Rättningarna klarar nu samma eller starkare krav: den sista kontrollen markerar och bokmärker 112:1 och verifierar att åtgärden hör till rätt sura. **Fysisk iPhone, ljudrutter, energi och signering återstår.** Se [native-proven](docs/IOS_VERIFICATION.md).

Den tidigare [Linux-sammanställningen](docs/evidence/polish-verification-2026-10-25.json) bevarar dåtidens resultat, avgränsningar och källhashar. De senare Mac-resultaten och deras exakta kodcommit länkas separat nedan.

## Implementation

| Del | Nuvarande läge | Återstående kontroll |
| --- | --- | --- |
| iPhone-app | SwiftUI för iOS 17+, startsida, läsare, övning, inställningar och ljudnedladdningar. Mac-byggen för simulator och fysisk iPhone samt 18 native-tester har passerat. | Personlig signering, installation och fysisk iPhone-verifiering. |
| Korantext | Alla 114 suror och 6 236 ayat lokalt, uppdelade per sura. Källmaterial och hashmanifest ingår. | Visuell arabisk återgivning och läsflöde på enheten. |
| Tajweedvisning | Separat annoterad edition, parser och på/av-val. | Färger, diakritik och växling på iPhone. |
| Arabisk font | Amiri Quran är bundlad med OFL-licens och fixerad proveniens. Hashar och täckning av lästextens synliga tecken är verifierade. | Formgivning, radbrytning och tillgänglighet på iPhone. Glyph-täckning är inte ett renderingsprov. |
| Läsprogression | Lokal läsposition, bokmärken, dagligt mål och uppmuntrande streak. Uttrycklig läsmarkering räknas, inte bara appstart. Återstart, bokmärken och surabyte har passerat simulatorprov. | Fysiska kalender-/tidszonsbyten och längre användning. |
| Recitation | AVPlayer med al-Afasy, al-Husary och al-Minshawi, en fil per vers och spelarstyrd markering. | Ljud/textkoppling, buffring, avbrott, bakgrund och recitatörsbyte på iPhone. Ord-för-ord-synkning är inte verifierad. |
| Ljud offline | Uttrycklig nedladdning per sura/recitatör, framsteg, avbrytning, fortsättning och radering finns i native-koden. Spelaren föredrar lokal fil. Inget ljud är förpaketerat. Sju simulatorprov av lokal filhantering passerar. | Nätverksnedladdning, avkodning och verklig offlineuppspelning på iPhone återstår. Ljudrättigheter återstår. |
| Tafsir | Al-Muyassar på arabiska hämtas online med källangivelse. | iOS-nätverksflöde och visuell återgivning. Ingen offline-tafsir eller svensk tafsir ingår. |
| Egen röst | Lokal inspelning och återlyssning. | Mikrofonbehörighet, ljudsessioner och radering på iPhone. Ingen automatisk uppladdning. |
| Experimentell analys | Separat Muaalem-backend, typad native-klient, svarskontroller och återkopplingsvy är integrerade. **Avstängd som standard**, tom HTTPS-adress och ingen publik driftsättning. | Bredare modellprov, native-integration och sakkunnig kvalitet. Ett begränsat verkligt CPU-prov är utfört. Ingen automatisk uttalspoäng ges. |
| Modellreferens | Separat quran-transcript-0.6.4-utgåva för backend och app, cirka 2,01 MB. Alla 6 236 referenser och 112 öppningsfraser klarar fonemvokabulär-/mappningskontroll. | Akustisk bedömning av inspelningar. Återkoppling visas i exakt referenstext, inte med offsets i läsvyns andra edition. |
| Prestanda och kostnad | Läsaren utlöser ingen tung talanalys. Ingen obligatorisk abonnemangsfunktion är implementerad. | Fysiska temperatur-/energimätningar och finansiering av eventuell serverdrift. |

Korantext, tajweeddata och övningsreferenser är lokala. Recitationsljud kräver nät tills respektive fil har laddats ned. Tafsir kräver fortfarande internet. Ljud och tafsir ingår inte i de paketerade koranresurserna.

## Genomförd verifiering

| Kontroll | Resultat | Omfattning |
| --- | --- | --- |
| Portabla Swift-tester | **61 passerade, 0 fel** | 22 kärntester, 18 datatester och 21 övnings-/analyskontraktstester. Tvärspråkstestet validerar fem verkliga Python-svar genom Swift-klienten. Körda på både Linux och macOS; iOS-resultaten redovisas separat. |
| Backendtester | **28 passerade** | Kontrakt, validering, resursgränser, riktig M4A/AAC-/WAV-avkodning, upprepad avbrytning och avgränsade madd arid-varianter. Kontraktstester med motorersättning mäter inte modellkvalitet. |
| Koranresurser | **Godkända** | 114 suror, 6 236 konsekutiva referenser, metadatakoppling, UTF-8-bevarande och samtliga käll-/resurshashar. |
| Övningsreferenser | **Godkända** | Fixerad källversion, originaldata/API-hashar, filinventering, licensnotiser samt fonemkompatibilitet för samtliga referenser. |
| Font och resurser | **Godkända** | Amiri Quran-/OFL-hashar, resursdeklarationer och synlig teckentäckning för kanonisk lästext. |
| Native Xcode-/enhetsprov | **Xcode-bygge och 18 av 18 native-tester passerade** | iPhone 16 Pro / iOS 18.5-simulator, Xcode 16.4, arm64. 15 hostade tester och tre UI-flöden gav noll fel. Fysisk telefon, ljudrutter och signering återstår. |
| Verklig Muaalem-inferens | **Utförd; utökat prov med 35 indata** | 33 referensklipp från al-Fatiha/al-Ikhlas med tre recitatörer samt annan vers och tystnad. Ett referensfall behöver sakkunnig granskning. Inga expertetiketter eller generell kvalitetsmätning. |
| REA-inspektion | **Utförd på verklig viktfil** | 816 F32-tensorer, 605 754 251 deklarerade element och full SHA256 verifierade. Tensorvärden eller kvalitet tolkas inte av denna kontroll. |
| Dockerbygg/-start | **Tidigare image och aktuell källstart kontrollerade** | Image från 2026-10-24 kördes som UID 10001 utan nätverk eller värdportar. Den 25 oktober startades aktuell backendkod och referenser via read-only-mount i samma runtime, som UID 1000, utan nätverk/värdportar. Verklig lokal HTTP-hälsa gav inte-redo-läge och ren avstängning. Det är ingen ny imagebyggning, containerinferens eller publik tjänst. |

Koranverifieringen körs med `python3 scripts/verify_content.py`. Offlineåterskapande från källögonblicksbilder har kontrollerats som deterministiskt. Negativa kontroller avvisar ändrad arabisk text, en extra kapitelresurs och ändrad text även när dess resurshash har skrivits om. Det är inte en oberoende lärd certifiering av källan.

Övningsreferenserna kontrolleras med `python3 scripts/export_practice_references.py --verify`. Det separata datasetet behövs eftersom läsvyns rikare Uthmani-text lämnar vissa tecken utanför modellens fonemvokabulär. Inga originalsträngar i läsvyn har ändrats för att passa modellen.

Swift-syntax, Foundation-baserad typkontroll och Xcode-projektets struktur har också kontrollerats. Dessa tidigare kontroller har nu följts av det riktiga Mac-bygget ovan; ingen av dem ersätter fysisk iPhone-provning. Kommandon och projektlayout finns i [README.md](README.md); backendens testomfattning finns i [backend/README.md](backend/README.md).

## Recitationsanalysens faktiska gränser

Övningen använder en uttryckligt vald vers och högst 60 sekunders inspelning med analys efteråt. Ingen liveföljning av orden i användarens egen röst är implementerad. Basmala är av som standard och väljs före inspelningen; valet låses när en giltig inspelning finns och ändras inte genom att tyst radera inspelningen.

Standardkonfigurationen är `SAKINA_ENABLE_EXPERIMENTAL_ANALYSIS=false` och `SAKINA_ANALYSIS_URL` tom. En aktiverad experimentell byggversion kräver en nåbar HTTPS-server och en uttrycklig analysåtgärd. Det finns ingen automatisk uppladdning och ingen dold modellkörning medan användaren läser.

Backend använder en fixerad MIT-licensierad PyPI-release av `quran-muaalem` 0.2.2, `quran-transcript` 0.6.4 och modellrevision `01a1ef9fbe40d144ef845101e89ff924aed3fef5`. Dagens Git-main har andra licensvillkor och är inte samma valda artefakt. Licenser och proveniens är dokumenterade.

Aktuell kod jämför Muaalems fonemutdata med referensen. Separata sifat-huvuden ger ännu ingen egen återkoppling, så alla uttalsegenskaper är inte bedömda. Madd arid-varianter på 2, 4 eller 6 godtas nu endast för samma långa vokal och en exakt typad, ensam `AaredMaddRule` med konsekventa längduppgifter; andra regler eller vokalbyten döljs inte. Övriga Hafs-/madd-antaganden och pauser kan påverka resultatet. Ingen jämförelse med Tarteels aktuella betalversion har gjorts. **Kravet om minst Tarteels kvalitet är inte uppfyllt eller styrkt.**

Den cirka 2,42 GB stora viktfilen finns i extern utvecklingscache under `/workspace/scratch/sakina-model-cache`, utanför apprepot. Den ska inte läggas i Git eller beskrivas som bundlad iPhone-AI.

Det första verkliga [CPU-/API-provet](docs/MODEL_SMOKE_RESULTS.md) gav noll presenterade indikationer för al-Afasy, al-Husary och al-Minshawi 1:1, 15 för den avsiktligt andra versen 112:1 mot referens 1:1 samt `insufficient_audio` utan indikationer för tystnad. [Råresultaten](docs/evidence/model-smoke-2026-10-24.json) är sparade, liksom [körningen före madd-ändringen](docs/evidence/model-smoke-before-variants-2026-10-24.json).

Ett [utökat prov med 35 indata](docs/evidence/model-baseline-2026-10-24.json) omfattade samtliga sju al-Fatiha-verser och fyra al-Ikhlas-verser med var och en av tre recitatörer, totalt 33 referensklipp. Alla fick `assessed`; 32 gav noll indikationer och al-Afasy 112:2 gav en `normal`/`delete`-indikation för förväntat initialt fonem `ءَ`. Den kräver sakkunnig granskning av källklipp/onset, wasl, referens, lässtil och modell. Den är inte klassificerad som falsk indikation eller verkligt uttalsfel, och ingen noggrannhetsprocent räknas ut. Kontrollen med annan vers gav fortsatt 15 indikationer, och tystnaden `insufficient_audio`.

Modelladdning från lokala filer tog 2,041 sekunder; topp-RSS för Linux-processen var 2 749,1 MiB. De tre 1:1-anropen tog 2,283–3,282 sekunder med två CPU-trådar i ett in-process HTTP-test. Fil-/sidcache var inte dokumenterat kall och inget publikt nät användes. Detta är inga iPhone-, nätverks-, temperatur- eller energimått. Det utökade provets referensanrop tog 1,343–8,475 sekunder med median 2,351 sekunder; dess modelladdning tog 1,911 sekunder och topp-RSS var 3 240,5 MiB. Dessa mått är från den separata 35-indatakörningen med samma lokala CPU-/API-upplägg. Två suror och publicerade recitatörer med okänt träningsöverlapp bevisar inte generell felupptäckt. Författarnas separata forskningssiffror finns kvar i [modellunderlaget](docs/RECITATION_RESEARCH.md); de blandas inte med detta funktionsprov.

## Innehåll och rättigheter

Den kanoniska koranresursen är cirka **4,78 MB**, inklusive komprimerade originalögonblicksbilder och notiser. Övningsreferenserna tillför cirka **2,01 MB**. Amiri Quran distribueras separat med oförändrad OFL-licens. Proveniens finns i [CONTENT_SOURCES.json](CONTENT_SOURCES.json), [fontnotisen](App/Resources/Fonts/SOURCE.md) och [övningsreferensernas index](Sources/QuranPractice/Resources/PracticeReferences/index.json).

Uthmani- och tajweededitionerna skiljer sig i tecken och Basmala-gruppering. Uthmani har två exakta öppningsprefix: det vanliga i 110 suror och en variant med shadda på första bokstaven i 95 och 97. Presentationen känner igen båda och bevarar källans prefix; Unicodepositioner överförs inte mellan editioner. Övningsåterkopplingen använder dessutom sin egen namngivna referensutgåva.

Tillgängliga API:er och ljudfiler betyder inte att alla rättigheter för appens distribution är färdigkontrollerade. **Ljudrättigheter och övriga villkor för offentlig release är inte avslutade.** Se [källnotiserna](App/Resources/Quran/NOTICE.txt).

## Bevarande, REA och distribution

Ett lokalt Git-repo finns. Grundversionen är sparad i `238ac4b` och den integrerade offline-/analyspipelinen i `10abe88`; följande ändringar och dokumentation bevaras i nya snapshots. Se lokal Git-logg för senaste commit. Denna status innebär inte att det senaste arbetsträdet redan är uppladdat eller att utvecklingen är färdig.

Användaren har skapat [AllCrow/Koran-test-](https://github.com/AllCrow/Koran-test-). Ägare AllCrow, publikt läge och läs-/skrivåtkomst är kontrollerade den 25 oktober. Användaren godkände uttryckligen **publikt tills vidare**, vilket ersätter det tidigare privatkravet för uppladdningen. Integrationen nekas att ändra synlighet (403); ägaren behöver utföra ett senare byte till privat.

Koden och hela den tidigare lokala Git-historiken är uppladdade. Första remote `main` verifierades mot lokal commit **`eccabe79ad7405d2cb4fe5ad317e46de9416d14d`**. Det [första Mac-bygget](https://github.com/AllCrow/Koran-test-/actions/runs/40152872024) kompilerade appen, men testlänkningen hittade en arkitekturkonflikt. Standardinställningen `ONLY_ACTIVE_ARCH=YES` för Debug rättade den.

I [nästa körning](https://github.com/AllCrow/Koran-test-/actions/runs/40153076721) passerade appbygget och åtta hostade tester. UI-proven hittade kortidentifieraren som maskerade knapparnas egna identifierare. När den flyttats till en textetikett passerade [två UI-flöden](https://github.com/AllCrow/Koran-test-/actions/runs/40153744517); surabytet visade därefter gamla kontrollidentifierare. Globala versidentiteter, surans identitet på versgruppen och motsvarande scrollreferenser rättade detta.

**Tidigare godkänd körning:** [40154343011](https://github.com/AllCrow/Koran-test-/actions/runs/40154343011), exakt kodcommit **`4a30f477e0b9b1174ee95ca950d51ab4a682ec7f`**. Båda jobben är `success`: appbygge, 61 portabla tester, 28 backendtester, åtta hostade tester och tre UI-flöden. Native-resultat (`Sakina-native-test-results`, ID 12584176677) och simulatorapp (`Sakina-simulator`, ID 12584471042) är uppladdade som CI-artefakter med sju dagars lagring. Senare dokumentationscommits ändrar ingen testad appkod och utlöser ingen onödig Mac-omkörning.

**Senast samlat godkända körning:** [40154414555](https://github.com/AllCrow/Koran-test-/actions/runs/40154414555), exakt källversion **`a0b2e624406242f85af75e483854a09ce8265919`**. Den tillför sju AudioLibrary-prov: 15 hostade och tre UI-prov passerar tillsammans med 61 portabla tester och 28 backendtester. Båda jobben är `success`. Native-resultat (ID 12584416801) och simulatorapp (ID 12584341948) är uppladdade; artefakternas head-SHA matchar den testade versionen. Därefter integrerad dokumentation från `2a83295` och denna resultatuppdatering ändrar ingen körbar kod, testkod eller bygginställning.

Simulatorappen kan **inte** installeras på fysisk iPhone. Ingen signerad iPhone-version eller TestFlight-publicering finns ännu. Den slutliga distributionen behöver även uppfylla Apples då aktuella Xcode-/SDK-krav.

REA finns separat i `/workspace/rea`, commit `f196ebf80665107aedc16892af25a1e1f9f26f43`. Det har faktiskt inventerat Muaalems safetensors-fil och strömmat hela filen för SHA256; den matchar den fixerade HF-artefakten. [Oförändrad evidens och metod](docs/REA_MODEL_INSPECTION.md) är sparade. Detta är en artefaktundersökning, inte en kvalitetsbedömning. **Tarteels app eller servrar har inte analyserats.**

Användaren har iPhone men ingen egen Mac. Den prioriterade privata vägen är nu personlig signering enligt guiden ovan om en dator kan lånas. TestFlight är ett alternativ som kräver medlemskap hos en signerande utgivare och App Store Connect; testaren behöver inget eget betalt medlemskap. **Varken personlig signering eller TestFlight är färdigt.** Inga Apple-lösenord, parkopplingsfiler, serverhemligheter eller signeringsnycklar ska checkas in.

## Återstående releasekrav och fortsatt arbete

1. Utöka modellproven från den verifierade begränsade körningen till flera verser, elever och verkliga förhållanden. Kör sakkunnig utvärdering; påstå ingen Tarteel-paritet innan den är styrkt.
2. Fortsätt verifiera uppladdade commits i användarens AllCrow/Koran-test-. Bevara lokala snapshots; följ det nya beslutet om publikt tills vidare.
3. Prova läsning, arabisk text, ljudsynkning, nedladdning/offline, tafsir, streak, inspelning och eventuell analys på fysisk iPhone. Automatiskt simulatorbygge och 18 native-tester är nu godkända, men täcker inte alla manuella flöden.
4. Mät telefonens värme, batteri, minne och svarstid. **Ingen fysisk temperatur- eller energimätning är ännu utförd.**
5. Slutför innehållsrättigheter, användarinformation, signering och TestFlight-distribution. Dokumentera vad som faktiskt passerar varje steg.

Arbetet är pågående. Portabla tester och bevarad källkod är framsteg, men de avslutar inte native-verifiering, modellkvalitet eller releasekrav.
