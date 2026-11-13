[English](../README.md) | [Polski](README.pl.md) | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt.md) | [Русский](README.ru.md) | [Українська](README.uk.md) | [Italiano](README.it.md) | **Nederlands** | [Čeština](README.cs.md) | [Magyar](README.hu.md) | [Română](README.ro.md) | [Türkçe](README.tr.md) | [Ελληνικά](README.el.md) | [العربية](README.ar.md) | [עברית](README.he.md) | [हिन्दी](README.hi.md) | [বাংলা](README.bn.md) | [اردو](README.ur.md) | [中文](README.zh.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Bahasa Indonesia](README.id.md) | [Tiếng Việt](README.vi.md) | [ไทย](README.th.md) | [فارسی](README.fa.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [मराठी](README.mr.md)

# Kadr

**Een snelle, piepkleine, draagbare fotoviewer en -editor voor Windows — van Windows XP tot en met Windows 11, in één `Kadr.exe` van minder dan 1 MB.**

Kadr is een native Win32/GDI+-toepassing, geschreven in [Zig](https://ziglang.org/). Geen installatieprogramma, geen .NET, geen Electron, geen Node.js: kopieer `Kadr.exe` naar een willekeurige plek en start het. De instellingen worden opgeslagen in `Kadr.ini` naast het programma (draagbaar — er wordt niets naar het register of AppData geschreven).

![Hoofdvenster van Kadr, licht thema](../docs/screenshots/main-light.png)

## Inhoudsopgave

- [Functies](#functies)
- [Schermafbeeldingen](#schermafbeeldingen)
- [Downloaden / Installatie](#downloaden--installatie)
- [Gebruik](#gebruik)
- [Sneltoetsen](#sneltoetsen)
- [Editor](#editor-1)
- [Afdrukken](#afdrukken)
- [Thema's](#themas)
- [Instellingen (Kadr.ini)](#instellingen-kadrini)
- [Bouwen vanaf de broncode](#bouwen-vanaf-de-broncode)
- [Tests uitvoeren](#tests-uitvoeren)
- [Licentie](#licentie)
- [Credits](#credits)

## Functies

- **Viewer** — foto's openen, door de map bladeren (pijltoetsen, vorige/volgende), diavoorstelling, volledig scherm, vloeiend zoomen (passend maken, 1:1, muiswiel op de cursorpositie, getypte waarden zoals `125%`, `37,5%` of `200×`), verschuiven, afspelen van geanimeerde GIF's, TIFF en DjVu met meerdere pagina's, automatische EXIF-oriëntatie.
- **Editor** — bijsnijden met een live kader en vaste verhoudingen (vrij, 1:1, 4:3, 3:4, 3:2, 2:3, 16:9, A4 staand/liggend); pen, markeerstift, gum, lijn, pijl, rechthoek en tekst; ongedaan maken/opnieuw; draaien en spiegelen; helderheid, contrast, verzadiging en zwart-wit. Wijzigingen blijven in het geheugen tot u opslaat.
- **Afdrukken** — live afdrukvoorbeeld met papierformaat, afdrukstand, schaal (passend / vullen (bijsnijden) / Stretch (hele pagina) / 100% / eigen % / breedte of hoogte in mm), marges, positie, kleur of grijstinten.
- **Bestandsfuncties** — opslaan (rotatie), opslaan als, exporteren / comprimeren (PNG, JPEG, BMP, TIFF, GIF) met formaat wijzigen en geschatte bestandsgrootte, afbeelding of pad naar het klembord kopiëren, hernoemen, naar de Prullenbak of definitief verwijderen, in map weergeven, als bureaubladachtergrond instellen.
- **Formaten** — PNG, JPEG/JFIF, BMP/DIB, GIF, TIFF, DjVu, ICO, WMF/EMF, TGA, PCX, PSD (samengevoegde afbeelding), PBM/PGM/PPM/PNM, QOI.
- **30 interfacetalen** — de taal van Windows wordt automatisch herkend (met Engels als terugval) en kan via het menu worden gewijzigd; lay-out van rechts naar links voor Arabisch, Hebreeuws, Urdu en Perzisch.
- **Thema's** — licht, donker of automatisch (volgt de app-modus van Windows en wisselt direct mee).
- **Klein** — één `Kadr.exe` van minder dan 1 MB.
- **Windows XP en nieuwer** — draait op Windows XP SP3 (x86) tot en met Windows 10/11.

## Schermafbeeldingen

| Licht thema | Donker thema |
|---|---|
| ![Hoofdvenster, licht thema](../docs/screenshots/main-light.png) | ![Hoofdvenster, donker thema](../docs/screenshots/main-dark.png) |

**Editor** — bijsnijkader met de verhouding 3:2, pen, markeerstift, pijl, rechthoek en tekst:

![Editor met bijsnijkader en tekeningen](../docs/screenshots/editor-crop.png)

**Afdrukvoorbeeld** in de modus *Stretch (whole page)* (uitrekken: hele pagina):

![Afdrukvoorbeeld, Stretch-modus](../docs/screenshots/print-stretch.png)

**Het menu "Meer" (…)** met het submenu *Thema*:

![Menu Meer met het submenu Thema](../docs/screenshots/more-menu.png)

## Downloaden / Installatie

1. Download `Kadr.exe` van de [Releases-pagina](https://github.com/snakex21/kadr/releases) (een kant-en-klare `Kadr.exe` staat ook in de hoofdmap van de repository).
2. Zet het bestand in een map waarin u kunt schrijven (bijvoorbeeld op een usb-stick) en start het. Er is geen installatieprogramma.
3. Voor DjVu-bestanden houdt u de map `deps\djvu\` uit de repository naast `Kadr.exe`.

Om afbeeldingen met een dubbelklik te openen, kiest u in Windows bij een afbeelding *Openen met → Een andere app kiezen* en selecteert u `Kadr.exe`.

**Vereisten:** Windows XP SP3 x86 of nieuwer (Windows 10/11 werken ook). Verder niets.

> De DjVu-decoder is het oudere DjVuLibre 3.5.27 — open alleen DjVu-bestanden die u vertrouwt (details in `THIRD-PARTY.txt`).

## Gebruik

- **Open** een afbeelding met **Openen** (Ctrl+O), door een bestand naar het venster te slepen of door het op de opdrachtregel mee te geven: `Kadr.exe photo.jpg`.
- **Blader** door de map met ← / → of de pijlknoppen; de teller toont de positie (bijv. `1 / 3`). Houd een pijltoets ingedrukt om snel te bladeren.
- **Zoom** met het muiswiel (zoomt op de cursorpositie), `+` / `−`, **Passend maken** (Home), **1:1** (`1`) of typ een waarde in het zoomveld en druk op Enter. Sleep de afbeelding om te verschuiven.
- **Draai** met R / L. Alleen de weergave wordt gedraaid; **Opslaan** (Ctrl+S) schrijft de rotatie naar het bestand.
- **Meer (…)** opent het menu met alle bestandsbewerkingen, de editor, afdrukken, de diavoorstelling, volledig scherm, help, *Controleren op updates…*, *Thema* en *Taal*.
- **Controleren op updates…** opent alleen de GitHub-releasepagina van het project in uw webbrowser — Kadr zelf maakt nooit verbinding met internet.

## Sneltoetsen

### Viewer

| Sneltoets | Actie |
|---|---|
| Ctrl+O | Openen |
| Ctrl+S | Opslaan (schrijft de rotatie naar het huidige bestand) |
| Ctrl+Shift+S | Opslaan als |
| Ctrl+E | Afbeelding bewerken |
| Ctrl+P | Afdrukken |
| Ctrl+C | Afbeelding kopiëren |
| Ctrl+Shift+C | Pad kopiëren |
| F2 | Hernoemen |
| Delete | Naar Prullenbak |
| Shift+Delete | Definitief verwijderen |
| ← / → | Vorige / volgende afbeelding in de map (ingedrukt houden om snel te bladeren) |
| Home | Passend maken in venster |
| 1 | Ware grootte (1:1) |
| + / − (ook numeriek toetsenblok) | Inzoomen / uitzoomen |
| Muiswiel | Zoomen op de cursorpositie |
| Slepen met de linkermuisknop | Verschuiven |
| Dubbelklikken | Volledig scherm aan / uit |
| R / L | Rechtsom / linksom draaien |
| Spatiebalk | Animatie pauzeren / hervatten |
| Page Up / Page Down | Vorige / volgende pagina (TIFF, DjVu) |
| F5 | Diavoorstelling (elke 4 seconden) |
| F11 | Volledig scherm |
| Esc | Volledig scherm verlaten, diavoorstelling stoppen |
| F1 | Help en sneltoetsen |
| Shift+F10 of de Menu-toets | Menu "Meer" (ook via rechtsklikken op de afbeelding) |
| Tab / Shift+Tab, Enter of Spatiebalk | Tussen de werkbalkknoppen bewegen en ze indrukken |

### Zoomveld

| Sneltoets | Actie |
|---|---|
| Enter | Getypte zoomwaarde toepassen (`125%`, `37,5%`, `200×` …) |
| Esc | Huidige waarde herstellen |
| Ctrl+A | Alles selecteren |

### Editor

| Sneltoets | Actie |
|---|---|
| C | Bijsnijden |
| P | Pen |
| H | Highlighter (markeerstift) |
| E | Eraser (gum) |
| L | Line (lijn) |
| A | Arrow (pijl) |
| B | Rectangle (rechthoek) |
| T | Text (tekst) |
| Ctrl+Z | Undo (ongedaan maken) |
| Ctrl+Y of Ctrl+Shift+Z | Redo (opnieuw) |
| Enter (gereedschap Bijsnijden) of dubbelklikken | Het verduisterde deel wegsnijden |
| Enter / Esc (tijdens het typen van tekst) | Tekst voltooien / annuleren |
| Esc | Editor sluiten zonder wijzigingen |

### Afdrukvoorbeeld

| Sneltoets | Actie |
|---|---|
| Afbeelding op het vel slepen | De positie ervan wijzigen |
| Esc | Voorbeeld sluiten (annuleert een lopende afdruktaak) |

## Editor

Open de editor met **Edit** (Ctrl+E). Alle wijzigingen blijven in het geheugen; het oorspronkelijke bestand wordt pas aangepast als u opslaat.

- **Bijsnijden** — een live kader met acht grepen; sleep het kader of de grepen, typ exacte X / Y / breedte / hoogte in pixels of kies een vaste verhouding (vrij, vierkant 1:1, 4:3, 3:4, 3:2 (4×6 liggend), 2:3, 16:9, A4 staand, A4 liggend). Het gebied buiten het kader wordt verduisterd; **Bijsnijden** (Enter) snijdt het weg en **Whole photo** (hele foto) zet het kader terug.
- **Tekenen** — pen, doorschijnende markeerstift, gum (wist alleen tekeningen en tekst, nooit de foto), rechte lijn, pijl, rechthoek en tekst, met tien kleuren en een instelbare dikte.
- **Afbeelding** — ongedaan maken / opnieuw, 90° naar links of rechts draaien, horizontaal of verticaal spiegelen, alles herstellen.
- **Kleur en licht** — helderheid, contrast, verzadiging en zwart-wit.
- **Afronden** — *Toepassen* brengt de bewerkte afbeelding terug naar de viewer, *Save as…* (opslaan als) slaat een kopie onder een nieuwe naam op, *Print…* (afdrukken) gaat direct naar het afdrukvoorbeeld, *Annuleren* (Esc) verwerpt de wijzigingen.

## Afdrukken

**Afdrukken** (Ctrl+P) opent een live voorbeeld van het vel. Kies de printer, het papier (A3–A6, B4/B5, Letter, Legal, Executive, Tabloid, fotoformaten 10×15, 13×18, 15×20, 20×25 cm, 4×6, 5×7, 8×10 in, aangepast of het eigen formaat van de printer), de afdrukstand en kleur of grijstinten. De afdrukstand volgt de afbeelding automatisch, totdat u hem zelf wijzigt.

Schaalmodi:

| Modus | Wat het doet |
|---|---|
| **Passend maken** | De hele afbeelding past binnen de marges; de verhoudingen blijven behouden, aan twee kanten kan witruimte overblijven. |
| **Vullen / bijsnijden** | De afbeelding bedekt het hele afdrukbare gebied; de verhoudingen blijven behouden en de uitstekende randen worden bijgesneden. |
| **Stretch (whole page)** | De afbeelding wordt precies tot het afdrukbare gebied uitgerekt — geen witte balken, maar de verhoudingen blijven **niet** behouden. |
| **100% · Ware grootte (96 DPI)** | Eén pixel = 1/96 inch. |
| **Aangepast percentage** | 0,1–1000% ten opzichte van 96 DPI (100% = de grootte hierboven). |
| **Breedte (mm) / Hoogte (mm)** | Exacte fysieke breedte of hoogte; de andere kant volgt de verhoudingen. |

**Geavanceerd ▸** voegt een aangepast papierformaat, marges en een exacte positie op het vel toe (of sleep de afbeelding in het voorbeeld; *Centreren* zet haar terug in het midden). De grijze lijn toont de hardwaregrens van de printer. De laatst gekozen schaalmodus wordt onthouden in `Kadr.ini`.

## Thema's

**Meer (…) → Thema** biedt **Licht**, **Donker** en **Automatisch** (de standaard).

- **Automatisch** volgt de *app-modus* van Windows (Instellingen → Persoonlijke instellingen → Kleuren, de waarde `AppsUseLightTheme`) en wisselt direct mee als u die in Windows wijzigt. Op systemen zonder die instelling (Windows XP, Vista, 7, 8) betekent Automatisch hetzelfde als Licht.
- Het thema geldt voor het hoofdvenster, de werkbalk, knoppen en pictogrammen, de editor, het afdrukvoorbeeld en de eigen dialoogvensters van Kadr. In de donkere modus is de achtergrond van de afbeelding donkergrijs, en op Windows 10/11 zijn ook de titelbalken en pop-upmenu's donker.
- Een paar native Windows-onderdelen houden het systeemuiterlijk: berichtvensters (help, bevestigingen), de systeemdialoogvensters Openen / Opslaan / Afdrukken en de schuifregelaars.

## Instellingen (Kadr.ini)

Alle instellingen worden opgeslagen in `Kadr.ini` naast `Kadr.exe`. Als de map alleen-lezen is, meldt Kadr dat de instellingen niet kunnen worden opgeslagen.

```ini
[General]
Language=en      ; pl, en, es, fr, de, pt, ru, uk, it, nl, cs, hu, ro, tr, el, ar, he, hi, bn, ur, zh, ja, ko, id, vi, th, fa, ta, te, mr
Theme=auto       ; auto, light or dark
[Print]
Scale=fit        ; fit, fill, stretch, actual, percent, width or height
```

De taal kan ook worden gekozen via **Meer (…) → Taal**; de wijziging gaat in na een herstart van Kadr. Het thema wordt direct toegepast.

Interfacetalen: Polski, English, Español, Français, Deutsch, Português, Русский, Українська, Italiano, Nederlands, Čeština, Magyar, Română, Türkçe, Ελληνικά, العربية, עברית, हिन्दी, বাংলা, اردو, 中文, 日本語, 한국어, Bahasa Indonesia, Tiếng Việt, ไทย, فارسی, தமிழ், తెలుగు, मराठी.

## Bouwen vanaf de broncode

Vereisten: [Zig 0.11.0](https://ziglang.org/download/0.11.0/zig-windows-x86_64-0.11.0.zip) uitgepakt naar `tools\zig-windows-x86_64-0.11.0\` (het archief maakt geen deel uit van de repository; de SHA-256 ervan staat in `THIRD-PARTY.txt`).

```bat
build.cmd
```

Het resultaat is `Kadr.exe` (doel `x86-windows.xp`, Pentium III, `ReleaseSmall`) met een XP-compatibele PE-header. Het pictogram opnieuw genereren: `tools\build_icon.cmd` (Pillow + windres/objcopy).

Kadr linkt alleen naar bibliotheken die op Windows XP aanwezig zijn. Nieuwere functies (donkere titelbalken, donkere menu's en besturingselementen) worden tijdens de uitvoering geladen met `LoadLibrary` / `GetProcAddress` en op oudere systemen overgeslagen.

## Tests uitvoeren

- De testsuites staan in submappen van `tests\` (`editor-check`, `print-options`, `loader-check`, `image-check`, `codec-check`, `render-check`, `export-check`); elke suite wordt gestart met haar `check.cmd`, dat Zig-testharnassen bouwt en uitvoert. `tests\editor-check\check.cmd` voert de tests van het hoofdvenster uit (inclusief de tests voor de thema-instelling en de themabepaling), de editortests, de controle op taaldekking en een x86/XP-kandidaatbuild; `tests\print-options\check.cmd` voert de afdruk- en lay-outtests uit.
- Unittests in afzonderlijke modules kunnen worden uitgevoerd met `zig test`, bijv. `zig test src\toolbar.zig`, `src\navigation.zig`, `src\image.zig`, `src\zoom.zig`, `src\theme.zig` (met hetzelfde doel en dezelfde include-vlaggen als in `check.cmd`).
- Python 3-hulpscripts: `python tests\i18n-check\run.py` (taalkeuze), `python tests\locale_coverage.py` (alle UI-teksten staan in de catalogus voor 30 talen), `python tests\audit_xp.py` (XP-controle van imports/header van `Kadr.exe`), `tests\measure_print.py`, `tests\tooltip_probe.py`, `tests\shot.py`.
- `tests\generate_fixtures.py` maakt testafbeeldingen aan (vereist Pillow); het wordt alleen bij de ontwikkeling gebruikt, nooit door `Kadr.exe`.

## Licentie

**GPL-3.0-or-later** — volledige tekst in [`LICENSE`](../LICENSE).

Componenten van derden en hun licenties (DjVuLibre, VC100/GDI+, Zig): [`THIRD-PARTY.txt`](../THIRD-PARTY.txt). Tekst van de GNU GPL v2 voor DjVuLibre: [`COPYING.txt`](../COPYING.txt).

Dit is een vertaling; de Engelse versie ([README.md](../README.md)) is leidend.

## Credits

- Gebouwd met [Zig](https://ziglang.org/) op Win32 en GDI+.
- DjVu-decodering: [DjVuLibre](https://djvu.sourceforge.net/) 3.5.27 (GPL-2.0-or-later).
- De interfacepictogrammen en het Kadr-logo zijn origineel werk van het project (`src/ui.zig`, `tools/make_icon.py`).
- De afbeeldingen in de schermafbeeldingen zijn synthetische beelden die voor deze README zijn gegenereerd.
