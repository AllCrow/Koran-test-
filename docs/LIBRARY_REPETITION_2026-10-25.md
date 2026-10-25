# Ljudbibliotek, repetition och personlig övning

Omgången genomför de sex förbättringar användaren godkände efter bygge53.
**Implementationen granskas och native-verifiering återstår.** Det tidigare
godkända paketet och dess underlag bevaras. Faktiska utfall förs in här när
kandidaten har verifierats; förväntade funktioner är inte godkända provresultat.

## Användarbeteende

- Ljudbiblioteket samlar sparade suror och recitatörer. Tillgängliga verser
  skiljs från filer som tar plats men behöver hämtas igen. Varje val kan
  öppnas och raderas separat efter bekräftelse. Uppspelning öppnar rätt sura
  och vers med spelkontroller. Det uttryckliga sparade valet binds till den
  lokala filen även vid nytt försök och får inte byta till strömning om filen
  har försvunnit.
- Repetition väljs uttryckligen för ett intervall i en sura, 1–20 omgångar
  och 0–15 sekunders paus mellan verserna. Den vanliga inställningen för
  automatisk nästa vers ändras inte. Ett färdigt pass stannar; explicit
  uppspelning kan börja om från intervallets början.
- Mobildata för ljud är ett separat sparat val. Äldre installationer behåller
  tidigare nätbeteende. När valet ändras avbryts pågående nedladdning och
  berörd strömning, medan lokalt ljud fortsätter fungera. Valet gäller ljud,
  inte ny tafsir eller en separat aktiverad experimentell analystjänst.
- Övningskön är ordnad, unik och begränsad till 200 verser. Den ger ingen
  läskredit. Inspelningar raderas inte genom dold navigation eller ett
  oavsiktligt köval. Ny läskopia innehåller kön; gamla kopior fungerar också.
- Felsökningsrapporten skapas först på begäran. En förhandsvisning visar
  innehållet före export till Filer. Den innehåller versionsnummer,
  avgränsade statusflaggor och kontrollerad lagringsstatus. Röst, versval,
  läshistorik, råa felmeddelanden, sökvägar, adresser och konton ingår inte.

## Genomförande och gränser

Bibliotekets diskgenomgång sker utanför huvudaktorn. Resultat från avbrutna
eller inaktuella genomgångar får inte ersätta ett senare tillstånd. Det sker
ingen förladdning av ljud. En strukturell MP3-kontroll motsvarar fortfarande
inte en garanti att hela filen kan avkodas eller att dess innehåll är korrekt.

Repetition följer riktiga slutnotiser från den enda AVPlayer-instansen. Bara
pausen mellan verser använder en avbrytbar väntan. Fördröjda återanrop får inte
starta ljud efter paus, stopp, systemavbrott eller nytt val. Ingen kontinuerlig
pollning eller extra ljudmotor införs för funktionen.

Sparformatets v1 får valfria köfält. Import validerar både kapacitet och
sammanlagda byte före mutation; befintliga data ska vara orörda om den
föreslagna sammanfogningen inte ryms. Frysta äldre format används för
kompatibilitetsproven och återskapas inte med den nya kodens skrivare.

De nya gränssnittsproven använder isolerad Debug-lagring och genererat lokalt
testljud. De kan därför använda de verkliga knapparna utan externa ljudanrop
eller att röra ordinarie läsdata. Testhjälpen kompileras inte in i Release.

Fysisk iPhone-installation, radioväxling, låsskärm/ljudrutter, VoiceOver och
energiförbrukning behöver fortfarande provas på telefon. Automatisk
tajweedanalys är avstängd i normalbygget; inga nya lärarbedömningar eller
anspråk på Tarteel-kvalitet följer av denna omgång.

Förväntad ordinarie native-svit är 139 hostade och tolv UI-fall per
simulatorvariant, samt 89 separata portabla Mac-fall och 57 backendfall.
Det är förväntade antal, inte ett godkänt körresultat. Innehålls-, referens-,
font-, ikon- och projektkontrollerna har passerat lokalt. Backendens indata
är oförändrade jämfört med den tidigare godkända källan.

Efter återställningen passerade en samlad Swift6.0.3-förkontroll: syntax för
app- och testfiler med Debug aktiverat samt **87 portabla Swift-fall** i en
isolerad container med avstängt nät. Syntaxkontrollen ersätter inte Apples
SDK-typkontroll eller native-körning. Granskningen rättade raderingskontroll
av lagringsmappar, inaktuella lagringssummor, summeringsöverflöde och två
skillnader mellan spelknapparnas symboler/etiketter och deras faktiska avsikt.
Den utökade native-/UI-sviten har 40 minuters jobbtidsgräns i stället för 25;
testkrav, interaktioner och de tidigare tidsgränserna inne i proven behålls.

## Observerad rättning före godkännande

[PR-körning54](https://github.com/AllCrow/Koran-test-/actions/runs/40200192657)
på `63465b5c140160ef35647ada7095da8cd3f99a0e` underkändes i tjänsteproven.
Kö- och uppdateringsproven visade en verklig återläsningsbugg: en tillståndsfull
lazy-filterkedja kunde läsas flera gånger av Collection-adaptrar. Redan sedda
poster förbrukades före kopieringen, vilket gav en tom kö eller inkonsekventa
index och en Range-krasch. Rättningen använder ett enda uttryckligt varv med
oförändrad ordning, avduplicering och gräns på 200 poster. Ett separat litet
Swift-prov reproducerade den tomma gamla utmatningen och den korrekta nya.
De befintliga nya kö- och uppdateringsproven behålls; inga felkrav tas bort.

Det nya UI-provets gest mot en läsbadge har också anpassats till dess
dokumenterade tillgänglighetsbeteende. Badgen kan sakna AX-aktiveringspunkt på
iOS26. En sammanhängande native-ögonblicksbild måste visa exakt en badge med
rätt ID och text, hela ändliga ramen inom läsytan och appen i förgrunden inom
samma fem sekunder. Därefter görs ett verkligt långt tryck vid dess mitt.
Menyns interaktiva knapp måste fortfarande vara nåbar och tryckas på riktigt.
De åtta tidigare UI-proven är oförändrade. Inga UI-fall kördes i54 eftersom
tjänstegrinden stoppade dem; rättningen kräver en ny fullständig körning.

[PR-körning55](https://github.com/AllCrow/Koran-test-/actions/runs/40201628843)
på `42ed270ad805f01dd684dfa97bea4560abca08e6` bekräftade rättningen av kön.
iOS26 passerade samtliga 138 hostade fall och tio av tolv UI-fall, inklusive
alla åtta tidigare UI-fall. Två nya UI-avläsningar underkändes: svenskt
lagringsvärde innehöll ett hårt blanksteg i `2 502 byte`, och versväljaren
visade korrekt start- och slutvers3 men saknade ett tillförlitligt explicit
AX-värde. Bytejämförelsen normaliserar nu endast numeriska gruppblanksteg;
vers- och pausväljarna anger sina faktiska val som tillgänglighetsvärden.
Exakta värden, riktiga menytryck och kontrollen av ogiltiga intervall behålls.

De två andra simulatorerna stoppades av var sitt tjänsteprov. Det nya
sekventiella inventeringsprovet väntade på en onödig tidsstyrd testgrind.
Det väntar nu direkt på två riktiga genomgångar och kontrollerar både bevarade
rader och byte samt okontrollerat felstatus. Det äldre pausprovet läste en
övergående native-status efter första pausnotisen. Observationen installeras
nu före kommandot och kräver ett sammanhängande 100ms lugnt tillstånd inom
samma tidigare tvåsekundersgräns, med avgränsad feltidslinje. Produktionspaus,
samma ljudkälla, uteblivet filslut och uttrycklig återstart behålls.
Körning55 är underkänd som helhet och dess loggar och felbilder bevaras.

Granskningen upptäckte dessutom att bibliotekets tidigare spelknapp inte
öppnade motsvarande text. Den nya vägen laddar och verifierar rätt lokala
kapitel före uppspelning, avbryter inaktuell navigation och visar läsaren
med vanliga spelkontroller. En sessionsidentitet hindrar att stängning av
vyn stoppar ett nyare uttryckligt ljudval. En avbruten öppning visar ett
uttryckligt återförsök även när en kvarhållen vy återkommer efter flikbyte.
Ett ytterligare native-prov kontrollerar faktisk
MP3-uppspelning från en bunden lokal fil och utebliven nätfallback vid förlust.
Det befintliga UI-biblioteksfallet utökas med ljud/textkopplingen för112/Husary;
antalet UI-fall är fortfarande tolv. Allt detta kräver nästa fullständiga körning.

Molnmiljön fick tillfälligt slut på disk under förkontrollen. Återskapbar
paketcache och en oanvänd härledd backend-containerbild rensades; källkod,
modellfiler, Git-historik, tidigare iPhone-paket och verifieringsunderlag
bevarades. En avbruten skrivning till ett nytt test återställdes före fortsatt
kontroll. Detta var ett miljöfel, inte ett godkänt eller underkänt native-prov.
