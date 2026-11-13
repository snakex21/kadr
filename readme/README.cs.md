[English](../README.md) | [Polski](README.pl.md) | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt.md) | [Русский](README.ru.md) | [Українська](README.uk.md) | [Italiano](README.it.md) | [Nederlands](README.nl.md) | **Čeština** | [Magyar](README.hu.md) | [Română](README.ro.md) | [Türkçe](README.tr.md) | [Ελληνικά](README.el.md) | [العربية](README.ar.md) | [עברית](README.he.md) | [हिन्दी](README.hi.md) | [বাংলা](README.bn.md) | [اردو](README.ur.md) | [中文](README.zh.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Bahasa Indonesia](README.id.md) | [Tiếng Việt](README.vi.md) | [ไทย](README.th.md) | [فارسی](README.fa.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [मराठी](README.mr.md)

# Kadr

**Rychlý, malinký a přenosný prohlížeč a editor fotografií pro Windows — od Windows XP po Windows 11, v jediném souboru `Kadr.exe` menším než 1 MB.**

Kadr je nativní aplikace Win32/GDI+ napsaná v jazyce [Zig](https://ziglang.org/). Žádný instalátor, žádné .NET, žádný Electron, žádný Node.js: zkopírujte `Kadr.exe` kamkoli a spusťte ho. Nastavení se ukládá do `Kadr.ini` vedle programu (přenosně — nic se nezapisuje do registru ani do AppData).

![Hlavní okno Kadru, světlý motiv](../docs/screenshots/main-light.png)

## Obsah

- [Funkce](#funkce)
- [Snímky obrazovky](#snímky-obrazovky)
- [Stažení / instalace](#stažení--instalace)
- [Použití](#použití)
- [Klávesové zkratky](#klávesové-zkratky)
- [Editor](#editor-1)
- [Tisk](#tisk)
- [Motivy](#motivy)
- [Nastavení (Kadr.ini)](#nastavení-kadrini)
- [Sestavení ze zdrojového kódu](#sestavení-ze-zdrojového-kódu)
- [Spouštění testů](#spouštění-testů)
- [Licence](#licence)
- [Poděkování](#poděkování)

## Funkce

- **Prohlížeč** — otevírání fotografií, procházení složky (šipky, předchozí/další), prezentace, celá obrazovka, plynulé zvětšování (přizpůsobit, 1:1, kolečko myši v místě kurzoru, zadané hodnoty jako `125%`, `37,5%` nebo `200×`), posouvání obrázku, přehrávání animovaných GIFů, vícestránkové TIFF a DjVu, automatická orientace podle EXIF.
- **Editor** — ořez s živým rámečkem a předvolbami poměru stran (volný, 1:1, 4:3, 3:4, 3:2, 2:3, 16:9, A4 na výšku/na šířku); pero, zvýrazňovač, guma, čára, šipka, obdélník a text; zpět/znovu; otáčení a převracení; jas, kontrast, sytost a černobílý režim. Změny zůstávají v paměti, dokud je neuložíte.
- **Tisk** — živý náhled tisku s volbou velikosti papíru, orientace, měřítka (přizpůsobit / vyplnit (s ořezem) / roztáhnout (celá stránka) / 100% / vlastní % / šířka nebo výška v mm), okrajů, polohy, barevného tisku nebo odstínů šedi.
- **Práce se soubory** — uložení (otočení), uložení jako, export / komprese (PNG, JPEG, BMP, TIFF, GIF) se změnou velikosti a odhadem velikosti souboru, kopírování obrázku nebo cesty do schránky, přejmenování, přesun do Koše nebo trvalé odstranění, zobrazení ve složce, nastavení jako pozadí plochy.
- **Formáty** — PNG, JPEG/JFIF, BMP/DIB, GIF, TIFF, DjVu, ICO, WMF/EMF, TGA, PCX, PSD (sloučený obraz), PBM/PGM/PPM/PNM, QOI.
- **30 jazyků rozhraní** — jazyk Windows se rozpozná automaticky (jinak se použije angličtina) a lze ho změnit v nabídce; pro arabštinu, hebrejštinu, urdštinu a perštinu se rozhraní zobrazuje zprava doleva.
- **Motivy** — světlý, tmavý nebo automatický (řídí se režimem aplikací ve Windows a přepíná se za běhu).
- **Malý** — jediný `Kadr.exe` menší než 1 MB.
- **Windows XP a novější** — běží na Windows XP SP3 (x86) až po Windows 10/11.

## Snímky obrazovky

| Světlý motiv | Tmavý motiv |
|---|---|
| ![Hlavní okno, světlý motiv](../docs/screenshots/main-light.png) | ![Hlavní okno, tmavý motiv](../docs/screenshots/main-dark.png) |

**Editor** — rámeček ořezu s předvolbou 3:2, pero, zvýrazňovač, šipka, obdélník a text:

![Editor s rámečkem ořezu a kresbami](../docs/screenshots/editor-crop.png)

**Náhled tisku** v režimu *Stretch (whole page)* (roztáhnout na celou stránku):

![Náhled tisku, režim Stretch](../docs/screenshots/print-stretch.png)

**Nabídka „Více“ (…)** s podnabídkou *Motiv*:

![Nabídka Více s podnabídkou Motiv](../docs/screenshots/more-menu.png)

## Stažení / instalace

1. Stáhněte `Kadr.exe` ze [stránky vydání](https://github.com/snakex21/kadr/releases) (hotový `Kadr.exe` je také v kořeni repozitáře).
2. Umístěte ho do libovolné složky, do které můžete zapisovat (například na USB flash disk), a spusťte ho. Instalátor neexistuje.
3. Pro soubory DjVu ponechte vedle `Kadr.exe` složku `deps\djvu\` z repozitáře.

Chcete-li otevírat obrázky dvojklikem, použijte ve Windows na obrázku *Otevřít v programu → Zvolit jinou aplikaci* a vyberte `Kadr.exe`.

**Požadavky:** Windows XP SP3 x86 nebo novější (fungují i Windows 10/11). Nic dalšího.

> Dekodér DjVu je starší DjVuLibre 3.5.27 — otevírejte jen soubory DjVu, kterým důvěřujete (podrobnosti v `THIRD-PARTY.txt`).

## Použití

- **Otevřete** obrázek tlačítkem **Otevřít** (Ctrl+O), přetažením souboru do okna nebo jeho předáním na příkazovém řádku: `Kadr.exe photo.jpg`.
- **Procházejte** složku klávesami ← / → nebo tlačítky se šipkami; počítadlo ukazuje pozici (např. `1 / 3`). Podržením šipky procházíte rychle.
- **Zvětšujte** kolečkem myši (zvětšuje v místě kurzoru), klávesami `+` / `−`, tlačítky **Přizpůsobit** (Home), **1:1** (`1`) nebo zadejte hodnotu do pole zvětšení a stiskněte Enter. Přetažením obrázek posunete.
- **Otáčejte** klávesami R / L. Otáčí se zobrazení; **Uložit** (Ctrl+S) zapíše otočení do souboru.
- **Více (…)** otevře nabídku se všemi operacemi se souborem, editorem, tiskem, prezentací, celou obrazovkou, nápovědou a položkami *Zkontrolovat aktualizace…*, *Motiv* a *Jazyk*.
- **Zkontrolovat aktualizace…** pouze otevře stránku vydání projektu na GitHubu ve webovém prohlížeči — samotný Kadr se nikdy nepřipojuje k internetu.

## Klávesové zkratky

### Prohlížeč

| Zkratka | Akce |
|---|---|
| Ctrl+O | Otevřít |
| Ctrl+S | Uložit (zapíše otočení do aktuálního souboru) |
| Ctrl+Shift+S | Uložit jako |
| Ctrl+E | Upravit obrázek |
| Ctrl+P | Tisk |
| Ctrl+C | Kopírovat obrázek |
| Ctrl+Shift+C | Kopírovat cestu |
| F2 | Přejmenovat |
| Delete | Přesunout do Koše |
| Shift+Delete | Trvale odstranit |
| ← / → | Předchozí / další obrázek ve složce (podržením rychle procházíte) |
| Home | Přizpůsobit oknu |
| 1 | Skutečná velikost (1:1) |
| + / − (i na numerické klávesnici) | Přiblížit / oddálit |
| Kolečko myši | Zvětšení v místě kurzoru |
| Tažení levým tlačítkem | Posun obrázku |
| Dvojklik | Zapnout / vypnout celou obrazovku |
| R / L | Otočit doprava / doleva |
| Space | Pozastavit / obnovit animaci |
| Page Up / Page Down | Předchozí / další stránka (TIFF, DjVu) |
| F5 | Prezentace (každé 4 sekundy) |
| F11 | Celá obrazovka |
| Esc | Ukončit celou obrazovku, zastavit prezentaci |
| F1 | Nápověda a zkratky |
| Shift+F10 nebo klávesa Menu | Nabídka „Více“ (také pravým kliknutím na obrázek) |
| Tab / Shift+Tab, Enter nebo Space | Přechod mezi tlačítky panelu nástrojů a jejich stisknutí |

### Pole zvětšení

| Zkratka | Akce |
|---|---|
| Enter | Použít zadané zvětšení (`125%`, `37,5%`, `200×` …) |
| Esc | Obnovit aktuální hodnotu |
| Ctrl+A | Vybrat vše |

### Editor

| Zkratka | Akce |
|---|---|
| C | Oříznout |
| P | Pen (pero) |
| H | Highlighter (zvýrazňovač) |
| E | Eraser (guma) |
| L | Line (čára) |
| A | Arrow (šipka) |
| B | Rectangle (obdélník) |
| T | Text (text) |
| Ctrl+Z | Undo (zpět) |
| Ctrl+Y nebo Ctrl+Shift+Z | Redo (znovu) |
| Enter (nástroj Oříznout) nebo dvojklik | Odříznout ztmavenou část |
| Enter / Esc (při psaní textu) | Dokončit / zrušit text |
| Esc | Zavřít editor bez změn |

### Náhled tisku

| Zkratka | Akce |
|---|---|
| Tažení obrázku na listu | Změna jeho polohy |
| Esc | Zavřít náhled (přeruší probíhající tiskovou úlohu) |

## Editor

Editor otevřete tlačítkem **Edit** (upravit, Ctrl+E). Všechny změny se drží v paměti; původní soubor zůstane nedotčen, dokud neuložíte.

- **Oříznout** — živý rámeček s osmi úchyty; táhněte rámeček nebo jeho úchyty, zadejte přesné X / Y / šířku / výšku v pixelech nebo zvolte předvolbu poměru stran (volný, čtverec 1:1, 4:3, 3:4, 3:2 (4×6 na šířku), 2:3, 16:9, A4 na výšku, A4 na šířku). Oblast mimo rámeček je ztmavená; **Oříznout** (Enter) ji odřízne a **Whole photo** (celá fotografie) rámeček obnoví.
- **Kreslení** — pero, průsvitný zvýrazňovač, guma (maže jen kresby a text, nikdy fotografii), rovná čára, šipka, obdélník a text, s deseti barvami a nastavitelnou tloušťkou.
- **Image** (obrázek) — zpět / znovu, otočení o 90° doleva nebo doprava, zrcadlení vodorovně nebo svisle, obnovení všeho.
- **Colour and light** (barvy a světlo) — jas, kontrast, sytost a černobílý režim.
- **Dokončení** — *Použít* vrátí upravený obrázek do prohlížeče, *Save as…* (uložit jako) uloží kopii pod novým názvem, *Print…* (tisk) přejde rovnou do náhledu tisku, *Zrušit* (Esc) změny zahodí.

## Tisk

**Tisk** (Ctrl+P) otevře živý náhled listu. Zvolte tiskárnu, papír (A3–A6, B4/B5, Letter, Legal, Executive, Tabloid, fotoformáty 10×15, 13×18, 15×20, 20×25 cm, 4×6, 5×7, 8×10 in, vlastní nebo formát tiskárny), orientaci a barevný tisk nebo odstíny šedi. Orientace se automaticky řídí obrázkem, dokud ji nezměníte.

Režimy měřítka:

| Režim | Co dělá |
|---|---|
| **Přizpůsobit** | Celý obrázek se vejde do okrajů; poměr stran zůstane zachován, na dvou stranách může zůstat bílé místo. |
| **Vyplnit / oříznout** | Obrázek pokryje celou tisknutelnou oblast; poměr stran zůstane zachován a přečnívající okraje se oříznou. |
| **Stretch (whole page)** (roztáhnout na celou stránku) | Obrázek se roztáhne přesně na tisknutelnou oblast — bez bílých pruhů, ale poměr stran se **nezachová**. |
| **100% · Skutečná velikost (96 DPI)** | Jeden pixel = 1/96 palce. |
| **Vlastní procenta** | 0.1–1000 % vzhledem k 96 DPI (100% = velikost o řádek výše). |
| **Šířka / Výška (mm)** | Přesná fyzická šířka nebo výška; druhý rozměr vyplyne z poměru stran. |

**Pokročilé ▸** přidá vlastní velikost papíru, okraje a přesnou polohu na listu (nebo přetáhněte obrázek v náhledu; *Na střed* ho vrátí doprostřed). Šedá čára ukazuje hardwarovou hranici tiskárny. Naposledy zvolený režim měřítka se pamatuje v `Kadr.ini`.

## Motivy

**Více (…) → Motiv** nabízí **Světlý**, **Tmavý** a **Automatický** (výchozí).

- **Automatický** se řídí *režimem aplikací* ve Windows (Nastavení → Přizpůsobení → Barvy, hodnota `AppsUseLightTheme`) a přepne se za běhu, jakmile ho ve Windows změníte. V systémech bez tohoto nastavení (Windows XP, Vista, 7, 8) znamená Automatický totéž co Světlý.
- Motiv se týká hlavního okna, panelu nástrojů, tlačítek a ikon, editoru, náhledu tisku a vlastních dialogových oken Kadru. V tmavém režimu je pozadí obrázku tmavě šedé a ve Windows 10/11 jsou tmavé i záhlaví oken a místní nabídky.
- Několik nativních prvků Windows si ponechává systémový vzhled: okna se zprávami (nápověda, potvrzení), systémová dialogová okna Otevřít / Uložit / Tisk a jezdce posuvníků.

## Nastavení (Kadr.ini)

Všechna nastavení se ukládají do `Kadr.ini` vedle `Kadr.exe`. Pokud je složka jen pro čtení, Kadr oznámí, že nastavení nelze uložit.

```ini
[General]
Language=en      ; pl, en, es, fr, de, pt, ru, uk, it, nl, cs, hu, ro, tr, el, ar, he, hi, bn, ur, zh, ja, ko, id, vi, th, fa, ta, te, mr
Theme=auto       ; auto, light or dark
[Print]
Scale=fit        ; fit, fill, stretch, actual, percent, width or height
```

Jazyk lze zvolit také v **Více (…) → Jazyk**; změna se projeví po restartu Kadru. Motiv se použije okamžitě.

Jazyky rozhraní: Polski, English, Español, Français, Deutsch, Português, Русский, Українська, Italiano, Nederlands, Čeština, Magyar, Română, Türkçe, Ελληνικά, العربية, עברית, हिन्दी, বাংলা, اردو, 中文, 日本語, 한국어, Bahasa Indonesia, Tiếng Việt, ไทย, فارسی, தமிழ், తెలుగు, मराठी.

## Sestavení ze zdrojového kódu

Požadavky: [Zig 0.11.0](https://ziglang.org/download/0.11.0/zig-windows-x86_64-0.11.0.zip) rozbalený do `tools\zig-windows-x86_64-0.11.0\` (archiv není součástí repozitáře; jeho SHA-256 je uveden v `THIRD-PARTY.txt`).

```bat
build.cmd
```

Výsledkem je `Kadr.exe` (cíl `x86-windows.xp`, Pentium III, `ReleaseSmall`) s hlavičkou PE kompatibilní s XP. Opětovné vygenerování ikony: `tools\build_icon.cmd` (Pillow + windres/objcopy).

Kadr se linkuje jen proti knihovnám, které existují ve Windows XP. Novější funkce (tmavá záhlaví oken, tmavé nabídky a ovládací prvky) se načítají za běhu pomocí `LoadLibrary` / `GetProcAddress` a ve starších systémech se přeskakují.

## Spouštění testů

- Sady testů jsou v podsložkách `tests\` (`editor-check`, `print-options`, `loader-check`, `image-check`, `codec-check`, `render-check`, `export-check`); každá se spouští svým `check.cmd`, který sestaví a spustí testovací programy v Zigu. `tests\editor-check\check.cmd` spouští testy hlavního okna (včetně testů nastavení motivu a určení motivu), testy editoru, kontrolu pokrytí jazyků a zkušební sestavení pro x86/XP; `tests\print-options\check.cmd` spouští testy tisku a rozvržení.
- Jednotkové testy jednotlivých modulů lze spustit pomocí `zig test`, např. `zig test src\toolbar.zig`, `src\navigation.zig`, `src\image.zig`, `src\zoom.zig`, `src\theme.zig` (se stejným cílem a stejnými přepínači include jako v `check.cmd`).
- Pomocné skripty v Pythonu 3: `python tests\i18n-check\run.py` (výběr jazyka), `python tests\locale_coverage.py` (všechny řetězce rozhraní jsou v katalogu pro 30 jazyků), `python tests\audit_xp.py` (kontrola importů a hlavičky `Kadr.exe` z hlediska XP), `tests\measure_print.py`, `tests\tooltip_probe.py`, `tests\shot.py`.
- `tests\generate_fixtures.py` vytváří testovací obrázky (vyžaduje Pillow); používá se jen při vývoji, `Kadr.exe` ho nikdy nepoužívá.

## Licence

**GPL-3.0-or-later** — úplný text v [`LICENSE`](../LICENSE).

Komponenty třetích stran a jejich licence (DjVuLibre, VC100/GDI+, Zig): [`THIRD-PARTY.txt`](../THIRD-PARTY.txt). Text GNU GPL v2 pro DjVuLibre: [`COPYING.txt`](../COPYING.txt).

Toto je překlad; závazná je anglická verze ([README.md](../README.md)).

## Poděkování

- Vytvořeno v jazyce [Zig](https://ziglang.org/) nad Win32 a GDI+.
- Dekódování DjVu: [DjVuLibre](https://djvu.sourceforge.net/) 3.5.27 (GPL-2.0-or-later).
- Ikony rozhraní a logo Kadru jsou původní dílo projektu (`src/ui.zig`, `tools/make_icon.py`).
- Obrázky na snímcích obrazovky jsou syntetické obrázky vytvořené pro tento README.
