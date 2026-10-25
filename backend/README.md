# Experimentell recitationsanalys

Det här är en separat, valfri server för iPhone-appens övningsläge. Läsning,
recitation och lokala inspelningar kräver inte servern. Servern använder riktiga
akustiska utdata från **Muaalem**, följda av `quran-transcript.explain_error`.
Den använder inga påhittade betyg eller rättningar när modellen saknas.

Kvaliteten är experimentell och har inte jämförts med Tarteel eller bedömts av
tajweedlärare. Aktuell implementation jämför modellens fonetiska utdata; dess
separata sifat-huvuden ger ännu ingen återkoppling. Den bedömer därför inte alla
uttalsegenskaper. Rättningar från modellen behöver mänsklig granskning.

## Installation på en egen dator/server

Python 3.12 och ffmpeg behövs. Kör från projektets rot:

```sh
python3 -m venv backend/.venv
backend/.venv/bin/pip install torch==2.7.1 --index-url https://download.pytorch.org/whl/cpu
backend/.venv/bin/pip install -r backend/requirements-inference.txt
backend/.venv/bin/python -m backend.download_model
SAKINA_ENABLE_MODEL=1 backend/.venv/bin/python -m backend.main
```

Modellnedladdningen är ett uttryckligt engångssteg på flera GB. Modellvikter
läggs i Hugging Faces cache och ska inte checkas in i Git. Startkommandot lyssnar
på `127.0.0.1:8000`. Modellen laddas en gång vid start från lokal cache.
`GET /health` visar verklig beredskap; en server som svarar kan fortfarande ha
`ready: false`.

Använd `SAKINA_API_KEY` för autentisering och skicka nyckeln i `X-API-Key`.
Nyckeln hör hemma på servern och i användarens konfiguration, inte i källkoden.
För åtkomst från iPhone behövs en serveradress som telefonen når samt HTTPS.
En reverse proxy framför servern kan tillhandahålla TLS. Det behövs ingen
obligatorisk tjänsteprenumeration, men egen serverdrift och beräkning kostar.

Miljövariabler:

| Variabel | Standard | Betydelse |
| --- | --- | --- |
| `SAKINA_ENABLE_MODEL` | `0` | `1` laddar den experimentella modellen vid start. |
| `SAKINA_ALLOW_MODEL_DOWNLOAD` | `0` | `1` tillåter explicit nätåtkomst under modelladdning vid start. |
| `HF_HOME` / `HF_HUB_CACHE` | Hugging Faces standard | Plats för modellcache. |
| `SAKINA_API_KEY` | saknas | Om angiven krävs `X-API-Key` före läsning av uppladdningen. |
| `SAKINA_MODEL_DEVICE` | `cpu` | PyTorch-enhet. CPU är standard och använder float32. |
| `SAKINA_QURAN_RESOURCES` | Bundlad `PracticeReferences` | Separat verifierad referensutgåva för modellen. |
| `SAKINA_FFMPEG` | `ffmpeg` | Körbar ljudavkodare. |

## Docker

Dockerfilen använder projektroten som build context:

```sh
docker build -f backend/Dockerfile -t sakina-analysis .
docker volume create sakina-models
docker run --rm -v sakina-models:/var/lib/sakina/huggingface sakina-analysis python -m backend.download_model
docker run --rm -p 127.0.0.1:8000:8000 -v sakina-models:/var/lib/sakina/huggingface sakina-analysis
```

I en hanterad molnmiljö med sessionsproxy måste bygget få den kombinerade
CA-bunten via BuildKit-secreten `proxy_ca`, exempelvis
`--secret id=proxy_ca,src=/etc/ssl/certs/ca-certificates.crt`. Behåll miljöns
proxyinställningar och TLS-verifiering. Vid modellnedladdning i en sådan
container behövs motsvarande skrivskyddade CA-mount och `REQUESTS_CA_BUNDLE`.
CA-filer ska inte kopieras till image-lager. Dockerfilen är tillhandahållen för
distribution; se projektets statusrapport för vilka körningar som verifierats.

## API-kontrakt

`POST /v1/assess` tar multipart:

- `audio`: M4A/AAC eller PCM WAV. Native-appens M4A stöds via ffmpeg.
- `surah_id`, `ayah_number`: heltal i den bundlade Koranreferensen.
- `include_basmala`: boolesk, standard `false`.

Servern hämtar texten från sin egen källkontrollerade referens. Klienttext
används aldrig som referens. Gränser: högst 8 MiB fil, högst 60 sekunder,
minst 0,35 sekunder med hörbart ljud. För kort/tyst ljud ger
`insufficient_audio`, ingen rättning. Ogiltig media ger HTTP 415, felaktig vers
422, för stor uppladdning 413, upptagen analys 429 och fel API-nyckel 401.

Ett HTTP 200-svar har stabilt `schema_version: 1` och status `assessed`,
`unavailable` eller `insufficient_audio`. Alla svar anger `experimental: true`,
modellrevision, källutgåva, exakt `reference_text` och `issues`.
`unavailable` och `insufficient_audio` har alltid tom `issues`.

En markering innehåller `kind` (`tajweed`, `normal`, `tashkeel`), `category`
(`insert`, `delete`, `replace`), `start_scalar`, `end_scalar`, `expected`,
`observed` och `message`. Förväntat/observerat är **fonetisk skrift**, inte
säkra citat av vad användaren sade. Positionerna kommer från den riktiga
modelljämförelsens mappning. Inga ljudtidsstämplar eller övergripande betyg ges.

`start_scalar` och `end_scalar` är en halvöppen intervallposition i Unicode
scalars i **svarstexten** `reference_text`. Nollbredd för en möjlig infogning är
tillåten. `reference_scalar_offset` anger eventuell borttagen inledande BOM i
övningsreferensen. För en inledande vers i sura 2–114 utom 9 kan
`include_basmala=true` lägga till den separat källbelagda Basmala-texten.
Texten för sura 95/97 bevarar källans särskilda skrivning.

Övningsreferensen är `quran-transcript-0.6.4` och skiljer sig från läsvyns
Uthmani-utgåva. iOS validerar vers-ID, källutgåva och exakt text mot samma lokalt
bundlade dataset. Markeringar får **aldrig flyttas till läsvyn med dessa offsets**.
Ingen godtycklig borttagning av arabiska tecken görs för att passa modellens
vokabulär. En inkompatibel referens ger `unavailable`.

Antaganden: Hafs an Asim, madd munfasil 4, muttasil 4, muttasil vid waqf 4 och
madd arid med referenslängd 4 harakat. Vid jämförelsen godtas nu 2, 4 eller 6
för **samma långa vokal**, men bara när biblioteket anger exakt en typad
`AaredMaddRule` och alla vokal-/längduppgifter stämmer. Undantaget döljer inte
andra regler, vokalbyten, blandade avvikelser eller vanliga/tashkeel-fel. Andra
korrekta lässätt och pauser efter Basmala kan fortfarande påverka resultatet;
full täckning av giltiga Hafs-varianter är inte verifierad.

Ljudfilen behandlas tillfälligt och raderas efter avkodning. Inga uppladdningar,
filnamn eller ljudinnehåll skrivs till logg av serverkoden. En analys körs åt
gången i en arbetstråd; eventloopen kan fortsätta svara på hälsokontroller.
Upprepad avbrytning av samma HTTP-anrop släpper inte analysplatsen medan
arbetstråden fortfarande kör. Avkodaren väljer uttryckligen WAV, ISO BMFF M4A
eller ADTS AAC; spellistor, externa MOV-referenser och trunkerad native PCM
godtas inte som en vanlig tagning.

## Verifiering

```sh
backend/.venv/bin/pip install -r backend/requirements-test.txt
backend/.venv/bin/python -W error::ResourceWarning -m unittest discover -s backend/tests -v
```

HTTP-kontrakttester använder en uttrycklig fake-motor och verifierar endast
validering, resursgränser, avkodning och transport. De är ingen mätning av
modellens kvalitet. Testet för M4A kör verklig ffmpeg-avkodning.
**28 backendtester har passerat** i utvecklingsmiljön, inklusive de avgränsade
madd arid-fallen, upprepad avbrytning och riktig avkodning av M4A/AAC/WAV.
Dessutom har riktig CPU-inferens körts genom HTTP-API:t i
samma process på fem insignalstester. Al-Afasy, al-Husary och al-Minshawi 1:1
gav inga presenterade indikationer; 112:1 mot referens 1:1 gav 15 och tystnad
gav `insufficient_audio`. Se [det faktiska provet](../docs/MODEL_SMOKE_RESULTS.md)
och [rårapporten](../docs/evidence/model-smoke-2026-10-24.json).

Ett separat [utökat prov med 35 indata](../docs/evidence/model-baseline-2026-10-24.json)
har också körts: 33 referensklipp, alla verser i al-Fatiha och al-Ikhlas med tre
recitatörer, samt annan-vers- och tystnadskontroller. 32 referensklipp gav noll
indikationer; en `normal`/`delete` för initialt `ءَ` i al-Afasys 112:2 behöver
sakkunnig källklippsgranskning. Den är inte klassificerad som ett modellfel
eller ett verkligt uttalsfel; ingen noggrannhetsprocent beräknas. Samtliga
referensklipp fick `assessed`, annan-vers-kontrollen gav 15 indikationer och
tystnad gav `insufficient_audio`.

I den körningen var modelladdningen 1,911 sekunder och processens topp-RSS
3 240,5 MiB. Referensanropens tidsintervall var 1,343–8,475 sekunder, median
2,351 sekunder. Det är lokala in-process CPU-mått, inte iPhone- eller publika
nätverksmått. Se [sammanställningen](../docs/MODEL_SMOKE_RESULTS.md).

Körningen använde lokala modellfiler och två CPU-trådar på Linux. Uppmätt
modelladdning var 2,041 sekunder och processens topp-RSS 2 749,1 MiB. De tre
1:1-anropen tog 2,283–3,282 sekunder i just denna in-process-körning. Dessa
mått är ingen nätverks-, iPhone-, kallcache- eller energimätning. En enda vers,
publicerade recitatörer och okänt träningsöverlapp räcker inte för en
noggrannhetsstudie eller ett Tarteel-anspråk.

Dockerbilden `sakina-analysis:dev` byggdes den 24 oktober och startades som UID 10001
med nätverk avstängt, utan publicerade värdportar eller modellcache. `/health`
rapporterade säkert att modellen inte var redo; containern stoppades rent.
Den då patchade bilden byggdes om och samma isolerade, icke-root
hälsokontroll kördes igen. Dess lokala image-ID är
`sha256:7e1d0e70b0fed94cbc66598c7da2a8f9c3e6c1300ce029bfca130ac1527b2bba`.
Modellvikter är inte inbakade. Det verifierar bygg-/startvägen och läget utan
modell, inte modellinferens i containern eller en publik driftsättning. Dockerbilden sätter
`SAKINA_ENABLE_MODEL=1`; utan i förväg hämtade modellfiler blir tjänsten ändå
`unavailable`, eftersom nätbaserad modellhämtning vid start är avstängd.

Den 25 oktober provades aktuell backendkod och referenser via read-only-mount
i denna runtime, med UID 1000, avstängt nätverk och utan värdportar. En verklig
HTTP-hälsokontroll på containerns loopback rapporterade `ready=false`,
`model_loaded=false` och rätt referensutgåva; servern stängdes rent. Detta
verifierar dagens källstart, **inte en ny imagebyggning** eller containerinferens.

REA har också [inspekterat den faktiska viktfilen](../docs/REA_MODEL_INSPECTION.md)
och verifierat tensorinventering och full SHA256. Den kontrollen är separat
från både modellkörningen och de kontraktstester som använder en ersättningsmotor.

## Versioner och licenser

- `quran-muaalem` **0.2.2**, exakt MIT-licensierad PyPI-wheel med SHA-256 i
  `requirements-inference.txt`. Git main har andra licensvillkor trots samma
  versionsnummer och används inte.
- `quran-transcript` **0.6.4**, exakt wheel med SHA-256. Licenstexten inkluderar
  MIT för mjukvaran och Tanzils villkor för korantexten.
- Modell `obadx/muaalem-model-v3_2`, revision
  `01a1ef9fbe40d144ef845101e89ff924aed3fef5`. Kontrollera modellkortets och
  datasetens villkor för avsedd distribution.

Oförändrade paketlicenser finns i `backend/licenses`. Bundlad referenstext har
egen proveniens och checksummeindex i `Sources/QuranPractice/Resources/PracticeReferences`.
