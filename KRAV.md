# Sakina – produktkrav

Uppdaterat: **2026-10-24**. Sakina är ett arbetsnamn. Dokumentet bevarar användarens krav och beslut; en kravpunkt är inte automatiskt en levererad eller verifierad funktion. Se [STATUS.md](STATUS.md) för genomförandet.

## Syfte och plattform

Skapa en koranapp som är behaglig att använda, uppmuntrar regelbunden läsning och håller telefonens batteri- och värmebelastning låg. Användaren ska inte behöva betala en obligatorisk månadsavgift för appens funktioner.

Användaren valde först Android och iPhone men har därefter uttryckligen prioriterat **iPhone** om det underlättar utvecklingen. Första versionen utvecklas därför som en native-app i SwiftUI för iPhone. Android är ett möjligt senare steg och ingår inte i den aktuella första leveransen.

Användaren har en iPhone men ingen Mac. Utvecklings- och distributionsvägen behöver därför fungera utan en lokal Mac hos användaren. TestFlight via en molnbaserad Mac är den tänkta vägen, men kräver bland annat ett fungerande Xcode-bygge, signering och tillgång till ett lämpligt Apple Developer-konto och App Store Connect. Dessa förutsättningar är ännu inte klara. Eventuella Apple- och molnbyggkostnader är skilda från ett abonnemang för appens användare.

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

Sparad läsposition, bokmärken och lokal inspelning/återlyssning ingår i den byggda appgrunden som stöd för läsning och övning. Lokal återlyssning uppfyller inte K08 och ska inte beskrivas som automatisk tajweedbedömning.

## Prestanda och kostnad

- Vanlig läsning och uppspelning ska använda så lite CPU och minne som rimligt möjligt. Läsning ska inte utlösa tung talanalys.
- Låg värmeutveckling och rimlig batteriförbrukning är krav som måste mätas på riktiga iPhone-modeller. De är inte bevisade genom källkodsgranskning eller genom tester i Linux.
- Jämför längre pass med läsning, uppspelning och framtida recitationsanalys. Följ energiförbrukning, termiskt tillstånd, minne och eventuell prestandasänkning. Konkreta gränsvärden behöver fastställas efter en baslinjemätning.
- Inget obligatoriskt månadsabonnemang ska krävas av slutanvändaren. Drift, modellkörning, Apple-medlemskap och molnbyggen kan ändå medföra kostnader för projektet. Valet av affärsmodell och finansiering återstår.
- Den nuvarande offlinefunktionen gäller **korantext och tajweeddata**. Ljudströmning och tafsir kräver internet. Offlinepaket för ljud eller tafsir är en senare fråga som även kräver rättighetskontroll.

## Automatisk recitationshjälp

Återkopplingen behöver kunna skilja mellan att hitta läsposition, upptäcka missade eller felaktiga ord och bedöma fonetiska tajweedfel. Exempelvis madd och ghunnah kräver bedömning av ljudet; en korrekt texttranskription räcker inte.

Innan K08 kan godkännas behövs en lämplig tal-/uttalsmodell, tydligt avgränsade stödda regler och recitationsformer, lagligt användbara data och en jämförelse med sakkunnigas bedömningar. Modellen behöver kunna avstå från en rättning när ljud eller säkerhet inte räcker. Ingen sådan automatisk bedömning är ansluten i den nuvarande appen.

## REA och källor

[REA](https://github.com/morluto/rea) betyder Reverse Engineer Anything och är ett separat analysverktyg. Lokalt finns det i `/workspace/rea` på commit `f196ebf80665107aedc16892af25a1e1f9f26f43`. REA:s källkod ingår inte som del av Sakina. Verktyget är MIT-licensierat, men det ger inte tillgång till en annan tjänsts servermodell, modellvikter eller träningsdata. Ingen faktisk analys av Tarteels app har ännu utförts.

Korantext och tajweed kommer från namngivna AlQuran Cloud-editioner. Originalögonblicksbilder, SHA256-hashar och källnotiser finns i projektet; se [CONTENT_SOURCES.json](CONTENT_SOURCES.json) och [NOTICE.txt](App/Resources/Quran/NOTICE.txt). Rättigheter för extern ljuddistribution och andra innehållspaket måste kontrolleras före publicering. Ingen svensk översättning eller svensk tafsir är utlovad eller paketerad.
