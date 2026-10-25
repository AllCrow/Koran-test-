# Fortsatt stabilitetsarbete 2026-10-25

Användaren bad om fortsatt förbättringsarbete efter det godkända personliga
bygget 46. Det paketet och dess fullständiga historik/backup bevaras.

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
