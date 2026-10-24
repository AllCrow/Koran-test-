# Sakina – utvecklingsstatus

Uppdaterat: **2026-10-24**. Utvecklingen fortsätter enligt användarens instruktion att arbeta självständigt mot hög kvalitet och bevara arbetet. Detta är en utvecklingsversion i källkod; ingen signerad eller färdigtestad iPhone-release är publicerad. Produktkraven finns i [KRAV.md](KRAV.md).

## Implementation

| Del | Nuvarande läge | Återstående kontroll |
| --- | --- | --- |
| iPhone-app | SwiftUI för iOS 17+, startsida, läsare, övning, inställningar och ljudnedladdningar. | Verkligt Xcode-bygge, simulator och fysisk iPhone. |
| Korantext | Alla 114 suror och 6 236 ayat lokalt, uppdelade per sura. Källmaterial och hashmanifest ingår. | Visuell arabisk återgivning och läsflöde på enheten. |
| Tajweedvisning | Separat annoterad edition, parser och på/av-val. | Färger, diakritik och växling på iPhone. |
| Arabisk font | Amiri Quran är bundlad med OFL-licens och fixerad proveniens. Hashar och täckning av lästextens synliga tecken är verifierade. | Formgivning, radbrytning och tillgänglighet på iPhone. Glyph-täckning är inte ett renderingsprov. |
| Läsprogression | Lokal läsposition, bokmärken, dagligt mål och uppmuntrande streak. Uttrycklig läsmarkering räknas, inte bara appstart. | Integrerat beteende på iPhone. Portabla kärntester passerar. |
| Recitation | AVPlayer med al-Afasy, al-Husary och al-Minshawi, en fil per vers och spelarstyrd markering. | Ljud/textkoppling, buffring, avbrott, bakgrund och recitatörsbyte på iPhone. Ord-för-ord-synkning är inte verifierad. |
| Ljud offline | Uttrycklig nedladdning per sura/recitatör, framsteg, avbrytning, fortsättning och radering finns i native-koden. Spelaren föredrar lokal fil. Inget ljud är förpaketerat. | Nedladdnings- och offlineflödet är ännu inte native-testat på iPhone. Ljudrättigheter återstår. |
| Tafsir | Al-Muyassar på arabiska hämtas online med källangivelse. | iOS-nätverksflöde och visuell återgivning. Ingen offline-tafsir eller svensk tafsir ingår. |
| Egen röst | Lokal inspelning och återlyssning. | Mikrofonbehörighet, ljudsessioner och radering på iPhone. Ingen automatisk uppladdning. |
| Experimentell analys | Separat Muaalem-backend, typad native-klient, svarskontroller och återkopplingsvy är integrerade. **Avstängd som standard**, tom HTTPS-adress och ingen publik driftsättning. | Faktisk modellkörning, native-integration och sakkunnig kvalitet. Ingen automatisk uttalspoäng ges. |
| Modellreferens | Separat quran-transcript-0.6.4-utgåva för backend och app, cirka 2,01 MB. Alla 6 236 referenser och 112 öppningsfraser klarar fonemvokabulär-/mappningskontroll. | Akustisk bedömning av inspelningar. Återkoppling visas i exakt referenstext, inte med offsets i läsvyns andra edition. |
| Prestanda och kostnad | Läsaren utlöser ingen tung talanalys. Ingen obligatorisk abonnemangsfunktion är implementerad. | Fysiska temperatur-/energimätningar och finansiering av eventuell serverdrift. |

Korantext, tajweeddata och övningsreferenser är lokala. Recitationsljud kräver nät tills respektive fil har laddats ned. Tafsir kräver fortfarande internet. Ljud och tafsir ingår inte i de paketerade koranresurserna.

## Genomförd verifiering

| Kontroll | Resultat | Omfattning |
| --- | --- | --- |
| Portabla Swift-tester | **55 passerade, 0 fel** | 21 kärntester, 16 datatester och 18 övnings-/analyskontraktstester. Körda på Linux med Swift, inte via iOS-runtime. |
| Backendtester | **16 passerade** | HTTP-kontrakt, validering, resursgränser och ljudavkodning. Riktig M4A-avkodning kördes i den fixerade ML-miljön. Motorersättning i kontrakttester mäter inte modellens kvalitet. |
| Koranresurser | **Godkända** | 114 suror, 6 236 konsekutiva referenser, metadatakoppling, UTF-8-bevarande och samtliga käll-/resurshashar. |
| Övningsreferenser | **Godkända** | Fixerad källversion, originaldata/API-hashar, filinventering, licensnotiser samt fonemkompatibilitet för samtliga referenser. |
| Font och resurser | **Godkända** | Amiri Quran-/OFL-hashar, resursdeklarationer och synlig teckentäckning för kanonisk lästext. |
| Native Xcode-/enhetsprov | **Inte utförda** | SwiftUI, AVFoundation, fysisk telefon och signering är inte godkända genom portabla tester. |
| Verklig Muaalem-inferens | **Första prov väntar** | Modellvikter hämtas separat; inget lyckat CPU-inferensprov är ännu bekräftat i denna status. |

Koranverifieringen körs med `python3 scripts/verify_content.py`. Offlineåterskapande från källögonblicksbilder har kontrollerats som deterministiskt. Negativa kontroller avvisar ändrad arabisk text, en extra kapitelresurs och ändrad text även när dess resurshash har skrivits om. Det är inte en oberoende lärd certifiering av källan.

Övningsreferenserna kontrolleras med `python3 scripts/export_practice_references.py --verify`. Det separata datasetet behövs eftersom läsvyns rikare Uthmani-text lämnar vissa tecken utanför modellens fonemvokabulär. Inga originalsträngar i läsvyn har ändrats för att passa modellen.

Swift-syntax, Foundation-baserad typkontroll och Xcode-projektets struktur har också kontrollerats under arbetet. Detta ersätter inte ett riktigt Xcode-bygge. Kommandon och projektlayout finns i [README.md](README.md); backendens testomfattning finns i [backend/README.md](backend/README.md).

## Recitationsanalysens faktiska gränser

Standardkonfigurationen är `SAKINA_ENABLE_EXPERIMENTAL_ANALYSIS=false` och `SAKINA_ANALYSIS_URL` tom. En aktiverad experimentell byggversion kräver en nåbar HTTPS-server och en uttrycklig analysåtgärd. Det finns ingen automatisk uppladdning och ingen dold modellkörning medan användaren läser.

Backend använder en fixerad MIT-licensierad PyPI-release av `quran-muaalem` 0.2.2, `quran-transcript` 0.6.4 och modellrevision `01a1ef9fbe40d144ef845101e89ff924aed3fef5`. Dagens Git-main har andra licensvillkor och är inte samma valda artefakt. Licenser och proveniens är dokumenterade.

Aktuell kod jämför Muaalems fonemutdata med referensen. Separata sifat-huvuden ger ännu ingen egen återkoppling. Därför är alla tajweed- och uttalsegenskaper inte bedömda. Fasta Hafs-/madd-antaganden och pauser kan påverka indikationerna. Ingen jämförelse med Tarteels aktuella betalversion har gjorts. **Kravet om minst Tarteels kvalitet är inte uppfyllt eller styrkt.**

Den cirka 2,42 GB stora viktfilen hämtas till en extern utvecklingscache under `/workspace/scratch/sakina-model-cache`, utanför apprepot. Den ska inte läggas i Git eller beskrivas som bundlad iPhone-AI. Första faktiska CPU-inferensprov, minnesmätning och modellfilsundersökning återstår att bekräfta. Se [modellunderlaget](docs/RECITATION_RESEARCH.md) för publicerade resultat och begränsningar; de är inte våra egna kvalitetsmätningar.

## Innehåll och rättigheter

Den kanoniska koranresursen är cirka **4,78 MB**, inklusive komprimerade originalögonblicksbilder och notiser. Övningsreferenserna tillför cirka **2,01 MB**. Amiri Quran distribueras separat med oförändrad OFL-licens. Proveniens finns i [CONTENT_SOURCES.json](CONTENT_SOURCES.json), [fontnotisen](App/Resources/Fonts/SOURCE.md) och [övningsreferensernas index](Sources/QuranPractice/Resources/PracticeReferences/index.json).

Uthmani- och tajweededitionerna skiljer sig i tecken och Basmala-gruppering. Uthmani har två exakta öppningsprefix: det vanliga i 110 suror och en variant med shadda på första bokstaven i 95 och 97. Presentationen känner igen båda och bevarar källans prefix; Unicodepositioner överförs inte mellan editioner. Övningsåterkopplingen använder dessutom sin egen namngivna referensutgåva.

Tillgängliga API:er och ljudfiler betyder inte att alla rättigheter för appens distribution är färdigkontrollerade. **Ljudrättigheter och övriga villkor för offentlig release är inte avslutade.** Se [källnotiserna](App/Resources/Quran/NOTICE.txt).

## Bevarande, REA och distribution

Ett lokalt Git-repo finns. Den första sparade snapshoten är `238ac4b`; fortsatt utveckling och dokumentation bevaras i följande snapshots. Se lokal Git-logg för senaste commit. Denna status innebär inte att det senaste arbetsträdet redan är uppladdat eller att utvecklingen är färdig.

Ett separat **privat GitHub-repo under AllCrow** är begärt. Autentiserad anslutning är bekräftad, men skapande nekades med HTTP 403, `Resource not accessible by integration`. Ingen ny GitHub-repository eller lyckad uppladdning är bekräftad. Arbetet fortsätter lokalt utan nya rutinfrågor medan denna externa behörighetsbegränsning kvarstår.

REA finns separat i `/workspace/rea`, commit `f196ebf80665107aedc16892af25a1e1f9f26f43`. Det är ett analysverktyg, inte appens talmodell. Tarteel har inte analyserats. Inspektion av Muaalems faktiska viktfil kan göras när nedladdningen är färdig; den är ännu inte genomförd i denna status.

Användaren har iPhone men ingen Mac. Molnbaserad macOS-byggmiljö, Apple Developer-medlemskap, App Store Connect och signering behövs för den tänkta TestFlight-vägen. **Signering och TestFlight är inte färdiga.** Det förberedda GitHub Actions-flödet ersätter inte dessa förutsättningar, och en osignerad simulatorartefakt kan inte installeras på fysisk iPhone. Inga serverhemligheter eller signeringsnycklar ska checkas in.

## Återstående releasekrav och fortsatt arbete

1. Slutför faktiskt modellprov och dokumentera resultat samt begränsningar. Kör därefter sakkunnig utvärdering av verkliga inspelningar; påstå ingen Tarteel-paritet innan den är styrkt.
2. Verifiera privat GitHub-bevarande under AllCrow när rätt åtkomst finns. Behåll lokala snapshots under tiden.
3. Kör riktigt Xcode-bygge och simulatorprov i macOS. Prova därefter läsning, arabisk text, ljudsynkning, nedladdning/offline, tafsir, streak, inspelning och eventuell analys på fysisk iPhone.
4. Mät telefonens värme, batteri, minne och svarstid. **Ingen fysisk temperatur- eller energimätning är ännu utförd.**
5. Slutför innehållsrättigheter, användarinformation, signering och TestFlight-distribution. Dokumentera vad som faktiskt passerar varje steg.

Arbetet är pågående. Portabla tester och bevarad källkod är framsteg, men de avslutar inte native-verifiering, modellkvalitet eller releasekrav.
