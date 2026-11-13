//! Synchronous, UI-thread-only print preview. The owner is disabled while this
//! window is open; a private image clone keeps the preview stable during the
//! nested message loop. Printer DEVMODE changes are private to this window.
//! No job is started by printer selection, paper changes, or dialog acceptance.
const std = @import("std");
const w = @import("win.zig");
const c = w.c;
const i18n = @import("i18n.zig");
const L = i18n.L;
const layout = @import("layout.zig");
const ui = @import("ui.zig");
const theme = @import("theme.zig");

pub const Source = struct { image: *w.GpImage, width: u32, height: u32 };

extern "gdiplus" fn GdipCloneImage(*w.GpImage, *?*w.GpImage) callconv(.Stdcall) i32;
// win.zig intentionally does not import winspool.h. These are XP-era APIs;
// DocumentProperties uses IN/OUT_BUFFER only, never DM_UPDATE/system defaults.
extern "winspool" fn OpenPrinterW([*:0]const u16, *c.HANDLE, ?*anyopaque) callconv(.Stdcall) c.BOOL;
extern "winspool" fn ClosePrinter(c.HANDLE) callconv(.Stdcall) c.BOOL;
extern "winspool" fn DocumentPropertiesW(c.HWND, c.HANDLE, [*:0]const u16, ?*c.DEVMODEW, ?*c.DEVMODEW, c.DWORD) callconv(.Stdcall) c.LONG;

const Control = enum(usize) { paper, orientation, scale, left, top, right, bottom, center, printer, details, setup, print, cancel, status, color, advanced, value, value_label, media_width, media_height, x, y };
const control_count = std.meta.fields(Control).len;
const class_name = L("Kadr.PrintPreview.1");
const papers = [_]layout.Paper{ .a4, .a5, .letter, .photo_10x15, .a3, .a6, .b4, .b5, .legal, .executive, .tabloid, .photo_13x18, .photo_15x20, .photo_20x25, .inch_4x6, .inch_5x7, .inch_8x10 };
const advanced_controls = [_]Control{ .value_label, .value, .media_width, .media_height, .left, .right, .top, .bottom, .x, .y, .center, .details };
const sidebar_width = 296;
const sidebar_inset = 24;
const form_width = sidebar_width - 2 * sidebar_inset;

const State = struct {
    source: Source,
    hwnd: c.HWND = null,
    controls: [control_count]c.HWND = [_]c.HWND{null} ** control_count,
    initializing: bool = true,
    background_brush: c.HBRUSH = null,
    page: layout.Page = layout.paperPage(.a4, .portrait),
    paper_index: usize = 0,
    orientation: layout.Orientation = .portrait,
    automatic_orientation: bool = true,
    // Minimal margins: the image may use the whole printable area of the sheet.
    settings: layout.Settings = .{ .margins = .{ .left = 0, .top = 0, .right = 0, .bottom = 0 } },
    placement: ?layout.Placement = null,
    margins_valid: bool = true,
    input_valid: bool = true,
    geometry_valid: bool = true,
    printer_ready: bool = false,
    driver_changed: bool = false,
    driver_color_changed: bool = false,
    grayscale: bool = false,
    advanced: bool = false,
    advanced_labels: [12]c.HWND = [_]c.HWND{null} ** 12,
    advanced_label_count: usize = 0,
    collecting_advanced: bool = false,
    media_width: f64 = 210,
    media_height: f64 = 297,
    dragging: bool = false,
    drag_start: c.POINT = .{ .x = 0, .y = 0 },
    drag_placement: ?layout.Placement = null,
    drag_transform: layout.Transform = .{ .scale_x = 1, .scale_y = 1 },
    tooltip: c.HWND = null,
    dc: c.HDC = null,
    devmode: c.HGLOBAL = null,
    devnames: c.HGLOBAL = null,
    caps: layout.DeviceCaps = undefined,
    printer_name: [128]u16 = [_]u16{0} ** 128,
    printing: bool = false,
    cancel_requested: bool = false,
    // Owner disabled while the preview is open. It must be re-enabled BEFORE
    // the preview is destroyed; otherwise Windows activates another app's
    // window for a moment (visible flash) before Kadr gets focus back.
    owner: c.HWND = null,

    fn get(self: *State, control: Control) c.HWND {
        return self.controls[@intFromEnum(control)];
    }
};

// Only one preview/job on the application's UI thread. The abort callback has
// no context parameter in Win32, so its state must remain here until EndDoc.
var preview_open = false;
var active_job: ?*State = null;

/// Blocks until the preview closes, without taking ownership of source.image.
/// GDI+ must already have been started by the application.
pub fn show(owner: c.HWND, source: Source) void {
    if (preview_open) return;
    if (source.width == 0 or source.height == 0) {
        notify(owner, L("Brak obrazu do wydrukowania."), c.MB_ICONINFORMATION);
        return;
    }
    var clone: ?*w.GpImage = null;
    if (GdipCloneImage(source.image, &clone) != 0 or clone == null) {
        notify(owner, L("Nie można przygotować obrazu do podglądu wydruku."), c.MB_ICONERROR);
        return;
    }
    defer _ = w.GdipDisposeImage(clone.?);
    preview_open = true;
    defer preview_open = false;

    const instance = c.GetModuleHandleW(null);
    var wc = std.mem.zeroes(c.WNDCLASSW);
    wc.style = c.CS_HREDRAW | c.CS_VREDRAW;
    wc.lpfnWndProc = windowProc;
    wc.hInstance = instance;
    wc.hIcon = c.LoadIconW(instance, @ptrFromInt(4));
    wc.hCursor = c.LoadCursorW(null, @ptrFromInt(32512)); // IDC_ARROW
    wc.lpszClassName = class_name;
    if (c.RegisterClassW(&wc) == 0 and c.GetLastError() != c.ERROR_CLASS_ALREADY_EXISTS) {
        notify(owner, L("Nie można utworzyć okna podglądu wydruku."), c.MB_ICONERROR);
        return;
    }
    var state = State{ .source = .{ .image = clone.?, .width = source.width, .height = source.height } };
    defer {
        restoreOwner(&state);
        if (state.hwnd != null) _ = c.DestroyWindow(state.hwnd);
        if (state.dc != null) _ = c.DeleteDC(state.dc);
        if (state.devmode != null) _ = c.GlobalFree(state.devmode);
        if (state.devnames != null) _ = c.GlobalFree(state.devnames);
    }
    var work = c.RECT{ .left = 0, .top = 0, .right = 1024, .bottom = 768 };
    _ = c.SystemParametersInfoW(c.SPI_GETWORKAREA, 0, &work, 0);
    const width = @min(@as(i32, 1020), work.right - work.left);
    const height = @min(@as(i32, 730), work.bottom - work.top);
    const hwnd = c.CreateWindowExW(c.WS_EX_CONTROLPARENT, class_name, L("Kadr — podgląd wydruku"),
        c.WS_OVERLAPPEDWINDOW | c.WS_CLIPCHILDREN,
        work.left + @divTrunc(work.right - work.left - width, 2),
        work.top + @divTrunc(work.bottom - work.top - height, 2),
        width, height, owner, null, instance, &state);
    if (hwnd == null) {
        notify(owner, L("Nie można utworzyć kontrolek podglądu wydruku."), c.MB_ICONERROR);
        return;
    }
    // Restore the last chosen scale mode (Kadr.ini [Print] Scale).
    state.settings.scale = loadScale();
    _ = c.SendMessageW(state.get(.scale), c.CB_SETCURSEL, @intFromEnum(state.settings.scale), 0);
    if (@intFromEnum(state.settings.scale) >= @intFromEnum(layout.Scale.percent)) state.advanced = true;
    // Choose the whole-image layout before querying the default printer.
    formatChanged(&state);
    // PD_RETURNDEFAULT is silent and does not print or change the default
    // printer. Its real DC makes even the initial preview hardware-aware.
    loadDefaultPrinter(&state);
    refresh(&state);
    const enable_owner = owner != null and c.IsWindow(owner) != 0 and c.IsWindowEnabled(owner) != 0;
    if (enable_owner) {
        _ = c.EnableWindow(owner, c.FALSE);
        state.owner = owner;
    }
    defer restoreOwner(&state);
    theme.applyWindow(hwnd);
    _ = c.ShowWindow(hwnd, c.SW_SHOW);
    _ = c.UpdateWindow(hwnd);
    _ = c.SetFocus(state.get(.setup));

    var msg: c.MSG = undefined;
    while (state.hwnd != null) {
        const result = c.GetMessageW(&msg, null, 0, 0);
        if (result == 0) {
            c.PostQuitMessage(@bitCast(@as(u32, @truncate(msg.wParam))));
            break;
        }
        if (result < 0) break;
        if (c.IsDialogMessageW(state.hwnd, &msg) == 0) {
            _ = c.TranslateMessage(&msg);
            _ = c.DispatchMessageW(&msg);
        }
    }
}

fn notify(hwnd: c.HWND, text: [*c]const u16, icon: c.UINT) void {
    _ = c.MessageBoxW(hwnd, text, L("Kadr — drukowanie"), @as(c.UINT, c.MB_OK) | icon);
}

fn controlId(control: Control) usize {
    return if (control == .cancel) c.IDCANCEL else 100 + @intFromEnum(control);
}

// USER/GDI handles are encoded values, not dereferenced pointers. Their low
// bits need not satisfy the dummy handle structs' alignment in the C headers.
fn nativeHandle(comptime Handle: type, value: usize) Handle {
    @setRuntimeSafety(false);
    return @ptrFromInt(value);
}

// The application owns the shared UI lifetime. Hidden-window tests (and a
// failed font allocation) can still use the native controls without ui.init.
fn formFont() c.HFONT {
    return ui.font orelse nativeHandle(c.HFONT, @intFromPtr(c.GetStockObject(c.DEFAULT_GUI_FONT)));
}

fn child(state: *State, control: Control, class: [*c]const u16, text: [*c]const u16, style: c.DWORD, x: i32, y: i32, width: i32, height: i32) bool {
    const hwnd = c.CreateWindowExW(0, class, text, @as(c.DWORD, c.WS_CHILD) | @as(c.DWORD, c.WS_VISIBLE) | style,
        x, y, width, height, state.hwnd, null, c.GetModuleHandleW(null), null);
    state.controls[@intFromEnum(control)] = hwnd;
    if (hwnd == null) return false;
    // Set the integer child ID separately instead of casting it to HMENU.
    _ = c.SetWindowLongPtrW(hwnd, c.GWLP_ID, @intCast(controlId(control)));
    _ = c.SendMessageW(hwnd, c.WM_SETFONT, @intFromPtr(formFont()), 1);
    return true;
}

fn label(state: *State, text: [*c]const u16, x: i32, y: i32, width: i32, height: i32) bool {
    const hwnd = c.CreateWindowExW(0, L("STATIC"), text, c.WS_CHILD | c.WS_VISIBLE,
        x, y, width, height, state.hwnd, null, c.GetModuleHandleW(null), null);
    if (hwnd == null) return false;
    if (state.collecting_advanced) {
        state.advanced_labels[state.advanced_label_count] = hwnd;
        state.advanced_label_count += 1;
    }
    _ = c.SendMessageW(hwnd, c.WM_SETFONT, @intFromPtr(formFont()), 1);
    return true;
}

fn button(state: *State, control: Control, text: [*c]const u16, tip: [*c]const u16, icon: ui.Icon, primary: bool, x: i32, y: i32, width: i32) bool {
    if (ui.font == null) {
        return child(state, control, L("BUTTON"), text,
            @as(c.DWORD, c.WS_TABSTOP) | @as(c.DWORD, if (primary) c.BS_DEFPUSHBUTTON else c.BS_PUSHBUTTON),
            x, y, width, 36);
    }
    const hwnd = ui.button(state.hwnd, text, tip, 0, icon, primary);
    state.controls[@intFromEnum(control)] = hwnd;
    if (hwnd == null) return false;
    _ = c.SetWindowLongPtrW(hwnd, c.GWLP_ID, @intCast(controlId(control)));
    ui.place(hwnd, x, y, width, 36, false);
    return true;
}

fn positionStatus(state: *State, width: i32) void {
    if (state.get(.status) != null) {
        _ = c.MoveWindow(state.get(.status), sidebar_width + 24, 62,
            @max(1, width - sidebar_width - 48), 36, c.TRUE);
    }
    var client: c.RECT = undefined;
    _ = c.GetClientRect(state.hwnd, &client);
    _ = c.MoveWindow(state.get(.print), sidebar_inset, client.bottom - 54, 120, 36, c.TRUE);
    _ = c.MoveWindow(state.get(.cancel), 152, client.bottom - 54, 120, 36, c.TRUE);
}

fn addItems(hwnd: c.HWND, items: []const [*c]const u16) void {
    for (items) |item| _ = c.SendMessageW(hwnd, c.CB_ADDSTRING, 0, @bitCast(@intFromPtr(item)));
    _ = c.SendMessageW(hwnd, c.CB_SETCURSEL, 0, 0);
}

fn createControls(state: *State) bool {
    const combo_style = c.WS_TABSTOP | c.WS_VSCROLL | c.CBS_DROPDOWNLIST;
    // Each static immediately precedes its field in child order, so native
    // accessibility and dialog-key navigation associate the correct label.
    if (!label(state, L("Drukarka:"), sidebar_inset, 54, 140, 18) or
        !child(state, .printer, L("STATIC"), L("Nie wybrano"), c.SS_LEFTNOWORDWRAP | c.SS_ENDELLIPSIS, sidebar_inset, 78, 124, 20) or
        !button(state, .setup, L("Wybierz…"), L("Wybierz drukarkę. Nie rozpoczyna drukowania."), .printer, false, 152, 64, 120) or
        !label(state, L("Papier:"), sidebar_inset, 112, 136, 18) or
        !child(state, .paper, L("COMBOBOX"), L(""), combo_style, sidebar_inset, 132, 136, 360) or
        !label(state, L("Orientacja:"), 168, 112, 104, 18) or
        !child(state, .orientation, L("COMBOBOX"), L(""), combo_style, 168, 132, 104, 100) or
        !label(state, L("Skala obrazu:"), sidebar_inset, 170, form_width, 18) or
        !child(state, .scale, L("COMBOBOX"), L(""), combo_style, sidebar_inset, 190, form_width, 210) or
        !label(state, L("Kolor:"), sidebar_inset, 228, form_width, 18) or
        !child(state, .color, L("COMBOBOX"), L(""), combo_style, sidebar_inset, 248, form_width, 100)) return false;
    addItems(state.get(.paper), &.{ L("A4"), L("A5"), L("Letter"), L("10 × 15 cm"), L("A3"), L("A6"), L("B4 (ISO)"), L("B5 (ISO)"), L("Legal"), L("Executive"), L("Tabloid"), L("13 × 18 cm"), L("15 × 20 cm"), L("20 × 25 cm"), L("4 × 6 cali"), L("5 × 7 cali"), L("8 × 10 cali"), L("Własny (mm)"), L("Z drukarki") });
    addItems(state.get(.orientation), &.{ L("Pionowa"), L("Pozioma") });
    addItems(state.get(.scale), &.{ L("Dopasuj (cały obraz)"), L("Wypełnij (przytnij)"), L("Rozciągnij (cała strona)"), L("100% (96 DPI)"), L("Własny procent"), L("Szerokość (mm)"), L("Wysokość (mm)") });
    addItems(state.get(.color), &.{ L("Kolor"), L("Skala szarości") });
    if (!child(state, .advanced, L("BUTTON"), L("Zaawansowane ▸"), c.WS_TABSTOP | c.BS_PUSHBUTTON, sidebar_inset, 290, form_width, 30)) return false;
    state.collecting_advanced = true;
    const edit_style = c.WS_TABSTOP | c.WS_BORDER | c.ES_AUTOHSCROLL;
    if (!child(state, .value_label, L("STATIC"), L("Wartość skali:"), 0, sidebar_inset, 334, 146, 20) or
        !child(state, .value, L("EDIT"), L("100"), edit_style, 178, 330, 94, 24) or
        !label(state, L("Papier mm:"), sidebar_inset, 364, 86, 20) or
        !child(state, .media_width, L("EDIT"), L("210"), edit_style, 112, 360, 72, 24) or
        !label(state, L("×"), 188, 364, 12, 20) or
        !child(state, .media_height, L("EDIT"), L("297"), edit_style, 202, 360, 70, 24) or
        !label(state, L("Marginesy (mm):"), sidebar_inset, 392, form_width, 18) or
        !label(state, L("Lewy:"), sidebar_inset, 418, 52, 18) or
        !child(state, .left, L("EDIT"), L("0"), edit_style, 80, 414, 64, 24) or
        !label(state, L("Prawy:"), 152, 418, 55, 18) or
        !child(state, .right, L("EDIT"), L("0"), edit_style, 210, 414, 62, 24) or
        !label(state, L("Górny:"), sidebar_inset, 448, 52, 18) or
        !child(state, .top, L("EDIT"), L("0"), edit_style, 80, 444, 64, 24) or
        !label(state, L("Dolny:"), 152, 448, 55, 18) or
        !child(state, .bottom, L("EDIT"), L("0"), edit_style, 210, 444, 62, 24) or
        !label(state, L("Pozycja od rogu arkusza (mm):"), sidebar_inset, 478, form_width, 18) or
        !label(state, L("X:"), sidebar_inset, 504, 24, 18) or
        !child(state, .x, L("EDIT"), L("10"), edit_style, 52, 500, 92, 24) or
        !label(state, L("Y:"), 152, 504, 24, 18) or
        !child(state, .y, L("EDIT"), L("10"), edit_style, 180, 500, 92, 24) or
        !child(state, .center, L("BUTTON"), L("Wyśrodkuj / reset pozycji"), c.WS_TABSTOP | c.BS_PUSHBUTTON, sidebar_inset, 532, form_width, 28) or
        !child(state, .details, L("STATIC"), L(""), 0, sidebar_inset, 570, form_width, 42)) return false;
    state.collecting_advanced = false;
    for ([_]Control{ .left, .right, .top, .bottom, .value, .media_width, .media_height, .x, .y }) |control| {
        _ = c.SendMessageW(state.get(control), c.EM_SETLIMITTEXT, 16, 0);
    }
    if (!button(state, .print, L("Drukuj"), L("Wydrukuj bieżący układ po potwierdzeniu."), .printer, true, sidebar_inset, 630, 120) or
        !button(state, .cancel, L("Wróć"), L("Zamknij podgląd; podczas drukowania przerwij zadanie."), .previous, false, 152, 630, 120) or
        !child(state, .status, L("STATIC"), L(""), 0, sidebar_width + 24, 62, 400, 36)) return false;
    state.tooltip = c.CreateWindowExW(c.WS_EX_TOPMOST, L("tooltips_class32"), null, c.WS_POPUP | c.TTS_ALWAYSTIP | c.TTS_NOPREFIX, c.CW_USEDEFAULT, c.CW_USEDEFAULT, c.CW_USEDEFAULT, c.CW_USEDEFAULT, state.hwnd, null, c.GetModuleHandleW(null), null);
    addTip(state, .scale, L("100% i własny procent: 1 piksel = 1/96 cala. Wymiary w mm zachowują proporcje."));
    addTip(state, .value, L("Procent: 0,1–1000. Wymiar: 0,1–10000 mm. Proporcje są zablokowane."));
    addTip(state, .media_width, L("Własny papier: szerokość i wysokość 10–3276,7 mm, przed obrotem."));
    addTip(state, .media_height, L("Własny papier: szerokość i wysokość 10–3276,7 mm, przed obrotem."));
    addTip(state, .x, L("Od lewego górnego rogu fizycznego arkusza, nie od marginesów. Zakres ±10000 mm."));
    addTip(state, .y, L("Od lewego górnego rogu fizycznego arkusza, nie od marginesów. Zakres ±10000 mm."));
    addTip(state, .color, L("Dotyczy tylko podglądu i wydruku. Obraz źródłowy pozostaje bez zmian."));
    addTip(state, .details, L("Arkusz / obraz. Szara linia: granica drukarki. Zielona: marginesy."));
    theme.applyTooltip(state.tooltip);
    state.initializing = false;
    showAdvanced(state);
    return true;
}

fn addTip(state: *State, control: Control, text: [*c]const u16) void {
    if (state.tooltip == null) return;
    var tool = std.mem.zeroes(c.TOOLINFOW);
    tool.cbSize = ui.tool_size;
    tool.uFlags = c.TTF_IDISHWND | c.TTF_SUBCLASS;
    tool.hwnd = state.hwnd;
    tool.uId = @intFromPtr(state.get(control));
    tool.lpszText = @constCast(text);
    _ = c.SendMessageW(state.tooltip, c.TTM_ADDTOOLW, 0, @bitCast(@intFromPtr(&tool)));
    _ = c.SendMessageW(state.tooltip, c.TTM_SETMAXTIPWIDTH, 0, 340);
}

fn showAdvanced(state: *State) void {
    const visibility: c.INT = if (state.advanced) c.SW_SHOW else c.SW_HIDE;
    // Hidden controls are also removed from the native dialog Tab order.
    for (advanced_controls) |control| _ = c.ShowWindow(state.get(control), visibility);
    for (state.advanced_labels[0..state.advanced_label_count]) |hwnd| _ = c.ShowWindow(hwnd, visibility);
    _ = c.SetWindowTextW(state.get(.advanced), if (state.advanced) L("Zaawansowane ▾") else L("Zaawansowane ▸"));
    _ = c.EnableWindow(state.get(.value), @intFromBool(@intFromEnum(state.settings.scale) >= @intFromEnum(layout.Scale.percent)));
    const custom = state.paper_index == papers.len;
    _ = c.EnableWindow(state.get(.media_width), @intFromBool(custom));
    _ = c.EnableWindow(state.get(.media_height), @intFromBool(custom));
}

fn stateFor(hwnd: c.HWND) ?*State {
    const value = c.GetWindowLongPtrW(hwnd, c.GWLP_USERDATA);
    if (value == 0) return null;
    return @ptrFromInt(@as(usize, @bitCast(value)));
}

fn windowProc(hwnd: c.HWND, message: c.UINT, wp: c.WPARAM, lp: c.LPARAM) callconv(.Stdcall) c.LRESULT {
    if (message == c.WM_NCCREATE) {
        const create: *c.CREATESTRUCTW = @ptrFromInt(@as(usize, @bitCast(lp)));
        const state: *State = @ptrCast(@alignCast(create.lpCreateParams orelse return 0));
        state.hwnd = hwnd;
        _ = c.SetWindowLongPtrW(hwnd, c.GWLP_USERDATA, @bitCast(@intFromPtr(state)));
        // Let Windows initialize its non-client state, including copying the
        // creation caption. Returning TRUE directly leaves the title empty.
        return c.DefWindowProcW(hwnd, message, wp, lp);
    }
    const state = stateFor(hwnd) orelse return c.DefWindowProcW(hwnd, message, wp, lp);
    switch (message) {
        c.WM_CREATE => {
            state.background_brush = c.CreateSolidBrush(ui.shell);
            return if (createControls(state)) 0 else -1;
        },
        c.WM_DRAWITEM => {
            if (lp != 0) {
                const item: *const c.DRAWITEMSTRUCT = @ptrFromInt(@as(usize, @bitCast(lp)));
                if (ui.drawButton(item)) return c.TRUE;
            }
        },
        c.WM_CTLCOLORSTATIC, c.WM_CTLCOLORBTN => {
            const dc = nativeHandle(c.HDC, wp);
            const control: usize = @bitCast(lp);
            _ = c.SetBkMode(dc, c.TRANSPARENT);
            _ = c.SetBkColor(dc, ui.shell);
            _ = c.SetTextColor(dc, if (control == @intFromPtr(state.get(.status))) ui.accent else if (control == @intFromPtr(state.get(.details))) ui.muted else ui.ink);
            const brush = state.background_brush orelse c.GetSysColorBrush(c.COLOR_BTNFACE);
            return @bitCast(@intFromPtr(brush));
        },
        c.WM_CTLCOLOREDIT, c.WM_CTLCOLORLISTBOX => {
            if (theme.dialogColor(message, wp)) |brush| return brush;
        },
        theme.changed_message => {
            if (state.background_brush != null) _ = c.DeleteObject(state.background_brush);
            state.background_brush = c.CreateSolidBrush(ui.shell);
            theme.applyTooltip(state.tooltip);
            _ = c.InvalidateRect(hwnd, null, c.FALSE);
            return 0;
        },
        c.WM_GETMINMAXINFO => {
            const info: *c.MINMAXINFO = @ptrFromInt(@as(usize, @bitCast(lp)));
            info.ptMinTrackSize.x = 760;
            info.ptMinTrackSize.y = 730;
            return 0;
        },
        c.WM_SIZE => {
            const width: i32 = @intCast(@as(usize, @bitCast(lp)) & 0xffff);
            positionStatus(state, width);
            _ = c.InvalidateRect(hwnd, null, c.FALSE);
            return 0;
        },
        c.WM_ERASEBKGND => return 1,
        c.WM_PAINT => {
            paint(state);
            return 0;
        },
        c.WM_NCPAINT, c.WM_NCACTIVATE => {
            // Hidden frame edge sampled by DPI scaling (theme.paintFrameEdge).
            const result = c.DefWindowProcW(hwnd, message, wp, lp);
            theme.paintFrameEdge(hwnd, theme.colors.shell);
            return result;
        },
        c.WM_COMMAND => {
            var id = wp & 0xffff;
            const event = (wp >> 16) & 0xffff;
            // IsDialogMessage can send IDOK for an owner-drawn button. Keep
            // Enter on Setup/Back equivalent to clicking that focused button.
            if (id == c.IDOK and event == c.BN_CLICKED) {
                const focus = c.GetFocus();
                if (focus != null and focus == state.get(.cancel)) {
                    id = controlId(.cancel);
                } else {
                    for ([_]Control{ .setup, .advanced, .center }) |control| {
                        if (focus != null and focus == state.get(control)) id = controlId(control);
                    }
                }
            }
            if (id == c.IDCANCEL) {
                closeOrCancel(state);
            } else if (!state.initializing and !state.printing) {
                if ((id == controlId(.print) or id == c.IDOK) and event == c.BN_CLICKED) {
                    printPage(state);
                } else if (id == controlId(.setup) and event == c.BN_CLICKED) {
                    selectPrinter(state);
                } else if (id == controlId(.advanced) and event == c.BN_CLICKED) {
                    state.advanced = !state.advanced;
                    showAdvanced(state);
                } else if (id == controlId(.center) and event == c.BN_CLICKED) {
                    state.settings.position = null;
                    state.settings.center = true;
                    refresh(state);
                } else if ((id == controlId(.paper) or id == controlId(.orientation)) and event == c.CBN_SELCHANGE) {
                    if (id == controlId(.orientation)) state.automatic_orientation = false;
                    formatChanged(state);
                } else if ((id == controlId(.media_width) or id == controlId(.media_height)) and event == c.EN_CHANGE) {
                    formatChanged(state);
                } else if (id == controlId(.scale) and event == c.CBN_SELCHANGE) {
                    state.settings.scale = selectedScale(state);
                    saveScale(state.settings.scale);
                    if (@intFromEnum(state.settings.scale) >= @intFromEnum(layout.Scale.percent)) {
                        state.initializing = true;
                        setNumber(state.get(.value), if (state.settings.scale == .percent) state.settings.percent else state.settings.physical_mm);
                        state.initializing = false;
                        state.advanced = true;
                    }
                    refresh(state);
                } else if (id == controlId(.color) and event == c.CBN_SELCHANGE) {
                    state.grayscale = c.SendMessageW(state.get(.color), c.CB_GETCURSEL, 0, 0) == 1;
                    if (state.dc != null) {
                        state.printer_ready = applyPrinterFormat(state, state.paper_index, state.orientation);
                    }
                    refresh(state);
                } else if (event == c.EN_CHANGE) {
                    if (id == controlId(.x) or id == controlId(.y)) {
                        if (state.settings.position == null) state.settings.position = .{ .x = 0, .y = 0 };
                    }
                    refresh(state);
                }
            }
            return 0;
        },
        c.WM_LBUTTONDOWN => {
            if (!state.printing and state.input_valid and state.geometry_valid) beginDrag(state, mousePoint(lp));
            return 0;
        },
        c.WM_MOUSEMOVE => {
            if (state.dragging) moveDrag(state, mousePoint(lp));
            return 0;
        },
        c.WM_LBUTTONUP => {
            if (state.dragging) {
                moveDrag(state, mousePoint(lp));
                state.dragging = false;
                _ = c.ReleaseCapture();
            }
            return 0;
        },
        c.WM_CAPTURECHANGED => state.dragging = false,
        c.WM_KEYDOWN => if (wp == c.VK_ESCAPE) {
            closeOrCancel(state);
            return 0;
        },
        c.WM_CLOSE => {
            closeOrCancel(state);
            return 0;
        },
        c.WM_NCDESTROY => {
            if (state.tooltip != null) _ = c.DestroyWindow(state.tooltip);
            state.tooltip = null;
            if (state.background_brush != null) _ = c.DeleteObject(state.background_brush);
            state.background_brush = null;
            _ = c.SetWindowLongPtrW(hwnd, c.GWLP_USERDATA, 0);
            state.hwnd = null;
        },
        else => {},
    }
    return c.DefWindowProcW(hwnd, message, wp, lp);
}

fn closeOrCancel(state: *State) void {
    if (state.printing) {
        state.cancel_requested = true;
        status(state, L("Przerywanie zadania drukowania…"));
    } else {
        restoreOwner(state);
        _ = c.DestroyWindow(state.hwnd);
    }
}

fn restoreOwner(state: *State) void {
    const owner = state.owner orelse return;
    state.owner = null;
    if (c.IsWindow(owner) == 0) return;
    _ = c.EnableWindow(owner, c.TRUE);
    _ = c.SetActiveWindow(owner);
}

fn status(state: *State, text: [*c]const u16) void {
    _ = c.SetWindowTextW(state.get(.status), text);
}

/// Empty/whitespace means zero. Both Polish decimal comma and dot are accepted;
/// signs, exponents, NaN and infinity are deliberately not numeric UI input.
fn parseMargin(text: []const u16) ?f64 {
    var start: usize = 0;
    var end = text.len;
    while (start < end and (text[start] == ' ' or text[start] == '\t')) : (start += 1) {}
    while (end > start and (text[end - 1] == ' ' or text[end - 1] == '\t')) : (end -= 1) {}
    if (start == end) return 0;
    if (end - start > 31) return null;
    var ascii: [32]u8 = undefined;
    for (text[start..end], 0..) |ch, i| {
        ascii[i] = if (ch == ',' or ch == '.') '.' else if (ch >= '0' and ch <= '9') @intCast(ch) else return null;
    }
    const value = std.fmt.parseFloat(f64, ascii[0 .. end - start]) catch return null;
    return if (std.math.isFinite(value) and value >= 0 and value <= 10000) value else null;
}

fn margin(hwnd: c.HWND) ?f64 {
    var buffer: [32]u16 = undefined;
    const length = c.GetWindowTextW(hwnd, &buffer, buffer.len);
    if (length < 0) return null;
    return parseMargin(buffer[0..@intCast(length)]);
}

/// Strict numeric fields (unlike legacy empty=zero margins). Decimal comma and
/// dot are accepted, but never exponents/NaN/Inf or an incomplete decimal.
fn parseNumber(text: []const u16, minimum: f64, maximum: f64) ?f64 {
    var start: usize = 0;
    var end = text.len;
    while (start < end and (text[start] == ' ' or text[start] == '\t')) : (start += 1) {}
    while (end > start and (text[end - 1] == ' ' or text[end - 1] == '\t')) : (end -= 1) {}
    if (start == end or end - start > 31) return null;
    var ascii: [32]u8 = undefined;
    var digits: usize = 0;
    var separators: usize = 0;
    for (text[start..end], 0..) |ch, i| {
        if (ch >= '0' and ch <= '9') {
            ascii[i] = @intCast(ch);
            digits += 1;
        } else if (ch == ',' or ch == '.') {
            ascii[i] = '.';
            separators += 1;
        } else if (ch == '-' and i == 0 and minimum < 0) {
            ascii[i] = '-';
        } else return null;
    }
    if (digits == 0 or separators > 1 or ascii[end - start - 1] == '.') return null;
    const value = std.fmt.parseFloat(f64, ascii[0 .. end - start]) catch return null;
    return if (std.math.isFinite(value) and value >= minimum and value <= maximum) value else null;
}

fn number(hwnd: c.HWND, minimum: f64, maximum: f64) ?f64 {
    var buffer: [40]u16 = undefined;
    const length = c.GetWindowTextW(hwnd, &buffer, buffer.len);
    if (length < 0) return null;
    return parseNumber(buffer[0..@intCast(length)], minimum, maximum);
}

fn setNumber(hwnd: c.HWND, value: f64) void {
    var ascii: [48]u8 = undefined;
    const text = std.fmt.bufPrint(&ascii, "{d:.3}", .{value}) catch return;
    var wide: [48]u16 = undefined;
    _ = c.SetWindowTextW(hwnd, w.utf16(&wide, text).ptr);
}

fn selectedScale(state: *State) layout.Scale {
    const index = c.SendMessageW(state.get(.scale), c.CB_GETCURSEL, 0, 0);
    const count = std.meta.fields(layout.Scale).len;
    // Combo items are in enum order.
    return if (index > 0 and index < count) @enumFromInt(index) else .fit;
}

// The last chosen "Skala obrazu" is kept in the existing portable Kadr.ini.
const scale_names = [_][]const u8{ "fit", "fill", "stretch", "actual", "percent", "width", "height" };
comptime {
    std.debug.assert(scale_names.len == std.meta.fields(layout.Scale).len);
}
pub fn scaleFromName(name: []const u8) ?layout.Scale {
    for (scale_names, 0..) |n, i| if (std.mem.eql(u8, n, name)) return @enumFromInt(i);
    return null;
}
fn loadScale() layout.Scale {
    const path = i18n.settingsPath();
    if (path.len == 0) return .fit;
    var wide: [16]u16 = [_]u16{0} ** 16;
    const n = c.GetPrivateProfileStringW(w.L("Print"), w.L("Scale"), w.L(""), &wide, wide.len, path.ptr);
    if (n == 0 or n >= 15) return .fit;
    var ascii: [16]u8 = undefined;
    for (wide[0..n], 0..) |ch, i| ascii[i] = if (ch < 128) @intCast(ch) else '?';
    return scaleFromName(ascii[0..n]) orelse .fit;
}
fn saveScale(scale: layout.Scale) void {
    const path = i18n.settingsPath();
    if (path.len == 0) return;
    var wide: [16]u16 = undefined;
    _ = c.WritePrivateProfileStringW(w.L("Print"), w.L("Scale"), w.utf16(&wide, scale_names[@intFromEnum(scale)]).ptr, path.ptr);
}

fn refresh(state: *State) void {
    if (state.initializing) return;
    var settings = state.settings;
    settings.scale = selectedScale(state);
    const left = margin(state.get(.left));
    const top = margin(state.get(.top));
    const right = margin(state.get(.right));
    const bottom = margin(state.get(.bottom));
    state.margins_valid = left != null and top != null and right != null and bottom != null;
    state.input_valid = state.margins_valid;
    if (state.margins_valid) settings.margins = .{ .left = left.?, .top = top.?, .right = right.?, .bottom = bottom.? };
    if (settings.scale == .percent) {
        if (number(state.get(.value), 0.1, 1000)) |v| settings.percent = v else state.input_valid = false;
    } else if (settings.scale == .width_mm or settings.scale == .height_mm) {
        if (number(state.get(.value), 0.1, 10000)) |v| settings.physical_mm = v else state.input_valid = false;
    }
    if (settings.position != null) {
        const x = number(state.get(.x), -10000, 10000);
        const y = number(state.get(.y), -10000, 10000);
        if (x != null and y != null) settings.position = .{ .x = x.?, .y = y.? } else state.input_valid = false;
    }
    if (state.paper_index == papers.len) {
        state.input_valid = state.input_valid and number(state.get(.media_width), layout.min_media_mm, layout.max_media_mm) != null and number(state.get(.media_height), layout.min_media_mm, layout.max_media_mm) != null;
    }
    state.geometry_valid = false;
    if (state.input_valid) {
        const placement = layout.place(state.page, .{ .width = state.source.width, .height = state.source.height }, settings);
        state.geometry_valid = placement != null;
        state.settings = settings;
        // Preserve the last valid preview on incomplete input or off-sheet edits.
        if (placement) |p| {
            state.placement = p;
            if (settings.position == null) {
                state.initializing = true;
                setNumber(state.get(.x), p.image.x);
                setNumber(state.get(.y), p.image.y);
                state.initializing = false;
            }
        }
    }
    _ = c.SetWindowTextW(state.get(.value_label), if (settings.scale == .percent) L("Procent (96 DPI):") else if (settings.scale == .width_mm) L("Szerokość (mm):") else if (settings.scale == .height_mm) L("Wysokość (mm):") else L("Wartość skali:"));
    showAdvanced(state);
    _ = c.EnableWindow(state.get(.print), @intFromBool(!state.printing and state.dc != null and state.printer_ready and state.input_valid and state.geometry_valid));
    if (!state.input_valid) {
        status(state, L("Popraw liczby. Zachowano ostatni poprawny podgląd."));
    } else if (!state.geometry_valid) {
        status(state, L("Obraz poza obszarem druku. Zmień marginesy lub wyśrodkuj."));
    } else if (state.dc == null) {
        status(state, L("Wybierz drukarkę, aby sprawdzić rzeczywisty obszar druku."));
    } else if (!state.printer_ready) {
        status(state, L("Nie przyjęto ustawień. Wybierz drukarkę ponownie."));
    } else if (state.driver_changed) {
        status(state, L("Sterownik zmienił format. Podgląd pokazuje przyjęty arkusz."));
    } else if (state.driver_color_changed) {
        status(state, L("Drukarka przyjęła skalę szarości zamiast koloru."));
    } else if (state.placement != null and isClipped(state.placement.?)) {
        status(state, L("Część obrazu zostanie przycięta do obszaru druku."));
    } else {
        status(state, L("Obraz mieści się w obszarze druku."));
    }
    updateSummary(state);
    _ = c.InvalidateRect(state.hwnd, null, c.FALSE);
}

fn isClipped(p: layout.Placement) bool {
    return p.image.x < p.clip.x - 0.01 or p.image.y < p.clip.y - 0.01 or p.image.right() > p.clip.right() + 0.01 or p.image.bottom() > p.clip.bottom() + 0.01;
}

fn updateSummary(state: *State) void {
    var ascii: [160]u8 = undefined;
    const p = state.placement;
    const text = std.fmt.bufPrint(&ascii, "{d:.1} × {d:.1} mm\r\n{d:.1} × {d:.1} mm", .{
        state.page.width, state.page.height, if (p) |v| v.image.width else @as(f64, 0), if (p) |v| v.image.height else @as(f64, 0),
    }) catch return;
    var wide: [160]u16 = undefined;
    _ = c.SetWindowTextW(state.get(.details), w.utf16(&wide, text).ptr);
    _ = c.SetWindowTextW(state.get(.printer), if (state.dc != null) @as([*:0]const u16, @ptrCast(&state.printer_name)) else L("Nie wybrano"));
}

fn deviceCaps(dc: c.HDC) layout.DeviceCaps {
    return .{
        .dpi_x = c.GetDeviceCaps(dc, c.LOGPIXELSX), .dpi_y = c.GetDeviceCaps(dc, c.LOGPIXELSY),
        .physical_width = c.GetDeviceCaps(dc, c.PHYSICALWIDTH), .physical_height = c.GetDeviceCaps(dc, c.PHYSICALHEIGHT),
        .offset_x = c.GetDeviceCaps(dc, c.PHYSICALOFFSETX), .offset_y = c.GetDeviceCaps(dc, c.PHYSICALOFFSETY),
        .printable_width = c.GetDeviceCaps(dc, c.HORZRES), .printable_height = c.GetDeviceCaps(dc, c.VERTRES),
    };
}

fn samePage(a: layout.Page, b: layout.Page) bool {
    // Driver caps are integral device pixels; tolerate sub-mm quantization only.
    return @fabs(a.width - b.width) < 0.7 and @fabs(a.height - b.height) < 0.7;
}

fn syncPageControls(state: *State) void {
    state.orientation = if (state.page.width > state.page.height) .landscape else .portrait;
    state.paper_index = papers.len + 1;
    for (papers, 0..) |paper, i| {
        if (samePage(layout.paperPage(paper, state.orientation), state.page)) {
            state.paper_index = i;
            break;
        }
    }
    _ = c.SendMessageW(state.get(.paper), c.CB_SETCURSEL, state.paper_index, 0);
    _ = c.SendMessageW(state.get(.orientation), c.CB_SETCURSEL, @intFromBool(state.orientation == .landscape), 0);
}

fn requestedPage(state: *State, index: usize, orientation: layout.Orientation) ?layout.Page {
    if (index < papers.len) return layout.paperPage(papers[index], orientation);
    if (index == papers.len) return layout.customPage(state.media_width, state.media_height, orientation);
    // Keep the accepted physical dimensions for driver-specific forms.
    const width = if (state.orientation == .portrait) state.page.width else state.page.height;
    const height = if (state.orientation == .portrait) state.page.height else state.page.width;
    return layout.customPage(width, height, orientation);
}

fn cachePrinterName(state: *State) void {
    @memset(&state.printer_name, 0);
    const raw = c.GlobalLock(state.devnames) orelse return;
    defer _ = c.GlobalUnlock(state.devnames);
    const names: *const c.DEVNAMES = @ptrCast(@alignCast(raw));
    const base: [*]const u16 = @ptrCast(@alignCast(raw));
    const name = base + names.wDeviceOffset;
    var i: usize = 0;
    while (i + 1 < state.printer_name.len and name[i] != 0) : (i += 1) state.printer_name[i] = name[i];
}

/// Takes ownership of dc, even on failure. A driver which ignores a requested
/// format cannot cause a preview/print mismatch: physical caps always win.
fn acceptDC(state: *State, dc: c.HDC) bool {
    if (dc == null) return false;
    const caps = deviceCaps(dc);
    const page = layout.pageFromDevice(caps) orelse {
        _ = c.DeleteDC(dc);
        return false;
    };
    if (state.dc != null) _ = c.DeleteDC(state.dc);
    state.dc = dc;
    state.caps = caps;
    state.page = page;
    state.printer_ready = true;
    cachePrinterName(state);
    syncPageControls(state);
    refresh(state);
    return true;
}

fn loadDefaultPrinter(state: *State) void {
    const chosen_index = state.paper_index;
    const chosen_orientation = state.orientation;
    var pd = std.mem.zeroes(c.PRINTDLGW);
    pd.lStructSize = @sizeOf(c.PRINTDLGW);
    pd.hwndOwner = state.hwnd;
    pd.Flags = c.PD_RETURNDEFAULT | c.PD_RETURNDC;
    const ok = c.PrintDlgW(&pd) != 0;
    state.devmode = pd.hDevMode;
    state.devnames = pd.hDevNames;
    if (ok) {
        if (acceptDC(state, pd.hDC)) {
            // Keep the image-based orientation instead of forcing A4/portrait.
            state.printer_ready = applyPrinterFormat(state, chosen_index, preferredOrientation(state, chosen_index, chosen_orientation));
        }
    } else if (pd.hDC != null) {
        _ = c.DeleteDC(pd.hDC);
    }
}

fn selectPrinter(state: *State) void {
    const chosen_index = state.paper_index;
    const chosen_orientation = state.orientation;
    const chosen_page = state.page;
    var pd = std.mem.zeroes(c.PRINTDLGW);
    pd.lStructSize = @sizeOf(c.PRINTDLGW);
    pd.hwndOwner = state.hwnd;
    pd.hDevMode = state.devmode;
    pd.hDevNames = state.devnames;
    pd.Flags = c.PD_PRINTSETUP | c.PD_RETURNDC | c.PD_HIDEPRINTTOFILE | c.PD_DISABLEPRINTTOFILE;
    pd.nCopies = 1;
    const ok = c.PrintDlgW(&pd) != 0;
    const dialog_error = if (!ok) c.CommDlgExtendedError() else 0;
    // The common dialog may reallocate the input global handles. Always keep
    // the returned handles; do not free stale pre-dialog copies of them.
    state.devmode = pd.hDevMode;
    state.devnames = pd.hDevNames;
    if (!ok) {
        if (pd.hDC != null) _ = c.DeleteDC(pd.hDC);
        if (dialog_error != 0) notify(state.hwnd, L("Nie można otworzyć ustawień drukarki. Sprawdź, czy drukarka jest zainstalowana i dostępna."), c.MB_ICONEXCLAMATION);
        return; // Cancel is not an error and never starts a job.
    }
    if (!acceptDC(state, pd.hDC)) {
        state.printer_ready = false;
        refresh(state);
        notify(state.hwnd, L("Drukarka nie udostępnia poprawnego rozmiaru papieru lub obszaru druku. Nie rozpoczęto drukowania."), c.MB_ICONEXCLAMATION);
        return;
    }
    if (chosen_index == papers.len + 1) {
        state.media_width = if (chosen_orientation == .portrait) chosen_page.width else chosen_page.height;
        state.media_height = if (chosen_orientation == .portrait) chosen_page.height else chosen_page.width;
    }
    // Printer selection is not permission to replace the chosen medium/color.
    const requested_index = if (chosen_index == papers.len + 1) papers.len else chosen_index;
    state.printer_ready = applyPrinterFormat(state, requested_index, preferredOrientation(state, requested_index, chosen_orientation));
    refresh(state);
    _ = c.UpdateWindow(state.hwnd);
}

test "automatic orientation follows pixels and custom media but preserves manual choice" {
    var state = State{ .source = .{ .image = @ptrFromInt(1), .width = 1600, .height = 900 } };
    try std.testing.expectEqual(layout.Orientation.landscape, preferredOrientation(&state, 0, .portrait));
    state.source = .{ .image = @ptrFromInt(1), .width = 900, .height = 1600 };
    try std.testing.expectEqual(layout.Orientation.portrait, preferredOrientation(&state, 0, .landscape));
    state.source = .{ .image = @ptrFromInt(1), .width = 100, .height = 100 };
    try std.testing.expectEqual(layout.Orientation.landscape, preferredOrientation(&state, 0, .landscape));
    state.source = .{ .image = @ptrFromInt(1), .width = 1600, .height = 900 };
    state.automatic_orientation = false;
    try std.testing.expectEqual(layout.Orientation.portrait, preferredOrientation(&state, 0, .portrait));
    state.automatic_orientation = true;
    state.media_width = 300;
    state.media_height = 100;
    try std.testing.expectEqual(layout.Orientation.portrait, preferredOrientation(&state, papers.len, .landscape));
    state.source = .{ .image = @ptrFromInt(1), .width = 900, .height = 1600 };
    try std.testing.expectEqual(layout.Orientation.landscape, preferredOrientation(&state, papers.len, .portrait));
}

// Custom forms retain their entered base dimensions, even when already wide.
// Convert the physical best-fit orientation back to that form's rotation.
fn preferredOrientation(state: *State, index: usize, manual: layout.Orientation) layout.Orientation {
    if (!state.automatic_orientation) return manual;
    const base = requestedPage(state, index, .portrait) orelse return manual;
    const wide_base = base.width > base.height;
    const preferred = if (wide_base) oppositeOrientation(manual) else manual;
    const best = layout.bestFitOrientation(state.source.width, state.source.height, base, state.settings.margins, preferred);
    return if (wide_base) oppositeOrientation(best) else best;
}
fn oppositeOrientation(orientation: layout.Orientation) layout.Orientation {
    return if (orientation == .portrait) .landscape else .portrait;
}
fn formatChanged(state: *State) void {
    const index = c.SendMessageW(state.get(.paper), c.CB_GETCURSEL, 0, 0);
    var orientation: layout.Orientation = if (c.SendMessageW(state.get(.orientation), c.CB_GETCURSEL, 0, 0) == 1) .landscape else .portrait;
    if (index < 0 or index > papers.len + 1) return;
    const requested: usize = @intCast(index);
    if (requested == papers.len) {
        state.paper_index = requested;
        state.advanced = true;
        const width = number(state.get(.media_width), layout.min_media_mm, layout.max_media_mm);
        const height = number(state.get(.media_height), layout.min_media_mm, layout.max_media_mm);
        if (width == null or height == null) {
            refresh(state);
            return;
        }
        state.media_width = width.?;
        state.media_height = height.?;
    }
    orientation = preferredOrientation(state, requested, orientation);
    if (state.dc == null) {
        if (requestedPage(state, requested, orientation)) |page| {
            state.paper_index = requested;
            state.orientation = orientation;
            state.page = page;
            _ = c.SendMessageW(state.get(.orientation), c.CB_SETCURSEL, @intFromBool(orientation == .landscape), 0);
        }
        refresh(state);
        return;
    }
    if (!applyPrinterFormat(state, requested, orientation)) {
        syncPageControls(state);
        refresh(state);
        status(state, L("Sterownik odrzucił papier. Zachowano przyjęty arkusz."));
    } else refresh(state);
}

fn applyPrinterFormat(state: *State, paper_index: usize, orientation: layout.Orientation) bool {
    if (state.devmode == null or state.devnames == null) return false;
    const names_raw = c.GlobalLock(state.devnames) orelse return false;
    defer _ = c.GlobalUnlock(state.devnames);
    const names: *const c.DEVNAMES = @ptrCast(@alignCast(names_raw));
    const base: [*]const u16 = @ptrCast(@alignCast(names_raw));
    const device: [*:0]const u16 = @ptrCast(base + names.wDeviceOffset);
    var printer: c.HANDLE = null;
    if (OpenPrinterW(device, &printer, null) == 0) return false;
    defer _ = ClosePrinter(printer);
    const required = DocumentPropertiesW(state.hwnd, printer, device, null, null, 0);
    if (required <= 0) return false;
    const old_size = c.GlobalSize(state.devmode);
    if (old_size < @sizeOf(c.DEVMODEW)) return false;
    const size = @max(@as(usize, @intCast(required)), old_size);
    if (size > 16 * 1024 * 1024) return false;
    const new_handle = c.GlobalAlloc(c.GMEM_MOVEABLE | c.GMEM_ZEROINIT, size);
    if (new_handle == null) return false;
    var adopted = false;
    defer if (!adopted) { _ = c.GlobalFree(new_handle); };
    const raw = c.GlobalLock(new_handle) orelse return false;
    defer _ = c.GlobalUnlock(new_handle);
    const old_raw = c.GlobalLock(state.devmode) orelse return false;
    @memcpy(@as([*]u8, @ptrCast(raw))[0..old_size], @as([*]const u8, @ptrCast(old_raw))[0..old_size]);
    _ = c.GlobalUnlock(state.devmode);
    const mode: *c.DEVMODEW = @ptrCast(@alignCast(raw));
    if (mode.dmSize < @sizeOf(c.DEVMODEW) or @as(usize, mode.dmSize) + mode.dmDriverExtra > size) return false;
    const wanted_page = requestedPage(state, paper_index, orientation) orelse return false;
    configureMode(mode, if (paper_index < papers.len) papers[paper_index] else null, wanted_page, orientation, state.grayscale);
    if (DocumentPropertiesW(state.hwnd, printer, device, mode, mode, c.DM_IN_BUFFER | c.DM_OUT_BUFFER) != c.IDOK) return false;
    // A driver-side scale would invalidate our mm/DC placement contract.
    if (mode.dmFields & c.DM_SCALE != 0 and mode.unnamed_0.unnamed_0.dmScale != 100) return false;
    const dc = c.CreateDCW(L("WINSPOOL"), device, null, mode);
    if (dc == null) return false;
    // Check first so a bad DC cannot replace a previously usable one.
    if (layout.pageFromDevice(deviceCaps(dc)) == null) {
        _ = c.DeleteDC(dc);
        return false;
    }
    const old_handle = state.devmode;
    state.devmode = new_handle;
    adopted = true;
    _ = c.GlobalFree(old_handle);
    if (!acceptDC(state, dc)) return false;
    state.driver_changed = !samePage(wanted_page, state.page);
    const actual_grayscale = acceptedGrayscale(state.grayscale, mode);
    state.driver_color_changed = actual_grayscale != state.grayscale;
    state.grayscale = actual_grayscale;
    _ = c.SendMessageW(state.get(.color), c.CB_SETCURSEL, @intFromBool(actual_grayscale), 0);
    if (!state.driver_changed and paper_index == papers.len) {
        // Preserve custom base dimensions and orientation even for a wide form.
        state.paper_index = paper_index;
        state.orientation = orientation;
        _ = c.SendMessageW(state.get(.paper), c.CB_SETCURSEL, paper_index, 0);
        _ = c.SendMessageW(state.get(.orientation), c.CB_SETCURSEL, @intFromBool(orientation == .landscape), 0);
        state.initializing = true;
        setNumber(state.get(.media_width), state.media_width);
        setNumber(state.get(.media_height), state.media_height);
        state.initializing = false;
    }
    return true;
}

fn acceptedGrayscale(requested: bool, mode: *const c.DEVMODEW) bool {
    // A monochrome-only driver cannot promise a color preview. Conversely our
    // matrix still guarantees gray pixels if a color driver ignores dmColor.
    return requested or (mode.dmFields & c.DM_COLOR != 0 and mode.dmColor == c.DMCOLOR_MONOCHROME);
}

fn paperCode(paper: layout.Paper) c.SHORT {
    return @intCast(switch (paper) {
        .a3 => c.DMPAPER_A3, .a4 => c.DMPAPER_A4, .a5 => c.DMPAPER_A5, .a6 => c.DMPAPER_A6,
        .b4 => c.DMPAPER_ISO_B4, .letter => c.DMPAPER_LETTER, .legal => c.DMPAPER_LEGAL,
        .executive => c.DMPAPER_EXECUTIVE, .tabloid => c.DMPAPER_TABLOID,
        // ISO B5, metric photos and inch photos use exact explicit dimensions.
        else => c.DMPAPER_USER,
    });
}

fn configureMode(mode: *c.DEVMODEW, paper: ?layout.Paper, page: layout.Page, orientation: layout.Orientation, grayscale: bool) void {
    mode.dmFields &= ~@as(c.DWORD, c.DM_PAPERWIDTH | c.DM_PAPERLENGTH | c.DM_FORMNAME);
    mode.dmFields |= c.DM_ORIENTATION | c.DM_SCALE | c.DM_PAPERSIZE | c.DM_COLOR;
    mode.unnamed_0.unnamed_0.dmOrientation = @intCast(if (orientation == .portrait) c.DMORIENT_PORTRAIT else c.DMORIENT_LANDSCAPE);
    mode.unnamed_0.unnamed_0.dmScale = 100; // Scaling belongs exclusively to layout.
    mode.dmColor = @intCast(if (grayscale) c.DMCOLOR_MONOCHROME else c.DMCOLOR_COLOR);
    const code = if (paper) |p| paperCode(p) else @as(c.SHORT, c.DMPAPER_USER);
    mode.unnamed_0.unnamed_0.dmPaperSize = code;
    if (code == c.DMPAPER_USER) {
        mode.dmFields |= c.DM_PAPERWIDTH | c.DM_PAPERLENGTH;
        const width = if (orientation == .portrait) page.width else page.height;
        const height = if (orientation == .portrait) page.height else page.width;
        mode.unnamed_0.unnamed_0.dmPaperWidth = @intFromFloat(@round(std.math.clamp(width, layout.min_media_mm, layout.max_media_mm) * 10));
        mode.unnamed_0.unnamed_0.dmPaperLength = @intFromFloat(@round(std.math.clamp(height, layout.min_media_mm, layout.max_media_mm) * 10));
    }
}

const ImageAttributes = opaque {};
const ColorMatrix = extern struct { values: [5][5]f32 };
extern "gdiplus" fn GdipCreateImageAttributes(*?*ImageAttributes) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipDisposeImageAttributes(*ImageAttributes) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipSetImageAttributesColorMatrix(*ImageAttributes, i32, c.BOOL, *const ColorMatrix, ?*const ColorMatrix, i32) callconv(.Stdcall) i32;

fn drawPlacement(dc: c.HDC, source: Source, placement: layout.Placement, transform: layout.Transform, grayscale: bool) bool {
    const saved = c.SaveDC(dc);
    if (saved == 0) return false;
    defer _ = c.RestoreDC(dc, saved);
    const white_rect = integerRect(transform.rect(placement.clip));
    fill(dc, &white_rect, w.rgb(255, 255, 255)); // Transparent pixels over white, also on a printer DC.
    var attributes: ?*ImageAttributes = null;
    defer if (attributes) |a| { _ = GdipDisposeImageAttributes(a); };
    if (grayscale) {
        if (GdipCreateImageAttributes(&attributes) != 0 or attributes == null) return false;
        const matrix = ColorMatrix{ .values = .{
            .{ 0.299, 0.299, 0.299, 0, 0 }, .{ 0.587, 0.587, 0.587, 0, 0 },
            .{ 0.114, 0.114, 0.114, 0, 0 }, .{ 0, 0, 0, 1, 0 }, .{ 0, 0, 0, 0, 1 },
        } };
        if (GdipSetImageAttributesColorMatrix(attributes.?, 1, c.TRUE, &matrix, null, 0) != 0) return false;
    }
    var graphics: ?*w.GpGraphics = null;
    if (w.GdipCreateFromHDC(dc, &graphics) != 0 or graphics == null) return false;
    defer _ = w.GdipDeleteGraphics(graphics.?);
    if (w.GdipSetPageUnit(graphics.?, 2) != 0) return false; // UnitPixel
    _ = w.GdipSetInterpolationMode(graphics.?, 7); // HighQualityBicubic
    const clip = transform.rect(placement.clip);
    const image = transform.rect(placement.image);
    if (w.GdipSetClipRect(graphics.?, @floatCast(clip.x), @floatCast(clip.y), @floatCast(clip.width), @floatCast(clip.height), 0) != 0) return false;
    return w.GdipDrawImageRectRect(graphics.?, source.image,
        @floatCast(image.x), @floatCast(image.y), @floatCast(image.width), @floatCast(image.height),
        0, 0, @floatFromInt(source.width), @floatFromInt(source.height), 2, attributes, null, null) == 0;
}

const JobPlacement = struct { placement: layout.Placement, caps: layout.DeviceCaps };

/// Placement for the page that is really being printed. Uses the preview's
/// placement when the job page matches it; otherwise re-fits (centred, whole
/// image unless the user explicitly chose Fill) on the job's actual page.
fn jobPlacement(state: *State, preview: layout.Placement) ?JobPlacement {
    const caps = deviceCaps(state.dc);
    const page = layout.pageFromDevice(caps) orelse return .{ .placement = preview, .caps = state.caps };
    if (samePage(page, state.page) and caps.dpi_x == state.caps.dpi_x and caps.dpi_y == state.caps.dpi_y and
        caps.offset_x == state.caps.offset_x and caps.offset_y == state.caps.offset_y)
        return .{ .placement = preview, .caps = caps };
    var settings = state.settings;
    settings.position = null;
    settings.center = true;
    // Keep Fill/Stretch; anything size-based is re-fitted so nothing is lost.
    if (settings.scale != .fill and settings.scale != .stretch) settings.scale = .fit;
    const placement = layout.place(page, .{ .width = state.source.width, .height = state.source.height }, settings) orelse return null;
    return .{ .placement = placement, .caps = caps };
}

/// Upper bounds for the raster sent to the printer. 300 DPI is photo quality
/// on every inkjet/laser; the pixel cap keeps memory sane on 32-bit XP.
const print_max_dpi: f64 = 300;
const print_max_pixels: f64 = 16_000_000;

pub fn rasterSize(device_width: f64, device_height: f64, dpi_x: i32, dpi_y: i32) [2]u32 {
    var fx = @min(1.0, print_max_dpi / @as(f64, @floatFromInt(@max(1, dpi_x))));
    var fy = @min(1.0, print_max_dpi / @as(f64, @floatFromInt(@max(1, dpi_y))));
    const pixels = device_width * fx * device_height * fy;
    if (pixels > print_max_pixels) {
        const k = @sqrt(print_max_pixels / pixels);
        fx *= k;
        fy *= k;
    }
    return .{
        @intFromFloat(@max(1, @round(device_width * fx))),
        @intFromFloat(@max(1, @round(device_height * fy))),
    };
}

/// Printer output path. GDI+ is NOT used on the printer DC: drawing a photo
/// with GDI+ straight onto a printer HDC makes GDI+ resample to the full
/// device resolution in bands (hundreds of MB at 600-1200 DPI), which many
/// drivers - especially on XP - truncate, so only a strip of the photo is
/// printed. Instead the visible part is rendered (with GDI+) into a bounded
/// memory DIB and sent with one plain GDI StretchDIBits to the exact device
/// rectangle computed from the job's own GetDeviceCaps.
fn printPlacement(dc: c.HDC, source: Source, placement: layout.Placement, caps: layout.DeviceCaps, grayscale: bool) bool {
    const device = layout.printerTransform(caps);
    const visible = layout.intersection(placement.image, placement.clip) orelse return false;
    const target = integerRect(device.rect(visible));
    const tw = target.right - target.left;
    const th = target.bottom - target.top;
    if (tw <= 0 or th <= 0) return false;
    var size = rasterSize(@floatFromInt(tw), @floatFromInt(th), caps.dpi_x, caps.dpi_y);
    var attempt: u32 = 0;
    while (attempt < 4) : (attempt += 1) {
        switch (printRaster(dc, source, placement, visible, target, size, grayscale)) {
            .ok => return true,
            .failed => break,
            // Out of memory for the DIB: retry at a lower resolution.
            .no_memory => size = .{ @max(1, size[0] / 2), @max(1, size[1] / 2) },
        }
    }
    // Last resort: the previous direct GDI+ path.
    return drawPlacement(dc, source, placement, device, grayscale);
}

const RasterResult = enum { ok, no_memory, failed };

fn printRaster(dc: c.HDC, source: Source, placement: layout.Placement, visible: layout.Rect, target: c.RECT, size: [2]u32, grayscale: bool) RasterResult {
    const rw: i32 = @intCast(size[0]);
    const rh: i32 = @intCast(size[1]);
    var info = std.mem.zeroes(c.BITMAPINFO);
    info.bmiHeader.biSize = @sizeOf(c.BITMAPINFOHEADER);
    info.bmiHeader.biWidth = rw;
    info.bmiHeader.biHeight = -rh; // top-down
    info.bmiHeader.biPlanes = 1;
    info.bmiHeader.biBitCount = 24;
    info.bmiHeader.biCompression = c.BI_RGB;
    const memory = c.CreateCompatibleDC(null) orelse return .no_memory;
    defer _ = c.DeleteDC(memory);
    var bits: ?*anyopaque = null;
    const bitmap = c.CreateDIBSection(memory, &info, c.DIB_RGB_COLORS, &bits, null, 0);
    if (bitmap == null or bits == null) return .no_memory;
    defer _ = c.DeleteObject(bitmap);
    const old = c.SelectObject(memory, bitmap);
    defer _ = c.SelectObject(memory, old);
    // Millimetres of the visible area -> raster pixels.
    const local = layout.Transform{
        .scale_x = @as(f64, @floatFromInt(rw)) / visible.width,
        .scale_y = @as(f64, @floatFromInt(rh)) / visible.height,
        .origin_x = -visible.x * @as(f64, @floatFromInt(rw)) / visible.width,
        .origin_y = -visible.y * @as(f64, @floatFromInt(rh)) / visible.height,
    };
    if (!drawPlacement(memory, source, .{ .image = placement.image, .clip = visible }, local, grayscale)) return .no_memory;
    _ = c.GdiFlush();
    _ = c.SetStretchBltMode(dc, c.HALFTONE);
    _ = c.SetBrushOrgEx(dc, 0, 0, null);
    const lines = c.StretchDIBits(dc, target.left, target.top, target.right - target.left, target.bottom - target.top,
        0, 0, rw, rh, bits, &info, c.DIB_RGB_COLORS, c.SRCCOPY);
    return if (lines > 0) .ok else .failed;
}

fn integerRect(rect: layout.Rect) c.RECT {
    return .{ .left = @intFromFloat(@round(rect.x)), .top = @intFromFloat(@round(rect.y)),
        .right = @intFromFloat(@round(rect.right())), .bottom = @intFromFloat(@round(rect.bottom())) };
}

fn fill(dc: c.HDC, rect: *const c.RECT, color: c.COLORREF) void {
    const brush = c.CreateSolidBrush(color);
    if (brush == null) return;
    defer _ = c.DeleteObject(brush);
    _ = c.FillRect(dc, rect, brush);
}

fn outline(dc: c.HDC, rect: layout.Rect, color: c.COLORREF, dotted: bool) void {
    const pen = c.CreatePen(if (dotted) c.PS_DOT else c.PS_SOLID, 1, color);
    if (pen == null) return;
    defer _ = c.DeleteObject(pen);
    const old_pen = c.SelectObject(dc, pen);
    const old_brush = c.SelectObject(dc, c.GetStockObject(c.NULL_BRUSH));
    defer {
        _ = c.SelectObject(dc, old_pen);
        _ = c.SelectObject(dc, old_brush);
    }
    _ = c.SetBkMode(dc, c.TRANSPARENT);
    const r = integerRect(rect);
    _ = c.Rectangle(dc, r.left, r.top, r.right, r.bottom);
}

fn paintCanvas(state: *State, dc: c.HDC, client: c.RECT) void {
    fill(dc, &client, ui.shell);
    fill(dc, &.{ .left = sidebar_width, .top = 20, .right = sidebar_width + 1, .bottom = client.bottom - 20 }, ui.line_color);
    ui.text(dc, .{ .left = sidebar_inset, .top = 20, .right = sidebar_width - sidebar_inset, .bottom = 42 },
        L("Ustawienia wydruku"), formFont(), ui.accent, c.DT_SINGLELINE | c.DT_VCENTER);
    ui.text(dc, .{ .left = sidebar_width + 24, .top = 18, .right = client.right - 24, .bottom = 54 },
        L("Podgląd wydruku"), ui.title_font orelse formFont(), ui.accent, c.DT_SINGLELINE | c.DT_VCENTER);
    var canvas = canvasRect(client);
    // Neutral desk-like backdrop, as in common print previews.
    fill(dc, &canvas, theme.colors.desk);
    const transform = previewTransform(state.page, client);
    const sheet = transform.rect(.{ .x = 0, .y = 0, .width = state.page.width, .height = state.page.height });
    paperShadow(dc, sheet);
    var paper = integerRect(sheet);
    fill(dc, &paper, w.rgb(255, 255, 255));
    // Hardware non-printable border: a faint tint, never a dashed frame.
    if (state.dc != null) shadeOutside(dc, sheet, transform.rect(state.page.printable), w.rgb(238, 238, 238));
    var image_ok = true;
    if (state.placement) |placement| image_ok = drawPlacement(dc, state.source, placement, transform, state.grayscale);
    // Margin guide only while the photo is being moved.
    if (state.dragging) {
        if (state.placement) |placement| outline(dc, transform.rect(placement.clip), w.rgb(150, 150, 150), true);
    }
    outline(dc, sheet, w.rgb(150, 150, 150), false);
    ui.rule(dc, canvas.left, client.bottom - 68, canvas.right - canvas.left);
    const legend = c.RECT{ .left = canvas.left, .top = client.bottom - 58, .right = canvas.right, .bottom = client.bottom - 12 };
    const text = if (!image_ok) L("Nie udało się narysować obrazu.") else if (state.settings.scale == .stretch) L("Obraz rozciągnięty na cały obszar druku (bez zachowania proporcji).") else L("Przeciągnij obraz na arkuszu. Linie pomocnicze nie są drukowane.");
    ui.text(dc, legend, text, formFont(), ui.muted, c.DT_WORDBREAK);
}

fn paperShadow(dc: c.HDC, sheet: layout.Rect) void {
    // Three soft layers offset down-right; cheap GDI, fine on XP.
    const shadow = theme.colors.shadow;
    const layers = [_]struct { offset: f64, color: c.COLORREF }{
        .{ .offset = 6, .color = shadow[0] },
        .{ .offset = 4, .color = shadow[1] },
        .{ .offset = 2, .color = shadow[2] },
    };
    for (layers) |layer| {
        var r = integerRect(.{ .x = sheet.x + layer.offset, .y = sheet.y + layer.offset, .width = sheet.width, .height = sheet.height });
        fill(dc, &r, layer.color);
    }
}

fn shadeOutside(dc: c.HDC, outer: layout.Rect, inner: layout.Rect, color: c.COLORREF) void {
    const o = integerRect(outer);
    const i = integerRect(inner);
    const left = @max(o.left, @min(i.left, o.right));
    const right = @min(o.right, @max(i.right, o.left));
    const top = @max(o.top, @min(i.top, o.bottom));
    const bottom = @min(o.bottom, @max(i.bottom, o.top));
    const bands = [_]c.RECT{
        .{ .left = o.left, .top = o.top, .right = o.right, .bottom = top },
        .{ .left = o.left, .top = bottom, .right = o.right, .bottom = o.bottom },
        .{ .left = o.left, .top = top, .right = left, .bottom = bottom },
        .{ .left = right, .top = top, .right = o.right, .bottom = bottom },
    };
    for (bands) |band| {
        if (band.right > band.left and band.bottom > band.top) fill(dc, &band, color);
    }
}

fn canvasRect(client: c.RECT) c.RECT {
    return .{ .left = sidebar_width + 24, .top = 104, .right = client.right - 24, .bottom = client.bottom - 70 };
}

fn previewTransform(page: layout.Page, client: c.RECT) layout.Transform {
    const canvas = canvasRect(client);
    // Leave room for the shadow; the sheet should dominate the canvas.
    const pad = 18;
    const width: f64 = @floatFromInt(@max(1, canvas.right - canvas.left - 2 * pad));
    const height: f64 = @floatFromInt(@max(1, canvas.bottom - canvas.top - 2 * pad));
    const scale = @min(width / page.width, height / page.height);
    return .{
        .scale_x = scale, .scale_y = scale,
        .origin_x = @as(f64, @floatFromInt(canvas.left + pad)) + (width - page.width * scale) / 2,
        .origin_y = @as(f64, @floatFromInt(canvas.top + pad)) + (height - page.height * scale) / 2,
    };
}

fn mousePoint(lp: c.LPARAM) c.POINT {
    const bits: usize = @bitCast(lp);
    return .{ .x = @as(i16, @bitCast(@as(u16, @truncate(bits)))), .y = @as(i16, @bitCast(@as(u16, @truncate(bits >> 16)))) };
}

fn beginDrag(state: *State, point: c.POINT) void {
    // Stretch always covers the whole usable area: nothing to move.
    if (state.settings.scale == .stretch) return;
    const p = state.placement orelse return;
    const visible = layout.intersection(p.image, p.clip) orelse return;
    var client: c.RECT = undefined;
    _ = c.GetClientRect(state.hwnd, &client);
    const transform = previewTransform(state.page, client);
    const hit = transform.rect(visible);
    const x: f64 = @floatFromInt(point.x);
    const y: f64 = @floatFromInt(point.y);
    if (x < hit.x or x >= hit.right() or y < hit.y or y >= hit.bottom()) return;
    state.dragging = true;
    state.drag_start = point;
    state.drag_placement = p;
    state.drag_transform = transform;
    _ = c.SetCapture(state.hwnd);
}

fn moveDrag(state: *State, point: c.POINT) void {
    const p = state.drag_placement orelse return;
    const delta = state.drag_transform.deltaMM(@floatFromInt(point.x - state.drag_start.x), @floatFromInt(point.y - state.drag_start.y));
    const position = layout.dragPosition(p, delta);
    state.settings.position = position;
    state.initializing = true;
    setNumber(state.get(.x), position.x);
    setNumber(state.get(.y), position.y);
    state.initializing = false;
    refresh(state);
}

fn paint(state: *State) void {
    var ps: c.PAINTSTRUCT = undefined;
    const dc = c.BeginPaint(state.hwnd, &ps);
    defer _ = c.EndPaint(state.hwnd, &ps);
    if (dc == null) return;
    var client: c.RECT = undefined;
    _ = c.GetClientRect(state.hwnd, &client);
    if (client.right <= 0 or client.bottom <= 0) return;
    const memory = c.CreateCompatibleDC(dc);
    if (memory == null) {
        paintCanvas(state, dc, client);
        return;
    }
    defer _ = c.DeleteDC(memory);
    const bitmap = c.CreateCompatibleBitmap(dc, client.right, client.bottom);
    if (bitmap == null) {
        paintCanvas(state, dc, client);
        return;
    }
    const old = c.SelectObject(memory, bitmap);
    defer {
        _ = c.SelectObject(memory, old);
        _ = c.DeleteObject(bitmap);
    }
    paintCanvas(state, memory, client);
    _ = c.BitBlt(dc, 0, 0, client.right, client.bottom, memory, 0, 0, c.SRCCOPY);
}

fn pumpJob(state: *State) bool {
    var msg: c.MSG = undefined;
    while (c.PeekMessageW(&msg, null, 0, 0, c.PM_REMOVE) != 0) {
        if (msg.message == c.WM_QUIT) {
            state.cancel_requested = true;
            c.PostQuitMessage(@bitCast(@as(u32, @truncate(msg.wParam))));
            break;
        }
        if (c.IsDialogMessageW(state.hwnd, &msg) == 0) {
            _ = c.TranslateMessage(&msg);
            _ = c.DispatchMessageW(&msg);
        }
    }
    return !state.cancel_requested;
}

fn abortProc(_: c.HDC, _: c.INT) callconv(.Stdcall) c.BOOL {
    const state = active_job orelse return c.FALSE;
    return @intFromBool(pumpJob(state));
}

const JobResult = enum { sent, canceled, failed };

fn spool(state: *State, placement: layout.Placement) JobResult {
    if (!pumpJob(state)) return .canceled;
    var doc = std.mem.zeroes(c.DOCINFOW);
    doc.cbSize = @sizeOf(c.DOCINFOW);
    doc.lpszDocName = L("Kadr — fotografia");
    if (c.StartDocW(state.dc, &doc) <= 0) return if (state.cancel_requested) .canceled else .failed;
    var completed = false;
    defer if (!completed) { _ = c.AbortDoc(state.dc); };
    if (!pumpJob(state)) return .canceled;
    if (c.StartPage(state.dc) <= 0) return if (state.cancel_requested) .canceled else .failed;
    // Drivers may adopt a different form/orientation at StartDoc than the one
    // they reported for the preview DC. Always lay out against the caps of the
    // page actually being printed, so the whole image lands on that sheet.
    const job = jobPlacement(state, placement) orelse return .failed;
    if (!printPlacement(state.dc, state.source, job.placement, job.caps, state.grayscale)) return if (state.cancel_requested) .canceled else .failed;
    if (!pumpJob(state)) return .canceled;
    if (c.EndPage(state.dc) <= 0) return if (state.cancel_requested) .canceled else .failed;
    if (!pumpJob(state)) return .canceled;
    if (c.EndDoc(state.dc) <= 0) return if (state.cancel_requested) .canceled else .failed;
    completed = true;
    return .sent;
}

fn printPage(state: *State) void {
    refresh(state);
    const placement = state.placement orelse return;
    if (!state.input_valid or !state.geometry_valid or !state.printer_ready or state.dc == null or active_job != null) return;
    _ = c.UpdateWindow(state.hwnd);
    const answer = c.MessageBoxW(state.hwnd,
        L("Wydrukować stronę według podglądu?"),
        L("Kadr — potwierdź wydruk"), c.MB_YESNO | c.MB_ICONQUESTION | c.MB_DEFBUTTON2);
    if (answer != c.IDYES) return;
    state.printing = true;
    state.cancel_requested = false;
    active_job = state;
    for ([_]Control{ .paper, .orientation, .scale, .left, .top, .right, .bottom, .center, .setup, .print, .advanced, .color, .value, .x, .y, .media_width, .media_height }) |control| {
        _ = c.EnableWindow(state.get(control), c.FALSE);
    }
    _ = c.SetWindowTextW(state.get(.cancel), L("Przerwij"));
    ui.state(state.get(.cancel), true, null);
    status(state, L("Wysyłanie strony do drukarki…"));
    _ = c.UpdateWindow(state.hwnd);
    _ = c.SetAbortProc(state.dc, abortProc);
    const result = spool(state, placement);
    _ = c.SetAbortProc(state.dc, null);
    active_job = null;
    state.printing = false;
    for ([_]Control{ .paper, .orientation, .scale, .left, .top, .right, .bottom, .center, .setup, .advanced, .color, .value, .x, .y, .media_width, .media_height }) |control| {
        _ = c.EnableWindow(state.get(control), c.TRUE);
    }
    _ = c.SetWindowTextW(state.get(.cancel), L("Wróć"));
    ui.state(state.get(.cancel), false, null);
    refresh(state);
    switch (result) {
        .sent => status(state, L("Strona została przekazana do kolejki drukarki.")),
        .canceled => status(state, L("Anulowano zadanie drukowania.")),
        .failed => notify(state.hwnd, L("Nie udało się przekazać strony do drukarki. Zadanie przerwano. Sprawdź drukarkę i jej kolejkę."), c.MB_ICONERROR),
    }
}

extern "gdiplus" fn GdipCreateBitmapFromScan0(i32, i32, i32, i32, ?[*]u8, *?*w.GpImage) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipBitmapSetPixel(*w.GpImage, i32, i32, u32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipBitmapGetPixel(*w.GpImage, i32, i32, *u32) callconv(.Stdcall) i32;

const TestSurface = struct {
    dc: c.HDC,
    bitmap: c.HBITMAP,
    previous: c.HGDIOBJ,
    pixels: [*]u32,

    fn init(width: i32, height: i32) !TestSurface {
        const dc = c.CreateCompatibleDC(null);
        if (dc == null) return error.CreateDC;
        errdefer _ = c.DeleteDC(dc);
        var info = std.mem.zeroes(c.BITMAPINFO);
        info.bmiHeader.biSize = @sizeOf(c.BITMAPINFOHEADER);
        info.bmiHeader.biWidth = width;
        info.bmiHeader.biHeight = -height;
        info.bmiHeader.biPlanes = 1;
        info.bmiHeader.biBitCount = 32;
        info.bmiHeader.biCompression = c.BI_RGB;
        var bits: ?*anyopaque = null;
        const bitmap = c.CreateDIBSection(dc, &info, c.DIB_RGB_COLORS, &bits, null, 0);
        if (bitmap == null or bits == null) return error.CreateDIB;
        return .{ .dc = dc, .bitmap = bitmap, .previous = c.SelectObject(dc, bitmap), .pixels = @ptrCast(@alignCast(bits.?)) };
    }

    fn deinit(self: *TestSurface) void {
        _ = c.SelectObject(self.dc, self.previous);
        _ = c.DeleteObject(self.bitmap);
        _ = c.DeleteDC(self.dc);
    }
};

test "strict numeric scale, physical and position fields accept comma/dot but reject incomplete input" {
    try std.testing.expectEqual(@as(?f64, 75.5), parseNumber(L(" 75,5 "), 0.1, 1000));
    try std.testing.expectEqual(@as(?f64, 0.25), parseNumber(L("0.25"), 0.1, 1000));
    try std.testing.expectEqual(@as(?f64, -12.5), parseNumber(L("-12,5"), -10000, 10000));
    for ([_][]const u16{ L(""), L(" "), L("."), L("1,"), L("1,2.3"), L("nan"), L("inf"), L("1e2"), L("-1"), L("0"), L("1000.1") }) |bad| {
        try std.testing.expect(parseNumber(bad, 0.1, 1000) == null);
    }
    try std.testing.expect(parseNumber(L("3276,7"), layout.min_media_mm, layout.max_media_mm) != null);
    try std.testing.expect(parseNumber(L("3276,8"), layout.min_media_mm, layout.max_media_mm) == null);
}

test "all DEVMODE media/orientations use exact standard codes or safe tenths-mm custom sizes" {
    for (papers) |paper| {
        for (std.enums.values(layout.Orientation)) |orientation| {
            var mode = std.mem.zeroes(c.DEVMODEW);
            mode.dmFields = c.DM_FORMNAME | c.DM_PAPERWIDTH | c.DM_PAPERLENGTH;
            const page = layout.paperPage(paper, orientation);
            configureMode(&mode, paper, page, orientation, true);
            try std.testing.expect(mode.dmFields & c.DM_FORMNAME == 0);
            try std.testing.expect(mode.dmFields & (c.DM_ORIENTATION | c.DM_COLOR | c.DM_SCALE | c.DM_PAPERSIZE) == (c.DM_ORIENTATION | c.DM_COLOR | c.DM_SCALE | c.DM_PAPERSIZE));
            try std.testing.expectEqual(@as(c.SHORT, c.DMCOLOR_MONOCHROME), mode.dmColor);
            try std.testing.expectEqual(@as(c.SHORT, 100), mode.unnamed_0.unnamed_0.dmScale);
            try std.testing.expectEqual(paperCode(paper), mode.unnamed_0.unnamed_0.dmPaperSize);
            if (paperCode(paper) == c.DMPAPER_USER) {
                const nominal = layout.paperPage(paper, .portrait);
                try std.testing.expectApproxEqAbs(nominal.width, @as(f64, @floatFromInt(mode.unnamed_0.unnamed_0.dmPaperWidth)) / 10, 0.051);
                try std.testing.expectApproxEqAbs(nominal.height, @as(f64, @floatFromInt(mode.unnamed_0.unnamed_0.dmPaperLength)) / 10, 0.051);
            }
        }
    }
    var mode = std.mem.zeroes(c.DEVMODEW);
    configureMode(&mode, null, layout.customPage(10, 3276.7, .landscape).?, .landscape, false);
    try std.testing.expectEqual(@as(c.SHORT, c.DMPAPER_USER), mode.unnamed_0.unnamed_0.dmPaperSize);
    try std.testing.expectEqual(@as(c.SHORT, 100), mode.unnamed_0.unnamed_0.dmPaperWidth);
    try std.testing.expectEqual(@as(c.SHORT, 32767), mode.unnamed_0.unnamed_0.dmPaperLength);
    try std.testing.expectEqual(@as(c.SHORT, c.DMCOLOR_COLOR), mode.dmColor);
}

test "shared grayscale preview/print renderer produces equal RGB over white without editing source" {
    var token: usize = 0;
    try std.testing.expectEqual(@as(i32, 0), w.GdiplusStartup(&token, &w.StartupInput{}, null));
    defer w.GdiplusShutdown(token);
    var bitmap: ?*w.GpImage = null;
    try std.testing.expectEqual(@as(i32, 0), GdipCreateBitmapFromScan0(64, 16, 0, 0x26200a, null, &bitmap));
    defer _ = w.GdipDisposeImage(bitmap.?);
    const colors = [_]u32{ 0xffff0000, 0xff00ff00, 0xff0000ff, 0x80ff0000 };
    for (0..16) |y| {
        for (0..64) |x| try std.testing.expectEqual(@as(i32, 0), GdipBitmapSetPixel(bitmap.?, @intCast(x), @intCast(y), colors[x / 16]));
    }
    const source = Source{ .image = bitmap.?, .width = 64, .height = 16 };
    var preview = try TestSurface.init(128, 32);
    defer preview.deinit();
    var printed = try TestSurface.init(128, 32);
    defer printed.deinit();
    const p = layout.Placement{ .image = .{ .x = 0, .y = 0, .width = 128, .height = 32 }, .clip = .{ .x = 0, .y = 0, .width = 128, .height = 32 } };
    const transform = layout.Transform{ .scale_x = 1, .scale_y = 1 };
    try std.testing.expect(drawPlacement(preview.dc, source, p, transform, true));
    try std.testing.expect(drawPlacement(printed.dc, source, p, transform, true));
    _ = c.GdiFlush();
    try std.testing.expectEqualSlices(u32, preview.pixels[0 .. 128 * 32], printed.pixels[0 .. 128 * 32]);
    const expected_gray = [_]f64{ 76, 149, 29, 165 };
    for ([_]usize{ 16, 48, 80, 112 }, 0..) |x, i| {
        const color = preview.pixels[16 * 128 + x];
        try std.testing.expectEqual(color & 255, (color >> 8) & 255);
        try std.testing.expectEqual(color & 255, (color >> 16) & 255);
        try std.testing.expectApproxEqAbs(expected_gray[i], @as(f64, @floatFromInt(color & 255)), 1.1);
    }
    // Alpha is retained by the matrix, then composited over white.
    try std.testing.expect((preview.pixels[16 * 128 + 112] & 255) > (preview.pixels[16 * 128 + 16] & 255));
    for (colors, 0..) |color, i| {
        var unchanged: u32 = 0;
        try std.testing.expectEqual(@as(i32, 0), GdipBitmapGetPixel(bitmap.?, @intCast(i * 16 + 8), 8, &unchanged));
        try std.testing.expectEqual(color, unchanged);
    }
    try std.testing.expect(drawPlacement(printed.dc, source, p, transform, false));
    _ = c.GdiFlush();
    const red = printed.pixels[16 * 128 + 16];
    try std.testing.expect(((red >> 16) & 255) > (red & 255) + 100);
}

test "native Advanced, percent, invalid edits, drag and Center share one placement without any job" {
    const instance = c.GetModuleHandleW(null);
    const test_class = L("Kadr.PrintPreview.OptionsTest");
    var wc = std.mem.zeroes(c.WNDCLASSW);
    wc.lpfnWndProc = windowProc;
    wc.hInstance = instance;
    wc.lpszClassName = test_class;
    try std.testing.expect(c.RegisterClassW(&wc) != 0);
    defer _ = c.UnregisterClassW(test_class, instance);
    var state = State{ .source = .{ .image = undefined, .width = 960, .height = 480 } };
    const hwnd = c.CreateWindowExW(0, test_class, L("Podgląd"), c.WS_OVERLAPPEDWINDOW, 0, 0, 1020, 730, null, null, instance, &state);
    try std.testing.expect(hwnd != null);
    defer if (state.hwnd != null) { _ = c.DestroyWindow(hwnd); };
    var memory = try TestSurface.init(32, 32);
    defer memory.deinit();
    state.dc = memory.dc; // A memory DC, never a printer or a spooler job.
    state.printer_ready = true;
    refresh(&state);
    try std.testing.expect(c.IsWindowEnabled(state.get(.print)) != 0);
    try std.testing.expect(!state.advanced);
    try std.testing.expect(c.GetWindowLongW(state.get(.x), c.GWL_STYLE) & c.WS_VISIBLE == 0);
    _ = c.SendMessageW(hwnd, c.WM_COMMAND, controlId(.advanced), 0);
    try std.testing.expect(state.advanced);
    try std.testing.expect(c.GetWindowLongW(state.get(.x), c.GWL_STYLE) & c.WS_VISIBLE != 0);
    _ = c.SendMessageW(state.get(.scale), c.CB_SETCURSEL, @intFromEnum(layout.Scale.percent), 0);
    _ = c.SendMessageW(hwnd, c.WM_COMMAND, controlId(.scale) | (@as(usize, c.CBN_SELCHANGE) << 16), 0);
    _ = c.SetWindowTextW(state.get(.value), L("25,5"));
    try std.testing.expect(state.input_valid and state.geometry_valid);
    try std.testing.expectApproxEqAbs(@as(f64, 64.77), state.placement.?.image.width, 0.00001);
    const previous = state.placement.?;
    _ = c.SetWindowTextW(state.get(.value), L(""));
    try std.testing.expect(!state.input_valid);
    try std.testing.expectEqual(previous, state.placement.?);
    try std.testing.expect(c.IsWindowEnabled(state.get(.print)) == 0);
    _ = c.SetWindowTextW(state.get(.value), L("25.5"));
    var client: c.RECT = undefined;
    _ = c.GetClientRect(hwnd, &client);
    const transform = previewTransform(state.page, client);
    const image = transform.rect(state.placement.?.image);
    const point = c.POINT{ .x = @intFromFloat(image.x + image.width / 2), .y = @intFromFloat(image.y + image.height / 2) };
    beginDrag(&state, point);
    try std.testing.expect(state.dragging);
    moveDrag(&state, .{ .x = point.x + 25, .y = point.y + 15 });
    state.dragging = false;
    _ = c.ReleaseCapture();
    const delta = transform.deltaMM(25, 15);
    // Numeric position is displayed to 0.001 mm and is also used by printing.
    try std.testing.expectApproxEqAbs(previous.image.x + delta.x, state.placement.?.image.x, 0.00051);
    try std.testing.expectApproxEqAbs(previous.image.y + delta.y, state.placement.?.image.y, 0.00051);
    _ = c.SetWindowTextW(state.get(.x), L("10000"));
    try std.testing.expect(!state.geometry_valid);
    try std.testing.expect(c.IsWindowEnabled(state.get(.print)) == 0);
    _ = c.SendMessageW(hwnd, c.WM_COMMAND, controlId(.center), 0);
    try std.testing.expect(state.geometry_valid and state.settings.position == null);
    try std.testing.expectApproxEqAbs(previous.image.x, state.placement.?.image.x, 0.00001);
    try std.testing.expect(c.IsWindowEnabled(state.get(.print)) != 0);
    state.dc = null;
    _ = c.SendMessageW(state.get(.color), c.CB_SETCURSEL, 1, 0);
    _ = c.SendMessageW(hwnd, c.WM_COMMAND, controlId(.color) | (@as(usize, c.CBN_SELCHANGE) << 16), 0);
    try std.testing.expect(state.grayscale);
    try std.testing.expect(active_job == null and state.dc == null);
    _ = c.SendMessageW(state.get(.paper), c.CB_SETCURSEL, papers.len, 0);
    _ = c.SendMessageW(hwnd, c.WM_COMMAND, controlId(.paper) | (@as(usize, c.CBN_SELCHANGE) << 16), 0);
    _ = c.SetWindowTextW(state.get(.media_width), L("123,4"));
    _ = c.SetWindowTextW(state.get(.media_height), L("234.5"));
    try std.testing.expect(state.automatic_orientation);
    try std.testing.expectEqual(layout.Orientation.landscape, state.orientation);
    try std.testing.expectApproxEqAbs(@as(f64, 234.5), state.page.width, 0.00001);
    try std.testing.expectApproxEqAbs(@as(f64, 123.4), state.page.height, 0.00001);
    _ = c.SetWindowTextW(state.get(.media_width), L(""));
    try std.testing.expect(!state.input_valid);
    _ = c.SetWindowTextW(state.get(.media_width), L("123,4"));
    _ = c.SendMessageW(state.get(.orientation), c.CB_SETCURSEL, 1, 0);
    _ = c.SendMessageW(hwnd, c.WM_COMMAND, controlId(.orientation) | (@as(usize, c.CBN_SELCHANGE) << 16), 0);
    try std.testing.expectApproxEqAbs(@as(f64, 234.5), state.page.width, 0.00001);
    try std.testing.expectApproxEqAbs(@as(f64, 123.4), state.page.height, 0.00001);
    try std.testing.expect(!state.automatic_orientation);
    _ = c.SendMessageW(state.get(.paper), c.CB_SETCURSEL, 0, 0);
    _ = c.SendMessageW(hwnd, c.WM_COMMAND, controlId(.paper) | (@as(usize, c.CBN_SELCHANGE) << 16), 0);
    try std.testing.expectEqual(layout.Orientation.landscape, state.orientation);
    try std.testing.expectApproxEqAbs(@as(f64, 297), state.page.width, 0.00001);
    _ = c.SendMessageW(state.get(.orientation), c.CB_SETCURSEL, 0, 0);
    _ = c.SendMessageW(hwnd, c.WM_COMMAND, controlId(.orientation) | (@as(usize, c.CBN_SELCHANGE) << 16), 0);
    _ = c.SendMessageW(state.get(.paper), c.CB_SETCURSEL, 1, 0);
    _ = c.SendMessageW(hwnd, c.WM_COMMAND, controlId(.paper) | (@as(usize, c.CBN_SELCHANGE) << 16), 0);
    try std.testing.expect(!state.automatic_orientation);
    try std.testing.expectEqual(layout.Orientation.portrait, state.orientation);
    try std.testing.expectApproxEqAbs(@as(f64, 148), state.page.width, 0.00001);
    // Simulate accepted caps for a driver which substituted 4x6in for 10x15cm.
    const caps = layout.DeviceCaps{ .dpi_x = 254, .dpi_y = 508, .physical_width = 1016, .physical_height = 3048, .offset_x = 20, .offset_y = 60, .printable_width = 960, .printable_height = 2928 };
    state.page = layout.pageFromDevice(caps).?;
    syncPageControls(&state);
    try std.testing.expectEqual(@as(usize, 14), state.paper_index);
    try std.testing.expect(!samePage(layout.paperPage(.photo_10x15, .portrait), state.page));
    _ = c.SendMessageW(state.get(.scale), c.CB_SETCURSEL, 0, 0);
    refresh(&state);
    // Default margins are 0: Fit uses the whole 96 mm printable width.
    try std.testing.expectApproxEqAbs(@as(f64, 96), state.placement.?.image.width, 0.00001);
}

test "scale names round-trip for the saved setting" {
    for (std.enums.values(layout.Scale)) |scale| try std.testing.expectEqual(@as(?layout.Scale, scale), scaleFromName(scale_names[@intFromEnum(scale)]));
    try std.testing.expect(scaleFromName("bogus") == null);
    try std.testing.expect(scaleFromName("") == null);
}

test "raster size is bounded by 300 DPI and a pixel budget, never upscaled" {
    try std.testing.expectEqual([2]u32{ 2480, 3508 }, rasterSize(4960, 7016, 600, 600));
    try std.testing.expectEqual([2]u32{ 1000, 500 }, rasterSize(1000, 500, 150, 150));
    const big = rasterSize(20000, 20000, 300, 300);
    try std.testing.expect(@as(f64, @floatFromInt(big[0])) * @as(f64, @floatFromInt(big[1])) <= print_max_pixels * 1.001);
}

fn countInk(surface: *const TestSurface, width: i32, x0: i32, y0: i32, x1: i32, y1: i32) usize {
    var n: usize = 0;
    var y = y0;
    while (y < y1) : (y += 1) {
        var x = x0;
        while (x < x1) : (x += 1) {
            if (surface.pixels[@intCast(y * width + x)] & 0xffffff != 0xffffff) n += 1;
        }
    }
    return n;
}

test "printed page: whole image fits the printable area of a simulated A4 printer (portrait and landscape)" {
    var token: usize = 0;
    try std.testing.expectEqual(@as(i32, 0), w.GdiplusStartup(&token, &w.StartupInput{}, null));
    defer w.GdiplusShutdown(token);
    // A 1600x1000 photo, solid red with a blue 1px frame on every edge, so a
    // cropped print would be detectable as a missing frame edge.
    var bitmap: ?*w.GpImage = null;
    try std.testing.expectEqual(@as(i32, 0), GdipCreateBitmapFromScan0(160, 100, 0, 0x26200a, null, &bitmap));
    defer _ = w.GdipDisposeImage(bitmap.?);
    for (0..100) |y| for (0..160) |x| {
        const edge = x == 0 or y == 0 or x == 159 or y == 99;
        _ = GdipBitmapSetPixel(bitmap.?, @intCast(x), @intCast(y), if (edge) 0xff0000ff else 0xffff0000);
    };
    const source = Source{ .image = bitmap.?, .width = 160, .height = 100 };
    // 50 DPI "printer", A4, 4 mm unprintable border (8 px) on every side.
    for ([_]bool{ false, true }) |landscape| {
        const pw: i32 = if (landscape) 585 else 413;
        const ph: i32 = if (landscape) 413 else 585;
        const caps = layout.DeviceCaps{ .dpi_x = 50, .dpi_y = 50, .physical_width = pw, .physical_height = ph, .offset_x = 8, .offset_y = 8, .printable_width = pw - 16, .printable_height = ph - 16 };
        var printer = try TestSurface.init(caps.printable_width, caps.printable_height);
        defer printer.deinit();
        fill(printer.dc, &.{ .left = 0, .top = 0, .right = caps.printable_width, .bottom = caps.printable_height }, w.rgb(255, 255, 255));
        const page = layout.pageFromDevice(caps).?;
        const p = layout.place(page, .{ .width = 160, .height = 100 }, .{ .margins = .{ .left = 0, .top = 0, .right = 0, .bottom = 0 } }).?;
        try std.testing.expect(printPlacement(printer.dc, source, p, caps, false));
        _ = c.GdiFlush();
        const r = integerRect(layout.printerTransform(caps).rect(p.image));
        // Image lies fully inside the printable area and touches two opposite edges.
        try std.testing.expect(r.left >= 0 and r.top >= 0 and r.right <= caps.printable_width and r.bottom <= caps.printable_height);
        if (landscape) {
            try std.testing.expect(r.top == 0 or r.left == 0);
        } else try std.testing.expectEqual(@as(i32, 0), r.left);
        const used = @as(f64, @floatFromInt((r.right - r.left) * (r.bottom - r.top))) / @as(f64, @floatFromInt(caps.printable_width * caps.printable_height));
        try std.testing.expect(used > (if (landscape) @as(f64, 0.85) else 0.4));
        // All four frame edges are present (nothing cut off) ...
        const W = caps.printable_width;
        try std.testing.expect(countInk(&printer, W, r.left, r.top, r.right, r.top + 2) > @as(usize, @intCast(r.right - r.left)) / 2);
        try std.testing.expect(countInk(&printer, W, r.left, r.bottom - 2, r.right, r.bottom) > @as(usize, @intCast(r.right - r.left)) / 2);
        try std.testing.expect(countInk(&printer, W, r.left, r.top, r.left + 2, r.bottom) > @as(usize, @intCast(r.bottom - r.top)) / 2);
        try std.testing.expect(countInk(&printer, W, r.right - 2, r.top, r.right, r.bottom) > @as(usize, @intCast(r.bottom - r.top)) / 2);
        // ... the centre is red, and nothing is printed outside the image rect.
        const centre = printer.pixels[@intCast(@divTrunc(r.top + r.bottom, 2) * W + @divTrunc(r.left + r.right, 2))];
        try std.testing.expect((centre >> 16) & 255 > 200 and centre & 255 < 60);
        try std.testing.expectEqual(@as(usize, 0), countInk(&printer, W, 0, 0, W, @max(0, r.top - 1)));
        try std.testing.expectEqual(@as(usize, 0), countInk(&printer, W, 0, @min(caps.printable_height, r.bottom + 1), W, caps.printable_height));
    }
}

test "driver mono acceptance changes preview while gray remains guaranteed on a color driver" {
    var mode = std.mem.zeroes(c.DEVMODEW);
    mode.dmFields = c.DM_COLOR;
    mode.dmColor = c.DMCOLOR_MONOCHROME;
    try std.testing.expect(acceptedGrayscale(false, &mode));
    mode.dmColor = c.DMCOLOR_COLOR;
    try std.testing.expect(!acceptedGrayscale(false, &mode));
    try std.testing.expect(acceptedGrayscale(true, &mode));
}

test "entry point and its entire window/printing path compile without opening UI" {
    const entry: *const fn (c.HWND, Source) void = &show;
    std.mem.doNotOptimizeAway(entry);
}

test "Polish numeric margins, blanks and invalid input" {
    try std.testing.expectEqual(@as(?f64, 0), parseMargin(L("")[0..0]));
    try std.testing.expectEqual(@as(?f64, 0), parseMargin(L(" \t")));
    try std.testing.expectEqual(@as(?f64, 12.5), parseMargin(L(" 12,5 ")));
    try std.testing.expectEqual(@as(?f64, 0.25), parseMargin(L("0.25")));
    try std.testing.expect(parseMargin(L("-1")) == null);
    try std.testing.expect(parseMargin(L("nan")) == null);
    try std.testing.expect(parseMargin(L("1e2")) == null);
    try std.testing.expect(parseMargin(L("1,2.3")) == null);
    try std.testing.expect(parseMargin(L("10001")) == null);
}

test "preview controls have a safe uninitialized theme fallback and owned brush lifetime" {
    try std.testing.expect(ui.font == null);
    const instance = c.GetModuleHandleW(null);
    const test_class = L("Kadr.PrintPreview.ControlsTest");
    var wc = std.mem.zeroes(c.WNDCLASSW);
    wc.lpfnWndProc = windowProc;
    wc.hInstance = instance;
    wc.lpszClassName = test_class;
    try std.testing.expect(c.RegisterClassW(&wc) != 0);
    defer _ = c.UnregisterClassW(test_class, instance);
    // No window is shown and no image or printer is accessed.
    var state = State{ .source = undefined };
    const hwnd = c.CreateWindowExW(0, test_class, L("Podgląd"), c.WS_OVERLAPPEDWINDOW,
        0, 0, 760, 580, null, null, instance, &state);
    try std.testing.expect(hwnd != null);
    defer if (state.hwnd != null) { _ = c.DestroyWindow(hwnd); };
    try std.testing.expect(state.background_brush != null);
    for ([_]Control{ .paper, .orientation, .scale, .left, .top, .right, .bottom, .center, .setup, .print, .cancel, .status }) |control| {
        try std.testing.expect(state.get(control) != null);
        try std.testing.expectEqual(@intFromPtr(formFont()), @as(usize, @bitCast(c.SendMessageW(state.get(control), c.WM_GETFONT, 0, 0))));
    }
    const dc = c.GetDC(hwnd);
    try std.testing.expect(dc != null);
    {
        defer _ = c.ReleaseDC(hwnd, dc);
        const brush = c.SendMessageW(hwnd, c.WM_CTLCOLORSTATIC, @intFromPtr(dc), @bitCast(@intFromPtr(state.get(.status))));
        try std.testing.expectEqual(@intFromPtr(state.background_brush), @as(usize, @bitCast(brush)));
        try std.testing.expectEqual(ui.shell, c.GetBkColor(dc));
        try std.testing.expectEqual(ui.accent, c.GetTextColor(dc));
    }
    try std.testing.expect(c.DestroyWindow(hwnd) != 0);
    try std.testing.expect(state.hwnd == null);
    try std.testing.expect(state.background_brush == null);
}

test "preview non-client creation preserves the native window caption" {
    const CaptionWindow = struct {
        fn proc(hwnd: c.HWND, message: c.UINT, wp: c.WPARAM, lp: c.LPARAM) callconv(.Stdcall) c.LRESULT {
            // Exercise the real non-client handlers without creating controls,
            // loading an image, opening printer dialogs, or showing a window.
            if (message == c.WM_NCCREATE or message == c.WM_NCDESTROY)
                return windowProc(hwnd, message, wp, lp);
            return c.DefWindowProcW(hwnd, message, wp, lp);
        }
    };
    const instance = c.GetModuleHandleW(null);
    const test_class = L("Kadr.PrintPreview.CaptionTest");
    const caption = L("Kadr — podgląd wydruku");
    var wc = std.mem.zeroes(c.WNDCLASSW);
    wc.lpfnWndProc = CaptionWindow.proc;
    wc.hInstance = instance;
    wc.lpszClassName = test_class;
    try std.testing.expect(c.RegisterClassW(&wc) != 0);
    defer _ = c.UnregisterClassW(test_class, instance);
    var state = State{ .source = undefined }; // Not used by the non-client handlers.
    const hwnd = c.CreateWindowExW(0, test_class, caption, c.WS_OVERLAPPEDWINDOW,
        0, 0, 320, 240, null, null, instance, &state);
    try std.testing.expect(hwnd != null);
    defer _ = c.DestroyWindow(hwnd);
    var buffer: [128]u16 = undefined;
    const length = c.GetWindowTextW(hwnd, &buffer, buffer.len);
    try std.testing.expect(length >= 0);
    try std.testing.expectEqualSlices(u16, caption, buffer[0..@intCast(length)]);
}

test "stretch prints ink on the whole printable area (no white bars) and cannot be dragged" {
    var token: usize = 0;
    try std.testing.expectEqual(@as(i32, 0), w.GdiplusStartup(&token, &w.StartupInput{}, null));
    defer w.GdiplusShutdown(token);
    var bitmap: ?*w.GpImage = null;
    try std.testing.expectEqual(@as(i32, 0), GdipCreateBitmapFromScan0(160, 90, 0, 0x26200a, null, &bitmap)); // 16:9
    defer _ = w.GdipDisposeImage(bitmap.?);
    for (0..90) |y| for (0..160) |x| {
        _ = GdipBitmapSetPixel(bitmap.?, @intCast(x), @intCast(y), 0xff2040c0);
    };
    const source = Source{ .image = bitmap.?, .width = 160, .height = 90 };
    // A4 landscape and portrait, plus an odd 4x6in sheet, 50 DPI, uneven offsets.
    const sheets = [_][2]i32{ .{ 585, 413 }, .{ 413, 585 }, .{ 200, 300 } };
    for (sheets) |sheet| {
        const caps = layout.DeviceCaps{ .dpi_x = 50, .dpi_y = 50, .physical_width = sheet[0], .physical_height = sheet[1], .offset_x = 7, .offset_y = 11, .printable_width = sheet[0] - 14, .printable_height = sheet[1] - 25 };
        var printer = try TestSurface.init(caps.printable_width, caps.printable_height);
        defer printer.deinit();
        fill(printer.dc, &.{ .left = 0, .top = 0, .right = caps.printable_width, .bottom = caps.printable_height }, w.rgb(255, 255, 255));
        const page = layout.pageFromDevice(caps).?;
        const p = layout.place(page, .{ .width = 160, .height = 90 }, .{ .scale = .stretch, .margins = .{ .left = 0, .top = 0, .right = 0, .bottom = 0 } }).?;
        const r = integerRect(layout.printerTransform(caps).rect(p.image));
        try std.testing.expectEqual(c.RECT{ .left = 0, .top = 0, .right = caps.printable_width, .bottom = caps.printable_height }, r);
        try std.testing.expect(printPlacement(printer.dc, source, p, caps, false));
        _ = c.GdiFlush();
        const W = caps.printable_width;
        const total: usize = @intCast(W * caps.printable_height);
        try std.testing.expectEqual(total, countInk(&printer, W, 0, 0, W, caps.printable_height));
    }
    var state = State{ .source = source };
    state.settings.scale = .stretch;
    state.placement = layout.place(layout.paperPage(.a4, .landscape), .{ .width = 160, .height = 90 }, state.settings);
    beginDrag(&state, .{ .x = 500, .y = 300 });
    try std.testing.expect(!state.dragging);
}
