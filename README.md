# Sakina – koranapp för iPhone

Pågående native-app i SwiftUI för iOS 17 eller senare. Arbetsnamnet är Sakina.
Målet är en lugn koranapp med låg energiförbrukning och utan obligatorisk månadsprenumeration.

## Det som finns i koden

- Alla 114 suror och 6 236 verser lokalt, uppdelade per sura för att begränsa minnesanvändningen.
- Valbar tajweedvisning från en separat, annoterad textutgåva.
- Tre recitatörer: Mishary al-Afasy, Mahmoud al-Husary och Muhammad al-Minshawi.
- En ljudfil per vers. Markering och versbyte styrs av AVPlayer, utan uppskattade tidtagare.
- Tafsir al-Muyassar på arabiska, hämtad från AlQuran Cloud.
- Lokala bokmärken, läsposition och uppmuntrande streak med valbart dagligt läsmål.
- Lokal inspelning och återlyssning för övning; ingen röst laddas upp.

**Automatisk tajweedbedömning är ännu inte implementerad.** Inspelning och återlyssning är inte en ersättning för den funktionen. Tarteel-paritet och låg värmeutveckling är mål som ännu inte har verifierats.

Se [kravlistan](KRAV.md) och [aktuell status](STATUS.md) för hela omfattningen och kvarvarande arbete.

## Provköra med bara iPhone

Projektet behöver byggas och signeras i en macOS-miljö, men du behöver inte äga en Mac.
Det finns ett GitHub Actions-flöde för kärntester och ett osignerat simulatorbygge.
Simulatorartefakten kan **inte** installeras på en fysisk iPhone.

Nästa distributionssteg är TestFlight: anslut Apple Developer-medlemskap och App Store Connect,
välj ett eget bundle-ID och konfigurera signering i en betrodd macOS-byggmiljö.
Ingen Apple-inloggning eller signeringsnyckel finns i detta repo.
Developer-medlemskapets årsavgift är en distributionskostnad, inte en månadsavgift för appens användare.
Ingen TestFlight-version har ännu publicerats.

## Bygga på en Mac

1. Öppna `Sakina.xcodeproj` i Xcode 16 eller senare.
2. Välj `Sakina` och en iPhone-simulator. Projektet använder det lokala Swift-paketet `QuranCore` utan externa paketberoenden.
3. För fysisk iPhone: välj ditt team och ett eget bundle-ID under Signing & Capabilities.
4. Kör appen. Mikrofontillstånd begärs först när inspelningen startas.

```sh
swift test
python3 scripts/verify_content.py
xcodebuild -project Sakina.xcodeproj -scheme Sakina \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Efter tillägg av Swift-filer eller resurser: kör `python3 scripts/generate_project.py`
och checka in det uppdaterade projektet. Generatorn kräver bara Python 3.

## Struktur

| Sökväg | Innehåll |
| --- | --- |
| `App/` | SwiftUI-vyer, lokal appstatus, AVPlayer och inspelning |
| `Sources/QuranCore/` | Validerade versreferenser, tajweedparser och kalenderbaserad streak |
| `Tests/QuranCoreTests/` | Tester av kärnlogiken |
| `App/Resources/Quran/` | Lokal källtext, källögonblicksbilder och rättighetsnotiser |
| `scripts/` | Reproducerbar import, innehållskontroll och projektgenerering |
| `.github/workflows/ios.yml` | macOS-tester och simulatorbygge |

## Källor och REA

Källtext, SHA256-kontroller, licensnotiser och skillnaden mellan textutgåvorna beskrivs i
[CONTENT_SOURCES.json](CONTENT_SOURCES.json) och [textnotiserna](App/Resources/Quran/NOTICE.txt).
Tafsir och ljud hämtas över HTTPS; dessa kräver nätanslutning. Ljud är inte paketerat för offlinebruk.
Rättigheter för vald ljuddistribution och annoteringsdata behöver slutföras före offentlig release.

[REA](https://github.com/morluto/rea) har hämtats separat och identifierats som ett analysverktyg.
Det är ingen talmodell och ingår inte som beroende i iPhone-appen. Tarteels app, modell eller servrar
har inte analyserats. Den kommande tajweedmotorn kräver en egen teknisk utvärdering och sakkunnig validering.

## Integritet och verifiering

Läsdata sparas lokalt. Senaste övningsinspelningen kan raderas och tas bort vid nästa appstart.
EveryAyah och AlQuran Cloud ser de nätförfrågningar som krävs för ljud respektive tafsir.
Det finns inga konton, betalflöden, annonser eller analys-SDK:er i appen.

Exakt genomförd verifiering och dess begränsningar finns i [STATUS.md](STATUS.md).
