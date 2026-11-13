//! Light / dark / automatic UI theme. XP-safe: every post-XP API (DWM title
//! bar, uxtheme dark-mode ordinals, SetWindowTheme) is resolved at run time
//! with LoadLibraryW/GetProcAddress and silently skipped when absent.
//! SPDX-License-Identifier: GPL-3.0-or-later
const std = @import("std");
const w = @import("win.zig");
const c = w.c;

pub const Mode = enum { light, dark, auto };

/// Colours used by the custom-drawn UI (COLORREF, 0x00BBGGRR).
pub const Palette = struct {
    shell: u32,
    paper: u32,
    line: u32,
    ink: u32,
    muted: u32,
    accent: u32,
    /// Background behind a loaded image (viewer and editor canvas).
    canvas: u32,
    /// Background of the empty viewer (no image yet).
    empty: u32,
    chip: u32,
    hover: u32,
    pressed: u32,
    selected: u32,
    selected_border: u32,
    primary: u32,
    primary_hover: u32,
    primary_pressed: u32,
    on_primary: u32,
    disabled: u32,
    danger: u32,
    /// Edit/list fields inside dialogs.
    field: u32,
    /// Print preview desk and paper shadow.
    desk: u32,
    shadow: [3]u32,
    swatch_border: u32,
};

pub const light_palette = Palette{
    .shell = w.rgb(248, 249, 246),
    .paper = w.rgb(255, 255, 253),
    .line = w.rgb(222, 227, 219),
    .ink = w.rgb(35, 48, 43),
    .muted = w.rgb(111, 125, 116),
    .accent = w.rgb(20, 125, 102),
    .canvas = w.rgb(25, 30, 35),
    .empty = w.rgb(237, 242, 235),
    .chip = w.rgb(239, 244, 234),
    .hover = w.rgb(233, 237, 229),
    .pressed = w.rgb(211, 228, 216),
    .selected = w.rgb(225, 240, 230),
    .selected_border = w.rgb(179, 213, 192),
    .primary = w.rgb(20, 125, 102),
    .primary_hover = w.rgb(13, 110, 89),
    .primary_pressed = w.rgb(10, 91, 75),
    .on_primary = w.rgb(255, 255, 252),
    .disabled = w.rgb(170, 179, 171),
    .danger = w.rgb(180, 55, 45),
    .field = w.rgb(255, 255, 255),
    .desk = w.rgb(128, 132, 136),
    .shadow = .{ w.rgb(112, 116, 120), w.rgb(96, 100, 104), w.rgb(80, 84, 88) },
    .swatch_border = w.rgb(160, 168, 160),
};

pub const dark_palette = Palette{
    .shell = w.rgb(31, 33, 35),
    .paper = w.rgb(42, 45, 47),
    .line = w.rgb(64, 69, 71),
    .ink = w.rgb(232, 236, 233),
    .muted = w.rgb(163, 172, 167),
    .accent = w.rgb(82, 196, 166),
    .canvas = w.rgb(44, 45, 47),
    .empty = w.rgb(38, 41, 43),
    .chip = w.rgb(48, 62, 57),
    .hover = w.rgb(50, 54, 57),
    .pressed = w.rgb(38, 72, 62),
    .selected = w.rgb(36, 66, 57),
    .selected_border = w.rgb(56, 120, 100),
    .primary = w.rgb(24, 132, 108),
    .primary_hover = w.rgb(30, 150, 123),
    .primary_pressed = w.rgb(18, 108, 88),
    .on_primary = w.rgb(255, 255, 252),
    .disabled = w.rgb(98, 105, 101),
    .danger = w.rgb(244, 120, 108),
    .field = w.rgb(45, 48, 50),
    .desk = w.rgb(58, 61, 64),
    .shadow = .{ w.rgb(48, 50, 53), w.rgb(40, 42, 45), w.rgb(30, 32, 34) },
    .swatch_border = w.rgb(112, 120, 115),
};

// ------------------------------------------------------------ pure logic

pub fn parseMode(text: []const u8) ?Mode {
    const trimmed = std.mem.trim(u8, text, " \t");
    inline for (.{ .{ "light", Mode.light }, .{ "dark", Mode.dark }, .{ "auto", Mode.auto }, .{ "automatic", Mode.auto }, .{ "system", Mode.auto } }) |entry| {
        if (std.ascii.eqlIgnoreCase(trimmed, entry[0])) return entry[1];
    }
    return null;
}

pub fn modeName(value: Mode) []const u8 {
    return switch (value) {
        .light => "light",
        .dark => "dark",
        .auto => "auto",
    };
}

/// `apps_use_light` is the Windows AppsUseLightTheme value, or null when the
/// key does not exist (XP, Vista, 7, 8, early 10): automatic is then light.
pub fn resolveDark(selected: Mode, apps_use_light: ?u32) bool {
    return switch (selected) {
        .light => false,
        .dark => true,
        .auto => if (apps_use_light) |value| value == 0 else false,
    };
}

/// WM_SETTINGCHANGE carries "ImmersiveColorSet" when the app mode changes.
pub fn isColorSetChange(name: ?[*:0]const u16) bool {
    const value = name orelse return false;
    const expected = w.L("ImmersiveColorSet");
    var i: usize = 0;
    while (i < expected.len) : (i += 1) {
        if (value[i] != expected[i]) return false;
    }
    return value[expected.len] == 0;
}

// ------------------------------------------------------------ state

pub var mode: Mode = .auto;
var dark_active = false;
pub var colors: Palette = light_palette;
var shell_brush: c.HBRUSH = null;
var field_brush: c.HBRUSH = null;
/// Sent to every top-level window of the thread after the theme changed.
pub const changed_message: c.UINT = c.WM_APP + 0x2E1;

pub fn dark() bool {
    return dark_active;
}

fn setActive(is_dark: bool) void {
    dark_active = is_dark;
    colors = if (is_dark) dark_palette else light_palette;
    if (shell_brush != null) _ = c.DeleteObject(shell_brush);
    if (field_brush != null) _ = c.DeleteObject(field_brush);
    shell_brush = c.CreateSolidBrush(colors.shell);
    field_brush = c.CreateSolidBrush(colors.field);
}

pub fn shellBrush() c.HBRUSH {
    if (shell_brush == null) setActive(dark_active);
    return shell_brush;
}
pub fn fieldBrush() c.HBRUSH {
    if (field_brush == null) setActive(dark_active);
    return field_brush;
}

// ------------------------------------------------------------ registry / ini

const HKEY = ?*opaque {};
const hkey_current_user: HKEY = @ptrFromInt(0x80000001);
const RegOpenKeyExW = *const fn (HKEY, [*:0]const u16, u32, u32, *HKEY) callconv(.Stdcall) i32;
const RegQueryValueExW = *const fn (HKEY, [*:0]const u16, ?*u32, ?*u32, ?*anyopaque, ?*u32) callconv(.Stdcall) i32;
const RegCloseKey = *const fn (HKEY) callconv(.Stdcall) i32;

/// AppsUseLightTheme (HKCU), or null when absent (pre-Windows 10 1607).
/// advapi32 is resolved at run time, so the import tables stay unchanged.
pub fn systemAppsUseLight() ?u32 {
    const advapi = c.LoadLibraryW(w.L("advapi32.dll")) orelse return null;
    defer _ = c.FreeLibrary(advapi);
    const open: RegOpenKeyExW = @ptrCast(procAddress(advapi, "RegOpenKeyExW") orelse return null);
    const query: RegQueryValueExW = @ptrCast(procAddress(advapi, "RegQueryValueExW") orelse return null);
    const close: RegCloseKey = @ptrCast(procAddress(advapi, "RegCloseKey") orelse return null);
    var key: HKEY = null;
    if (open(hkey_current_user, w.L("Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize"), 0, 0x20019, &key) != 0) return null;
    defer _ = close(key);
    var value: u32 = 0;
    var kind: u32 = 0;
    var size: u32 = @sizeOf(u32);
    if (query(key, w.L("AppsUseLightTheme"), null, &kind, &value, &size) != 0 or kind != 4 or size != 4) return null;
    return value;
}

pub fn load(ini: [:0]const u16) Mode {
    if (ini.len == 0) return .auto;
    var value: [32]u16 = [_]u16{0} ** 32;
    const n = c.GetPrivateProfileStringW(w.L("General"), w.L("Theme"), w.L(""), &value, value.len, ini.ptr);
    var ascii: [32]u8 = undefined;
    var i: usize = 0;
    while (i < n and i < ascii.len) : (i += 1) {
        if (value[i] > 0x7f) return .auto;
        ascii[i] = @intCast(value[i]);
    }
    return parseMode(ascii[0..i]) orelse .auto;
}

pub fn save(ini: [:0]const u16, value: Mode) bool {
    if (ini.len == 0) return false;
    const wide: [:0]const u16 = switch (value) {
        .light => w.L("light"),
        .dark => w.L("dark"),
        .auto => w.L("auto"),
    };
    if (c.WritePrivateProfileStringW(w.L("General"), w.L("Theme"), wide.ptr, ini.ptr) == 0) return false;
    _ = c.WritePrivateProfileStringW(null, null, null, ini.ptr);
    return load(ini) == value;
}

// ------------------------------------------------------------ native dark mode

const Proc = *const fn () callconv(.C) void;
const DwmSetWindowAttribute = *const fn (c.HWND, u32, *const anyopaque, u32) callconv(.Stdcall) i32;
const SetWindowTheme = *const fn (c.HWND, ?[*:0]const u16, ?[*:0]const u16) callconv(.Stdcall) i32;
const AllowDarkModeForWindow = *const fn (c.HWND, i32) callconv(.Stdcall) i32;
const SetPreferredAppMode = *const fn (i32) callconv(.Stdcall) i32;
const FlushMenuThemes = *const fn () callconv(.Stdcall) void;

var native_loaded = false;
var dwm_set: ?DwmSetWindowAttribute = null;
var set_theme: ?SetWindowTheme = null;
var allow_window: ?AllowDarkModeForWindow = null;
var preferred_mode: ?SetPreferredAppMode = null;
var flush_menus: ?FlushMenuThemes = null;

extern "kernel32" fn GetProcAddress(c.HMODULE, usize) callconv(.Stdcall) ?*const anyopaque;
fn procAddress(module: c.HMODULE, name: [*:0]const u8) ?*const anyopaque {
    return GetProcAddress(module, @intFromPtr(name));
}
/// MAKEINTRESOURCEA-style lookup by export ordinal.
fn ordinal(module: c.HMODULE, value: usize) ?*const anyopaque {
    return GetProcAddress(module, value);
}

const OsVersion = extern struct { size: u32, major: u32, minor: u32, build: u32, platform: u32, csd: [128]u16 };
const RtlGetVersion = *const fn (*OsVersion) callconv(.Stdcall) i32;

pub fn windowsBuild() u32 {
    const ntdll = c.GetModuleHandleW(w.L("ntdll.dll")) orelse return 0;
    const get: RtlGetVersion = @ptrCast(procAddress(ntdll, "RtlGetVersion") orelse return 0);
    var info = std.mem.zeroes(OsVersion);
    info.size = @sizeOf(OsVersion);
    if (get(&info) != 0) return 0;
    if (info.major < 10) return 0;
    return info.build;
}

fn loadNative() void {
    if (native_loaded) return;
    native_loaded = true;
    if (c.LoadLibraryW(w.L("dwmapi.dll"))) |dwm| {
        if (procAddress(dwm, "DwmSetWindowAttribute")) |p| dwm_set = @ptrCast(p);
    }
    const ux = c.LoadLibraryW(w.L("uxtheme.dll")) orelse return;
    if (procAddress(ux, "SetWindowTheme")) |p| set_theme = @ptrCast(p);
    // Undocumented dark-mode ordinals: only on Windows 10 1903 (18362) or
    // newer, where #135 is SetPreferredAppMode. On other systems these
    // ordinals do not exist or mean something else, so they are not touched.
    if (windowsBuild() >= 18362) {
        if (ordinal(ux, 133)) |p| allow_window = @ptrCast(p);
        if (ordinal(ux, 135)) |p| preferred_mode = @ptrCast(p);
        if (ordinal(ux, 136)) |p| flush_menus = @ptrCast(p);
    }
}

/// Popup menus follow the process "preferred app mode" (1903+).
fn applyAppMode() void {
    loadNative();
    if (preferred_mode) |set| _ = set(if (dark_active) 2 else 3); // ForceDark / ForceLight
    if (flush_menus) |flush| flush();
}

fn setControlTheme(hwnd: c.HWND, app: ?[*:0]const u16, list: ?[*:0]const u16) void {
    if (set_theme) |set| _ = set(hwnd, app, list);
}

fn classIs(hwnd: c.HWND, comptime name: []const u8) bool {
    var buffer: [64]u16 = undefined;
    const n = c.GetClassNameW(hwnd, &buffer, buffer.len);
    if (n <= 0) return false;
    const expected = w.L(name);
    if (@as(usize, @intCast(n)) != expected.len) return false;
    for (buffer[0..@intCast(n)], expected) |a, b| {
        const la = if (a >= 'A' and a <= 'Z') a + 32 else a;
        const lb = if (b >= 'A' and b <= 'Z') b + 32 else b;
        if (la != lb) return false;
    }
    return true;
}

/// Native controls: themed dark where Windows does it cleanly, otherwise
/// left with their default (light) visual style.
fn themeControl(hwnd: c.HWND) void {
    const on = dark_active;
    if (allow_window) |allow| _ = allow(hwnd, @intFromBool(on));
    if (classIs(hwnd, "Button")) {
        const kind = @as(u32, @bitCast(c.GetWindowLongW(hwnd, c.GWL_STYLE))) & 0xf;
        if (kind == c.BS_OWNERDRAW) return;
        if (kind == c.BS_PUSHBUTTON or kind == c.BS_DEFPUSHBUTTON) {
            setControlTheme(hwnd, if (on) w.L("DarkMode_Explorer") else null, null);
        } else {
            // Themed check boxes ignore WM_CTLCOLORSTATIC text colour; the
            // classic look keeps the caption readable on a dark background.
            setControlTheme(hwnd, if (on) w.L("") else null, if (on) w.L("") else null);
        }
    } else if (classIs(hwnd, "ComboBox") or classIs(hwnd, "Edit")) {
        setControlTheme(hwnd, if (on) w.L("DarkMode_CFD") else null, null);
    } else if (classIs(hwnd, "ListBox")) {
        setControlTheme(hwnd, if (on) w.L("DarkMode_Explorer") else null, null);
    }
    _ = c.SendMessageW(hwnd, c.WM_THEMECHANGED, 0, 0);
}

fn childCallback(hwnd: c.HWND, _: c.LPARAM) callconv(.Stdcall) c.BOOL {
    // SetWindowTheme / WM_THEMECHANGED may paint a native control at once in
    // its default style; with redraw off nothing reaches the screen until the
    // single composited repaint in applyWindow. Only visible controls are
    // locked: WM_SETREDRAW TRUE would also show a hidden one.
    const visible = (@as(u32, @bitCast(c.GetWindowLongW(hwnd, c.GWL_STYLE))) & c.WS_VISIBLE) != 0;
    if (visible) _ = c.SendMessageW(hwnd, c.WM_SETREDRAW, c.FALSE, 0);
    themeControl(hwnd);
    if (visible) _ = c.SendMessageW(hwnd, c.WM_SETREDRAW, c.TRUE, 0);
    return c.TRUE;
}

/// WM_PAINT, or WM_PRINTCLIENT with the whole client area as the dirty
/// rectangle. Custom-painted windows accept both, so showAtOnce can render
/// them off-screen.
pub const Paint = struct {
    hwnd: c.HWND,
    ps: c.PAINTSTRUCT,
    dc: c.HDC,
    printing: bool,

    pub fn begin(hwnd: c.HWND, msg: c.UINT, wp: c.WPARAM) Paint {
        var p = Paint{ .hwnd = hwnd, .ps = std.mem.zeroes(c.PAINTSTRUCT), .dc = null, .printing = msg == c.WM_PRINTCLIENT };
        if (p.printing) {
            p.dc = handle(c.HDC, wp);
            p.ps.hdc = p.dc;
            _ = c.GetClientRect(hwnd, &p.ps.rcPaint);
        } else p.dc = c.BeginPaint(hwnd, &p.ps);
        return p;
    }
    pub fn end(self: *Paint) void {
        if (!self.printing) _ = c.EndPaint(self.hwnd, &self.ps);
    }
};

/// Render every visible descendant of `parent` into `dc`, which maps the
/// client area of `root`. Each control prints only itself (no PRF_CHILDREN:
/// DefWindowProc does not handle it everywhere); grandchildren are walked
/// here, so nested windows (the editor canvas, combo boxes) are covered.
fn printChildren(root: c.HWND, parent: c.HWND, dc: c.HDC) void {
    // Top of the z-order first: that is the order in which Windows sends
    // WM_PAINT to siblings, so where controls without WS_CLIPSIBLINGS
    // overlap (a label and the rounded corner of a button in the print
    // preview), the later one wins here as it does on screen.
    var child = c.GetWindow(parent, c.GW_CHILD);
    while (child) |hwnd| : (child = c.GetWindow(hwnd, c.GW_HWNDNEXT)) {
        if (c.IsWindowVisible(hwnd) == 0) continue;
        var r: c.RECT = undefined;
        if (c.GetWindowRect(hwnd, &r) == 0) continue;
        _ = c.MapWindowPoints(null, root, @ptrCast(&r), 2);
        const saved = c.SaveDC(dc);
        _ = c.SetViewportOrgEx(dc, r.left, r.top, null);
        _ = c.IntersectClipRect(dc, 0, 0, r.right - r.left, r.bottom - r.top);
        _ = c.SendMessageW(hwnd, c.WM_PRINT, @intFromPtr(dc), c.PRF_NONCLIENT | c.PRF_CLIENT | c.PRF_ERASEBKGND);
        _ = c.RestoreDC(dc, saved);
        printChildren(root, hwnd, dc);
    }
}

/// Show a window's new look in one step. Windows repaints the parent and
/// then each child with its own WM_PAINT; the owner-drawn toolbar buttons
/// (GDI+) are slow enough that the screen shows the steps in between: the
/// new background with old-colour button fields on it, which looks like
/// outlines around every button. Instead the window and its children are
/// rendered off-screen (WM_PRINT) and copied to the screen with one BitBlt.
pub fn showAtOnce(hwnd: c.HWND) void {
    if (hwnd == null or c.IsWindowVisible(hwnd) == 0 or c.IsIconic(hwnd) != 0) return;
    var client: c.RECT = undefined;
    if (c.GetClientRect(hwnd, &client) == 0 or client.right <= 0 or client.bottom <= 0) return;
    // A cache DC without DCX_CLIPCHILDREN covers the children too.
    const screen = c.GetDCEx(hwnd, null, c.DCX_CACHE) orelse return;
    defer _ = c.ReleaseDC(hwnd, screen);
    const memory = c.CreateCompatibleDC(screen) orelse return;
    defer _ = c.DeleteDC(memory);
    const bitmap = c.CreateCompatibleBitmap(screen, client.right, client.bottom) orelse return;
    defer _ = c.DeleteObject(bitmap);
    const old = c.SelectObject(memory, bitmap);
    defer _ = c.SelectObject(memory, old);
    // Anything that cannot print itself keeps its current pixels.
    _ = c.BitBlt(memory, 0, 0, client.right, client.bottom, screen, 0, 0, c.SRCCOPY);
    _ = c.SendMessageW(hwnd, c.WM_PRINTCLIENT, @intFromPtr(memory), c.PRF_CLIENT | c.PRF_ERASEBKGND);
    printChildren(hwnd, hwnd, memory);
    _ = c.BitBlt(screen, 0, 0, client.right, client.bottom, memory, 0, 0, c.SRCCOPY);
    // The screen is now up to date. The repaint applyWindow queued would
    // only draw the same pixels again, but piecemeal (a parent fill wiping
    // headings, a label erased before its text), so it is dropped. The
    // frame edge is repainted by the WM_NCACTIVATE pair in notifyCallback.
    _ = c.RedrawWindow(hwnd, null, null, c.RDW_VALIDATE | c.RDW_NOERASE | c.RDW_NOFRAME | c.RDW_ALLCHILDREN);
}

fn setTitleBar(hwnd: c.HWND) void {
    const set = dwm_set orelse return;
    const value: i32 = @intFromBool(dark_active);
    if (set(hwnd, 20, &value, @sizeOf(i32)) != 0) _ = set(hwnd, 19, &value, @sizeOf(i32));
}

/// Title bar, native children and their redraw. Safe on XP (no-ops).
pub fn applyWindow(hwnd: c.HWND) void {
    if (hwnd == null) return;
    loadNative();
    if (allow_window) |allow| _ = allow(hwnd, @intFromBool(dark_active));
    setTitleBar(hwnd);
    _ = c.EnumChildWindows(hwnd, childCallback, 0);
    _ = c.RedrawWindow(hwnd, null, null, c.RDW_INVALIDATE | c.RDW_ERASE | c.RDW_FRAME | c.RDW_ALLCHILDREN);
}

const DwmIsCompositionEnabled = *const fn (*i32) callconv(.Stdcall) i32;
var dwm_composition: ?DwmIsCompositionEnabled = null;
var dwm_composition_loaded = false;

fn compositionEnabled() bool {
    if (!dwm_composition_loaded) {
        dwm_composition_loaded = true;
        if (c.LoadLibraryW(w.L("dwmapi.dll"))) |dwm| {
            if (procAddress(dwm, "DwmIsCompositionEnabled")) |p| dwm_composition = @ptrCast(p);
        }
    }
    const query = dwm_composition orelse return false;
    var enabled: i32 = 0;
    return query(&enabled) == 0 and enabled != 0;
}

/// Rectangle of the hidden ring just outside the client area, in window
/// coordinates (the client rectangle grown by `ring` on every side).
pub fn frameEdgeRing(window: c.RECT, client_origin: c.POINT, client_size: c.POINT, ring: i32) struct { outer: c.RECT, client: c.RECT } {
    const left = client_origin.x - window.left;
    const top = client_origin.y - window.top;
    const inner = c.RECT{ .left = left, .top = top, .right = left + client_size.x, .bottom = top + client_size.y };
    return .{
        .outer = .{ .left = @max(0, inner.left - ring), .top = @max(0, inner.top - ring), .right = @min(window.right - window.left, inner.right + ring), .bottom = @min(window.bottom - window.top, inner.bottom + ring) },
        .client = inner,
    };
}

/// WM_NCPAINT helper (call after DefWindowProc). With DWM the frame is drawn
/// by the compositor and the window's own non-client pixels are never shown,
/// but when Windows scales a DPI-unaware window (125 %, 150 %, ...) its
/// bilinear filter blends the pixels just outside the client area - white
/// by default - into the first client row and column. In dark mode that is a
/// light line under the title bar and along the right edge. Painting that
/// hidden ring in the client background colour removes it. No-op without
/// DWM composition (XP, classic theme), where the frame is really visible.
pub fn paintFrameEdge(hwnd: c.HWND, color: u32) void {
    if (hwnd == null or !compositionEnabled()) return;
    var window: c.RECT = undefined;
    var client: c.RECT = undefined;
    if (c.GetWindowRect(hwnd, &window) == 0 or c.GetClientRect(hwnd, &client) == 0) return;
    var origin = c.POINT{ .x = 0, .y = 0 };
    if (c.ClientToScreen(hwnd, &origin) == 0) return;
    const ring = frameEdgeRing(window, origin, .{ .x = client.right, .y = client.bottom }, 3);
    const dc = c.GetWindowDC(hwnd) orelse return;
    defer _ = c.ReleaseDC(hwnd, dc);
    _ = c.ExcludeClipRect(dc, ring.client.left, ring.client.top, ring.client.right, ring.client.bottom);
    const brush = c.CreateSolidBrush(color) orelse return;
    defer _ = c.DeleteObject(brush);
    _ = c.FillRect(dc, &ring.outer, brush);
}

/// Tooltip popups are top-level windows of their own.
pub fn applyTooltip(hwnd: c.HWND) void {
    if (hwnd == null) return;
    loadNative();
    setControlTheme(hwnd, if (dark_active) w.L("DarkMode_Explorer") else null, null);
}

fn notifyCallback(hwnd: c.HWND, _: c.LPARAM) callconv(.Stdcall) c.BOOL {
    if (classIs(hwnd, "tooltips_class32")) {
        applyTooltip(hwnd);
    } else {
        _ = c.SendMessageW(hwnd, changed_message, 0, 0);
        applyWindow(hwnd);
        showAtOnce(hwnd);
        // Repaint the caption now; otherwise the title bar keeps its old
        // colour until the window is next activated.
        if (c.IsWindowVisible(hwnd) != 0 and dwm_set != null) {
            const active = c.GetActiveWindow() == hwnd;
            _ = c.SendMessageW(hwnd, c.WM_NCACTIVATE, @intFromBool(!active), 0);
            _ = c.SendMessageW(hwnd, c.WM_NCACTIVATE, @intFromBool(active), 0);
        }
    }
    return c.TRUE;
}

/// Resolve the effective theme; returns true when it changed.
pub fn refresh() bool {
    const next = resolveDark(mode, if (mode == .auto) systemAppsUseLight() else null);
    const changed = next != dark_active or shell_brush == null;
    setActive(next);
    applyAppMode();
    return changed;
}

/// Called after the palette changed and before windows are notified
/// (the viewer installs ui.applyTheme here).
pub var on_change: ?*const fn () void = null;

/// Startup: read Kadr.ini and resolve, before any window exists.
pub fn init(ini: [:0]const u16) void {
    mode = load(ini);
    _ = refresh();
    if (on_change) |callback| callback();
}

/// Re-resolve and, when the effective theme changed, tell every window of
/// this thread (viewer, editor, print preview, dialogs) to recolour.
pub fn update() void {
    if (refresh()) {
        if (on_change) |callback| callback();
        _ = c.EnumThreadWindows(c.GetCurrentThreadId(), notifyCallback, 0);
    }
}

pub fn deinit() void {
    if (shell_brush != null) _ = c.DeleteObject(shell_brush);
    if (field_brush != null) _ = c.DeleteObject(field_brush);
    shell_brush = null;
    field_brush = null;
}

/// Colours for native dialog children in dark mode. Light mode returns null
/// so the classic system colours stay exactly as before.
/// GDI handles are not pointers; they need not be aligned.
fn handle(comptime T: type, value: usize) T {
    @setRuntimeSafety(false);
    return @ptrFromInt(value);
}

pub fn dialogColor(msg: c.UINT, wp: c.WPARAM) ?c.LRESULT {
    if (!dark_active) return null;
    const dc = handle(c.HDC, wp);
    switch (msg) {
        c.WM_CTLCOLORSTATIC, c.WM_CTLCOLORBTN, c.WM_CTLCOLORDLG => {
            _ = c.SetTextColor(dc, colors.ink);
            _ = c.SetBkColor(dc, colors.shell);
            return @bitCast(@intFromPtr(shellBrush()));
        },
        c.WM_CTLCOLOREDIT, c.WM_CTLCOLORLISTBOX => {
            _ = c.SetTextColor(dc, colors.ink);
            _ = c.SetBkColor(dc, colors.field);
            return @bitCast(@intFromPtr(fieldBrush()));
        },
        else => return null,
    }
}

/// Owner-drawn list row background and text colour in dark mode.
pub fn fillListRow(dc: c.HDC, rect: *const c.RECT) bool {
    if (!dark_active) return false;
    _ = c.FillRect(dc, rect, fieldBrush());
    _ = c.SetTextColor(dc, colors.ink);
    return true;
}

/// WM_ERASEBKGND for dialog-like windows registered with COLOR_BTNFACE.
pub fn eraseBackground(hwnd: c.HWND, wp: c.WPARAM) bool {
    if (!dark_active) return false;
    var rect: c.RECT = undefined;
    _ = c.GetClientRect(hwnd, &rect);
    _ = c.FillRect(handle(c.HDC, wp), &rect, shellBrush());
    return true;
}

// ------------------------------------------------------------ tests

test "theme setting parses saved names and rejects unknown values" {
    try std.testing.expectEqual(@as(?Mode, .light), parseMode("light"));
    try std.testing.expectEqual(@as(?Mode, .dark), parseMode("Dark"));
    try std.testing.expectEqual(@as(?Mode, .auto), parseMode("auto"));
    try std.testing.expectEqual(@as(?Mode, .auto), parseMode(" AUTOMATIC "));
    try std.testing.expectEqual(@as(?Mode, null), parseMode(""));
    try std.testing.expectEqual(@as(?Mode, null), parseMode("blue"));
    for ([_]Mode{ .light, .dark, .auto }) |m| try std.testing.expectEqual(@as(?Mode, m), parseMode(modeName(m)));
}

test "automatic theme follows AppsUseLightTheme and falls back to light without the key" {
    try std.testing.expect(!resolveDark(.light, 0));
    try std.testing.expect(resolveDark(.dark, 1));
    try std.testing.expect(resolveDark(.dark, null));
    try std.testing.expect(resolveDark(.auto, 0));
    try std.testing.expect(!resolveDark(.auto, 1));
    try std.testing.expect(!resolveDark(.auto, null)); // XP / 7 / 8
}

test "only ImmersiveColorSet setting changes trigger a re-check" {
    try std.testing.expect(isColorSetChange(w.L("ImmersiveColorSet")));
    try std.testing.expect(!isColorSetChange(w.L("ImmersiveColorSetX")));
    try std.testing.expect(!isColorSetChange(w.L("Immersive")));
    try std.testing.expect(!isColorSetChange(w.L("intl")));
    try std.testing.expect(!isColorSetChange(null));
}

test "theme persists in an INI file and missing or invalid values mean automatic" {
    var dir: [260]u16 = undefined;
    const n = c.GetTempPathW(dir.len, &dir);
    try std.testing.expect(n > 0 and n < 200);
    const name = w.L("kadr-theme-test.ini");
    var path: [261]u16 = undefined;
    @memcpy(path[0..n], dir[0..n]);
    @memcpy(path[n..][0..name.len], name);
    path[n + name.len] = 0;
    const ini: [:0]const u16 = path[0 .. n + name.len :0];
    _ = c.DeleteFileW(ini.ptr);
    defer _ = c.DeleteFileW(ini.ptr);
    try std.testing.expectEqual(Mode.auto, load(ini));
    for ([_]Mode{ .dark, .light, .auto, .dark }) |m| {
        try std.testing.expect(save(ini, m));
        try std.testing.expectEqual(m, load(ini));
    }
    try std.testing.expect(c.WritePrivateProfileStringW(w.L("General"), w.L("Theme"), w.L("purple"), ini.ptr) != 0);
    try std.testing.expectEqual(Mode.auto, load(ini));
    // Other keys of [General] survive a theme write.
    try std.testing.expect(c.WritePrivateProfileStringW(w.L("General"), w.L("Language"), w.L("en"), ini.ptr) != 0);
    try std.testing.expect(save(ini, .light));
    var value: [8]u16 = undefined;
    try std.testing.expectEqual(@as(u32, 2), c.GetPrivateProfileStringW(w.L("General"), w.L("Language"), w.L(""), &value, value.len, ini.ptr));
    try std.testing.expectEqual(@as(?Mode, null), parseMode(""));
}

test "palettes keep readable contrast and distinct dark image background" {
    const P = struct {
        fn lum(color: u32) f64 {
            var sum: f64 = 0;
            const weights = [_]f64{ 0.2126, 0.7152, 0.0722 };
            for (0..3) |i| {
                const v = @as(f64, @floatFromInt((color >> @intCast(i * 8)) & 255)) / 255.0;
                const lin = if (v <= 0.03928) v / 12.92 else std.math.pow(f64, (v + 0.055) / 1.055, 2.4);
                sum += weights[i] * lin;
            }
            return sum;
        }
        fn ratio(a: u32, b: u32) f64 {
            const x = lum(a);
            const y = lum(b);
            return (@max(x, y) + 0.05) / (@min(x, y) + 0.05);
        }
    };
    for ([_]Palette{ light_palette, dark_palette }) |p| {
        try std.testing.expect(P.ratio(p.ink, p.shell) >= 7);
        try std.testing.expect(P.ratio(p.muted, p.shell) >= 4.0);
        try std.testing.expect(P.ratio(p.accent, p.shell) >= 4.5);
        try std.testing.expect(P.ratio(p.on_primary, p.primary) >= 4.5);
        try std.testing.expect(P.ratio(p.ink, p.field) >= 7);
    }
    try std.testing.expect(P.ratio(dark_palette.muted, dark_palette.shell) >= 4.5);
    try std.testing.expect(P.lum(dark_palette.canvas) < 0.05);
    try std.testing.expect(dark_palette.canvas != dark_palette.shell);
}

test "dark mode colours native dialog fields; light mode leaves system defaults" {
    setActive(false);
    try std.testing.expect(dialogColor(c.WM_CTLCOLORSTATIC, 0) == null);
    const dc = c.CreateCompatibleDC(null);
    defer _ = c.DeleteDC(dc);
    setActive(true);
    defer {
        setActive(false);
        deinit();
    }
    try std.testing.expectEqual(@as(c.LRESULT, @bitCast(@intFromPtr(fieldBrush()))), dialogColor(c.WM_CTLCOLOREDIT, @intFromPtr(dc)).?);
    try std.testing.expectEqual(dark_palette.ink, c.GetTextColor(dc));
    try std.testing.expectEqual(dark_palette.field, c.GetBkColor(dc));
    try std.testing.expectEqual(@as(c.LRESULT, @bitCast(@intFromPtr(shellBrush()))), dialogColor(c.WM_CTLCOLORSTATIC, @intFromPtr(dc)).?);
    try std.testing.expect(dialogColor(c.WM_PAINT, @intFromPtr(dc)) == null);
}

test "native theming entry points are safe on windows without dark mode support" {
    loadNative();
    applyWindow(null);
    applyTooltip(null);
    _ = windowsBuild();
    _ = systemAppsUseLight();
}
