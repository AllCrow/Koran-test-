# Läsning, sökning och källor – 2026-10-25

Användaren godkände genomförandet av förbättringsförslagen med
”Okej kör på, kör dina rekommendationer”. Omgången bygger vidare på den
befintliga iPhone-appen. Alla ursprungliga krav och den ordagranna korantexten
bevaras. Se [kraven](../KRAV.md) för K17–K20 och
[aktuell verifiering](../STATUS.md) för faktiska källversioner och provutfall.

**Läge när detta underlag skrevs:** implementation och nya prov finns i
källkoden. Ny native-verifiering är inte ännu godkänd i detta dokument.
Tidigare godkända prov av en annan källversion blir inte bevis för dessa
ändringar. Resultat ska kompletteras först efter lästa CI-utfall.

## Fortsätt från den synliga versen

Vanlig rullning kunde tidigare lämna den sparade läspositionen vid det senaste
uttryckliga versvalet. Läsvyn mäter nu versrader i den synliga läsytan och
följer positionen efter en manuell dragning. Den första tydligt synliga versen
väljs; en gammal rad som bara har en smal kant kvar ska inte bestämma platsen.
En lång vers fortsätter däremot vara aktuell när början har rullat ovanför
skärmen men versen fortfarande upptar läsytan.

Sparningen är fördröjd kort för att undvika en skrivning vid varje
geometriförändring. Den aktuella kandidaten sparas även när läsvyn lämnas
eller appen går ur aktivt läge. Gamla surarader, skärmar bakom en dialog,
automatiska hopp och pågående recitation ska inte skapa en ny manuell
läsposition. Ett senare uttryckligt versval eller ljudval stoppar den äldre
rullningskandidaten. Startvyn får en tydlig läspositionsreferens.

Versmenyn har även **Spara läsplats här**, som sparar den uttryckligt valda
versen. Det ger ett tydligt alternativ vid bland annat VoiceOver-läsning,
som inte alltid använder samma draggest som visuell rullning.

Detta sparar en **versreferens**, aldrig en gissad läskredit eller en ljudtid.
Att rulla, öppna en sökträff eller återuppta läsningen ska inte ändra dagens
lästa antal eller streak. Ljudets sekundposition återställs inte av arbetet.

## Sök i den arabiska texten offline

Läsmenyn öppnar ett separat sökflöde för ord i hela den bundlade arabiska
korantexten. Minst två arabiska bokstäver behövs. Sökningen kan matcha text
med eller utan vokaltecken och några vanliga tangentbordsvarianter av
arabiska bokstäver. Normalisering görs på tillfälliga sökkopior; den
ursprungliga texten och dess teckenpositioner används inte som sökindex.

Träffarna följer Koranens ordning och visar den exakta lästextens
presentationsutdrag med sura och versreferens. Listan visar de första
50 träffarna och anger när fler matchningar finns, så att sökningen kan
preciseras. Sökningen begränsar indata och resultat, utför arbetet utanför
UI-aktorn och avbryter äldre förfrågningar. Ny inmatning rensar gamla träffar
direkt. Valet av en träff öppnar rätt sura och vers och ger ingen läskredit.

Inget nätanrop, ingen svensk översättning och ingen translittererad verstext
ingår. Den tidigare surasökningens latinska namn och arabiska siffror
behålls. Svensk sökning i en översättning förutsätter att en namngiven,
rättighetskontrollerad och granskad översättning först väljs.

## Tydliga källor och lokalt granskningsunderlag

Den nya källvyn visar de faktiska utgåvorna `quran-uthmani` och
`quran-tajweed`, Hafs-numrering, namngivna recitatörer och EveryAyah som
ljudkälla. Al-Muyassar (`ar.muyassar`) anges separat som en arabisk
tafsirförklaring med AlQuran Clouds källangivelse King Fahad Quran Complex.
Ingen svensk översättning eller AI-genererad tafsir påstås finnas.
Källänkar, ursprunglig notis och fontattribution bevaras.

Användaren kan välja **Granska innehåll** vid en vers. Vyn visar den valda
versreferensen och den arabiska Uthmani-texten, och låter användaren ange om
frågan gäller lästext, tajweedvisning, tafsir eller recitationsljud.
För en ljudfråga binds den valda recitatören till underlaget. En beskrivning
krävs innan rapporten kan skapas.

**Granska rapport** skapar endast en lokal förhandsvisning. Den visar exakt
JSON som sedan kan sparas via **Spara rapport i Filer**. Ändrad beskrivning
eller innehållstyp tar bort föregående förhandsvisning så att den måste
skapas på nytt. Rapporten innehåller schema, vald versreferens, källutgåvor,
tajweedval, innehållstyp och användarens beskrivning. Recitatör ingår endast
för ljudfrågor. Den arabiska versen visas för orientering men exporteras inte.

Appen skickar ingen rapport och väljer ingen mottagare. Läshistorik,
inspelningar, kontouppgifter och filvägar hämtas inte till rapporten.
Beskrivningen är uttryckligen användarens egen text; vyn uppmanar att
utelämna privata uppgifter. Inmatningen är begränsad både i antal tecken
och byte, så att extremt många kombinerande tecken inte kringgår gränsen.
Tangentbordet har en märkt **Klart**-kontroll för att nå granskning och
export även med stor text på en kompakt skärm.

Rapporten ändrar ingen korantext och klassificerar inget sakligt eller
religiöst fel automatiskt. Källspårbarhet och fungerande export innebär inte
sakkunnigt godkänt innehåll eller avslutade distributionsrättigheter.
[Rättighetsunderlaget](CONTENT_RIGHTS.md) och dess öppna frågor gäller kvar.

## Avsedd verifiering och kvarvarande provning

| Område | Prov som ska granskas |
| --- | --- |
| Synlig vers | Portabla `ReadingViewportTests`: långa verser, små synliga kanter, geometriska gränser, gamla suror, ogiltiga och icke ändliga mått. UI-flöde: verklig rullning, sparad position, omstart och oförändrad läskredit. |
| Verstextsökning | Portabla `QuranVerseSearchTests`: verklig bundlad text, vokaltecken/tangentbordsvarianter, ordagranna resultat, begränsningar, avbrott och tomma träffar. UI-flöde: skriv söktext, öppna träff och kontrollera rätt synlig vers samt oförändrat dagsmål. |
| Rapport | `ContentIssueReportTests`: avgränsat exportschema, rätt källkoppling, alla recitatörer, tom/överstor beskrivning och bevarade Unicode-skalärer. UI-flöde: stor text, korrekt vers, faktisk inmatning, tangentbordsstängning, förhandsvisning och synligt exportval. |
| Källor och äldre funktioner | Källvyns faktiska text och identiteter. Oförändrad korpus genom `verify_content.py`, resurs- och övningsreferenskontroller, befintliga läs-/ljud-/importprov och backendprov. |
| Native-paket | CI:s aktuella tre simulatorkonfigurationer, båda resultatsamlingarna och separat osignerat iPhoneOS-paket. Ett konfigurerat jobb räknas inte som ett passerat prov. |

Genomförd provning och exakta resultat ska hämtas från [STATUS.md](../STATUS.md).
Detta underlag påstår inga nya godkända provantal, ingen fysisk installation
och ingen förbättrad akustisk noggrannhet.

På fysisk iPhone återstår personlig signering och installation, vanlig
läsning och återupptagning med varierande textstorlekar, VoiceOver-navigering,
tangentbord och Filer-leverantörer samt energi- och värmemätning under längre
pass. Reporterns export ska provas genom att öppna den sparade filen och
jämföra med förhandsvisningen. Mobilradio, mikrofon, ljudrutter och låsta
repetitionspauser förblir separata fysiska prov. Ingen ny automatisk analys,
Tarteel-paritet eller sakkunnig certifiering följer av denna omgång.
