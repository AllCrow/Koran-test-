# Privat installation på iPhone

Användaren vill behålla den riktiga iPhone-appen och har uttryckligen valt bort
Safari/PWA. Egen Mac och betalt Developer-medlemskap saknas. Privat bruk kräver
fortfarande signering, men ett vanligt Apple-konto kan användas för gratis
personlig signering med exempelvis SideStore.

**Denna väg kräver tillgång till en lånad Mac eller Windows-dator för
grundinstallationen.** Enbart iPhone räcker inte för detta första steg. Datorn
kan också behövas igen vid utgången parkoppling eller återställning.

## Appfilen

CI-jobbet `personal-iphone-package` bygger `Release` för **iPhoneOS/arm64** och
paketerar `Payload/Sakina.app` till `Sakina-iPhone-unsigned.ipa`. Scriptet
verifierar plattform, arkitektur, koranresurser, font och övningsreferenser samt
att testpaket/provisioneringsprofiler inte följer med. Byggrapporten innehåller
commit, appversion/byggnummer, minsta iOS-version, filstorlek och SHA256.

Efter att hela CI-körningen har godkänts sparar flödet även paketet som ett
**releaseutkast**. Logga in som AllCrow på [repolänkens Releases-sida](https://github.com/AllCrow/Koran-test-/releases)
och öppna det senaste godkända utkastet **Sakina – privat testbygge**. Hämta
`Sakina-iPhone-unsigned.ipa`. Utkastet är synligt för ägaren och behöriga
medarbetare och är inte en publicerad apprelease. Det bevarar nedladdningen
efter att de vanliga CI-artefakternas sjudagarslagring löper ut.

Som reserv finns samma paket i den godkända [Actions-körningen](https://github.com/AllCrow/Koran-test-/actions),
under **Artifacts → Sakina-iPhone-personal-unsigned**. Packa upp ZIP-filen om
GitHub levererar ett arkiv. Behåll IPA-filen och byggrapporten tillsammans.

IPA-filen behöver därefter signeras för användarens telefon. Att trycka på en
osignerad IPA i Filer eller Safari installerar den inte. Den tidigare artefakten
`Sakina-simulator` går inte heller att använda för detta. **Sakina kräver iOS 17
eller senare.** Ingen faktisk installation på fysisk iPhone är ännu godkänd.

## Kostnadsfri personlig signering med SideStore

Följ de aktuella [officiella instruktionerna](https://docs.sidestore.io/).
Den kontrollerade guiden använder **iloader och LocalDevVPN**. Äldre guider med
andra installationsverktyg kan beskriva en annan version av SideStore.

1. Installera LocalDevVPN på iPhone via länken i SideStores officiella guide.
2. På den lånade datorn: installera iloader; Windows-instruktionen kräver även
   iTunes. Anslut iPhone med USB och välj att lita på datorn.
3. Följ iloaders guide med ditt vanliga Apple-konto och installera SideStore
   Stable. Apple-inloggning sker direkt i verktygen. Lösenord och parkopplingsfil
   ska inte skickas till chatten eller läggas i Git.
4. På telefonen: följ guiden för utvecklarprofilen under Allmänt → VPN och
   enhetshantering samt Utvecklarläge under Integritet och säkerhet. Genomför
   de omstarter som guiden begär.
5. Anslut LocalDevVPN och använd Wi-Fi. Öppna SideStore med samma Apple-konto.
   Förnya först SideStore självt genom dess `7 DAYS` under `My Apps`.
6. Hämta Sakinas riktiga iPhone-IPA och importera den i SideStore. SideStore
   signerar den för ditt personliga konto/telefon. Följ den aktuella guiden
   för import och förnyelse.

Gratis signering gäller normalt sju dagar. Förnya innan den löper ut;
bakgrundsförnyelse ska inte behandlas som garanterad. SideStore kräver enligt
guiden Wi-Fi och LocalDevVPN för installation, uppdatering och förnyelse.
Mobilnät ensamt anges som otillräckligt. Tre aktiva personligt signerade appar
tillåts, inklusive SideStore självt. Vanliga App Store-appar räknas inte där.

En parkopplingsfil kan upphöra efter iOS-uppdatering, återställning eller andra
problem. Då kan datorn behövas igen. **Detta är därför inte en garanti om en
enda datoranslutning för all framtid.** Att bygga IPA-filen verifierar inte
SideStore-installation, automatisk förnyelse, mikrofon eller ljud på din enhet.

## Källor och verifieringsläge

Officiella instruktioner kontrollerade 2026-10-25:

- [Förberedelser](https://github.com/SideStore/SideStore-Docs/blob/main/docs/installation/prerequisites.mdx)
- [Installation](https://github.com/SideStore/SideStore-Docs/blob/main/docs/installation/install.mdx)
- [FAQ om egna appar, signering och förnyelse](https://github.com/SideStore/SideStore-Docs/blob/main/docs/faq.mdx)
- [Parkopplingsfilens begränsningar](https://github.com/SideStore/SideStore-Docs/blob/main/docs/advanced/pairing-file.mdx)
- [Apples kostnadsfria Personal Team och sjudagarsgränser](https://developer.apple.com/support/compare-memberships/)

När en lånad dator inte är möjlig återstår en distributör med ett befintligt
Apple Developer-konto eller att projektet ansluter ett sådant medlemskap.
En TestFlight-testare behöver inget eget betalt Developer-konto. Det finns ännu
ingen signerande distributör ansluten till projektet.

Efter installationen: följ [det korta första iPhone-provet](https://github.com/AllCrow/Koran-test-/blob/main/docs/FIRST_IPHONE_TEST.md).
Exportera läsdata i **Mitt** före avinstallation eller större uppdateringar.
Avinstallation raderar appens lokala data; exporten innehåller inte röst eller
nedladdat ljud. Installera uppdateringar med samma personliga appidentitet när
verktyget erbjuder det, och bevara en separat läskopia även då.
