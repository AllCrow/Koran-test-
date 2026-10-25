# Första provet på din iPhone

Det här är en personlig testversion, inte en färdig App Store-release.
Installera först enligt [SideStore-guiden](PERSONAL_IPHONE_INSTALL.md).
Sakina kräver **iOS 17 eller senare**. Den osignerade IPA-filen behöver signeras
för din telefon innan den kan öppnas.

## Ett kort första prov

1. Öppna **Mitt** och anteckna versionen längst ned. Notera även iPhone-modell
   och iOS-version. Appen ska inte kräva konto, betalning eller mikrofonåtkomst
   bara för att du läser.
2. Öppna **Koranen**, välj al-Fatiha och läs. Växla tajweedfärger och prova de
   fyra storlekarna under **Läsinställningar → Arabisk textstorlek** (reglageikonen
   uppe till höger). Under **Mitt → Arabisk
   textstorlek** finns samma val och en förhandsvisning från vers 1:1. Stäng
   och öppna appen för att kontrollera att valet sparas. Prova också större
   text i iOS-inställningarna; appens val ska samverka med systemets storlek.
   Kontrollera bokstäver, diakritik och högerjustering. Prova även en lång vers,
   **Mitt → Utseende → Mörkt** och telefonens största textstorlek. Prova även
   **Ljust** och **Följ iPhone**; utseendet ska sparas efter omstart.
   Välj till exempel sura 2, öppna **Läsinställningar → Gå till vers** och skriv **255**.
   Hoppet ska visa 2:255 utan att räknas som en läst vers.
3. Markera en vers som läst och spara ett bokmärke. Stäng och öppna appen igen.
   Markeringen och bokmärket ska finnas kvar. Att bara öppna eller hoppa till en
   vers ska inte ge läskredit; samma vers räknas en gång per dag. På **Idag** ska
   dagens läsning synas i **Senaste sju dagarna**. En prick visar markerad
   läsning och en bock ett uppnått dagsmål.
4. Spela samma vers med var och en av de tre recitatörerna. Kontrollera att
   vald vers och recitatör stämmer med ljudet. Prova paus, nästa vers och sista
   versen i en sura. Prova även 2:255: versens början ska visas när den nya
   recitationen startar. Markeringen avser hela versen, inte tidssatta ord.
5. Under **Mitt → Ljud för offline-lyssning**, ladda ned al-Fatiha för en
   recitatör och vänta tills alla sju verserna är sparade. Stoppa uppspelningen,
   slå på flygplansläge och stäng av Wi-Fi. Öppna appen igen, välj samma
   recitatör och spela 1:1. Prova även en senare vers. Andra recitatörer behöver
   sina egna nedladdningar. Ny tafsir och ljud som inte har sparats behöver
   fortfarande nätverk. Stäng sedan av flygplansläget och återställ Wi-Fi och
   Bluetooth inför de följande proven.
6. Med internet på: öppna **Tafsir** för en vers och kontrollera referensen och
   källan al-Muyassar. Stäng appen, slå på flygplansläge och stäng av Wi-Fi.
   Öppna appen igen och visa samma förklaring; den ska kunna läsas från den
   lokala cachen. Prova sedan tafsir för en vers du aldrig öppnat: den behöver
   nät och ska ge möjlighet att försöka igen. Hela tafsiren finns inte offline
   och äldre cacheposter kan tas bort när utrymmet fylls. Återställ nätet och
   kontrollera återförsök samt snabb stängning och återöppning av tafsirvyn.
7. Under **Öva**, välj en vers, spela in en kort tagning och lyssna tillbaka.
   Mikrofonfrågan ska komma först när du väljer att spela in. Byt lässura och
   återvänd till övningen: tagningens vers och Basmala-val ska vara kvar.
   Kontrollera att inspelningstid och återstående tid visas under tagningen.
   Prova separat att inspelningen avslutas vid gränsen på en minut; den
   synliga räknaren ersätter inte kontroll av den faktiska inspelade längden.
   Inspelning och egen återlyssning ska stanna när appen lämnas eller låses.
   Tagningen är tillfällig och tas bort vid nästa appstart.
8. Prova recitation med låst skärm, ljudkontroller och hörlurar. Koppla ur
   hörlurarna under egen återlyssning; den ska stoppa. Telefonsamtal och
   Bluetooth behöver också provas på den verkliga telefonen. Om iOS ljudtjänst
   startas om ska ingen uppspelning starta av sig själv. Prova att återuppta
   uttryckligen med samma valda vers och recitatör. Anteckna om ett sådant
   systemavbrott inte har inträffat; simulatorns simulerade notiser provar
   inte telefonens verkliga återhämtning.
9. Under **Mitt**, exportera en säkerhetskopia av läsdatan till Filer. Importera
   samma fil och bekräfta tillägget. Bokmärken och läsdagar ska inte dubbleras.
   Filen innehåller läsdata, inte inspelningar, nedladdat ljud eller inställningar.
   Välj själv en lokal mapp eller iCloud Drive; appen synkar inte automatiskt.

Den automatiska tajweedbedömningen är **avstängd i standardbygget**. Lokal
inspelning och återlyssning finns, men motsvarar inte Tarteels betalda analys.
Kvalitetsmålet för den automatiska hjälpen återstår.

## Längre användning och uppdateringar

Prova ett längre läspass och ett separat pass med sparad recitation. Notera
varaktighet, batteriförändring, eventuell värme, hack eller oväntade avbrott.
Jämför med samma ljusstyrka och utan laddning. Sådana observationer hjälper
felsökningen; temperatur och energi behöver även mätas på enheten innan
värmekravet kan godkännas. [Utvecklarens provlista](IOS_VERIFICATION.md) har
ytterligare kontroller.

Förnya både SideStore och Sakina innan den kostnadsfria signeringen löper ut,
normalt efter sju dagar. Följ SideStores aktuella krav på Wi-Fi och LocalDevVPN.
Exportera läsdatan före större uppdateringar och innan du avinstallerar appen.
**Avinstallation raderar appens lokala data.** Spara säkerhetskopian i Filer;
en kopia som bara finns inne i appens lagring skyddar inte vid avinstallation.

Vid problem: anteckna version, telefon/iOS, vilken vers och recitatör som
användes och de steg som ledde till felet. Skicka inga Apple-lösenord,
parkopplingsfiler eller privata inspelningar till ett publikt GitHub-ärende.
