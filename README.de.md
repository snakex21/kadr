[English](README.md) | [Polski](README.pl.md) | [Español](README.es.md) | [Français](README.fr.md) | **Deutsch** | [Português](README.pt.md) | [Русский](README.ru.md) | [Українська](README.uk.md) | [Italiano](README.it.md) | [Nederlands](README.nl.md) | [Čeština](README.cs.md) | [Magyar](README.hu.md) | [Română](README.ro.md) | [Türkçe](README.tr.md) | [Ελληνικά](README.el.md) | [العربية](README.ar.md) | [עברית](README.he.md) | [हिन्दी](README.hi.md) | [বাংলা](README.bn.md) | [اردو](README.ur.md) | [中文](README.zh.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Bahasa Indonesia](README.id.md) | [Tiếng Việt](README.vi.md) | [ไทย](README.th.md) | [فارسی](README.fa.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [मराठी](README.mr.md)

# Kadr

**Ein schneller, winziger, portabler Bildbetrachter und -editor für Windows — von Windows XP bis Windows 11, in einer einzigen `Kadr.exe` mit weniger als 1 MB.**

Kadr ist eine native Win32/GDI+-Anwendung, geschrieben in [Zig](https://ziglang.org/). Kein Installationsprogramm, kein .NET, kein Electron, kein Node.js: `Kadr.exe` an einen beliebigen Ort kopieren und starten. Die Einstellungen liegen in `Kadr.ini` neben dem Programm (portabel — nichts wird in die Registry oder nach AppData geschrieben).

![Kadr-Hauptfenster, helles Design](docs/screenshots/main-light.png)

## Inhaltsverzeichnis

- [Funktionen](#funktionen)
- [Screenshots](#screenshots)
- [Download / Installation](#download--installation)
- [Verwendung](#verwendung)
- [Tastenkürzel](#tastenkürzel)
- [Editor](#editor-1)
- [Drucken](#drucken)
- [Designs](#designs)
- [Einstellungen (Kadr.ini)](#einstellungen-kadrini)
- [Aus dem Quellcode bauen](#aus-dem-quellcode-bauen)
- [Tests ausführen](#tests-ausführen)
- [Lizenz](#lizenz)
- [Danksagungen](#danksagungen)

## Funktionen

- **Betrachter** — Fotos öffnen, durch den Ordner blättern (Pfeiltasten, vorheriges/nächstes), Diashow, Vollbild, stufenloser Zoom (einpassen, 1:1, Mausrad an der Cursorposition, eingetippte Werte wie `125%`, `37,5%` oder `200×`), Verschieben des Bildausschnitts, Wiedergabe animierter GIFs, mehrseitige TIFF- und DjVu-Dateien, automatische EXIF-Ausrichtung.
- **Editor** — Zuschneiden mit Live-Rahmen und Seitenverhältnis-Vorgaben (frei, 1:1, 4:3, 3:4, 3:2, 2:3, 16:9, A4 hoch/quer); Stift, Textmarker, Radierer, Linie, Pfeil, Rechteck und Text; Rückgängig/Wiederholen; Drehen und Spiegeln; Helligkeit, Kontrast, Sättigung und Schwarzweiß. Änderungen bleiben im Speicher, bis Sie speichern.
- **Drucken** — Live-Druckvorschau mit Papierformat, Ausrichtung, Skalierung (Einpassen / Füllen (zuschneiden) / Strecken (ganze Seite) / 100% / eigener Prozentsatz / Breite oder Höhe in mm), Rändern, Position, Farbe oder Graustufen.
- **Dateiwerkzeuge** — Speichern (Drehung), Speichern unter, Exportieren / Komprimieren (PNG, JPEG, BMP, TIFF, GIF) mit Größenänderung und Größenschätzung, Bild oder Pfad in die Zwischenablage kopieren, Umbenennen, in den Papierkorb verschieben oder endgültig löschen, im Ordner anzeigen, als Desktophintergrund festlegen.
- **Formate** — PNG, JPEG/JFIF, BMP/DIB, GIF, TIFF, DjVu, ICO, WMF/EMF, TGA, PCX, PSD (zusammengefügtes Bild), PBM/PGM/PPM/PNM, QOI.
- **30 Oberflächensprachen** — die Windows-Sprache wird automatisch erkannt (Rückfall auf Englisch) und lässt sich im Menü ändern; Rechts-nach-links-Layout für Arabisch, Hebräisch, Urdu und Persisch.
- **Designs** — hell, dunkel oder automatisch (folgt dem App-Modus von Windows und wechselt live).
- **Klein** — eine einzige `Kadr.exe` mit weniger als 1 MB.
- **Windows XP und neuer** — läuft von Windows XP SP3 (x86) bis Windows 10/11.

## Screenshots

| Helles Design | Dunkles Design |
|---|---|
| ![Hauptfenster, helles Design](docs/screenshots/main-light.png) | ![Hauptfenster, dunkles Design](docs/screenshots/main-dark.png) |

**Editor** — Zuschneiderahmen mit 3:2-Vorgabe, Stift, Textmarker, Pfeil, Rechteck und Text:

![Editor mit Zuschneiderahmen und Zeichnungen](docs/screenshots/editor-crop.png)

**Druckvorschau** im Modus *Stretch (whole page)* (Strecken: ganze Seite):

![Druckvorschau, Modus Strecken](docs/screenshots/print-stretch.png)

**Das Menü „Mehr“ (…)** mit dem Untermenü *Design*:

![Menü Mehr mit dem Untermenü Design](docs/screenshots/more-menu.png)

## Download / Installation

1. `Kadr.exe` von der [Releases-Seite](https://github.com/snakex21/kadr/releases) herunterladen (eine fertige `Kadr.exe` liegt auch im Stammverzeichnis des Repositorys).
2. In einen beliebigen beschreibbaren Ordner legen (zum Beispiel auf einen USB-Stick) und starten. Es gibt kein Installationsprogramm.
3. Für DjVu-Dateien den Ordner `deps\djvu\` aus dem Repository neben `Kadr.exe` belassen.

Um Bilder per Doppelklick zu öffnen, in Windows auf einer Bilddatei *Öffnen mit → Andere App auswählen* verwenden und `Kadr.exe` wählen.

**Voraussetzungen:** Windows XP SP3 x86 oder neuer (Windows 10/11 funktionieren ebenfalls). Sonst nichts.

> Der DjVu-Decoder ist das ältere DjVuLibre 3.5.27 — öffnen Sie nur DjVu-Dateien, denen Sie vertrauen (Details in `THIRD-PARTY.txt`).

## Verwendung

- **Öffnen** Sie ein Bild mit **Öffnen** (Ctrl+O), indem Sie eine Datei auf das Fenster ziehen, oder per Kommandozeile: `Kadr.exe photo.jpg`.
- **Blättern** Sie mit ← / → oder den Pfeilschaltflächen durch den Ordner; der Zähler zeigt die Position (z. B. `1 / 3`). Halten Sie eine Pfeiltaste gedrückt, um schnell zu blättern.
- **Zoomen** Sie mit dem Mausrad (Zoom an der Cursorposition), `+` / `−`, **Einpassen** (Home), **1:1** (`1`) oder tippen Sie einen Wert in das Zoomfeld und drücken Sie Enter. Ziehen Sie das Bild, um den Ausschnitt zu verschieben.
- **Drehen** Sie mit R / L. Gedreht wird die Ansicht; **Speichern** (Ctrl+S) schreibt die Drehung in die Datei.
- **Mehr (…)** öffnet das Menü mit allen Dateioperationen, Editor, Drucken, Diashow, Vollbild, Hilfe, *Nach Updates suchen…*, *Design* und *Sprache*.
- **Nach Updates suchen…** öffnet lediglich die GitHub-Releases-Seite des Projekts in Ihrem Webbrowser — Kadr selbst verbindet sich nie mit dem Internet.

## Tastenkürzel

### Betrachter

| Tastenkürzel | Aktion |
|---|---|
| Ctrl+O | Öffnen |
| Ctrl+S | Speichern (schreibt die Drehung in die aktuelle Datei) |
| Ctrl+Shift+S | Speichern unter |
| Ctrl+E | Bild bearbeiten |
| Ctrl+P | Drucken |
| Ctrl+C | Bild kopieren |
| Ctrl+Shift+C | Pfad kopieren |
| F2 | Umbenennen |
| Delete | In den Papierkorb |
| Shift+Delete | Endgültig löschen |
| ← / → | Vorheriges / nächstes Bild im Ordner (gedrückt halten zum schnellen Blättern) |
| Home | An das Fenster anpassen |
| 1 | Originalgröße (1:1) |
| + / − (auch Ziffernblock) | Vergrößern / Verkleinern |
| Mausrad | Zoom an der Cursorposition |
| Ziehen mit der linken Maustaste | Ausschnitt verschieben |
| Doppelklick | Vollbild ein / aus |
| R / L | Nach rechts / links drehen |
| Leertaste | Animation pausieren / fortsetzen |
| Page Up / Page Down | Vorherige / nächste Seite (TIFF, DjVu) |
| F5 | Diashow (alle 4 Sekunden) |
| F11 | Vollbild |
| Esc | Vollbild verlassen, Diashow beenden |
| F1 | Hilfe und Tastenkürzel |
| Shift+F10 oder die Menütaste | Menü „Mehr“ (auch Rechtsklick auf das Bild) |
| Tab / Shift+Tab, Enter oder Leertaste | Zwischen den Schaltflächen der Symbolleiste wechseln und sie betätigen |

### Zoomfeld

| Tastenkürzel | Aktion |
|---|---|
| Enter | Eingetippten Zoom übernehmen (`125%`, `37,5%`, `200×` …) |
| Esc | Aktuellen Wert wiederherstellen |
| Ctrl+A | Alles auswählen |

### Editor

| Tastenkürzel | Aktion |
|---|---|
| C | Zuschneiden |
| P | Pen (Stift) |
| H | Highlighter (Textmarker) |
| E | Eraser (Radierer) |
| L | Line (Linie) |
| A | Arrow (Pfeil) |
| B | Rectangle (Rechteck) |
| T | Text |
| Ctrl+Z | Undo (Rückgängig) |
| Ctrl+Y oder Ctrl+Shift+Z | Redo (Wiederholen) |
| Enter (Werkzeug Zuschneiden) oder Doppelklick | Abgedunkelten Bereich abschneiden |
| Enter / Esc (beim Eingeben von Text) | Text abschließen / verwerfen |
| Esc | Editor ohne Änderungen schließen |

### Druckvorschau

| Tastenkürzel | Aktion |
|---|---|
| Bild auf dem Blatt ziehen | Seine Position ändern |
| Esc | Vorschau schließen (bricht einen laufenden Druckauftrag ab) |

## Editor

Den Editor öffnen Sie mit **Edit** (Bearbeiten; Ctrl+E). Alle Änderungen bleiben im Speicher; die Originaldatei wird erst beim Speichern angetastet.

- **Zuschneiden** — ein Live-Rahmen mit acht Anfassern; ziehen Sie den Rahmen oder seine Anfasser, geben Sie X / Y / Breite / Höhe exakt in Pixeln ein oder wählen Sie eine Seitenverhältnis-Vorgabe (frei, Quadrat 1:1, 4:3, 3:4, 3:2 (4×6 quer), 2:3, 16:9, A4 hoch, A4 quer). Der Bereich außerhalb des Rahmens wird abgedunkelt; **Zuschneiden** (Enter) schneidet ihn ab, **Whole photo** (ganzes Foto) setzt den Rahmen zurück.
- **Zeichnen** — Stift, durchscheinender Textmarker, Radierer (entfernt nur Zeichnungen und Text, nie das Foto), gerade Linie, Pfeil, Rechteck und Text, mit zehn Farben und einstellbarer Stärke.
- **Bild** — Rückgängig / Wiederholen, um 90° nach links oder rechts drehen, horizontal oder vertikal spiegeln, alles zurücksetzen.
- **Farbe und Licht** — Helligkeit, Kontrast, Sättigung und Schwarzweiß.
- **Abschließen** — *Übernehmen* gibt das bearbeitete Bild an den Betrachter zurück, *Save as…* (Speichern unter…) speichert eine Kopie unter neuem Namen, *Print…* (Drucken…) führt direkt zur Druckvorschau, *Abbrechen* (Esc) verwirft die Änderungen.

## Drucken

**Drucken** (Ctrl+P) öffnet eine Live-Vorschau des Blatts. Wählen Sie Drucker, Papier (A3–A6, B4/B5, Letter, Legal, Executive, Tabloid, Fotoformate 10×15, 13×18, 15×20, 20×25 cm, 4×6, 5×7, 8×10 in, benutzerdefiniert oder das druckereigene Format), Ausrichtung sowie Farbe oder Graustufen. Die Ausrichtung folgt automatisch dem Bild, bis Sie sie ändern.

Skalierungsmodi:

| Modus | Wirkung |
|---|---|
| **Einpassen** | Das ganze Bild passt in die Ränder; die Proportionen bleiben erhalten, an zwei Seiten kann ein weißer Rand bleiben. |
| **Füllen / zuschneiden** | Das Bild bedeckt den gesamten druckbaren Bereich; die Proportionen bleiben erhalten, überstehende Ränder werden abgeschnitten. |
| **Stretch (whole page)** (Strecken: ganze Seite) | Das Bild wird exakt auf den druckbaren Bereich gestreckt — keine weißen Balken, aber die Proportionen bleiben **nicht** erhalten. |
| **100% · Originalgröße (96 DPI)** | Ein Pixel = 1/96 Zoll. |
| **Eigener Prozentsatz** | 0,1–1000 % bezogen auf 96 DPI (100% = die Größe darüber). |
| **Breite / Höhe (mm)** | Exakte physische Breite oder Höhe; die andere Seite folgt den Proportionen. |

**Erweitert ▸** ergänzt eine eigene Papiergröße, Ränder und eine exakte Position auf dem Blatt (oder ziehen Sie das Bild in der Vorschau; *Zentrieren* setzt es wieder in die Mitte). Die graue Linie zeigt die Hardwaregrenze des Druckers. Der zuletzt gewählte Skalierungsmodus wird in `Kadr.ini` gespeichert.

## Designs

**Mehr (…) → Design** bietet **Hell**, **Dunkel** und **Automatisch** (Standard).

- **Automatisch** folgt dem *App-Modus* von Windows (Einstellungen → Personalisierung → Farben, der Wert `AppsUseLightTheme`) und wechselt live, wenn Sie ihn in Windows ändern. Auf Systemen ohne diese Einstellung (Windows XP, Vista, 7, 8) bedeutet Automatisch Hell.
- Das Design umfasst Hauptfenster, Symbolleiste, Schaltflächen und Symbole, den Editor, die Druckvorschau und Kadrs eigene Dialoge. Im dunklen Modus ist der Bildhintergrund dunkelgrau, und unter Windows 10/11 sind auch Titelleisten und Kontextmenüs dunkel.
- Einige native Windows-Elemente behalten das Systemaussehen: Meldungsfenster (Hilfe, Bestätigungen), die Systemdialoge Öffnen / Speichern / Drucken und die Schieberegler-Griffe.

## Einstellungen (Kadr.ini)

Alle Einstellungen werden in `Kadr.ini` neben `Kadr.exe` gespeichert. Ist der Ordner schreibgeschützt, weist Kadr darauf hin, dass die Einstellungen nicht gespeichert werden können.

```ini
[General]
Language=en      ; pl, en, es, fr, de, pt, ru, uk, it, nl, cs, hu, ro, tr, el, ar, he, hi, bn, ur, zh, ja, ko, id, vi, th, fa, ta, te, mr
Theme=auto       ; auto, light or dark
[Print]
Scale=fit        ; fit, fill, stretch, actual, percent, width or height
```

Die Sprache lässt sich auch unter **Mehr (…) → Sprache / Language…** wählen; die Änderung gilt nach einem Neustart von Kadr. Das Design wirkt sofort.

Oberflächensprachen: Polski, English, Español, Français, Deutsch, Português, Русский, Українська, Italiano, Nederlands, Čeština, Magyar, Română, Türkçe, Ελληνικά, العربية, עברית, हिन्दी, বাংলা, اردو, 中文, 日本語, 한국어, Bahasa Indonesia, Tiếng Việt, ไทย, فارسی, தமிழ், తెలుగు, मराठी.

## Aus dem Quellcode bauen

Voraussetzungen: [Zig 0.11.0](https://ziglang.org/download/0.11.0/zig-windows-x86_64-0.11.0.zip), entpackt nach `tools\zig-windows-x86_64-0.11.0\` (das Archiv ist nicht Teil des Repositorys; seine SHA-256-Prüfsumme steht in `THIRD-PARTY.txt`).

```bat
build.cmd
```

Das Ergebnis ist `Kadr.exe` (Ziel `x86-windows.xp`, Pentium III, `ReleaseSmall`) mit XP-kompatiblem PE-Header. Icon neu erzeugen: `tools\build_icon.cmd` (Pillow + windres/objcopy).

Kadr linkt nur gegen Bibliotheken, die es unter Windows XP gibt. Neuere Funktionen (dunkle Titelleisten, dunkle Menüs und Steuerelemente) werden zur Laufzeit mit `LoadLibrary` / `GetProcAddress` geladen und auf älteren Systemen übersprungen.

## Tests ausführen

- Die Testsuiten liegen in Unterordnern von `tests\` (`editor-check`, `print-options`, `loader-check`, `image-check`, `codec-check`, `render-check`, `export-check`); jede wird über ihre `check.cmd` gestartet, die Zig-Testprogramme baut und ausführt. `tests\editor-check\check.cmd` führt die Hauptfenster-Tests (einschließlich der Tests für die Design-Einstellung und die Design-Auflösung), die Editor-Tests, die Prüfung der Sprachabdeckung und einen x86/XP-Kandidaten-Build aus; `tests\print-options\check.cmd` führt die Druck- und Layout-Tests aus.
- Unit-Tests einzelner Module lassen sich mit `zig test` ausführen, z. B. `zig test src\toolbar.zig`, `src\navigation.zig`, `src\image.zig`, `src\zoom.zig`, `src\theme.zig` (mit denselben Ziel- und Include-Flags wie in `check.cmd`).
- Python-3-Hilfsskripte: `python tests\i18n-check\run.py` (Sprachauswahl), `python tests\locale_coverage.py` (alle UI-Texte sind für 30 Sprachen im Katalog), `python tests\audit_xp.py` (XP-Import-/Header-Prüfung von `Kadr.exe`), `tests\measure_print.py`, `tests\tooltip_probe.py`, `tests\shot.py`.
- `tests\generate_fixtures.py` erzeugt Testbilder (benötigt Pillow); es dient nur der Entwicklung und wird nie von `Kadr.exe` verwendet.

## Lizenz

**GPL-3.0-or-later** — vollständiger Text in [`LICENSE`](LICENSE).

Komponenten von Drittanbietern und ihre Lizenzen (DjVuLibre, VC100/GDI+, Zig): [`THIRD-PARTY.txt`](THIRD-PARTY.txt). Text der GNU GPL v2 für DjVuLibre: [`COPYING.txt`](COPYING.txt).

Dies ist eine Übersetzung; maßgeblich ist die englische Fassung ([README.md](README.md)).

## Danksagungen

- Gebaut mit [Zig](https://ziglang.org/) auf Win32 und GDI+.
- DjVu-Dekodierung: [DjVuLibre](https://djvu.sourceforge.net/) 3.5.27 (GPL-2.0-or-later).
- Die Oberflächensymbole und das Kadr-Logo sind eigene Grafiken des Projekts (`src/ui.zig`, `tools/make_icon.py`).
- Die Bilder in den Screenshots sind synthetische Bilder, die für dieses README erzeugt wurden.
