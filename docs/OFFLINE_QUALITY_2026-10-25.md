# Offlineåterhämtning och tajweedutvärdering

Denna omgång följer användarens beslut att färdigställa de förbättringar som går
att verifiera i molnmiljön. Den tidigare godkända appen och hela Git-historiken
bevaras. Ingen fysisk iPhone eller sakkunnig tajweedgranskning finns tillgänglig.

## Avgränsade ändringar

- **Ljudlagring:** ett misslyckat skapande av lagringsmappen låser inte längre
  samma appsession. Ett uttryckligt nytt nedladdningsförsök försöker förbereda
  lagringen igen. Ingen automatisk återhämtning startar nättrafik.
- **Publicering av ljud:** filskydd och filidentitet förbereds före flytt eller
  ersättning till versens slutliga filnamn. Ingen fallibel metadataoperation
  återstår efter den flytten. Tidigare färdiga verser ska bevaras vid fel.
- **Tafsir:** en försvunnen cachemapp kan återskapas utan en ny repository-instans.
  Mappens aktuella typ kontrolleras vid diskåtkomst och efter nätverksväntan.
  En ersättande symbolisk länk används inte för läsning, skrivning eller
  kvotstädning. Giltig online-text visas även när cachen inte kan användas.
- **Tajweed:** ett separat [offlineverktyg](TAJWEED_EVALUATION.md) jämför deklarerade,
  sakkunnigt avgjorda fel med sparade modellindikationer. Det binder exakt
  ljudhash, referenstext och modellrevision. Ogranskade fall får inget resultat
  för träffsäkerhet. Matchningen mäter felklass och plats; den avgör inte att en
  föreslagen tajweedregel eller fonetisk rättning är korrekt.

Ingen lagringsmigration, ny molnsynk, automatisk uppladdning eller ändring av
korantext införs. MP3-kontrollen i appen är fortfarande en avgränsad strukturell
kontroll, inte en helfilsavkodning. Automatisk analys är avstängd i standardappen.

## Regressioner och verifiering

Tre nya AudioLibrary-fall provar återhämtad lagring i samma instans, reparation
av en trasig versfil med bevarade färdiga byte och sena svar från en transport
som avsiktligt ignorerar avbrytning. Två nya HTTP-fall använder riktiga
URLSession-download tasks över loopback: avbruten TCP-kropp efter giltiga
MP3-ramar samt radering följd av ett nytt recitatörsjobb medan gamla svar städas.

Tre nya portabla tafsirfall provar borttagen rot, ersättande länk med externa
filer som inte får ändras eller städas, och rotbyte under ett pågående nätsvar.
De två första regressionerna misslyckades mot den gamla implementationen.
Alla **83 portabla Linux-Swift-fall** passerade därefter i Swift6.0.3 med
avstängt containernät. Innehåll, källhashar, övningsreferenser, font, ikon och
reproducerbar projektgenerering passerade också.

**Native-verifieringen är godkänd i [huvudkörning 53](https://github.com/AllCrow/Koran-test-/actions/runs/40192974053)**
på `e1bb2625136277beb8f4eab78f17576acc3d56e5`. Alla sex jobb och faktiska
loggar har lästs: **96 hostade + åtta UI-fall på vardera tre simulatorer**,
85 unika portabla Mac-fall per variant och 57 backendfall, varav 21 syntetiska
utvärderingskontraktsprov. Det är 104 unika native-/UI-fall och 312
exekveringar. Byggen och det gated ägarutkastet passerade också.

Personligt paket **0.1.0 (53)** har jämförts oberoende med CI-artefakt,
releasepost, Mach-O/plist och alla 239 källresurser. IPA:n är fortfarande
osignerad. De tre nya 2:255-bilderna har hashkontrollerats och granskats.
[Leveransbeviset](evidence/delivery-53-2026-10-25.json) binder källa,
jobb, paket, bilder och kvarvarande provgränser.

Utvärderingsrapportens indata-/kodhashar, kompletta baslinjesvar och alla
reproducerbara resultatfält matchar vid separat kontroll. 112:2 är fortsatt
`pending`, noll sakkunnigt avgjorda fall och `quality_metrics: null`.
Den sparade rapporten dokumenterar återfunnen originalfil; denna separata
kontroll hade inte ljudbyten och intygar ingen andra bytekontroll.

## Kvarvarande gränser

Loopback HTTP provar inte extern TLS, faktisk EveryAyah-tillgänglighet eller
telefonens radioväxling. Simulatorer verifierar inte fysisk installation,
mikrofon, filskydd vid låst telefon, hörlurar, VoiceOver, värme eller batteri.
Filrotens typkontroller är återhämtningsskydd, ingen garanti mot alla samtidiga
POSIX-filsystembyten. Ingen generell noggrannhet, full sifat-bedömning eller
Tarteel-jämförelse påstås. Innehållsrättigheter inför offentlig release kvarstår.
