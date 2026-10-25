# Innehåll, ljudkällor och kvarvarande rättighetsglapp

Kontrollerat **2026-10-25** mot publika originalkällor och Sakinas konfiguration.
Detta underlag skiljer verifierade källuppgifter från ännu obesvarade frågor.
Det godkänner inte alla innehållsrättigheter eller den religiösa kvaliteten.
Ingen rättighetshavare har kontaktats i denna kontroll.

Arbetet är framtaget på `codex/traceable-recitation-sources` från
`67461e0d2c075acc44be8f20db399566fe1a2670`. Appkod, koranresurser,
bygginställningar, native-prov och arbetsflöden ändras inte. Det nya
manuella Python-verktyget har körts mot de verkliga källorna; rapportens
skripthash matchar den levererade filen. JSON-/källhashar, dokumentlänkar,
Python-kompilering, `git diff --check` och den ordagranna innehållskontrollen
passerar. Inget nytt Apple-prov påstås för denna källgranskning.

## Exakt innehåll och villkor

| Innehåll i Sakina | Faktiskt underlag | Åtgärd och återstående glapp |
| --- | --- | --- |
| Offlinekorantext, `quran-uthmani` | [AlQuran Cloud §II](https://alquran.cloud/terms-and-conditions) tillåter återgivning, inbäddning, lagring och visning av arabisk korantext. [Tanzils textlicens](https://tanzil.net/docs/text_license) anger CC BY 3.0 och uttryckligen ordagrann kopiering, ingen textändring, källänk och bevarad notis. | Befintligt [hashmanifest](../CONTENT_SOURCES.json), originalögonblicksbilder, varje kapitels notis och appens källvy bevaras. `verify_content.py` kontrollerar samtliga 6 236 versers båda texter mot de sparade utgåvorna. Detta är mekanisk kontroll, ingen sakkunnig certifiering. |
| Tajweed, `quran-tajweed` | Hämtad från samma tjänst; separat annoterad utgåva med egna teckenpositioner. AlQuran Clouds textvillkor och [notationsguide](https://alquran.cloud/tajweed-guide) är namngivna i befintlig notis. | Ingen fristående annotationslicens hittades i de granskade villkoren. Behåll källtrogen återgivning och tydlig attribution; slutlig rättighetskontroll är fortfarande öppen. Färgregler är inte automatiskt bevis för korrekt uttalsbedömning. |
| Al-Muyassar på arabiska | API:ts verkliga editionsmetadata anger `ar.muyassar`, `ar/text/tafsir`, namn `تفسير المیسر` och `englishName: King Fahad Quran Complex`. | Appen namnger al-Muyassar och skiljer kommentaren från korantexten. Ingen editionsspecifik lagrings-/vidaredistributionslicens identifierades i den granskade metadata-/villkorsmängden. §II gäller korantext; §IV om översättningar räcker inte ensam som tafsirtillstånd. Bekräfta villkor för den faktiska utgåvan, inklusive den begränsade lokala cachen, före offentlig distribution. |
| Tre recitatörer via EveryAyah | Källans egen katalog matchar appens tre mappar, se nedan. Dess nedladdningssidor och MD5-listor är tillgängliga. | Inget uttryckligt ljudlicenstillstånd hittades på de fem granskade EveryAyah-sidorna. Detta betyder inte att inget tillstånd finns någon annanstans. Bekräfta strömning, lokal användarnedladdning och eventuell distribution av just dessa inspelningar/bitrater; offentliga länkar och checksummor ger inte den rätten. |
| Amiri Quran | Paketerad font med [OFL 1.1](../App/Resources/Fonts/OFL.txt) och [källidentitet](../App/Resources/Fonts/SOURCE.md). | Bevara fontens licens och attribution i paketet. Ingen fontändring gjordes här. |
| Experimentell Muaalem | Fixerade modell-/paketartefakter och deras faktiska licenser beskrivs i [modellunderlaget](RECITATION_RESEARCH.md). | Ändra inte till senare Git-/modellrevision med antagandet att licensen är oförändrad. Standardanalys förblir avstängd. Forskningslicens eller fungerande inferens uppfyller inte kvalitetsmålet. |

AlQuran Clouds §IV säger att **deras** recitationer får strömmas, bäddas in
och hämtas för personligt/utbildande bruk. Sakina använder **EveryAyahs**
adresser. Tjänstens tillstånd har därför inte överförts till Sakinas andra
ljudkälla, och ingen källmigration har gjorts. Båda tjänsternas tillgänglighet
kan ändras. Inga licensbetalningar eller nya tjänster har beställts.

[Käll-URL:er, sidornas SHA256 och korta kontrollerade citat](evidence/content-terms-audit-2026-10-25.json)
gör granskningen spårbar. Sidornas dynamiska HTML kan ändras; ett senare
hashbyte kräver ny granskning och betyder inte automatiskt ändrade villkor.
En bekräftelse från rättighetshavaren behöver ange utgåva/inspelning,
användningssätt, villkor och datum innan punkten markeras avslutad.

## Verkliga ljudfiler: hämtning och avkodning

Det manuella [kontrollverktyget](../scripts/audit_recitation_sources.py)
läser appens aktuella recitatörsmappar och namngivningsregel, jämför
källans versantal med det paketerade indexet och läser varje mapps filkatalog.
Ingen komplett ljudkorpus hämtas. Resultatet 2026-10-25:

| Val i appen | Källans katalogetikett / mapp | Kanoniska filnamn listade | Extra numrerade filer |
| --- | --- | --- | --- |
| Mishary al-Afasy | `Alafasy` / `Alafasy_128kbps` | 6 236 av 6 236 | 112 |
| Mahmoud al-Husary | `Husary` / `Husary_128kbps` | 6 236 av 6 236 | 1 |
| Muhammad al-Minshawi | `Minshawy Murattal` / `Minshawy_Murattal_128kbps` | 6 236 av 6 236 | 113 |

De extra filnamnen har versnummer `000` och används inte som koranverser
av appens validerade `AyahReference`. Katalogtäckningen visar filnamn,
inte att alla filer finns kvar, kan avkodas eller innehåller rätt recitation.

Fem hela versfiler per recitatör hämtades: **1:1, 2:255, 9:1, 112:2 och
114:6**. Det omfattar lång vers, början utan Basmala i texten, ett tidigare
oavgjort modellfall och Koranens sista vers. Samtliga **15 HTTP 200-svar**
var `audio/mpeg` och hade rätt total byteantal mot `Content-Length`.
De sammanlagt **4 482 300 byten** matchade källans respektive MD5-lista.
MD5 används för konsistens mot utgivaren; varje fil och PCM-resultat har
dessutom en separat SHA256. Ingen MD5-lista behandlas som äkthetssignatur.

Alla 15 filer avkodades i sin helhet med **ffmpeg `-xerror`**, exitkod 0,
till 16 kHz mono PCM utan enbart digital tystnad. Totalt blev det
**275,8095 sekunder** avkodad PCM. Hela svar, källans etiketter, längder,
HTTP-metadata, fil-/PCM-hashar, verktygsversion och kontrollskriptets hash
finns i [den maskinläsbara rapporten](evidence/recitation-source-audit-2026-10-25.json).
Inga MP3-/PCM-filer eller mänskliga röster lades i Git. Verktygets
tillfälliga ljudfiler raderas när respektive prov är klart.

Kör manuellt från repots rot med Python 3.10+, ffmpeg och ffprobe:

```sh
python3 scripts/audit_recitation_sources.py --output /tmp/sakina-recitation-audit.json
```

Verktyget kontaktar publika källor genom miljöns vanliga HTTPS-/proxyväg
med certifikatkontroll på. Det avvisar byte till HTTP eller annan origin,
begränsar svarsstorlekar och lagrar endast metadata i rapporten. Det
anropas inte av appen eller normal CI och tar inte emot egna inspelningar.
Nätfel och ändrade källfiler kan göra en senare manuell kontroll röd.

**Detta är Linux-/ffmpeg-bevis.** Det är inte prov av URLSession/ATS,
AVPlayer, lokalt filval i appen, synkroniserad markering eller offlineväxling
för just dessa imaminspelningar på iOS. De tidigare native-proven använder
genererad ton och loopback; de räknas inte om till nya externa ljudprov.
Inga ordtider, fysisk ljudrutt, energi-/värmemätningar eller nya
modellanrop ingår. 112:2 har en hel avkodningsbar fil, men den tidigare
tajweedindikationen för al-Afasy är fortfarande inte sakkunnigt avgjord.

Ett senare [separat native-iOS-prov](LIVE_RECITATION_AUDIT.md) har nu
passerat: tolv riktiga al-Ikhlas-filer hämtades och avkodades, och exakt
hashkontrollerad 112:2 spelades lokalt till native-EOF för alla tre
recitatörer på iPhone16e/iOS26.2-simulator. Detta tillför iOS-bevis för den
begränsade källmängden; det gör inte Linux-provet till ett iPhone-prov.
Nästa acceptanssteg är fysiskt prov enligt
[telefonprotokollet](FIRST_IPHONE_TEST.md), samt
kunnig kontroll av recitatör, versinnehåll, Basmala och klippgränser.
Samla rättighetsbekräftelser separat; en tekniskt fungerande ljudfil
avslutar inte den kontrollen. Inga Tarteel- eller tajweedkvalitetsanspråk
ändras av denna leverans.

## Förberett underlag för det oavgjorda 112:2-fallet

Ett [granskningspaket utan ljud](evidence/recitation-review-112-2.json)
binder den befintliga modellrapportens exakta klippindex, M4A-uppladdningshash,
motor-/modellrevision, antaganden och `normal/delete`-indikation till den
exakta övningsutgåvan. Referenstexten har jämförts ordagrant. Indikationen
gäller ett möjligt initialt fonem; den är inte klassificerad som ett
sakkunnigt tajweedfel.

Den senare hela MP3:n har samma käll-URL och en egen verifierad hash, men
den gamla rapporten sparade bara den konverterade insignalens hash. Samma
URL bevisar därför inte byteidentitet mellan körningarna. För att bedöma
det gamla resultatet behöver dess exakta lokala insignal återfinnas och
hashmatchas, eller ett nytt prov märkas som ett nytt fall. Paketet anger
frågorna om ljudstart, wasl/waqf, klippgräns, tillåten variation och
referens-/fonemkoppling för två oberoende sakkunniga. Mänsklig bedömning,
noggrannhetsmått och Tarteel-jämförelse står uttryckligen som saknade.
Ingen modelltröskel, återkoppling eller standardinställning har ändrats.
