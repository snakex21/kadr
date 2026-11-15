[English](../README.md) | [Polski](README.pl.md) | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt.md) | [Русский](README.ru.md) | [Українська](README.uk.md) | [Italiano](README.it.md) | [Nederlands](README.nl.md) | [Čeština](README.cs.md) | [Magyar](README.hu.md) | **Română** | [Türkçe](README.tr.md) | [Ελληνικά](README.el.md) | [العربية](README.ar.md) | [עברית](README.he.md) | [हिन्दी](README.hi.md) | [বাংলা](README.bn.md) | [اردو](README.ur.md) | [中文](README.zh.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Bahasa Indonesia](README.id.md) | [Tiếng Việt](README.vi.md) | [ไทย](README.th.md) | [فارسی](README.fa.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [मराठी](README.mr.md)

# Kadr

**Un vizualizator și editor de fotografii pentru Windows rapid, minuscul și portabil — de la Windows XP la Windows 11, într-un singur `Kadr.exe` sub 1 MB.**

Kadr este o aplicație nativă Win32/GDI+ scrisă în [Zig](https://ziglang.org/). Fără program de instalare, fără .NET, fără Electron, fără Node.js: copiază `Kadr.exe` oriunde și rulează-l. Setările sunt păstrate în `Kadr.ini`, lângă program (portabil — nu se scrie nimic în registry sau în AppData).

![Fereastra principală Kadr, temă luminoasă](../docs/screenshots/main-light.png)

## Cuprins

- [Funcționalități](#funcționalități)
- [Capturi de ecran](#capturi-de-ecran)
- [Descărcare / Instalare](#descărcare--instalare)
- [Utilizare](#utilizare)
- [Comenzi rapide de la tastatură](#comenzi-rapide-de-la-tastatură)
- [Editor](#editor-1)
- [Imprimare](#imprimare)
- [Teme](#teme)
- [Setări (Kadr.ini)](#setări-kadrini)
- [Compilare din sursă](#compilare-din-sursă)
- [Rularea testelor](#rularea-testelor)
- [Licență](#licență)
- [Mulțumiri](#mulțumiri)

## Funcționalități

- **Vizualizator** — deschiderea fotografiilor, răsfoirea dosarului (tastele săgeți, anterioara/următoarea), prezentare, ecran complet, zoom fin (potrivire, 1:1, rotița mouse-ului în dreptul cursorului, valori tastate precum `125%`, `37,5%` sau `200×`), deplasarea imaginii, redarea GIF-urilor animate, TIFF și DjVu cu mai multe pagini, orientare EXIF automată.
- **Editor** — decupare cu cadru în timp real și proporții predefinite (liber, 1:1, 4:3, 3:4, 3:2, 2:3, 16:9, A4 portret/peisaj); creion, marker, radieră, linie, săgeată, dreptunghi și text; anulare/refacere; rotire și oglindire; luminozitate, contrast, saturație și alb-negru. Modificările rămân în memorie până când salvezi.
- **Imprimare** — previzualizare în timp real cu dimensiunea hârtiei, orientare, scară (Potrivește (toată imaginea) / Umple (decupează) / Întinde (pagina întreagă) / 100% / procent personalizat / lățime sau înălțime în mm), margini, poziție, color sau tonuri de gri.
- **Instrumente pentru fișiere** — salvare (rotire), salvare ca, export / comprimare (PNG, JPEG, BMP, TIFF, GIF) cu redimensionare și estimarea dimensiunii, copierea imaginii sau a căii în clipboard, redenumire, mutare în Coș sau ștergere definitivă, afișare în dosar, setare ca fundal al desktopului.
- **Formate** — PNG, JPEG/JFIF, BMP/DIB, GIF, TIFF, DjVu, ICO, WMF/EMF, TGA, PCX, PSD (imagine combinată), PBM/PGM/PPM/PNM, QOI.
- **30 de limbi ale interfeței** — limba Windows este detectată automat (cu revenire la engleză) și poate fi schimbată din meniu; aranjare de la dreapta la stânga pentru arabă, ebraică, urdu și persană.
- **Teme** — luminoasă, întunecată sau automată (urmează modul aplicațiilor din Windows și comută din mers).
- **Mic** — un singur `Kadr.exe` sub 1 MB.
- **Windows XP și mai nou** — rulează de la Windows XP SP3 (x86) până la Windows 10/11.

## Capturi de ecran

| Temă luminoasă | Temă întunecată |
|---|---|
| ![Fereastra principală, temă luminoasă](../docs/screenshots/main-light.png) | ![Fereastra principală, temă întunecată](../docs/screenshots/main-dark.png) |

**Editor** — cadru de decupare cu proporția 3:2, creion, marker, săgeată, dreptunghi și text:

![Editor cu cadru de decupare și desene](../docs/screenshots/editor-crop.png)

**Previzualizarea imprimării** în modul *Întinde (pagina întreagă)*:

![Previzualizare imprimare, modul Întinde](../docs/screenshots/print-stretch.png)

**Meniul „Mai multe” (…)** cu submeniul *Temă*:

![Meniul Mai multe cu submeniul Temă](../docs/screenshots/more-menu.png)

## Descărcare / Instalare

1. Descarcă `Kadr.exe` de pe [pagina de versiuni (Releases)](https://github.com/snakex21/kadr/releases) (un `Kadr.exe` gata compilat se află și în rădăcina depozitului).
2. Pune-l în orice dosar în care poți scrie (de exemplu pe un stick USB) și rulează-l. Nu există program de instalare.
3. Pentru fișierele DjVu, păstrează dosarul `deps\djvu\` din depozit lângă `Kadr.exe`.

Pentru a deschide imaginile cu dublu clic, folosește în Windows *Deschidere cu → Alegeți altă aplicație* pe o imagine și selectează `Kadr.exe`.

**Cerințe:** Windows XP SP3 x86 sau mai nou (funcționează și pe Windows 10/11). Nimic altceva.

> Decodorul DjVu este mai vechiul DjVuLibre 3.5.27 — deschide doar fișiere DjVu în care ai încredere (detalii în `THIRD-PARTY.txt`).

## Utilizare

- **Deschide** o imagine cu **Deschide** (Ctrl+O), trăgând un fișier peste fereastră sau transmițându-l în linia de comandă: `Kadr.exe photo.jpg`.
- **Răsfoiește** dosarul cu ← / → sau cu butoanele săgeți; contorul arată poziția (de ex. `1 / 3`). Ține apăsată o tastă săgeată pentru a răsfoi rapid.
- **Mărește** cu rotița mouse-ului (zoom în dreptul cursorului), `+` / `−`, **Potrivește** (Home), **1:1** (`1`) sau tastează o valoare în câmpul de zoom și apasă Enter. Trage imaginea pentru a o deplasa.
- **Rotește** cu R / L. Se rotește vizualizarea; **Salvează** (Ctrl+S) scrie rotirea în fișier.
- **Mai multe (…)** deschide meniul cu toate operațiile pe fișiere, editorul, imprimarea, prezentarea, ecranul complet, ajutorul, *Caută actualizări…*, *Temă* și *Limbă*.
- **Caută actualizări…** doar deschide pagina de versiuni a proiectului pe GitHub în browserul web — Kadr însuși nu se conectează niciodată la internet.

## Comenzi rapide de la tastatură

### Vizualizator

| Comandă rapidă | Acțiune |
|---|---|
| Ctrl+O | Deschide |
| Ctrl+S | Salvează (scrie rotirea în fișierul curent) |
| Ctrl+Shift+S | Salvează ca |
| Ctrl+E | Editare imagine |
| Ctrl+P | Imprimă |
| Ctrl+C | Copiază imaginea |
| Ctrl+Shift+C | Copiază calea |
| F2 | Redenumește |
| Delete | Mută în Coș |
| Shift+Delete | Șterge definitiv |
| ← / → | Imaginea anterioară / următoare din dosar (ține apăsat pentru răsfoire rapidă) |
| Home | Potrivire în fereastră |
| 1 | Dimensiune reală (1:1) |
| + / − (și pe tastatura numerică) | Mărește / Micșorează |
| Rotița mouse-ului | Zoom în dreptul cursorului |
| Tragere cu butonul stâng | Deplasarea imaginii |
| Dublu clic | Ecran complet pornit / oprit |
| R / L | Rotește la dreapta / la stânga |
| Spațiu | Pauză / reluarea animației |
| Page Up / Page Down | Pagina anterioară / următoare (TIFF, DjVu) |
| F5 | Prezentare (la fiecare 4 secunde) |
| F11 | Ecran complet |
| Esc | Ieșire din ecranul complet, oprirea prezentării |
| F1 | Ajutor și scurtături |
| Shift+F10 sau tasta Meniu | Meniul „Mai multe” (și clic dreapta pe imagine) |
| Tab / Shift+Tab, Enter sau Spațiu | Deplasare între butoanele barei de instrumente și apăsarea lor |

### Câmpul de zoom

| Comandă rapidă | Acțiune |
|---|---|
| Enter | Aplică zoomul tastat (`125%`, `37,5%`, `200×` …) |
| Esc | Restabilește valoarea curentă |
| Ctrl+A | Selectează tot |

### Editor

| Comandă rapidă | Acțiune |
|---|---|
| C | Decupare |
| P | Stilou |
| H | Marcator |
| E | Radieră |
| L | Linie |
| A | Săgeată |
| B | Dreptunghi |
| T | Text |
| Ctrl+Z | Anulare |
| Ctrl+Y sau Ctrl+Shift+Z | Refacere |
| Enter (instrumentul Decupare) sau dublu clic | Taie partea întunecată |
| Enter / Esc (în timpul scrierii textului) | Finalizează / anulează textul |
| Esc | Închide editorul fără modificări |

### Previzualizare imprimare

| Comandă rapidă | Acțiune |
|---|---|
| Tragerea imaginii pe foaie | Schimbă poziția acesteia |
| Esc | Închide previzualizarea (anulează o lucrare de imprimare în curs) |

## Editor

Deschide editorul cu **Editare** (Ctrl+E). Toate modificările sunt păstrate în memorie; fișierul original nu este atins până când nu salvezi.

- **Decupare** — un cadru în timp real cu opt mânere; trage cadrul sau mânerele, tastează valorile exacte X / Y / lățime / înălțime în pixeli sau alege o proporție predefinită (liber, pătrat 1:1, 4:3, 3:4, 3:2 (4×6 peisaj), 2:3, 16:9, A4 portret, A4 peisaj). Zona din afara cadrului este întunecată; **Decupează** (Enter) o taie, iar **Toată fotografia** resetează cadrul.
- **Desen** — creion, marker semitransparent, radieră (șterge doar desenele și textul, niciodată fotografia), linie dreaptă, săgeată, dreptunghi și text, cu zece culori și grosime reglabilă.
- **Imagine** — anulare / refacere, rotire cu 90° la stânga sau la dreapta, oglindire orizontală sau verticală, resetare completă.
- **Culoare și lumină** — luminozitate, contrast, saturație și alb-negru.
- **Finalizare** — *Aplică* trimite imaginea editată înapoi în vizualizator, *Salvează ca…* salvează o copie sub un nume nou, *Imprimă…* duce direct la previzualizarea imprimării, *Anulează* (Esc) renunță la modificări.

## Imprimare

**Imprimă** (Ctrl+P) deschide o previzualizare în timp real a foii. Alege imprimanta, hârtia (A3–A6, B4/B5, Letter, Legal, Executive, Tabloid, formate foto 10×15, 13×18, 15×20, 20×25 cm, 4×6, 5×7, 8×10 in, personalizată sau cea a imprimantei), orientarea și color sau tonuri de gri. Orientarea urmează automat imaginea până când o schimbi.

Moduri de scalare:

| Mod | Ce face |
|---|---|
| **Potrivește (toată imaginea)** | Întreaga imagine încape între margini; proporțiile sunt păstrate, pe două laturi poate rămâne spațiu alb. |
| **Umple (decupează)** | Imaginea acoperă toată zona imprimabilă; proporțiile sunt păstrate, iar marginile care depășesc sunt decupate. |
| **Întinde (pagina întreagă)** | Imaginea este întinsă exact pe zona imprimabilă — fără benzi albe, dar proporțiile **nu** sunt păstrate. |
| **100% · Dimensiune reală (96 DPI)** | Un pixel = 1/96 inch. |
| **Procent personalizat** | 0,1–1000 % raportat la 96 DPI (100% = dimensiunea de mai sus). |
| **Lățime / Înălțime (mm)** | Lățime sau înălțime fizică exactă; cealaltă latură urmează proporțiile. |

**Avansat ▸** adaugă dimensiunea personalizată a hârtiei, marginile și o poziție exactă pe foaie (sau trage imaginea în previzualizare; *Centrează* o readuce în mijloc). Linia gri arată limita hardware a imprimantei. Ultimul mod de scalare ales este memorat în `Kadr.ini`.

## Teme

**Mai multe (…) → Temă** oferă **Luminoasă**, **Întunecată** și **Automată** (implicit).

- **Automată** urmează *modul aplicațiilor* din Windows (Setări → Personalizare → Culori, valoarea `AppsUseLightTheme`) și comută din mers când îl schimbi în Windows. Pe sistemele fără această setare (Windows XP, Vista, 7, 8), Automată înseamnă Luminoasă.
- Tema acoperă fereastra principală, bara de instrumente, butoanele și pictogramele, editorul, previzualizarea imprimării și dialogurile proprii ale Kadr. În modul întunecat fundalul imaginii este gri închis, iar pe Windows 10/11 barele de titlu și meniurile pop-up sunt și ele întunecate.
- Câteva elemente native Windows păstrează aspectul sistemului: casetele de mesaj (ajutor, confirmări), dialogurile de sistem Deschide / Salvează / Imprimă și cursoarele glisoarelor.

## Setări (Kadr.ini)

Toate setările sunt păstrate în `Kadr.ini`, lângă `Kadr.exe`. Dacă dosarul este doar în citire, Kadr te anunță că setările nu pot fi salvate.

```ini
[General]
Language=en      ; pl, en, es, fr, de, pt, ru, uk, it, nl, cs, hu, ro, tr, el, ar, he, hi, bn, ur, zh, ja, ko, id, vi, th, fa, ta, te, mr
Theme=auto       ; auto, light or dark
[Print]
Scale=fit        ; fit, fill, stretch, actual, percent, width or height
```

Limba poate fi aleasă și din **Mai multe (…) → Limbă / Language…**; schimbarea se aplică după repornirea Kadr. Tema se aplică imediat.

Limbile interfeței: Polski, English, Español, Français, Deutsch, Português, Русский, Українська, Italiano, Nederlands, Čeština, Magyar, Română, Türkçe, Ελληνικά, العربية, עברית, हिन्दी, বাংলা, اردو, 中文, 日本語, 한국어, Bahasa Indonesia, Tiếng Việt, ไทย, فارسی, தமிழ், తెలుగు, मराठी.

## Compilare din sursă

Cerințe: [Zig 0.11.0](https://ziglang.org/download/0.11.0/zig-windows-x86_64-0.11.0.zip) dezarhivat în `tools\zig-windows-x86_64-0.11.0\` (arhiva nu face parte din depozit; suma sa SHA-256 se află în `THIRD-PARTY.txt`).

```bat
build.cmd
```

Rezultatul este `Kadr.exe` (țintă `x86-windows.xp`, Pentium III, `ReleaseSmall`) cu un antet PE compatibil cu XP. Regenerarea pictogramei: `tools\build_icon.cmd` (Pillow + windres/objcopy).

Kadr se leagă doar de biblioteci care există în Windows XP. Funcțiile mai noi (bare de titlu întunecate, meniuri și controale întunecate) sunt încărcate la rulare cu `LoadLibrary` / `GetProcAddress` și sunt omise pe sistemele mai vechi.

## Rularea testelor

- Suitele de teste se află în subdosarele din `tests\` (`editor-check`, `print-options`, `loader-check`, `image-check`, `codec-check`, `render-check`, `export-check`); fiecare se pornește cu propriul `check.cmd`, care compilează și rulează programe de test în Zig. `tests\editor-check\check.cmd` rulează testele ferestrei principale (inclusiv testele setării temei și ale determinării temei), testele editorului, verificarea acoperirii limbilor și o compilare candidată x86/XP; `tests\print-options\check.cmd` rulează testele de imprimare și de aranjare în pagină.
- Testele unitare ale modulelor individuale se rulează cu `zig test`, de ex. `zig test src\toolbar.zig`, `src\navigation.zig`, `src\image.zig`, `src\zoom.zig`, `src\theme.zig` (cu aceleași opțiuni de țintă și de include ca în `check.cmd`).
- Scripturi ajutătoare Python 3: `python tests\i18n-check\run.py` (selectarea limbii), `python tests\locale_coverage.py` (toate textele interfeței sunt în catalog pentru 30 de limbi), `python tests\audit_xp.py` (verificarea importurilor și a antetului XP pentru `Kadr.exe`), `tests\measure_print.py`, `tests\tooltip_probe.py`, `tests\shot.py`.
- `tests\generate_fixtures.py` creează imagini de test (necesită Pillow); este folosit doar pentru dezvoltare, niciodată de `Kadr.exe`.

## Licență

**GPL-3.0-or-later** — textul complet în [`LICENSE`](../LICENSE).

Componente terțe și licențele lor (DjVuLibre, VC100/GDI+, Zig): [`THIRD-PARTY.txt`](../THIRD-PARTY.txt). Textul GNU GPL v2 pentru DjVuLibre: [`COPYING.txt`](../COPYING.txt).

Aceasta este o traducere; versiunea în engleză ([README.md](../README.md)) este cea de referință.

## Mulțumiri

- Construit cu [Zig](https://ziglang.org/) pe Win32 și GDI+.
- Decodarea DjVu: [DjVuLibre](https://djvu.sourceforge.net/) 3.5.27 (GPL-2.0-or-later).
- Pictogramele interfeței și logoul Kadr sunt grafică originală a proiectului (`src/ui.zig`, `tools/make_icon.py`).
- Imaginile din capturile de ecran sunt imagini sintetice generate pentru acest README.
