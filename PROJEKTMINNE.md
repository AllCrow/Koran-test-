# Sakina – löpande projektminne

Senast uppdaterat: **2026-11-03**, Europe/Stockholm.
Detta är projektets gemensamma minne mellan chattar. Läs det vid varje
återupptagning och uppdatera det under arbetet och före överlämning.

## Nuläge och nästa uppgift

**Native-appen finns på användarens iPhone och öppnas, men användaren tycker
att den är långt ifrån optimal.** Inga specifika utseende-, navigations- eller
funktionsproblem har ännu beskrivits. Påstå inte att upplevelsen är godkänd
bara för att simulatorproven eller installationen lyckades.

**Beslut 2026-11-03:** användaren accepterade rekommendationen att först göra
en separat, mobilanpassad och klickbar prototyp som går att prova på
Windows-datorn. Arbeta med utseende, navigation och läsupplevelse där; för
sedan stegvis över den godkända riktningen till befintliga SwiftUI-Sakina.
Testa också på verklig iPhone under arbetet, inte enbart vid slutet.

Det är en förlaga och arbetsyta för iPhone-upplevelsen, inte ett beslut att
ersätta appen med Safari/PWA, göra en hybridomskrivning eller bygga en separat
Windowsprodukt. Ingen automatisk konvertering från webb till SwiftUI har
utlovats. Native-källan, historiken och användarens befintliga installation
ska bevaras. Prototypen är **beslutad men ännu inte skapad**.

Användaren vill påbörja prototyparbetet i **en ny chatt inom samma projekt**.
Denna överlämning sparar minnet och startprompten; den implementerar inte
prototypen. Rekommenderad första avgränsning är startsida och koranläsare
med suraval/läsinställningar. Exakta problem, visuell stil, teknikval och
slutlig omfattning återstår att konkretisera med användarens feedback.

## Läsordning och hur minnet hålls aktuellt

1. Läs `AGENTS.md`, detta dokument, `STATUS.md` och `KRAV.md` före meningsfullt arbete.
2. Kontrollera faktisk arbetsgren, `git status`, relevanta filer och aktuella
   bygg-/verktygsresultat. Minnet är en daterad sammanfattning, inte livebevis.
3. Uppdatera avsnittet Nuläge när riktning eller leverans ändras. Lägg en
   daterad loggpost längst ned med ändringar, berörda filer, verifiering,
   öppna frågor och det konkreta nästa steget. Bevara tidigare beslut och
   underkända utfall; markera sådant som ersatts i stället för att radera historik.
4. Håll `STATUS.md` uppdaterad om faktisk verifiering och `KRAV.md` om användarens
   krav/beslut. Länka till detaljerade bevis i stället för att duplicera råloggar.
5. Håll kod, användarens omdöme, tekniska testresultat och fysisk provning
   åtskilda. Skriv vad som verkligen gjorts och vad som endast planeras.
6. Spara aldrig lösenord, Apple-kontouppgifter, koder, parkopplingsfiler,
   signeringsmaterial eller privata inspelningar här eller i Git.

## Projekt, miljö och kontinuitet

| Uppgift | Sparat läge |
| --- | --- |
| Projektmapp | `C:\Users\msaou\Documents\Codex\Koran-test-` |
| Projekt i Codex sidofält | **Koran-test-**, lokal Git-mapp; kontrollerat 2026-11-03 |
| GitHub | [AllCrow/Koran-test-](https://github.com/AllCrow/Koran-test-) |
| Remote | `https://github.com/AllCrow/Koran-test-.git` |
| Synlighet | Public, uttryckligen godkänt av ägaren 2026-10-25; ändra inte på eget initiativ |
| Arbetsgren vid överlämning | `main`; full historik bevarad |
| Main före denna minnesuppdatering | `d90a34aac6f84d44cdacf170ae32fb75e783b10e`, lokalt och på origin |
| Dator | Windows; ingen lokal Xcode/Mac |
| Telefon | Användaren anger iPhone 15 Pro; iloader visar iOS 26.6.1 |
| Byggväg | Molnets Mac/GitHub Actions; personlig installation via Windows/iloader |

Den tidigare chatten flyttades till projektet och heter
**Sakina – fortsätt från läsförbättringarna**. Den nya chatten ska använda
samma projektmapp. Chatthistorik behöver inte vara automatiskt tillgänglig;
filerna här är återupptagningsunderlaget.

## Vad som finns i appen

Sakina är en iPhone-först-app i SwiftUI, iOS 17+. `Package.swift` innehåller
portabla biblioteken QuranCore, QuranData och QuranPractice. Appens vyer och
native-tjänster finns i `App/`; Python-backenden är separat och experimentell.

- Alla 114 suror och 6 236 verser lokalt, exakt korantext, valbar tajweed och
  bundlad Amiri Quran-font med ursprunglig licens.
- Fyra arabiska textstorlekar, Dynamic Type och sparat ljust/mörkt/systemläge.
- Tre recitatörer: al-Afasy, al-Husary och al-Minshawi. En recitations-AVPlayer,
  versbaserat ljud, uttryckliga nedladdningar, lokalt ljudbibliotek,
  uppspelningskontroller och nätpolicy för nya ljudhämtningar.
- Ändlig versrepetition, 1–20 omgångar och 0–15 sekunders paus; övningskö
  med högst 200 referenser. Inget recitationsljud är förpaketerat.
- Tafsir al-Muyassar på arabiska, med källa och begränsad cache för tidigare
  öppnade förklaringar: 64 poster, 4 MiB totalt, 128 KiB per post.
- Bokmärken, läsdagar, läsmål/streak och backup/import av läsdata.
- Sparad läsplats på versnivå efter manuell rullning eller uttryckligt val,
  surasökning, vershopp och offline-sökning i arabisk verstext.
- Källvy och innehållsrapport med lokal förhandsvisning och uttrycklig export.
- Lokal inspelning/återlyssning för övning, upp till en minut, med bevarat
  vers-/Basmala-val och skydd mot oavsiktlig ersättning.
- Diagnostik med lokal, avgränsad förhandsvisning och uttrycklig export.
- Experimentell bedömningsklient och Muaalem-backend, men **analysen är av**
  och **ingen analysserver är konfigurerad**.

Detta beskriver implementerade funktioner, inte godkänd fysisk användarupplevelse.
Ingen svensk översättning, svensk verstextsökning, translittererad verstext
eller återupptagning på en sparad ljudsekund har levererats.

## Senaste native-verifiering och paket

- PR #15 integrerades som `491c7471d8b276a25950eb3441fdb7569108fd9c`,
  komplett Git-träd `58e51d1e8b35c36193107663c625c62128a9c054`.
- [Huvudkörning 74, 41694013456](https://github.com/AllCrow/Koran-test-/actions/runs/41694013456)
  avslutades med alla sex jobb godkända efter riktad omkörning på samma källa.
  Tre simulatorvarianter: 150 hostade och 19 UI-fall per variant; separat
  106 portabla Mac-fall per variant och 57 backendfall. Det är 169 unika
  native-/UI-fall och 507 valda lyckade exekveringar.
- Första försöket är bevarat som underkänt: ett UI-inmatningsfel
  (`Kontrol` begärt, `Kontro` observerat före rapportskapandet) samt ett
  iOS26-jobb som avbröts i runner-kön. Senare pass avgör inte UI-felets rotorsak.
- Färska simulatorbilder granskades visuellt för samtliga tre varianter.
- Paketet är **0.1.0 (74)**, **3 663 212 byte**, iPhoneOS/arm64,
  minsta iOS17 och SDK26.2. Plattform och 239 paketerade källresurser
  kontrollerades oberoende mot Git-källan.
- IPA SHA256: `c6d6fb7d1db07bcd2bea9e9cac212f62a28729937ee6cd02d7606489929ad64a`.
- Ägarutkast **433135893**, tagg **personal-build-74-2**, är draft/prerelease.
  IPA, byggrapport och ursprunglig installationsguide jämfördes mot CI-filerna.
  [Privat testbygge 74](https://github.com/AllCrow/Koran-test-/releases/tag/untagged-227b199ee9eb87aa020d)
  kräver att ägaren är inloggad; det är inte en publicerad apprelease.
- [STATUS.md](STATUS.md) och
  [leveransbeviset](docs/evidence/reading-delivery-74-2026-11-03.json)
  innehåller exakta jobb, hashbindning, resultat och begränsningar.

Dokumentationscommits efter byggkällan ändrar inte appens körbeteende.
Återanvänd inte beviset som ett godkänt bygge av senare ändrad appkod.

## Faktisk telefoninstallation och öppna installationsfrågor

2026-11-03 installerades iTunes och iloader 2.4.1 på Windows. Telefonen
laddade först utan att upptäckas; USB-anslutningen fungerade därefter och
iloader kunde välja telefonen. Användaren hanterade Apple-inloggningen själv.
iloader lyckades installera SideStore och rapporterade att parkopplingsfilen
placerats. Användaren uppgav också att LocalDevVPN installerats; dess aktuella
anslutningsläge är inte oberoende verifierat.

Inloggning inne i SideStore misslyckades med **-80045**, även efter att
Apple-inloggningen i iloader fungerat. Användaren valde uttryckligen att
fortsätta med sitt valda konto efter riskdiskussionen. Be inte om inloggnings-
eller parkopplingshemligheter i chatten. SideStores första förnyelse och
automatiska förnyelse är fortfarande **inte klara/verifierade**.

Vi importerade den hashkontrollerade build74-IPA:n direkt genom **Import IPA**
i det redan inloggade iloader. Verktyget visade **Operation completed** och
grön bock för **Sign & Install App**. Användaren svarade sedan uttryckligen
**Sakina öppnas**. Detta verifierar installationsverktygets lyckade resultat
och användarbekräftad appstart, inte en fullständig fysisk funktionsprovning.
Versionen under Mitt har inte återlästs från telefonen.

Tills SideStore-förnyelse fungerar behövs datorn/iloader för normal förnyelse
före den kostnadsfria sjudagarsgränsen. Installationsdagen är 2026-11-03;
exakt utgångstid har inte lästs ur telefonens provisionering. Ingen påminnelse
är skapad. Behåll samma konto/appidentitet vid uppdatering och exportera
läsdata före större ändringar. Avinstallation är inte ett normalt förnyelsesteg.

Se [installationsguiden](docs/PERSONAL_IPHONE_INSTALL.md) och
[första iPhone-provet](docs/FIRST_IPHONE_TEST.md). Fysisk ljud-/mikrofonprovning,
mobilradio, låsta repetitionspauser, Filer, VoiceOver och energi återstår.

## Källor, historik och viktiga arbetsfiler

| Fil/område | Användning |
| --- | --- |
| [KRAV.md](KRAV.md) | Fullständiga krav och användarbeslut; äldre besked bevaras historiskt |
| [STATUS.md](STATUS.md) | Faktiska resultat, historiska byggen och kvarstående provgränser |
| [README.md](README.md) | Funktionsöversikt och struktur |
| [Läsförbättringarna](docs/READING_IMPROVEMENTS_2026-10-25.md) | Läsplats, arabisk sökning och käll-/rapportflöde |
| [Bibliotek/repetition](docs/LIBRARY_REPETITION_2026-10-25.md) | Bygge63:s funktioner och verifiering |
| [Offline/kvalitet](docs/OFFLINE_QUALITY_2026-10-25.md) | Bygge53:s arbete; historiskt underlag |
| [Tidigare status](docs/STATUS_HISTORY_2026-10-25.md) | Bevarad äldre utveckling |
| [Tidigare stabilitetsarbete](docs/STATUS_HISTORY_PREMIUM_2026-10-25.md) | Bevarade tidigare förbättringar |
| [Innehållsrättigheter](docs/CONTENT_RIGHTS.md) | Skiljer textlicenser från olösta tafsir-/EveryAyah-frågor |
| [Native-provning](docs/IOS_VERIFICATION.md) | Provomfattning och begränsningar |
| [Planerat användarprov](docs/USABILITY_CHECK_2026-10-25.md) | Plan, inte utfört användarprov |
| `docs/evidence/` | Bevarade leverans-, käll-, inferens- och granskningsbevis |
| `App/Views/DesignSystem.swift` | Befintligt visuellt system |
| `App/Views/HomeView.swift`, `ReaderView.swift`, `SettingsView.swift` | Naturliga startpunkter för prototypinventeringen |
| `App/Models/AppStore.swift` | Läsdata och appens tillstånd |
| `App/Services/` | Native-ljud, inspelning, nedladdning och lagring |
| `Sources/` | Portabla kärn-/data-/övningsbibliotek |
| `backend/` | Separat experimentell analys; ingen ny inferens beställd |
| `scripts/generate_project.py` | Genererar Xcode-projektet; kör när App-Swift eller resursgrupper ändras |

Lokala leveransfiler finns under
`C:\Users\msaou\Documents\Codex\2026-11-03\det\outputs\Sakina-build74\`:
`Sakina-iPhone-unsigned.ipa`, `iPhone-build-info.json`, `Installera-pa-iPhone.md`.
Originalpaketet är osignerat; den personliga signeringen skedde i iloader.
Lokala granskningar finns i `work/main74-owner/`, `work/main74-package/` och
`work/pr15-review/`. `work/` är lokalt Git-exkluderad och är ingen molnbackup.
Bevara relevanta bevis; lägg inte ljud, hemligheter eller signeringsmaterial i Git.

## Regler att bära med till prototypen

- Korantext för visning ska bevaras exakt. Använd projektets kontrollerade
  resurser; hitta inte på arabisk korantext. Söknormalisering gäller kopior.
- Navigation, rullning och sökträffar får inte ge läskredit. Skydda sparad
  läsdata, befintliga inspelningar och användarens ljudfiler.
- Håll prototypkod separat, exempelvis i `prototype/`. Teknikval och mapp
  bestäms i nästa chatt; det finns ännu inget prototypprojekt att starta.
- Granska och prova mobilbredd, arabisk höger-till-vänster-text, längre verser,
  stor text och navigation. Skilj fungerande prototypinteraktion från
  illustrerad native-funktion, särskilt ljud, mikrofon, offline och bakgrund.
- En browserprototyp bevisar inte iPhone-prestanda, batteri, temperatur,
  mikrofon, radio eller låsskärmsbeteende. Ingen Tarteel-paritet är fastställd.
- Analys förblir av; inga automatiska inspelningsuppladdningar eller nya
  analystjänster följer av prototypbeslutet. Ingen obligatorisk månadsavgift.
- Arbeta på en separat feature-gren när implementationen börjar. Bevara main,
  äldre godkända paket, underkända körningar och hela källhistoriken.
- Dokumentationsändringar kräver ingen ny native-runda när körbara indata
  är oförändrade; ändrad appkod behöver relevanta faktiska kontroller.

## Löpande logg

### 2026-10-25 till 2026-10-27 – tidigare molnarbete

Native-appens kärna, läsning, ljud, lokal lagring, övning och experimentella
analyskontrakt utvecklades och verifierades i flera omgångar. Bygge46, 51,
53 och 63 har separata bevarade resultat och paketbevis. Läsförbättringarnas
PR-körning73 passerade; PR-artefakterna hade gått ut vid Windowsfortsättningen.
Full historik och exakta omfattningar finns i STATUS och dokumentlänkarna ovan.

### 2026-11-03 – projektåterupptagning, bygge74 och installation

Full Git-historik hämtades till Windows; projektet fick egen plats i sidofältet
och chatten flyttades dit. PR15 granskades, integrerades och följdes av
godkänd huvudkörning74 efter oförändrad omkörning. Paket och tre ägarfiler
kontrollerades oberoende och hämtades lokalt. Commit `87d36b5` sparade
leveransunderlaget. iTunes/iloader installerades, USB började fungera och
SideStore installerades, men SideStore-inloggningen stannade på -80045.
Direktimport i iloader installerade Sakina; användaren bekräftade appstart.
Commit `d90a34a` sparade det faktiska installationsutfallet och dess gränser.

### 2026-11-03 – beslutad prototyp och överlämning till ny chatt

Användaren bedömde appen som långt ifrån optimal och föreslog datorversion
följd av appkonvertering. Vi rekommenderade en mobilanpassad prototyp på
datorn följd av stegvisa förbättringar i befintliga SwiftUI-appen. Användaren
accepterade och bad om en startprompt samt ett löpande .md-minne först.

Denna uppdatering skapar PROJEKTMINNE.md och kopplar läs-/uppdateringsrutinen
till AGENTS.md, README, KRAV och STATUS. Endast dokumentation ändras.
Kontroller: Git-diff och relativa dokumentlänkar, oförändrade körbara indata,
commit och fjärrmatchning. Ingen ny native- eller användarprovning påstås.
Nästa chatt ska läsa minnet, konkretisera användarens största hinder och
bygga den första separata, klickbara mobilprototypen.

## Startprompt för nästa chatt

```text
Fortsätt Sakina i detta projekt. Läs först AGENTS.md, PROJEKTMINNE.md,
STATUS.md och KRAV.md och kontrollera Git-läget.

Vi har beslutat att göra en separat, mobilanpassad och klickbar prototyp
som jag kan prova direkt på Windows-datorn. När designen och flödena är
godkända för vi stegvis över förbättringarna till befintliga SwiftUI-appen
och provar på iPhone under arbetet.

Börja med att granska nuvarande gränssnitt och konkretisera de största
hindren. Be mig kort om min viktigaste feedback medan du inventerar.
Bygg sedan en första körbar prototyp med startsida, koranläsare, suraval
och läsinställningar. Prioritera lugn och genomarbetad form, tydlig
navigation, arabisk läsbarhet och mobilskärm. Visa prototypen så att jag
kan prova flödet. Kontrollera RTL, lång text, stor text och olika bredder.

Behåll native-appen, historiken och korantexten intakta. Prototypen ska
ligga separat och vara en förlaga; ingen PWA-/hybridomskrivning eller
automatisk konvertering är beställd. Redovisa vilka funktioner som faktiskt
fungerar i prototypen och vilka som bara illustreras.

Uppdatera PROJEKTMINNE.md löpande med beslut, ändringar, utförda kontroller,
öppna frågor och nästa steg. Fortsätt till en körbar första version.
```
