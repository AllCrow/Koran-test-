# Utvärdering av REA/Muaalems indikationer

`backend.evaluation` är ett separat, lokalt granskningsverktyg. Det kör ingen
modell, kontaktar ingen tjänst och laddar inte upp inspelningar. Den vanliga
iPhone-appen och analysservern importerar inte verktyget. Automatisk analys är
fortsatt experimentell och avstängd i standardappen.

Verktyget gör en tidigare saknad del av kvalitetsarbetet körbar: det jämför
arkiverade modellindikationer med en uttrycklig, komplett sakkunniggranskning
och redovisar överflödiga indikationer, missade märkningar, avstående och
granskningstäckning. **Ingen sakkunnigmärkt utvärderingskorpus finns ännu.**
Den medföljande verkliga observationen är ogranskad och får inga kvalitetsmått.

## Kör nu utan modellvikter

Installera projektets lätta backend-provberoenden enligt
[backendguiden](../backend/README.md). Kör från projektroten:

```sh
python -m backend.evaluation \
  --corpus docs/evidence/evaluation-pending-112-2-corpus.json \
  --predictions docs/evidence/evaluation-pending-112-2-predictions.json
```

Resultatet har en `pending` observation, noll `adjudicated`,
`review_coverage: 0` och **`quality_metrics: null`**. Modellens indikation blir
varken en bekräftad rättning eller ett falsklarm genom att körningen lyckas.

`--output /egen/sökväg/resultat.json` sparar rapporten och vägrar skriva över
en befintlig fil. Utan flaggan skrivs JSON till terminalen. Felaktiga indata ger
exitkod 2 innan någon rapport skapas. Filerna måste vara UTF-8-JSON, högst
8 MiB; dubbla JSON-nycklar, okända fält och automatiska typkonverteringar
godtas inte.

## Förbered en sakkunniggranskning

1. Skapa en separat korpus med egna fall-ID:n; använd
   [det ogranskade korpusexemplet](evidence/evaluation-pending-112-2-corpus.json)
   som formatmall. Bevara råa ljudfiler privat **utanför Git** och skaffa
   nödvändigt samtycke/rättigheter. Använd pseudonyma granskar-ID:n.
2. Bind varje fall till SHA256 och antal byte för **exakt den fil som skickades
   till modellen**, före avkodning. En senare hämtning från samma URL räcker
   inte. Samma ljudhash får inte förekomma flera gånger och oavsiktligt vikta
   studien; kontroller med andra referenser får köras i en separat korpus.
3. Ange sura, vers, Basmala-val och SHA256 av exakt svarstext i
   `quran-transcript-0.6.4`. Verktyget hämtar den oberoende referensen från samma
   lokala hashkontrollerade utgåva som appens övningsläge. Det tar inte en
   godtycklig klienttext som sanning och normaliserar inte arabiska tecken.
4. Låt minst två kunniga Hafs-granskare lyssna **oberoende, innan de ser
   modellens indikationer**. Granska hela klippet, klippgränser, kontext och
   tillåtna lässätt. Bevara de ursprungliga bedömningarna separat och avgör
   oenighet. Verktyget intygar inte granskarnas behörighet eller arbetsmetod.
5. Sätt `review.status` till `adjudicated` först när hela fallet är avgjort,
   `blinded` och `complete` är `true` och minst två unika `reviewer_ids`
   finns. `errors: []` betyder då uttryckligen att granskningen inte hittade
   fel inom den deklarerade omfattningen. `pending` och `inconclusive` kräver
   `complete: false` och tom `errors`; de räknas aldrig som felfria fall.
6. Registrera endast granskade fel i `errors`, med `kind` (`normal`,
   `tashkeel`, `tajweed`), `category` (`insert`, `delete`, `replace`) samt
   `start_scalar` och `end_scalar`. Siffrorna är nollbaserade, halvöppna
   intervall i **Unicode scalars** i exakt övningsreferens. Arabiska
   kombinationstecken räknas separat; använd inte UTF-8-byte, UTF-16-enheter
   eller läsvyns andra koranutgåva. Bara `insert` får ha noll bredd.
7. Skapa prediktionsfilen enligt
   [det arkiverade svarsexemplet](evidence/evaluation-pending-112-2-predictions.json).
   Spara hela oförändrade API-svaret i `assessment`, filhash/antal byte och
   samma fall-ID. `engine_source_sha256` måste avse koden som faktiskt kördes,
   även när ett historiskt svar används. Modell, revision, motorversion,
   källutgåva, text, Basmala och scalar-offset valideras mot den nu fixerade
   konfigurationen; saknade metadata fylls inte i från schemats standardvärden.

Korpusen ska ha `purpose: "expert_review"`. Kontraktstester använder
`synthetic_fixture`; sådana rapporter får alltid `quality_metrics: null` även
när matchningsräkningen blir perfekt. Att ändra deklarationen bevisar inte
att en verklig sakkunnigstudie har genomförts.

För att även återkontrollera de ursprungliga ljudbyten, placera varje fil i en
privat mapp som `<case_id>.audio` och lägg till:

```sh
python -m backend.evaluation \
  --corpus /privat/korpus.json --predictions /privat/prediktioner.json \
  --audio-directory /privat/originalfiler --output /privat/resultat.json
```

Varje fil måste vara en vanlig fil, inte en symbolisk länk, och dess längd och
SHA256 måste matcha. Ingen ljudavkodning sker här: detta kontrollerar identitet,
inte hörbarhet eller klippkvalitet. Utan flaggan anges
`original_audio_verified_locally: false`; matchande deklarerade hashar är då
inte en ny kontroll av själva ljudfilen. Rapporten binder även korpus,
prediktioner och utvärderingskod till SHA256.

## Vad räknas och vad kan måtten säga?

Primär matchning kräver **samma kind, category och exakt scalar-intervall**.
En markering matchar högst ett lärarfel och ett lärarfel högst en markering.
En dubblerad modellmarkering kan därför ge en extra indikation men aldrig
två träffar på ett enda lärarfel. Dubblerade lärarmärkningar avvisas.

Rapporten innehåller också `overlap_diagnostic`: samma typ/kategori och
positiv överlappning mellan halvöppna intervall. Angränsande intervall
överlappar inte. Nollbreda infogningar matchar bara exakt samma punkt, inte
ett helt omgivande ord. En maximal en-till-en-tilldelning undviker att en
tidig bred markering felaktigt förbrukar det enda möjliga målet för en senare
markering. Den generösare diagnostiken ersätter **inte** primärresultatet.

Matchning bedömer **klassificering och lokalisering av indikationer**. Dagens
API har ingen strukturerad identitet för en viss tajweedregel. En träff på
samma intervall bevisar därför inte att modellen förklarade rätt regel,
angav rätt förväntade/observerade fonem eller gav bra pedagogisk återkoppling.
En framtida sakkunnigstudie behöver bedöma dessa delar separat.

Endast kompletta `adjudicated`-fall ingår i räkningen:

| Utdata | Betydelse |
| --- | --- |
| `matched` | En-till-en-träffar enligt den angivna matchningsregeln. |
| `false_indications` | Modellmarkeringar som saknar matchad lärarmärkning; omfattar också fel typ eller position, inte enbart bevisat felaktigt uttalsråd. |
| `missed_errors` | Lärarmärkningar utan träff, inklusive när modellen avstår eller dess svar saknas. |
| `by_kind` | Samma räkning separat för uttal, vokalisering och tajweed. |
| `precision` | Träffar / alla modellindikationer i granskade fall. |
| `recall_including_abstentions_and_missing` | Träffar / alla granskade lärarfel, även i avstådda eller saknade svar. |
| `recall_on_assessed_only` | Träffar / lärarfel i just de fall som modellen faktiskt bedömde. Måste läsas tillsammans med täckningen. |
| `assessment_coverage` | Antal `assessed` / alla avgjorda fall; avstående får inte höja resultatet genom att försvinna. |
| `error_free_clip_false_correction_rate_on_assessed` | Andel av sakkunnigt felfria och faktiskt bedömda klipp som ändå fick indikationer. |
| `review_coverage` | Andel av hela korpusen som är avgjord; ogranskade klipp ligger utanför kvalitetsnämnarna. |

`unavailable`, `insufficient_audio` och saknade prediktioner redovisas separat.
Ett avstående får inte innehålla indikationer. En nollnämnare ger `null`, inte
0 eller 100 procent. Rapportens `cases` visar exakta parade och omatchade
index så att varje total kan granskas.

Detta ger inga populationsmått, full sifat-bedömning eller Tarteel-paritet.
Sådana anspråk kräver ett representativt, förutbestämt och talarseparerat
elevmaterial med riktiga fel, tillåtna varianter och svåra inspelningsvillkor,
osäkerhetsintervall och en jämförbar blind bedömning av båda produkterna.
Enbart publicerade imamer med okänt träningsöverlapp räcker inte. Använd inte
samma märkta material både för att justera regler och som slutligt test.

## Den bevarade 112:2-observationen

Korpus- och prediktionsfilerna kopierar exakt det arkiverade al-Afasy-fallet
ur [baslinjerapportens](evidence/model-baseline-2026-10-24.json) klippindex 8.
Den sparade indikationens `normal`/`delete` är **inte** en sakkunnigt
bekräftad tajweedavvikelse.

Den ursprungliga konverterade M4A-filen återfanns lokalt och kontrollerades:
**21 619 byte**, SHA256
`35b7b49e10fb3c295c7ec076403e241714c8cc75a72c2d909f145a62b47a2f6d`.
Den matchar det ursprungliga anropet, inte bara en senare fil från samma URL.
En kopia utanför Git användes med `--audio-directory` för den
[sparade körbara rapporten](evidence/evaluation-pending-112-2-report.json).
Rapporten anger återkontrollerad filidentitet men fortsatt `pending`, noll
granskningstäckning och `quality_metrics: null`. Inget nytt modellanrop,
ingen uppladdning eller expertklassificering gjordes och inget ljud lades i Git.

De 21 automatiska verktygsproven ligger i
`backend/tests/test_evaluation.py`. De använder uttryckligt syntetiska
kontrakt och provar bland annat fel nämnare, avstående, en-till-en-matchning,
intervallgränser, manipulerad text, fel ljudhash, metadata som saknas,
Unicode- och storleksgränser samt den verkliga men fortsatt ogranskade
arkivobservationens fortsatt uteblivna kvalitetsmått.

```sh
python -W error::ResourceWarning -m unittest backend.tests.test_evaluation -v
```
