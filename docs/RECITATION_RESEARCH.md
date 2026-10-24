# Underlag för automatisk recitationshjälp

Kontrollerat **2026-10-24** mot publika originalkällor. Detta är ett tekniskt beslutsunderlag för Sakina. Modellvikter har inte laddats ned, ingen neural inferens har körts och ingen jämförelse med Tarteels betalversion har genomförts. Att paket-API:er och modellfiler finns är inte ett bevis på tillräcklig återkopplingskvalitet.

## Rekommendation

Börja med en separat, valbar serverprototyp baserad på **Quran Muaalem v3.2**, med uttrycklig vald vers och tydligt angivna Hafs-inställningar. Den är den starkaste verifierade kandidaten här för ljudbaserade tajweedegenskaper. Använd den publicerade, fixerade Python-releasen och modellrevisionen nedan, och låt appen fortsätta fungera utan servern. Publicera inga uttalsbetyg som låtsas vara lärarverifierade.

Utred lokal iPhone-körning som ett eget senare spår. Det finns en riktig INT8-ONNX-export och en mindre modell med rapporterad Core ML-körning, men ingen av dem ger ett verifierat paket med låg värme, full tajweedbedömning och visad kvalitet på våra iPhone-enheter. Nuvarande Rust-repots löfte om Swift-SDK motsvaras ännu inte av en fungerande inferensmotor.

## Faktiska kandidater

| Kandidat | Faktisk utdata och storlek | Bedömning för Sakina |
| --- | --- | --- |
| [obadx/muaalem-model-v3_2](https://huggingface.co/obadx/muaalem-model-v3_2) + [quran-muaalem](https://github.com/obadx/quran-muaalem) | Wav2Vec2-BERT med 11 CTC-nivåer: fonem och tio sifat-egenskaper. HF redovisar **605 754 251 parametrar**; den publicerade FP32-filen är **2 423 124 012 byte**. | Förstahandskandidat för en experimentell server. Verklig fonetisk utdata finns, men generell och lärarverifierad felbedömning återstår. |
| [Abddar/muaalem-v3-2-int8-android-onnx](https://huggingface.co/Abddar/muaalem-v3-2-int8-android-onnx) | En självständig INT8-ONNX-fil på **876 466 434 byte**. Modellkortet anger samma fixerade v3.2-källa och SHA256. | Möjlig utgångspunkt för en ONNX-utredning. Android-artefaktens existens bevisar inte iOS-kompatibilitet, bibehållen kvalitet eller låg värme. Förbehandling, vokabulär, avkodning och felmappning följer inte automatiskt med modellen. |
| [sysofwan/hifzguide-muaalem-mini](https://huggingface.co/sysofwan/hifzguide-muaalem-mini) | Distillerad Wav2Vec2-BERT, **116 318 635 parametrar**, endast fonemhuvudet med 43 klasser. Kortet uppger numeriskt verifierad Core ML-export och en lyckad enkelchunk-körning på Apple Neural Engine. | Intressant för läspositions-/fonemspåret på iPhone. **Saknar de tio sifat-huvudena** och är inte ett belägg för tajweedegenskaper. AGPL-3.0 för vikterna och CC BY-NC 4.0 för angiven träningskorpus kräver ett separat produktbeslut. |
| [TBOGamer22/wav2vec2-quran-phonetics](https://huggingface.co/TBOGamer22/wav2vec2-quran-phonetics) | Wav2Vec2-base, **94 402 472 parametrar**, fonetiska strängar, tränad på enskilda ord. Kortet rapporterar 99,8 % utvärderingsnoggrannhet på en 10 %-uppdelning. | Möjlig mindre fonem-/aligneringsmodell. Kortet säger uttryckligen att den inte är avsedd för fullständig tajweedbedömning av ayat. Orddata och en konsekvent recitationsstil gör siffran olämplig som mått på felupptäckt hos nya elever. |
| [tarteel-ai/whisper-base-ar-quran](https://huggingface.co/tarteel-ai/whisper-base-ar-quran) | Whisper-base finjusterad för koranrecitation, arabisk textutdata, modellkortets WER **5,7544 %**. Apache-2.0 anges. | Användbar kandidat för textigenkänning/läsposition, inte bevis för fonetisk tajweedbedömning. Det publika forskningsmodellen är inte automatiskt samma motor eller kvalitet som dagens betalda app. |

Övriga sökresultat valdes bort: `obadx/muaalem-model-v3-mini` hade vid kontrollen ingen publicerad viktfil eller konfigurationsfil; `testemailmailx/quran-phonetics-onnx` hade modellfiler men inget modellkort eller verifierad licensproveniens. De ska inte väljas enbart på sina namn.

## Varför Muaalem skiljer sig från vanlig ASR

Den verifierade konfigurationen anger arkitekturen `Wav2Vec2BertForMultilevelCTC`, 24 encoderlager, 16 attention-huvuden, hidden size 1024 och en stride-2-adapter. Fonemnivån har 43 klasser. De övriga tio nivåerna är:

- `ghonna`, `qalqla` och `tafkheem_or_taqeeq`.
- `hams_or_jahr`, `shidda_or_rakhawa` och `itbaq`.
- `safeer`, `tikraar`, `tafashie` och `istitala`.

`quran-transcript` producerar en förväntad fonetisk representation och kopplingar tillbaka till den arabiska referenstexten. `Muaalem` ger en predikterad fonemsekvens och egenskaper per fonemgrupp. Det finns alltså en faktisk ljudbaserad väg till exempelvis ghunnah och qalqalah, inte bara en jämförelse mellan två arabiska textsträngar.

Det betyder inte att alla egenskaper kan rättas tillförlitligt. Författarna påpekar att träning på korrekta experter ger begränsat stöd för vissa fel: egenskaper som istitala och tikrar är starkt kopplade till särskilda bokstäver och kan därför läras som bokstavsidentitet i stället för en verklig akustisk avvikelse. Ishmam omfattas inte av den angivna fullständiga Hafs-täckningen.

## Publicerad utvärdering och dess begränsningar

Originalartikel: [Automatic Pronunciation Error Detection and Correction of the Holy Quran's Learners Using Deep Learning, arXiv:2509.00094v2](https://arxiv.org/html/2509.00094v2). Artikeln beskriver cirka **848 timmar**, **286 537 segment** och **22 expertrecitatörer** i träningskorpusen. Detta är författarnas uppgifter, inte våra egna reproducerade mätningar.

[qdat_bench](https://huggingface.co/datasets/obadx/qdat_bench) innehåller **159 elevklipp från en enda vers, 5:109**, med 120 kvinnliga och 39 manliga inspelningar enligt artikeln. Datasetet heter `train` i HF men används här som ett utvärderingsmaterial; det namnet ska inte tolkas som att samma klipp bör användas för både träning och godkännande av produkten.

De [publicerade råresultaten för v3.2](https://github.com/obadx/qdat_bench/blob/e8aa630fc988a4eade0225fb965d05f955ecdf86/assets/results/result_muaalem-model-v3_2_predictions.json) anger:

| Mått | Författarnas resultat | Praktisk betydelse |
| --- | --- | --- |
| Fonemnivåns PER | 5,7786 % | Skilt från genomsnittet över alla nivåer. |
| Genomsnittlig PER över nivåerna | 1,9362 % | Ska inte beskrivas som att endast 1,94 % av elevernas uttalsfel missas. |
| Genomsnittlig tajweed-F1 | 75,8207 % | Ett användbart forskningsresultat; inte nära ett bevis för alla regler i hela Koranen. |
| Noon moshaddadah, makro-F1 | 86,9059 % | Avgränsad ghunnahbedömning i det aktuella materialet. |
| Noon mokhfah/ikhfaa, makro-F1 | **45,2560 %** | En tydlig svaghet. Klassen `PARTIAL` har **0 i recall** i publicerat resultat. |
| Qalqalah, makro-F1 | 95,3000 % | Lovande men bygger på begränsat ljud och samma verskontext. |
| Medel-RMSE för madd | 0,5965 | Inte ett procentmått på korrekt uttal. Kräver rätt vald längd-/recitationskonfiguration. |

Artikelns cirka 0,21 % genomsnittliga PER på korrekta expertinspelningar gäller en annan utvärdering än elevfelen. Varken den siffran, HF-modellkortens noggrannhet eller imitation av en större modell uppfyller i sig kravet om Tarteels betalversion.

HifzGuide-minimodellens rapporterade 94,97 % testnoggrannhet är **överensstämmelse med lärarmodellens avkodning**, inte med oberoende korrekta transkriptioner eller kunniga lärares felbedömningar. Kortet är uttryckligt med detta och med att sifat-huvudena saknas.

## Reproducerbara artefakter och licenser

| Artefakt | Fixerad identitet | Kontrollerad licensinformation |
| --- | --- | --- |
| `quran-muaalem==0.2.2` från PyPI | Hjulets SHA256 `c5b5de2fbba2fe2b7a0ff3f155a669d75012609637f241df46f652d0089c10e9`, 52 554 byte. [PyPI-metadata](https://pypi.org/pypi/quran-muaalem/0.2.2/json). | Hjulets **faktiska medföljande LICENSE har lästs och är MIT**. Detta är releasen som rekommenderas för den första serverprototypen. |
| `quran-transcript==0.6.4` från PyPI | Hjulets SHA256 `8db46fa8217514d44b81abfe548b92f7eb6d23988195ad2c193c7d69c13c50a9`, 6 518 419 byte. [PyPI-metadata](https://pypi.org/pypi/quran-transcript/0.6.4/json). | Faktiska LICENSE har lästs: **MIT för programvara samt Tanzils CC BY 3.0-notis med villkor om källtrogen text**. Bevara båda. |
| Muaalem-vikter och processor | `obadx/muaalem-model-v3_2`, revision `01a1ef9fbe40d144ef845101e89ff924aed3fef5`. Viktfilens LFS-SHA256 `6b6a2e85303d17ff0f3af5e1fc79ac83daecee409c756ddf27f0ced59393bb41`. | Fixerat HF-modellkort anger MIT. Filmetadata har lästs; själva viktfilen har inte hämtats. |
| Basmodell | `facebook/w2v-bert-2.0`, revision `da985ba0987f70aaeb84a80f2851cfac8c697a7b`. | HF-modellkort anger MIT. |
| Aktuellt Python-gitrepo | `obadx/quran-muaalem`, granskad commit `2829e1aad719218d2e9b0e2720ff29eb8b84a67a`. | **QML 1.0**, en anpassad licens med ytterligare villkor. Den är inte samma licensartefakt som PyPI-hjulet ovan, trots samma versionssträng i källan. |

Den aktuella [QML-licensen](https://github.com/obadx/quran-muaalem/blob/2829e1aad719218d2e9b0e2720ff29eb8b84a67a/LICENSE) kräver bland annat AI-information före första användningen och senare åtkomlig information på gränssnittets språk och arabiska, förbjuder annonser och kräver en fri tillgångsväg för personer som inte kan betala. Den innehåller även ett Sharia-villkor. Om en senare Git-revision eller senare release används måste dess verkliga villkor granskas på nytt. Klassificera inte en ny artefakt som MIT genom att läsa ett äldre modellkort eller ett annat projekts README.

Det publika [iTarek/Quran-Muaalem-iOS](https://github.com/iTarek/Quran-Muaalem-iOS) visar att ett server-/SwiftUI-upplägg har byggts av andra, men dess README säger att originalprojektet är MIT utan att spegla dagens Git-licens. GitHub-API:t redovisade ingen licens för det repot vid denna kontroll. Det används som arkitekturreferens, inte som kod som Sakina har kopierat eller som bevis på produktionsmognad. Dess pris- och latensuppgifter har inte reproducerats.

## Konkret Python-väg för serverprototypen

Följande gränssnitt är kontrollerade i källan och delvis körda enligt nästa avsnitt. **Modellanropet är ännu inte kört.** Välj Python 3.11 eller 3.12 och lås hela beroendegrafen i serverprojektet, inte bara två toppaket.

PyPI-releasen kräver Python >=3.10 samt bland annat `torch>=2.7.0`, `transformers>=4.55.0`, `numpy>=2.2.6`, `quran-transcript>=0.6.1`, `rich>=14.1.0` och `diff-match-patch>=20241021`. För en tjänst behövs dessutom ett HTTP-ramverk och en fungerande ljudavkodare. CPU och GPU ska få olika testade Torch-installationer; välj inte CUDA-hjul till en CPU-miljö av misstag.

```python
from huggingface_hub import snapshot_download
from quran_transcript import Aya, MoshafAttributes, quran_phonetizer, explain_error
from quran_muaalem import Muaalem
import torch

model_directory = snapshot_download(
    repo_id="obadx/muaalem-model-v3_2",
    revision="01a1ef9fbe40d144ef845101e89ff924aed3fef5",
)
# Constructor saknar revision-argument; använd därför den fixerade lokala mappen.
model = Muaalem(model_name_or_path=model_directory, device="cpu", dtype=torch.float32)
model.model.eval()

moshaf = MoshafAttributes(
    rewaya="hafs",
    madd_monfasel_len=4,
    madd_mottasel_len=4,
    madd_mottasel_waqf=4,
    madd_aared_len=4,
)
reference_text = Aya(1, 2).get().uthmani  # 1-baserad sura, ayah
reference = quran_phonetizer(reference_text, moshaf, remove_spaces=True)

# waveform: verkligt avkodat mono-ljud, 16 000 Hz, float32.
# Det andra argumentet är [reference]-objekt, INTE [reference.phonemes].
output = model([waveform], [reference], sampling_rate=16000)[0]
errors = explain_error(
    uthmani_text=reference_text,
    ref_ph_text=reference.phonemes,
    predicted_ph_text=output.phonemes.text,
    mappings=reference.mappings,
)
```

`output.phonemes` innehåller `text`, `probs` och `ids`. `output.sifat` innehåller dataklasser med `phonemes_group` och valfria `SingleUnit(text, prob, idx)` för egenskaperna. Tensorer måste uttryckligen göras till JSON-värden. Råa softmaxvärden är inte kalibrerad sannolikhet för att en rättning är sann och ska inte visas som elevens noggrannhet.

`explain_error` ger dataklassen `ReciterError` med:

- `uthmani_pos` och `ph_pos`: Python-intervall med exklusivt slut.
- `error_type`: `tajweed`, `normal` eller `tashkeel`.
- `speech_error_type`: `insert`, `delete` eller `replace`.
- `expected_ph` och det faktiskt felstavade API-fältet `preditected_ph`.
- Valfria `expected_len`, `predicted_len` och listor med `ref_tajweed_rules`, `inserted_tajweed_rules`, `replaced_tajweed_rules`, `missing_tajweed_rules`.

Regelobjekten anger bland annat lokaliserat namn, `golden_len`, `correctness_type` (`match`/`count`) och `tag`. Mappning av dessa fonemfel täcker inte automatiskt alla modellerade sifat-fel; en separat jämförelse/kalibrering krävs innan sådana rättningar kan presenteras.

Den aktuella upstream-API:n har `/predict`, `/transcript`, `/search` och `/correct-recitation`. `/correct-recitation` söker först efter en passande koranposition. För Sakinas **redan valda vers** bör tjänsten använda den givna versreferensen direkt och avstå om ljudet inte passar, så att den inte tyst rättar mot en annan liknande vers. Upstreams angivna standardsgräns är 15 sekunders ljud; en egen tjänst måste ange och testa sina gränser. Sakinas längre lokala inspelningsfunktion är inte automatiskt kompatibel med den gränsen.

Hafs-valen måste visas tydligt och senare göras inställbara med sakkunnigt stöd. En giltig alternativ madd-längd får inte felmärkas bara för att en osynlig serverstandard valde fyra. `rewaya="hafs"` är inte stöd för alla qira’at.

## Utförda lätta kontroller och viktig textkompatibilitet

`quran-transcript==0.6.4` har installerats i en separat temporär Pythonmiljö, utan Torch eller modellvikter. Följande har faktiskt körts:

1. Referensgenerering för 1:1, 1:2 och 95:1 med biblioteksreferensen.
2. Jämförelse av referensen med sig själv: noll fel i dessa exempel.
3. En avsiktligt syntetisk borttagning av slutets `ن` i 1:2: en `normal`/`delete`-post med `uthmani_pos=(36,37)` returnerades. Detta testar mappnings-API:t, inte modellens hörsel.
4. Fonemgenerering för **alla 6 236 ayat i Sakinas paketerade Uthmani-edition**, efter enbart uttrycklig Basmala-extraktion och borttagning av inledande BOM i arbetsrepresentationen. Körningen slutfördes på cirka 27,65 sekunder i den här miljön och inga fonetizer-undantag uppstod.
5. En separat kontroll av **alla 6 236 biblioteksägda `Aya(...).get().uthmani`-referenser** slutfördes på cirka 27,47 sekunder: **inga okända fonem, inga undantag och rätt längd på positionsmappningen** för samtliga. Detta är fortfarande en kontroll av fonetisering och referenser, inte av inspelat ljud.

Den sista kontrollen hittade dock **elva tecken som fortfarande hamnar i fonemutdata men inte finns i modellens fonemvokabulär**: `U+06DB`, `U+06D6`, `U+06ED`, `U+06D7`, `U+06DA`, `U+06D9`, `U+06DE`, `U+06D8`, `U+06E2`, `U+0653`, `U+06E9`. De förekommer tusentals gånger, bland annat som paustecken, hizb-/sajdamärken och särskilda korantecken. Ett lyckat anrop till fonetizern är därför **inte** ett tillräckligt kompatibilitetstest för modelltokaniseringen. Det exakta neurala körningsfelet är inte reproducerat.

En inledande BOM i Sakinas råa 1:1-text bevaras också i fonemutdata om den inte hanteras. Originalresurserna ska fortsätta vara orörda. Ta inte bort okända tecken godtyckligt från förväntade fonem för att få anropet att gå igenom; det riskerar att ändra förväntat uttal.

Säker första integrationsväg är därför att använda bibliotekets egen träningsanpassade versrepresentation och returnera **exakt `reference_text`** tillsammans med felpositionerna. Resultatvyn kan visa och markera den referenstexten. Bibliotekets text har delvis annan ortografi än läsarens edition, exempelvis tatweel. Felpositioner får inte direkt läggas på läsartexten utan verifierad positionsöversättning. Pythonsträngarnas index räknar Unicode-kodpunkter; Swift `String`-index räknar normalt grafem och NSString använder UTF-16. Avtalet ska uttryckligen ange Unicode-skalärintervall och klienten måste validera dem.

En separat, gemensam app-/serverdataset **har exporterats** under `Sources/QuranPractice/Resources/PracticeReferences/`, med källidentiteten `quran-transcript-0.6.4`. `scripts/export_practice_references.py` kontrollerar den fixerade paketversionen, originaldatans SHA256, käll-API:ns SHA256, alla versreferenser och modellvokabulären före export. Den kopierar varje API-text ordagrant och inkluderar de ursprungliga licenserna. Kapitel använder `surah_id`, ett separat valfritt `basmala` och `ayahs[{ayah_number,text}]`; `index.json` innehåller proveniens, antal och hashmanifest. Läsvyns befintliga koranresurser ändras inte.

Exporten innehåller 118 filer, totalt **2 011 271 byte**, inklusive notiser och det lilla vokabulärunderlaget. Exportens fullständiga kontroll av 6 236 versreferenser och ytterligare 112 sammanslagna öppningsfraser passerade utan okända fonem eller fel på mappningslängder. `python3 scripts/export_practice_references.py --verify` har därefter körts med enbart standardbiblioteket och godkänt inventering, identiteter, notiser och SHA256-hashar. Detta innebär fortfarande ingen utförd ljudinferens eller bedömning av en elev.

Bibliotekets versreferens innehåller ingen prefixerad Basmala utanför Fatiha. `bismillah_uthmani` är ett separat originalfält och är null för sura 1 och 9; i sura 1 är Basmala själva ayah 1. En eventuell inställning som inkluderar Basmala för annan suras öppningsvers använder detta exakta fält och en separator. Även ett vokabulärkompatibelt sammanslaget textfält behöver ljudtestas för pauser kontra sammanhängande läsning; det ger inte automatiskt en korrekt bedömning av båda sätten.

## iPhone: Core ML, ONNX och WhisperKit

- **Full Muaalem:** vikter på cirka 2,42 GB i FP32 innebär minst den storleksordningen före activationsminne och övrig körning; FP16/BF16 kan minska vikternas lagring men garanterar inte minne eller temperatur. Uppgiften om 1,5 GB GPU-minne i upstream-README är författarnas, inte vår iPhone-mätning. En 24-lagers Conformer-liknande modell kan inte antas bli en lätt kontinuerlig bakgrundslyssnare.
- **ONNX Runtime för iOS:** [officiell iOS-dokumentation](https://onnxruntime.ai/docs/tutorials/mobile/deploy-ios.html) ger en möjlig runtimeväg. Den publicerade Android-ONNX-modellen är en forskningsstart, inte en färdig Swift-produkt. Förbehandlingslikhet, dynamiska dimensioner, operatorstöd, Core ML-exekveringsprovider/fallback, flernivålogiter och svensk återkoppling behöver verifieras. Kvantiseringens inverkan på varje tajweedregel behöver mätas, inte bara filstorleken.
- **Core ML:** en egen konvertering kräver ett numeriskt ekvivalenstest mot den fixerade Pythonmodellen samt fysisk iPhone-provning. HifzGuide visar att ett mindre fonemspår kan vara genomförbart men ger inga sifat-huvuden åt Sakina. Det bevisar inte att fulla v3.2 kan köras med samma prestanda.
- **WhisperKit:** [Argmax OSS Swift](https://github.com/argmaxinc/argmax-oss-swift) ger faktisk lokal Whisper-inferens. [whisperkittools](https://github.com/argmaxinc/whisperkittools) dokumenterar konvertering av egna Hugging Face Whisper-varianter. En konverterad Tarteel-Whispermodell skulle kunna hjälpa läspositions-/ordspåret, men WhisperKit kan inte utan vidare köra Muaalems andra arkitektur eller skapa dess saknade tajweedegenskaper. En sådan konvertering och dess kvalitet är inte gjorda här.
- **Rust-/Swift-SDK:** [quran-muaalem-rs](https://github.com/obadx/quran-muaalem-rs), kontrollerad commit `23488e0c0c8ee64761175e849c2bf9e8f2fc1b30`, är Apache-2.0 och har korandatatillgångar, men inga Swift-bindningar eller XCFramework-filer i trädet. `crates/engine/src/lib.rs` innehåller vid den revisionen bara en genererad `add(left, right)`-funktion och ett motsvarande exempeltest. Beskrivningen om Swift-SDK är inte grund för att använda det som färdig inferensmotor.

## Nästa implementering och godkännande

1. Bygg en valbar tjänsteadapter som läser ett begränsat verkligt ljudklipp, validerar versreferens och Hafs-inställningar, avkodar/resamplar till 16 kHz mono och använder fixerade modellfiler. Modellstart ska ske på tjänsten, inte när någon öppnar koranläsaren.
2. Bevara referenstext och modell-/inställningsrevision i svaret. Separera möjliga fel från säkra fakta. Returnera ett begripligt resultat när ljudet är för kort, för långt, tyst, obegripligt eller inte passar referensen. Osäkerhet ska inte bli ett automatiskt underkänt resultat.
3. Kör verklig modellinferens på kända ljudfiler och kontrollera fonem, sifat, felmappning, minne och svarstid. Ett test med en fejkmotor eller en syntetisk fonemborttagning är endast ett kontraktstest.
4. Skapa en oberoende, samtyckesbaserad testmängd med nybörjare, korrekta recitationer och avsiktliga/regleriktiga variationer, flera telefonmikrofoner, rum och hastigheter. Dela per talare så att samma person inte återkommer i utveckling och sluttest.
5. Låt minst två kvalificerade bedömare märka relevanta regler och avgöra oenighet. Redovisa precision, recall och falska rättningar per regel; ett enda sammanslaget betyg döljer exempelvis ikhfaa-svagheten.
6. Jämför samma inspelningar mot de aktuella relevanta funktionerna i Tarteels betalversion. Målet är användarens krav; någon likvärdighet är ännu inte visad. Förslaget om minst 95 % lärarbekräftade presenterade rättningar är ett framtida acceptansmål, inte ett uppmätt resultat.
7. Mät långa pass på riktiga iPhone-modeller: läsning, referensljud och analys var för sig. Samla energi, termiskt tillstånd, peakminne och svarstid. Prova därefter en optimerad lokal modell bara om kvalitet och termik håller.

Servern kan finansieras utan ett obligatoriskt abonnemang för slutanvändaren, exempelvis med egen drift eller projektfinansiering, men CPU/GPU, lagring och nät kostar fortfarande. Offentlig modellåtkomst ger inte en kostnadsfri produktionsserver. Prissättning eller ett serveravtal har inte ordnats i den här undersökningen.

## Ytterligare fixerade källor

- QDAT-resultatrepo: `e8aa630fc988a4eade0225fb965d05f955ecdf86`.
- QDAT-HF-dataset: `8003b22ece41b26ea65e0dd71843e5943686a4fa`, modellkort anger Apache-2.0.
- Android-ONNX-artefakt: HF-revision `5d5a3510728b3d02e4a84897c311a5d404505ee9`; kortets angivna SHA256 `3ef7f9760b54161d876b5866fccd19cbcc7b793386753f515395f2d5012e9f96`. Ingen filhämtning eller egen hashkontroll är utförd.
- HifzGuide-minimodell: HF-revision `a2bebf7c2e9a74d9ff5c3269594132d7caea7696`.
- Mindre ordmodell: HF-revision `65c3ab93446f2f1041a18082433a911e5e154a9d`.

Versionspinnar dokumenterar det som lästes vid undersökningen. Första verkliga inferenskörningen ska även spara låsta runtimeberoenden och hårdvarubeskrivning; det arbetet kan inte ersättas av denna rapport.
