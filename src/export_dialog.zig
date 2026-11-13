// Native export-copy dialog. SPDX-License-Identifier: GPL-3.0-or-later
//! Synchronous, UI-thread only, after GdiplusStartup. The caller should pause
//! playback/loading while show() is running. No source Image ownership is taken.
const std = @import("std");
const w = @import("win.zig");
const c = w.c;
const i18n = @import("i18n.zig");
const L = i18n.L;
const Image = @import("image.zig").Image;
const output = @import("output.zig");
const theme = @import("theme.zig");
const path_capacity = c.MAX_PATH; // GetTempFileNameW's XP contract, including NUL.
const class_name = L("KadrExportCopyWindow");
const id_format = 101;
const id_quality = 102;
const id_width = 103;
const id_height = 104;
const id_lock = 105;
const id_measure = 106;
const id_status = 107;
const kinds = [_]output.Format{ .png, .jpeg, .bmp, .tiff, .gif };

pub const CopyError = error{ InvalidPath, SameSource, InvalidOptions, WrongExtension, TargetExists, ReserveFailed, EncodeFailed, CommitFailed };

fn absolute(path: [*:0]const u16, buffer: []u16) ?[:0]const u16 {
    if (path[0] == 0 or buffer.len == 0) return null;
    const n = c.GetFullPathNameW(path, @intCast(buffer.len), buffer.ptr, null);
    if (n == 0 or n >= buffer.len) return null;
    return buffer[0..n :0];
}

fn identity(path: [*:0]const u16) ?c.BY_HANDLE_FILE_INFORMATION {
    const file = c.CreateFileW(path, 0, c.FILE_SHARE_READ | c.FILE_SHARE_WRITE | c.FILE_SHARE_DELETE, null, c.OPEN_EXISTING, c.FILE_FLAG_BACKUP_SEMANTICS, null);
    if (file == c.INVALID_HANDLE_VALUE) return null;
    defer _ = c.CloseHandle(file);
    var info: c.BY_HANDLE_FILE_INFORMATION = undefined;
    if (c.GetFileInformationByHandle(file, &info) == 0) return null;
    return info;
}

/// Includes canonical case-insensitive path equality and existing file IDs
/// (8.3 aliases, hard links, and paths through directory junctions).
pub fn sameFile(a: [*:0]const u16, b: [*:0]const u16) bool {
    var aa: [32768]u16 = undefined;
    var bb: [32768]u16 = undefined;
    const pa = absolute(a, &aa) orelse return false;
    const pb = absolute(b, &bb) orelse return false;
    if (c.lstrcmpiW(pa.ptr, pb.ptr) == 0) return true;
    const ia = identity(pa.ptr) orelse return false;
    const ib = identity(pb.ptr) orelse return false;
    return ia.dwVolumeSerialNumber == ib.dwVolumeSerialNumber and ia.nFileIndexHigh == ib.nFileIndexHigh and ia.nFileIndexLow == ib.nFileIndexLow;
}

fn parentPath(path: []const u16, buffer: []u16) ?[:0]const u16 {
    const slash = std.mem.lastIndexOfScalar(u16, path, '\\') orelse return null;
    // Preserve the slash of C:\\, and also allow UNC share roots.
    const n = slash + 1;
    if (n + 1 > buffer.len) return null;
    @memcpy(buffer[0..n], path[0..n]);
    buffer[n] = 0;
    return buffer[0..n :0];
}

fn reserve(folder: [*:0]const u16, buffer: *[path_capacity]u16) bool {
    return c.GetTempFileNameW(folder, L("kex"), 0, buffer) != 0;
}

/// Backend used by the dialog and independent tests. replace_authorized must
/// come from an explicit user confirmation, default No. False uses a genuinely
/// non-replacing rename even if a destination appears while encoding. The
/// reserved empty temporary file is always in the destination directory.
pub fn saveCopy(source: *const Image, source_path: [*:0]const u16, target_path: [*:0]const u16, kind: output.Format, options: output.ExportOptions, replace_authorized: bool) CopyError!void {
    if (!output.validOptions(source, options)) return error.InvalidOptions;
    var target_buffer: [path_capacity]u16 = undefined;
    const target = absolute(target_path, &target_buffer) orelse return error.InvalidPath;
    if (sameFile(source_path, target.ptr)) return error.SameSource;
    if (output.format(target) != kind) return error.WrongExtension;
    const attributes = c.GetFileAttributesW(target.ptr);
    if (attributes != c.INVALID_FILE_ATTRIBUTES) {
        if (attributes & c.FILE_ATTRIBUTE_DIRECTORY != 0) return error.InvalidPath;
        if (!replace_authorized) return error.TargetExists;
    }
    var folder_buffer: [path_capacity]u16 = undefined;
    const folder = parentPath(target, &folder_buffer) orelse return error.InvalidPath;
    var temp: [path_capacity]u16 = undefined;
    if (!reserve(folder.ptr, &temp)) return error.ReserveFailed;
    defer _ = c.DeleteFileW(&temp);
    if (!output.saveOptions(source, @ptrCast(&temp), kind, options)) return error.EncodeFailed;
    // Reject source aliases even if a destination was changed during encoding.
    if (sameFile(source_path, target.ptr)) return error.SameSource;
    const flags: c.DWORD = @as(c.DWORD, c.MOVEFILE_WRITE_THROUGH) | (if (replace_authorized) @as(c.DWORD, c.MOVEFILE_REPLACE_EXISTING) else 0);
    if (c.MoveFileExW(&temp, target.ptr, flags) == 0) return error.CommitFailed;
}

fn extension(kind: output.Format) [:0]const u16 {
    return switch (kind) { .png => L("png"), .jpeg => L("jpg"), .bmp => L("bmp"), .tiff => L("tif"), .gif => L("gif") };
}

/// Default copy name, beside the source. Does not create any files.
pub fn defaultPath(source_path: [*:0]const u16, kind: output.Format, buffer: []u16) ?[:0]const u16 {
    var full: [path_capacity]u16 = undefined;
    const path = absolute(source_path, &full) orelse return null;
    const slash = std.mem.lastIndexOfScalar(u16, path, '\\') orelse return null;
    const dot = std.mem.lastIndexOfScalar(u16, path[slash + 1 ..], '.');
    const end = if (dot) |d| (if (d == 0) path.len else slash + 1 + d) else path.len;
    const suffix = L("-export.");
    const ext = extension(kind);
    const n = end + suffix.len + ext.len;
    if (n + 1 > buffer.len) return null;
    @memcpy(buffer[0..end], path[0..end]);
    @memcpy(buffer[end..][0..suffix.len], suffix);
    @memcpy(buffer[end + suffix.len ..][0..ext.len], ext);
    buffer[n] = 0;
    return buffer[0..n :0];
}

/// Strict integer input: signs, decimals, NaN/Inf, whitespace, zero, overflow
/// and truncated text are all invalid rather than being silently clamped.
pub fn positiveInteger(text: []const u16) ?u32 {
    if (text.len == 0) return null;
    var result: u32 = 0;
    for (text) |ch| {
        if (ch < '0' or ch > '9') return null;
        result = std.math.mul(u32, result, 10) catch return null;
        result = std.math.add(u32, result, ch - '0') catch return null;
    }
    return if (result == 0) null else result;
}

const State = struct {
    source: *const Image,
    path: [*:0]const u16,
    hwnd: c.HWND = null,
    done: bool = false,
    saved: bool = false,
    updating: bool = false,

    fn text(self: *State, value: [*c]const u16) void {
        _ = c.SetDlgItemTextW(self.hwnd, id_status, value);
    }
    fn kind(self: *State) output.Format {
        const index = c.SendDlgItemMessageW(self.hwnd, id_format, c.CB_GETCURSEL, 0, 0);
        return if (index >= 0 and index < kinds.len) kinds[@intCast(index)] else .png;
    }
    fn integer(self: *State, id: c.INT) ?u32 {
        const control = c.GetDlgItem(self.hwnd, id);
        const n = c.GetWindowTextLengthW(control);
        if (n <= 0 or n >= 24) return null;
        var buffer: [24]u16 = undefined;
        const got = c.GetWindowTextW(control, &buffer, buffer.len);
        if (got != n) return null;
        return positiveInteger(buffer[0..@intCast(n)]);
    }
    fn readOptions(self: *State) ?output.ExportOptions {
        const width = self.integer(id_width) orelse return null;
        const height = self.integer(id_height) orelse return null;
        const quality = if (self.kind() == .jpeg) (self.integer(id_quality) orelse return null) else 90;
        const value = output.ExportOptions{ .width = width, .height = height, .jpeg_quality = quality };
        return if (output.validOptions(self.source, value)) value else null;
    }
    fn aspect(self: *State, changed: c.INT) void {
        if (self.updating or c.SendDlgItemMessageW(self.hwnd, id_lock, c.BM_GETCHECK, 0, 0) != c.BST_CHECKED) return;
        const value = self.integer(changed) orelse return;
        const width_changed = changed == id_width;
        const other = output.aspectDimension(value, if (width_changed) self.source.width else self.source.height, if (width_changed) self.source.height else self.source.width);
        self.updating = true;
        defer self.updating = false;
        if (other) |n| {
            _ = c.SetDlgItemInt(self.hwnd, if (width_changed) id_height else id_width, n, 0);
        } else {
            _ = c.SetDlgItemTextW(self.hwnd, if (width_changed) id_height else id_width, L(""));
        }
    }
    fn measure(self: *State, options: output.ExportOptions) void {
        var full: [path_capacity]u16 = undefined;
        const source_path = absolute(self.path, &full) orelse { self.text(L("Ścieżka jest za długa dla eksportu w Windows XP.")); return; };
        var folder_buffer: [path_capacity]u16 = undefined;
        const folder = parentPath(source_path, &folder_buffer) orelse return;
        var temp: [path_capacity]u16 = undefined;
        if (!reserve(folder.ptr, &temp)) { self.text(L("Nie można utworzyć pliku tymczasowego w folderze źródłowym.")); return; }
        defer _ = c.DeleteFileW(&temp);
        const old_cursor = c.SetCursor(c.LoadCursorW(null, @ptrFromInt(32514)));
        defer _ = c.SetCursor(old_cursor);
        if (!output.saveOptions(self.source, @ptrCast(&temp), self.kind(), options)) { self.text(L("Nie udało się obliczyć rozmiaru kopii.")); return; }
        var info: c.WIN32_FILE_ATTRIBUTE_DATA = undefined;
        if (c.GetFileAttributesExW(&temp, c.GetFileExInfoStandard, &info) == 0) { self.text(L("Nie udało się odczytać rozmiaru pliku.")); return; }
        const bytes = (@as(u64, info.nFileSizeHigh) << 32) | info.nFileSizeLow;
        var narrow: [160]u8 = undefined;
        const value = std.fmt.bufPrint(&narrow, "{s}: {d} B", .{ i18n.utf8("Rozmiar pliku"), bytes }) catch return;
        var wide: [180]u16 = undefined;
        self.text(w.utf16(&wide, value).ptr);
    }
    fn save(self: *State, options: output.ExportOptions) void {
        if (self.source.animated or self.source.pages > 1) {
            if (c.MessageBoxW(self.hwnd, L("Zapisana zostanie tylko bieżąca klatka lub strona. Kontynuować?"), L("Kadr — eksportuj kopię"), c.MB_YESNO | c.MB_ICONWARNING | c.MB_DEFBUTTON2) != c.IDYES) return;
        }
        const selected = self.kind();
        var path: [path_capacity]u16 = [_]u16{0} ** path_capacity;
        _ = defaultPath(self.path, selected, &path) orelse { self.text(L("Ścieżka jest za długa dla eksportu w Windows XP.")); return; };
        var folder_buffer: [path_capacity]u16 = undefined;
        const folder = parentPath(std.mem.sliceTo(&path, 0), &folder_buffer) orelse return;
        var dialog = std.mem.zeroes(c.OPENFILENAMEW);
        dialog.lStructSize = @sizeOf(c.OPENFILENAMEW);
        dialog.hwndOwner = self.hwnd;
        dialog.lpstrFile = &path;
        dialog.nMaxFile = path.len;
        dialog.lpstrInitialDir = folder.ptr;
        dialog.lpstrTitle = L("Kadr — eksportuj nową kopię");
        dialog.lpstrFilter = switch (selected) {
            .png => L("PNG (*.png)\x00*.png\x00\x00"),
            .jpeg => L("JPEG (*.jpg;*.jpeg)\x00*.jpg;*.jpeg\x00\x00"),
            .bmp => L("BMP (*.bmp)\x00*.bmp\x00\x00"),
            .tiff => L("TIFF (*.tif;*.tiff)\x00*.tif;*.tiff\x00\x00"),
            .gif => L("GIF (*.gif)\x00*.gif\x00\x00"),
        };
        dialog.nFilterIndex = 1;
        dialog.lpstrDefExt = extension(selected).ptr;
        dialog.Flags = c.OFN_EXPLORER | c.OFN_PATHMUSTEXIST | c.OFN_NOCHANGEDIR | c.OFN_ENABLEHOOK | c.OFN_ENABLESIZING;
        dialog.lpfnHook = saveDialogHook;
        if (c.GetSaveFileNameW(&dialog) == 0) {
            if (c.CommDlgExtendedError() != 0) self.text(L("Nie można otworzyć okna wyboru pliku."));
            return;
        }
        if (sameFile(self.path, @ptrCast(&path))) { self.text(L("Eksport tworzy nową kopię. Aby zmienić oryginał, użyj polecenia Zapisz.")); return; }
        if (output.format(std.mem.sliceTo(&path, 0)) != selected) { self.text(L("Rozszerzenie pliku musi odpowiadać wybranemu formatowi.")); return; }
        const exists = c.GetFileAttributesW(&path) != c.INVALID_FILE_ATTRIBUTES;
        if (exists and c.MessageBoxW(self.hwnd, L("Plik docelowy już istnieje. Czy na pewno zastąpić go nową kopią?"), L("Kadr — zastąpienie kopii"), c.MB_YESNO | c.MB_DEFBUTTON2 | c.MB_ICONWARNING) != c.IDYES) return;
        const old_cursor = c.SetCursor(c.LoadCursorW(null, @ptrFromInt(32514)));
        defer _ = c.SetCursor(old_cursor);
        saveCopy(self.source, self.path, @ptrCast(&path), selected, options, exists) catch |err| {
            self.text(switch (err) {
                error.SameSource => L("Eksport nie nadpisuje źródła. Użyj polecenia Zapisz lub wybierz nową nazwę."),
                error.TargetExists, error.CommitFailed => L("Nie zapisano kopii. Cel mógł pojawić się w trakcie zapisu lub jest chroniony. Wybierz inną nazwę."),
                error.ReserveFailed => L("Brak możliwości zapisu w folderze docelowym. Wybierz zapisywalny folder."),
                else => L("Nie udało się wyeksportować kopii. Sprawdź ustawienia, ścieżkę i wolne miejsce."),
            });
            return;
        };
        self.saved = true;
        _ = c.DestroyWindow(self.hwnd);
    }
};

// HMENU carries an integer control ID here, NOT an aligned/dereferenced pointer.
fn controlId(id: usize) c.HMENU {
    @setRuntimeSafety(false);
    return @ptrFromInt(id);
}
fn child(parent: c.HWND, class: [*c]const u16, label: [*c]const u16, style: c.DWORD, id: usize, x: i32, y: i32, width: i32, height: i32) c.HWND {
    const hwnd = c.CreateWindowExW(0, class, label, @as(c.DWORD, c.WS_CHILD | c.WS_VISIBLE) | style, x, y, width, height, parent, controlId(id), null, null);
    if (hwnd != null) {
        const font = @import("ui.zig").font;
        if (font != null) _ = c.SendMessageW(hwnd, c.WM_SETFONT, @intFromPtr(font), 0) else w.setFont(hwnd);
    }
    return hwnd;
}
fn controls(state: *State) bool {
    const h = state.hwnd;
    if (child(h, L("STATIC"), L("Eksportuj bieżący obraz do nowej kopii"), 0, 0, 20, 16, 450, 22) == null) return false;
    _ = child(h, L("STATIC"), L("&Format:"), 0, 0, 20, 52, 130, 22);
    const combo = child(h, L("COMBOBOX"), L(""), c.WS_TABSTOP | c.CBS_DROPDOWNLIST | c.WS_VSCROLL, id_format, 160, 48, 300, 160);
    if (combo == null) return false;
    for ([_][*c]const u16{ L("PNG"), L("JPEG"), L("BMP"), L("TIFF"), L("GIF — jedna klatka") }) |label| _ = c.SendMessageW(combo, c.CB_ADDSTRING, 0, @intCast(@intFromPtr(label)));
    const initial = output.format(std.mem.span(state.path)) orelse .png;
    for (kinds, 0..) |kind, index| { if (kind == initial) _ = c.SendMessageW(combo, c.CB_SETCURSEL, index, 0); }
    _ = child(h, L("STATIC"), L("&Jakość JPEG (1–100):"), 0, 0, 20, 94, 140, 22);
    if (child(h, L("EDIT"), L("90"), c.WS_TABSTOP | c.WS_BORDER | c.ES_AUTOHSCROLL, id_quality, 160, 90, 110, 26) == null) return false;
    _ = c.EnableWindow(c.GetDlgItem(h, id_quality), if (initial == .jpeg) 1 else 0);
    _ = child(h, L("STATIC"), L("&Szerokość (px):"), 0, 0, 20, 136, 130, 22);
    if (child(h, L("EDIT"), L(""), c.WS_TABSTOP | c.WS_BORDER | c.ES_AUTOHSCROLL, id_width, 160, 132, 110, 26) == null) return false;
    _ = child(h, L("STATIC"), L("&Wysokość (px):"), 0, 0, 285, 136, 110, 22);
    if (child(h, L("EDIT"), L(""), c.WS_TABSTOP | c.WS_BORDER | c.ES_AUTOHSCROLL, id_height, 395, 132, 110, 26) == null) return false;
    _ = c.SetDlgItemInt(h, id_width, state.source.width, 0);
    _ = c.SetDlgItemInt(h, id_height, state.source.height, 0);
    if (child(h, L("BUTTON"), L("Zachowaj &proporcje"), c.WS_TABSTOP | c.BS_AUTOCHECKBOX, id_lock, 160, 170, 280, 26) == null) return false;
    _ = c.SendDlgItemMessageW(h, id_lock, c.BM_SETCHECK, c.BST_CHECKED, 0);
    _ = child(h, L("STATIC"), L("Limit kopii: 64 mln pikseli. PNG/TIFF zachowują przezroczystość; JPEG ma białe tło. Bez metadanych, animacji i pozostałych stron."), 0, 0, 20, 210, 490, 44);
    if (child(h, L("BUTTON"), L("Sprawdź &rozmiar"), c.WS_TABSTOP | c.BS_PUSHBUTTON, id_measure, 20, 268, 160, 30) == null) return false;
    if (child(h, L("STATIC"), L("Rozmiar pliku jest liczony tylko na żądanie."), 0, id_status, 20, 310, 490, 54) == null) return false;
    if (child(h, L("BUTTON"), L("&Eksportuj…"), c.WS_TABSTOP | c.BS_DEFPUSHBUTTON, c.IDOK, 270, 382, 130, 32) == null) return false;
    if (child(h, L("BUTTON"), L("Anuluj"), c.WS_TABSTOP | c.BS_PUSHBUTTON, c.IDCANCEL, 410, 382, 100, 32) == null) return false;
    return true;
}
fn saveDialogHook(_: c.HWND, _: c.UINT, _: c.WPARAM, _: c.LPARAM) callconv(.Stdcall) c.UINT_PTR { return 0; }
fn windowProc(hwnd: c.HWND, msg: c.UINT, wp: c.WPARAM, lp: c.LPARAM) callconv(.Stdcall) c.LRESULT {
    if (msg == c.WM_NCCREATE) {
        const cs: *const c.CREATESTRUCTW = @ptrFromInt(@as(usize, @bitCast(lp)));
        _ = c.SetWindowLongPtrW(hwnd, c.GWLP_USERDATA, @bitCast(@intFromPtr(cs.lpCreateParams)));
    }
    const address = c.GetWindowLongPtrW(hwnd, c.GWLP_USERDATA);
    if (address == 0) return c.DefWindowProcW(hwnd, msg, wp, lp);
    const state: *State = @ptrFromInt(@as(usize, @bitCast(address)));
    switch (msg) {
        c.WM_CREATE => { state.hwnd = hwnd; return if (controls(state)) 0 else -1; },
        c.WM_ERASEBKGND => if (theme.eraseBackground(hwnd, wp)) return 1 else return c.DefWindowProcW(hwnd, msg, wp, lp),
        c.WM_CTLCOLORSTATIC, c.WM_CTLCOLORBTN, c.WM_CTLCOLOREDIT, c.WM_CTLCOLORLISTBOX => return theme.dialogColor(msg, wp) orelse c.DefWindowProcW(hwnd, msg, wp, lp),
        theme.changed_message => { _ = c.InvalidateRect(hwnd, null, c.TRUE); return 0; },
        c.DM_GETDEFID => return (@as(c.LRESULT, c.DC_HASDEFID) << 16) | c.IDOK,
        c.WM_COMMAND => {
            const id: c.INT = @intCast(wp & 0xffff);
            const notification = (wp >> 16) & 0xffff;
            if (id == c.IDCANCEL) { _ = c.DestroyWindow(hwnd); return 0; }
            if (id == id_format and notification == c.CBN_SELCHANGE) {
                _ = c.EnableWindow(c.GetDlgItem(hwnd, id_quality), if (state.kind() == .jpeg) 1 else 0);
                state.text(L("Ustawienia zmienione. Sprawdź rozmiar ponownie, jeśli jest potrzebny."));
            } else if ((id == id_width or id == id_height or id == id_quality) and notification == c.EN_CHANGE) {
                if (!state.updating) {
                    if (id != id_quality) state.aspect(id);
                    state.text(L("Ustawienia zmienione. Sprawdź rozmiar ponownie, jeśli jest potrzebny."));
                }
            } else if (id == id_lock) {
                state.aspect(id_width);
            } else if (id == id_measure or id == c.IDOK) {
                const options = state.readOptions() orelse { state.text(L("Podaj dodatnie całkowite wymiary (do 64 mln pikseli) i jakość JPEG od 1 do 100.")); return 0; };
                if (id == id_measure) state.measure(options) else state.save(options);
            }
            return 0;
        },
        c.WM_CLOSE => { _ = c.DestroyWindow(hwnd); return 0; },
        c.WM_DESTROY => { state.done = true; return 0; },
        else => return c.DefWindowProcW(hwnd, msg, wp, lp),
    }
}

/// Returns true only when a new copy has been committed. Cancellation, invalid
/// input, and failures leave both the source Image and its file untouched.
pub fn show(owner: c.HWND, source: *const Image, source_path: [*:0]const u16) bool {
    if (source.handle == null or source.width == 0 or source.height == 0 or source_path[0] == 0) return false;
    const instance = c.GetModuleHandleW(null);
    var wc = std.mem.zeroes(c.WNDCLASSW);
    wc.lpfnWndProc = windowProc;
    wc.hInstance = instance;
    wc.hCursor = c.LoadCursorW(null, @ptrFromInt(32512));
    wc.hbrBackground = @ptrFromInt(c.COLOR_BTNFACE + 1);
    wc.lpszClassName = class_name;
    if (c.RegisterClassW(&wc) == 0 and c.GetLastError() != c.ERROR_CLASS_ALREADY_EXISTS) return false;
    var state = State{ .source = source, .path = source_path };
    var rect = c.RECT{ .left = 0, .top = 0, .right = 530, .bottom = 438 };
    const style = c.WS_POPUP | c.WS_CAPTION | c.WS_SYSMENU;
    _ = c.AdjustWindowRectEx(&rect, style, 0, c.WS_EX_DLGMODALFRAME);
    const width = rect.right - rect.left;
    const height = rect.bottom - rect.top;
    var parent = c.RECT{ .left = 0, .top = 0, .right = c.GetSystemMetrics(c.SM_CXSCREEN), .bottom = c.GetSystemMetrics(c.SM_CYSCREEN) };
    if (owner != null) _ = c.GetWindowRect(owner, &parent);
    const hwnd = c.CreateWindowExW(c.WS_EX_DLGMODALFRAME, class_name, L("Kadr — eksportuj kopię"), style, @max(0, parent.left + @divTrunc(parent.right - parent.left - width, 2)), @max(0, parent.top + @divTrunc(parent.bottom - parent.top - height, 2)), width, height, owner, null, instance, &state);
    if (hwnd == null) return false;
    const disable_owner = owner != null and c.IsWindowEnabled(owner) != 0;
    if (disable_owner) _ = c.EnableWindow(owner, 0);
    defer {
        if (c.IsWindow(hwnd) != 0) _ = c.DestroyWindow(hwnd);
        if (disable_owner and c.IsWindow(owner) != 0) { _ = c.EnableWindow(owner, 1); _ = c.SetActiveWindow(owner); }
    }
    theme.applyWindow(hwnd);
    _ = c.ShowWindow(hwnd, c.SW_SHOW);
    _ = c.SetFocus(c.GetDlgItem(hwnd, id_format));
    var message: c.MSG = undefined;
    while (!state.done) {
        const result = c.GetMessageW(&message, null, 0, 0);
        if (result <= 0) { if (result == 0) c.PostQuitMessage(@intCast(message.wParam)); break; }
        if (c.IsDialogMessageW(hwnd, &message) == 0) { _ = c.TranslateMessage(&message); _ = c.DispatchMessageW(&message); }
    }
    return state.saved;
}
