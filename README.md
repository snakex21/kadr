# Kadr

**Kadr** — natywna przeglądarka zdjęć dla Windows, napisana w [Zigu](https://ziglang.org/) na Win32/GDI+. Jeden plik `Kadr.exe`, bez instalacji, bez .NET, Electrona i Node.js — ustawienia zapisuje w `Kadr.ini` obok niego (portable).

![Ikona Kadr](assets/kadr.png)

W repozytorium leży gotowe `Kadr.exe` — można uruchomić bez kompilowania.

## Możliwości

- **Przeglądanie** — otwieranie zdjęć, nawigacja po katalogu (strzałki, poprzedni/następny), pokaz slajdów (Spacja), tryb pełnoekranowy (F11).
- **Zoom** — dopasowanie do okna (Home), 1:1 (`1`), skoki 125% / 37.5% / 200×, powiększanie `+` / `−`.
- **Pliki wielostronicowe** — strony TIFF i DjVu (Page Up / Page Down).
- **Drukowanie** (Ctrl+P) — podgląd na żywo, wybór papieru (A4, A5, Letter, formaty odbitek), orientacja, skala i marginesy.
- **Edytor** (Ctrl+E) — kadrowanie z podglądem na żywo, jasność/kontrast/nasycenie, obrót i odbijanie, pisak, zakreślacz, gumka, kształty i tekst; zmiany trafiają do pliku dopiero po zapisaniu.
- **Pliki** — zapis (Ctrl+S), zapis jako (Ctrl+Shift+S), kopiowanie do schowka (Ctrl+C), zmiana nazwy (F2), usuwanie (Delete → kosz, Shift+Delete → trwałe).
- **Automatyczna orientacja EXIF** — portrety z aparatu wyświetlają się we właściwą stronę.
- **30 języków interfejsu** — wykrywanie języka Windows z odesłaniem na angielski, wybór z menu; tryb RTL dla arabskiego, hebrajskiego, urdu i farskiego.
- **Przenośność** — brak zapisu w rejestrze i AppData; cała konfiguracja w `Kadr.ini` obok EXE.

## Obsługiwane formaty

PNG, JPEG/JFIF, BMP/DIB, GIF, TIFF, DjVu, ICO, WMF/EMF, TGA, PCX, PSD (scalony obraz), PBM/PGM/PPM/PNM, QOI.

Otwieranie „wszystkich plików" też działa — GDI+ rozpoznaje zdjęcia także po zawartości, nie tylko po rozszerzeniu.

## Języki interfejsu (30)

| Kod | Język |
|-----|-------|
| pl | Polski |
| en | English |
| es | Español |
| fr | Français |
| de | Deutsch |
| pt | Português |
| ru | Русский |
| uk | Українська |
| it | Italiano |
| nl | Nederlands |
| cs | Čeština |
| hu | Magyar |
| ro | Română |
| tr | Türkçe |
| el | Ελληνικά |
| ar | العربية |
| he | עברית |
| hi | हिन्दी |
| bn | বাংলা |
| ur | اردو |
| zh | 中文 |
| ja | 日本語 |
| ko | 한국어 |
| id | Bahasa Indonesia |
| vi | Tiếng Việt |
| th | ไทย |
| fa | فارسی |
| ta | தமிழ் |
| te | తెలుగు |
| mr | मराठी |

Język ustawia się też ręcznie w pliku `Kadr.ini` (`Language=pl`, kod z tabeli powyżej).

## Wymagania

- Windows XP SP3 x86 lub nowszy (działa też na Windows 10/11).
- Otwieranie DjVu korzysta z bibliotek w `deps\djvu\` (dołączone do repozytorium).
- Uwaga: dekoder DjVu to starszy DjVuLibre 3.5.27 — otwieraj tylko zaufane pliki (szczegóły w `THIRD-PARTY.txt`).

## Budowanie

```bat
build.cmd
```

Wymagania: Zig 0.11.0 rozpakowany w `tools\zig-windows-x86_64-0.11.0\`. Archiwum `tools\zig-0.11.0.zip` nie jest częścią repozytorium — pobierz je z <https://ziglang.org/download/0.11.0/zig-windows-x86_64-0.11.0.zip> (suma SHA-256 w `THIRD-PARTY.txt`) i rozpakuj do `tools\`.

Wynik: `Kadr.exe` (cel `x86-windows.xp`, Pentium III, `ReleaseSmall`) z poprawionym nagłówkiem XP. Regeneracja ikony: `tools\build_icon.cmd` (Pillow + windres/objcopy).

## Testy

- Zestawy kontrolne w podkatalogach `tests\` (codec, editor, export, image, loader, print-options, render) — każdy uruchamiany skryptem `check.cmd`; budują i odpalają harnessy w Zigu.
- Skrypty pomocnicze (Python 3): `tests\locale_coverage.py` (zgodność tłumaczeń 30 języków), `tests\audit_xp.py` (audyt zgodności binarek z XP), `tests\measure_print.py` (geometria wydruku), `tests\tooltip_probe.py`, `tests\shot.py`.
- `tests\generate_fixtures.py` generuje obrazy testowe — wymaga Pillow; używany tylko rozwojowo, nigdy przez `Kadr.exe`.

## Skróty klawiszowe

| Skrót | Działanie |
|-------|-----------|
| Ctrl+O | Otwórz |
| Ctrl+S / Ctrl+Shift+S | Zapisz / Zapisz jako |
| Ctrl+E | Edytor |
| Ctrl+C / Ctrl+Shift+C | Kopiuj / Kopiuj ścieżkę |
| Home / 1 / + / − | Dopasuj / 1:1 / Zoom |
| R / L | Obróć w prawo / w lewo |
| Spacja | Pauza (pokaz slajdów) |
| Ctrl+P | Drukuj |
| F2 | Zmień nazwę |
| Delete / Shift+Delete | Usuń do kosza / trwale |
| F5 / F11 / Esc | Pokaz slajdów / Pełny ekran / Zamknij |
| Page Up / Page Down | Strony TIFF / DjVu |

## Licencja

**GPL-3.0-or-later** — pełny tekst w pliku [`LICENSE`](LICENSE).

Zależności i licencje trzecie (DjVuLibre, VC100/GDI+, Zig): [`THIRD-PARTY.txt`](THIRD-PARTY.txt). Tekst GNU GPL v2 dla DjVuLibre: [`COPYING.txt`](COPYING.txt).
