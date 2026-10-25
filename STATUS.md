# Sakina – utvecklingsstatus

Uppdaterat **2026-10-25**. Verifierad native-grund för ett personligt iPhone-prov,
**iOS 17+**. Personlig signering, fysisk enhet och färdig tajweedkvalitet återstår.

## Verifierad kod och testresultat

[PR #6](https://github.com/AllCrow/Koran-test-/pull/6) är mergad som
`8cd977c4f2063e51784cc0b7c3fbca75b1760ec3`. Den bevarar båda pausgrenarnas
historik, inklusive `ecd130a` och `03cf72d`; PR5 stängdes som sammanförd
dubblett. PR3:s HTTP-brygga och PR4:s MP3-prov ingår också.

[Mac-körning 40175540017](https://github.com/AllCrow/Koran-test-/actions/runs/40175540017)
är **completed/success** på
`35114317d7faa690fcd6fee641e88eaa6eccc4cb`.
Faktisk Apple-checkout `8ded616d03e3ca0a512b1979580d0730d78dfdb3`,
branchkällan och mergad main 8cd977c har **byteidentiska kompletta filträd**:
`bb29ae36fce16da46c05b35535f30257adab2152`. Jobbloggar, artefakternas
head-SHA, paket och bilder har lästs/kontrollerats.

| Simulator | Byggverktyg | Hostade prov | UI-flöden | Portabla Swift-prov |
| --- | --- | --- | --- | --- |
| iPhone SE, 3:e generationen / iOS 18.5 | Xcode 16.4 | **80/80** | **8/8** | **82/82** |
| iPhone 16 Pro / iOS 18.5 | Xcode 26.2 | **80/80** | **8/8** | **82/82** |
| iPhone 16e / iOS 26.2 | Xcode 26.2 | **80/80** | **8/8** | **82/82** |

Det är **88 native-prov per variant**, inte 264 olika prov. Swift-loggarna
innehåller 82 unika körda fall vardera. **36 backendprov** passerar med
ResourceWarning som fel och riktig ffmpeg-avkodning. Simulatorbyggen,
fysiskt iPhoneOS-bygge, alla innehålls-/font-/referenskontroller och
deterministisk projektgenerering passerar. Projektet har 15 appfiler,
sju hostade testfiler, en UI-testfil och tre lokala bibliotek.
Detta är Mac-resultat; ingen aktuell Linux-Swift-körning påstås.

Den automatiska efterföljande
[main-körningen 40176707574](https://github.com/AllCrow/Koran-test-/actions/runs/40176707574)
på 8cd977c behöver sitt eget faktiska slutresultat och ägarnedladdningsjobb.
Identisk appkod mot den godkända PR-körningen är verifierad; en separat
main-success eller ny beständig nedladdning påstås inte i förväg.

## Vad som rättats och faktiskt provats

- **Paus:** sena native rate-/tillståndshändelser får inte hålla motorn igång
  efter användarens paus. Båda observertyperna kontrollerar aktuell
  item/generation på huvudaktorn. Ingen ytterligare pausesetter vid rate0,
  inga timers eller pollning. Ett riktigt åttasekunders WAV-prov tvingar en
  positiv sen start, kräver rate0 + paused inom två sekunder före EOF,
  bevarar samma item/vers/filval och verifierar uttrycklig återstart.
- **MP3:** sju prov av verklig MP3-till-PCM-avkodning och AVPlayer genom
  AudioLibrary för tre recitatörsval, naturligt versslut/autospelning,
  enstaka övningsvers, simulerade avbrotts-/hörlursnotiser och sena händelser.
  Väntarna tar emot KVO på huvudkön och kräver även motorns aktuella värden.
  Samma tvåsekundersgräns och kvarvarande ljud behålls. Genererad svag ton,
  inga mänskliga inspelningar eller mikrofonprov.
- **Nedladdning:** fem riktiga URLSessionDownloadTask-prov mot 127.0.0.1
  kontrollerar lagring/MP3-avkodning för alla tre val, diskåteröppning,
  HTTP-fel/återupptagning, avbruten kropp och storleksavbrott före EOF.
  Sessionens download-delegate driver 32 MiB-gränsen och en temporär fil
  bevaras innan Foundations callback återvänder. Testet återställer begärd
  HTTPS-adress i svarsmetadata; extern TLS/EveryAyah ingår inte.
- **Läsning:** kontinuerlig native List med återanvända celler och globala
  vers-ID:n. Fyra positionskontroller kräver hela badgen nära toppen inom
  fem sekunder vid 2:255, återstart, upprepat hopp och senare läsposition.
  Ingen navigationskredit. Bilderna för 2:255 har granskats på alla tre
  varianter: rätt badge och versbörjan syns direkt under navigeringen.
- **Tillgänglighet och lokala val:** åtta verkliga UI-flöden täcker också
  bokmärke/surabyte, största Dynamic Type, sparad arabisk textstorlek,
  sparat mörkt läge, veckohistorik, backupkontroller och nästa sura fram
  till an-Nas. Interaktiva kontroller kräver hela nåbara 44pt-mål och
  faktiska värdeändringar/omstarter.

iOS 26:s read-only badge kunde rapporteras som ej hittable trots att
felbilden och diagnostiken visade hela 2:255 vid y129–155 inom krävda y101–251.
Positionsprovet mäter därför full ändlig vertikal/horisontell synlighet,
exakt etikett/global referens och app i förgrunden. Ingen tapppunkt krävs på
läsetiketten. Krav och deadlines för interaktiva kontroller är kvar.
Det är en rättning av verifieringen, ingen ny läsarimplementation.

## Paket och installationsväg

Den godkända PR-körningens paket är **Sakina 0.1.0(44)**, Release,
**iPhoneOS/arm64**, Xcode 26.2/17C52, SDK iphoneos26.2 och minsta iOS 17.

- IPA-storlek: **3257523 byte**.
- SHA256: `71b52b07f67c0a2b74df39747b771ed6c3b968eec0da0403e8663dbb105f72a0`.
- Faktisk Mach-O bekräftar iOS-plattform 2, arm64, minOS 17 och SDK 26.2.
- Paketrapporten anger verklig checkout 8ded616d; ingen provisioningprofil.
- Fysisk IPA-artefakt: **12591659073**, matchande head3511431.
  Samtliga körning 44-artefakter lagras till **2026-11-01**.

Paketet är **osignerat**, inte installerat på en telefon och inte en
TestFlight-/App Store-release. Det kan inte öppnas som en app från Filer.
En simulatorapp är en annan produkt än denna iPhoneOS-IPA.

Följ [personlig installation](docs/PERSONAL_IPHONE_INSTALL.md) och
[första telefonprovet](docs/FIRST_IPHONE_TEST.md). SideStore med vanligt
Apple-konto och lånad Mac/Windows är den förberedda gratisvägen.
Datoråtkomst finns ännu inte; ingen ny rutinfråga om detta behövs.
Appleuppgifter, parkopplingsfil och röster ska inte till chatt/Git.
Den äldre återkontrollerade ägardraften26 finns kvar som historisk
återställningspunkt; en ny beständig draft kräver godkänt main-jobb.

Apples officiellt kontrollerade uppladdningskrav är Xcode26+/iOS 26SDK
sedan 28 april 2026. Bygg-SDK 26.2 är nu faktiskt använd, även mot iOS18.5.
Det bevisar inte accepterad uppladdning eller personlig signering.

## Funktioner och återstående färdigkriterier

| Del | Implementerat/verifierat i denna miljö | Kvar före färdig produkt |
| --- | --- | --- |
| Koranläsning | 114 suror/6 236 ayat offline, byteexakta käll-/övningsutgåvor, Amiri Quran med källnotiser, valbar tajweed och textstorlek. | Fysisk återgivning, VoiceOver/Switch Control och längre läspass. |
| Läsdata | Position, bokmärken, eget mål, uppmuntrande streak, sju dagars historik och additiv läsbackup. | Fysisk filväljare, ominstallation/återställning och verkliga kalenderbyten. |
| Tafsir | Källangiven arabisk al-Muyassar, validerad bounded cache av tidigare öppnade förklaringar. | Verkligt nät/flygplansläge och användningsvillkor. Nya förklaringar kräver nät, ingen fullständig offline-tafsir eller svensk förklaring. |
| Recitation | Tre val, lokala filer föredras, faktisk spelarhändelse styr versmarkering, robusta syntetiska native-prov. | Riktiga imaminspelningar, extern TLS/nedladdning, fysisk offlineuppspelning, ljudrutter/samtal/låsskärm och rättigheter. Ingen ordtidssynkning. |
| Egen röst | Lokal vald tagning/återlyssning, högst 60 s, skyddad livscykel och ljudsessionsägarskap. | Riktig mikrofon, inspelningslängd, ljudavbrott och bakgrundsåterhämtning på telefon. |
| Tajweedanalys | Separat experimentell Muaalem-backend/native-klient och dokumenterade verkliga CPU-funktionsprov. Avstängd i standardbygget, ingen publik server. | Expertetiketter, stödda regler/sifat, representativa elevklipp, precision/recall, drift och Tarteel-jämförelse. **Kvalitetsmålet är inte uppnått.** |
| Energi/leverans | Lätta händelsestyrda läs-/ljudflöden, avgränsade cacher, SDK 26.2-byggen och personlig installationsguide. | Fysisk värme/batteri/minne, signering/installation och säker uppdatering. Serverdrift kan kosta trots avsaknad av obligatorisk månadsavgift. |

De 18 nya verkliga modellfunktionsproven och tidigare 35 indata beskrivs i
[modellrapporten](docs/MODEL_SMOKE_RESULTS.md). Alla sju kodhashar i den nya
evidensen har matchats mot backendkoden; alla 18 svarade assessed utan
presenterade indikationer. Det är inte sakkunnig bedömning av deras innehåll
eller bevis på vilka elevfel som missas. Fallet al-Afasy 112:2 och de ännu
oanvända sifat-huvudena kvarstår. Modellvikter och ljud finns inte i Git/app.
[REA-inspektionen](docs/REA_MODEL_INSPECTION.md) gäller modellartefakten,
inte Tarteels privata motor eller akustisk kvalitetsparitet.

## Fortsatt arbete och historik

[PR #7](https://github.com/AllCrow/Koran-test-/pull/7) verifierar separat
kortare CI-återkoppling: bygg testmålen en gång, kör hostade prov före UI och
bevara båda resultatbundlarna. App- och testkod är oförändrad; den nya
workflow-layouten behöver sitt verkliga Mac-resultat före integration.

[Tidigare status och verifieringsförlopp](docs/STATUS_HISTORY_2026-10-25.md)
bevarar tidigare fulltext, godkända baslinjer, de faktiskt misslyckade
körningarna och avbrutna kandidater. Inget gammalt failure/cancelled blir
success genom kodjämförelse. Fortsätt på arbetsgrenar medan kandidat verifieras.
Publik synlighet är godkänd tills vidare och full Git-historik är bevarad.
