[English](README.md) | [Polski](README.pl.md) | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt.md) | [Русский](README.ru.md) | [Українська](README.uk.md) | **Italiano** | [Nederlands](README.nl.md) | [Čeština](README.cs.md) | [Magyar](README.hu.md) | [Română](README.ro.md) | [Türkçe](README.tr.md) | [Ελληνικά](README.el.md) | [العربية](README.ar.md) | [עברית](README.he.md) | [हिन्दी](README.hi.md) | [বাংলা](README.bn.md) | [اردو](README.ur.md) | [中文](README.zh.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Bahasa Indonesia](README.id.md) | [Tiếng Việt](README.vi.md) | [ไทย](README.th.md) | [فارسی](README.fa.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [मराठी](README.mr.md)

# Kadr

**Un visualizzatore ed editor di foto per Windows veloce, minuscolo e portatile — da Windows XP a Windows 11, in un unico `Kadr.exe` da meno di 1 MB.**

Kadr è un’applicazione nativa Win32/GDI+ scritta in [Zig](https://ziglang.org/). Niente installer, niente .NET, niente Electron, niente Node.js: copia `Kadr.exe` dove vuoi e avvialo. Le impostazioni vengono salvate in `Kadr.ini` accanto al programma (portatile — non viene scritto nulla nel registro né in AppData).

![Finestra principale di Kadr, tema chiaro](docs/screenshots/main-light.png)

## Indice

- [Funzionalità](#funzionalità)
- [Screenshot](#screenshot)
- [Download / Installazione](#download--installazione)
- [Utilizzo](#utilizzo)
- [Scorciatoie da tastiera](#scorciatoie-da-tastiera)
- [Editor](#editor-1)
- [Stampa](#stampa)
- [Temi](#temi)
- [Impostazioni (Kadr.ini)](#impostazioni-kadrini)
- [Compilazione dai sorgenti](#compilazione-dai-sorgenti)
- [Esecuzione dei test](#esecuzione-dei-test)
- [Licenza](#licenza)
- [Ringraziamenti](#ringraziamenti)

## Funzionalità

- **Visualizzatore** — apertura delle foto, navigazione nella cartella (tasti freccia, precedente/successiva), presentazione, schermo intero, zoom fluido (adatta, 1:1, rotellina del mouse sul cursore, valori digitati come `125%`, `37,5%` o `200×`), spostamento della vista, riproduzione di GIF animate, TIFF e DjVu multipagina, orientamento EXIF automatico.
- **Editor** — ritaglio con cornice in tempo reale e proporzioni predefinite (libera, 1:1, 4:3, 3:4, 3:2, 2:3, 16:9, A4 verticale/orizzontale); penna, evidenziatore, gomma, linea, freccia, rettangolo e testo; annulla/ripeti; rotazione e riflessione; luminosità, contrasto, saturazione e bianco e nero. Le modifiche restano in memoria finché non salvi.
- **Stampa** — anteprima di stampa in tempo reale con formato carta, orientamento, scala (Adatta / Riempi (ritaglia) / Estendi (pagina intera) / 100% / percentuale personalizzata / larghezza o altezza in mm), margini, posizione, colore o scala di grigi.
- **Strumenti per i file** — salva (rotazione), salva con nome, esporta / comprimi (PNG, JPEG, BMP, TIFF, GIF) con ridimensionamento e stima delle dimensioni, copia dell’immagine o del percorso negli appunti, rinomina, Cestino o eliminazione definitiva, mostra nella cartella, imposta come sfondo del desktop.
- **Formati** — PNG, JPEG/JFIF, BMP/DIB, GIF, TIFF, DjVu, ICO, WMF/EMF, TGA, PCX, PSD (immagine unita), PBM/PGM/PPM/PNM, QOI.
- **30 lingue dell’interfaccia** — la lingua di Windows viene rilevata automaticamente (con ripiego sull’inglese) e si può cambiare dal menu; layout da destra a sinistra per arabo, ebraico, urdu e persiano.
- **Temi** — chiaro, scuro o automatico (segue la modalità app di Windows e cambia in tempo reale).
- **Leggero** — un solo `Kadr.exe` da meno di 1 MB.
- **Windows XP e successivi** — funziona da Windows XP SP3 (x86) fino a Windows 10/11.

## Screenshot

| Tema chiaro | Tema scuro |
|---|---|
| ![Finestra principale, tema chiaro](docs/screenshots/main-light.png) | ![Finestra principale, tema scuro](docs/screenshots/main-dark.png) |

**Editor** — cornice di ritaglio con proporzione 3:2, penna, evidenziatore, freccia, rettangolo e testo:

![Editor con cornice di ritaglio e disegni](docs/screenshots/editor-crop.png)

**Anteprima di stampa** in modalità *Stretch (whole page)* (Estendi: pagina intera):

![Anteprima di stampa, modalità Estendi](docs/screenshots/print-stretch.png)

**Il menu «Altro» (…)** con il sottomenu *Tema*:

![Menu Altro con il sottomenu Tema](docs/screenshots/more-menu.png)

## Download / Installazione

1. Scarica `Kadr.exe` dalla [pagina delle release](https://github.com/snakex21/kadr/releases) (un `Kadr.exe` già pronto si trova anche nella radice del repository).
2. Mettilo in una qualsiasi cartella in cui puoi scrivere (per esempio una chiavetta USB) e avvialo. Non c’è alcun installer.
3. Per i file DjVu, tieni la cartella `deps\djvu\` del repository accanto a `Kadr.exe`.

Per aprire le immagini con un doppio clic, usa in Windows *Apri con → Scegli un’altra app* su un’immagine e seleziona `Kadr.exe`.

**Requisiti:** Windows XP SP3 x86 o successivo (funzionano anche Windows 10/11). Nient’altro.

> Il decodificatore DjVu è il vecchio DjVuLibre 3.5.27 — apri solo file DjVu di cui ti fidi (dettagli in `THIRD-PARTY.txt`).

## Utilizzo

- **Apri** un’immagine con **Apri** (Ctrl+O), trascinando un file sulla finestra o passandolo dalla riga di comando: `Kadr.exe photo.jpg`.
- **Sfoglia** la cartella con ← / → o con i pulsanti freccia; il contatore mostra la posizione (ad es. `1 / 3`). Tieni premuto un tasto freccia per sfogliare rapidamente.
- **Ingrandisci** con la rotellina del mouse (zoom sul cursore), `+` / `−`, **Adatta** (Home), **1:1** (`1`) oppure digita un valore nel campo zoom e premi Enter. Trascina l’immagine per spostare la vista.
- **Ruota** con R / L. Viene ruotata la vista; **Salva** (Ctrl+S) scrive la rotazione nel file.
- **Altro (…)** apre il menu con tutte le operazioni sui file, l’editor, la stampa, la presentazione, lo schermo intero, la guida, *Controlla aggiornamenti…*, *Tema* e *Lingua*.
- **Controlla aggiornamenti…** si limita ad aprire la pagina delle release del progetto su GitHub nel browser — Kadr di per sé non si connette mai a Internet.

## Scorciatoie da tastiera

### Visualizzatore

| Scorciatoia | Azione |
|---|---|
| Ctrl+O | Apri |
| Ctrl+S | Salva (scrive la rotazione nel file corrente) |
| Ctrl+Shift+S | Salva con nome |
| Ctrl+E | Modifica immagine |
| Ctrl+P | Stampa |
| Ctrl+C | Copia immagine |
| Ctrl+Shift+C | Copia percorso |
| F2 | Rinomina |
| Delete | Sposta nel Cestino |
| Shift+Delete | Elimina definitivamente |
| ← / → | Immagine precedente / successiva nella cartella (tieni premuto per sfogliare rapidamente) |
| Home | Adatta alla finestra |
| 1 | Dimensioni reali (1:1) |
| + / − (anche tastierino numerico) | Ingrandisci / Riduci |
| Rotellina del mouse | Zoom sul cursore |
| Trascinamento con il tasto sinistro | Sposta la vista |
| Doppio clic | Schermo intero sì / no |
| R / L | Ruota a destra / a sinistra |
| Spazio | Metti in pausa / riprendi l’animazione |
| Page Up / Page Down | Pagina precedente / successiva (TIFF, DjVu) |
| F5 | Presentazione (ogni 4 secondi) |
| F11 | Schermo intero |
| Esc | Esci dallo schermo intero, ferma la presentazione |
| F1 | Guida e scorciatoie |
| Shift+F10 o il tasto Menu | Menu «Altro» (anche clic destro sull’immagine) |
| Tab / Shift+Tab, Enter o Spazio | Spostati tra i pulsanti della barra degli strumenti e premili |

### Campo zoom

| Scorciatoia | Azione |
|---|---|
| Enter | Applica lo zoom digitato (`125%`, `37,5%`, `200×` …) |
| Esc | Ripristina il valore attuale |
| Ctrl+A | Seleziona tutto |

### Editor

| Scorciatoia | Azione |
|---|---|
| C | Ritaglia |
| P | Pen (penna) |
| H | Highlighter (evidenziatore) |
| E | Eraser (gomma) |
| L | Line (linea) |
| A | Arrow (freccia) |
| B | Rectangle (rettangolo) |
| T | Text (testo) |
| Ctrl+Z | Undo (annulla) |
| Ctrl+Y o Ctrl+Shift+Z | Redo (ripeti) |
| Enter (strumento Ritaglia) o doppio clic | Taglia la parte scurita |
| Enter / Esc (durante la digitazione del testo) | Conferma / annulla il testo |
| Esc | Chiudi l’editor senza modifiche |

### Anteprima di stampa

| Scorciatoia | Azione |
|---|---|
| Trascina l’immagine sul foglio | Cambia la sua posizione |
| Esc | Chiudi l’anteprima (annulla un lavoro di stampa in corso) |

## Editor

Apri l’editor con **Edit** (Modifica; Ctrl+E). Tutte le modifiche restano in memoria; il file originale non viene toccato finché non salvi.

- **Ritaglia** — una cornice in tempo reale con otto maniglie; trascina la cornice o le maniglie, digita X / Y / larghezza / altezza esatte in pixel oppure scegli una proporzione predefinita (libera, quadrato 1:1, 4:3, 3:4, 3:2 (4×6 orizzontale), 2:3, 16:9, A4 verticale, A4 orizzontale). L’area fuori dalla cornice viene scurita; **Ritaglia** (Enter) la taglia via e **Whole photo** (foto intera) reimposta la cornice.
- **Disegno** — penna, evidenziatore semitrasparente, gomma (cancella solo disegni e testo, mai la foto), linea retta, freccia, rettangolo e testo, con dieci colori e spessore regolabile.
- **Immagine** — annulla / ripeti, rotazione di 90° a sinistra o a destra, riflessione orizzontale o verticale, ripristina tutto.
- **Colore e luce** — luminosità, contrasto, saturazione e bianco e nero.
- **Conclusione** — *Applica* riporta l’immagine modificata nel visualizzatore, *Save as…* (Salva con nome…) salva una copia con un nuovo nome, *Print…* (Stampa…) passa direttamente all’anteprima di stampa, *Annulla* (Esc) scarta le modifiche.

## Stampa

**Stampa** (Ctrl+P) apre un’anteprima del foglio in tempo reale. Scegli la stampante, la carta (A3–A6, B4/B5, Letter, Legal, Executive, Tabloid, formati foto 10×15, 13×18, 15×20, 20×25 cm, 4×6, 5×7, 8×10 in, personalizzato o quello della stampante), l’orientamento e il colore o la scala di grigi. L’orientamento segue automaticamente l’immagine finché non lo cambi.

Modalità di scala:

| Modalità | Cosa fa |
|---|---|
| **Adatta** | L’intera immagine sta dentro i margini; le proporzioni sono mantenute e su due lati può restare dello spazio bianco. |
| **Riempi / ritaglia** | L’immagine copre l’intera area stampabile; le proporzioni sono mantenute e i bordi in eccesso vengono ritagliati. |
| **Stretch (whole page)** (Estendi: pagina intera) | L’immagine viene estesa esattamente sull’area stampabile — niente bande bianche, ma le proporzioni **non** sono mantenute. |
| **100% · Dimensioni reali (96 DPI)** | Un pixel = 1/96 di pollice. |
| **Percentuale personalizzata** | 0,1–1000 % rispetto a 96 DPI (100% = la dimensione sopra). |
| **Larghezza / Altezza (mm)** | Larghezza o altezza fisica esatta; l’altro lato segue le proporzioni. |

**Avanzate ▸** aggiunge un formato carta personalizzato, i margini e una posizione esatta sul foglio (oppure trascina l’immagine nell’anteprima; *Centra* la rimette al centro). La linea grigia indica il limite hardware della stampante. L’ultima modalità di scala scelta viene memorizzata in `Kadr.ini`.

## Temi

**Altro (…) → Tema** offre **Chiaro**, **Scuro** e **Automatico** (predefinito).

- **Automatico** segue la *modalità app* di Windows (Impostazioni → Personalizzazione → Colori, il valore `AppsUseLightTheme`) e cambia in tempo reale quando la modifichi in Windows. Sui sistemi privi di questa impostazione (Windows XP, Vista, 7, 8) Automatico equivale a Chiaro.
- Il tema si applica alla finestra principale, alla barra degli strumenti, ai pulsanti e alle icone, all’editor, all’anteprima di stampa e alle finestre di dialogo di Kadr. In modalità scura lo sfondo dell’immagine è grigio scuro e, su Windows 10/11, anche le barre del titolo e i menu a comparsa sono scuri.
- Alcuni elementi nativi di Windows mantengono l’aspetto di sistema: le finestre di messaggio (guida, conferme), le finestre di sistema Apri / Salva / Stampa e i cursori dei controlli a scorrimento.

## Impostazioni (Kadr.ini)

Tutte le impostazioni sono salvate in `Kadr.ini` accanto a `Kadr.exe`. Se la cartella è di sola lettura, Kadr avvisa che le impostazioni non possono essere salvate.

```ini
[General]
Language=en      ; pl, en, es, fr, de, pt, ru, uk, it, nl, cs, hu, ro, tr, el, ar, he, hi, bn, ur, zh, ja, ko, id, vi, th, fa, ta, te, mr
Theme=auto       ; auto, light or dark
[Print]
Scale=fit        ; fit, fill, stretch, actual, percent, width or height
```

La lingua si può scegliere anche da **Altro (…) → Lingua / Language…**; la modifica ha effetto dopo il riavvio di Kadr. Il tema si applica subito.

Lingue dell’interfaccia: Polski, English, Español, Français, Deutsch, Português, Русский, Українська, Italiano, Nederlands, Čeština, Magyar, Română, Türkçe, Ελληνικά, العربية, עברית, हिन्दी, বাংলা, اردو, 中文, 日本語, 한국어, Bahasa Indonesia, Tiếng Việt, ไทย, فارسی, தமிழ், తెలుగు, मराठी.

## Compilazione dai sorgenti

Requisiti: [Zig 0.11.0](https://ziglang.org/download/0.11.0/zig-windows-x86_64-0.11.0.zip) estratto in `tools\zig-windows-x86_64-0.11.0\` (l’archivio non fa parte del repository; il suo SHA-256 è in `THIRD-PARTY.txt`).

```bat
build.cmd
```

Il risultato è `Kadr.exe` (target `x86-windows.xp`, Pentium III, `ReleaseSmall`) con un’intestazione PE compatibile con XP. Per rigenerare l’icona: `tools\build_icon.cmd` (Pillow + windres/objcopy).

Kadr si collega solo a librerie presenti in Windows XP. Le funzioni più recenti (barre del titolo scure, menu e controlli scuri) vengono caricate in fase di esecuzione con `LoadLibrary` / `GetProcAddress` e saltate sui sistemi più vecchi.

## Esecuzione dei test

- Le suite di test si trovano nelle sottocartelle di `tests\` (`editor-check`, `print-options`, `loader-check`, `image-check`, `codec-check`, `render-check`, `export-check`); ognuna si avvia con il proprio `check.cmd`, che compila ed esegue i programmi di test in Zig. `tests\editor-check\check.cmd` esegue i test della finestra principale (compresi i test dell’impostazione del tema e della risoluzione del tema), i test dell’editor, il controllo della copertura linguistica e una build candidata x86/XP; `tests\print-options\check.cmd` esegue i test di stampa e di impaginazione.
- I test unitari dei singoli moduli si eseguono con `zig test`, ad es. `zig test src\toolbar.zig`, `src\navigation.zig`, `src\image.zig`, `src\zoom.zig`, `src\theme.zig` (con gli stessi flag di target e di include di `check.cmd`).
- Script di supporto in Python 3: `python tests\i18n-check\run.py` (selezione della lingua), `python tests\locale_coverage.py` (tutte le stringhe dell’interfaccia sono nel catalogo per 30 lingue), `python tests\audit_xp.py` (verifica di import e intestazione XP di `Kadr.exe`), `tests\measure_print.py`, `tests\tooltip_probe.py`, `tests\shot.py`.
- `tests\generate_fixtures.py` crea immagini di test (richiede Pillow); serve solo allo sviluppo e non viene mai usato da `Kadr.exe`.

## Licenza

**GPL-3.0-or-later** — testo completo in [`LICENSE`](LICENSE).

Componenti di terze parti e relative licenze (DjVuLibre, VC100/GDI+, Zig): [`THIRD-PARTY.txt`](THIRD-PARTY.txt). Testo della GNU GPL v2 per DjVuLibre: [`COPYING.txt`](COPYING.txt).

Questa è una traduzione; fa fede la versione inglese ([README.md](README.md)).

## Ringraziamenti

- Realizzato con [Zig](https://ziglang.org/) su Win32 e GDI+.
- Decodifica DjVu: [DjVuLibre](https://djvu.sourceforge.net/) 3.5.27 (GPL-2.0-or-later).
- Le icone dell’interfaccia e il logo di Kadr sono grafiche originali del progetto (`src/ui.zig`, `tools/make_icon.py`).
- Le immagini negli screenshot sono immagini sintetiche generate per questo README.
