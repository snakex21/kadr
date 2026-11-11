// Native filename dialog, no resources or post-XP APIs. SPDX-License-Identifier: GPL-3.0-or-later
const std = @import("std");
const w = @import("win.zig");
const c = w.c;
const L = @import("i18n.zig").L;
const edit_id = 2001;
const State = struct { original: [*:0]const u16, buffer: []u16 };
const Template = extern struct { dialog: c.DLGTEMPLATE, menu: u16 = 0, class: u16 = 0, title: u16 = 0 };

pub fn validName(name: []const u16) bool {
    if (name.len == 0 or name.len > 255 or name[name.len - 1] == '.' or name[name.len - 1] == ' ') return false;
    for (name) |ch| {
        if (ch < 32 or std.mem.indexOfScalar(u16, L("\\/:*?\"<>|"), ch) != null) return false;
    }
    // Windows device names remain reserved even when followed by an extension.
    const dot = std.mem.indexOfScalar(u16, name, '.') orelse name.len;
    var base: [256]u8 = undefined;
    for (name[0..dot], 0..) |ch, i| base[i] = if (ch < 128) std.ascii.toUpper(@intCast(ch)) else '?';
    for ([_][]const u8{ "CON", "PRN", "AUX", "NUL" }) |device| if (std.mem.eql(u8, base[0..dot], device)) return false;
    if (dot == 4 and (std.mem.eql(u8, base[0..3], "COM") or std.mem.eql(u8, base[0..3], "LPT")) and base[3] >= '1' and base[3] <= '9') return false;
    return true;
}
fn child(hwnd: c.HWND, class: [*c]const u16, title: [*c]const u16, style: u32, id: usize, x: i32, y: i32, width: i32, height: i32) c.HWND {
    const h = c.CreateWindowExW(0, class, title, @as(u32, c.WS_CHILD | c.WS_VISIBLE) | style, x, y, width, height, hwnd, @ptrFromInt(id), null, null);
    const font = @import("ui.zig").font;
    if (font != null) _ = c.SendMessageW(h, c.WM_SETFONT, @intFromPtr(font), 0) else w.setFont(h);
    return h;
}
fn proc(hwnd: c.HWND, msg: c.UINT, wp: c.WPARAM, lp: c.LPARAM) callconv(.Stdcall) c.INT_PTR {
    if (msg == c.WM_INITDIALOG) {
        _ = c.SetWindowLongPtrW(hwnd, c.DWLP_USER, lp);
        const state: *State = @ptrFromInt(@as(usize, @bitCast(lp)));
        _ = c.SetWindowTextW(hwnd, L("Kadr — zmień nazwę"));
        // Use pixels for the children; size the shell independently of the default dialog font.
        var frame = c.RECT{ .left = 0, .top = 0, .right = 440, .bottom = 132 };
        _ = c.AdjustWindowRectEx(&frame, c.WS_POPUP | c.WS_CAPTION | c.WS_SYSMENU | c.DS_MODALFRAME, 0, c.WS_EX_DLGMODALFRAME);
        var owner: c.RECT = undefined;
        _ = c.GetWindowRect(c.GetParent(hwnd), &owner);
        const width = frame.right - frame.left;
        const height = frame.bottom - frame.top;
        _ = c.SetWindowPos(hwnd, null, @divTrunc(owner.left + owner.right - width, 2), @divTrunc(owner.top + owner.bottom - height, 2), width, height, c.SWP_NOZORDER);
        _ = child(hwnd, L("STATIC"), L("Nowa nazwa pliku (z rozszerzeniem):"), 0, 2002, 16, 12, 406, 22);
        const edit = child(hwnd, L("EDIT"), state.original, c.WS_TABSTOP | c.WS_BORDER | c.ES_AUTOHSCROLL, edit_id, 16, 38, 406, 26);
        _ = c.SendMessageW(edit, c.EM_SETLIMITTEXT, 255, 0);
        _ = child(hwnd, L("BUTTON"), L("Zmień nazwę"), c.WS_TABSTOP | c.BS_DEFPUSHBUTTON, c.IDOK, 204, 86, 112, 30);
        _ = child(hwnd, L("BUTTON"), L("Anuluj"), c.WS_TABSTOP | c.BS_PUSHBUTTON, c.IDCANCEL, 326, 86, 96, 30);
        const name = std.mem.span(state.original);
        var stem = std.mem.lastIndexOfScalar(u16, name, '.') orelse name.len;
        if (stem == 0) stem = name.len;
        _ = c.SetFocus(edit);
        _ = c.SendMessageW(edit, c.EM_SETSEL, 0, @intCast(stem));
        return 0;
    }
    if (msg == c.WM_CLOSE or (msg == c.WM_COMMAND and (wp & 0xffff) == c.IDCANCEL)) {
        _ = c.EndDialog(hwnd, c.IDCANCEL);
        return 1;
    }
    if (msg == c.WM_COMMAND and (wp & 0xffff) == c.IDOK) {
        const value = c.GetWindowLongPtrW(hwnd, c.DWLP_USER);
        if (value == 0) return 1;
        const state: *State = @ptrFromInt(@as(usize, @bitCast(value)));
        const edit = c.GetDlgItem(hwnd, edit_id);
        const n = c.GetWindowTextW(edit, state.buffer.ptr, @intCast(state.buffer.len));
        if (n <= 0 or !validName(state.buffer[0..@intCast(n)])) {
            _ = c.MessageBoxW(hwnd, L("Wpisz poprawną nazwę pliku. Nie używaj znaków \\ / : * ? \" < > |, nazw urządzeń ani kropki lub spacji na końcu."), L("Kadr — niepoprawna nazwa"), c.MB_OK | c.MB_ICONWARNING);
            _ = c.SetFocus(edit);
            return 1;
        }
        _ = c.EndDialog(hwnd, c.IDOK);
        return 1;
    }
    return 0;
}
pub fn rename(owner: c.HWND, original: [*:0]const u16, buffer: []u16) bool {
    var template = std.mem.zeroes(Template);
    template.dialog.style = c.WS_POPUP | c.WS_CAPTION | c.WS_SYSMENU | c.DS_MODALFRAME;
    template.dialog.dwExtendedStyle = c.WS_EX_DLGMODALFRAME;
    template.dialog.cx = 270;
    template.dialog.cy = 80;
    var state = State{ .original = original, .buffer = buffer };
    return c.DialogBoxIndirectParamW(c.GetModuleHandleW(null), &template.dialog, owner, proc, @bitCast(@intFromPtr(&state))) == c.IDOK;
}

test "filename validation including reserved Windows devices" {
    for ([_][]const u16{ L(""), L(".."), L("a/b.png"), L("a*.jpg"), L("CON.png"), L("lpt1.jpg"), L("NUL"), L("photo."), L("photo ") }) |name| try std.testing.expect(!validName(name));
    for ([_][]const u16{ L("zdjęcie.png"), L("zażółć-gęślą.jpg"), L("COM10.png"), L("a.b.c.tiff") }) |name| try std.testing.expect(validName(name));
}
