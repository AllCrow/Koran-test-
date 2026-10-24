# Sakina – utvecklingsstatus

Uppdaterat: **2026-10-24**. Detta är en utvecklingsgrund i källkod, inte en signerad eller färdigtestad iPhone-app. Kraven finns i [KRAV.md](KRAV.md).

## Det som finns i projektet

| Del | Nuvarande läge | Kvar att verifiera eller bygga |
| --- | --- | --- |
| iPhone-app | SwiftUI-källkod för läsning, startsida, övning och inställningar. Sakina är arbetsnamnet. | Kompilering med Xcode, simulator och verklig iPhone. |
| Korantext | Samtliga 114 suror och 6 236 ayat är paketerade lokalt, uppdelade per sura. | Visuell arabisk återgivning och fullständig läsning på iPhone. |
| Tajweedfärger | Separat annoterad edition och parser; valbar färgvisning i läsaren. | Kontroll av fonter, diakritik, färger och växling mellan editionerna på enheten. |
| Läsprogression | Lokal läsposition, bokmärken, dagligt mål och streak finns i källkod. Dagar räknas från uttrycklig läsmarkering, inte bara från att öppna appen. Kärntesterna passerar. | Integration och beteende på iPhone. |
| Recitation | Källkod för en AVPlayer och tre recitatörer: al-Afasy, al-Husary och al-Minshawi. Strömning använder referens per vers och spelarhändelser. | Faktisk ljud/textkoppling, buffring, avbrott, bakgrundsljud och recitatörsbyte på iPhone. Ingen verifierad ordsynkning. |
| Tafsir | Al-Muyassar på arabiska hämtas online med källangivelse. | iOS-nätverksflöde, felhantering och visuell återgivning. Ingen offline-tafsir eller svensk tafsir levereras. |
| Egen röst | Lokal inspelning och återlyssning finns i källkod. Ingen röst skickas till en analystjänst av den här versionen. | Mikrofonbehörighet, verklig inspelning, radering och ljudsessioner på iPhone. |
| Automatisk tajweedbedömning | **Saknas.** Ingen modell bedömer uttal och ingen automatisk rättning eller poängsättning ges. | Modellval, integration, data, sakkunnig validering och kvalitetstester. Tarteel-målet är inte uppnått. |
| Prestanda | Grunden undviker tung talanalys under läsning och laddar text per sura. | Värme- och batterimätning på fysiska iPhone-modeller. Ingen uppmätt prestandagaranti. |
| Avgifter | Ingen abonnemangs- eller betalningsfunktion är implementerad. | Finansiering och eventuella externa driftskostnader behöver beslutas. |

Offline gäller korantexten och tajweedmaterialet. **Recitationsljud och tafsir behöver internet i den här versionen.** Ljud, tafsir och översättningar ingår inte i det paketerade koranmaterialet.

## Utförd verifiering

`python3 scripts/verify_content.py` har körts och passerat i molnmiljön. Kontrollen omfattar:

- 114 suror och 6 236 konsekutiva, entydiga ayah-referenser med rätt antal per sura.
- Överensstämmelse mellan suraindex och kapitelmetadata.
- SHA256 och byteantal för samtliga koranresurser och de sparade originalögonblicksbilderna.
- Exakt UTF-8-överensstämmelse mellan varje paketerad arabisk text och motsvarande källedition, inklusive diakritik och osynliga tecken.
- Källangivelse och bevarad Tanzil-notis.

Offlineåterskapande från originalögonblicksbilder har också kontrollerats som deterministiskt. Separata negativa kontroller visade att verifieraren avvisar ändrad arabisk text, en extra kapitelresurs och ändrad text även när dess resurshash har skrivits om.

Detta styrker importens struktur och bevarandet av det hämtade materialet. Det är inte en oberoende lärd certifiering av källmaterialet eller ett bevis på korrekt visuell återgivning på iPhone.

Dessutom genomfört i molnmiljön:

- **14 Swift-kärntester passerade, 0 fel**, med Swift 6.0.3 i Linux-container i Swift 5-språkläge. Testerna täcker versreferenser, recitatörernas ljudadresser, streak inklusive sommartid och resor samt tajweedparserns bevarande av Unicode.
- Samtliga appfiler har passerat Swift-kompilatorns syntaxkontroll (`swiftc -frontend -parse`).
- De Foundation-baserade koran- och tafsirrepositoryerna har typkontrollerats mot QuranCore på Linux.
- Xcode-projektets OpenStep-format har parsats och alla filreferenser har kontrollerats. Projektgeneratorn körs med Python 3 utan externa beroenden.

Syntaxkontroll och Linux-typkontroll ersätter inte ett Xcode-bygge av SwiftUI och AVFoundation.

## Tester och distribution som återstår

- Kärntesterna är körda enligt ovan. iOS-integrations- och enhetstester återstår.
- Inget Xcode-bygge, ingen iOS-simulator och inga tester på fysisk iPhone är genomförda.
- Signering, Apple Developer-koppling, App Store Connect och TestFlight är inte färdiga.
- Användaren har ingen Mac. Den tänkta distributionsvägen är en molnbaserad Mac med Xcode och korrekt signering, därefter installation via TestFlight på användarens iPhone. Den vägen är ännu inte verifierad.
- Apple-medlemskap, molnbyggmiljö och säkert tillförda signeringsbehörigheter kan behövas. Hemligheter och signeringsmaterial ska hållas utanför Git.
- Det separata privata GitHub-repot under **AllCrow** har begärts. Autentiserad anslutning till AllCrow är bekräftad, men skapande nekades av GitHub med HTTP 403, `Resource not accessible by integration`. Ett tomt privat `AllCrow/koran-ios` behöver skapas av kontoinnehavaren innan arbetet kan pushas. Ingen lyckad GitHub-uppladdning är ännu bekräftad.

## Innehåll och kända skillnader

Resurserna tar cirka **4,78 MB**, inklusive komprimerade originalögonblicksbilder och notiser. Proveniens och hashmanifest finns i [CONTENT_SOURCES.json](CONTENT_SOURCES.json).

Uthmani-editionen prefixerar Basmala till första ayah i suror utom 1 och 9. Tajweed-editionen gör inte det. Läsarens presentation behöver hantera den som en separat rubrik när det är aktuellt; Unicodepositioner kan inte överföras mellan editionerna. Källsträngarna i resurserna har inte ändrats.

Allmänt tillgängliga ljudfiler och API:er innebär inte att alla rättigheter för paketering och kommersiell distribution är verifierade. Särskilt ljudrättigheter och eventuella framtida offlinepaket återstår att klarlägga före publicering. Se även [källnotiserna](App/Resources/Quran/NOTICE.txt).

REA finns separat i `/workspace/rea`, commit `f196ebf80665107aedc16892af25a1e1f9f26f43`. Det är ett verktyg för undersökning av befintliga program, inte Sakinas talmodell. REA är inte en del av appens källkod och Tarteels app har ännu inte analyserats.

## Nästa konkreta steg

1. Spara källkod, krav och denna status i det begärda privata AllCrow-repot och verifiera synlighet samt uppladdad commit.
2. Kör det förberedda GitHub Actions-flödet på macOS för både kärntester och verkligt Xcode-bygge.
3. Anslut signering och distribuera en intern testversion via TestFlight när förutsättningarna finns.
4. Prova läsning, arabisk återgivning, versljud, tafsir, streak och inspelning på iPhone. Mät därefter värme, energi och minne.
5. Utred och bygg den separata recitationsanalysen. Jämför den mot Tarteels relevanta betal-funktioner och sakkunnigas bedömningar innan likvärdig kvalitet påstås.
