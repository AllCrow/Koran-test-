# Verkliga CPU-prov av recitationsanalysen

Utfört **2026-10-24**. Det här är ett funktionellt prov av den riktiga
Muaalem-modellen genom backendens HTTP-API i samma process. Det är inte en
noggrannhetsstudie, ett iPhone-prov eller en jämförelse med Tarteel.

Fullständiga svar, klippadresser, uppladdningshashar, källkodsidentifierare och
körmiljö finns i [det första provets resultatfil](evidence/model-smoke-2026-10-24.json)
och [det utökade provet med 35 indata](evidence/model-baseline-2026-10-24.json).

## Resultat

Alla anrop använde den valda referensen **1:1**. Inspelningarna hämtades från
EveryAyah och avkodades av tjänsten. Ingen syntetisk modellmotor användes i
detta prov. Tystnadskontrollen är en separat genererad ljudfil.

| Insignal | API-status | Antal indikationer | Uppmätt tid |
| --- | --- | --- | --- |
| Al-Afasy, 1:1 | `assessed` | 0 | 3,282 s |
| Al-Husary, 1:1 | `assessed` | 0 | 2,398 s |
| Al-Minshawi, 1:1 | `assessed` | 0 | 2,283 s |
| Al-Afasy, **112:1** mot referens 1:1 | `assessed` | 15 | 1,561 s |
| Tystnad | `insufficient_audio` | 0 | 0,003 s |

Noll indikationer betyder att denna fonetiska jämförelse inte presenterade någon
skillnad. Det är inget intyg på korrekt recitation. De 15 indikationerna för en
avsiktligt annan vers visar ett avvikande utfall men är inte 15 lärarverifierade
uttalsfel.

## Madd arid: upptäckt och avgränsad ändring

Den [tidigare körningen](evidence/model-smoke-before-variants-2026-10-24.json)
finns kvar oförändrad. Den gav en indikation på al-Minshawis 1:1 när referensens
slutmadd hade fyra harakat och modellens utdata motsvarade en annan längd.

Backend accepterar nu **2, 4 eller 6** för samma långa vokal i en uttryckligen
typad `AaredMaddRule`. Undantaget kräver rätt feltyp, exakt denna enda regel,
matchande vokalslag, samma upprepade vokaltecken och konsekventa angivna längder.
Det döljer inte andra regler, andra vokaler, blandade regelavvikelser eller
vanliga/tashkeel-fel. Referensgeneratorn kan fortfarande utgå från fyra harakat;
undantaget gäller vilka jämförelseskillnader som presenteras.

Efter ändringen presenterar ingen av de tre 1:1-inspelningarna indikationer.
Den avsiktligt andra versen ger fortfarande 15. Detta är ett avgränsat
regressionsprov. Det fastställer inte korrekt hantering av alla korrekta
Hafs-varianter eller pauser.

## Körmiljö och resursmått

| Uppgift | Värde i rapporten |
| --- | --- |
| Modell | `obadx/muaalem-model-v3_2` |
| Fixerad revision | `01a1ef9fbe40d144ef845101e89ff924aed3fef5` |
| Plattform | Linux x86_64, CPU |
| Python / PyTorch | 3.12.14 / 2.7.1+cpu |
| CPU-trådar | 2 |
| Uppmätt modelladdning | 2,041 s |
| Högsta rapporterade RSS för processen | 2 749,1 MiB |

Modellen fanns redan i lokal filcache; måtten omfattar inte nedladdning eller
en dokumenterad kall disk-/sidcache. Klipptiderna gäller denna körnings anrop
genom ett in-process HTTP-testgränssnitt. De är inte svarstider över ett publikt
nätverk, telefonlatens, en statistisk p95 eller prestanda för långa sessioner.
RSS gäller Linux-processen, inte en iPhones minne, effekt eller temperatur.

## Utökat funktionsprov: 35 indata

En senare körning samma dag omfattade alla sju verser i al-Fatiha och alla
fyra i al-Ikhlas med var och en av de tre recitatörerna: **33 referensklipp**,
plus en kontroll med avsiktligt annan vers och en tystnadskontroll.

| Insignal | Utfall |
| --- | --- |
| 33 referensklipp, två suror och tre recitatörer | Samtliga fick `assessed`. 32 gav noll presenterade indikationer; ett klipp gav en indikation. |
| Al-Afasy 112:1 mot referens 1:1 | `assessed`, 15 indikationer. |
| Tystnad | `insufficient_audio`, inga indikationer. |

Det enskilda referensfallet är **al-Afasy 112:2**. Svaret anger `normal`/`delete`
vid referensens första Unicode-skalär, förväntat fonem `ءَ` och tom observerad
sträng. Fallet behöver granskas genom lyssning på källklippet och sakkunnig
bedömning av onset, wasl/versgräns, referens, lässtil och modellutdata. Det är
**inte klassificerat som vare sig en falsk indikation eller ett verkligt
uttalsfel**. Någon noggrannhetsprocent beräknas därför inte från dessa antal.

I det utökade provet tog modelladdning från lokala filer **1,911 sekunder**,
och processens rapporterade topp-RSS var **3 240,5 MiB**. De 33 referensanropen
tog **1,343–8,475 sekunder**, med median **2,351 sekunder**, beräknat direkt ur
de sparade klipptiderna. Kontrollen med annan vers tog 1,678 sekunder och
tystnaden 0,009 sekunder. Miljön var fortsatt Linux x86_64, PyTorch 2.7.1+cpu
och två CPU-trådar, med lokala modellfiler och in-process HTTP-anrop. Ingen
publik nätverkslatens, iPhone-prestanda eller fysisk energiförbrukning har mätts.

Den bredare körningen utökar funktionsprovet till elva versreferenser, men
omfattar fortfarande bara två suror och publicerade recitatörer. Träningsöverlapp
är okänt och oberoende expertetiketter saknas. Antal uteblivna indikationer
ska inte tolkas som träffsäkerhet, och testet godkänner inte en färdig
uttalslärare.

## Vad som återstår att visa

- Det första provet täcker en vers och det utökade provet två suror med elva versreferenser. Båda använder tre publicerade recitatörer; eventuellt träningsöverlapp är inte utrett.
- Det finns inga oberoende expertetiketter för uttalsfel i detta prov, inga elevgrupper och ingen mätning av precision/recall per tajweedregel.
- Sifat-huvudena används ännu inte för återkoppling; alla uttalsegenskaper bedöms därför inte.
- Den avsiktligt andra versen och tystnaden är begränsade kontroller, inte bevis på robusthet mot brus, dialekter, olika mikrofoner, pauser eller godtyckliga fel.
- Ingen publik HTTPS-driftsättning, nätverkskörning från iPhone, Apple-SDK-kompilering, TestFlight-distribution eller fysisk energimätning har verifierats genom detta prov.
- Tarteels aktuella betalversion har inte jämförts. **Kvalitetsmålet är fortfarande inte uppnått eller styrkt.**

Modellens faktiska fil har också undersökts med REA; se
[artefaktinspektionen](REA_MODEL_INSPECTION.md). Den kontrollen fastställer
deklarationer och filidentitet, medan provet här visar att verklig inferens och
API-svar fungerar för de angivna insignalernas begränsade fall. Ingen av
kontrollerna ersätter den bredare utvärderingen i
[forskningsunderlaget](RECITATION_RESEARCH.md).

## Fler verkliga funktionsprov 2026-10-25

En ytterligare körning har genomförts med **18 hela källklipp**: öppningsversen
**2:1, 9:1, 95:1, 97:1, 113:1 och 114:1**, var och en med al-Afasy,
al-Husary och al-Minshawi. Samtliga filer hämtades från samma EveryAyah-mappar
som appen använder. Inget klipp hoppades över eller ersattes. Källfilerna
avkodades och kodades till **M4A/AAC, mono, 44,1 kHz, 64 kbit/s** utan
beskärning, sammanfogning eller införda fel. M4A-filernas containertider var
**3,417–19,618 sekunder**, samtliga under inspelningsgränsen på 60 sekunder.

Alla anrop använde respektive vald referens med `include_basmala=false`.
Källklippens fullständiga frasinnehåll och Basmala-/waqf-förhållande till
referensen har **inte sakkunnigkontrollerats**. Formatet liknar appens
inspelningar, men ljudet kommer från publicerade recitatörer, inte från
iPhone-mikrofon eller nya elever.

**Alla 18 anrop returnerade `assessed` med noll presenterade indikationer.**
Inga anrop fick `unavailable` eller `insufficient_audio`. Det senare
valideringskontraktet avvisar byteidentiska förväntade/observerade fonem och
kolliderande återkopplingsidentiteter; denna körnings svar innehöll inga
sådana poster. Noll indikationer är fortfarande inget intyg på korrekt
recitation och mäter inte vilka fel modellen skulle missa hos en elev.

[Hela resultatfilen](evidence/model-expanded-smoke-2026-10-25.json) bevarar
alla 18 API-svar, källadresser, separata SHA256-hashar för MP3 och M4A,
format-/längdmetadata, kodhashar och begränsningar. Ljudfiler och modellvikter
ligger utanför Git och iPhone-paketet. Backendfilerna matchade exakt
**f9c77d2889c01e7608d8b59d96235c1b0d5aaa64** vid körningen.

| Mått | Observerat i denna körning |
| --- | --- |
| Modell/revision | Muaalem v3.2, `01a1ef9fbe40d144ef845101e89ff924aed3fef5` |
| Miljö | Linux x86_64, Python 3.12.14, PyTorch 2.7.1+cpu, två CPU-trådar |
| Modelladdning från befintliga lokala filer | 1,976 s |
| Anropstid, min/median/max | 1,743 / 3,3945 / 11,609 s |
| Rapporterad topp-RSS för processen | 3 334,6 MiB |

Inferensen kördes med lokal modellcache och explicita offlineinställningar;
ingen modell hämtades och ingen publik tjänst startades. Anropstiderna gäller
API-anrop i samma process och omfattar inte källhämtning, transkodning eller
publikt nätverk. Disk-/sidcachen dokumenterades inte som kall. Måtten gäller
Linux-processen och säger inget om iPhones temperatur, batteri eller minne.

Körningen breddar funktionsprovet med sex ytterligare versreferenser men
tillför inga oberoende lärarbedömningar eller precision-/recall-mått.
Träningsöverlapp är okänt och sifat-huvudena bedöms fortfarande inte separat.
Det tidigare fallet med en indikation för **al-Afasy 112:2** finns kvar
oförändrat och har inte omklassificerats. Ingen jämförelse med Tarteel har
gjorts. Den automatiska tajweedhjälpen är fortsatt experimentell och avstängd
i standardbygget; kvalitetsmålet är ännu inte styrkt.
