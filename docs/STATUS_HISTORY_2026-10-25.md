> Historisk status före den senaste härdningen och vershoppsomgången. Aktuell status finns i [STATUS.md](../STATUS.md). Uppgifter om senaste körning nedan avser dåtidens läge.

# Sakina – utvecklingsstatus

Uppdaterat: **2026-10-25**. Den senaste omgången fokuserar på användarens begärda finjusteringar, granskning och bevarande. Detta är en utvecklingsversion i källkod; ingen signerad eller färdigtestad iPhone-release är publicerad. Produktkraven finns i [KRAV.md](../KRAV.md).

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

[Installationsguiden](../docs/PERSONAL_IPHONE_INSTALL.md) beskriver gratis personlig
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

**Det riktiga Apple SDK-bygget och samtliga 18 native-tester har passerat** i [GitHub Actions](https://github.com/AllCrow/Koran-test-/actions/runs/40154414555): åtta AppStore-tester, sju AudioLibrary-tester och tre UI-flöden på iPhone 16 Pro-simulator med iOS 18.5, arm64 och Xcode 16.4. UI-proven hittade först konflikter i tillgänglighetsidentifierare och radidentitet vid surabyte. Rättningarna klarar nu samma eller starkare krav: den sista kontrollen markerar och bokmärker 112:1 och verifierar att åtgärden hör till rätt sura. **Fysisk iPhone, ljudrutter, energi och signering återstår.** Se [native-proven](../docs/IOS_VERIFICATION.md).

Den tidigare [Linux-sammanställningen](../docs/evidence/polish-verification-2026-10-25.json) bevarar dåtidens resultat, avgränsningar och källhashar. De senare Mac-resultaten och deras exakta kodcommit länkas separat nedan.

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

Swift-syntax, Foundation-baserad typkontroll och Xcode-projektets struktur har också kontrollerats. Dessa tidigare kontroller har nu följts av det riktiga Mac-bygget ovan; ingen av dem ersätter fysisk iPhone-provning. Kommandon och projektlayout finns i [README.md](../README.md); backendens testomfattning finns i [backend/README.md](../backend/README.md).

## Recitationsanalysens faktiska gränser

Övningen använder en uttryckligt vald vers och högst 60 sekunders inspelning med analys efteråt. Ingen liveföljning av orden i användarens egen röst är implementerad. Basmala är av som standard och väljs före inspelningen; valet låses när en giltig inspelning finns och ändras inte genom att tyst radera inspelningen.

Standardkonfigurationen är `SAKINA_ENABLE_EXPERIMENTAL_ANALYSIS=false` och `SAKINA_ANALYSIS_URL` tom. En aktiverad experimentell byggversion kräver en nåbar HTTPS-server och en uttrycklig analysåtgärd. Det finns ingen automatisk uppladdning och ingen dold modellkörning medan användaren läser.

Backend använder en fixerad MIT-licensierad PyPI-release av `quran-muaalem` 0.2.2, `quran-transcript` 0.6.4 och modellrevision `01a1ef9fbe40d144ef845101e89ff924aed3fef5`. Dagens Git-main har andra licensvillkor och är inte samma valda artefakt. Licenser och proveniens är dokumenterade.

Aktuell kod jämför Muaalems fonemutdata med referensen. Separata sifat-huvuden ger ännu ingen egen återkoppling, så alla uttalsegenskaper är inte bedömda. Madd arid-varianter på 2, 4 eller 6 godtas nu endast för samma långa vokal och en exakt typad, ensam `AaredMaddRule` med konsekventa längduppgifter; andra regler eller vokalbyten döljs inte. Övriga Hafs-/madd-antaganden och pauser kan påverka resultatet. Ingen jämförelse med Tarteels aktuella betalversion har gjorts. **Kravet om minst Tarteels kvalitet är inte uppfyllt eller styrkt.**

Den cirka 2,42 GB stora viktfilen finns i extern utvecklingscache under `/workspace/scratch/sakina-model-cache`, utanför apprepot. Den ska inte läggas i Git eller beskrivas som bundlad iPhone-AI.

Det första verkliga [CPU-/API-provet](../docs/MODEL_SMOKE_RESULTS.md) gav noll presenterade indikationer för al-Afasy, al-Husary och al-Minshawi 1:1, 15 för den avsiktligt andra versen 112:1 mot referens 1:1 samt `insufficient_audio` utan indikationer för tystnad. [Råresultaten](../docs/evidence/model-smoke-2026-10-24.json) är sparade, liksom [körningen före madd-ändringen](../docs/evidence/model-smoke-before-variants-2026-10-24.json).

Ett [utökat prov med 35 indata](../docs/evidence/model-baseline-2026-10-24.json) omfattade samtliga sju al-Fatiha-verser och fyra al-Ikhlas-verser med var och en av tre recitatörer, totalt 33 referensklipp. Alla fick `assessed`; 32 gav noll indikationer och al-Afasy 112:2 gav en `normal`/`delete`-indikation för förväntat initialt fonem `ءَ`. Den kräver sakkunnig granskning av källklipp/onset, wasl, referens, lässtil och modell. Den är inte klassificerad som falsk indikation eller verkligt uttalsfel, och ingen noggrannhetsprocent räknas ut. Kontrollen med annan vers gav fortsatt 15 indikationer, och tystnaden `insufficient_audio`.

Modelladdning från lokala filer tog 2,041 sekunder; topp-RSS för Linux-processen var 2 749,1 MiB. De tre 1:1-anropen tog 2,283–3,282 sekunder med två CPU-trådar i ett in-process HTTP-test. Fil-/sidcache var inte dokumenterat kall och inget publikt nät användes. Detta är inga iPhone-, nätverks-, temperatur- eller energimått. Det utökade provets referensanrop tog 1,343–8,475 sekunder med median 2,351 sekunder; dess modelladdning tog 1,911 sekunder och topp-RSS var 3 240,5 MiB. Dessa mått är från den separata 35-indatakörningen med samma lokala CPU-/API-upplägg. Två suror och publicerade recitatörer med okänt träningsöverlapp bevisar inte generell felupptäckt. Författarnas separata forskningssiffror finns kvar i [modellunderlaget](../docs/RECITATION_RESEARCH.md); de blandas inte med detta funktionsprov.

## Innehåll och rättigheter

Den kanoniska koranresursen är cirka **4,78 MB**, inklusive komprimerade originalögonblicksbilder och notiser. Övningsreferenserna tillför cirka **2,01 MB**. Amiri Quran distribueras separat med oförändrad OFL-licens. Proveniens finns i [CONTENT_SOURCES.json](../CONTENT_SOURCES.json), [fontnotisen](../App/Resources/Fonts/SOURCE.md) och [övningsreferensernas index](../Sources/QuranPractice/Resources/PracticeReferences/index.json).

Uthmani- och tajweededitionerna skiljer sig i tecken och Basmala-gruppering. Uthmani har två exakta öppningsprefix: det vanliga i 110 suror och en variant med shadda på första bokstaven i 95 och 97. Presentationen känner igen båda och bevarar källans prefix; Unicodepositioner överförs inte mellan editioner. Övningsåterkopplingen använder dessutom sin egen namngivna referensutgåva.

Tillgängliga API:er och ljudfiler betyder inte att alla rättigheter för appens distribution är färdigkontrollerade. **Ljudrättigheter och övriga villkor för offentlig release är inte avslutade.** Se [källnotiserna](../App/Resources/Quran/NOTICE.txt).

## Bevarande, REA och distribution

Ett lokalt Git-repo finns. Grundversionen är sparad i `238ac4b` och den integrerade offline-/analyspipelinen i `10abe88`; följande ändringar och dokumentation bevaras i nya snapshots. Se lokal Git-logg för senaste commit. Denna status innebär inte att det senaste arbetsträdet redan är uppladdat eller att utvecklingen är färdig.

Användaren har skapat [AllCrow/Koran-test-](https://github.com/AllCrow/Koran-test-). Ägare AllCrow, publikt läge och läs-/skrivåtkomst är kontrollerade den 25 oktober. Användaren godkände uttryckligen **publikt tills vidare**, vilket ersätter det tidigare privatkravet för uppladdningen. Integrationen nekas att ändra synlighet (403); ägaren behöver utföra ett senare byte till privat.

Koden och hela den tidigare lokala Git-historiken är uppladdade. Första remote `main` verifierades mot lokal commit **`eccabe79ad7405d2cb4fe5ad317e46de9416d14d`**. Det [första Mac-bygget](https://github.com/AllCrow/Koran-test-/actions/runs/40152872024) kompilerade appen, men testlänkningen hittade en arkitekturkonflikt. Standardinställningen `ONLY_ACTIVE_ARCH=YES` för Debug rättade den.

I [nästa körning](https://github.com/AllCrow/Koran-test-/actions/runs/40153076721) passerade appbygget och åtta hostade tester. UI-proven hittade kortidentifieraren som maskerade knapparnas egna identifierare. När den flyttats till en textetikett passerade [två UI-flöden](https://github.com/AllCrow/Koran-test-/actions/runs/40153744517); surabytet visade därefter gamla kontrollidentifierare. Globala versidentiteter, surans identitet på versgruppen och motsvarande scrollreferenser rättade detta.

**Tidigare godkänd körning:** [40154343011](https://github.com/AllCrow/Koran-test-/actions/runs/40154343011), exakt kodcommit **`4a30f477e0b9b1174ee95ca950d51ab4a682ec7f`**. Båda jobben är `success`: appbygge, 61 portabla tester, 28 backendtester, åtta hostade tester och tre UI-flöden. Native-resultat (`Sakina-native-test-results`, ID 12584176677) och simulatorapp (`Sakina-simulator`, ID 12584471042) är uppladdade som CI-artefakter med sju dagars lagring. Senare dokumentationscommits ändrar ingen testad appkod och utlöser ingen onödig Mac-omkörning.

**Senast samlat godkända körning:** [40154414555](https://github.com/AllCrow/Koran-test-/actions/runs/40154414555), exakt källversion **`a0b2e624406242f85af75e483854a09ce8265919`**. Den tillför sju AudioLibrary-prov: 15 hostade och tre UI-prov passerar tillsammans med 61 portabla tester och 28 backendtester. Båda jobben är `success`. Native-resultat (ID 12584416801) och simulatorapp (ID 12584341948) är uppladdade; artefakternas head-SHA matchar den testade versionen. Därefter integrerad dokumentation från `2a83295` och denna resultatuppdatering ändrar ingen körbar kod, testkod eller bygginställning.

Simulatorappen kan **inte** installeras på fysisk iPhone. Ingen signerad iPhone-version eller TestFlight-publicering finns ännu. Den slutliga distributionen behöver även uppfylla Apples då aktuella Xcode-/SDK-krav.

REA finns separat i `/workspace/rea`, commit `f196ebf80665107aedc16892af25a1e1f9f26f43`. Det har faktiskt inventerat Muaalems safetensors-fil och strömmat hela filen för SHA256; den matchar den fixerade HF-artefakten. [Oförändrad evidens och metod](../docs/REA_MODEL_INSPECTION.md) är sparade. Detta är en artefaktundersökning, inte en kvalitetsbedömning. **Tarteels app eller servrar har inte analyserats.**

Användaren har iPhone men ingen egen Mac. Den prioriterade privata vägen är nu personlig signering enligt guiden ovan om en dator kan lånas. TestFlight är ett alternativ som kräver medlemskap hos en signerande utgivare och App Store Connect; testaren behöver inget eget betalt medlemskap. **Varken personlig signering eller TestFlight är färdigt.** Inga Apple-lösenord, parkopplingsfiler, serverhemligheter eller signeringsnycklar ska checkas in.

## Återstående releasekrav och fortsatt arbete

1. Utöka modellproven från den verifierade begränsade körningen till flera verser, elever och verkliga förhållanden. Kör sakkunnig utvärdering; påstå ingen Tarteel-paritet innan den är styrkt.
2. Fortsätt verifiera uppladdade commits i användarens AllCrow/Koran-test-. Bevara lokala snapshots; följ det nya beslutet om publikt tills vidare.
3. Prova läsning, arabisk text, ljudsynkning, nedladdning/offline, tafsir, streak, inspelning och eventuell analys på fysisk iPhone. Automatiskt simulatorbygge och 18 native-tester är nu godkända, men täcker inte alla manuella flöden.
4. Mät telefonens värme, batteri, minne och svarstid. **Ingen fysisk temperatur- eller energimätning är ännu utförd.**
5. Slutför innehållsrättigheter, användarinformation, signering och TestFlight-distribution. Dokumentera vad som faktiskt passerar varje steg.

Arbetet är pågående. Portabla tester och bevarad källkod är framsteg, men de avslutar inte native-verifiering, modellkvalitet eller releasekrav.


# Status före verifierad körning44 (arkiverad2026-10-25)

# Sakina – utvecklingsstatus

Uppdaterat **2026-10-25**. Native-app för personligt iPhone-prov, iOS 17+.
Ljud, inspelningslivstid, offlinefiler, läsdata och textberedning har härdats.
Direkt vershopp och säkerhetskopiering av läsdata är tillagda.
**Native-listläsaren, skärpta positionstester och samtliga 61 native-prov har passerat.** Personlig signering,
fysisk installation och en offentlig apprelease är inte verifierade.

## Aktuell samlad verifieringspunkt

I körning43 passerade SE3 hela80hostade+8UI på03926e5. På16Pro/iOS18.5
passerade alla8UI och det avsiktligt sena native-start-provet, men MP3-provet
läste åter rate1 efter ett tidigare KVO-kvitto. Kandidaten är därför inte
godkänd. Paus-/återstartsväntarna levererar nu KVO på huvudkön och jämför
även motorns aktuella rate/timeControlStatus innan de kvitterar; samma
tvåsekundersgräns, slutassertioner och återstående ljud krävs. Inga ytterligare
produktionsändringar eller sleeps införs. Ny kandidat behöver faktisk CI.

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
