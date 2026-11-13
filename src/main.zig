// Kadr — native picture viewer. SPDX-License-Identifier: GPL-3.0-or-later
const std = @import("std");
const w = @import("win.zig");
const c = w.c;
const Image = @import("image.zig").Image;
const printing = @import("printing.zig");
const ui = @import("ui.zig");
const formats = @import("formats.zig");
const loader = @import("loader.zig");
const render = @import("render.zig");
const Renderer = render.Renderer;
const zoomMath = @import("zoom.zig");
const Surface = @import("surface.zig").Surface;
const output = @import("output.zig");
const file_dialog = @import("file_dialog.zig");
const export_dialog = @import("export_dialog.zig");
const editor = @import("editor.zig");
const file_tools = @import("file_tools.zig");
const toolbar = @import("toolbar.zig");
const navigation = @import("navigation.zig");
const i18n = @import("i18n.zig");
const theme = @import("theme.zig");
const L = i18n.L;
/// "Check for updates" only opens this page in the default browser.
const releases_url = "https://github.com/snakex21/kadr/releases";
const ID = struct {
    const open = 100;
    const previous = 101;
    const next = 102;
    const fit = 103;
    const actual = 104;
    const minus = 105;
    const plus = 106;
    const rotate = 107;
    const pause = 108;
    const print = 109;
    const fullscreen = 110;
    const help = 111;
    const page_prev = 112;
    const page_next = 113;
    const slide = 114;
    const open_empty = 115;
    const zoom_apply = 116;
    const save_as = 117;
    const save_rotation = 118;
    const copy = 119;
    const rename = 120;
    const remove = 121;
    const folder = 122;
    const menu = 123;
    const remove_permanent = 124;
    const language = 125;
    const export_copy = 126;
    const copy_path = 127;
    const wallpaper = 128;
    const edit = 129;
    const rotate_left = 130;
    const theme_light = 131;
    const theme_dark = 132;
    const theme_auto = 133;
    const updates = 134;
};
const timer_gif = 1;
const timer_slide = 2;
const timer_view = 3;
const timer_settle = 4;
const timer_folder = 5;
const toolbar_height = toolbar.height;
const status_height = toolbar.status_height;
var window: c.HWND = null;
var image = Image{};
var preview = Image{};
var rotations: u2 = 0;
var edited = false;
// A detached fallback raster must not make a failed document recovery eligible
// for flat in-place export. Recompute this only when a source loads successfully.
var source_is_static = false;
var file_path: [32768]u16 = [_]u16{0} ** 32768;
var files: [8192]?[*:0]u16 = [_]?[*:0]u16{null} ** 8192;
var file_count: usize = 0;
var file_index: usize = 0;
var navigation_index: usize = 0;
var navigation_direction: i32 = 0;
/// Held arrow-key browsing (autorepeat coalescing); see navigation.zig.
var held = navigation.Held{};
var unreadable: [8192]bool = [_]bool{false} ** 8192;
var folder_scanning = false;
var folder_search: c.HANDLE = null;
var folder_data: c.WIN32_FIND_DATAW = undefined;
var folder_pattern: [32768]u16 = undefined;
var folder_prefix: usize = 0;
var live_resize = false;
var fit_mode = true;
var zoom: f32 = 1;
var pan_x: f32 = 0;
var pan_y: f32 = 0;
var dragging = false;
var drag_x: i32 = 0;
var drag_y: i32 = 0;
var paused = false;
var slideshow = false;
var modal_depth: u32 = 0;
var fullscreen = false;
var restore_rect: c.RECT = std.mem.zeroes(c.RECT);
var restore_placement: c.WINDOWPLACEMENT = std.mem.zeroes(c.WINDOWPLACEMENT);
var restore_style: c.LONG = 0;
var controls: [19]c.HWND = [_]c.HWND{null} ** 19;
var status: c.HWND = null;
var file_counter: c.HWND = null;
var zoom_label: c.HWND = null;
var zoom_name: c.HWND = null;
var zoom_frame: c.RECT = std.mem.zeroes(c.RECT);
var zoom_editing = false;
var zoom_dirty = false;
var zoom_setting = false;
var zoom_invalid = false;
var page_label: c.HWND = null;
var app_icon: c.HICON = null;
var renderer = Renderer{};
var back_buffer = Surface{};
var loading = false;
var pending_scan = false;
var page_request = false;
var pending_page: u32 = 0;
var closing = false;
var interactive = false;
var frame_pending = false;
var zoom_animating = false;
var zoom_goal: f32 = 1;
var zoom_anchor_x: f32 = 0;
var zoom_anchor_y: f32 = 0;
var label_tick: u32 = 0;
var last_fit_zoom: f32 = 1;
// Opt-in developer timing: --profile-open <file>, written to inherited stdout.
var profile_started: i64 = 0;
var profile_ready: i64 = 0;
var profile_frequency: i64 = 1;
// Opt-in developer timing: --profile-view <file>; one line per paint.
var profile_view = false;
var profile_input: i64 = 0;
fn profileInput() void {
    if (profile_view and profile_input == 0) profile_input = counter();
}
fn counter() i64 {
    var value: c.LARGE_INTEGER = undefined;
    _ = c.QueryPerformanceCounter(&value);
    return value.QuadPart;
}
fn profilePaint(paint_started: i64) void {
    if (profile_started == 0 or profile_ready == 0 or image.handle == null) return;
    _ = c.GdiFlush();
    const finished = counter();
    const factor = 1000 / @as(f64, @floatFromInt(profile_frequency));
    var buffer: [384]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, "KADR_FIRST_PAINT ready_ms={d:.3} ready_to_paint_ms={d:.3} paint_ms={d:.3} total_ms={d:.3} pixels={d}x{d}\n", .{ @as(f64, @floatFromInt(profile_ready - profile_started)) * factor, @as(f64, @floatFromInt(finished - profile_ready)) * factor, @as(f64, @floatFromInt(finished - paint_started)) * factor, @as(f64, @floatFromInt(finished - profile_started)) * factor, image.width, image.height }) catch "";
    profile_started = 0;
    var written: c.DWORD = 0;
    _ = c.WriteFile(c.GetStdHandle(c.STD_OUTPUT_HANDLE), text.ptr, @intCast(text.len), &written, null);
}

fn invalidate() void {
    _ = c.InvalidateRect(window, null, c.FALSE);
}
fn invalidateCanvas() void {
    var rect = canvasRect();
    _ = c.InvalidateRect(window, &rect, c.FALSE);
}
fn requestViewFrame() void {
    if (!frame_pending) {
        frame_pending = true;
        _ = c.SetTimer(window, timer_view, 10, null);
    }
}
fn gesture() void {
    interactive = true;
    requestViewFrame();
    _ = c.SetTimer(window, timer_settle, 240, null);
}
fn stopZoom() void {
    zoom_animating = false;
    frame_pending = false;
    _ = c.KillTimer(window, timer_view);
    interactive = false;
    _ = c.KillTimer(window, timer_settle);
}
fn zoomCaption(force: bool) void {
    if (zoom_label == null or (!force and (zoom_editing or zoom_dirty))) return;
    var text: [64]u8 = undefined;
    var wide: [80]u16 = undefined;
    zoom_setting = true;
    defer zoom_setting = false;
    _ = c.SetWindowTextW(zoom_label, w.utf16(&wide, zoomMath.caption(&text, actualZoom())));
}
fn zoomFrameChanged() void {
    _ = c.InvalidateRect(window, &zoom_frame, c.FALSE);
    _ = c.InvalidateRect(zoom_label, null, c.FALSE);
}
fn cancelZoomEdit() void {
    zoom_dirty = false;
    zoom_invalid = false;
    zoom_editing = false;
    zoomCaption(true);
    zoomFrameChanged();
    updateViewInfo();
}
fn badZoom(range: bool) bool {
    zoom_invalid = true;
    zoomFrameChanged();
    if (range) {
        const bounds = zoomMath.limits(image.width, image.height, fitZoom(), render.max_geometry);
        var low: [64]u8 = undefined;
        var high: [64]u8 = undefined;
        var text: [256]u8 = undefined;
        var wide: [300]u16 = undefined;
        const info = std.fmt.bufPrint(&text, "{s} {s} – {s}.", .{ i18n.utf8("Sprawdź wpisane wartości."), zoomMath.caption(&low, bounds.minimum), zoomMath.caption(&high, bounds.maximum) }) catch "";
        _ = c.SetWindowTextW(status, w.utf16(&wide, info));
    } else _ = c.SetWindowTextW(status, L("Wpisz dodatni zoom, np. 125%, 37,5% lub 200×. Enter zatwierdza, Esc cofa."));
    return false;
}
fn commitZoomEdit() bool {
    if (image.handle == null) return false;
    if (!zoom_dirty) {
        zoom_editing = false;
        zoomCaption(true);
        return true;
    }
    if (c.GetWindowTextLengthW(zoom_label) > 64) return badZoom(false);
    var text: [65]u16 = undefined;
    const n = c.GetWindowTextW(zoom_label, &text, text.len);
    if (n <= 0) return badZoom(false);
    const scale = zoomMath.parse(text[0..@intCast(n)]) catch return badZoom(false);
    if (!zoomMath.inRange(scale, zoomMath.limits(image.width, image.height, fitZoom(), render.max_geometry))) return badZoom(true);
    const current = actualZoom();
    stopZoom();
    zoom_dirty = false;
    zoom_invalid = false;
    zoom_editing = false;
    fit_mode = false;
    zoom = current;
    zoom_goal = scale;
    zoom_anchor_x = 0;
    zoom_anchor_y = 0;
    zoom_animating = true;
    zoomFrameChanged();
    gesture();
    return true;
}
fn confirmZoom() void {
    if (commitZoomEdit()) {
        _ = c.SetFocus(window);
    } else {
        _ = c.SetFocus(zoom_label);
        _ = c.SendMessageW(zoom_label, c.EM_SETSEL, 0, -1);
    }
}
fn zoomNotice(notice: usize) void {
    if (zoom_setting or closing or zoom_label == null) return;
    switch (notice) {
        c.EN_SETFOCUS => {
            stopZoom();
            if (!zoom_dirty) zoomCaption(true);
            zoom_editing = true;
            zoomFrameChanged();
            _ = c.PostMessageW(zoom_label, c.EM_SETSEL, 0, -1);
        },
        c.EN_CHANGE => {
            zoom_dirty = true;
            zoom_invalid = false;
            zoomFrameChanged();
        },
        c.EN_KILLFOCUS => {
            zoom_editing = false;
            if (zoom_dirty) {
                _ = commitZoomEdit();
            } else zoomCaption(true);
            zoomFrameChanged();
        },
        else => {},
    }
}
fn updateViewInfo() void {
    var utf8: [320]u8 = undefined;
    var wide: [400]u16 = undefined;
    var scale_text: [64]u8 = undefined;
    zoomCaption(false);
    const info = std.fmt.bufPrint(&utf8, "{d} × {d} px    ·    {s}{s}{s}", .{ image.width, image.height, zoomMath.caption(&scale_text, actualZoom()), if (fit_mode) i18n.utf8(" · dopasowanie") else "", if (image.animated) i18n.utf8("    ·    animacja") else "" }) catch "";
    if (!loading and image.handle != null) _ = c.SetWindowTextW(status, w.utf16(&wide, info));
    ui.state(controls[3], fit_mode and image.handle != null, null);
    ui.state(controls[4], !fit_mode and zoom == 1 and image.handle != null, null);
}
fn viewFrame() void {
    if (!frame_pending) return;
    if (zoom_animating) {
        const old = zoom;
        zoom += (zoom_goal - zoom) * 0.38;
        if (std.math.fabs(zoom_goal - zoom) < @max(0.0001, zoom_goal * 0.002)) {
            zoom = zoom_goal;
            zoom_animating = false;
        }
        if (old > 0) {
            const ratio = zoom / old;
            pan_x = zoom_anchor_x - (zoom_anchor_x - pan_x) * ratio;
            pan_y = zoom_anchor_y - (zoom_anchor_y - pan_y) * ratio;
        }
    }
    const now = c.GetTickCount();
    if (now -% label_tick >= 48 or !zoom_animating) {
        label_tick = now;
        updateViewInfo();
    }
    invalidateCanvas();
    if (!zoom_animating) {
        _ = c.KillTimer(window, timer_view);
        frame_pending = false;
    }
}
fn beginModal() void {
    modal_depth += 1;
    _ = c.KillTimer(window, timer_gif);
    _ = c.KillTimer(window, timer_slide);
}
fn endModal() void {
    modal_depth -= 1;
    if (modal_depth == 0) {
        scheduleGif();
        if (slideshow) _ = c.SetTimer(window, timer_slide, 4000, null);
        _ = c.PostMessageW(window, loader.result_message, 0, 0);
    }
}
fn message(value: [*c]const u16) void {
    beginModal();
    defer endModal();
    w.message(window, value);
}
fn fileName(path: []const u16) []const u16 {
    var start: usize = 0;
    for (path, 0..) |ch, i| {
        if (ch == '\\' or ch == '/') start = i + 1;
    }
    return path[start..];
}

fn clearFiles() void {
    for (files[0..file_count]) |path| {
        if (path) |p| _ = c.HeapFree(c.GetProcessHeap(), 0, p);
    }
    file_count = 0;
    file_index = 0;
    navigation_index = 0;
    navigation_direction = 0;
    @memset(unreadable[0..], false);
}
fn lessThan(_: void, a: ?[*:0]u16, b: ?[*:0]u16) bool {
    return c.lstrcmpiW(a.?, b.?) < 0;
}
fn syncFileIndex() void {
    for (files[0..file_count], 0..) |p, i| {
        if (c.lstrcmpiW(p.?, @ptrCast(&file_path)) == 0) {
            file_index = i;
            navigation_index = i;
            return;
        }
    }
    navigation_index = file_index;
}
fn stopFolderScan() void {
    _ = c.KillTimer(window, timer_folder);
    if (folder_search != null and folder_search != c.INVALID_HANDLE_VALUE) _ = c.FindClose(folder_search);
    folder_search = null;
    folder_scanning = false;
}
fn finishFolderScan() void {
    stopFolderScan();
    std.sort.heap(?[*:0]u16, files[0..file_count], {}, lessThan);
    var found = false;
    for (files[0..file_count]) |p| {
        if (c.lstrcmpiW(p.?, @ptrCast(&file_path)) == 0) {
            found = true;
            break;
        }
    }
    if (!found) clearFiles() else syncFileIndex();
    refresh();
}
fn enumerateFolder() void {
    stopFolderScan();
    clearFiles();
    const path = std.mem.sliceTo(&file_path, 0);
    folder_prefix = 0;
    for (path, 0..) |ch, i| {
        if (ch == '\\' or ch == '/') folder_prefix = i + 1;
    }
    if (folder_prefix + 2 >= folder_pattern.len) return;
    @memcpy(folder_pattern[0..folder_prefix], path[0..folder_prefix]);
    folder_pattern[folder_prefix] = '*';
    folder_pattern[folder_prefix + 1] = 0;
    folder_scanning = true;
    // WM_PAINT precedes this low-priority timer: show the image before indexing.
    _ = c.SetTimer(window, timer_folder, 15, null);
}
fn folderStep() void {
    if (!folder_scanning) return;
    if (folder_search == null) {
        folder_search = c.FindFirstFileW(@ptrCast(&folder_pattern), &folder_data);
        if (folder_search == c.INVALID_HANDLE_VALUE) {
            folder_search = null;
            finishFolderScan();
            return;
        }
    }
    const began = c.GetTickCount();
    var entries: usize = 0;
    // Count ALL directory entries, not only supported pictures; yield frequently.
    while (entries < 64 and c.GetTickCount() -% began < 4) : (entries += 1) {
        const name = std.mem.sliceTo(&folder_data.cFileName, 0);
        if ((folder_data.dwFileAttributes & c.FILE_ATTRIBUTE_DIRECTORY) == 0 and formats.supported(name) and folder_prefix + name.len + 1 < folder_pattern.len) {
            const n = folder_prefix + name.len;
            if (c.HeapAlloc(c.GetProcessHeap(), 0, (n + 1) * 2)) |memory| {
                const item: [*]u16 = @ptrCast(@alignCast(memory));
                @memcpy(item[0..folder_prefix], folder_pattern[0..folder_prefix]);
                @memcpy(item[folder_prefix..n], name);
                item[n] = 0;
                files[file_count] = @ptrCast(item);
                file_count += 1;
            }
        }
        if (file_count == files.len or c.FindNextFileW(folder_search, &folder_data) == 0) {
            finishFolderScan();
            return;
        }
    }
}
fn canvasRect() c.RECT {
    var rect: c.RECT = undefined;
    _ = c.GetClientRect(window, &rect);
    if (!fullscreen) {
        rect.left = 16;
        rect.right -= 16;
        rect.top = toolbar_height;
        rect.bottom = @max(rect.top + 1, rect.bottom - status_height);
    }
    return rect;
}
fn actualZoom() f32 {
    return if (fit_mode) fitZoom() else zoom;
}
fn fitZoom() f32 {
    if (image.handle == null or image.width == 0 or image.height == 0) return 1;
    if (c.IsIconic(window) != 0) return last_fit_zoom;
    const r = canvasRect();
    const available_w: f32 = @floatFromInt(@max(1, r.right - r.left - 28));
    const available_h: f32 = @floatFromInt(@max(1, r.bottom - r.top - 28));
    last_fit_zoom = @min(available_w / @as(f32, @floatFromInt(image.width)), available_h / @as(f32, @floatFromInt(image.height)));
    return last_fit_zoom;
}
fn refresh() void {
    var buffer: [1200]u16 = undefined;
    var title: [32768]u16 = undefined;
    const path = std.mem.sliceTo(&file_path, 0);
    const name = fileName(path);
    const title_n = @min(name.len, title.len - 10);
    @memcpy(title[0..title_n], name[0..title_n]);
    const suffix = L(" — Kadr");
    @memcpy(title[title_n..][0..suffix.len], suffix[0..suffix.len]);
    title[title_n + suffix.len] = 0;
    _ = c.SetWindowTextW(window, if (image.handle != null) @ptrCast(&title) else L("Kadr — przeglądarka zdjęć"));
    if (image.handle != null) {
        var text_buf: [600]u8 = undefined;
        var scale_text: [64]u8 = undefined;
        const text = std.fmt.bufPrint(&text_buf, "{d} × {d} px    ·    {s}{s}{s}{s}", .{
            image.width,                             image.height,                                                                                        zoomMath.caption(&scale_text, actualZoom()),
            if (fit_mode) i18n.utf8(" · dopasowanie") else "", if (image.animated) (if (paused) i18n.utf8("    ·    animacja wstrzymana") else i18n.utf8("    ·    animacja")) else "", if (slideshow) i18n.utf8("    ·    pokaz co 4 s") else "",
        }) catch "";
        _ = c.SetWindowTextW(status, w.utf16(&buffer, text));
    } else {
        _ = c.SetWindowTextW(status, L("Gotowy na Twoje zdjęcia. Przeciągnij plik do okna."));
    }
    var counter_buf: [48]u8 = undefined;
    var counter_wide: [64]u16 = undefined;
    var available: usize = 0;
    var position: usize = 0;
    for (unreadable[0..file_count], 0..) |bad, i| {
        if (!bad) {
            available += 1;
            if (i <= file_index) position = available;
        }
    }
    const counter_text = std.fmt.bufPrint(&counter_buf, "{d} / {d}{s}", .{ if (image.handle != null) @max(1, position) else 0, if (image.handle != null) @max(1, available) else 0, if (folder_scanning) "…" else "" }) catch "";
    _ = c.SetWindowTextW(file_counter, w.utf16(&counter_wide, counter_text));
    zoomCaption(false);
    const page_text = std.fmt.bufPrint(&counter_buf, "{d} / {d}", .{ image.page + 1, image.pages }) catch "";
    _ = c.SetWindowTextW(page_label, w.utf16(&counter_wide, page_text));
    for ([_]c.HWND{ file_counter, zoom_label, zoom_name }) |label| _ = c.ShowWindow(label, if (fullscreen) c.SW_HIDE else c.SW_SHOW);
    const show_pages = !fullscreen and image.pages > 1;
    for ([_]c.HWND{ controls[12], controls[13], page_label }) |control| _ = c.ShowWindow(control, if (show_pages) c.SW_SHOW else c.SW_HIDE);
    _ = c.ShowWindow(controls[15], if (!fullscreen and image.handle == null) c.SW_SHOW else c.SW_HIDE);
    ui.state(controls[3], fit_mode and image.handle != null, null);
    ui.state(controls[4], !fit_mode and zoom == 1 and image.handle != null, null);
    ui.state(controls[8], paused, if (paused) .play else .pause);
    ui.state(controls[14], slideshow, if (slideshow) .pause else .slide);
    _ = c.EnableWindow(zoom_label, @intFromBool(image.handle != null));
    _ = c.EnableWindow(controls[16], @intFromBool(image.handle != null));
    _ = c.EnableWindow(controls[17], @intFromBool(image.handle != null and !loading));
    const from = if (loading and navigation_direction != 0) navigation_index else file_index;
    const can_browse = image.handle != null and !folder_scanning and (!loading or navigation_direction != 0);
    _ = c.EnableWindow(controls[1], @intFromBool(can_browse and nextFile(from, unreadable[0..file_count], -1) != null));
    _ = c.EnableWindow(controls[2], @intFromBool(can_browse and nextFile(from, unreadable[0..file_count], 1) != null));
    for (controls[3..11]) |control| _ = c.EnableWindow(control, @intFromBool(image.handle != null));
    _ = c.EnableWindow(controls[18], @intFromBool(image.handle != null and !loading));
    _ = c.EnableWindow(controls[8], @intFromBool(image.animated));
    // Simpler toolbar: 1:1 and slideshow live in the "Więcej" menu (and keep
    // their shortcuts); Pause appears only for animations.
    _ = c.ShowWindow(controls[4], c.SW_HIDE);
    _ = c.ShowWindow(controls[14], c.SW_HIDE);
    _ = c.ShowWindow(controls[8], if (!fullscreen and image.animated) c.SW_SHOW else c.SW_HIDE);
    _ = c.SetWindowTextW(controls[8], if (paused) L("Odtwórz") else L("Pauza"));
    _ = c.SetWindowTextW(controls[14], if (slideshow) L("Zatrzymaj") else L("Pokaz"));
    _ = c.EnableWindow(controls[14], @intFromBool(image.handle != null and file_count > 1 and !folder_scanning));
    _ = c.EnableWindow(controls[12], @intFromBool(image.pages > 1 and image.page > 0));
    _ = c.EnableWindow(controls[13], @intFromBool(image.pages > 1 and image.page + 1 < image.pages));
    if (loading) _ = c.SetWindowTextW(status, L("Wczytywanie… Bieżące zdjęcie pozostaje dostępne."));
    invalidateCanvas();
}
fn scheduleGif() void {
    _ = c.KillTimer(window, timer_gif);
    if (image.animated and !paused and modal_depth == 0 and !loading) _ = c.SetTimer(window, timer_gif, image.frameDelay(), null);
}
fn stopSlide() void {
    slideshow = false;
    _ = c.KillTimer(window, timer_slide);
}
fn hasChanges() bool {
    return edited or rotations != 0;
}
fn confirmDiscard() bool {
    if (!hasChanges()) return true;
    stopSlide();
    beginModal();
    defer endModal();
    return c.MessageBoxW(window, L("Są niezapisane zmiany. Kontynuować bez zapisywania?\n\nAby je zachować, wybierz Anuluj i użyj Zapisz (Ctrl+S) lub Zapisz jako (Ctrl+Shift+S)."), L("Kadr — niezapisane zmiany"), c.MB_OKCANCEL | c.MB_ICONWARNING | c.MB_DEFBUTTON2) == c.IDOK;
}
fn openPath(path: [*:0]const u16, scan: bool) void {
    if (!confirmDiscard()) return;
    var absolute: [32768]u16 = undefined;
    const n = c.GetFullPathNameW(path, absolute.len, &absolute, null);
    if (n == 0 or n >= absolute.len) {
        message(L("Nie można odczytać ścieżki pliku."));
        return;
    }
    if (!loader.request(@ptrCast(&absolute))) {
        message(L("Nie można zlecić wczytania obrazu."));
        return;
    }
    pending_scan = scan;
    navigation_direction = 0;
    page_request = false;
    loading = true;
    if (scan) stopSlide();
    _ = c.KillTimer(window, timer_gif);
    refresh();
}
fn imageReady() void {
    if (closing or modal_depth != 0) return;
    const result = loader.take() orelse return;
    defer loader.release(result);
    loading = false;
    const direction = navigation_direction;
    navigation_direction = 0;
    page_request = false;
    if (!result.success) {
        if (direction != 0) {
            if (navigation_index < file_count and c.lstrcmpiW(files[navigation_index].?, @ptrCast(&result.path)) == 0) unreadable[navigation_index] = true;
            if (nextFile(navigation_index, unreadable[0..file_count], direction)) |next| {
                if (requestNavigation(next, direction)) return;
            }
            navigation_index = file_index;
            stopSlide();
            scheduleGif();
            refresh();
            _ = c.SetWindowTextW(status, L("Pominięto nieczytelne lub brakujące pliki. Brak dalszych zdjęć w tym kierunku."));
            return;
        }
        navigation_index = file_index;
        stopSlide();
        scheduleGif();
        refresh();
        message(L("Nie udało się otworzyć tego pliku. Bieżące zdjęcie pozostaje nietknięte.\n\nPlik może być uszkodzony lub mieć nieobsługiwany wariant formatu. DjVu wymaga folderu deps\\djvu. PDF, RAW, WebP, AVIF i HEIC nie są obsługiwane."));
        return;
    }
    if (profile_started != 0 and profile_ready == 0) profile_ready = counter();
    renderer.setPreview(null, 0, 0);
    renderer.invalidate();
    preview.close();
    image.close();
    image = result.image;
    result.image = .{};
    source_is_static = !image.animated and image.pages == 1 and !image.is_djvu;
    rotations = 0;
    edited = false;
    preview = result.preview;
    result.preview = .{};
    renderer.setPreview(preview.handle, preview.width, preview.height);
    const n = std.mem.sliceTo(&result.path, 0).len;
    @memcpy(file_path[0 .. n + 1], result.path[0 .. n + 1]);
    stopZoom();
    fit_mode = true;
    zoom = 1;
    zoom_goal = 1;
    pan_x = 0;
    pan_y = 0;
    paused = false;
    interactive = true;
    _ = c.SetTimer(window, timer_settle, 240, null);
    if (pending_scan) enumerateFolder() else syncFileIndex();
    // Arrow still held: request the next image now, so it decodes on the
    // worker while this one is painted. No queue of stale repeats builds up.
    if (direction != 0 and held.continues(direction, c.GetTickCount()) and !folder_scanning) {
        if (nextFile(file_index, unreadable[0..file_count], direction)) |next| _ = requestNavigation(next, direction);
    }
    scheduleGif();
    refresh();
    invalidate();
}
/// Arrow released (or focus lost) while browsing by autorepeat: stop on the
/// image on screen instead of jumping to one still being decoded.
fn stopHeldNavigation() void {
    if (!loading or navigation_direction == 0) return;
    loader.cancel();
    loading = false;
    navigation_direction = 0;
    navigation_index = file_index;
    scheduleGif();
    refresh();
}
fn chooseFile() void {
    beginModal();
    defer endModal();
    var path: [32768]u16 = [_]u16{0} ** 32768;
    var dialog = std.mem.zeroes(c.OPENFILENAMEW);
    dialog.lStructSize = @sizeOf(c.OPENFILENAMEW);
    dialog.hwndOwner = window;
    dialog.lpstrFile = &path;
    dialog.nMaxFile = path.len;
    dialog.lpstrFilter = formats.localizedFilter();
    dialog.lpstrTitle = L("Kadr — otwórz obraz");
    dialog.Flags = c.OFN_EXPLORER | c.OFN_FILEMUSTEXIST | c.OFN_PATHMUSTEXIST | c.OFN_NOCHANGEDIR;
    if (c.GetOpenFileNameW(&dialog) != 0) openPath(@ptrCast(&path), true);
}
// Work on an independent raster before replacing/renaming a file. GDI+ keeps
// ordinary source files open; a snapshot also preserves unsaved rotations if IO fails.
fn detachCurrent() bool {
    if (image.handle == null) return false;
    const detached = output.snapshot(&image) orelse return false;
    renderer.setPreview(null, 0, 0);
    renderer.invalidate();
    preview.close();
    image.close();
    image = detached;
    invalidateCanvas();
    return true;
}
fn canOverwrite() bool {
    return source_is_static and image.handle != null and !loading and !image.animated and image.pages == 1 and !image.is_djvu and output.format(std.mem.sliceTo(&file_path, 0)) != null;
}
fn saveTo(path: [*:0]const u16, kind: output.Format, same: bool, replace: bool) bool {
    const target = std.mem.span(path);
    const prefix = target.len - fileName(target).len;
    // GetTempFileNameW is an XP API with a MAX_PATH-sized output buffer.
    if (prefix == 0 or prefix + 14 >= c.MAX_PATH) {
        message(L("Nie można utworzyć pliku tymczasowego. Wybierz krótszą ścieżkę zapisu."));
        return false;
    }
    var folder: [c.MAX_PATH]u16 = undefined;
    @memcpy(folder[0..prefix], target[0..prefix]);
    folder[prefix] = 0;
    var temporary: [c.MAX_PATH]u16 = undefined;
    if (c.GetTempFileNameW(@ptrCast(&folder), L("kdr"), 0, &temporary) == 0) {
        message(L("Nie można utworzyć pliku tymczasowego w folderze docelowym. Sprawdź uprawnienia."));
        return false;
    }
    defer _ = c.DeleteFileW(@ptrCast(&temporary));
    if (!output.save(&image, @ptrCast(&temporary), kind)) {
        message(L("Nie udało się zapisać obrazu. Plik docelowy nie został zmieniony."));
        return false;
    }
    if (same and !detachCurrent()) {
        message(L("Nie można zwolnić pliku źródłowego. Zapisz obraz pod inną nazwą."));
        return false;
    }
    const flags: u32 = @as(u32, c.MOVEFILE_WRITE_THROUGH) | (if (replace) @as(u32, c.MOVEFILE_REPLACE_EXISTING) else 0);
    if (c.MoveFileExW(@ptrCast(&temporary), path, flags) == 0) {
        message(L("Nie można zastąpić pliku docelowego. Sprawdź uprawnienia i czy plik nie jest używany. Bieżący obraz pozostaje w pamięci."));
        return false;
    }
    if (same) {
        rotations = 0;
        edited = false;
        openPath(path, true);
    } else {
        enumerateFolder();
        refresh();
        _ = c.SetWindowTextW(status, L("Zapisano kopię obrazu. Oryginał nie został zmieniony."));
    }
    return true;
}
// Keep the XP Explorer-style common dialog on newer Windows too. Besides a
// consistent interface this exposes native filename controls to accessibility tools.
fn saveDialogHook(_: c.HWND, _: c.UINT, _: c.WPARAM, _: c.LPARAM) callconv(.Stdcall) c.UINT_PTR {
    return 0;
}
fn saveAs() void {
    if (image.handle == null or loading) return;
    beginModal();
    defer endModal();
    if ((image.animated or image.pages > 1) and c.MessageBoxW(window, L("Zapisana zostanie tylko bieżąca klatka lub strona, bez animacji i pozostałych stron. Kontynuować?"), L("Kadr — zapisz jako"), c.MB_OKCANCEL | c.MB_ICONINFORMATION) != c.IDOK) return;
    var path: [32768]u16 = [_]u16{0} ** 32768;
    const source = std.mem.sliceTo(&file_path, 0);
    const kind = output.format(source) orelse .png;
    const extension: [:0]const u16 = switch (kind) { .png => L(".png"), .jpeg => L(".jpg"), .bmp => L(".bmp"), .tiff => L(".tiff"), .gif => L(".gif") };
    // Keep the original name (including its exact extension) and directory.
    // Unsupported extensions still require an explicit supported export suffix.
    const name = fileName(source);
    @memcpy(path[0..name.len], name);
    var directory: [32768]u16 = [_]u16{0} ** 32768;
    const prefix = source.len - name.len;
    const directory_len = if (prefix > 3) prefix - 1 else prefix;
    @memcpy(directory[0..directory_len], source[0..directory_len]);
    var dialog = std.mem.zeroes(c.OPENFILENAMEW);
    dialog.lStructSize = @sizeOf(c.OPENFILENAMEW);
    dialog.hwndOwner = window;
    dialog.lpstrFile = &path;
    dialog.nMaxFile = path.len;
    dialog.lpstrFilter = L("PNG (*.png)\x00*.png\x00JPEG (*.jpg;*.jpeg)\x00*.jpg;*.jpeg\x00BMP (*.bmp)\x00*.bmp\x00TIFF (*.tif;*.tiff)\x00*.tif;*.tiff\x00GIF (*.gif)\x00*.gif\x00\x00");
    dialog.nFilterIndex = switch (kind) { .png => 1, .jpeg => 2, .bmp => 3, .tiff => 4, .gif => 5 };
    dialog.lpstrDefExt = extension[1..].ptr;
    dialog.lpstrInitialDir = &directory;
    dialog.lpstrTitle = L("Kadr — zapisz kopię obrazu");
    dialog.Flags = c.OFN_EXPLORER | c.OFN_PATHMUSTEXIST | c.OFN_NOCHANGEDIR | c.OFN_ENABLEHOOK | c.OFN_ENABLESIZING;
    dialog.lpfnHook = saveDialogHook;
    if (c.GetSaveFileNameW(&dialog) == 0) return;
    const selected = output.format(std.mem.sliceTo(&path, 0)) orelse {
        message(L("Wybierz rozszerzenie PNG, JPG, BMP, TIFF lub GIF. Format zapisu wynika z rozszerzenia pliku."));
        return;
    };
    const same = c.lstrcmpiW(@ptrCast(&path), @ptrCast(&file_path)) == 0;
    if (same and !canOverwrite()) {
        message(L("Nie nadpisuj animacji ani dokumentu wielostronicowego pojedynczym obrazem. Wybierz nową nazwę pliku."));
        return;
    }
    const replace = c.GetFileAttributesW(@ptrCast(&path)) != c.INVALID_FILE_ATTRIBUTES;
    if (replace and c.MessageBoxW(window, L("Plik docelowy już istnieje. Zastąpić go bieżącym obrazem?\n\nZapis może usunąć metadane; JPEG zostanie ponownie skompresowany."), L("Kadr — potwierdź nadpisanie"), c.MB_YESNO | c.MB_ICONWARNING | c.MB_DEFBUTTON2) != c.IDYES) return;
    // A new file appearing during encoding must not be replaced without consent.
    _ = saveTo(@ptrCast(&path), selected, same, replace);
}
fn saveRotation() void {
    if (image.handle == null or loading) return;
    if (!canOverwrite()) {
        message(L("Ten format, animacja lub dokument wielostronicowy nie może być nadpisany pojedynczym obrazem. Użyj Zapisz jako (Ctrl+Shift+S) i nowej nazwy z rozszerzeniem PNG, JPG, BMP, TIFF lub GIF, aby zachować oryginał."));
        return;
    }
    if (!hasChanges()) {
        _ = c.SetWindowTextW(status, L("Brak zmian do zapisania."));
        return;
    }
    beginModal();
    defer endModal();
    const question = if (edited) L("Nadpisać plik zmienionym obrazem?\n\nZapis może usunąć metadane, a JPEG zostanie ponownie skompresowany. Aby zachować oryginał, wybierz Nie i użyj Zapisz jako.") else L("Nadpisać plik obróconym obrazem?\n\nZapis może usunąć metadane, a JPEG zostanie ponownie skompresowany. Aby zachować oryginał, wybierz Nie i użyj Zapisz jako.");
    if (c.MessageBoxW(window, question, if (edited) L("Kadr — zapisz zmiany") else L("Kadr — zapisz obrót"), c.MB_YESNO | c.MB_ICONWARNING | c.MB_DEFBUTTON2) != c.IDYES) return;
    _ = saveTo(@ptrCast(&file_path), output.format(std.mem.sliceTo(&file_path, 0)).?, true, true);
}
/// Opens the editor; returns what the user asked to do next (save/print).
fn editCurrent() editor.Then {
    if (image.handle == null or loading) return .none;
    stopSlide();
    stopZoom();
    beginModal();
    defer endModal();
    if ((image.animated or image.pages > 1 or image.is_djvu) and c.MessageBoxW(window, L("Edycja dotyczy tylko bieżącej klatki lub strony. Wynik zapisz pod nową nazwą, aby zachować cały dokument."), L("Kadr — edycja zdjęcia"), c.MB_OKCANCEL | c.MB_ICONINFORMATION) != c.IDOK) return .none;
    const outcome = editor.show(window, &image) orelse return .none;
    const changed = outcome.image orelse return outcome.then;
    renderer.setPreview(null, 0, 0);
    renderer.invalidate();
    preview.close();
    image.close();
    image = changed;
    // Do not recompute source_is_static: flattening is not permission to
    // overwrite the original animation, document, or DjVu container.
    edited = true;
    rotations = 0;
    fit_mode = true;
    pan_x = 0;
    pan_y = 0;
    refresh();
    invalidate();
    return outcome.then;
}
fn copyImage() void {
    if (image.handle == null or loading) return;
    beginModal();
    defer endModal();
    if (!output.copyClipboard(window, &image)) {
        message(L("Nie udało się skopiować obrazu. Schowek może być używany przez inny program."));
    } else _ = c.SetWindowTextW(status, L("Skopiowano cały obraz do schowka (z bieżącym obrotem)."));
}
fn exportCopy() void {
    if (image.handle == null or loading) return;
    beginModal();
    defer endModal();
    if (export_dialog.show(window, &image, @ptrCast(&file_path)))
        _ = c.SetWindowTextW(status, L("Kopia zapisana. Oryginał bez zmian."));
}
fn copyPath() void {
    if (image.handle == null or loading) return;
    beginModal();
    defer endModal();
    if (!file_tools.copyPath(window, @ptrCast(&file_path))) {
        message(L("Nie można skopiować ścieżki do schowka."));
    } else _ = c.SetWindowTextW(status, L("Skopiowano ścieżkę do schowka."));
}
fn setWallpaper() void {
    if (image.handle == null or loading) return;
    beginModal();
    defer endModal();
    _ = file_tools.wallpaper(window, &image);
}
// A failed document rename/delete must not discard the visible page/frame.
// The detached raster remains usable even if reopening the document fails.
fn restoreDocument(page: u32, frame: u32, turns: u2) void {
    defer {
        refresh();
        invalidate();
    }
    var recovered = Image{};
    defer recovered.close();
    if (!recovered.load(@ptrCast(&file_path))) return;
    if (page != 0 and !recovered.setPage(page)) return;
    if (recovered.animated and frame < recovered.frames) {
        if (w.GdipImageSelectActiveFrame(recovered.handle.?, &w.dimension_time, frame) != 0) return;
        recovered.frame = frame;
        _ = w.GdipGetImageWidth(recovered.handle.?, &recovered.width);
        _ = w.GdipGetImageHeight(recovered.handle.?, &recovered.height);
    }
    var i: u3 = 0;
    while (i < turns) : (i += 1) recovered.rotate();
    renderer.invalidate();
    image.close();
    image = recovered;
    recovered = .{};
    rotations = turns;
}
fn releaseCurrent() void {
    _ = c.KillTimer(window, timer_gif);
    stopZoom();
    renderer.setPreview(null, 0, 0);
    renderer.invalidate();
    preview.close();
    image.close();
    rotations = 0;
    edited = false;
    source_is_static = false;
}
fn renameCurrent() void {
    if (image.handle == null or loading) return;
    beginModal();
    defer endModal();
    stopSlide();
    const path = std.mem.sliceTo(&file_path, 0);
    const name = fileName(path);
    var old_name: [256]u16 = undefined;
    if (name.len >= old_name.len) return;
    @memcpy(old_name[0..name.len], name);
    old_name[name.len] = 0;
    var new_name: [256]u16 = undefined;
    if (!file_dialog.rename(window, @ptrCast(&old_name), &new_name)) return;
    const selected = std.mem.sliceTo(&new_name, 0);
    if (std.mem.eql(u16, name, selected)) return;
    const prefix = path.len - name.len;
    if (prefix + selected.len >= file_path.len) {
        message(L("Nowa ścieżka jest zbyt długa."));
        return;
    }
    var destination: [32768]u16 = undefined;
    @memcpy(destination[0..prefix], path[0..prefix]);
    @memcpy(destination[prefix..][0..selected.len], selected);
    destination[prefix + selected.len] = 0;
    const keep_view = !image.animated and image.pages == 1 and !image.is_djvu;
    const page = image.page;
    const frame = image.frame;
    const turns = rotations;
    if (!detachCurrent()) {
        message(L("Nie można przygotować obrazu do zmiany nazwy. Plik nie został zmieniony."));
        return;
    }
    if (c.MoveFileW(@ptrCast(&file_path), @ptrCast(&destination)) == 0) {
        if (!keep_view) restoreDocument(page, frame, turns);
        message(L("Nie można zmienić nazwy. Sprawdź, czy nazwa nie jest już zajęta i czy masz uprawnienia do pliku."));
        return;
    }
    @memcpy(file_path[0 .. prefix + selected.len + 1], destination[0 .. prefix + selected.len + 1]);
    if (!keep_view) restoreDocument(page, frame, turns);
    enumerateFolder();
    refresh();
    invalidate();
}
fn removeCurrent(permanent: bool) void {
    if (image.handle == null or loading or folder_scanning) return;
    beginModal();
    defer endModal();
    const path = std.mem.sliceTo(&file_path, 0);
    var question: [1024]u16 = undefined;
    const first = if (permanent) L("Trwale usunąć ten plik?\nPlik NIE trafi do Kosza. Tej operacji nie można cofnąć!\n\n") else L("Przenieść ten plik do Kosza?\n\n");
    const name = fileName(path);
    const n = @min(name.len, question.len - first.len - 1);
    @memcpy(question[0..first.len], first[0..first.len]);
    @memcpy(question[first.len..][0..n], name[0..n]);
    question[first.len + n] = 0;
    if (c.MessageBoxW(window, @ptrCast(&question), if (permanent) L("Kadr — usuń trwale") else L("Kadr — usuń do Kosza"), c.MB_YESNO | c.MB_ICONWARNING | c.MB_DEFBUTTON2) != c.IDYES) return;
    stopSlide();
    var next: [32768]u16 = [_]u16{0} ** 32768;
    if (nextFile(file_index, unreadable[0..file_count], 1) orelse nextFile(file_index, unreadable[0..file_count], -1)) |index| {
        const next_path = std.mem.span(files[index].?);
        @memcpy(next[0 .. next_path.len + 1], files[index].?[0 .. next_path.len + 1]);
    }
    const keep_view = !image.animated and image.pages == 1 and !image.is_djvu;
    const page = image.page;
    const frame = image.frame;
    const turns = rotations;
    if (!detachCurrent()) {
        message(L("Nie można zwolnić pliku. Zdjęcie nie zostało usunięte."));
        return;
    }
    if (permanent) {
        // Never change read-only attributes or fall back to recycling on failure.
        if (c.DeleteFileW(@ptrCast(&file_path)) == 0) {
            if (!keep_view) restoreDocument(page, frame, turns);
            message(L("Nie udało się trwale usunąć pliku. Sprawdź uprawnienia, atrybut tylko do odczytu i czy plik nie jest używany."));
            return;
        }
    } else {
        // Shell requires a double-NUL-terminated list, even for a single file.
        var paths: [32769]u16 = undefined;
        @memcpy(paths[0 .. path.len + 1], file_path[0 .. path.len + 1]);
        paths[path.len + 1] = 0;
        var operation = std.mem.zeroes(c.SHFILEOPSTRUCTW);
        operation.hwnd = window;
        operation.wFunc = c.FO_DELETE;
        operation.pFrom = &paths;
        // WANTNUKEWARNING retains Shell's separate confirmation if the system cannot
        // recycle this file. Never silently fall back to permanent deletion on XP.
        operation.fFlags = c.FOF_ALLOWUNDO | c.FOF_NOCONFIRMATION | c.FOF_NOERRORUI | c.FOF_WANTNUKEWARNING;
        const result = c.SHFileOperationW(&operation);
        if (result != 0 or operation.fAnyOperationsAborted != 0 or c.GetFileAttributesW(@ptrCast(&file_path)) != c.INVALID_FILE_ATTRIBUTES) {
            if (!keep_view) restoreDocument(page, frame, turns);
            if (operation.fAnyOperationsAborted == 0) message(L("Nie udało się przenieść pliku do Kosza. Sprawdź uprawnienia i czy plik nie jest używany."));
            return;
        }
    }
    releaseCurrent();
    stopFolderScan();
    clearFiles();
    file_path[0] = 0;
    if (next[0] != 0) openPath(@ptrCast(&next), true);
    refresh();
    invalidate();
}
fn showFolder() void {
    if (image.handle == null or loading) return;
    const path = std.mem.sliceTo(&file_path, 0);
    const prefix = L("/select,\"");
    var args: [32780]u16 = undefined;
    @memcpy(args[0..prefix.len], prefix[0..prefix.len]);
    @memcpy(args[prefix.len..][0..path.len], path);
    args[prefix.len + path.len] = '"';
    args[prefix.len + path.len + 1] = 0;
    const result = c.ShellExecuteW(window, L("open"), L("explorer.exe"), @ptrCast(&args), null, c.SW_SHOWNORMAL);
    if (@intFromPtr(result) <= 32) message(L("Nie można otworzyć folderu w Eksploratorze."));
}
fn showMenu(position: c.POINT) void {
    if (modal_depth != 0 or closing) return;
    const menu = c.CreatePopupMenu() orelse return;
    defer _ = c.DestroyMenu(menu);
    const ready = image.handle != null and !loading;
    const enabled: u32 = c.MF_STRING;
    const disabled: u32 = c.MF_STRING | c.MF_GRAYED;
    _ = c.AppendMenuW(menu, enabled, ID.open, L("Otwórz…\tCtrl+O"));
    _ = c.AppendMenuW(menu, if (ready) enabled else disabled, ID.save_rotation, L("Zapisz\tCtrl+S"));
    _ = c.AppendMenuW(menu, if (ready) enabled else disabled, ID.save_as, L("Zapisz jako…\tCtrl+Shift+S"));
    _ = c.AppendMenuW(menu, if (ready) enabled else disabled, ID.export_copy, L("Eksport / kompresja…"));
    _ = c.AppendMenuW(menu, c.MF_SEPARATOR, 0, null);
    _ = c.AppendMenuW(menu, if (ready) enabled else disabled, ID.copy, L("Kopiuj obraz\tCtrl+C"));
    _ = c.AppendMenuW(menu, if (ready) enabled else disabled, ID.copy_path, L("Kopiuj ścieżkę\tCtrl+Shift+C"));
    _ = c.AppendMenuW(menu, if (ready) enabled else disabled, ID.rename, L("Zmień nazwę…\tF2"));
    _ = c.AppendMenuW(menu, if (ready and !folder_scanning) enabled else disabled, ID.remove, L("Usuń do Kosza…\tDelete"));
    _ = c.AppendMenuW(menu, if (ready and !folder_scanning) enabled else disabled, ID.remove_permanent, L("Usuń trwale…\tShift+Delete"));
    _ = c.AppendMenuW(menu, if (ready) enabled else disabled, ID.folder, L("Pokaż w folderze"));
    _ = c.AppendMenuW(menu, if (ready) enabled else disabled, ID.wallpaper, L("Ustaw jako tapetę…"));
    _ = c.AppendMenuW(menu, c.MF_SEPARATOR, 0, null);
    _ = c.AppendMenuW(menu, if (ready) enabled else disabled, ID.edit, L("Edytuj zdjęcie…\tCtrl+E"));
    _ = c.AppendMenuW(menu, if (ready) enabled else disabled, ID.rotate, L("Obróć w prawo\tR"));
    _ = c.AppendMenuW(menu, if (ready) enabled else disabled, ID.rotate_left, L("Obróć w lewo\tL"));
    _ = c.AppendMenuW(menu, if (ready) enabled else disabled, ID.actual, L("Rzeczywisty rozmiar (1:1)\t1"));
    _ = c.AppendMenuW(menu, (if (ready and file_count > 1 and !folder_scanning) enabled else disabled) | (if (slideshow) @as(u32, c.MF_CHECKED) else 0), ID.slide, L("Pokaz slajdów\tF5"));
    _ = c.AppendMenuW(menu, if (ready) enabled else disabled, ID.print, L("Drukuj…\tCtrl+P"));
    _ = c.AppendMenuW(menu, enabled | (if (fullscreen) @as(u32, c.MF_CHECKED) else 0), ID.fullscreen, L("Pełny ekran\tF11"));
    _ = c.AppendMenuW(menu, enabled, ID.help, L("Pomoc i skróty\tF1"));
    _ = c.AppendMenuW(menu, enabled, ID.updates, L("Sprawdź aktualizacje…"));
    _ = c.AppendMenuW(menu, c.MF_SEPARATOR, 0, null);
    const themes = c.CreatePopupMenu();
    if (themes != null) {
        _ = c.AppendMenuW(themes, enabled, ID.theme_light, L("Jasny"));
        _ = c.AppendMenuW(themes, enabled, ID.theme_dark, L("Ciemny"));
        _ = c.AppendMenuW(themes, enabled, ID.theme_auto, L("Automatyczny"));
        const current: c.UINT = switch (theme.mode) {
            .light => ID.theme_light,
            .dark => ID.theme_dark,
            .auto => ID.theme_auto,
        };
        _ = c.CheckMenuRadioItem(themes, ID.theme_light, ID.theme_auto, current, c.MF_BYCOMMAND);
        // The submenu is destroyed together with its parent menu.
        _ = c.AppendMenuW(menu, c.MF_POPUP, @intFromPtr(themes), L("Motyw"));
    }
    _ = c.AppendMenuW(menu, enabled, ID.language, L("Język / Language…"));
    beginModal();
    const selected = c.TrackPopupMenu(menu, c.TPM_RETURNCMD | c.TPM_RIGHTBUTTON, position.x, position.y, 0, window, null);
    endModal();
    if (selected != 0) command(@intCast(selected));
}
// No wrapping or out-of-range requests, even when keys arrive during decoding.
fn nextFile(from: usize, bad: []const bool, direction: i32) ?usize {
    if (from >= bad.len or direction == 0) return null;
    var index = from;
    while (true) {
        if (direction < 0) {
            if (index == 0) return null;
            index -= 1;
        } else {
            if (index + 1 >= bad.len) return null;
            index += 1;
        }
        if (!bad[index]) return index;
    }
}
fn requestNavigation(index: usize, direction: i32) bool {
    if (!loader.request(files[index].?)) return false;
    navigation_index = index;
    navigation_direction = direction;
    pending_scan = false;
    page_request = false;
    loading = true;
    _ = c.KillTimer(window, timer_gif);
    refresh();
    return true;
}
fn navigate(direction: i32) void {
    if (image.handle == null or folder_scanning or (loading and navigation_direction == 0)) return;
    const from = if (loading) navigation_index else file_index;
    const next = nextFile(from, unreadable[0..file_count], direction) orelse {
        if (slideshow and direction > 0) {
            stopSlide();
            refresh();
        }
        return;
    };
    if (!confirmDiscard()) return;
    _ = requestNavigation(next, direction);
}

test {
    _ = @import("theme.zig");
}
test "folder navigation stops at both ends and handles empty or single-image lists" {
    try std.testing.expect(nextFile(0, &.{}, 1) == null);
    try std.testing.expect(nextFile(0, &.{false}, -1) == null);
    try std.testing.expect(nextFile(0, &.{false}, 1) == null);
    try std.testing.expect(nextFile(0, &.{ false, false, false }, -1) == null);
    try std.testing.expect(nextFile(2, &.{ false, false, false }, 1) == null);
    try std.testing.expectEqual(@as(?usize, 1), nextFile(0, &.{ false, false, false }, 1));
    try std.testing.expectEqual(@as(?usize, 1), nextFile(2, &.{ false, false, false }, -1));
}
test "folder navigation skips unreadable entries without wrapping or retry loops" {
    const bad = [_]bool{ true, false, true, false, true };
    try std.testing.expectEqual(@as(?usize, 3), nextFile(1, &bad, 1));
    try std.testing.expectEqual(@as(?usize, 1), nextFile(3, &bad, -1));
    try std.testing.expect(nextFile(1, &bad, -1) == null);
    try std.testing.expect(nextFile(3, &bad, 1) == null);
    try std.testing.expect(nextFile(0, &.{ true, true, true }, 1) == null);
    try std.testing.expect(nextFile(99, &bad, 1) == null);
}
fn changePage(direction: i32) void {
    if (image.pages <= 1) return;
    const next: i64 = @as(i64, if (loading and page_request) pending_page else image.page) + direction;
    if (next < 0 or next >= image.pages) return;
    if (!confirmDiscard()) return;
    if (!loader.requestPage(@ptrCast(&file_path), @intCast(next))) return;
    loading = true;
    pending_scan = false;
    navigation_direction = 0;
    page_request = true;
    pending_page = @intCast(next);
    _ = c.KillTimer(window, timer_gif);
    refresh();
}
fn setZoomAt(factor: f32, anchor_x: f32, anchor_y: f32) void {
    if (image.handle == null) return;
    if (!zoom_animating) {
        zoom = actualZoom();
        zoom_goal = zoom;
    }
    fit_mode = false;
    zoom_goal = zoomMath.nextScale(zoom_goal, factor, zoomMath.limits(image.width, image.height, fitZoom(), render.max_geometry));
    zoom_anchor_x = anchor_x;
    zoom_anchor_y = anchor_y;
    zoom_animating = true;
    gesture();
}
fn setZoom(factor: f32) void {
    setZoomAt(factor, 0, 0);
}
/// Wheel zoom like IrfanView: each notch is applied and painted at once,
/// with no easing animation trailing behind the mouse.
fn zoomNow(factor: f32, anchor_x: f32, anchor_y: f32) void {
    if (image.handle == null) return;
    const shown = actualZoom();
    const base = if (zoom_animating) zoom_goal else shown;
    const target = zoomMath.nextScale(base, factor, zoomMath.limits(image.width, image.height, fitZoom(), render.max_geometry));
    zoom_animating = false;
    fit_mode = false;
    if (shown > 0) {
        const ratio = target / shown;
        pan_x = anchor_x - (anchor_x - pan_x) * ratio;
        pan_y = anchor_y - (anchor_y - pan_y) * ratio;
    }
    zoom = target;
    zoom_goal = target;
    paintNow();
    updateViewInfo();
}
/// Paint the canvas synchronously instead of waiting for the next timer
/// tick (Win32 timers fire only every ~15.6 ms); idle HQ follows on settle.
fn paintNow() void {
    interactive = true;
    _ = c.SetTimer(window, timer_settle, 240, null);
    invalidateCanvas();
    _ = c.UpdateWindow(window);
}
fn toggleFullscreen() void {
    if (!fullscreen) {
        _ = c.GetWindowRect(window, &restore_rect);
        restore_placement.length = @sizeOf(c.WINDOWPLACEMENT);
        _ = c.GetWindowPlacement(window, &restore_placement);
        restore_style = c.GetWindowLongW(window, c.GWL_STYLE);
        _ = c.SetWindowLongW(window, c.GWL_STYLE, @bitCast(@as(u32, c.WS_POPUP | c.WS_VISIBLE)));
        var info = std.mem.zeroes(c.MONITORINFO);
        info.cbSize = @sizeOf(c.MONITORINFO);
        _ = c.GetMonitorInfoW(c.MonitorFromWindow(window, c.MONITOR_DEFAULTTONEAREST), &info);
        fullscreen = true;
        for (controls) |control| _ = c.ShowWindow(control, c.SW_HIDE);
        _ = c.ShowWindow(status, c.SW_HIDE);
        _ = c.SetWindowPos(window, c.HWND_TOP, info.rcMonitor.left, info.rcMonitor.top, info.rcMonitor.right - info.rcMonitor.left, info.rcMonitor.bottom - info.rcMonitor.top, c.SWP_FRAMECHANGED);
    } else {
        fullscreen = false;
        _ = c.SetWindowLongW(window, c.GWL_STYLE, restore_style);
        for (controls) |control| _ = c.ShowWindow(control, c.SW_SHOW);
        _ = c.ShowWindow(status, c.SW_SHOW);
        _ = c.SetWindowPos(window, null, restore_rect.left, restore_rect.top, restore_rect.right - restore_rect.left, restore_rect.bottom - restore_rect.top, c.SWP_FRAMECHANGED | c.SWP_NOZORDER);
        _ = c.SetWindowPlacement(window, &restore_placement);
    }
    refresh();
}
fn help() void {
    message(L("Skróty Kadra"));
}
fn openReleases() void {
    const result = c.ShellExecuteW(window, L("open"), w.L(releases_url), null, null, c.SW_SHOWNORMAL);
    if (@intFromPtr(result) <= 32) message(L("Nie można otworzyć strony w przeglądarce."));
}
fn chooseTheme(selected: theme.Mode) void {
    theme.mode = selected;
    if (!theme.save(i18n.settingsPath(), selected)) message(L("Nie można zapisać ustawień obok pliku EXE. Sprawdź uprawnienia do folderu programu."));
    theme.update();
}
/// Recolour after a theme change (sent to every window by theme.update()).
fn themeChanged() void {
    renderer.invalidate();
    _ = c.InvalidateRect(window, null, c.FALSE);
}
fn command(id: usize) void {
    const keyboard_focus = if (ui.keyboard_activation) c.GetFocus() else null;
    defer {
        if (keyboard_focus != null and c.IsWindow(keyboard_focus) != 0 and c.IsWindowVisible(keyboard_focus) != 0 and c.IsWindowEnabled(keyboard_focus) != 0) {
            _ = c.SetFocus(keyboard_focus);
        } else _ = c.SetFocus(window);
    }
    switch (id) {
        ID.open, ID.open_empty => chooseFile(),
        ID.save_as => saveAs(),
        ID.edit => switch (editCurrent()) {
            .none => {},
            .save => saveAs(),
            .print => command(ID.print),
        },
        ID.save_rotation => saveRotation(),
        ID.copy => copyImage(),
        ID.copy_path => copyPath(),
        ID.export_copy => exportCopy(),
        ID.wallpaper => setWallpaper(),
        ID.rename => renameCurrent(),
        ID.remove => removeCurrent(false),
        ID.remove_permanent => removeCurrent(true),
        ID.folder => showFolder(),
        ID.language => {
            beginModal();
            i18n.choose(window);
            endModal();
        },
        ID.menu => {
            var rect: c.RECT = undefined;
            _ = c.GetWindowRect(controls[11], &rect);
            var point = c.POINT{ .x = rect.left, .y = rect.bottom };
            if (fullscreen) {
                const canvas = canvasRect();
                point = .{ .x = @divTrunc(canvas.right + canvas.left, 2), .y = @divTrunc(canvas.bottom + canvas.top, 2) };
                _ = c.ClientToScreen(window, &point);
            }
            showMenu(point);
        },
        ID.previous => navigate(-1),
        ID.next => navigate(1),
        ID.fit => {
            stopZoom();
            fit_mode = true;
            pan_x = 0;
            pan_y = 0;
            refresh();
        },
        ID.actual => {
            stopZoom();
            fit_mode = false;
            zoom = 1;
            pan_x = 0;
            pan_y = 0;
            refresh();
        },
        ID.minus => setZoom(0.8),
        ID.plus => setZoom(1.25),
        ID.rotate, ID.rotate_left => {
            const left = id == ID.rotate_left;
            stopZoom();
            renderer.invalidate();
            if (image.handle != null and !loading) {
                if (left) image.rotateLeft() else image.rotate();
                // u2 clockwise quarter turns: a left turn is three right turns.
                if (image.handle != null) rotations +%= if (left) 3 else 1;
            }
            if (preview.handle != null and !loading) {
                if (left) preview.rotateLeft() else preview.rotate();
            }
            renderer.setPreview(preview.handle, preview.width, preview.height);
            pan_x = 0;
            pan_y = 0;
            refresh();
        },
        ID.pause => {
            paused = !paused;
            scheduleGif();
            refresh();
        },
        ID.print => if (image.handle) |handle| {
            beginModal();
            printing.show(window, .{ .image = handle, .width = image.width, .height = image.height });
            endModal();
            refresh();
        },
        ID.fullscreen => toggleFullscreen(),
        ID.help => help(),
        ID.updates => openReleases(),
        ID.theme_light => chooseTheme(.light),
        ID.theme_dark => chooseTheme(.dark),
        ID.theme_auto => chooseTheme(.auto),
        ID.page_prev => changePage(-1),
        ID.page_next => changePage(1),
        ID.slide => {
            if (image.handle == null or file_count < 2) return;
            slideshow = !slideshow;
            if (slideshow) {
                _ = c.SetTimer(window, timer_slide, 4000, null);
            } else {
                _ = c.KillTimer(window, timer_slide);
            }
            refresh();
        },
        else => {},
    }
}
fn resize() void {
    var r: c.RECT = undefined;
    _ = c.GetClientRect(window, &r);
    zoom_frame = toolbar.place(r, canvasRect(), .{
        .buttons = &controls,
        .counter = file_counter,
        .zoom_name = zoom_name,
        .zoom_edit = zoom_label,
        .status = status,
        .page_label = page_label,
        .zoom_text_height = zoom_text_height,
    });
    refresh();
    invalidate();
}
/// Line height of the zoom field font; the field is sized to it so the
/// text sits in the middle of its frame (see toolbar.geometry).
var zoom_text_height: i32 = 19;
fn measureZoomText() void {
    const dc = c.GetDC(window) orelse return;
    defer _ = c.ReleaseDC(window, dc);
    const old = c.SelectObject(dc, ui.font);
    defer _ = c.SelectObject(dc, old);
    var metrics: c.TEXTMETRICW = undefined;
    if (c.GetTextMetricsW(dc, &metrics) != 0 and metrics.tmHeight > 0) zoom_text_height = metrics.tmHeight;
}
fn fill(dc: c.HDC, rect: *const c.RECT, color: u32) void {
    const brush = c.CreateSolidBrush(color);
    _ = c.FillRect(dc, rect, brush);
    _ = c.DeleteObject(brush);
}
fn paint() void {
    const paint_started = if (profile_started != 0 or profile_view) counter() else 0;
    var ps: c.PAINTSTRUCT = undefined;
    const target = c.BeginPaint(window, &ps);
    defer _ = c.EndPaint(window, &ps);
    var client: c.RECT = undefined;
    _ = c.GetClientRect(window, &client);
    if (client.right <= 0 or client.bottom <= 0) return;
    const resized = back_buffer.dc == null or back_buffer.width != client.right or back_buffer.height != client.bottom;
    if (!back_buffer.ensure(target, client.right, client.bottom)) return;
    const dc = back_buffer.dc;
    const draw_chrome = resized or ps.rcPaint.top < toolbar_height or ps.rcPaint.bottom > client.bottom - status_height;
    if (draw_chrome) {
        ui.fill(dc, client, ui.shell);
        if (!fullscreen) {
            ui.chrome(dc, client, fileName(std.mem.sliceTo(&file_path, 0)), std.mem.sliceTo(&file_path, 0), image.handle != null);
            ui.rounded(dc, zoom_frame, 6, ui.shell, if (zoom_invalid) theme.colors.danger else if (zoom_editing) ui.accent else ui.line_color);
        }
    }
    var canvas = canvasRect();
    var intersection: c.RECT = undefined;
    if (resized or draw_chrome or c.IntersectRect(&intersection, &canvas, &ps.rcPaint) != 0) {
        ui.rounded(dc, canvas, if (fullscreen) 0 else 12, if (image.handle != null) ui.canvas_dark else theme.colors.empty, null);
        if (image.handle) |handle| {
            const z = actualZoom();
            const dw = @as(f32, @floatFromInt(image.width)) * z;
            const dh = @as(f32, @floatFromInt(image.height)) * z;
            const cw: f32 = @floatFromInt(canvas.right - canvas.left);
            const ch: f32 = @floatFromInt(canvas.bottom - canvas.top);
            const limit_x = zoomMath.panLimit(dw, cw);
            const limit_y = zoomMath.panLimit(dh, ch);
            pan_x = std.math.clamp(pan_x, -limit_x, limit_x);
            pan_y = std.math.clamp(pan_y, -limit_y, limit_y);
            const x = @as(f32, @floatFromInt(canvas.left)) + (cw - dw) / 2 + pan_x;
            const y = @as(f32, @floatFromInt(canvas.top)) + (ch - dh) / 2 + pan_y;
            renderer.draw(dc, handle, image.width, image.height, x, y, dw, dh, canvas, interactive or dragging or zoom_editing or (image.animated and !paused));
        } else {
            ui.empty(dc, canvas);
        }
    }
    const dirty = ps.rcPaint;
    _ = c.BitBlt(target, dirty.left, dirty.top, dirty.right - dirty.left, dirty.bottom - dirty.top, dc, dirty.left, dirty.top, c.SRCCOPY);
    profilePaint(paint_started);
    if (profile_view) {
        _ = c.GdiFlush();
        const now = counter();
        const factor = 1000 / @as(f64, @floatFromInt(profile_frequency));
        var buffer: [256]u8 = undefined;
        const text = std.fmt.bufPrint(&buffer, "KADR_FRAME paint_ms={d:.3} input_ms={d:.3} interactive={d} zoom={d:.4}\n", .{ @as(f64, @floatFromInt(now - paint_started)) * factor, if (profile_input != 0) @as(f64, @floatFromInt(now - profile_input)) * factor else -1, @intFromBool(interactive or dragging), actualZoom() }) catch "";
        profile_input = 0;
        var written: c.DWORD = 0;
        _ = c.WriteFile(c.GetStdHandle(c.STD_OUTPUT_HANDLE), text.ptr, @intCast(text.len), &written, null);
    }
}
fn createLabel(hwnd: c.HWND, id: usize) c.HWND {
    const h = c.CreateWindowExW(0, L("STATIC"), L(""), c.WS_CHILD | c.WS_VISIBLE | c.SS_CENTER | c.SS_CENTERIMAGE, 0, 0, 1, 1, hwnd, @ptrFromInt(id), null, null);
    _ = c.SendMessageW(h, c.WM_SETFONT, @intFromPtr(ui.font), 0);
    return h;
}
fn controlId(id: usize) c.HMENU {
    return @ptrFromInt(id);
}
fn createControls(hwnd: c.HWND) void {
    ui.init(hwnd);
    controls[0] = ui.button(hwnd, L("Otwórz"), L("Otwórz obraz z dysku (Ctrl+O)"), ID.open, .folder, true);
    controls[1] = ui.button(hwnd, L("Poprzednie zdjęcie"), L("Poprzednie zdjęcie w folderze (←)"), ID.previous, .previous, false);
    controls[2] = ui.button(hwnd, L("Następne zdjęcie"), L("Następne zdjęcie w folderze (→)"), ID.next, .next, false);
    controls[3] = ui.button(hwnd, L("Dopasuj"), L("Pokaż całe zdjęcie (Home)"), ID.fit, .fit, false);
    controls[4] = ui.button(hwnd, L("1:1"), L("Rzeczywisty rozmiar — jeden piksel obrazu na piksel ekranu (1)"), ID.actual, .actual, false);
    controls[5] = ui.button(hwnd, L("Pomniejsz"), L("Pomniejsz (− / kółko myszy)"), ID.minus, .minus, false);
    controls[6] = ui.button(hwnd, L("Powiększ"), L("Powiększ (+ / kółko myszy)"), ID.plus, .plus, false);
    controls[7] = ui.button(hwnd, L("Obróć"), L("Obróć widok w prawo — bez zmiany pliku (R)"), ID.rotate, .rotate, false);
    controls[8] = ui.button(hwnd, L("Pauza"), L("Odtwarzaj / zatrzymaj animację (Spacja)"), ID.pause, .pause, false);
    controls[9] = ui.button(hwnd, L("Drukuj"), L("Ułóż zdjęcie na kartce i wydrukuj (Ctrl+P)"), ID.print, .printer, false);
    controls[10] = ui.button(hwnd, L("Pełny ekran"), L("Pełny ekran (F11), powrót (Esc)"), ID.fullscreen, .fullscreen, false);
    controls[11] = ui.button(hwnd, L("Więcej"), L("Operacje na zdjęciu: zapis obrotu, schowek, nazwa, Kosz i folder (Shift+F10)"), ID.menu, .more, false);
    controls[12] = ui.button(hwnd, L("Poprzednia strona"), L("Poprzednia strona dokumentu (Page Up)"), ID.page_prev, .previous, false);
    controls[13] = ui.button(hwnd, L("Następna strona"), L("Następna strona dokumentu (Page Down)"), ID.page_next, .next, false);
    controls[14] = ui.button(hwnd, L("Pokaz"), L("Pokaz slajdów co cztery sekundy (F5)"), ID.slide, .slide, false);
    controls[15] = ui.button(hwnd, L("Wybierz zdjęcie"), L("Wybierz zdjęcie z dysku (Ctrl+O)"), ID.open_empty, .folder, true);
    file_counter = createLabel(hwnd, 900);
    zoom_name = createLabel(hwnd, 905);
    _ = c.SetWindowTextW(zoom_name, L("Zoom"));
    _ = c.SendMessageW(zoom_name, c.WM_SETFONT, @intFromPtr(ui.small_font), 0);
    zoom_setting = true;
    zoom_label = c.CreateWindowExW(0, L("EDIT"), L("100%"), c.WS_CHILD | c.WS_VISIBLE | c.WS_TABSTOP | c.ES_CENTER | c.ES_AUTOHSCROLL, 0, 0, 80, 26, hwnd, controlId(901), null, null);
    _ = c.SendMessageW(zoom_label, c.WM_SETFONT, @intFromPtr(ui.font), 0);
    _ = c.SendMessageW(zoom_label, c.EM_SETLIMITTEXT, 64, 0);
    _ = c.SendMessageW(zoom_label, c.EM_SETMARGINS, c.EC_LEFTMARGIN | c.EC_RIGHTMARGIN, 4 | (4 << 16));
    zoom_setting = false;
    measureZoomText();
    controls[16] = ui.button(hwnd, L("Ustaw zoom"), L("Zatwierdź wpisany zoom (Enter); Esc przywraca bieżącą wartość"), ID.zoom_apply, .check, false);
    controls[17] = ui.button(hwnd, L("Zapisz"), L("Zapisz obrót w bieżącym pliku (Ctrl+S)"), ID.save_rotation, .save, false);
    controls[18] = ui.button(hwnd, L("Edytuj"), L("Kadrowanie, pisak, zakreślacz, kształty i tekst (Ctrl+E)"), ID.edit, .edit, false);
    page_label = createLabel(hwnd, 902);
    status = c.CreateWindowExW(0, L("STATIC"), L(""), c.WS_CHILD | c.WS_VISIBLE | c.SS_CENTERIMAGE, 0, 0, 1, 1, hwnd, @ptrFromInt(904), null, null);
    _ = c.SendMessageW(status, c.WM_SETFONT, @intFromPtr(ui.small_font), 0);
    const order_flags = c.SWP_NOMOVE | c.SWP_NOSIZE | c.SWP_NOACTIVATE;
    _ = c.SetWindowPos(zoom_name, controls[5], 0, 0, 0, 0, order_flags);
    _ = c.SetWindowPos(zoom_label, zoom_name, 0, 0, 0, 0, order_flags);
    _ = c.SetWindowPos(controls[16], zoom_label, 0, 0, 0, 0, order_flags);
    _ = c.SetWindowPos(controls[6], controls[16], 0, 0, 0, 0, order_flags);
}
fn wndProc(hwnd: c.HWND, msg: c.UINT, wp: c.WPARAM, lp: c.LPARAM) callconv(.Stdcall) c.LRESULT {
    switch (msg) {
        c.WM_CREATE => {
            window = hwnd;
            createControls(hwnd);
            c.DragAcceptFiles(hwnd, c.TRUE);
            return 0;
        },
        loader.result_message => {
            imageReady();
            return 0;
        },
        c.WM_ACTIVATE => {
            // The key-up of a held arrow would go to another window.
            if ((wp & 0xffff) == c.WA_INACTIVE and held.direction != 0) {
                held.reset();
                stopHeldNavigation();
            }
            return c.DefWindowProcW(hwnd, msg, wp, lp);
        },
        c.WM_CONTEXTMENU => {
            if (wp == @intFromPtr(zoom_label)) return c.DefWindowProcW(hwnd, msg, wp, lp);
            const bits: usize = @bitCast(lp);
            var point = c.POINT{
                .x = @as(i16, @bitCast(@as(u16, @truncate(bits)))),
                .y = @as(i16, @bitCast(@as(u16, @truncate(bits >> 16)))),
            };
            if (point.x == -1 and point.y == -1) {
                const canvas = canvasRect();
                point = .{ .x = @divTrunc(canvas.right + canvas.left, 2), .y = @divTrunc(canvas.bottom + canvas.top, 2) };
                _ = c.ClientToScreen(hwnd, &point);
            }
            showMenu(point);
            return 0;
        },
        c.WM_ERASEBKGND => return 1,
        c.WM_PAINT => {
            paint();
            return 0;
        },
        c.WM_NCPAINT, c.WM_NCACTIVATE => {
            // DefWindowProc may repaint the hidden legacy frame white; keep
            // the edge the scaler samples in the toolbar colour (theme.zig).
            const result = c.DefWindowProcW(hwnd, msg, wp, lp);
            if (!fullscreen) theme.paintFrameEdge(hwnd, ui.shell);
            return result;
        },
        c.WM_SETTINGCHANGE => {
            // Automatic theme: Windows "app mode" switched (Settings > Colours).
            if (theme.mode == .auto and lp != 0) {
                const name: [*:0]const u16 = @ptrFromInt(@as(usize, @bitCast(lp)));
                if (theme.isColorSetChange(name)) theme.update();
            }
            return c.DefWindowProcW(hwnd, msg, wp, lp);
        },
        theme.changed_message => {
            themeChanged();
            return 0;
        },
        c.WM_ENTERSIZEMOVE => {
            live_resize = true;
            interactive = true;
            return 0;
        },
        c.WM_EXITSIZEMOVE => {
            live_resize = false;
            interactive = false;
            invalidate();
            return 0;
        },
        c.WM_SIZE => {
            if (wp == c.SIZE_MINIMIZED) return 0;
            if (status != null) resize();
            return 0;
        },
        c.WM_DRAWITEM => {
            const item: *c.DRAWITEMSTRUCT = @ptrFromInt(@as(usize, @bitCast(lp)));
            return if (ui.drawButton(item)) 1 else 0;
        },
        c.WM_CTLCOLOREDIT => {
            const dc: c.HDC = @ptrFromInt(wp);
            _ = c.SetBkColor(dc, ui.shell);
            _ = c.SetTextColor(dc, if (zoom_invalid) theme.colors.danger else ui.ink);
            return @bitCast(@intFromPtr(ui.background_brush));
        },
        c.WM_CTLCOLORSTATIC => {
            const dc: c.HDC = @ptrFromInt(wp);
            _ = c.SetBkColor(dc, ui.shell);
            _ = c.SetTextColor(dc, ui.muted);
            return @bitCast(@intFromPtr(ui.background_brush));
        },
        c.WM_GETMINMAXINFO => {
            const info: *c.MINMAXINFO = @ptrFromInt(@as(usize, @bitCast(lp)));
            info.ptMinTrackSize.x = 800;
            info.ptMinTrackSize.y = 620;
            return 0;
        },
        c.WM_COMMAND => {
            if ((wp & 0xffff) == 901) {
                zoomNotice((wp >> 16) & 0xffff);
                return 0;
            }
            if ((wp & 0xffff) == ID.zoom_apply and modal_depth == 0 and !closing) {
                confirmZoom();
                return 0;
            }
            if (modal_depth == 0) command(wp & 0xffff);
            return 0;
        },
        c.WM_TIMER => {
            if (wp == timer_view) {
                viewFrame();
                return 0;
            }
            if (wp == timer_settle) {
                if (zoom_animating or dragging or live_resize or zoom_editing) {
                    _ = c.SetTimer(hwnd, timer_settle, 100, null);
                    return 0;
                }
                _ = c.KillTimer(hwnd, timer_settle);
                interactive = false;
                updateViewInfo();
                invalidateCanvas();
                return 0;
            }
            if (modal_depth != 0) return 0;
            if (wp == timer_folder) {
                folderStep();
                return 0;
            }
            if (wp == timer_gif and image.animated and !paused) {
                if (c.IsIconic(hwnd) != 0) return 0;
                const delay = image.nextFrame();
                renderer.invalidate();
                if (delay == 0 or !image.animated) {
                    _ = c.KillTimer(hwnd, timer_gif);
                    refresh();
                } else {
                    _ = c.SetTimer(hwnd, timer_gif, @max(20, delay), null);
                    invalidateCanvas();
                }
            } else if (wp == timer_slide and slideshow and !loading) navigate(1);
            return 0;
        },
        c.WM_DROPFILES => {
            const drop: c.HDROP = @ptrFromInt(wp);
            var path: [32768]u16 = undefined;
            const count = c.DragQueryFileW(drop, 0, &path, path.len);
            c.DragFinish(drop);
            if (modal_depth == 0 and count > 0 and count < path.len) openPath(@ptrCast(&path), true);
            return 0;
        },
        c.WM_MOUSEWHEEL => {
            profileInput();
            const delta: i16 = @bitCast(@as(u16, @truncate(wp >> 16)));
            var point = c.POINT{ .x = @as(i16, @bitCast(@as(u16, @truncate(@as(usize, @bitCast(lp)))))), .y = @as(i16, @bitCast(@as(u16, @truncate(@as(usize, @bitCast(lp)) >> 16)))) };
            _ = c.ScreenToClient(hwnd, &point);
            const viewport = canvasRect();
            const amount: f32 = @floatFromInt(if (delta >= 0) @as(i32, delta) else -@as(i32, delta));
            const step = 1 + amount * 0.0015;
            zoomNow(if (delta >= 0) step else 1 / step, @floatFromInt(point.x - @divTrunc(viewport.left + viewport.right, 2)), @floatFromInt(point.y - @divTrunc(viewport.top + viewport.bottom, 2)));
            return 0;
        },
        c.WM_LBUTTONDOWN => {
            const x: i32 = @as(i16, @bitCast(@as(u16, @truncate(@as(usize, @bitCast(lp))))));
            const y: i32 = @as(i16, @bitCast(@as(u16, @truncate(@as(usize, @bitCast(lp)) >> 16))));
            const viewport = canvasRect();
            if (image.handle != null and x >= viewport.left and x < viewport.right and y >= viewport.top and y < viewport.bottom) {
                _ = c.SetFocus(hwnd);
                dragging = true;
                drag_x = x;
                drag_y = y;
                _ = c.SetCapture(hwnd);
            }
            return 0;
        },
        c.WM_MOUSEMOVE => {
            if (dragging) {
                profileInput();
                const x: i32 = @as(i16, @bitCast(@as(u16, @truncate(@as(usize, @bitCast(lp))))));
                const y: i32 = @as(i16, @bitCast(@as(u16, @truncate(@as(usize, @bitCast(lp)) >> 16))));
                pan_x += @as(f32, @floatFromInt(x - drag_x));
                pan_y += @as(f32, @floatFromInt(y - drag_y));
                drag_x = x;
                drag_y = y;
                paintNow();
            }
            return 0;
        },
        c.WM_LBUTTONUP, c.WM_CAPTURECHANGED => {
            dragging = false;
            interactive = zoom_animating;
            requestViewFrame();
            if (msg == c.WM_LBUTTONUP) _ = c.ReleaseCapture();
            return 0;
        },
        c.WM_LBUTTONDBLCLK => {
            toggleFullscreen();
            return 0;
        },
        c.WM_CLOSE => {
            if (modal_depth != 0 or !confirmDiscard()) return 0;
            closing = true;
            loader.shutdown();
            _ = c.DestroyWindow(hwnd);
            return 0;
        },
        c.WM_DESTROY => {
            _ = c.KillTimer(hwnd, timer_gif);
            _ = c.KillTimer(hwnd, timer_slide);
            _ = c.KillTimer(hwnd, timer_view);
            _ = c.KillTimer(hwnd, timer_settle);
            loader.shutdown();
            stopFolderScan();
            renderer.deinit();
            back_buffer.deinit();
            preview.close();
            image.close();
            clearFiles();
            c.PostQuitMessage(0);
            return 0;
        },
        else => return c.DefWindowProcW(hwnd, msg, wp, lp),
    }
}
fn keyboard(key: usize, lparam: c.LPARAM) bool {
    if (c.GetFocus() == zoom_label) {
        const action = zoomMath.editKey(key, c.GetKeyState(c.VK_CONTROL) < 0);
        if (action == .confirm) {
            confirmZoom();
            return true;
        }
        if (action == .cancel) {
            cancelZoomEdit();
            _ = c.SetFocus(window);
            return true;
        }
        if (action == .select_all) {
            _ = c.SendMessageW(zoom_label, c.EM_SETSEL, 0, -1);
            return true;
        }
        if (action != .tab) return false;
    }
    if (key == c.VK_TAB) {
        const next = c.GetNextDlgTabItem(window, c.GetFocus(), @intFromBool(c.GetKeyState(c.VK_SHIFT) < 0));
        if (next != null) _ = c.SetFocus(next);
        return true;
    }
    if (key == c.VK_RETURN and c.GetFocus() != window) {
        const focus = c.GetFocus();
        ui.keyboard_activation = true;
        defer ui.keyboard_activation = false;
        if (focus != null and c.IsWindowEnabled(focus) != 0) _ = c.SendMessageW(focus, c.BM_CLICK, 0, 0);
        return true;
    }
    if (key == c.VK_SPACE and c.GetFocus() != window) return false;
    const ctrl = c.GetKeyState(c.VK_CONTROL) < 0;
    const shift = c.GetKeyState(c.VK_SHIFT) < 0;
    const action: usize = switch (key) {
        'O' => if (ctrl) ID.open else return false,
        'P' => if (ctrl) ID.print else return false,
        'E' => if (ctrl) ID.edit else return false,
        'S' => if (ctrl) (if (shift) ID.save_as else ID.save_rotation) else return false,
        'C' => if (ctrl) (if (shift) ID.copy_path else ID.copy) else return false,
        c.VK_F2 => ID.rename,
        c.VK_DELETE => if (shift) ID.remove_permanent else ID.remove,
        c.VK_APPS => ID.menu,
        c.VK_F10 => if (c.GetKeyState(c.VK_SHIFT) < 0) ID.menu else return false,
        c.VK_LEFT, c.VK_RIGHT => {
            const direction: i32 = if (key == c.VK_LEFT) -1 else 1;
            const repeat = (@as(usize, @bitCast(lparam)) >> 30) & 1 != 0;
            const in_flight: i32 = if (loading) navigation_direction else 0;
            if (held.press(key, direction, repeat, in_flight, c.GetTickCount()) == .coalesce) return true;
            command(if (direction < 0) ID.previous else ID.next);
            return true;
        },
        c.VK_HOME => ID.fit,
        '1' => ID.actual,
        c.VK_ADD, c.VK_OEM_PLUS => ID.plus,
        c.VK_SUBTRACT, c.VK_OEM_MINUS => ID.minus,
        'R' => ID.rotate,
        'L' => if (!ctrl) ID.rotate_left else return false,
        c.VK_SPACE => ID.pause,
        c.VK_PRIOR => ID.page_prev,
        c.VK_NEXT => ID.page_next,
        c.VK_F5 => ID.slide,
        c.VK_F11 => ID.fullscreen,
        c.VK_F1 => ID.help,
        c.VK_ESCAPE => {
            if (fullscreen) toggleFullscreen();
            stopSlide();
            refresh();
            return true;
        },
        else => return false,
    };
    command(action);
    return true;
}
comptime {
    if (!@import("builtin").is_test) @export(wWinMainCRTStartup, .{ .name = "wWinMainCRTStartup" });
}
pub fn wWinMainCRTStartup() callconv(.C) noreturn {
    i18n.init();
    theme.on_change = ui.applyTheme;
    i18n.dialog_theme = .{ .apply = theme.applyWindow, .color = theme.dialogColor, .row = theme.fillListRow };
    theme.init(i18n.settingsPath());
    var token: usize = 0;
    const input = w.StartupInput{};
    if (w.GdiplusStartup(&token, &input, null) != 0) {
        w.message(null, L("Nie można uruchomić GDI+. Ten program wymaga Windows XP lub nowszego."));
        c.ExitProcess(1);
    }
    const instance = c.GetModuleHandleW(null);
    var cls = std.mem.zeroes(c.WNDCLASSEXW);
    cls.cbSize = @sizeOf(c.WNDCLASSEXW);
    cls.style = c.CS_DBLCLKS;
    cls.lpfnWndProc = wndProc;
    cls.hInstance = instance;
    cls.hCursor = c.LoadCursorW(null, @ptrFromInt(32512));
    app_icon = c.LoadIconW(instance, @ptrFromInt(4));
    cls.hIcon = if (app_icon != null) app_icon else c.LoadIconW(null, @ptrFromInt(32512));
    cls.hIconSm = cls.hIcon;
    cls.lpszClassName = L("Kadr.Main");
    _ = c.RegisterClassExW(&cls);
    window = c.CreateWindowExW(c.WS_EX_ACCEPTFILES, cls.lpszClassName, L("Kadr — przeglądarka zdjęć"), c.WS_OVERLAPPEDWINDOW | c.WS_CLIPCHILDREN, c.CW_USEDEFAULT, c.CW_USEDEFAULT, 1120, 800, null, null, instance, null);
    if (window == null) {
        w.GdiplusShutdown(token);
        c.ExitProcess(2);
    }
    if (!loader.init(window)) {
        w.message(window, L("Nie można uruchomić wątku wczytywania obrazów."));
        _ = c.DestroyWindow(window);
        ui.deinit();
        w.GdiplusShutdown(token);
        c.ExitProcess(3);
    }
    theme.applyWindow(window);
    _ = c.ShowWindow(window, c.SW_SHOWNORMAL);
    _ = c.UpdateWindow(window);
    if (i18n.hasSettingsError()) message(L("Nie można zapisać ustawień obok pliku EXE. Sprawdź uprawnienia do folderu programu."));
    var argc: c_int = 0;
    const argv = c.CommandLineToArgvW(c.GetCommandLineW(), &argc);
    if (argv != null) {
        if (argc > 2 and c.lstrcmpW(@ptrCast(argv[1]), L("--profile-open")) == 0) {
            var frequency: c.LARGE_INTEGER = undefined;
            _ = c.QueryPerformanceFrequency(&frequency);
            profile_frequency = frequency.QuadPart;
            profile_started = counter();
            openPath(@ptrCast(argv[2]), true);
        } else if (argc > 2 and c.lstrcmpW(@ptrCast(argv[1]), L("--profile-view")) == 0) {
            var frequency: c.LARGE_INTEGER = undefined;
            _ = c.QueryPerformanceFrequency(&frequency);
            profile_frequency = frequency.QuadPart;
            profile_view = true;
            openPath(@ptrCast(argv[2]), true);
        } else if (argc > 1) openPath(@ptrCast(argv[1]), true);
        _ = c.LocalFree(@ptrCast(argv));
    }
    refresh();
    var msg: c.MSG = undefined;
    while (c.GetMessageW(&msg, null, 0, 0) > 0) {
        if ((msg.message == c.WM_KEYDOWN or msg.message == c.WM_SYSKEYDOWN) and keyboard(msg.wParam, msg.lParam)) continue;
        if (msg.message == c.WM_KEYUP and held.release(msg.wParam)) stopHeldNavigation();
        _ = c.TranslateMessage(&msg);
        _ = c.DispatchMessageW(&msg);
    }
    ui.deinit();
    theme.deinit();
    w.GdiplusShutdown(token);
    c.ExitProcess(0);
}
