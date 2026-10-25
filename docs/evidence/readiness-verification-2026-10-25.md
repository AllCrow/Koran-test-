# Förberedelse för personligt iPhone-prov – 2026-10-25

Denna rapport skiljer faktisk automatisk verifiering från återstående
enhetsprov. Äldre modell-/REA-rapporter och Git-historik har bevarats.

## Körningar och observerade resultat

- [Första härdningskörningen 40159743043](https://github.com/AllCrow/Koran-test-/actions/runs/40159743043),
  källversion `1c13b88f968a18291eaacbd5f9795e94e5124389`: Apple SDK-bygge,
  67 Mac-pakettester, 47 hostade tester, tre befintliga UI-flöden och 32
  backendtester passerade. Det nya fjärde UI-provet misslyckades vid tryck på
  tajweedreglaget med största textstorleken. Körningen som helhet var **failure**.
  Videon och den syntetiserade tryckhändelsen visar att radens mitt träffade
  textetiketten. Testet visar nu hela raden och trycker på själva kontrollen;
  krav på ändrat värde och bevarande efter omstart är kvar.
- [Nästa körning 40160928793](https://github.com/AllCrow/Koran-test-/actions/runs/40160928793),
  källversion `4d6585173cbb118923a5fb8aacaa729d7d438b86`: **failure**.
  Alla **49 hostade tester och fyra av fem UI-flöden passerade**, inklusive
  stortextprovet med beständigt tajweedval. Det nya hopptestet hittade en
  verklig felposition efter hopp till 2:255: felhierarkin visar 2:200–206.
  Felet ledde vidare till nästa rättning; kraven på exakt mål, omstart och
  senare läsposition behölls.
  Release för fysisk iPhone, simulatorbygge, 67 Mac-pakettester och 32
  backendtester passerade. Ingen godkänd releaseutkast-nedladdning skapades.
- [Rättningskörning 40161887485](https://github.com/AllCrow/Koran-test-/actions/runs/40161887485),
  källversion `b6d983648f87c849a9fa3bb86ee80961f263b39e`: **failure**.
  Faktiska ForEach-ID:n och scrollpositionen använder nu samma globala sträng.
  49 hostade och fyra av fem UI-flöden passerade. 2:255 fanns i AX-trädet,
  men den omedelbara hittability-kontrollen föll och bilden visade ännu 2:1.
  Native-byggen, paketkontroller och backend passerade; inget releaseutkast.
- [Fortsatt rättning 40162749812](https://github.com/AllCrow/Koran-test-/actions/runs/40162749812),
  källversion `bc304a0953d03f2a330e85b34c1375663207dbcc`: **failure**.
  Lazy-layoutens konkurrerande eget ID är borttaget. Samtliga fyra
  positionskontroller väntar nu på både existens och hittability inom högst
  fem sekunder, i stället för enbart AX-existens följt av ett omedelbart prov.
  Inga sleeps eller längre timeout. Fel sparar elementram, AX-träd och bild;
  samma starka krav på rätt vers, omstart och senare position gäller.
  49 hostade och övriga fyra UI-flöden passerade. Efter fem sekunder visade
  AX-rapporten 2:238–243 med 2:240 nära toppen; 2:255 saknades. Alltså kvarstod
  ett verkligt fel i långt hopp. Byggen, paket och backend passerade.
- [Direkta versmål 40163850515](https://github.com/AllCrow/Koran-test-/actions/runs/40163850515),
  källversion `7657e3ad31c58a49f99d19b0db8f37913d249ee2`: **success**.
  Kapitelbindningen ligger nu utanför LazyVStack, så versernas ForEach är
  direkta barn i target-layouten. Lazy-rendering, globala ID:n och samma
  femsekunderskontroller är bevarade. **49 hostade och fem UI-flöden passerade**,
  liksom 67 Mac-pakettester, 32 backendtester och båda Applebyggena.
  Ett ägaråtkomligt releaseutkast skapades. Bildgranskningen upptäckte dock
  att 2:255-badgen ligger nära nederkanten medan 2:254 fyller skärmen.
  Hittability-kravet räckte därför inte för ett bra läsläge. Nästa rättning
  använder native-listceller och skärper kravet till versnumret nära toppen.
- [Integrerad List-/MP3-körning 40165021106](https://github.com/AllCrow/Koran-test-/actions/runs/40165021106),
  källversion `1ba557c3d6bed990504789caa2d01398d897e263`: **success**.
  Native List återanvänder samma kort med individuella globala rad-ID:n,
  sammanhängande sura och scrollkommando efter stängd versväljare. Alla fyra
  positionsprov kräver hela badgen nära toppen inom fem sekunder, med aktuella
  nav-/tabbargränser. De sju parallellt färdigställda MP3-proven från PR #2
  är integrerade med bevarad historik. **56 hostade och samtliga fem UI-flöden
  passerade**, liksom 67 Mac-pakettester, 32 backendtester och båda Applebyggena.
  Alla fyra jobb är success. Bilden A764D9DD-F9BE-4DD9-9CAA-8328108987FE.png
  visar 2:255 direkt under navigationsfältet med första textraderna läsbara;
  2:254 syns inte. Även Fatiha, stor text och backupkontroller har bildgranskats.
- Lokalt: **65 Swift-tester på Linux och 32 backendtester passerade**.
  Swift 6.0.3 använder paketets Swift 5-språkläge. Backendproven kördes med
  `ResourceWarning` som fel och riktig ffmpeg-avkodning av M4A/AAC/WAV.
  Linux FoundationNetworking har inte Darwins strömmande AsyncBytes-gräns;
  de två ytterligare Mac-proven är redovisade separat.

## Oberoende kontroll av den hämtade iPhone-filen

Från artefakt **12588770110**, körning **40165021106**, hämtades byggnummer **26**.
Paketkontroller och den samlade native-/UI-körningen är godkända:

| Fält | Observerat |
| --- | --- |
| Version | 0.1.0 (26) |
| Plattform | iPhoneOS, Release, arm64, iOS 17.0+ |
| Källcommit | `1ba557c3d6bed990504789caa2d01398d897e263` |
| IPA-storlek | 3 108 088 byte |
| IPA SHA256 | `39c86f27d566869783815576e615b42892b8f6277b0198b10c82a1c28325e480` |
| CI-arkivets SHA256 | `708099f767f8d25b80f99c7bbb7e15e2a19bb6e9fe44ff6a72346151dac42516` |
| Signering/installation | Osignerad; personlig signering och fysisk installation återstår |

Det hämtade arkivets och IPA-filens ZIP-integritet är godkända. Appens plist,
exekverbara filrättigheter och Mach-O har lästs på nytt: arm64, `MH_EXECUTE`
och `LC_BUILD_VERSION`-plattform **IOS (2)**. Samtliga **115 koran-JSON-filer**,
fonten och **118 övningsresurser** matchar källfilerna exakt. Inga inbäddade
testpaket, utvecklarprofiler eller externa dylib/framework-binärer finns.
Analysen är fortfarande avstängd och serveradressen tom i den faktiska appfilen.
Detta verifierar paketets innehåll, inte signering eller körning på telefonen.

Det verifierade [releaseutkastet](https://github.com/AllCrow/Koran-test-/releases)
har ID **423168520**, tagg **personal-build-26-1**, draft=true och källmål
**1ba557c3d6bed990504789caa2d01398d897e263**. API-metadata bekräftar att både
uppladdad IPA och byggrapport har samma storlek och SHA256 som de lokalt
återkontrollerade filerna. Det är en ägarnedladdning, ingen publik apprelease.

## Begränsad kontroll av externa källor

2026-10-25 kl. 04:11 UTC svarade EveryAyahs tre konfigurerade recitatörsadresser
för **1:1** med HTTP 206, `audio/mpeg` och en MPEG-/ID3-kompatibel inledning.
Endast 4 096 byte per fil lästes. AlQuran Clouds tafsir för **112:1** svarade
HTTP 200; JSON-kod, globalt versnummer 6222, sura/vers och edition
`ar.muyassar/ar/text/tafsir` validerades. Detta är tillgänglighet från Linuxnätet,
inte helfilsavkodning, hörselgranskning, iPhone-nätprov eller rättighetsgodkännande.

## Vad resultatet inte visar

- Ingen personlig signering, SideStore-installation eller fysisk iPhone-körning.
- Ingen fysisk mikrofon, Bluetooth-/hörlursrutt, samtalsavbrott eller energimätning.
- Ingen faktisk systemfilväljare/iCloud-provider för säkerhetskopiering provad.
- Ingen ny akustisk modellutvärdering eller Tarteel-jämförelse i denna omgång.
  Analysfunktionen är fortsatt experimentell och avstängd som standard.
- Ingen slutförd rättighetskontroll för offentlig ljud-/appdistribution.

[Första enhetsprovet](../FIRST_IPHONE_TEST.md) och
[native-provlistan](../IOS_VERIFICATION.md) beskriver de återstående kontrollerna.
