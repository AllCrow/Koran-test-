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
  Rättning pågår; kraven på exakt mål, omstart och senare läsposition behålls.
  Release för fysisk iPhone, simulatorbygge, 67 Mac-pakettester och 32
  backendtester passerade. Ingen godkänd releaseutkast-nedladdning skapades.
- [Rättningskörning 40161887485](https://github.com/AllCrow/Koran-test-/actions/runs/40161887485),
  källversion `b6d983648f87c849a9fa3bb86ee80961f263b39e`: slutresultat inväntas.
  Faktiska ForEach-ID:n och scrollpositionen använder nu samma globala sträng.
  iOS 17:s semantiska scrollning håller målet genom lazy-layoutens ändrade
  höjder; manuellt hopp köas till avslutad sheet-stängning. UI-kraven är kvar.
- Lokalt: **65 Swift-tester på Linux och 32 backendtester passerade**.
  Swift 6.0.3 använder paketets Swift 5-språkläge. Backendproven kördes med
  `ResourceWarning` som fel och riktig ffmpeg-avkodning av M4A/AAC/WAV.
  Linux FoundationNetworking har inte Darwins strömmande AsyncBytes-gräns;
  de två ytterligare Mac-proven är redovisade separat.

## Oberoende kontroll av den hämtade iPhone-filen

Från artefakt **12585743898**, körning **40161887485**, hämtades byggnummer **19**.
Paketkontrollerna är godkända; native-körningens slutresultat inväntas:

| Fält | Observerat |
| --- | --- |
| Version | 0.1.0 (19) |
| Plattform | iPhoneOS, Release, arm64, iOS 17.0+ |
| Källcommit | `b6d983648f87c849a9fa3bb86ee80961f263b39e` |
| IPA-storlek | 3 105 454 byte |
| IPA SHA256 | `2eb0b1bab9944fca26e4f7d5d3b885c748fc08ca67b34f6c3f4df10551f0b30c` |
| CI-arkivets SHA256 | `90f4e67f6aa5b0f88c0be7ece29b08af429da1ab8dc1fd59d1da67f21f116af6` |
| Signering/installation | Osignerad; personlig signering och fysisk installation återstår |

Det hämtade arkivets och IPA-filens ZIP-integritet är godkända. Appens plist,
exekverbara filrättigheter och Mach-O har lästs på nytt: arm64, `MH_EXECUTE`
och `LC_BUILD_VERSION`-plattform **IOS (2)**. Samtliga **115 koran-JSON-filer**,
fonten och **118 övningsresurser** matchar källfilerna exakt. Inga inbäddade
testpaket, utvecklarprofiler eller externa dylib/framework-binärer finns.
Analysen är fortfarande avstängd och serveradressen tom i den faktiska appfilen.
Detta verifierar paketets innehåll, inte signering eller körning på telefonen.

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
