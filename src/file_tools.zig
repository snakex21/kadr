// Small, portable file tools. SPDX-License-Identifier: GPL-3.0-or-later
//! UI thread, after GdiplusStartup. Images remain owned by the caller.
const std = @import("std");
const w = @import("win.zig");
const c = w.c;
const L = @import("i18n.zig").L;
const Image = @import("image.zig").Image;
const output = @import("output.zig");
const export_dialog = @import("export_dialog.zig");

/// Copies the full, unquoted Unicode path, including the terminating NUL.
/// Requires a real owner window. Ownership transfers only on SetClipboardData
/// success; every earlier failure frees our movable global allocation.
pub fn copyPath(owner: c.HWND, path: [*:0]const u16) bool {
    if (owner == null or c.IsWindow(owner) == 0 or path[0] == 0) return false;
    var full: [32768]u16 = undefined;
    const n = c.GetFullPathNameW(path, full.len, &full, null);
    if (n == 0 or n >= full.len) return false;
    const bytes = std.math.mul(usize, @as(usize, n) + 1, @sizeOf(u16)) catch return false;
    const memory = c.GlobalAlloc(c.GMEM_MOVEABLE, bytes) orelse return false;
    var transferred = false;
    defer if (!transferred) { _ = c.GlobalFree(memory); };
    const data = c.GlobalLock(memory) orelse return false;
    @memcpy(@as([*]u8, @ptrCast(data))[0..bytes], std.mem.sliceAsBytes(full[0 .. n + 1]));
    _ = c.GlobalUnlock(memory);
    // Shell/clipboard listeners can hold the clipboard briefly after a dialog
    // closes. Retry for at most 90 ms, not an unbounded UI wait.
    var attempts: u8 = 0;
    while (c.OpenClipboard(owner) == 0) {
        if (attempts == 9) return false;
        attempts += 1;
        c.Sleep(10);
    }
    defer _ = c.CloseClipboard();
    if (c.EmptyClipboard() == 0 or c.SetClipboardData(c.CF_UNICODETEXT, memory) == null) return false;
    transferred = true;
    return true;
}

pub const WallpaperMode = enum { fit, fill, stretch, center };
const Attributes = opaque {};
extern "gdiplus" fn GdipCreateBitmapFromScan0(i32, i32, i32, i32, ?[*]u8, *?*w.GpImage) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipGetImageGraphicsContext(*w.GpImage, *?*w.GpGraphics) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipGraphicsClear(*w.GpGraphics, u32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipSetCompositingMode(*w.GpGraphics, i32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipSetPixelOffsetMode(*w.GpGraphics, i32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipCreateImageAttributes(*?*Attributes) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipSetImageAttributesWrapMode(*Attributes, i32, u32, i32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipDisposeImageAttributes(*Attributes) callconv(.Stdcall) i32;

/// Drawing-only helper: writes an opaque white-backed screen-size BMP to an
/// explicit private target. NO SystemParametersInfo, registry, clipboard, UI,
/// or implicit cache paths. Safe for tests; the caller owns target replacement.
pub fn writeWallpaper(source: *const Image, target: [*:0]const u16, screen_width: u32, screen_height: u32, mode: WallpaperMode) bool {
    const source_handle = source.handle orelse return false;
    if (target[0] == 0 or !output.validExportDimensions(screen_width, screen_height) or
        source.width == 0 or source.height == 0 or source.width > std.math.maxInt(i32) or source.height > std.math.maxInt(i32)) return false;
    var canvas = Image{ .width = screen_width, .height = screen_height };
    defer canvas.close();
    if (GdipCreateBitmapFromScan0(@intCast(screen_width), @intCast(screen_height), 0, 0x0026200a, null, &canvas.handle) != 0) return false;
    var graphics: ?*w.GpGraphics = null;
    if (GdipGetImageGraphicsContext(canvas.handle orelse return false, &graphics) != 0) return false;
    const g = graphics orelse return false;
    defer if (graphics) |context| { _ = w.GdipDeleteGraphics(context); };
    var attributes: ?*Attributes = null;
    if (GdipCreateImageAttributes(&attributes) != 0) return false;
    const a = attributes orelse return false;
    defer _ = GdipDisposeImageAttributes(a);
    if (GdipSetImageAttributesWrapMode(a, 3, 0, 0) != 0 or w.GdipSetPageUnit(g, 2) != 0 or
        GdipGraphicsClear(g, 0xffffffff) != 0 or GdipSetCompositingMode(g, 0) != 0 or
        GdipSetPixelOffsetMode(g, 4) != 0) return false;
    const iw: f64 = @floatFromInt(source.width);
    const ih: f64 = @floatFromInt(source.height);
    const sw: f64 = @floatFromInt(screen_width);
    const sh: f64 = @floatFromInt(screen_height);
    var dx: f64 = 0;
    var dy: f64 = 0;
    var dw = sw;
    var dh = sh;
    var sx: f64 = 0;
    var sy: f64 = 0;
    var cw = iw;
    var ch = ih;
    switch (mode) {
        .fit => {
            const scale = @min(sw / iw, sh / ih);
            // A rounded subpixel-thin image still needs one destination pixel.
            dw = @max(1, @round(iw * scale));
            dh = @max(1, @round(ih * scale));
            dx = @floor((sw - dw) / 2);
            dy = @floor((sh - dh) / 2);
        },
        .fill => {
            const scale = @max(sw / iw, sh / ih);
            cw = sw / scale;
            ch = sh / scale;
            sx = (iw - cw) / 2;
            sy = (ih - ch) / 2;
        },
        .stretch => {},
        .center => {
            dw = @min(iw, sw);
            dh = @min(ih, sh);
            cw = dw;
            ch = dh;
            dx = @floor((sw - dw) / 2);
            dy = @floor((sh - dh) / 2);
            sx = @floor((iw - dw) / 2);
            sy = @floor((ih - dh) / 2);
        },
    }
    // All input dimensions are positive bounded integers. Ratios are finite;
    // crop-in-source-space avoids huge off-canvas upscaled coordinates.
    if (!std.math.isFinite(dw) or !std.math.isFinite(dh) or dw <= 0 or dh <= 0) return false;
    if (w.GdipSetInterpolationMode(g, if (dw == cw and dh == ch) 5 else 7) != 0) return false;
    if (w.GdipDrawImageRectRect(g, source_handle, @floatCast(dx), @floatCast(dy), @floatCast(dw), @floatCast(dh), @floatCast(sx), @floatCast(sy), @floatCast(cw), @floatCast(ch), 2, a, null, null) != 0) return false;
    // Release the drawing context before snapshotting/encoding the canvas.
    _ = w.GdipDeleteGraphics(g);
    graphics = null;
    return output.save(&canvas, target, .bmp);
}

/// One of eight bounded cache names, always beside this executable. Skips an
/// active path, including existing file aliases. No AppData or fallback path.
/// Does not create/write anything; callers must re-query active before commit.
pub fn wallpaperCachePath(buffer: []u16, active: [*:0]const u16, slot: u8) ?[:0]const u16 {
    if (slot >= 8) return null;
    var module: [c.MAX_PATH]u16 = undefined;
    const n = c.GetModuleFileNameW(null, &module, module.len);
    if (n == 0 or n >= module.len) return null;
    const slash = std.mem.lastIndexOfScalar(u16, module[0..n], '\\') orelse return null;
    const suffix = L("kadr-wallpaper-0.bmp");
    const length = slash + 1 + suffix.len;
    if (length + 1 > buffer.len or length >= c.MAX_PATH) return null;
    @memcpy(buffer[0 .. slash + 1], module[0 .. slash + 1]);
    @memcpy(buffer[slash + 1 ..][0..suffix.len], suffix);
    buffer[slash + 1 + L("kadr-wallpaper-").len] = '0' + slot;
    buffer[length] = 0;
    if (active[0] != 0 and export_dialog.sameFile(@ptrCast(buffer.ptr), active)) return null;
    return buffer[0..length :0];
}

fn applyWallpaper(owner: c.HWND, source: *const Image, mode: WallpaperMode) bool {
    // This is the ONLY setting-changing call site, reached exclusively after
    // the user selects a mode and answers the explicit default-No confirmation.
    var active: [c.MAX_PATH]u16 = [_]u16{0} ** c.MAX_PATH;
    if (c.SystemParametersInfoW(c.SPI_GETDESKWALLPAPER, active.len, &active, 0) == 0) {
        w.message(owner, L("Nie można odczytać bieżącej tapety. Nie zmieniono ustawień."));
        return false;
    }
    const sw = c.GetSystemMetrics(c.SM_CXSCREEN);
    const sh = c.GetSystemMetrics(c.SM_CYSCREEN);
    if (sw <= 0 or sh <= 0 or !output.validExportDimensions(@intCast(sw), @intCast(sh))) return false;
    var target: [c.MAX_PATH]u16 = undefined;
    var selected: ?[:0]const u16 = null;
    var slot: u8 = 0;
    while (slot < 8) : (slot += 1) {
        selected = wallpaperCachePath(&target, @ptrCast(&active), slot);
        if (selected != null) break;
    }
    const path = selected orelse { w.message(owner, L("Nie znaleziono bezpiecznej nazwy kopii tapety obok programu.")); return false; };
    var folder: [c.MAX_PATH]u16 = undefined;
    const slash = std.mem.lastIndexOfScalar(u16, path, '\\') orelse return false;
    @memcpy(folder[0 .. slash + 1], path[0 .. slash + 1]);
    folder[slash + 1] = 0;
    var temp: [c.MAX_PATH]u16 = undefined;
    if (c.GetTempFileNameW(&folder, L("kwp"), 0, &temp) == 0) {
        w.message(owner, L("Nie można zapisać tapety obok programu. Folder programu musi być zapisywalny; Kadr nie używa AppData."));
        return false;
    }
    defer _ = c.DeleteFileW(&temp);
    const old_cursor = c.SetCursor(c.LoadCursorW(null, @ptrFromInt(32514)));
    defer _ = c.SetCursor(old_cursor);
    if (!writeWallpaper(source, @ptrCast(&temp), @intCast(sw), @intCast(sh), mode)) {
        w.message(owner, L("Nie udało się utworzyć kopii BMP tapety. Ustawienia nie zostały zmienione."));
        return false;
    }
    @memset(&active, 0);
    if (c.SystemParametersInfoW(c.SPI_GETDESKWALLPAPER, active.len, &active, 0) == 0 or export_dialog.sameFile(path.ptr, @ptrCast(&active))) {
        w.message(owner, L("Bieżąca tapeta zmieniła się w trakcie przygotowania. Spróbuj ponownie."));
        return false;
    }
    if (c.MoveFileExW(&temp, path.ptr, c.MOVEFILE_REPLACE_EXISTING | c.MOVEFILE_WRITE_THROUGH) == 0) {
        w.message(owner, L("Nie można zapisać kopii tapety w folderze programu. Ustawienia nie zostały zmienione."));
        return false;
    }
    // A screen-sized canvas renders identically for XP center/tile/stretch;
    // no registry writes or unsupported Windows 7 WallpaperStyle values.
    if (c.SystemParametersInfoW(c.SPI_SETDESKWALLPAPER, 0, @ptrCast(@constCast(path.ptr)), c.SPIF_UPDATEINIFILE | c.SPIF_SENDCHANGE) == 0) {
        w.message(owner, L("Windows nie przyjął nowej tapety. Poprzedni aktywny plik nie został nadpisany."));
        return false;
    }
    return true;
}

const WallpaperDialog = struct { source: *const Image, hwnd: c.HWND = null, done: bool = false, applied: bool = false };
const wallpaper_class = L("KadrWallpaperChoiceWindow");
// HMENU carries an integer control ID here, not a dereferenced pointer.
fn controlId(id: usize) c.HMENU {
    @setRuntimeSafety(false);
    return @ptrFromInt(id);
}
fn control(parent: c.HWND, class: [*c]const u16, label: [*c]const u16, style: c.DWORD, id: usize, x: i32, y: i32, width: i32, height: i32) c.HWND {
    const h = c.CreateWindowExW(0, class, label, @as(c.DWORD, c.WS_CHILD | c.WS_VISIBLE) | style, x, y, width, height, parent, controlId(id), null, null);
    if (h != null) {
        const font = @import("ui.zig").font;
        if (font != null) _ = c.SendMessageW(h, c.WM_SETFONT, @intFromPtr(font), 0) else w.setFont(h);
    }
    return h;
}
fn wallpaperProc(hwnd: c.HWND, msg: c.UINT, wp: c.WPARAM, lp: c.LPARAM) callconv(.Stdcall) c.LRESULT {
    if (msg == c.WM_NCCREATE) {
        const cs: *const c.CREATESTRUCTW = @ptrFromInt(@as(usize, @bitCast(lp)));
        _ = c.SetWindowLongPtrW(hwnd, c.GWLP_USERDATA, @bitCast(@intFromPtr(cs.lpCreateParams)));
    }
    const address = c.GetWindowLongPtrW(hwnd, c.GWLP_USERDATA);
    if (address == 0) return c.DefWindowProcW(hwnd, msg, wp, lp);
    const state: *WallpaperDialog = @ptrFromInt(@as(usize, @bitCast(address)));
    switch (msg) {
        c.WM_CREATE => {
            state.hwnd = hwnd;
            if (control(hwnd, L("STATIC"), L("&Sposób ułożenia na głównym ekranie:"), 0, 0, 20, 18, 400, 24) == null) return -1;
            const combo = control(hwnd, L("COMBOBOX"), L(""), c.WS_TABSTOP | c.CBS_DROPDOWNLIST | c.WS_VSCROLL, 101, 20, 52, 400, 160);
            if (combo == null) return -1;
            for ([_][*c]const u16{ L("Dopasuj — cały obraz, białe marginesy"), L("Wypełnij — przytnij do ekranu"), L("Rozciągnij — bez zachowania proporcji"), L("Wyśrodkuj — bez skalowania") }) |label| _ = c.SendMessageW(combo, c.CB_ADDSTRING, 0, @intCast(@intFromPtr(label)));
            _ = c.SendMessageW(combo, c.CB_SETCURSEL, 0, 0);
            _ = control(hwnd, L("STATIC"), L("Kadr utworzy kopię BMP obok programu. Źródło pozostanie bez zmian. Ustawienia pulpitu zmienią się dopiero po dodatkowym potwierdzeniu."), 0, 0, 20, 100, 400, 64);
            if (control(hwnd, L("BUTTON"), L("&Ustaw tapetę…"), c.WS_TABSTOP | c.BS_DEFPUSHBUTTON, c.IDOK, 170, 192, 140, 32) == null) return -1;
            if (control(hwnd, L("BUTTON"), L("Anuluj"), c.WS_TABSTOP | c.BS_PUSHBUTTON, c.IDCANCEL, 320, 192, 100, 32) == null) return -1;
            return 0;
        },
        c.DM_GETDEFID => return (@as(c.LRESULT, c.DC_HASDEFID) << 16) | c.IDOK,
        c.WM_COMMAND => {
            const id = wp & 0xffff;
            if (id == c.IDCANCEL) { _ = c.DestroyWindow(hwnd); return 0; }
            if (id == c.IDOK) {
                const index = c.SendDlgItemMessageW(hwnd, 101, c.CB_GETCURSEL, 0, 0);
                if (index < 0 or index > 3) return 0;
                if (c.MessageBoxW(hwnd, L("Czy na pewno zmienić tapetę pulpitu Windows? Wybrany układ zostanie zapisany jako kopia BMP obok programu."), L("Kadr — potwierdź zmianę tapety"), c.MB_YESNO | c.MB_DEFBUTTON2 | c.MB_ICONQUESTION) != c.IDYES) return 0;
                state.applied = applyWallpaper(hwnd, state.source, @enumFromInt(@as(u2, @intCast(index))));
                if (state.applied) _ = c.DestroyWindow(hwnd);
            }
            return 0;
        },
        c.WM_CLOSE => { _ = c.DestroyWindow(hwnd); return 0; },
        c.WM_DESTROY => { state.done = true; return 0; },
        else => return c.DefWindowProcW(hwnd, msg, wp, lp),
    }
}

/// Interactive mode choice AND explicit default-No confirmation before any OS
/// setting change. Portable cache only, no source edits, no AppData fallback.
pub fn wallpaper(owner: c.HWND, source: *const Image) bool {
    if (source.handle == null or source.width == 0 or source.height == 0) return false;
    const instance = c.GetModuleHandleW(null);
    var wc = std.mem.zeroes(c.WNDCLASSW);
    wc.lpfnWndProc = wallpaperProc;
    wc.hInstance = instance;
    wc.hCursor = c.LoadCursorW(null, @ptrFromInt(32512));
    wc.hbrBackground = @ptrFromInt(c.COLOR_BTNFACE + 1);
    wc.lpszClassName = wallpaper_class;
    if (c.RegisterClassW(&wc) == 0 and c.GetLastError() != c.ERROR_CLASS_ALREADY_EXISTS) return false;
    var state = WallpaperDialog{ .source = source };
    var rect = c.RECT{ .left = 0, .top = 0, .right = 440, .bottom = 246 };
    const style = c.WS_POPUP | c.WS_CAPTION | c.WS_SYSMENU;
    _ = c.AdjustWindowRectEx(&rect, style, 0, c.WS_EX_DLGMODALFRAME);
    const width = rect.right - rect.left;
    const height = rect.bottom - rect.top;
    const hwnd = c.CreateWindowExW(c.WS_EX_DLGMODALFRAME, wallpaper_class, L("Kadr — tapeta pulpitu"), style, @max(0, @divTrunc(c.GetSystemMetrics(c.SM_CXSCREEN) - width, 2)), @max(0, @divTrunc(c.GetSystemMetrics(c.SM_CYSCREEN) - height, 2)), width, height, owner, null, instance, &state);
    if (hwnd == null) return false;
    const disable_owner = owner != null and c.IsWindowEnabled(owner) != 0;
    if (disable_owner) _ = c.EnableWindow(owner, 0);
    defer {
        if (c.IsWindow(hwnd) != 0) _ = c.DestroyWindow(hwnd);
        if (disable_owner and c.IsWindow(owner) != 0) { _ = c.EnableWindow(owner, 1); _ = c.SetActiveWindow(owner); }
    }
    _ = c.ShowWindow(hwnd, c.SW_SHOW);
    _ = c.SetFocus(c.GetDlgItem(hwnd, 101));
    var message: c.MSG = undefined;
    while (!state.done) {
        const result = c.GetMessageW(&message, null, 0, 0);
        if (result <= 0) { if (result == 0) c.PostQuitMessage(@intCast(message.wParam)); break; }
        if (c.IsDialogMessageW(hwnd, &message) == 0) { _ = c.TranslateMessage(&message); _ = c.DispatchMessageW(&message); }
    }
    return state.applied;
}
