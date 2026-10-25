# Sakina – utvecklingsstatus

Uppdaterat: **2026-10-25**. Den senaste omgången fokuserar på användarens begärda finjusteringar, granskning och bevarande. Detta är en utvecklingsversion i källkod; ingen signerad eller färdigtestad iPhone-release är publicerad. Produktkraven finns i [KRAV.md](KRAV.md).

## Senaste finjusteringar

- Ljudfältet har större tryckytor och bättre plats för stor text. Arabisk högerjustering och VoiceOver-rubriker är rättade; startsida och suraval har adaptiv layout.
- Låsskärms-/headsetkontroller och metadata för vald vers/recitatör är implementerade utan tidspollning. Recitatör och autospelning sparas mellan appstarter. Inspelningens ljudsession skyddas från gammal spelarstädning.
- En övningstagning och dess Basmala-val bevaras vid läsning av andra suror och återställs när övningen öppnas. Ersättning, radering och byte av övningsvers kräver uttryckligt val. Pågående mikrofonbehörighet kan inte samtidigt starta återlyssning eller analys.
- Hörlursurkoppling stoppar privat inspelning/återlyssning. När appen går till bakgrunden stoppas egen röst och förgrundsnedladdning; färdiga ljudfiler bevaras. Referensrecitation kan fortfarande fortsätta i bakgrunden.
- Tafsirens återförsök följer vyns livstid, och äldre avbrutna anrop kan inte skriva över ett nyare laddningstillstånd. Nedladdningar reserverar sitt jobb direkt för att undvika fördröjda starter efter avbrytning.
- Streakhistorik räknas konsekvent även i tidszoner med historiskt överhoppade datum. Systemets tids-/tidszonsändring uppdaterar dagens läsprogression utan polling. Modellens indikation om ett extra ljud färgar inte en befintlig bokstav.
- Backend avvisar spellistor och ofullständig PCM; dubbelt avbrutna HTTP-anrop behåller analysplatsen tills arbetstråden har avslutats.

Det första riktiga Apple SDK-bygget har nu passerat på macOS med Xcode 16.4 och iPhoneSimulator 18.5 SDK. Samtliga **åtta hostade AppStore-tester har passerat i simulatorn**. Tre UI-flöden kördes och hittade en verklig konflikt mellan verskortets och knapparnas tillgänglighetsidentifierare; kortets identifierare har flyttats till en separat textetikett. Samma UI-prov körs igen. Detta är ännu inget godkänt fullständigt simulator- eller enhetsresultat. Se [native-proven](docs/IOS_VERIFICATION.md).

[Verifieringssammanställningen](docs/evidence/polish-verification-2026-10-25.json) sparar resultat, avgränsningar och SHA256 för den granskade källkoden.

## Implementation

| Del | Nuvarande läge | Återstående kontroll |
| --- | --- | --- |
| iPhone-app | SwiftUI för iOS 17+, startsida, läsare, övning, inställningar och ljudnedladdningar. Riktigt simulatorbygge på macOS har passerat. | Slutför UI-prov och fysisk iPhone-verifiering. |
| Korantext | Alla 114 suror och 6 236 ayat lokalt, uppdelade per sura. Källmaterial och hashmanifest ingår. | Visuell arabisk återgivning och läsflöde på enheten. |
| Tajweedvisning | Separat annoterad edition, parser och på/av-val. | Färger, diakritik och växling på iPhone. |
| Arabisk font | Amiri Quran är bundlad med OFL-licens och fixerad proveniens. Hashar och täckning av lästextens synliga tecken är verifierade. | Formgivning, radbrytning och tillgänglighet på iPhone. Glyph-täckning är inte ett renderingsprov. |
| Läsprogression | Lokal läsposition, bokmärken, dagligt mål och uppmuntrande streak. Uttrycklig läsmarkering räknas, inte bara appstart. | Integrerat beteende på iPhone. Portabla kärntester passerar. |
| Recitation | AVPlayer med al-Afasy, al-Husary och al-Minshawi, en fil per vers och spelarstyrd markering. | Ljud/textkoppling, buffring, avbrott, bakgrund och recitatörsbyte på iPhone. Ord-för-ord-synkning är inte verifierad. |
| Ljud offline | Uttrycklig nedladdning per sura/recitatör, framsteg, avbrytning, fortsättning och radering finns i native-koden. Spelaren föredrar lokal fil. Inget ljud är förpaketerat. | Nedladdnings- och offlineflödet är ännu inte native-testat på iPhone. Ljudrättigheter återstår. |
| Tafsir | Al-Muyassar på arabiska hämtas online med källangivelse. | iOS-nätverksflöde och visuell återgivning. Ingen offline-tafsir eller svensk tafsir ingår. |
| Egen röst | Lokal inspelning och återlyssning. | Mikrofonbehörighet, ljudsessioner och radering på iPhone. Ingen automatisk uppladdning. |
| Experimentell analys | Separat Muaalem-backend, typad native-klient, svarskontroller och återkopplingsvy är integrerade. **Avstängd som standard**, tom HTTPS-adress och ingen publik driftsättning. | Bredare modellprov, native-integration och sakkunnig kvalitet. Ett begränsat verkligt CPU-prov är utfört. Ingen automatisk uttalspoäng ges. |
| Modellreferens | Separat quran-transcript-0.6.4-utgåva för backend och app, cirka 2,01 MB. Alla 6 236 referenser och 112 öppningsfraser klarar fonemvokabulär-/mappningskontroll. | Akustisk bedömning av inspelningar. Återkoppling visas i exakt referenstext, inte med offsets i läsvyns andra edition. |
| Prestanda och kostnad | Läsaren utlöser ingen tung talanalys. Ingen obligatorisk abonnemangsfunktion är implementerad. | Fysiska temperatur-/energimätningar och finansiering av eventuell serverdrift. |

Korantext, tajweeddata och övningsreferenser är lokala. Recitationsljud kräver nät tills respektive fil har laddats ned. Tafsir kräver fortfarande internet. Ljud och tafsir ingår inte i de paketerade koranresurserna.

## Genomförd verifiering

| Kontroll | Resultat | Omfattning |
| --- | --- | --- |
| Portabla Swift-tester | **61 passerade, 0 fel** | 22 kärntester, 18 datatester och 21 övnings-/analyskontraktstester. Tvärspråkstestet validerar fem verkliga Python-svar genom Swift-klienten. Körda på Linux med Swift, inte via iOS-runtime. |
| Backendtester | **28 passerade** | Kontrakt, validering, resursgränser, riktig M4A/AAC-/WAV-avkodning, upprepad avbrytning och avgränsade madd arid-varianter. Kontraktstester med motorersättning mäter inte modellkvalitet. |
| Koranresurser | **Godkända** | 114 suror, 6 236 konsekutiva referenser, metadatakoppling, UTF-8-bevarande och samtliga käll-/resurshashar. |
| Övningsreferenser | **Godkända** | Fixerad källversion, originaldata/API-hashar, filinventering, licensnotiser samt fonemkompatibilitet för samtliga referenser. |
| Font och resurser | **Godkända** | Amiri Quran-/OFL-hashar, resursdeklarationer och synlig teckentäckning för kanonisk lästext. |
| Native Xcode-/enhetsprov | **Bygge och åtta hostade tester passerade; UI-prov pågår** | Verkliga macOS-/iPhone-simulatorkörningar har utförts. Första testbyggets arkitekturkonflikt är rättad; åtta AppStore-tester passerade i nästa körning. Tre UI-prov hittade en identifierarkonflikt som nu är rättad och omprovas. Fysisk telefon, ljudrutter och signering återstår. |
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

I [nästa körning](https://github.com/AllCrow/Koran-test-/actions/runs/40153076721), kodcommit **`4645f6c3547057a6ee3f449664624af92116566b`**, passerade appbygget, 61 portabla Swift-tester, 28 backendtester och samtliga åtta hostade iOS-tester. De tre UI-proven kördes men misslyckades på versknapparnas identifierare. Den avgränsade rättningen finns i **`e7e859dc7a33734f59a731ea1ec6e386d6574589`** och [omprovas här](https://github.com/AllCrow/Koran-test-/actions/runs/40153744517). Ingen installerbar fysisk iPhone-version eller TestFlight-publicering finns ännu.

REA finns separat i `/workspace/rea`, commit `f196ebf80665107aedc16892af25a1e1f9f26f43`. Det har faktiskt inventerat Muaalems safetensors-fil och strömmat hela filen för SHA256; den matchar den fixerade HF-artefakten. [Oförändrad evidens och metod](docs/REA_MODEL_INSPECTION.md) är sparade. Detta är en artefaktundersökning, inte en kvalitetsbedömning. **Tarteels app eller servrar har inte analyserats.**

Användaren har iPhone men ingen Mac. Molnbaserad macOS-byggmiljö, Apple Developer-medlemskap, App Store Connect och signering behövs för den tänkta TestFlight-vägen. **Signering och TestFlight är inte färdiga.** Det förberedda GitHub Actions-flödet ersätter inte dessa förutsättningar, och en osignerad simulatorartefakt kan inte installeras på fysisk iPhone. Inga serverhemligheter eller signeringsnycklar ska checkas in.

## Återstående releasekrav och fortsatt arbete

1. Utöka modellproven från den verifierade begränsade körningen till flera verser, elever och verkliga förhållanden. Kör sakkunnig utvärdering; påstå ingen Tarteel-paritet innan den är styrkt.
2. Fortsätt verifiera uppladdade commits i användarens AllCrow/Koran-test-. Bevara lokala snapshots; följ det nya beslutet om publikt tills vidare.
3. Slutför simulatorns UI-prov efter det godkända Xcode-bygget och de åtta hostade testerna. Prova därefter läsning, arabisk text, ljudsynkning, nedladdning/offline, tafsir, streak, inspelning och eventuell analys på fysisk iPhone.
4. Mät telefonens värme, batteri, minne och svarstid. **Ingen fysisk temperatur- eller energimätning är ännu utförd.**
5. Slutför innehållsrättigheter, användarinformation, signering och TestFlight-distribution. Dokumentera vad som faktiskt passerar varje steg.

Arbetet är pågående. Portabla tester och bevarad källkod är framsteg, men de avslutar inte native-verifiering, modellkvalitet eller releasekrav.
