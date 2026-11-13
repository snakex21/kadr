[English](../README.md) | [Polski](README.pl.md) | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt.md) | [Русский](README.ru.md) | [Українська](README.uk.md) | [Italiano](README.it.md) | [Nederlands](README.nl.md) | [Čeština](README.cs.md) | **Magyar** | [Română](README.ro.md) | [Türkçe](README.tr.md) | [Ελληνικά](README.el.md) | [العربية](README.ar.md) | [עברית](README.he.md) | [हिन्दी](README.hi.md) | [বাংলা](README.bn.md) | [اردو](README.ur.md) | [中文](README.zh.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Bahasa Indonesia](README.id.md) | [Tiếng Việt](README.vi.md) | [ไทย](README.th.md) | [فارسی](README.fa.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [मराठी](README.mr.md)

# Kadr

**Gyors, apró, hordozható képnézegető és -szerkesztő Windowsra — Windows XP-től Windows 11-ig, egyetlen, 1 MB-nál kisebb `Kadr.exe` fájlban.**

A Kadr natív Win32/GDI+ alkalmazás, [Zig](https://ziglang.org/) nyelven írva. Nincs telepítő, nincs .NET, nincs Electron, nincs Node.js: másolja a `Kadr.exe` fájlt bárhová, és indítsa el. A beállítások a program mellett, a `Kadr.ini` fájlban tárolódnak (hordozható — semmi sem kerül a rendszerleíró adatbázisba vagy az AppData mappába).

![A Kadr főablaka, világos téma](../docs/screenshots/main-light.png)

## Tartalomjegyzék

- [Funkciók](#funkciók)
- [Képernyőképek](#képernyőképek)
- [Letöltés / telepítés](#letöltés--telepítés)
- [Használat](#használat)
- [Billentyűparancsok](#billentyűparancsok)
- [Szerkesztő](#szerkesztő-1)
- [Nyomtatás](#nyomtatás)
- [Témák](#témák)
- [Beállítások (Kadr.ini)](#beállítások-kadrini)
- [Fordítás forrásból](#fordítás-forrásból)
- [Tesztek futtatása](#tesztek-futtatása)
- [Licenc](#licenc)
- [Köszönetnyilvánítás](#köszönetnyilvánítás)

## Funkciók

- **Képnézegető** — fényképek megnyitása, lapozás a mappában (nyílbillentyűk, előző/következő), diavetítés, teljes képernyő, egyenletes nagyítás (igazítás, 1:1, egérgörgő a kurzor helyén, beírt értékek, például `125%`, `37,5%` vagy `200×`), a kép mozgatása, animált GIF-ek lejátszása, többoldalas TIFF és DjVu, automatikus EXIF-tájolás.
- **Szerkesztő** — körülvágás élő kerettel és előre beállított képarányokkal (szabad, 1:1, 4:3, 3:4, 3:2, 2:3, 16:9, A4 álló/fekvő); toll, kiemelő, radír, vonal, nyíl, téglalap és szöveg; visszavonás/újra; forgatás és tükrözés; fényerő, kontraszt, telítettség és fekete-fehér. A módosítások a mentésig a memóriában maradnak.
- **Nyomtatás** — élő nyomtatási kép papírmérettel, tájolással, méretezéssel (igazítás / kitöltés (körülvágással) / nyújtás (teljes oldalra) / 100% / egyéni % / szélesség vagy magasság mm-ben), margókkal, pozícióval, színes vagy szürkeárnyalatos nyomtatással.
- **Fájlműveletek** — mentés (forgatás), mentés másként, exportálás / tömörítés (PNG, JPEG, BMP, TIFF, GIF) átméretezéssel és méretbecsléssel, a kép vagy az elérési út vágólapra másolása, átnevezés, Lomtárba helyezés vagy végleges törlés, megjelenítés a mappában, beállítás asztali háttérképként.
- **Formátumok** — PNG, JPEG/JFIF, BMP/DIB, GIF, TIFF, DjVu, ICO, WMF/EMF, TGA, PCX, PSD (egyesített kép), PBM/PGM/PPM/PNM, QOI.
- **30 felületi nyelv** — a Windows nyelvét automatikusan felismeri (ennek hiányában angol), és a menüből módosítható; jobbról balra írt elrendezés arab, héber, urdu és perzsa nyelvhez.
- **Témák** — világos, sötét vagy automatikus (követi a Windows alkalmazásmódját, és azonnal vált).
- **Kicsi** — egyetlen `Kadr.exe`, amely kisebb 1 MB-nál.
- **Windows XP és újabb** — Windows XP SP3 (x86) rendszertől Windows 10/11-ig fut.

## Képernyőképek

| Világos téma | Sötét téma |
|---|---|
| ![Főablak, világos téma](../docs/screenshots/main-light.png) | ![Főablak, sötét téma](../docs/screenshots/main-dark.png) |

**Szerkesztő** — vágókeret 3:2 képaránnyal, toll, kiemelő, nyíl, téglalap és szöveg:

![Szerkesztő vágókerettel és rajzokkal](../docs/screenshots/editor-crop.png)

**Nyomtatási kép** *Stretch (whole page)* (nyújtás a teljes oldalra) módban:

![Nyomtatási kép, Stretch mód](../docs/screenshots/print-stretch.png)

**A „Továbbiak” (…) menü** a *Téma* almenüvel:

![A Továbbiak menü a Téma almenüvel](../docs/screenshots/more-menu.png)

## Letöltés / telepítés

1. Töltse le a `Kadr.exe` fájlt a [kiadások oldaláról](https://github.com/snakex21/kadr/releases) (egy kész `Kadr.exe` a tároló gyökerében is megtalálható).
2. Tegye bármely mappába, amelybe írhat (például egy USB-meghajtóra), és indítsa el. Telepítő nincs.
3. DjVu-fájlokhoz tartsa a tároló `deps\djvu\` mappáját a `Kadr.exe` mellett.

Ha dupla kattintással szeretne képeket megnyitni, egy képen válassza a Windows *Társítás → Másik alkalmazás választása* parancsát, és jelölje ki a `Kadr.exe` fájlt.

**Rendszerkövetelmények:** Windows XP SP3 x86 vagy újabb (a Windows 10/11 is megfelel). Más nem kell.

> A DjVu-dekóder a régebbi DjVuLibre 3.5.27 — csak megbízható DjVu-fájlokat nyisson meg (részletek: `THIRD-PARTY.txt`).

## Használat

- **Nyisson meg** egy képet a **Megnyitás** gombbal (Ctrl+O), egy fájl ablakra húzásával, vagy parancssorból: `Kadr.exe photo.jpg`.
- **Lapozzon** a mappában a ← / → billentyűkkel vagy a nyílgombokkal; a számláló mutatja a pozíciót (pl. `1 / 3`). Gyors lapozáshoz tartsa lenyomva a nyílbillentyűt.
- **Nagyítson** az egérgörgővel (a kurzor helyén nagyít), a `+` / `−` billentyűkkel, az **Igazítás** (Home) vagy az **1:1** (`1`) gombbal, vagy írjon be egy értéket a nagyítási mezőbe, és nyomja meg az Enter billentyűt. A kép mozgatásához húzza az egérrel.
- **Forgasson** az R / L billentyűkkel. Csak a nézet fordul el; a **Mentés** (Ctrl+S) írja bele a forgatást a fájlba.
- A **Továbbiak (…)** megnyitja a menüt az összes fájlművelettel, a szerkesztővel, a nyomtatással, a diavetítéssel, a teljes képernyővel, a súgóval, valamint a *Frissítések keresése…*, a *Téma* és a *Nyelv* menüponttal.
- A **Frissítések keresése…** csupán megnyitja a projekt GitHub-kiadásainak oldalát a böngészőben — maga a Kadr soha nem csatlakozik az internethez.

## Billentyűparancsok

### Képnézegető

| Billentyű | Művelet |
|---|---|
| Ctrl+O | Megnyitás |
| Ctrl+S | Mentés (a forgatást az aktuális fájlba írja) |
| Ctrl+Shift+S | Mentés másként |
| Ctrl+E | Kép szerkesztése |
| Ctrl+P | Nyomtatás |
| Ctrl+C | Kép másolása |
| Ctrl+Shift+C | Elérési út másolása |
| F2 | Átnevezés |
| Delete | Áthelyezés a Lomtárba |
| Shift+Delete | Végleges törlés |
| ← / → | Előző / következő kép a mappában (gyors lapozáshoz tartsa lenyomva) |
| Home | Igazítás az ablakhoz |
| 1 | Tényleges méret (1:1) |
| + / − (a numerikus billentyűzeten is) | Nagyítás / kicsinyítés |
| Egérgörgő | Nagyítás a kurzor helyén |
| Húzás bal gombbal | A kép mozgatása |
| Dupla kattintás | Teljes képernyő be / ki |
| R / L | Forgatás jobbra / balra |
| Space | Animáció szüneteltetése / folytatása |
| Page Up / Page Down | Előző / következő oldal (TIFF, DjVu) |
| F5 | Diavetítés (4 másodpercenként) |
| F11 | Teljes képernyő |
| Esc | Kilépés a teljes képernyőből, a diavetítés leállítása |
| F1 | Súgó és gyorsbillentyűk |
| Shift+F10 vagy a Menü billentyű | „Továbbiak” menü (jobb kattintás a képen is) |
| Tab / Shift+Tab, Enter vagy Space | Mozgás az eszköztár gombjai között és azok megnyomása |

### Nagyítási mező

| Billentyű | Művelet |
|---|---|
| Enter | A beírt nagyítás alkalmazása (`125%`, `37,5%`, `200×` …) |
| Esc | Az aktuális érték visszaállítása |
| Ctrl+A | Az összes kijelölése |

### Szerkesztő

| Billentyű | Művelet |
|---|---|
| C | Vágás |
| P | Pen (toll) |
| H | Highlighter (kiemelő) |
| E | Eraser (radír) |
| L | Line (vonal) |
| A | Arrow (nyíl) |
| B | Rectangle (téglalap) |
| T | Text (szöveg) |
| Ctrl+Z | Undo (visszavonás) |
| Ctrl+Y vagy Ctrl+Shift+Z | Redo (újra) |
| Enter (Vágás eszköz) vagy dupla kattintás | A sötétített rész levágása |
| Enter / Esc (szövegírás közben) | A szöveg befejezése / elvetése |
| Esc | A szerkesztő bezárása módosítás nélkül |

### Nyomtatási kép

| Billentyű | Művelet |
|---|---|
| A kép húzása a lapon | A kép helyének módosítása |
| Esc | A nyomtatási kép bezárása (a folyamatban lévő nyomtatást megszakítja) |

## Szerkesztő

A szerkesztőt az **Edit** („Szerkesztés”, Ctrl+E) gomb nyitja meg. Minden módosítás a memóriában marad; az eredeti fájl a mentésig érintetlen.

- **Körülvágás** — élő keret nyolc fogóponttal; húzza a keretet vagy a fogópontjait, adja meg pontosan az X / Y / szélesség / magasság értékét pixelben, vagy válasszon előre beállított képarányt (szabad, négyzet 1:1, 4:3, 3:4, 3:2 (4×6 fekvő), 2:3, 16:9, A4 álló, A4 fekvő). A kereten kívüli terület elsötétül; a **Körülvágás** (Enter) levágja, a **Whole photo** (teljes kép) pedig visszaállítja a keretet.
- **Rajzolás** — toll, áttetsző kiemelő, radír (csak a rajzokat és a szöveget törli, a fényképet soha), egyenes vonal, nyíl, téglalap és szöveg, tíz színnel és állítható vastagsággal.
- **Kép** — visszavonás / újra, forgatás 90°-kal balra vagy jobbra, vízszintes vagy függőleges tükrözés, minden visszaállítása.
- **Szín és fény** — fényerő, kontraszt, telítettség és fekete-fehér.
- **Befejezés** — az *Alkalmazás* visszaviszi a szerkesztett képet a nézegetőbe, a *Save as…* új néven ment egy másolatot, a *Print…* egyenesen a nyomtatási képre ugrik, a *Mégse* (Esc) elveti a módosításokat.

## Nyomtatás

A **Nyomtatás** (Ctrl+P) a lap élő előnézetét nyitja meg. Válassza ki a nyomtatót, a papírt (A3–A6, B4/B5, Letter, Legal, Executive, Tabloid, 10×15, 13×18, 15×20, 20×25 cm-es, illetve 4×6, 5×7, 8×10 in-es fotóméretek, egyéni vagy a nyomtató saját mérete), a tájolást, valamint a színes vagy szürkeárnyalatos nyomtatást. A tájolás automatikusan követi a képet, amíg Ön meg nem változtatja.

Méretezési módok:

| Mód | Mit csinál |
|---|---|
| **Igazítás** | A teljes kép a margókon belül fér el; a képarány megmarad, két oldalon fehér sáv maradhat. |
| **Kitöltés / körülvágás** | A kép a teljes nyomtatható területet kitölti; a képarány megmarad, a kilógó széleket levágja. |
| **Stretch (whole page)** (nyújtás a teljes oldalra) | A kép pontosan a nyomtatható területre nyúlik — fehér sávok nélkül, de a képarány **nem** marad meg. |
| **100% · Tényleges méret (96 DPI)** | Egy pixel = 1/96 hüvelyk. |
| **Egyéni százalék** | 0,1–1000% a 96 DPI-hez viszonyítva (100% = a fenti méret). |
| **Szélesség (mm)** / **Magasság (mm)** | Pontos fizikai szélesség vagy magasság; a másik oldal a képarányból adódik. |

A **Speciális ▸** egyéni papírméretet, margókat és pontos lapon belüli pozíciót tesz elérhetővé (vagy húzza a képet az előnézetben; a *Középre* visszateszi a közepére). A szürke vonal a nyomtató hardveres határát mutatja. A legutóbb választott méretezési módot a `Kadr.ini` megjegyzi.

## Témák

A **Továbbiak (…) → Téma** menüben **Világos**, **Sötét** és **Automatikus** (alapértelmezett) választható.

- Az **Automatikus** a Windows *alkalmazásmódját* követi (Beállítások → Személyre szabás → Színek, az `AppsUseLightTheme` érték), és azonnal vált, ha Ön módosítja a Windowsban. Az ezt a beállítást nem ismerő rendszereken (Windows XP, Vista, 7, 8) az Automatikus a Világos témát jelenti.
- A téma kiterjed a főablakra, az eszköztárra, a gombokra és ikonokra, a szerkesztőre, a nyomtatási képre és a Kadr saját párbeszédpaneleire. Sötét módban a kép háttere sötétszürke, Windows 10/11 alatt pedig a címsorok és a helyi menük is sötétek.
- Néhány natív Windows-elem megtartja a rendszer megjelenését: az üzenetablakok (súgó, megerősítések), a Megnyitás / Mentés / Nyomtatás rendszer-párbeszédpanelek és a csúszkák fogantyúi.

## Beállítások (Kadr.ini)

Minden beállítás a `Kadr.exe` melletti `Kadr.ini` fájlban tárolódik. Ha a mappa írásvédett, a Kadr jelzi, hogy a beállításokat nem lehet menteni.

```ini
[General]
Language=en      ; pl, en, es, fr, de, pt, ru, uk, it, nl, cs, hu, ro, tr, el, ar, he, hi, bn, ur, zh, ja, ko, id, vi, th, fa, ta, te, mr
Theme=auto       ; auto, light or dark
[Print]
Scale=fit        ; fit, fill, stretch, actual, percent, width or height
```

A nyelv a **Továbbiak (…) → Nyelv** menüpontban is kiválasztható; a változás a Kadr újraindítása után lép életbe. A téma azonnal érvényesül.

Felületi nyelvek: Polski, English, Español, Français, Deutsch, Português, Русский, Українська, Italiano, Nederlands, Čeština, Magyar, Română, Türkçe, Ελληνικά, العربية, עברית, हिन्दी, বাংলা, اردو, 中文, 日本語, 한국어, Bahasa Indonesia, Tiếng Việt, ไทย, فارسی, தமிழ், తెలుగు, मराठी.

## Fordítás forrásból

Követelmények: a [Zig 0.11.0](https://ziglang.org/download/0.11.0/zig-windows-x86_64-0.11.0.zip) kicsomagolva a `tools\zig-windows-x86_64-0.11.0\` mappába (az archívum nem része a tárolónak; SHA-256 ellenőrzőösszege a `THIRD-PARTY.txt` fájlban található).

```bat
build.cmd
```

Az eredmény a `Kadr.exe` (cél: `x86-windows.xp`, Pentium III, `ReleaseSmall`) XP-kompatibilis PE-fejléccel. Az ikon újragenerálása: `tools\build_icon.cmd` (Pillow + windres/objcopy).

A Kadr csak olyan könyvtárakhoz linkel, amelyek Windows XP-n is megvannak. Az újabb funkciókat (sötét címsorok, sötét menük és vezérlők) futásidőben tölti be a `LoadLibrary` / `GetProcAddress` segítségével, régebbi rendszereken pedig kihagyja őket.

## Tesztek futtatása

- A tesztkészletek a `tests\` almappáiban találhatók (`editor-check`, `print-options`, `loader-check`, `image-check`, `codec-check`, `render-check`, `export-check`); mindegyik a saját `check.cmd` fájljával indul, amely lefordítja és futtatja a Zig tesztprogramokat. A `tests\editor-check\check.cmd` a főablak tesztjeit (köztük a témabeállítás és a témafeloldás tesztjeit), a szerkesztő tesztjeit, a nyelvi lefedettség ellenőrzését és egy x86/XP próbafordítást futtat; a `tests\print-options\check.cmd` a nyomtatási és elrendezési teszteket futtatja.
- Az egyes modulok egységtesztjei a `zig test` paranccsal futtathatók, pl. `zig test src\toolbar.zig`, `src\navigation.zig`, `src\image.zig`, `src\zoom.zig`, `src\theme.zig` (ugyanazzal a céllal és include-kapcsolókkal, mint a `check.cmd` fájlban).
- Python 3 segédszkriptek: `python tests\i18n-check\run.py` (nyelvválasztás), `python tests\locale_coverage.py` (minden felületi szöveg megvan a katalógusban mind a 30 nyelvhez), `python tests\audit_xp.py` (a `Kadr.exe` XP-importjainak és -fejlécének ellenőrzése), `tests\measure_print.py`, `tests\tooltip_probe.py`, `tests\shot.py`.
- A `tests\generate_fixtures.py` tesztképeket hoz létre (Pillow szükséges hozzá); csak fejlesztéshez használatos, a `Kadr.exe` soha nem használja.

## Licenc

**GPL-3.0-or-later** — a teljes szöveg: [`LICENSE`](../LICENSE).

Külső összetevők és licencük (DjVuLibre, VC100/GDI+, Zig): [`THIRD-PARTY.txt`](../THIRD-PARTY.txt). A GNU GPL v2 szövege a DjVuLibre-hez: [`COPYING.txt`](../COPYING.txt).

Ez egy fordítás; az angol nyelvű változat ([README.md](../README.md)) a mérvadó.

## Köszönetnyilvánítás

- Készült [Zig](https://ziglang.org/) nyelven, Win32 és GDI+ alapokon.
- DjVu-dekódolás: [DjVuLibre](https://djvu.sourceforge.net/) 3.5.27 (GPL-2.0-or-later).
- A felület ikonjai és a Kadr logója a projekt saját, eredeti alkotásai (`src/ui.zig`, `tools/make_icon.py`).
- A képernyőképeken látható képek ehhez a README-hez generált szintetikus képek.
