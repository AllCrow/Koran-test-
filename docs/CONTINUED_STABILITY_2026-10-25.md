# Fortsatt stabilitetsarbete 2026-10-25

## Förtydligad native-kvittens i pausprovet

Körning 49 hittade ett för tidigt kvitterat pausläge i MP3-provets andra
avbrottsfas på iOS 26. Två rate-kontroller läste 1, medan status var paused;
provet tog 0,309 s och hade inte nått någon tidsgräns. Den tidigare
förutsättningen efter resume kontrollerade bara appens publicerade flagga.

Provet bevakar nu motorn före varje kommando och kräver positiv native-rate
och playing före avbrottet. KVO är endast väckning för nya aktuella getter-
kontroller på huvudaktorn. Samma tvåsekundersgräns, riktiga MP3-avkodning,
tresekunderston, kvarvarande ljud under 2,5 s, inget naturligt slut och
slutliga rate0/paused-krav behålls. Samma item och ljudfil kontrolleras också.
De senaste 64 tillståndsobservationerna bifogas om kvittensen misslyckas.
Detta testbyte påstår inte att ett ihållande produktfel har bevisats eller
att en tidigare misslyckad körning har blivit godkänd. Ny Mac-verifiering krävs.

Användaren bad om fortsatt förbättringsarbete efter det godkända personliga
bygget 46. Det paketet och dess fullständiga historik/backup bevaras.

**Senaste utfall:** PR8 är integrerad som `c907121`. Både
[PR50](https://github.com/AllCrow/Koran-test-/actions/runs/40184479157) och
[main51](https://github.com/AllCrow/Koran-test-/actions/runs/40186048325)
har faktiskt passerat alla tre simulatorvarianter: 91 hostade och åtta
UI-prov per variant, 82 portabla fall per Mac, backendens 36 fall och
båda byggena. Alla sex main51-jobbloggar har lästs. Ägarutkast51 är sparat
och dess IPA återkontrollerad mot källan och releasepostens hash-/storleksdata.
Se [leveransbevis](evidence/delivery-51-2026-10-25.json). De tidigare
avsnitten nedan bevarar utveckling/fel före detta godkännande.
Det [separata provet av riktiga ljudkällor](LIVE_RECITATION_AUDIT.md)
tillför tre native-fall på en simulator och räknas inte in i 91+8-matrisen.

## Avgränsade rättningar

- **Förlorad ljudtjänst:** spelaren hanterar nu iOS-notisen om förlust direkt,
  stoppar den verkliga motorn, ogiltigförklarar gamla callbacks och behåller
  vers/recitatör. Nya medieobjekt väntar på reset. Ingen automatisk återstart;
  användaren måste uttryckligen spela igen efter återställningen.
- **Sammanfogad läskopia:** två var för sig giltiga filer kan få en union
  större än den sparade läsdatans gräns. Både den föreslagna sparade staten
  och exporten storlekskontrolleras före publicering eller skrivning. En för
  stor union lämnar minne och tidigare sparade byte orörda. Standardgränsen
  är fortsatt 4 MiB. Ett internt lägre budgetvärde provar den riktiga
  serialiseringsgränsen utan stora syntetiska fixturefiler.
- **Avbruten suraladdning:** en återställning från Öva får inte byta läsarens
  sura efter att vyn lämnats. Den senaste färdiga suran, valet och eventuellt
  fel behålls tills laddningen lyckas eller faktiskt misslyckas. Cancellation
  och sena svar kan inte skriva över ett nyare val eller släcka dess
  laddningsindikator. Ett verkligt fel behåller rätt mål för återförsök.
- **UIKit-underhåll:** färgkontrastens traitkombinationer använder API:t för
  iOS 17 och senare i stället för den deprekerade sammanslagningsinitieraren.
  Källa, färgtoner, text och kontrastkrav är oförändrade.

## Prov och status före Mac-körningen

Elva nya hostade regressioner tillförs: två för ljudtjänstförlust, två för
importgränser och sex för laddning/cancellation. De två sena laddningsproven
provar både framgång och fel från den gamla laddningen. Förväntad native-svit
är nu **91 hostade + åtta UI-fall per simulator**. Det är ett förväntat antal,
inte ett godkänt Mac-utfall.

Innehålls-, referens-, font- och ikonvalidering passerade lokalt. Projektet
har återskapats med åtta hostade testfiler. Linux/Swift 6.0.3:s frontend
godkände syntaxen i alla ändrade Swift-filer; den kontrollen ersätter inte
Apple-SDK-typkontroll eller ett native-test. **Mac CI återstår för kandidaten.**

Nya ljudprov använder riktig AVPlayer med en genererad åtta sekunders WAV,
men ljudtjänstnotiserna är simulerade. Inspelningar, fysisk iPhone, externa
ljudrutter, energiförbrukning och faktisk installation är fortfarande inte
provade. Automatisk recitationsanalys är fortsatt avstängd i standardbygget;
inget nytt påstående om Tarteels kvalitet görs.

Senaste fullständigt godkända personliga paket och tidigare verifiering finns
i [STATUS.md](../STATUS.md) och [underlaget för bygge 46](evidence/premium-readiness-2026-10-25.md).

En separat granskning av den första kandidaten hittade att ett sent giltigt
katalogsvar kunde tappas när ett nyare suraval redan hade börjat. Katalogen
lagras nu efter cancellation-kontroll men före kapitelgenerationens kontroll.
Det sjunde laddningsprovet täcker både nyare färdigt och pågående kapitel.
Den ersatta körningen räknas inte som godkännande för denna rättade källa.

## Lästa resultat och positionskontroll på kompakt simulator

[Körning 48](https://github.com/AllCrow/Koran-test-/actions/runs/40181293204)
på `19a50e11becf236853cab29f779d5007cdbef7ba` är **failure**. Samtliga tre
hostade grupper passerade 91 prov. 16Pro/iOS18.5 och 16e/iOS26.2 passerade
även åtta UI-prov; SE3 hade ett fel i åtta UI-prov, vid återstarten till
114:1 i `testNextSurahSavesPositionWithoutReadingCreditAndEndsAtAnNas`.
Backendens 36 prov och det osignerade iPhoneOS-bygget passerade. Ingen
ny ägarnedladdning skapades av den underkända helkörningen.

SE-jobbet `121133205250` har lästs. Den första positionspredikatkörningen
gjorde flera efterföljande tillgänglighetsfrågor, med omförsök vid målfrågans
`exists`, genom femsekundersfönstret. Den hämtade felbilden och senare
ramdiagnostiken visar hela rätta badgen vid **(40,92,55,26.5)**, inom
krävda **y64–202.5**, med versbörjan synlig. Det senare belägget gör inte
den underkända femsekunderskontrollen godkänd i efterhand.

Artefakt `12594797373` har rätt käll-SHA och verifierad ZIP-SHA256
`7183ef36a8ae95b1e3a2876679da8f07833f044c9d538504a2042d4805593dde`.
Bild `C02DF83D-293C-46E4-9546-E2D0910F98E6.png`, ramtext
`5908B0D9-6E19-40EB-8743-6DBE81042D14.txt` och skärminspelningen har
granskats. Källans faktiska Apple-checkout `ca485ed4d3afdf9c3e5f5873011ba67e70c4c447`
är hämtad och helt tree-identisk med `19a50e1`.

Positionshjälparen läser nu badge, navigationsfält, flikfält och fönster ur
**en sammanhängande native-ögonblicksbild** i stället för många separata
fjärrfrågor som kan korsa ett flikbyte. Den kräver en enda matchande badge,
rätt globalt ID/etikett, hela ändliga ramen nära toppen och inom fönstrets
bredd samt appen i förgrunden. **Samma fem sekunder**, fyra långa hopp-/
återstarts-/upprepnings-/senarepositionskrav och verkliga knapptryck är kvar.
Läsaren, gesterna och all produktionskod är oförändrade av denna korrigering.
Den är ännu inte native-godkänd; en ny Mac-körning måste läsas före integration.
