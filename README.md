**English** | [Polski](README.pl.md) | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt.md) | [Русский](README.ru.md) | [Українська](README.uk.md) | [Italiano](README.it.md) | [Nederlands](README.nl.md) | [Čeština](README.cs.md) | [Magyar](README.hu.md) | [Română](README.ro.md) | [Türkçe](README.tr.md) | [Ελληνικά](README.el.md) | [العربية](README.ar.md) | [עברית](README.he.md) | [हिन्दी](README.hi.md) | [বাংলা](README.bn.md) | [اردو](README.ur.md) | [中文](README.zh.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Bahasa Indonesia](README.id.md) | [Tiếng Việt](README.vi.md) | [ไทย](README.th.md) | [فارسی](README.fa.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [मराठी](README.mr.md)

# Kadr

**A fast, tiny, portable photo viewer and editor for Windows — from Windows XP to Windows 11, in a single `Kadr.exe` under 1 MB.**

Kadr is a native Win32/GDI+ application written in [Zig](https://ziglang.org/). No installer, no .NET, no Electron, no Node.js: copy `Kadr.exe` anywhere and run it. Settings are stored in `Kadr.ini` next to the program (portable — nothing is written to the registry or AppData).

![Kadr main window, light theme](docs/screenshots/main-light.png)

## Table of contents

- [Features](#features)
- [Screenshots](#screenshots)
- [Download / Installation](#download--installation)
- [Usage](#usage)
- [Keyboard shortcuts](#keyboard-shortcuts)
- [Editor](#editor-1)
- [Printing](#printing)
- [Themes](#themes)
- [Settings (Kadr.ini)](#settings-kadrini)
- [Building from source](#building-from-source)
- [Running tests](#running-tests)
- [License](#license)
- [Credits](#credits)

## Features

- **Viewer** — open photos, browse the folder (arrow keys, previous/next), slideshow, full screen, smooth zoom (fit, 1:1, mouse wheel at the cursor, typed values such as `125%`, `37,5%` or `200×`), panning, animated GIF playback, multi-page TIFF and DjVu, automatic EXIF orientation.
- **Editor** — crop with a live frame and aspect presets (free, 1:1, 4:3, 3:4, 3:2, 2:3, 16:9, A4 portrait/landscape); pen, highlighter, eraser, line, arrow, rectangle and text; undo/redo; rotate and flip; brightness, contrast, saturation and black & white. Changes stay in memory until you save.
- **Printing** — live print preview with paper size, orientation, scale (Fit / Fill (crop) / Stretch (whole page) / 100% / custom % / width or height in mm), margins, position, colour or grayscale.
- **File tools** — save (rotation), save as, export / compress (PNG, JPEG, BMP, TIFF, GIF) with resize and size estimate, copy image or path to the clipboard, rename, Recycle Bin or permanent delete, show in folder, set as desktop wallpaper.
- **Formats** — PNG, JPEG/JFIF, BMP/DIB, GIF, TIFF, DjVu, ICO, WMF/EMF, TGA, PCX, PSD (merged image), PBM/PGM/PPM/PNM, QOI.
- **30 interface languages** — the Windows language is detected automatically (falls back to English) and can be changed from the menu; right-to-left layout for Arabic, Hebrew, Urdu and Persian.
- **Themes** — light, dark or automatic (follows the Windows app mode, switches live).
- **Small** — one `Kadr.exe` smaller than 1 MB.
- **Windows XP and newer** — runs on Windows XP SP3 (x86) through Windows 10/11.

## Screenshots

| Light theme | Dark theme |
|---|---|
| ![Main window, light theme](docs/screenshots/main-light.png) | ![Main window, dark theme](docs/screenshots/main-dark.png) |

**Editor** — crop frame with a 3:2 preset, pen, highlighter, arrow, rectangle and text:

![Editor with crop frame and drawings](docs/screenshots/editor-crop.png)

**Print preview** in *Stretch (whole page)* mode:

![Print preview, Stretch mode](docs/screenshots/print-stretch.png)

**The "More" (…) menu** with the *Theme* submenu:

![More menu with the Theme submenu](docs/screenshots/more-menu.png)

## Download / Installation

1. Download `Kadr.exe` from the [Releases page](https://github.com/snakex21/kadr/releases) (a ready-made `Kadr.exe` is also kept in the root of the repository).
2. Put it in any folder you can write to (for example a USB stick) and run it. There is no installer.
3. For DjVu files, keep the `deps\djvu\` folder from the repository next to `Kadr.exe`.

To open pictures with a double-click, use Windows' *Open with → Choose another app* on an image and select `Kadr.exe`.

**Requirements:** Windows XP SP3 x86 or newer (Windows 10/11 work too). Nothing else.

> The DjVu decoder is the older DjVuLibre 3.5.27 — only open DjVu files you trust (details in `THIRD-PARTY.txt`).

## Usage

- **Open** a picture with **Open** (Ctrl+O), by dragging a file onto the window, or by passing it on the command line: `Kadr.exe photo.jpg`.
- **Browse** the folder with ← / → or the arrow buttons; the counter shows the position (e.g. `1 / 3`). Hold an arrow key to browse quickly.
- **Zoom** with the mouse wheel (zooms at the cursor), `+` / `−`, **Fit** (Home), **1:1** (`1`) or type a value into the zoom field and press Enter. Drag the picture to pan.
- **Rotate** with R / L. The view is rotated; **Save** (Ctrl+S) writes the rotation into the file.
- **More (…)** opens the menu with all file operations, editor, print, slideshow, full screen, help, *Check for updates…*, *Theme* and *Language*.
- **Check for updates…** only opens the project's GitHub releases page in your web browser — Kadr itself never connects to the internet.

## Keyboard shortcuts

### Viewer

| Shortcut | Action |
|---|---|
| Ctrl+O | Open |
| Ctrl+S | Save (writes the rotation into the current file) |
| Ctrl+Shift+S | Save as |
| Ctrl+E | Edit image |
| Ctrl+P | Print |
| Ctrl+C | Copy image |
| Ctrl+Shift+C | Copy path |
| F2 | Rename |
| Delete | Move to Recycle Bin |
| Shift+Delete | Delete permanently |
| ← / → | Previous / next picture in the folder (hold to browse quickly) |
| Home | Fit to window |
| 1 | Actual size (1:1) |
| + / − (also numeric keypad) | Zoom in / out |
| Mouse wheel | Zoom at the cursor |
| Drag with the left button | Pan |
| Double-click | Full screen on / off |
| R / L | Rotate right / left |
| Space | Pause / resume animation |
| Page Up / Page Down | Previous / next page (TIFF, DjVu) |
| F5 | Slideshow (every 4 seconds) |
| F11 | Full screen |
| Esc | Leave full screen, stop the slideshow |
| F1 | Help and shortcuts |
| Shift+F10 or the Menu key | "More" menu (also right-click on the picture) |
| Tab / Shift+Tab, Enter or Space | Move between toolbar buttons and press them |

### Zoom field

| Shortcut | Action |
|---|---|
| Enter | Apply the typed zoom (`125%`, `37,5%`, `200×` …) |
| Esc | Restore the current value |
| Ctrl+A | Select all |

### Editor

| Shortcut | Action |
|---|---|
| C | Crop |
| P | Pen |
| H | Highlighter |
| E | Eraser |
| L | Line |
| A | Arrow |
| B | Rectangle |
| T | Text |
| Ctrl+Z | Undo |
| Ctrl+Y or Ctrl+Shift+Z | Redo |
| Enter (Crop tool) or double-click | Cut off the dimmed part |
| Enter / Esc (while typing text) | Finish / cancel the text |
| Esc | Close the editor without changes |

### Print preview

| Shortcut | Action |
|---|---|
| Drag the picture on the sheet | Change its position |
| Esc | Close the preview (cancels a running print job) |

## Editor

Open the editor with **Edit** (Ctrl+E). All changes are kept in memory; the original file is not touched until you save.

- **Crop** — a live frame with eight handles; drag the frame or its handles, type exact X / Y / width / height in pixels, or pick an aspect preset (free, square 1:1, 4:3, 3:4, 3:2 (4×6 landscape), 2:3, 16:9, A4 portrait, A4 landscape). The area outside the frame is dimmed; **Crop** (Enter) cuts it off and **Whole photo** resets the frame.
- **Drawing** — pen, translucent highlighter, eraser (removes drawings and text only, never the photo), straight line, arrow, rectangle and text, with ten colours and an adjustable size.
- **Image** — undo / redo, rotate 90° left or right, mirror horizontally or vertically, reset all.
- **Colour and light** — brightness, contrast, saturation and black & white.
- **Finish** — *Apply* returns the edited picture to the viewer, *Save as…* saves a copy under a new name, *Print…* goes straight to the print preview, *Cancel* (Esc) discards the changes.

## Printing

**Print** (Ctrl+P) opens a live preview of the sheet. Choose the printer, paper (A3–A6, B4/B5, Letter, Legal, Executive, Tabloid, photo sizes 10×15, 13×18, 15×20, 20×25 cm, 4×6, 5×7, 8×10 in, custom or the printer's own), orientation and colour or grayscale. The orientation follows the picture automatically until you change it.

Scale modes:

| Mode | What it does |
|---|---|
| **Fit (whole image)** | The whole picture fits inside the margins; proportions are kept, white space may remain on two sides. |
| **Fill (crop)** | The picture covers the whole printable area; proportions are kept and the overflowing edges are cropped. |
| **Stretch (whole page)** | The picture is stretched to exactly the printable area — no white bars, but the proportions are **not** kept. |
| **100% (96 DPI)** | One pixel = 1/96 inch. |
| **Custom percentage** | 0.1–1000 % relative to 96 DPI (100% = the size above). |
| **Width / height (mm)** | Exact physical width or height; the other side follows the proportions. |

**Advanced ▸** adds custom paper size, margins and an exact position on the sheet (or drag the picture in the preview; *Center* puts it back in the middle). The gray line shows the printer's hardware limit. The last chosen scale mode is remembered in `Kadr.ini`.

## Themes

**More (…) → Theme** offers **Light**, **Dark** and **Automatic** (the default).

- **Automatic** follows the Windows *app mode* (Settings → Personalization → Colours, the `AppsUseLightTheme` value) and switches live when you change it in Windows. On systems without that setting (Windows XP, Vista, 7, 8) Automatic means Light.
- The theme covers the main window, toolbar, buttons and icons, the editor, the print preview and Kadr's own dialogs. In dark mode the image background is dark gray, and on Windows 10/11 the title bars and popup menus are dark too.
- A few native Windows parts keep the system look: message boxes (help, confirmations), the Open / Save / Print system dialogs and the slider thumbs.

## Settings (Kadr.ini)

All settings are stored in `Kadr.ini` next to `Kadr.exe`. If the folder is read-only, Kadr tells you that settings cannot be saved.

```ini
[General]
Language=en      ; pl, en, es, fr, de, pt, ru, uk, it, nl, cs, hu, ro, tr, el, ar, he, hi, bn, ur, zh, ja, ko, id, vi, th, fa, ta, te, mr
Theme=auto       ; auto, light or dark
[Print]
Scale=fit        ; fit, fill, stretch, actual, percent, width or height
```

The language can also be chosen in **More (…) → Language**; the change applies after restarting Kadr. The theme applies immediately.

Interface languages: Polski, English, Español, Français, Deutsch, Português, Русский, Українська, Italiano, Nederlands, Čeština, Magyar, Română, Türkçe, Ελληνικά, العربية, עברית, हिन्दी, বাংলা, اردو, 中文, 日本語, 한국어, Bahasa Indonesia, Tiếng Việt, ไทย, فارسی, தமிழ், తెలుగు, मराठी.

## Building from source

Requirements: [Zig 0.11.0](https://ziglang.org/download/0.11.0/zig-windows-x86_64-0.11.0.zip) unpacked to `tools\zig-windows-x86_64-0.11.0\` (the archive is not part of the repository; its SHA-256 is in `THIRD-PARTY.txt`).

```bat
build.cmd
```

The result is `Kadr.exe` (target `x86-windows.xp`, Pentium III, `ReleaseSmall`) with an XP-compatible PE header. Regenerating the icon: `tools\build_icon.cmd` (Pillow + windres/objcopy).

Kadr links only to libraries that exist on Windows XP. Newer features (dark title bars, dark menus and controls) are loaded at run time with `LoadLibrary` / `GetProcAddress` and are skipped on older systems.

## Running tests

- Test suites live in `tests\` subfolders (`editor-check`, `print-options`, `loader-check`, `image-check`, `codec-check`, `render-check`, `export-check`); each is started with its `check.cmd`, which builds and runs Zig harnesses. `tests\editor-check\check.cmd` runs the main-window tests (including the theme setting and theme resolution tests), the editor tests, the language-coverage check and an x86/XP candidate build; `tests\print-options\check.cmd` runs the printing and layout tests.
- Unit tests in single modules can be run with `zig test`, e.g. `zig test src\toolbar.zig`, `src\navigation.zig`, `src\image.zig`, `src\zoom.zig`, `src\theme.zig` (with the same target and include flags as in `check.cmd`).
- Python 3 helpers: `python tests\i18n-check\run.py` (language selection), `python tests\locale_coverage.py` (all UI strings are in the catalog for 30 languages), `python tests\audit_xp.py` (XP import/header audit of `Kadr.exe`), `tests\measure_print.py`, `tests\tooltip_probe.py`, `tests\shot.py`.
- `tests\generate_fixtures.py` creates test images (requires Pillow); it is used only for development, never by `Kadr.exe`.

## License

**GPL-3.0-or-later** — full text in [`LICENSE`](LICENSE).

Third-party components and their licenses (DjVuLibre, VC100/GDI+, Zig): [`THIRD-PARTY.txt`](THIRD-PARTY.txt). GNU GPL v2 text for DjVuLibre: [`COPYING.txt`](COPYING.txt).

## Credits

- Built with [Zig](https://ziglang.org/) on Win32 and GDI+.
- DjVu decoding: [DjVuLibre](https://djvu.sourceforge.net/) 3.5.27 (GPL-2.0-or-later).
- The interface icons and the Kadr logo are original artwork of the project (`src/ui.zig`, `tools/make_icon.py`).
- The pictures in the screenshots are synthetic images generated for this README.
