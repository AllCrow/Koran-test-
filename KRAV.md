# Sakina – produktkrav

Uppdaterat: **2026-10-25**. Sakina är ett arbetsnamn. Dokumentet bevarar användarens krav och beslut; en kravpunkt är inte automatiskt en levererad eller verifierad funktion. Se [STATUS.md](STATUS.md) för genomförandet.

## Syfte och plattform

Skapa en koranapp som är behaglig att använda, uppmuntrar regelbunden läsning och håller telefonens batteri- och värmebelastning låg. Användaren ska inte behöva betala en obligatorisk månadsavgift för appens funktioner.

Användaren valde först Android och iPhone men har därefter uttryckligen prioriterat **iPhone** om det underlättar utvecklingen. Första versionen utvecklas därför som en native-app i SwiftUI för iPhone. Android är ett möjligt senare steg och ingår inte i den aktuella första leveransen.

Användaren har en iPhone men ingen Mac. Utvecklings- och distributionsvägen behöver därför fungera utan en lokal Mac hos användaren. TestFlight via en molnbaserad Mac är den tänkta vägen, men kräver bland annat ett fungerande Xcode-bygge, signering och tillgång till ett lämpligt Apple Developer-konto och App Store Connect. Dessa förutsättningar är ännu inte klara. Eventuella Apple- och molnbyggkostnader är skilda från ett abonnemang för appens användare.

Senare förtydligande: användaren vill ha den riktiga iPhone-appen lokalt för eget
bruk, saknar Developer-medlemskap och har uttryckligen avstått från Safari/PWA.
En fysisk iPhone-IPA för personlig signering är nu byggd. En möjlig gratisväg är
SideStore med vanligt Apple-konto och lånad Mac/Windows för grundinstallation;
tillgång till en sådan dator är inte bekräftad. Privat användning tar inte bort
signeringskravet. TestFlight är ett alternativ som kräver medlemskap hos
utgivaren, inte hos testaren. Se [installationsguiden](docs/PERSONAL_IPHONE_INSTALL.md).

Den senaste instruktionen är att **fortsätta självständigt så långt det går mot en app av hög kvalitet**, även medan användaren sover, och att bevara allt arbete. Implementation, tester och dokumentation ska fortsätta utan nya rutinfrågor. Det innebär inte att otestade funktioner får beskrivas som färdiga eller att kvalitets- och distributionskrav kan hoppas över.

Den 25 oktober gav användaren en timmes arbetsutrymme för finjusteringar. Arbetet fokuserar därför på befintliga flöden, felrättning, tillgänglighet och verifiering, med bevarad källkod och aktuell status.

Senaste fortsättningsbeskedet ersätter den tillfälliga timgränsen: arbeta så länge
det behövs med optimering och byggfel för att förbereda ett bra personligt
iPhone-test när användaren får tillgång till en dator. Datoråtkomst finns ännu
inte nu. Källkod, krav och faktisk status ska fortsätta bevaras; signering och
fysisk provning ska inte beskrivas som genomförda i förväg.

## Funktionella krav

| ID | Krav | Avsedd kontroll |
| --- | --- | --- |
| K01 | Fullständig och källtrogen korantext med bevarad arabisk ortografi och diakritik. | 114 suror och 6 236 ayat; varje referens och text kontrolleras mot det sparade källmaterialet. |
| K02 | Korantexten ska kunna läsas offline. | Kallstart och läsning av samtliga suror utan nätverk. |
| K03 | Valbar tajweedvisning. | Färger kan slås av och på utan att korantext går förlorad; regelmarkeringarna följer rätt källedition. |
| K04 | Tafsir med tydlig källangivelse. | Visa namngiven källa och skilj förklaringen från själva korantexten och från en översättning. Språk utöver nuvarande arabiska källa är inte beslutat. |
| K05 | En uppmuntrande streak som stödjer fortsatt läsning. | Meningsfullt läsmål, tydliga framsteg, inga dubbla dagsräkningar och korrekt hantering av lokala kalenderdagar. Ett brutet mönster ska mötas vänligt. |
| K06 | Börja med tre recitatörer: Mishary Rashid al-Afasy, Mahmoud Khalil al-Husary och Muhammad Siddiq al-Minshawi. | Kontrollera att vald recitatör och vers ger avsett ljud. |
| K07 | Det som spelas ska hänga ihop med texten. | Versmarkering ska följa faktisk uppspelning och säkra versreferenser, även vid paus, buffring och byte av recitatör. Ordmarkering kräver verifierade tider för varje inspelning och är inte ett löfte för första versionen. |
| K08 | Automatisk hjälp med den egna recitationen och tajweed, med **minst samma kvalitet som relevant funktion i Tarteels betalversion** som mål. | Jämför samma verkliga inspelningar och låt sakkunniga bedöma rättningar och missade fel. Ordigenkänning är inte tillräcklig verifiering av tajweed. Detta mål är ännu inte levererat. |
| K09 | Använd REA där det är relevant för undersökningen av en befintlig lösning. | Dokumentera målfil, verktyg, belägg och begränsningar när en faktisk undersökning görs. REA ersätter inte en talmodell. |
| K10 | Bevara kod, krav och status i ett separat **privat GitHub-repo under AllCrow**. | Verifiera repositoryns ägare, privata synlighet och uppladdad commit. Inga hemligheter eller signeringsnycklar i repot. |

Senare beslut 2026-10-25: användaren skapade [AllCrow/Koran-test-](https://github.com/AllCrow/Koran-test-) och godkände uttryckligen att repot får vara **publikt tills vidare**, med möjlighet att göra det privat senare. Det beslutet ersätter det tidigare privatkravet för den aktuella uppladdningen. Ägare, synlighet och den faktiska uppladdningen ska fortfarande verifieras.

Sparad läsposition, bokmärken och lokal inspelning/återlyssning ingår i den byggda appgrunden som stöd för läsning och övning. Lokal återlyssning uppfyller inte K08 och ska inte beskrivas som automatisk tajweedbedömning.

Läsdata kan exporteras till en separat fil och återimporteras med sammanfogning.
Det stöder personlig ominstallation utan att kräva konto eller automatisk
molnsynk. Exporten omfattar läsposition, bokmärken och läshistorik, inte röst,
nedladdad recitation eller appinställningar. Avinstallation utan separat kopia
raderar de lokala uppgifterna.

Ljud kan nu uttryckligen laddas ned per sura och recitatör; spelaren föredrar den lokala filen när den finns. Ingen recitation är förpaketerad. Denna implementation behöver fortfarande native-testas på iPhone. Amiri Quran är bundlad med originallicens och verifierad täckning av lästextens synliga tecken; faktisk återgivning på iPhone återstår.

## Prestanda och kostnad

- Vanlig läsning och uppspelning ska använda så lite CPU och minne som rimligt möjligt. Läsning ska inte utlösa tung talanalys.
- Låg värmeutveckling och rimlig batteriförbrukning är krav som måste mätas på riktiga iPhone-modeller. De är inte bevisade genom källkodsgranskning eller genom tester i Linux.
- Jämför längre pass med läsning, uppspelning och framtida recitationsanalys. Följ energiförbrukning, termiskt tillstånd, minne och eventuell prestandasänkning. Konkreta gränsvärden behöver fastställas efter en baslinjemätning.
- Inget obligatoriskt månadsabonnemang ska krävas av slutanvändaren. Drift, modellkörning, Apple-medlemskap och molnbyggen kan ändå medföra kostnader för projektet. Valet av affärsmodell och finansiering återstår.
- Korantext och tajweeddata är paketerade för offlinebruk. Ljud ska kunna användas offline efter en uttrycklig nedladdning; hämtning och strömning kräver internet. Tafsir är fortfarande online. Ljudnedladdningens native-funktion och rättigheter behöver verifieras före release.

## Automatisk recitationshjälp

Återkopplingen behöver kunna skilja mellan att hitta läsposition, upptäcka missade eller felaktiga ord och bedöma fonetiska tajweedfel. Exempelvis madd och ghunnah kräver bedömning av ljudet; en korrekt texttranskription räcker inte.

Innan K08 kan godkännas behövs en lämplig tal-/uttalsmodell, tydligt avgränsade stödda regler och recitationsformer, lagligt användbara data och en jämförelse med sakkunnigas bedömningar. Modellen behöver kunna avstå från en rättning när ljud eller säkerhet inte räcker. En **experimentell Muaalem-backend, typad native-klient och återkopplingsvy är nu integrerade**, men funktionen är avstängd som standard, har ingen konfigurerad publik server och är inte kvalitetsgodkänd. Röst skickas bara efter en uttrycklig analysåtgärd i en aktiverad byggversion. Ingen automatisk uppladdning eller övergripande uttalspoäng ingår. Aktuell modellväg jämför fonetiska utdata och bedömer ännu inte alla sifat-egenskaper. Verklig CPU-inferens har utförts genom API:t, senast med 35 indata: 33 referensklipp från två suror med tre recitatörer, en avsiktligt annan vers och tystnad. Ett enskilt referensfall behöver sakkunnig källklippsgranskning och har inte klassificerats som korrekt/felaktig indikation. Detta är funktionsprov utan oberoende expertetiketter, ingen mätning av generell noggrannhet eller Tarteel-paritet. Se [resultatrapporten](docs/MODEL_SMOKE_RESULTS.md).

En separat källfixerad övningsutgåva används gemensamt av backend och app, eftersom läsvyns rikare textutgåva inte direkt passar modellens vokabulär. Återkopplingen ska markeras i den exakta övningsreferensen, med tydlig källangivelse; dess positioner får inte appliceras på läsvyns andra textutgåva. Se [modellunderlaget](docs/RECITATION_RESEARCH.md).

## REA och källor

[REA](https://github.com/morluto/rea) betyder Reverse Engineer Anything och är ett separat analysverktyg. Lokalt finns det i `/workspace/rea` på commit `f196ebf80665107aedc16892af25a1e1f9f26f43`. REA:s källkod ingår inte som del av Sakina. Verktyget är MIT-licensierat, men det ger inte tillgång till en annan tjänsts servermodell, modellvikter eller träningsdata. Ingen faktisk analys av Tarteels app har ännu utförts.

Korantext och tajweed kommer från namngivna AlQuran Cloud-editioner. Originalögonblicksbilder, SHA256-hashar och källnotiser finns i projektet; se [CONTENT_SOURCES.json](CONTENT_SOURCES.json) och [NOTICE.txt](App/Resources/Quran/NOTICE.txt). Rättigheter för extern ljuddistribution och andra innehållspaket måste kontrolleras före publicering. Ingen svensk översättning eller svensk tafsir är utlovad eller paketerad.

REA har nu faktiskt undersökt Muaalems viktfil och verifierat dess fullfilshash och tensordeklarationer; se [inspektionen](docs/REA_MODEL_INSPECTION.md). Vikterna finns i en extern utvecklingscache och ska inte läggas i Git. En artefaktinspektion ersätter inte mätning av akustisk kvalitet. Tarteels app och servrar har inte analyserats.

## Krav före offentlig release

- Verkligt Xcode-bygge, simulatorprov och fysiska iPhone-tester av läsning, arabisk återgivning, ljud, nedladdning, inspelning och återkoppling.
- Uppmätt värme-, energi- och minnesbeteende på representativa iPhone-modeller.
- Sakkunnigt kontrollerad recitationshjälp och jämförelse som styrker kvalitetsanspråk. **Kravet om Tarteels betalnivå är inte uppfyllt.**
- Färdigställd innehålls-/ljudrättighetskontroll, korrekt användarinformation och validerad hantering av eventuell skickad röst.
- Fungerande signering, Apple Developer/App Store Connect och TestFlight-väg utan krav på egen Mac hos användaren.
- Verifierad GitHub-lagring under AllCrow enligt det uppdaterade synlighetsbeslutet. Lokala Git-snapshots och dokumentation ska bevaras; en senare ändring till privat kräver ägarens inställningsändring eftersom integrationen nekas den åtgärden (403).
