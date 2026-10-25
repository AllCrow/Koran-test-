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
  källversion `7657e3ad31c58a49f99d19b0db8f37913d249ee2`: slutresultat inväntas.
  Kapitelbindningen ligger nu utanför LazyVStack, så versernas ForEach är
  direkta barn i target-layouten. Lazy-rendering, globala ID:n och samma
  femsekunderskontroller är bevarade.
- Lokalt: **65 Swift-tester på Linux och 32 backendtester passerade**.
  Swift 6.0.3 använder paketets Swift 5-språkläge. Backendproven kördes med
  `ResourceWarning` som fel och riktig ffmpeg-avkodning av M4A/AAC/WAV.
  Linux FoundationNetworking har inte Darwins strömmande AsyncBytes-gräns;
  de två ytterligare Mac-proven är redovisade separat.

## Oberoende kontroll av den hämtade iPhone-filen

Från artefakt **12586829932**, körning **40163850515**, hämtades byggnummer **23**.
Paketkontrollerna är godkända; native-körningens slutresultat inväntas:

| Fält | Observerat |
| --- | --- |
| Version | 0.1.0 (23) |
| Plattform | iPhoneOS, Release, arm64, iOS 17.0+ |
| Källcommit | `7657e3ad31c58a49f99d19b0db8f37913d249ee2` |
| IPA-storlek | 3 104 771 byte |
| IPA SHA256 | `e9d1a927d131656e92f91eaffc8aacc8dbb41d4bb277eaf259323b572c1d911e` |
| CI-arkivets SHA256 | `d092045da15332223296d8cd7e43c7f650fc1b78aa1bc084c6ca30ba14f1cf33` |
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
