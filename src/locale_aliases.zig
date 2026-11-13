// Polish source literals map to one shared translated vocabulary. GPL-3.0-or-later.
const std = @import("std");
const words = @import("locale_words.zig");
const editor_words = @import("locale_editor.zig");
pub const count = words.count;
pub const Entry = struct { source: []const u8, text: [count][]const u8 };
fn a(comptime source: []const u8, comptime key: words.Key) Entry {
    var text = words.row(key);
    text[0] = source;
    return .{ .source = source, .text = text };
}
fn d(comptime source: []const u8, comptime key: words.Key, comptime prefix: []const u8, comptime suffix: []const u8) Entry {
    var text = words.decorate(key, prefix, suffix);
    text[0] = source;
    return .{ .source = source, .text = text };
}
fn e(comptime source: []const u8, comptime key: editor_words.Key, comptime prefix: []const u8, comptime suffix: []const u8) Entry {
    const base = editor_words.row(key);
    var text: [count][]const u8 = undefined;
    inline for (0..count) |i| text[i] = std.fmt.comptimePrint("{s}{s}{s}", .{ prefix, base[i], suffix });
    text[0] = source;
    return .{ .source = source, .text = text };
}
fn fixed(comptime source: []const u8, comptime value: []const u8) Entry {
    return .{ .source = source, .text = [_][]const u8{value} ** count };
}
const common = blk: {
    @setEvalBranchQuota(10000000);
    var result: [100]Entry = undefined;
    for (0..100) |i| {
        const key: words.Key = @enumFromInt(i);
        const values = words.row(key);
        result[i] = .{ .source = values[0], .text = values };
    }
    break :blk result;
};
fn helpTexts() [count][]const u8 {
    @setEvalBranchQuota(10000000);
    var result: [count][]const u8 = undefined;
    const open = words.row(.open);
    const save = words.row(.save);
    const edit = editor_words.row(.edit);
    const save_as = words.row(.save_as);
    const copy = words.row(.copy);
    const path = words.row(.copy_path);
    const previous = words.row(.previous);
    const next = words.row(.next);
    const fit = words.row(.fit);
    const rotate = words.row(.rotate);
    const rotate_left = editor_words.row(.rotate_left);
    const pause = words.row(.pause);
    const print = words.row(.print);
    const rename = words.row(.rename);
    const recycle = words.row(.recycle);
    const permanent = words.row(.permanent);
    const fullscreen = words.row(.fullscreen);
    const slideshow = words.row(.slideshow);
    const more = words.row(.more);
    const trusted = words.row(.trusted_files);
    inline for (0..count) |i| {
        result[i] = std.fmt.comptimePrint("Kadr\n\nCtrl+O — {s}\nCtrl+S — {s}\nCtrl+Shift+S — {s}\nCtrl+E — {s}\nCtrl+C — {s}\nCtrl+Shift+C — {s}\n← / → — {s} / {s}\nHome — {s}; 1 — 1:1; + / −\nR — {s}; L — {s}\nSpace — {s}\nCtrl+P — {s}\nF2 — {s}\nDelete — {s}\nShift+Delete — {s}\nF5 — {s}; F11 — {s}; Esc\nShift+F10 — {s}\nPage Up / Page Down — TIFF / DjVu\nZoom: 125%, 37.5%, 200×; Enter / Esc\n\n{s}\n\nWindows XP SP3 x86 · Zig / Win32 / GDI+\nGPL-3.0-or-later", .{ open[i], save[i], save_as[i], edit[i], copy[i], path[i], previous[i], next[i], fit[i], rotate[i], rotate_left[i], pause[i], print[i], rename[i], recycle[i], permanent[i], slideshow[i], fullscreen[i], more[i], trusted[i] });
    }
    return result;
}
const aliases = [_]Entry{
    fixed("Filtr obrazów", "PNG / JPEG / BMP / GIF / TIFF / DjVu / ICO / TGA / PCX / PSD / PNM / QOI\x00*.png;*.jpg;*.jpeg;*.jpe;*.jfif;*.jif;*.bmp;*.dib;*.gif;*.tif;*.tiff;*.djvu;*.djv;*.ico;*.wmf;*.emf;*.tga;*.targa;*.pcx;*.psd;*.pbm;*.pgm;*.ppm;*.pnm;*.qoi\x00JPEG / JFIF\x00*.jpg;*.jpeg;*.jpe;*.jfif;*.jif\x00PNG\x00*.png\x00BMP / DIB\x00*.bmp;*.dib\x00GIF\x00*.gif\x00TIFF\x00*.tif;*.tiff\x00DjVu\x00*.djvu;*.djv\x00ICO\x00*.ico\x00WMF / EMF\x00*.wmf;*.emf\x00Targa\x00*.tga;*.targa\x00PCX\x00*.pcx\x00PSD\x00*.psd\x00PNM / PBM / PGM / PPM\x00*.pnm;*.pbm;*.pgm;*.ppm\x00QOI\x00*.qoi\x00*.*\x00*.*\x00\x00"),
    a("Wybierz język. Zmiana będzie widoczna po ponownym uruchomieniu programu.", .restart),
    a("Nie można zapisać pliku Kadr.ini obok programu. Sprawdź uprawnienia do folderu. Ustawienia nie zostały zapisane.", .settings_error),
    a("Zapisano język. Uruchom ponownie program Kadr, aby zastosować zmianę.", .restart),
    a("Nie można otworzyć okna wyboru języka.", .io_error),
    d("Kadr — przeglądarka zdjęć", .photos, "Kadr — ", ""),
    d("Kadr — otwórz obraz", .open, "Kadr — ", ""),
    d("Kadr — zapisz kopię obrazu", .save_as, "Kadr — ", ""),
    d("Kadr — zapisz obrót", .save, "Kadr — ", ""),
    d("Kadr — potwierdź nadpisanie", .save, "Kadr — ", ""),
    d("Kadr — zmień nazwę", .rename, "Kadr — ", ""),
    d("Kadr — niepoprawna nazwa", .invalid_values, "Kadr — ", ""),
    d("Kadr — usuń do Kosza", .recycle, "Kadr — ", ""),
    d("Kadr — usuń trwale", .permanent, "Kadr — ", ""),
    d("Kadr — podgląd wydruku", .print, "Kadr — ", ""),
    d("Kadr — język", .language, "Kadr — ", ""),
    d("Kadr — eksport obrazu", .export_image, "Kadr — ", ""),
    d("Kadr — tapeta", .wallpaper, "Kadr — ", ""),
    a("Gotowy na Twoje zdjęcia. Przeciągnij plik do okna.", .ready_drop),
    a("Przeciągnij plik tutaj lub wybierz zdjęcie z dysku.", .drag_hint),
    a("Wczytywanie… Bieżące zdjęcie pozostaje dostępne.", .loading),
    a("Pominięto nieczytelne lub brakujące pliki. Brak dalszych zdjęć w tym kierunku.", .skipped),
    a("Zapisano kopię obrazu. Oryginał nie został zmieniony.", .saved_copy),
    a("Skopiowano cały obraz do schowka (z bieżącym obrotem).", .copied),
    a("Skopiowano ścieżkę do schowka.", .copied),
    a("Obróć", .rotate),
    a("Pokaz", .slideshow),
    a("Ustaw zoom", .apply),
    a("Zoom", .scale),
    a("Pomoc", .help),
    a("Nowa nazwa pliku (z rozszerzeniem):", .new_name),
    d("Otwórz…\tCtrl+O", .open, "", "…\tCtrl+O"),
    d("Zapisz\tCtrl+S", .save, "", "\tCtrl+S"),
    d("Zapisz jako…\tCtrl+Shift+S", .save_as, "", "…\tCtrl+Shift+S"),
    d("Zapisz jako…\tCtrl+S", .save_as, "", "…\tCtrl+Shift+S"),
    d("Zapisz obrót w pliku…", .save, "", "…"),
    d("Kopiuj obraz\tCtrl+C", .copy, "", "\tCtrl+C"),
    d("Kopiuj ścieżkę\tCtrl+Shift+C", .copy_path, "", "\tCtrl+Shift+C"),
    d("Zmień nazwę…\tF2", .rename, "", "…\tF2"),
    d("Usuń do Kosza…\tDelete", .recycle, "", "…\tDelete"),
    d("Usuń trwale…\tShift+Delete", .permanent, "", "…\tShift+Delete"),
    d("Obróć w prawo\tR", .rotate, "", "\tR"),
    d("Drukuj…\tCtrl+P", .print, "", "…\tCtrl+P"),
    d("Pełny ekran\tF11", .fullscreen, "", "\tF11"),
    d("Pomoc i skróty\tF1", .help, "", "\tF1"),
    d("Język / Language…", .language, "", " / Language…"),
    d("Eksport / kompresja…", .export_image, "", "…"),
    d("Ustaw jako tapetę…", .wallpaper, "", "…"),
    d("Otwórz obraz z dysku (Ctrl+O)", .open, "", " (Ctrl+O)"),
    d("Poprzednie zdjęcie w folderze (←)", .previous, "", " (←)"),
    d("Następne zdjęcie w folderze (→)", .next, "", " (→)"),
    d("Pokaż całe zdjęcie (Home)", .fit, "", " (Home)"),
    d("Rzeczywisty rozmiar — jeden piksel obrazu na piksel ekranu (1)", .actual, "", " (1:1)"),
    d("Pomniejsz (− / kółko myszy)", .zoom_out, "", " (−)"),
    d("Powiększ (+ / kółko myszy)", .zoom_in, "", " (+)"),
    d("Obróć widok w prawo — bez zmiany pliku (R)", .rotate, "", " (R)"),
    d("Odtwarzaj / zatrzymaj animację (Spacja)", .pause, "", " (Space)"),
    d("Ułóż zdjęcie na kartce i wydrukuj (Ctrl+P)", .print, "", " (Ctrl+P)"),
    d("Pełny ekran (F11), powrót (Esc)", .fullscreen, "", " (F11 / Esc)"),
    d("Operacje na zdjęciu: zapis obrotu, schowek, nazwa, Kosz i folder (Shift+F10)", .more, "", " (Shift+F10)"),
    d("Poprzednia strona dokumentu (Page Up)", .previous_page, "", " (Page Up)"),
    d("Następna strona dokumentu (Page Down)", .next_page, "", " (Page Down)"),
    d("Pokaz slajdów co cztery sekundy (F5)", .slideshow, "", " (F5)"),
    d("Otwórz obraz z dysku", .open, "", " (Ctrl+O)"),
    d("Zatwierdź wpisany zoom (Enter); Esc przywraca bieżącą wartość", .apply, "", " (Enter / Esc)"),
    d("Zapisz bieżący obrót w tym samym pliku (Ctrl+S)", .save, "", " (Ctrl+S)"),
    d("Zapisz kopię obrazu z bieżącym obrotem (Ctrl+S)", .save_as, "", " (Ctrl+Shift+S)"),
    d("Wpisz dodatni zoom, np. 125%, 37,5% lub 200×. Enter zatwierdza, Esc cofa.", .invalid_values, "", "\n125% / 37.5% / 200× · Enter / Esc"),
    fixed("Ctrl+O — otwórz   ·   F1 — pomoc", "Ctrl+O · F1"),
    a("Nie można odczytać ścieżki pliku.", .io_error),
    a("Nie można zlecić wczytania obrazu.", .io_error),
    a("Nie udało się otworzyć tego pliku. Bieżące zdjęcie pozostaje nietknięte.\n\nPlik może być uszkodzony lub mieć nieobsługiwany wariant formatu. DjVu wymaga folderu deps\\djvu. PDF, RAW, WebP, AVIF i HEIC nie są obsługiwane.", .io_error),
    a("Nie można utworzyć pliku tymczasowego. Wybierz krótszą ścieżkę zapisu.", .io_error),
    a("Nie można utworzyć pliku tymczasowego w folderze docelowym. Sprawdź uprawnienia.", .io_error),
    a("Nie udało się zapisać obrazu. Plik docelowy nie został zmieniony.", .io_error),
    a("Nie można zwolnić pliku źródłowego. Zapisz obraz pod inną nazwą.", .use_save_as),
    a("Nie można zastąpić pliku docelowego. Sprawdź uprawnienia i czy plik nie jest używany. Bieżący obraz pozostaje w pamięci.", .io_error),
    a("Zapisana zostanie tylko bieżąca klatka lub strona, bez animacji i pozostałych stron. Kontynuować?", .single_frame),
    a("Wybierz rozszerzenie PNG, JPG, BMP, TIFF lub GIF. Format zapisu wynika z rozszerzenia pliku.", .use_save_as),
    a("Nie nadpisuj animacji ani dokumentu wielostronicowego pojedynczym obrazem. Wybierz nową nazwę pliku.", .use_save_as),
    a("Ten format, animacja lub dokument wielostronicowy nie może być nadpisany pojedynczym obrazem. Użyj Zapisz jako (Ctrl+Shift+S) i nowej nazwy z rozszerzeniem PNG, JPG, BMP, TIFF lub GIF, aby zachować oryginał.", .use_save_as),
    a("Plik docelowy już istnieje. Zastąpić go bieżącym obrazem?\n\nZapis może usunąć metadane; JPEG zostanie ponownie skompresowany.", .overwrite),
    a("Nadpisać plik obróconym obrazem?\n\nZapis może usunąć metadane, a JPEG zostanie ponownie skompresowany. Aby zachować oryginał, wybierz Nie i użyj Zapisz jako.", .overwrite),
    a("Nie udało się skopiować obrazu. Schowek może być używany przez inny program.", .io_error),
    a("Nowa ścieżka jest zbyt długa.", .io_error),
    a("Nie można przygotować obrazu do zmiany nazwy. Plik nie został zmieniony.", .io_error),
    a("Nie można zmienić nazwy. Sprawdź, czy nazwa nie jest już zajęta i czy masz uprawnienia do pliku.", .io_error),
    d("Przenieść ten plik do Kosza?\n\n", .confirm_recycle, "", "\n\n"),
    d("Trwale usunąć ten plik?\nPlik NIE trafi do Kosza. Tej operacji nie można cofnąć!\n\n", .confirm_permanent, "", "\n\n"),
    a("Nie można zwolnić pliku. Zdjęcie nie zostało usunięte.", .io_error),
    a("Nie udało się trwale usunąć pliku. Sprawdź uprawnienia, atrybut tylko do odczytu i czy plik nie jest używany.", .io_error),
    a("Nie udało się przenieść pliku do Kosza. Sprawdź uprawnienia i czy plik nie jest używany.", .io_error),
    a("Nie można otworzyć folderu w Eksploratorze.", .io_error),
    a("Wpisz poprawną nazwę pliku. Nie używaj znaków \\ / : * ? \" < > |, nazw urządzeń ani kropki lub spacji na końcu.", .invalid_values),
    a("Nie można uruchomić GDI+. Ten program wymaga Windows XP lub nowszego.", .io_error),
    a("Nie można uruchomić wątku wczytywania obrazów.", .io_error),
    a("Wybierz drukarkę…", .choose_printer),
    a("Drukarka i papier", .printer),
    a("Bez drukarki", .no_printer),
    a("Podgląd poglądowy — bez drukarki", .no_printer),
    a("Dopasuj — cały obraz", .fit),
    a("Wypełnij — przytnij brzegi", .fill),
    d("100% — 96 DPI", .actual, "100% · ", " (96 DPI)"),
    a("Wyśrodkuj zdjęcie", .center),
    d("Marginesy (mm)", .margins, "", " (mm)"),
    d("Położenie (mm)", .position, "", " (mm)"),
    d("Szerokość (mm)", .width, "", " (mm)"),
    d("Wysokość (mm)", .height, "", " (mm)"),
    a("Pionowo", .portrait),
    a("Poziomo", .landscape),
    a("Czarno-białe", .grayscale),
    a("Więcej ustawień", .advanced),
    a("Ukryj ustawienia", .advanced),
    d("Skala (%)", .scale, "", " (%)"),
    d("Własny rozmiar (mm)", .custom_size, "", " (mm)"),
    a("Własny (%)", .custom_percent),
    a("Zachowaj proporcje zdjęcia", .keep_aspect),
    a("Uruchom ponownie Kadr, aby zmienić język.", .restart),
    a("Nie można zapisać ustawień obok pliku EXE. Sprawdź uprawnienia do folderu programu.", .settings_error),
    a("Język interfejsu", .language),
    a("Zmień język", .language),
    d("Wybierz język", .language, "", ":"),
    a("Skala szarości", .grayscale),
    a("Jakość JPEG (1–100)", .quality),
    a("Sprawdź rozmiar pliku", .estimate),
    a("Szacowany rozmiar", .file_size),
    a("Ustaw tapetę", .wallpaper),
    a("Wypełnij", .fill),
    a("Środek", .center),
    a("Ustaw bieżące zdjęcie jako tapetę?", .confirm_wallpaper),
    d(" · dopasowanie", .fit_state, " · ", ""),
    d("    ·    animacja", .animation, "    ·    ", ""),
    d("    ·    animacja wstrzymana", .paused_state, "    ·    ", ""),
    d("    ·    pokaz co 4 s", .slideshow_state, "    ·    ", ""),
    d("Kadr — zapisz jako", .save_as, "Kadr — ", ""),
    d("Wybierz zdjęcie z dysku (Ctrl+O)", .choose_image, "", " (Ctrl+O)"),
    d("Zapisz obrót w bieżącym pliku (Ctrl+S)", .save, "", " (Ctrl+S)"),
    a("Brak obrazu do wydrukowania.", .io_error),
    a("Nie można przygotować obrazu do podglądu wydruku.", .io_error),
    a("Nie można utworzyć okna podglądu wydruku.", .io_error),
    a("Nie można utworzyć kontrolek podglądu wydruku.", .io_error),
    d("Kadr — drukowanie", .print, "Kadr — ", ""),
    d("Drukarka:", .printer, "", ":"),
    a("Nie wybrano", .no_printer),
    d("Wybierz…", .choose_printer, "", "…"),
    a("Wybierz drukarkę. Nie rozpoczyna drukowania.", .choose_printer),
    d("Papier:", .paper, "", ":"),
    d("Orientacja:", .orientation, "", ":"),
    d("Skala obrazu:", .scale, "", ":"),
    d("Kolor:", .color, "", ":"),
    fixed("4 × 6 cali", "4 × 6 in"),
    fixed("5 × 7 cali", "5 × 7 in"),
    fixed("8 × 10 cali", "8 × 10 in"),
    d("Własny (mm)", .custom_size, "", " (mm)"),
    a("Z drukarki", .printer),
    a("Dopasuj (cały obraz)", .fit),
    a("Wypełnij (przytnij)", .fill),
    d("100% (96 DPI)", .actual, "100% · ", " (96 DPI)"),
    d("Zaawansowane ▸", .advanced, "", " ▸"),
    d("Zaawansowane ▾", .advanced, "", " ▾"),
    d("Wartość skali:", .scale, "", ":"),
    d("Papier mm:", .paper, "", " (mm):"),
    d("Marginesy (mm):", .margins, "", " (mm):"),
    d("Lewy:", .left, "", ":"),
    d("Prawy:", .right, "", ":"),
    d("Górny:", .top, "", ":"),
    d("Dolny:", .bottom, "", ":"),
    d("Pozycja od rogu arkusza (mm):", .position, "", " (X/Y, mm):"),
    a("Wyśrodkuj / reset pozycji", .center),
    a("Wydrukuj bieżący układ po potwierdzeniu.", .print),
    a("Zamknij podgląd; podczas drukowania przerwij zadanie.", .close),
    d("100% i własny procent: 1 piksel = 1/96 cala. Wymiary w mm zachowują proporcje.", .scale, "", " · 100% = 96 DPI · mm"),
    d("Procent: 0,1–1000. Wymiar: 0,1–10000 mm. Proporcje są zablokowane.", .keep_aspect, "", " · 0.1–1000% · 0.1–10000 mm"),
    d("Własny papier: szerokość i wysokość 10–3276,7 mm, przed obrotem.", .custom_size, "", " · 10–3276.7 mm"),
    d("Od lewego górnego rogu fizycznego arkusza, nie od marginesów. Zakres ±10000 mm.", .position, "", " · X/Y · ±10000 mm"),
    a("Dotyczy tylko podglądu i wydruku. Obraz źródłowy pozostaje bez zmian.", .color),
    a("Arkusz / obraz. Szara linia: granica drukarki. Zielona: marginesy.", .margins),
    d("Przerywanie zadania drukowania…", .stop, "", "…"),
    d("Procent (96 DPI):", .percent, "", " (96 DPI):"),
    d("Szerokość (mm):", .width, "", " (mm):"),
    d("Wysokość (mm):", .height, "", " (mm):"),
    a("Popraw liczby. Zachowano ostatni poprawny podgląd.", .invalid_values),
    a("Obraz poza obszarem druku. Zmień marginesy lub wyśrodkuj.", .invalid_values),
    a("Wybierz drukarkę, aby sprawdzić rzeczywisty obszar druku.", .choose_printer),
    a("Nie przyjęto ustawień. Wybierz drukarkę ponownie.", .io_error),
    a("Sterownik zmienił format. Podgląd pokazuje przyjęty arkusz.", .paper),
    a("Drukarka przyjęła skalę szarości zamiast koloru.", .grayscale),
    a("Część obrazu zostanie przycięta do obszaru druku.", .fill),
    a("Obraz mieści się w obszarze druku.", .fit),
    a("Nie można otworzyć ustawień drukarki. Sprawdź, czy drukarka jest zainstalowana i dostępna.", .io_error),
    a("Drukarka nie udostępnia poprawnego rozmiaru papieru lub obszaru druku. Nie rozpoczęto drukowania.", .io_error),
    a("Sterownik odrzucił papier. Zachowano przyjęty arkusz.", .paper),
    a("Ustawienia wydruku", .settings),
    a("Podgląd wydruku", .print),
    a("Nie udało się narysować obrazu.", .io_error),
    a("Przeciągnij obraz na arkuszu. Linie pomocnicze nie są drukowane.", .position),
    d("Kadr — fotografia", .photos, "Kadr — ", ""),
    d("Wydrukować stronę według podglądu?", .print, "", "?"),
    d("Kadr — potwierdź wydruk", .print, "Kadr — ", ""),
    a("Przerwij", .stop),
    a("Wysyłanie strony do drukarki…", .printing),
    a("Strona została przekazana do kolejki drukarki.", .printed),
    a("Anulowano zadanie drukowania.", .cancel),
    a("Nie udało się przekazać strony do drukarki. Zadanie przerwano. Sprawdź drukarkę i jej kolejkę.", .io_error),
    a("Ścieżka jest za długa dla eksportu w Windows XP.", .io_error),
    a("Nie można utworzyć pliku tymczasowego w folderze źródłowym.", .io_error),
    a("Nie udało się obliczyć rozmiaru kopii.", .io_error),
    a("Nie udało się odczytać rozmiaru pliku.", .io_error),
    d("Kadr — eksportuj nową kopię", .export_image, "Kadr — ", ""),
    a("Nie można otworzyć okna wyboru pliku.", .io_error),
    a("Eksport tworzy nową kopię. Aby zmienić oryginał, użyj polecenia Zapisz.", .use_save_as),
    a("Rozszerzenie pliku musi odpowiadać wybranemu formatowi.", .invalid_values),
    a("Plik docelowy już istnieje. Czy na pewno zastąpić go nową kopią?", .overwrite),
    d("Kadr — zastąpienie kopii", .save_as, "Kadr — ", ""),
    a("Eksport nie nadpisuje źródła. Użyj polecenia Zapisz lub wybierz nową nazwę.", .use_save_as),
    a("Nie zapisano kopii. Cel mógł pojawić się w trakcie zapisu lub jest chroniony. Wybierz inną nazwę.", .io_error),
    a("Brak możliwości zapisu w folderze docelowym. Wybierz zapisywalny folder.", .io_error),
    a("Nie udało się wyeksportować kopii. Sprawdź ustawienia, ścieżkę i wolne miejsce.", .io_error),
    a("Eksportuj bieżący obraz do nowej kopii", .export_image),
    d("&Format:", .format, "&", ":"),
    fixed("GIF — jedna klatka", "GIF"),
    d("&Jakość JPEG (1–100):", .quality, "&", " (1–100):"),
    d("&Szerokość (px):", .width, "&", " (px):"),
    d("&Wysokość (px):", .height, "&", " (px):"),
    a("Zachowaj &proporcje", .keep_aspect),
    d("Limit kopii: 64 mln pikseli. PNG/TIFF zachowują przezroczystość; JPEG ma białe tło. Bez metadanych, animacji i pozostałych stron.", .dimensions, "", " ≤64 MP · PNG/TIFF α · JPEG RGB"),
    a("Sprawdź &rozmiar", .estimate),
    a("Rozmiar pliku jest liczony tylko na żądanie.", .estimate),
    d("&Eksportuj…", .save_as, "&", "…"),
    a("Ustawienia zmienione. Sprawdź rozmiar ponownie, jeśli jest potrzebny.", .estimate),
    a("Podaj dodatnie całkowite wymiary (do 64 mln pikseli) i jakość JPEG od 1 do 100.", .invalid_values),
    d("Kadr — eksportuj kopię", .export_image, "Kadr — ", ""),
    a("Nie można odczytać bieżącej tapety. Nie zmieniono ustawień.", .io_error),
    a("Nie znaleziono bezpiecznej nazwy kopii tapety obok programu.", .io_error),
    a("Nie można zapisać tapety obok programu. Folder programu musi być zapisywalny; Kadr nie używa AppData.", .io_error),
    a("Nie udało się utworzyć kopii BMP tapety. Ustawienia nie zostały zmienione.", .io_error),
    a("Bieżąca tapeta zmieniła się w trakcie przygotowania. Spróbuj ponownie.", .io_error),
    a("Nie można zapisać kopii tapety w folderze programu. Ustawienia nie zostały zmienione.", .io_error),
    a("Windows nie przyjął nowej tapety. Poprzedni aktywny plik nie został nadpisany.", .io_error),
    d("&Sposób ułożenia na głównym ekranie:", .position, "&", ":"),
    a("Dopasuj — cały obraz, białe marginesy", .wallpaper_fit),
    a("Wypełnij — przytnij do ekranu", .fill),
    a("Rozciągnij — bez zachowania proporcji", .stretch),
    a("Wyśrodkuj — bez skalowania", .center),
    a("Kadr utworzy kopię BMP obok programu. Źródło pozostanie bez zmian. Ustawienia pulpitu zmienią się dopiero po dodatkowym potwierdzeniu.", .confirm_wallpaper),
    d("&Ustaw tapetę…", .apply, "&", "…"),
    a("Czy na pewno zmienić tapetę pulpitu Windows? Wybrany układ zostanie zapisany jako kopia BMP obok programu.", .confirm_wallpaper),
    d("Kadr — potwierdź zmianę tapety", .wallpaper, "Kadr — ", ""),
    d("Kadr — tapeta pulpitu", .wallpaper, "Kadr — ", ""),
    .{ .source = "Nie można skopiować ścieżki do schowka.", .text = .{ "Nie można skopiować ścieżki do schowka.", "Could not copy the path to the clipboard.", "No se pudo copiar la ruta al portapapeles.", "Impossible de copier le chemin dans le presse-papiers.", "Der Pfad konnte nicht in die Zwischenablage kopiert werden.", "Não foi possível copiar o caminho para a área de transferência.", "Не удалось скопировать путь в буфер обмена.", "Не вдалося скопіювати шлях до буфера обміну.", "Impossibile copiare il percorso negli appunti.", "Het pad kan niet naar het klembord worden gekopieerd.", "Cestu nelze zkopírovat do schránky.", "Az elérési út nem másolható a vágólapra.", "Calea nu a putut fi copiată în clipboard.", "Yol panoya kopyalanamadı.", "Δεν ήταν δυνατή η αντιγραφή της διαδρομής στο πρόχειρο.", "تعذر نسخ المسار إلى الحافظة.", "לא ניתן להעתיק את הנתיב ללוח.", "पथ क्लिपबोर्ड पर कॉपी नहीं हो सका।", "পথ ক্লিপবোর্ডে কপি করা যায়নি।", "راستہ کلپ بورڈ میں نقل نہیں ہو سکا۔", "无法将路径复制到剪贴板。", "パスをクリップボードにコピーできません。", "경로를 클립보드에 복사할 수 없습니다.", "Tidak dapat menyalin jalur ke papan klip.", "Không thể sao chép đường dẫn vào bộ nhớ tạm.", "ไม่สามารถคัดลอกพาธไปยังคลิปบอร์ดได้", "کپی مسیر در کلیپ‌بورد ممکن نیست.", "பாதையைப் பிடிப்புப்பலகைக்கு நகலெடுக்க முடியவில்லை.", "పాత్‌ను క్లిప్‌బోర్డ్‌కు కాపీ చేయలేకపోయాం.", "मार्ग क्लिपबोर्डवर कॉपी करता आला नाही." } },
    e("Edycja zdjęcia", .edit, "", ""),
    e("Kadr — edycja zdjęcia", .edit, "Kadr — ", ""),
    e("Edytuj zdjęcie…\tCtrl+E", .edit, "", "…\tCtrl+E"),
    e("Jasność", .brightness, "", ""),
    e("Kontrast", .contrast, "", ""),
    e("Nasycenie", .saturation, "", ""),
    e("Obróć w lewo", .rotate_left, "", ""),
    e("Odbij poziomo", .flip_h, "", ""),
    e("Odbij pionowo", .flip_v, "", ""),
    e("Kadrowanie: zaznacz obszar na zdjęciu lub wpisz piksele.", .crop_hint, "", ""),
    e("Zmiany są w pamięci. Plik zmieni się dopiero po zapisaniu.", .memory_hint, "", ""),
    e("Są niezapisane zmiany. Kontynuować bez zapisywania?\n\nAby je zachować, wybierz Anuluj i użyj Zapisz (Ctrl+S) lub Zapisz jako (Ctrl+Shift+S).", .unsaved, "", ""),
    e("Kadr — niezapisane zmiany", .edit, "Kadr — ", ""),
    d("Kadr — zapisz zmiany", .save, "Kadr — ", ""),
    a("Nadpisać plik zmienionym obrazem?\n\nZapis może usunąć metadane, a JPEG zostanie ponownie skompresowany. Aby zachować oryginał, wybierz Nie i użyj Zapisz jako.", .overwrite),
    a("Edycja dotyczy tylko bieżącej klatki lub strony. Wynik zapisz pod nową nazwą, aby zachować cały dokument.", .single_frame),
    a("Nie udało się przygotować podglądu.", .io_error),
    a("Nie udało się zastosować zmian. Obraz źródłowy jest nietknięty.", .io_error),
    a("Podaj obszar mieszczący się w zdjęciu (w pikselach).", .invalid_values),
    d("Szerokość:", .width, "", ":"),
    d("Wysokość:", .height, "", ":"),
    a("Resetuj", .reset),
    .{ .source = "Skróty Kadra", .text = helpTexts() },
    e("Obróć w lewo\tL", .rotate_left, "", "\tL"),
};
/// Editor/print additions (2026-11): Polish source and English; the other
/// languages show the English text until translated.
fn english(comptime source: []const u8, comptime value: []const u8) [count][]const u8 {
    var text = [_][]const u8{value} ** count;
    text[0] = source;
    return text;
}
const additions = [_]Entry{
    .{ .source = "Obraz rozciągnięty na cały obszar druku (bez zachowania proporcji).", .text = english("Obraz rozciągnięty na cały obszar druku (bez zachowania proporcji).", "Image stretched over the whole printable area (aspect ratio not kept).") },
    .{ .source = "Rozciągnij (cała strona)", .text = english("Rozciągnij (cała strona)", "Stretch (whole page)") },
    .{ .source = "Rzeczywisty rozmiar (1:1)\t1", .text = english("Rzeczywisty rozmiar (1:1)\t1", "Actual size (1:1)\t1") },
    .{ .source = "Pokaz slajdów\tF5", .text = english("Pokaz slajdów\tF5", "Slideshow\tF5") },
    .{ .source = "Edytuj", .text = english("Edytuj", "Edit") },
    .{ .source = "Kadrowanie, pisak, zakreślacz, kształty i tekst (Ctrl+E)", .text = english("Kadrowanie, pisak, zakreślacz, kształty i tekst (Ctrl+E)", "Crop, pen, highlighter, shapes and text (Ctrl+E)") },
    .{ .source = "Zaznacz mniejszy obszar — ramka obejmuje całe zdjęcie.", .text = english("Zaznacz mniejszy obszar — ramka obejmuje całe zdjęcie.", "Select a smaller area — the frame covers the whole photo.") },
    .{ .source = "Przycięto. Ctrl+Z cofa zmianę.", .text = english("Przycięto. Ctrl+Z cofa zmianę.", "Cropped. Ctrl+Z undoes it.") },
    .{ .source = "Ustaw ramkę — przyciemnione pole zostanie odcięte.", .text = english("Ustaw ramkę — przyciemnione pole zostanie odcięte.", "Set the frame — the dimmed area will be cut off.") },
    .{ .source = "Pisak: rysuj myszą po zdjęciu. Kolor i grubość wybierz po lewej.", .text = english("Pisak: rysuj myszą po zdjęciu. Kolor i grubość wybierz po lewej.", "Pen: draw on the photo with the mouse. Pick colour and size on the left.") },
    .{ .source = "Zakreślacz: półprzezroczysty flamaster — tekst pod nim pozostaje widoczny.", .text = english("Zakreślacz: półprzezroczysty flamaster — tekst pod nim pozostaje widoczny.", "Highlighter: a translucent marker — what is underneath stays visible.") },
    .{ .source = "Gumka: ściera rysunki i napisy, zdjęcie pozostaje nietknięte.", .text = english("Gumka: ściera rysunki i napisy, zdjęcie pozostaje nietknięte.", "Eraser: removes drawings and text; the photo stays untouched.") },
    .{ .source = "Linia: przeciągnij od początku do końca.", .text = english("Linia: przeciągnij od początku do końca.", "Line: drag from start to end.") },
    .{ .source = "Strzałka: przeciągnij od początku do grotu.", .text = english("Strzałka: przeciągnij od początku do grotu.", "Arrow: drag from the start to the tip.") },
    .{ .source = "Prostokąt: przeciągnij po przekątnej.", .text = english("Prostokąt: przeciągnij po przekątnej.", "Rectangle: drag diagonally.") },
    .{ .source = "Tekst: kliknij miejsce na zdjęciu i pisz. Enter — gotowe, Esc — anuluj.", .text = english("Tekst: kliknij miejsce na zdjęciu i pisz. Enter — gotowe, Esc — anuluj.", "Text: click on the photo and type. Enter — done, Esc — cancel.") },
    .{ .source = "Odrzucić zmiany wprowadzone w edytorze?", .text = english("Odrzucić zmiany wprowadzone w edytorze?", "Discard the changes made in the editor?") },
    .{ .source = "Narzędzia", .text = english("Narzędzia", "Tools") },
    .{ .source = "Proporcje", .text = english("Proporcje", "Aspect ratio") },
    .{ .source = "Zaznaczenie (px)", .text = english("Zaznaczenie (px)", "Selection (px)") },
    .{ .source = "Grubość", .text = english("Grubość", "Size") },
    .{ .source = "Obraz", .text = english("Obraz", "Image") },
    .{ .source = "Kolory i światło", .text = english("Kolory i światło", "Colour and light") },
    .{ .source = "Pisak", .text = english("Pisak", "Pen") },
    .{ .source = "Zakreślacz", .text = english("Zakreślacz", "Highlighter") },
    .{ .source = "Gumka", .text = english("Gumka", "Eraser") },
    .{ .source = "Linia", .text = english("Linia", "Line") },
    .{ .source = "Strzałka", .text = english("Strzałka", "Arrow") },
    .{ .source = "Prostokąt", .text = english("Prostokąt", "Rectangle") },
    .{ .source = "Tekst", .text = english("Tekst", "Text") },
    .{ .source = "Kadrowanie z podglądem na żywo (C)", .text = english("Kadrowanie z podglądem na żywo (C)", "Crop with live preview (C)") },
    .{ .source = "Pisak / flamaster (P)", .text = english("Pisak / flamaster (P)", "Pen / marker (P)") },
    .{ .source = "Zakreślacz — półprzezroczysty (H)", .text = english("Zakreślacz — półprzezroczysty (H)", "Highlighter — translucent (H)") },
    .{ .source = "Gumka — ściera rysunki (E)", .text = english("Gumka — ściera rysunki (E)", "Eraser — removes drawings (E)") },
    .{ .source = "Prosta linia (L)", .text = english("Prosta linia (L)", "Straight line (L)") },
    .{ .source = "Strzałka (A)", .text = english("Strzałka (A)", "Arrow (A)") },
    .{ .source = "Prostokąt (B)", .text = english("Prostokąt (B)", "Rectangle (B)") },
    .{ .source = "Napis na zdjęciu (T)", .text = english("Napis na zdjęciu (T)", "Text on the photo (T)") },
    .{ .source = "Dowolne", .text = english("Dowolne", "Free") },
    .{ .source = "Kwadrat 1:1", .text = english("Kwadrat 1:1", "Square 1:1") },
    .{ .source = "4:3 poziomo", .text = english("4:3 poziomo", "4:3 landscape") },
    .{ .source = "3:4 pionowo", .text = english("3:4 pionowo", "3:4 portrait") },
    .{ .source = "3:2 (10×15 poziomo)", .text = english("3:2 (10×15 poziomo)", "3:2 (4×6 landscape)") },
    .{ .source = "2:3 (10×15 pionowo)", .text = english("2:3 (10×15 pionowo)", "2:3 (4×6 portrait)") },
    .{ .source = "A4 pionowo", .text = english("A4 pionowo", "A4 portrait") },
    .{ .source = "A4 poziomo", .text = english("A4 poziomo", "A4 landscape") },
    .{ .source = "Odetnij przyciemnioną część (Enter)", .text = english("Odetnij przyciemnioną część (Enter)", "Cut off the dimmed part (Enter)") },
    .{ .source = "Całe zdjęcie", .text = english("Całe zdjęcie", "Whole photo") },
    .{ .source = "Zaznacz całe zdjęcie", .text = english("Zaznacz całe zdjęcie", "Select the whole photo") },
    .{ .source = "Cofnij", .text = english("Cofnij", "Undo") },
    .{ .source = "Cofnij (Ctrl+Z)", .text = english("Cofnij (Ctrl+Z)", "Undo (Ctrl+Z)") },
    .{ .source = "Ponów", .text = english("Ponów", "Redo") },
    .{ .source = "Ponów (Ctrl+Y)", .text = english("Ponów (Ctrl+Y)", "Redo (Ctrl+Y)") },
    .{ .source = "Obróć o 90° w lewo", .text = english("Obróć o 90° w lewo", "Rotate 90° left") },
    .{ .source = "Obróć o 90° w prawo", .text = english("Obróć o 90° w prawo", "Rotate 90° right") },
    .{ .source = "Odbicie lustrzane w poziomie", .text = english("Odbicie lustrzane w poziomie", "Mirror horizontally") },
    .{ .source = "Odbicie lustrzane w pionie", .text = english("Odbicie lustrzane w pionie", "Mirror vertically") },
    .{ .source = "Resetuj wszystko", .text = english("Resetuj wszystko", "Reset all") },
    .{ .source = "Przywróć oryginalne zdjęcie (można cofnąć)", .text = english("Przywróć oryginalne zdjęcie (można cofnąć)", "Restore the original photo (can be undone)") },
    .{ .source = "Zamknij edytor bez zmian (Esc)", .text = english("Zamknij edytor bez zmian (Esc)", "Close the editor without changes (Esc)") },
    .{ .source = "Zapisz jako…", .text = english("Zapisz jako…", "Save as…") },
    .{ .source = "Zastosuj zmiany i zapisz kopię pod nową nazwą", .text = english("Zastosuj zmiany i zapisz kopię pod nową nazwą", "Apply changes and save a copy under a new name") },
    .{ .source = "Drukuj…", .text = english("Drukuj…", "Print…") },
    .{ .source = "Zastosuj zmiany i przejdź do podglądu wydruku", .text = english("Zastosuj zmiany i przejdź do podglądu wydruku", "Apply changes and open the print preview") },
    .{ .source = "Zastosuj zmiany i wróć do przeglądarki", .text = english("Zastosuj zmiany i wróć do przeglądarki", "Apply changes and return to the viewer") },
};
/// Theme and update-check strings (2026-11), translated for all 30 languages.
/// Order: pl en es fr de pt ru uk it nl cs hu ro tr el ar he hi bn ur zh ja ko id vi th fa ta te mr.
fn all(comptime text: [count][]const u8) Entry {
    return .{ .source = text[0], .text = text };
}
const theme_entries = [_]Entry{
    // Editor crop tool label; previously skipped by the coverage check
    // (it starts with "Kadr"), so every language showed the Polish word.
    all(.{ "Kadruj", "Crop", "Recortar", "Rogner", "Zuschneiden", "Recortar", "Обрезка", "Обрізати", "Ritaglia", "Bijsnijden", "Oříznout", "Vágás", "Decupare", "Kırp", "Περικοπή", "قص", "חיתוך", "क्रॉप", "ক্রপ", "تراشیں", "裁剪", "トリミング", "자르기", "Pangkas", "Cắt", "ครอบตัด", "برش", "செதுக்கு", "కత్తిరించు", "क्रॉप" }),
    all(.{ "Motyw","Theme", "Tema", "Thème", "Design", "Tema", "Тема", "Тема", "Tema", "Thema", "Motiv", "Téma", "Temă", "Tema", "Θέμα", "السمة", "ערכת נושא", "थीम", "থিম", "تھیم", "主题", "テーマ", "테마", "Tema", "Chủ đề", "ธีม", "پوسته", "தீம்", "థీమ్", "थीम" }),
    all(.{ "Jasny", "Light", "Claro", "Clair", "Hell", "Claro", "Светлая", "Світла", "Chiaro", "Licht", "Světlý", "Világos", "Luminoasă", "Açık", "Φωτεινό", "فاتح", "בהיר", "हल्की", "হালকা", "ہلکا", "浅色", "ライト", "밝게", "Terang", "Sáng", "สว่าง", "روشن", "ஒளி", "లైట్", "फिकट" }),
    all(.{ "Ciemny", "Dark", "Oscuro", "Sombre", "Dunkel", "Escuro", "Тёмная", "Темна", "Scuro", "Donker", "Tmavý", "Sötét", "Întunecată", "Koyu", "Σκοτεινό", "داكن", "כהה", "गहरी", "গাঢ়", "گہرا", "深色", "ダーク", "어둡게", "Gelap", "Tối", "มืด", "تیره", "இருள்", "డార్క్", "गडद" }),
    all(.{ "Automatyczny", "Automatic", "Automático", "Automatique", "Automatisch", "Automático", "Автоматически", "Автоматично", "Automatico", "Automatisch", "Automatický", "Automatikus", "Automată", "Otomatik", "Αυτόματο", "تلقائي", "אוטומטי", "स्वचालित", "স্বয়ংক্রিয়", "خودکار", "自动", "自動", "자동", "Otomatis", "Tự động", "อัตโนมัติ", "خودکار", "தானியங்கு", "ఆటోమేటిక్", "स्वयंचलित" }),
    all(.{ "Sprawdź aktualizacje…", "Check for updates…", "Buscar actualizaciones…", "Rechercher des mises à jour…", "Nach Updates suchen…", "Verificar atualizações…", "Проверить обновления…", "Перевірити оновлення…", "Controlla aggiornamenti…", "Controleren op updates…", "Zkontrolovat aktualizace…", "Frissítések keresése…", "Caută actualizări…", "Güncellemeleri denetle…", "Έλεγχος για ενημερώσεις…", "التحقق من التحديثات…", "בדיקת עדכונים…", "अपडेट जांचें…", "আপডেট দেখুন…", "اپ ڈیٹس چیک کریں…", "检查更新…", "更新を確認…", "업데이트 확인…", "Periksa pembaruan…", "Kiểm tra cập nhật…", "ตรวจหาการอัปเดต…", "بررسی به‌روزرسانی…", "புதுப்பிப்புகளைச் சரிபார்…", "నవీకరణల కోసం తనిఖీ…", "अद्यतने तपासा…" }),
    all(.{ "Nie można otworzyć strony w przeglądarce.", "Cannot open the page in the web browser.", "No se puede abrir la página en el navegador.", "Impossible d'ouvrir la page dans le navigateur.", "Die Seite kann nicht im Browser geöffnet werden.", "Não é possível abrir a página no navegador.", "Не удаётся открыть страницу в браузере.", "Не вдається відкрити сторінку в браузері.", "Impossibile aprire la pagina nel browser.", "Kan de pagina niet openen in de browser.", "Stránku nelze otevřít v prohlížeči.", "Az oldal nem nyitható meg a böngészőben.", "Pagina nu poate fi deschisă în browser.", "Sayfa tarayıcıda açılamıyor.", "Δεν είναι δυνατό το άνοιγμα της σελίδας στο πρόγραμμα περιήγησης.", "تعذر فتح الصفحة في المتصفح.", "לא ניתן לפתוח את הדף בדפדפן.", "ब्राउज़र में पेज नहीं खोला जा सका।", "ব্রাউজারে পৃষ্ঠাটি খোলা যায়নি।", "براؤزر میں صفحہ نہیں کھل سکا۔", "无法在浏览器中打开页面。", "ブラウザーでページを開けません。", "브라우저에서 페이지를 열 수 없습니다.", "Tidak dapat membuka halaman di peramban.", "Không thể mở trang trong trình duyệt.", "ไม่สามารถเปิดหน้าในเบราว์เซอร์ได้", "نمی‌توان صفحه را در مرورگر باز کرد.", "உலாவியில் பக்கத்தைத் திறக்க முடியவில்லை.", "బ్రౌజర్‌లో పేజీని తెరవడం సాధ్యం కాలేదు.", "ब्राउझरमध्ये पृष्ठ उघडता आले नाही." }),
    // Editor: custom colour (ChooseColor) next to the palette.
    all(.{ "Własny kolor…", "Custom colour…", "Color personalizado…", "Couleur personnalisée…", "Eigene Farbe…", "Cor personalizada…", "Свой цвет…", "Власний колір…", "Colore personalizzato…", "Eigen kleur…", "Vlastní barva…", "Egyéni szín…", "Culoare personalizată…", "Özel renk…", "Προσαρμοσμένο χρώμα…", "لون مخصص…", "צבע מותאם אישית…", "कस्टम रंग…", "কাস্টম রং…", "حسب منشا رنگ…", "自定义颜色…", "カスタム色…", "사용자 지정 색…", "Warna khusus…", "Màu tùy chỉnh…", "สีกำหนดเอง…", "رنگ دلخواه…", "தனிப்பயன் நிறம்…", "అనుకూల రంగు…", "सानुकूल रंग…" }),
};
pub const entries = common ++ aliases ++ additions ++ theme_entries;

test "source aliases are unique and all languages are present" {
    for (entries, 0..) |entry, i| {
        for (entry.text) |value| {
            try std.testing.expect(value.len > 0);
            try std.testing.expect(std.unicode.utf8ValidateSlice(value));
        }
        for (entries[i + 1 ..]) |other| {
            if (std.mem.eql(u8, entry.source, other.source)) {
                std.debug.print("Duplicate localization source: {s}\n", .{entry.source});
                return error.DuplicateSource;
            }
        }
    }
}
