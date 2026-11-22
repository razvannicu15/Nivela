# Nivela

Nivelă cu bulă pentru **Android**, în stil Material 3, **fără reclame, fără cont și cu toate funcțiile gratuite**. Română + English, temă luminoasă / întunecată. by norAz

## Funcții

- **Nivel**: telefonul pe o muchie, pentru orizontală. Linia orizontului rămâne dreaptă, iar bula e într-o fiolă. Muchia se alege automat sau fix, iar textul se rotește după telefon.
- **Plumb**: muchia telefonului pe perete sau pe toc, pentru verticală. Arată firul cu plumb și scala.
- **Plan**: telefonul culcat, cu bula pe ambele axe, X/Y și înclinarea totală.
- **Cameră**: ghidaje peste imaginea camerei: orizont, grilă 3×3 sau 4×4, linii verticale, țintă și vizibilitate reglabilă.
- Unități: grade, %, mm/m, in/ft. Zecimalele se pot alege: 0, 1 sau 2.
- Alertă vizuală cu toleranță și culoare reglabile, plus vibrație și sunet. Opțional alertă și la multipli de 45°.
- **Blocare** cu apăsare lungă sau cu butonul, plus **blocare automată**: când telefonul stă nemișcat sau după 3, 5 sau 10 s.
- **Măsurare relativă** (Zero).
- **Calibrare ghidată** în 6 poziții, fiecare măsurată de 2 ori rotit cu 180°, deci nu ai nevoie de o suprafață perfect dreaptă. **3 profile**, de exemplu cu husă și fără. Avertizează dacă poziția folosită nu e calibrată sau dacă senzorul e imprecis.
- **Măsurători salvate nelimitat**, cu notă, copiere și distribuire.
- Culoare temă la alegere, ecran mereu aprins, netezirea citirii.

## Build

Build-ul se face automat în **GitHub Actions** la fiecare push pe `main`. APK-ul apare în release-ul `latest`, iar capturile de ecran în release-ul `screens`.

Pe PC: rulează **`Nivela.bat`** (de oriunde, chiar și de pe Desktop):

- `[1]` descarcă ultimul APK în `D:\Apps\Nivela\dist`
- `[2]` îl instalează pe telefon prin cablu USB (descarcă singur `adb` prima dată)
- `[4]` / `[5]` actualizează codul / build local, doar dacă ai Flutter

Toate build-urile sunt semnate cu aceeași cheie (`tool/debug.keystore`), așa că un APK nou se instalează peste cel vechi.
