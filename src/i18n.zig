//! Portable, restart-only UI language selection. No allocator or CRT dependency.
//! SPDX-License-Identifier: GPL-3.0-or-later
const std = @import("std");
const w = @import("win.zig");
const c = w.c;
const languages = @import("languages.zig");
const translations = @import("translations.zig");

comptime {
    if (translations.count != languages.count) @compileError("translation/language index count mismatch");
}

var initialized = false;
var current_language: usize = languages.english_index;
var saved_language: usize = languages.english_index;
var settings_error = false;
var settings_path: [32768]u16 = [_]u16{0} ** 32768;
var settings_path_len: usize = 0;

fn entryIndex(comptime source: []const u8) ?usize {
    @setEvalBranchQuota(2_000_000);
    for (translations.entries, 0..) |entry, index| {
        if (std.mem.eql(u8, source, entry.source)) return index;
    }
    return null;
}

fn wideTexts(comptime index: usize) [languages.count][:0]const u16 {
    @setEvalBranchQuota(2_000_000);
    var result: [languages.count][:0]const u16 = undefined;
    for (translations.entries[index].text, 0..) |text, language| result[language] = w.L(text);
    return result;
}

/// Lookup is comptime; only indexing constant UTF-16 data happens at runtime.
/// The unknown-source branch never reads runtime state, so class names can be
/// used in global constants. Slice lengths include embedded NULs (file filters).
pub fn L(comptime source: []const u8) [:0]const u16 {
    if (comptime entryIndex(source)) |index| {
        const wide = comptime wideTexts(index);
        return wide[current_language];
    }
    return w.L(source);
}

pub fn utf8(comptime source: []const u8) []const u8 {
    if (comptime entryIndex(source)) |index| return translations.entries[index].text[current_language];
    return source;
}

pub fn languageIndex() usize {
    return current_language;
}
pub fn languageCode() []const u8 {
    return languages.all[current_language].code;
}
pub fn isRtl() bool {
    return languages.all[current_language].rtl;
}
pub fn fontFace() [:0]const u16 {
    return languages.all[current_language].font_face;
}
pub fn settingsPath() [:0]const u16 {
    return settings_path[0..settings_path_len :0];
}
pub fn hasSettingsError() bool {
    return settings_error;
}

fn locateSettings() bool {
    const n = c.GetModuleFileNameW(null, &settings_path, settings_path.len);
    // On XP a truncated result need not have a NUL or set GetLastError.
    if (n == 0 or n >= settings_path.len) return false;
    var directory_end: usize = n;
    while (directory_end > 0) : (directory_end -= 1) {
        if (settings_path[directory_end - 1] == '\\' or settings_path[directory_end - 1] == '/') break;
    }
    const name = w.L("Kadr.ini");
    if (directory_end == 0 or directory_end + name.len >= settings_path.len) return false;
    @memcpy(settings_path[directory_end..][0..name.len], name);
    settings_path_len = directory_end + name.len;
    settings_path[settings_path_len] = 0;
    return true;
}

fn readLanguage() ?usize {
    var value: [32]u16 = [_]u16{0} ** 32;
    const n = c.GetPrivateProfileStringW(w.L("General"), w.L("Language"), w.L(""), &value, value.len, settingsPath().ptr);
    if (n != 2 or value[0] > 0x7f or value[1] > 0x7f) return null;
    const code = [_]u8{ @intCast(value[0]), @intCast(value[1]) };
    return languages.indexForCode(&code);
}

fn persist(index: usize) bool {
    if (settings_path_len == 0) return false;
    if (c.WritePrivateProfileStringW(w.L("General"), w.L("Language"), languages.all[index].code_wide.ptr, settingsPath().ptr) == 0) return false;
    // Flush the profile cache before read-back; the all-null flush operation
    // can return zero even after a successful write (there may be no mapping
    // cache). Check the actual write above and the value below, not that return.
    // Never fall back to AppData; the asInvoker manifest disables redirection.
    _ = c.WritePrivateProfileStringW(null, null, null, settingsPath().ptr);
    return readLanguage() == index;
}

/// Call once, before creating windows. Repeated calls deliberately do nothing:
/// even after choose(), every existing window keeps its original UI language.
pub fn init() void {
    if (initialized) return;
    initialized = true;
    current_language = languages.indexForLangId(c.GetUserDefaultUILanguage());
    if (!locateSettings()) {
        settings_path_len = 0;
        settings_path[0] = 0;
        settings_error = true;
        return;
    }
    if (readLanguage()) |index| current_language = index;
    saved_language = current_language;
    // Also verify writability for a valid existing INI. A read-only portable
    // configuration must be visible through hasSettingsError(), not hidden.
    settings_error = !persist(current_language);
}

const list_id = 100;
const Selector = struct {
    list: c.HWND = null,
    font: c.HFONT = null,
    row_fonts: [languages.count]c.HFONT = [_]c.HFONT{null} ** languages.count,
    row_height: i32 = 20,
};

fn newFont(height: i32, face: [:0]const u16) c.HFONT {
    return c.CreateFontW(height, 0, 0, 0, c.FW_NORMAL, 0, 0, 0, c.DEFAULT_CHARSET, c.OUT_DEFAULT_PRECIS, c.CLIP_DEFAULT_PRECIS, c.DEFAULT_QUALITY, c.DEFAULT_PITCH | c.FF_DONTCARE, face.ptr);
}

fn control(hwnd: c.HWND, comptime class: []const u8, text: [:0]const u16, style: u32, id: usize, x: i32, y: i32, width: i32, height: i32, font: c.HFONT) c.HWND {
    var rect = c.RECT{ .left = x, .top = y, .right = x + width, .bottom = y + height };
    _ = c.MapDialogRect(hwnd, &rect);
    const base_style: u32 = c.WS_CHILD | c.WS_VISIBLE;
    const child = c.CreateWindowExW(0, w.L(class), text.ptr, base_style | style, rect.left, rect.top, rect.right - rect.left, rect.bottom - rect.top, hwnd, @ptrFromInt(id), null, null);
    _ = c.SendMessageW(child, c.WM_SETFONT, @intFromPtr(font), 0);
    return child;
}

fn drawLanguage(state: *Selector, item: *const c.DRAWITEMSTRUCT) void {
    if (item.itemID >= languages.count) return;
    const index: usize = item.itemID;
    const selected = (item.itemState & c.ODS_SELECTED) != 0;
    _ = c.FillRect(item.hDC, &item.rcItem, c.GetSysColorBrush(if (selected) c.COLOR_HIGHLIGHT else c.COLOR_WINDOW));
    _ = c.SetTextColor(item.hDC, c.GetSysColor(if (selected) c.COLOR_HIGHLIGHTTEXT else c.COLOR_WINDOWTEXT));
    _ = c.SetBkMode(item.hDC, c.TRANSPARENT);
    const font = state.row_fonts[index] orelse state.font;
    const old_font = if (font != null) c.SelectObject(item.hDC, font) else null;
    defer if (old_font != null) { _ = c.SelectObject(item.hDC, old_font); };
    var rect = item.rcItem;
    rect.left += 4;
    rect.right -= 4;
    const direction: u32 = if (languages.all[index].rtl) c.DT_RTLREADING | c.DT_RIGHT else c.DT_LEFT;
    const flags: u32 = c.DT_SINGLELINE | c.DT_VCENTER | c.DT_NOPREFIX;
    _ = c.DrawTextW(item.hDC, languages.all[index].native_name_wide.ptr, -1, &rect, flags | direction);
    if ((item.itemState & c.ODS_FOCUS) != 0) _ = c.DrawFocusRect(item.hDC, &item.rcItem);
}

fn selectorProc(hwnd: c.HWND, message: c.UINT, wp: c.WPARAM, lp: c.LPARAM) callconv(.Stdcall) c.INT_PTR {
    if (message == c.WM_INITDIALOG) {
        const state: *Selector = @ptrFromInt(@as(usize, @bitCast(lp)));
        _ = c.SetWindowLongPtrW(hwnd, c.GWLP_USERDATA, lp);
        _ = c.SetWindowTextW(hwnd, L("Kadr — język").ptr);
        var unit = c.RECT{ .left = 0, .top = 0, .right = 0, .bottom = 12 };
        _ = c.MapDialogRect(hwnd, &unit);
        state.row_height = @max(20, unit.bottom);
        state.font = newFont(-@divTrunc(state.row_height * 3, 4), fontFace());
        for (languages.all, 0..) |language, index| state.row_fonts[index] = newFont(-@divTrunc(state.row_height * 3, 4), language.font_face);
        _ = control(hwnd, "STATIC", L("Wybierz język. Zmiana będzie widoczna po ponownym uruchomieniu programu."), c.SS_LEFT | c.SS_NOPREFIX, 101, 10, 8, 230, 28, state.font);
        state.list = control(hwnd, "LISTBOX", L(""), c.WS_BORDER | c.WS_VSCROLL | c.WS_TABSTOP | c.LBS_NOTIFY | c.LBS_NOINTEGRALHEIGHT | c.LBS_OWNERDRAWFIXED | c.LBS_HASSTRINGS, list_id, 10, 38, 230, 150, state.font);
        if (state.list == null) {
            _ = c.EndDialog(hwnd, -1);
            return c.TRUE;
        }
        for (languages.all) |language| _ = c.SendMessageW(state.list, c.LB_ADDSTRING, 0, @bitCast(@intFromPtr(language.native_name_wide.ptr)));
        _ = c.SendMessageW(state.list, c.LB_SETCURSEL, saved_language, 0);
        _ = control(hwnd, "BUTTON", L("Zapisz"), c.WS_TABSTOP | c.BS_DEFPUSHBUTTON, c.IDOK, 92, 198, 70, 18, state.font);
        _ = control(hwnd, "BUTTON", L("Anuluj"), c.WS_TABSTOP | c.BS_PUSHBUTTON, c.IDCANCEL, 170, 198, 70, 18, state.font);
        _ = c.SendMessageW(hwnd, c.DM_SETDEFID, c.IDOK, 0);
        return c.TRUE;
    }
    const data = c.GetWindowLongPtrW(hwnd, c.GWLP_USERDATA);
    if (data == 0) return c.FALSE;
    const state: *Selector = @ptrFromInt(@as(usize, @bitCast(data)));
    switch (message) {
        c.WM_MEASUREITEM => {
            const item: *c.MEASUREITEMSTRUCT = @ptrFromInt(@as(usize, @bitCast(lp)));
            if (item.CtlID != list_id) return c.FALSE;
            item.itemHeight = @intCast(state.row_height);
            return c.TRUE;
        },
        c.WM_DRAWITEM => {
            const item: *const c.DRAWITEMSTRUCT = @ptrFromInt(@as(usize, @bitCast(lp)));
            if (item.CtlID != list_id) return c.FALSE;
            drawLanguage(state, item);
            return c.TRUE;
        },
        c.WM_COMMAND => {
            const id = wp & 0xffff;
            const notification = (wp >> 16) & 0xffff;
            if (id == c.IDCANCEL) {
                _ = c.EndDialog(hwnd, c.IDCANCEL);
                return c.TRUE;
            }
            if (id == c.IDOK or (id == list_id and notification == c.LBN_DBLCLK)) {
                const selected = c.SendMessageW(state.list, c.LB_GETCURSEL, 0, 0);
                if (selected < 0 or selected >= languages.count) return c.TRUE;
                const index: usize = @intCast(selected);
                settings_error = !persist(index);
                if (settings_error) {
                    _ = c.MessageBoxW(hwnd, L("Nie można zapisać pliku Kadr.ini obok programu. Sprawdź uprawnienia do folderu. Ustawienia nie zostały zapisane.").ptr, L("Kadr — język").ptr, c.MB_OK | c.MB_ICONERROR);
                    return c.TRUE;
                }
                saved_language = index; // NOT current_language: restart is required.
                _ = c.MessageBoxW(hwnd, L("Zapisano język. Uruchom ponownie program Kadr, aby zastosować zmianę.").ptr, L("Kadr — język").ptr, c.MB_OK | c.MB_ICONINFORMATION);
                _ = c.EndDialog(hwnd, c.IDOK);
                return c.TRUE;
            }
        },
        c.WM_CLOSE => {
            _ = c.EndDialog(hwnd, c.IDCANCEL);
            return c.TRUE;
        },
        else => {},
    }
    return c.FALSE;
}

/// Native modal selector. Caller owns beginModal/endModal. Successful saves do
/// not change L/utf8/fontFace/isRtl until the next process; Cancel writes nothing.
pub fn choose(owner: c.HWND) void {
    var state = Selector{};
    defer {
        for (state.row_fonts) |font| {
            if (font != null) _ = c.DeleteObject(font);
        }
        if (state.font != null) _ = c.DeleteObject(state.font);
    }
    // Zero menu/class/title WORDs follow the aligned DLGTEMPLATE. Controls and
    // translated text are created in WM_INITDIALOG, without an RC dialog catalog.
    var template: [64]u8 align(4) = [_]u8{0} ** 64;
    const header: *c.DLGTEMPLATE = @ptrCast(&template);
    header.* = .{ .style = c.WS_POPUP | c.WS_CAPTION | c.WS_SYSMENU | c.DS_MODALFRAME | c.DS_CENTER, .dwExtendedStyle = if (isRtl()) c.WS_EX_LAYOUTRTL | c.WS_EX_RTLREADING else 0, .cdit = 0, .x = 0, .y = 0, .cx = 250, .cy = 226 };
    const result = c.DialogBoxIndirectParamW(c.GetModuleHandleW(null), header, owner, selectorProc, @bitCast(@intFromPtr(&state)));
    if (result == -1) _ = c.MessageBoxW(owner, L("Nie można otworzyć okna wyboru języka.").ptr, L("Kadr — język").ptr, c.MB_OK | c.MB_ICONERROR);
}
