# Verklig REA-inspektion av Muaalem-modellen

REA har den 24 oktober 2026 inspekterat den hämtade `model.safetensors` för
`obadx/muaalem-model-v3_2`. Kommandot lyckades och strömmade hela filen för
SHA-256. Detta är faktisk REA-evidens från modellartefakten, separat från
backendens inferensprov och från läsning av modellens källkod.

## Resultat

Källa: [oförändrad, fullständig REA-evidens](evidence/rea-model-v3_2-full-2026-10-24.json),
evidens-ID
`ev_52861e8dd61095c59a81a1f6580e03e1bbfaf60f2c9b72b44ac5f3d72d12bfa9`.

| Uppgift | Resultat | Evidenstyp |
| --- | --- | --- |
| Identifierat filformat | safetensors | Observerat från filens innehåll |
| Filstorlek | 2 423 124 012 byte, cirka 2,257 GiB | Observerat |
| Header inklusive längdfält | 107 008 byte | Observerat |
| Tensorer | 816 | Inventerade deklarationer |
| Deklarerade datatyper | Alla 816 är `F32` | Observerat i headern |
| Tensorelement, REA:s `parameter_count` | 605 754 251 | Härlett ur deklarerade former |
| Deklarerad tensorlagring | 2 423 017 004 byte, cirka 2,257 GiB | Härlett och kontrollerat mot deklarerade dataintervall |
| Metadatapost | `format = "pt"` | Observerad sträng |
| Header-, intervall- och lagringsstorlekskontroller | `complete` | REA:s rapporterade täckning |
| Tensorvärden | `not-interpreted` | Ingen tolkning av vikterna |

Fullständig SHA-256:

```text
6b6a2e85303d17ff0f3af5e1fc79ac83daecee409c756ddf27f0ced59393bb41
```

Headerns separata SHA-256:

```text
708a9ada53db32740bb0fccb2e6834999d520663432c002be94e4c848b254da4
```

REA:s fullfilshash överensstämmer med namnet på Hugging Face-cachens blob.
Headerhashen ensam skulle däremot inte identifiera tensorvärdena.

Exempel ur den fullständiga inventeringen: tensor 1,
`level_to_lm_head.ghonna.weight`, är deklarerad som `F32` med formen
`[3, 1024]`, 3 072 element och 12 288 byte. Tensorer med namnen
`wav2vec2_bert.adapter.layers.0.residual_conv.weight` och
`wav2vec2_bert.adapter.layers.0.self_attn_conv.weight` har vardera formen
`[2048, 1024, 3]` och upptar 25 165 824 deklarerade byte. Namn och former
fastställer inte modellens förmåga eller korrektheten i någon rättning.

## Vad storleken innebär för iPhone-arbetet

En minneskopia som behåller alla dessa tensorer i deras nuvarande `F32`-format
behöver cirka 2,257 GiB för själva tensorerna. Aktiveringar, arbetsbuffertar,
ljud, ramverk och appen tillkommer. Detta är ett beräkningsunderlag för en sådan
representation, inte en mätning av inferensens residenta eller maximala RAM.
Minnesmappning, strömning och andra körstrategier kan ge andra minnesförlopp.

Som rena räkneexempel ger samma antal element följande ideala lagringsmängder:

| Hypotetisk representation | Ideala byte | Cirka GiB |
| --- | --- | --- |
| 16 bitar per element | 1 211 508 502 | 1,128 |
| 8 bitar per element | 605 754 251 | 0,564 |
| 4 bitar per element, packat utan extra data | 302 877 126 | 0,282 |

Ingen sådan konvertering utfördes av REA. Tabellen utelämnar skalor,
packnings-/tensorjustering, modellstruktur och körbuffertar. Den visar inte att
kvantisering, Core ML eller en viss iPhone stöder modellen, och säger inget om
hur precisionen påverkas. REA deduplicerar inte delade eller upprepade vikter i
sitt elementantal.

## Verktyg och reproducerbarhet

Den lyckade körningen använde källkod från
[`morluto/rea`](https://github.com/morluto/rea/tree/f196ebf80665107aedc16892af25a1e1f9f26f43),
commit `f196ebf80665107aedc16892af25a1e1f9f26f43`. Paketmetadata anger version
6.7.0; detta källkodsbygge måste identifieras med commit, eftersom det publicerade
npm-paket med samma versionsetikett som tidigare undersöktes i arbetet inte
annonserade `inspect-model-artifact`. Det byggda källkodskommandots faktiska
`--help` bekräftade kommandot och `--hash full` innan inspektionen kördes.

REA byggdes med dess låsta beroenden och föreskrivna verktygsversioner:

```sh
cd /workspace/rea
npm exec --yes --package=node@24.22.1 --package=npm@11.16.0 \
  --call 'npm ci --ignore-scripts --no-audit --no-fund'
npm exec --yes --package=node@24.22.1 --package=npm@11.16.0 \
  --call 'npm run build:cached'
```

Bygget lyckades; `git status --short` var därefter tomt i REA-repot. Ingen
REA-källkod, MCP-konfiguration eller global Node-/npm-installation ändrades.
Låsta paket installerades lokalt i REA-checkouten och genererade byggartefakter
ligger där. [Den verkliga runtime-rapporten](evidence/rea-runtime-2026-10-24.json)
bekräftar Node 24.22.1 och att REA:s runtimekrav är uppfyllda.

Modellens valda Hugging Face-snapshot är
`01a1ef9fbe40d144ef845101e89ff924aed3fef5`. Dess `model.safetensors` är en
symbolisk länk. REA:s första anrop mot länken avböjdes med `ELOOP`; den
[oförändrade feldiagnostiken](evidence/rea-snapshot-symlink-error-2026-10-24.json)
finns kvar. Därefter kördes inspektionen mot den uttryckligen upplösta bloben
för samma fil, utan att kopiera eller ändra modellen:

```sh
npm exec --yes --package=node@24.22.1 --package=npm@11.16.0 --call \
  'node scripts/rea.mjs inspect-model-artifact /workspace/scratch/sakina-model-cache/models--obadx--muaalem-model-v3_2/blobs/6b6a2e85303d17ff0f3af5e1fc79ac83daecee409c756ddf27f0ced59393bb41 --hash full --format json'
```

[Anropsmetadata](evidence/rea-invocation-2026-10-24.json) bevarar snapshotväg,
länkmål, upplöst filväg, exakt kommando och avslutskod 0. Dessa metadata är
framställda av körningsskriptet och är uttryckligen **inte** en REA-evidenspost.
Själva REA-utdata bevaras oförändrade i den separata evidensfilen ovan.

Den lyckade engångskörningen tog 3,526 sekunder inklusive `npm exec`, med
3,537 sekunder användar-CPU och 0,673 sekunder system-CPU för barnprocesserna.
Största enskilda barnprocessens rapporterade topp var 382 080 KiB; detta är
inte summan av processfamiljens samtidiga minne. Cacheläget var inte fastställt
och tokenkostnad mättes inte. Måtten gäller artefaktinspektion och hashing,
inte modellinferens.

## Kvarstående gränser

Inspektionen verifierar deklarationer, intervall, storlekar och full filidentitet.
Den kör inga neuronnät och mäter inte uttalsbedömning, tajweedprecision,
svarstid för analys, batteriförbrukning eller temperatur. Den visar inte
kompatibilitet med en inferensmotor eller en iPhone. Tarteel-paritet kan därför
inte härledas ur denna evidens. Sådana slutsatser behöver separata modellprov,
sakkunnigbedömda inspelningar och mätningar på fysiska telefoner.
