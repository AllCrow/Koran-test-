# Separat native-prov av riktiga recitationskällor

Detta är ett opt-in-prov av ett verifieringsglapp som de vanliga genererade
tonerna och loopback-servern inte täcker: verkliga EveryAyah-filer genom
appens ordinarie HTTPS-nedladdare, diskantagning och lokala filval, följt
av native-avkodning och faktisk uppspelning på simulator.

**Status före första körningen: oprövat.** Linux har bara verifierat staging,
hashkoppling och källkod. Ett skapat arbetsflöde eller en kompilerbar mall
är inte ett native-resultat. Faktiska loggar, JSON-bilagor och käll-SHA måste
läsas före ett påstående om godkänt utfall.

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
