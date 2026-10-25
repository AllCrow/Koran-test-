# Separat native-prov av riktiga recitationskällor

Detta är ett opt-in-prov av ett verifieringsglapp som de vanliga genererade
tonerna och loopback-servern inte täcker: verkliga EveryAyah-filer genom
appens ordinarie HTTPS-nedladdare, diskantagning och lokala filval, följt
av native-avkodning och faktisk uppspelning på simulator.

**Verifierat 2026-10-25:** [den första riktiga körningen](https://github.com/AllCrow/Koran-test-/actions/runs/40185506975)
är avslutad med **success** på källan `3d980b3d97a7ac4c690eca0e5e5648209cd288e7`.
Jobbet `121145330461` kompilerade med Xcode26.2/17C52 och körde **tre
godkända native-fall**, utan fel, på iPhone16e/iOS26.2-simulatorn.
Jobbloggen, alla tre ursprungliga JSON-bilagor, deras hashkoppling och
artefaktens head-SHA/ZIP har faktiskt lästs och kontrollerats.

| Recitatör | Hela filer hämtade och native-avkodade | Lokalt spelad vers till native-EOF | Hashkontrollerade bytes för spelad fil |
| --- | --- | --- | --- |
| al-Afasy | 112:1–4 | 112:2 | 41 087 |
| al-Husary | 112:1–4 | 112:2 | 84 891 |
| al-Minshawi | 112:1–4 | 112:2 | 42 759 |

Totalt hämtades **12 riktiga filer / 855 505 byte** och avkodades
**52,020612 sekunder PCM** med `AVAudioFile`. Alla tre uppspelningar
visade positiv native-rate/`.playing`, faktiskt versslut, samma item,
lokal fil och exakt versreferens. Ingen fallback eller ny nedladdning
under den lokala fasen behövdes. De tre fallen tog sammanlagt 16,867
sekunder; detta är CI:s provtid, inte ett prestandalöfte för en telefon.

[Sparade resultatdata, originalbilagornas SHA256 och verifieringsmetadata](evidence/live-recitation-native-2026-10-25.json)
binder varje fil, kodhash och referens till körningen. Artefakt
`12595977499` är **96 942 byte**, ZIP-SHA256
`d54d4aa294e9e343f6aacd4bc48fbe3306dd6bb593c865ba3987e07e045fa1c7`,
med rätt käll-SHA och lagring till 2026-11-01. Den hämtade ZIP-filen har
46 poster och innehåller resultat/JSON, inga ljudfiler.

Appkod och ordinarie test-/byggindata i källan matchar den godkända
stabilitetskandidaten `0d85b19`. Huvudgrenens integration `c907121`
och dess faktiska CI50-checkout `7d29ca2` har samma filträd som den
gemensamma basen `5941917`: `188fe37ce0dfb1d2eaee63e78427f68482e8480d`.
Det separata live-provet räknas inte in i CI50:s 91 hostade/åtta UI-fall.

## Omfattning och källbindning

Tre fall, ett per konfigurerad recitatör, gör följande:

1. Hämtar al-Ikhlas fyra verser med en vanlig `AudioLibrary` och dess
   riktiga native-nedladdare. Ingen transportseam, loopback eller omskriven
   svarsadress används under nedladdningen.
2. Öppnar samma diskplats med en ny biblioteksinstans, validerar fyra lokala
   filer och avkodar dem i sin helhet med `AVAudioFile`. Totalt väntas
   tolv riktiga filer, utan att hela ljudkorpusen hämtas.
3. Kontrollerar råa bytes och SHA256 för 112:2 mot den redan körda
   [hela-källfilskontrollen](evidence/recitation-source-audit-2026-10-25.json).
   Nya källbytes gör kontrollen röd och kräver granskning; hashvärden får
   inte automatiskt bytas för att få grönt.
4. Spelar den valda lokala 112:2 med riktig mutad `AVPlayer` och aktiverad
   systemljudsession. Kräver observerad positiv native-rate/`.playing`,
   faktiskt native-EOF, rätt versreferens och samma lokala item vid slutet.
   En lokal källa som saknas får inte ersättas med en ny nätförfrågan.

Spelaren får en inspekterbar motor och samma `AudioLibrary.localURL`-val
som produktionsinitieraren. Bibliotekets återöppnade nedladdningsseam
avvisar nätanrop och en eventuell spelarfallback blir en saknad lokal fil.
Detta är inte en fysisk telefon med nätet avstängt. Det provar den lokala
kodvägen, ingen flygplans-/radio-/Bluetoothväxling.

## Körning och bevarande

`Verification/EveryAyahLiveSourceTests.swift` ligger **utanför AppTests**.
`scripts/stage_live_recitation_audit.py` binder manifest, aktuella relevanta
kodhashar och Git-källcommit till mallen och kopierar den till en tillfällig
CI-checkout. Projektet regenereras där, vilket lägger till dessa tre fall
endast i det uttryckliga provet. Vanlig app, ordinarie testschema,
deterministiska testantal och projektfil ändras inte i Git.

Det separata arbetsflödet `Opt-in real recitation audit` väljer
iPhone16e/iOS26.2/Xcode26.2. Under utveckling kör en push till just
`codex/verify-live-recitation-sources` provet; det har också ett manuellt
`workflow_dispatch`. Det stoppar eller ersätter inte den vanliga
leveranskandidatens verifiering. En senare uttrycklig körning kontaktar
EveryAyah och kan påverkas av tjänstens nät eller ändrade innehåll.

De tre JSON-bilagorna anger native-resultat, referenser, råfilshashar,
avkodade ramantal, käll-/kodidentitet och eventuella fel. Resultatbundeln
och dessa bilagor sparas i `Sakina-real-source-native-audit`, normalt sju
dagar; lästa fakta kan sedan dokumenteras i repot. Ljud, PCM, cachemappen
och hela DerivedData laddas inte upp. Temporära ljudfiler städas lokalt.

Ingen mikrofon, egen röst, modellinferens, publik analysserver, personlig
signering eller betaltjänst behövs. Standardanalys ska förbli avstängd.
En godkänd sådan körning skulle fortfarande inte bevisa korrekt recitatör
genom hörselgranskning, vers-/Basmala-/klippgränser, ljudrättigheter,
ordtider, fysisk energi/värme eller sakkunnig tajweed/Tarteel-kvalitet.
De gränserna står kvar i [innehållsunderlaget](CONTENT_RIGHTS.md).
