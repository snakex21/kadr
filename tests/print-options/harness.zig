//! End-to-end print-options harness (Zig 0.11, x86 XP target). Built by
//! tests\print-options\check.cmd as Kadr-print-options.exe and run headless.
//!
//! Unlike the unit tests in printing.zig, which drive windowProc on a private
//! test class, this goes through the production entry point printing.show():
//! class registration, Kadr.ini [Print] Scale restore/persist, the silent
//! default-printer query (PD_RETURNDEFAULT, no dialog, no job), owner
//! disabling/restoration, and Esc closing. It generates its own 1600x900
//! source in memory, opens only its own preview, finds it by class on its own
//! thread, and never clicks Print.
//!
//! Eight previews are chained: the Scale saved by preview k is the one preview
//! k+1 must restore, walking every mode of the combo
//!   Dopasuj (cały obraz) / Wypełnij (przytnij) / Rozciągnij (cała strona) /
//!   100% (96 DPI) / Własny procent / Szerokość (mm) / Wysokość (mm)
//! and checking each mode's placement from the preview's own summary field.
//!
//! The settings file is <exe dir>\Kadr.ini (i18n.settingsPath); the harness
//! creates it with Language=pl and deletes it afterwards.
//! `--interactive` opens one preview and leaves it for manual inspection.
const std = @import("std");
const w = @import("../../src/win.zig");
const c = w.c;
const i18n = @import("../../src/i18n.zig");
const layout = @import("../../src/layout.zig");
const printing = @import("../../src/printing.zig");
const theme = @import("../../src/theme.zig");
const ui = @import("../../src/ui.zig");
const L = w.L;

extern "gdiplus" fn GdipCreateBitmapFromScan0(i32, i32, i32, i32, ?[*]u8, *?*w.GpImage) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipBitmapSetPixel(*w.GpImage, i32, i32, u32) callconv(.Stdcall) i32;

// printing.zig: controlId(control) = 100 + @intFromEnum(Control), Cancel = IDCANCEL.
const id_scale = 102;
const id_details = 109;
const id_print = 111;
const id_status = 113;
const id_value = 116;
const id_value_label = 117;

const source_width = 1600;
const source_height = 900;
const mm_per_96dpi_px = 25.4 / 96.0;

const Scale = layout.Scale;
const scale_names = [_][]const u8{ "fit", "fill", "stretch", "actual", "percent", "width", "height" };
comptime {
    std.debug.assert(scale_names.len == std.meta.fields(Scale).len);
}
/// Combo order is enum order (printing.selectedScale relies on it).
const scale_labels = [_][:0]const u16{
    L("Dopasuj (cały obraz)"), L("Wypełnij (przytnij)"), L("Rozciągnij (cała strona)"),
    L("100% (96 DPI)"),        L("Własny procent"),      L("Szerokość (mm)"),
    L("Wysokość (mm)"),
};
/// Preview k must open in order[k] and then selects order[k + 1].
/// The first one starts from an invalid saved value, which must mean Fit.
const order = [_]Scale{ .fit, .fill, .stretch, .actual_96dpi, .percent, .width_mm, .height_mm, .fit };

var out: std.fs.File.Writer = undefined;
var failures: usize = 0;
var checks: usize = 0;
var owner: c.HWND = null;
var ini: [:0]const u16 = undefined;
var step: usize = 0;
var ticks: usize = 0;
var driven = false;

fn check(ok: bool, comptime what: []const u8, args: anytype) void {
    checks += 1;
    if (!ok) {
        failures += 1;
        out.print("FAIL: preview {d}: " ++ what ++ "\n", args) catch {};
    }
}

fn readIni(buffer: []u16) []const u16 {
    _ = c.WritePrivateProfileStringW(null, null, null, ini.ptr);
    const n = c.GetPrivateProfileStringW(L("Print"), L("Scale"), L(""), buffer.ptr, @intCast(buffer.len), ini.ptr);
    return buffer[0..n];
}

fn writeScale(value: [:0]const u16) void {
    _ = c.WritePrivateProfileStringW(L("Print"), L("Scale"), value.ptr, ini.ptr);
    _ = c.WritePrivateProfileStringW(null, null, null, ini.ptr);
}

fn eqlAscii(wide: []const u16, ascii: []const u8) bool {
    if (wide.len != ascii.len) return false;
    for (wide, ascii) |a, b| if (a != b) return false;
    return true;
}

fn windowText(hwnd: c.HWND, buffer: []u16) []const u16 {
    const n = c.GetWindowTextW(hwnd, buffer.ptr, @intCast(buffer.len));
    return buffer[0..@intCast(@max(n, 0))];
}

/// "P.w × P.h mm\r\nI.w × I.h mm" from printing.updateSummary.
const Summary = struct { page_w: f64, page_h: f64, image_w: f64, image_h: f64 };
fn summary(preview: c.HWND) ?Summary {
    var buffer: [160]u16 = undefined;
    const text = windowText(c.GetDlgItem(preview, id_details), &buffer);
    var values: [4]f64 = undefined;
    var count: usize = 0;
    var i: usize = 0;
    while (i < text.len and count < 4) {
        if (text[i] >= '0' and text[i] <= '9') {
            var ascii: [32]u8 = undefined;
            var n: usize = 0;
            while (i < text.len and n < ascii.len and ((text[i] >= '0' and text[i] <= '9') or text[i] == '.')) : (i += 1) {
                ascii[n] = @intCast(text[i]);
                n += 1;
            }
            values[count] = std.fmt.parseFloat(f64, ascii[0..n]) catch return null;
            count += 1;
        } else i += 1;
    }
    if (count != 4) return null;
    return .{ .page_w = values[0], .page_h = values[1], .image_w = values[2], .image_h = values[3] };
}

fn near(a: f64, b: f64, tolerance: f64) bool {
    return @fabs(a - b) <= tolerance;
}

const source_aspect = @as(f64, source_width) / @as(f64, source_height);

fn checkPlacement(preview: c.HWND, scale: Scale) void {
    const s = summary(preview) orelse {
        check(false, "summary field is not 'W × H mm / W × H mm'", .{step});
        return;
    };
    const aspect = s.image_w / s.image_h;
    // Summary values are rounded to 0.1 mm.
    const keeps_aspect = near(aspect, source_aspect, 0.01);
    switch (scale) {
        .fit => {
            check(keeps_aspect, "Fit keeps the image aspect ({d:.3})", .{ step, aspect });
            check(s.image_w <= s.page_w + 0.05 and s.image_h <= s.page_h + 0.05, "Fit stays on the sheet", .{step});
            check(@max(s.image_w / s.page_w, s.image_h / s.page_h) > 0.85, "Fit uses the printable area", .{step});
        },
        .fill => {
            check(keeps_aspect, "Fill keeps the image aspect ({d:.3})", .{ step, aspect });
            check(s.image_w >= 0.85 * s.page_w and s.image_h >= 0.85 * s.page_h, "Fill covers the printable area", .{step});
            check(s.image_w > s.page_w + 0.05 or s.image_h > s.page_h + 0.05 or near(s.page_w / s.page_h, source_aspect, 0.01), "Fill crops the overflowing side", .{step});
        },
        .stretch => {
            check(s.image_w <= s.page_w + 0.05 and s.image_h <= s.page_h + 0.05, "Stretch stays on the sheet", .{step});
            check(s.image_w >= 0.85 * s.page_w and s.image_h >= 0.85 * s.page_h, "Stretch covers the whole page", .{step});
            check(!keeps_aspect, "Stretch follows the page, not the image aspect", .{step});
        },
        .actual_96dpi, .percent => {
            // Freshly opened, the value field shows 100 %.
            check(near(s.image_w, source_width * mm_per_96dpi_px, 0.06) and near(s.image_h, source_height * mm_per_96dpi_px, 0.06), "100% is 96 DPI: {d} × {d} mm", .{ step, s.image_w, s.image_h });
        },
        .width_mm => check(near(s.image_w, 100, 0.06) and near(s.image_h, 100 / source_aspect, 0.06), "Width 100 mm keeps aspect: {d} × {d} mm", .{ step, s.image_w, s.image_h }),
        .height_mm => check(near(s.image_h, 100, 0.06) and near(s.image_w, 100 * source_aspect, 0.06), "Height 100 mm keeps aspect: {d} × {d} mm", .{ step, s.image_w, s.image_h }),
    }
}

fn setValue(preview: c.HWND, text: [:0]const u16) void {
    // SetWindowText on the EDIT sends EN_CHANGE synchronously (same thread).
    _ = c.SetWindowTextW(c.GetDlgItem(preview, id_value), text.ptr);
}

fn checkValueEdits(preview: c.HWND, scale: Scale) void {
    const target: f64 = switch (scale) {
        .percent => 50,
        .width_mm, .height_mm => 150,
        else => return,
    };
    setValue(preview, if (scale == .percent) L("50") else L("150"));
    var s = summary(preview) orelse return check(false, "summary after a value edit", .{step});
    const expected_w = switch (scale) {
        .percent => source_width * mm_per_96dpi_px * target / 100,
        .width_mm => target,
        else => target * source_aspect,
    };
    check(near(s.image_w, expected_w, 0.06) and near(s.image_w / s.image_h, source_aspect, 0.01), "value {d} gives {d} × {d} mm", .{ step, target, s.image_w, s.image_h });
    // Polish decimal comma.
    setValue(preview, L("12,5"));
    s = summary(preview) orelse return check(false, "summary after a comma value", .{step});
    const comma_w = if (scale == .percent) source_width * mm_per_96dpi_px * 0.125 else if (scale == .width_mm) 12.5 else 12.5 * source_aspect;
    check(near(s.image_w, comma_w, 0.06), "decimal comma 12,5 gives width {d}", .{ step, s.image_w });
    // Blank is invalid: the last valid placement stays and Print is disabled.
    const before = s;
    setValue(preview, L(""));
    var buffer: [160]u16 = undefined;
    const status = windowText(c.GetDlgItem(preview, id_status), &buffer);
    check(std.mem.eql(u16, status, L("Popraw liczby. Zachowano ostatni poprawny podgląd.")), "blank value reports invalid input", .{step});
    check(c.IsWindowEnabled(c.GetDlgItem(preview, id_print)) == 0, "blank value disables Print", .{step});
    const after = summary(preview) orelse return check(false, "summary after a blank value", .{step});
    check(std.meta.eql(before, after), "blank value keeps the last valid placement", .{step});
    // Back to the defaults (100 % / 100 mm) so the next mode starts from them.
    setValue(preview, L("100"));
    const again = windowText(c.GetDlgItem(preview, id_status), &buffer);
    check(!std.mem.eql(u16, again, L("Popraw liczby. Zachowano ostatni poprawny podgląd.")), "valid value clears the input error", .{step});
}

fn drive(preview: c.HWND) void {
    const scale = order[step];
    var buffer: [256]u16 = undefined;
    check(std.mem.eql(u16, windowText(preview, &buffer), L("Kadr — podgląd wydruku")), "native caption", .{step});
    check(c.GetWindow(preview, c.GW_OWNER) == owner, "preview is owned by the caller", .{step});
    check(c.IsWindowEnabled(owner) == 0, "owner disabled while the preview is open", .{step});
    const combo = c.GetDlgItem(preview, id_scale);
    check(c.SendMessageW(combo, c.CB_GETCOUNT, 0, 0) == scale_labels.len, "scale combo has 7 modes", .{step});
    for (scale_labels, 0..) |label, index| {
        const n = c.SendMessageW(combo, c.CB_GETLBTEXTLEN, index, 0);
        if (n < 0 or n >= buffer.len) {
            check(false, "scale item {d} readable", .{ step, index });
            continue;
        }
        _ = c.SendMessageW(combo, c.CB_GETLBTEXT, index, @bitCast(@intFromPtr(&buffer)));
        check(std.mem.eql(u16, buffer[0..@intCast(n)], label), "scale item {d} label/order", .{ step, index });
    }
    const selected = c.SendMessageW(combo, c.CB_GETCURSEL, 0, 0);
    check(selected == @intFromEnum(scale), "restored scale {s} from Kadr.ini (combo index {d})", .{ step, scale_names[@intFromEnum(scale)], selected });
    // Own value modes open the Advanced section with the value field enabled.
    const value = c.GetDlgItem(preview, id_value);
    const valued = @intFromEnum(scale) >= @intFromEnum(Scale.percent);
    check((c.IsWindowVisible(value) != 0) == valued and (c.IsWindowEnabled(value) != 0) == valued, "value field shown only for own-value modes", .{step});
    const value_label = windowText(c.GetDlgItem(preview, id_value_label), &buffer);
    const expected_label = switch (scale) {
        .percent => L("Procent (96 DPI):"),
        .width_mm => L("Szerokość (mm):"),
        .height_mm => L("Wysokość (mm):"),
        else => L("Wartość skali:"),
    };
    check(std.mem.eql(u16, value_label, expected_label), "value label for the mode", .{step});
    checkPlacement(preview, scale);
    checkValueEdits(preview, scale);
    if (step + 1 < order.len) {
        const next = order[step + 1];
        _ = c.SendMessageW(combo, c.CB_SETCURSEL, @intFromEnum(next), 0);
        _ = c.SendMessageW(preview, c.WM_COMMAND, id_scale | (@as(usize, c.CBN_SELCHANGE) << 16), @bitCast(@intFromPtr(combo)));
        checkPlacement(preview, next);
    }
    // Esc closes through the preview's own message loop; Print is never used.
    _ = c.PostMessageW(preview, c.WM_KEYDOWN, c.VK_ESCAPE, 0);
}

fn findPreview(hwnd: c.HWND, result: c.LPARAM) callconv(.Stdcall) c.BOOL {
    var name: [64]u16 = undefined;
    const n = c.GetClassNameW(hwnd, &name, name.len);
    if (n > 0 and std.mem.eql(u16, name[0..@intCast(n)], L("Kadr.PrintPreview.1"))) {
        const slot: *c.HWND = @ptrFromInt(@as(usize, @bitCast(result)));
        slot.* = hwnd;
        return c.FALSE;
    }
    return c.TRUE;
}

fn timerProc(_: c.HWND, _: c.UINT, id: c.UINT_PTR, _: c.DWORD) callconv(.Stdcall) void {
    var preview: c.HWND = null;
    _ = c.EnumThreadWindows(c.GetCurrentThreadId(), findPreview, @bitCast(@intFromPtr(&preview)));
    if (preview == null or c.IsWindowVisible(preview) == 0) {
        ticks += 1;
        if (ticks > 200) {
            out.print("FAIL: preview {d} did not open within 10 s\n", .{step}) catch {};
            std.process.exit(1);
        }
        return;
    }
    _ = c.KillTimer(null, id);
    driven = true;
    drive(preview);
}

fn ownerProc(hwnd: c.HWND, message: c.UINT, wp: c.WPARAM, lp: c.LPARAM) callconv(.Stdcall) c.LRESULT {
    return c.DefWindowProcW(hwnd, message, wp, lp);
}

fn hasPrinter() bool {
    var pd = std.mem.zeroes(c.PRINTDLGW);
    pd.lStructSize = @sizeOf(c.PRINTDLGW);
    pd.Flags = c.PD_RETURNDEFAULT;
    const ok = c.PrintDlgW(&pd) != 0;
    if (pd.hDevMode != null) _ = c.GlobalFree(pd.hDevMode);
    if (pd.hDevNames != null) _ = c.GlobalFree(pd.hDevNames);
    return ok;
}

pub fn main() !void {
    out = std.io.getStdOut().writer();
    var interactive = false;
    var args = try std.process.argsWithAllocator(std.heap.page_allocator);
    defer args.deinit();
    _ = args.skip();
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--interactive")) interactive = true;
    }

    // Fresh settings next to the EXE, in Polish (the source language), before
    // i18n.init reads them, exactly where production keeps Kadr.ini.
    var path: [32768]u16 = undefined;
    const n = c.GetModuleFileNameW(null, &path, path.len);
    if (n == 0 or n >= path.len) return error.ModulePath;
    var end: usize = n;
    while (end > 0 and path[end - 1] != '\\') end -= 1;
    const name = L("Kadr.ini");
    @memcpy(path[end..][0..name.len], name);
    path[end + name.len] = 0;
    const settings: [:0]const u16 = path[0 .. end + name.len :0];
    _ = c.DeleteFileW(settings.ptr);
    _ = c.WritePrivateProfileStringW(L("General"), L("Language"), L("pl"), settings.ptr);
    defer _ = c.DeleteFileW(settings.ptr);

    i18n.init();
    ini = i18n.settingsPath();
    if (!std.mem.eql(u16, ini, settings)) return error.SettingsPath;
    theme.on_change = ui.applyTheme;
    theme.init(ini);
    var token: usize = 0;
    if (w.GdiplusStartup(&token, &w.StartupInput{}, null) != 0) return error.GdiPlus;
    defer w.GdiplusShutdown(token);

    // A recognizable source: red/green/blue bands with a dark 1px frame.
    var bitmap: ?*w.GpImage = null;
    if (GdipCreateBitmapFromScan0(source_width, source_height, 0, 0x26200a, null, &bitmap) != 0) return error.Bitmap;
    defer _ = w.GdipDisposeImage(bitmap.?);
    var y: i32 = 0;
    while (y < source_height) : (y += 1) {
        var x: i32 = 0;
        while (x < source_width) : (x += 1) {
            const edge = x == 0 or y == 0 or x == source_width - 1 or y == source_height - 1;
            const band: u32 = switch (@divTrunc(x * 3, source_width)) {
                0 => 0xffd03030,
                1 => 0xff30a040,
                else => 0xff3050d0,
            };
            _ = GdipBitmapSetPixel(bitmap.?, x, y, if (edge) 0xff202020 else band);
        }
    }
    const source = printing.Source{ .image = bitmap.?, .width = source_width, .height = source_height };

    const instance = c.GetModuleHandleW(null);
    var wc = std.mem.zeroes(c.WNDCLASSW);
    wc.lpfnWndProc = ownerProc;
    wc.hInstance = instance;
    wc.lpszClassName = L("Kadr.PrintOptionsHarness");
    if (c.RegisterClassW(&wc) == 0) return error.OwnerClass;
    owner = c.CreateWindowExW(0, wc.lpszClassName, L("Kadr print-options harness"), c.WS_OVERLAPPEDWINDOW, 0, 0, 400, 300, null, null, instance, null);
    if (owner == null) return error.OwnerWindow;
    defer _ = c.DestroyWindow(owner);
    ui.init(owner);

    if (interactive) {
        try out.print("Interactive: close the preview (Wróć/Esc) to exit.\n", .{});
        printing.show(owner, source);
        return;
    }

    try out.print("print-options harness: default printer {s}\n", .{if (hasPrinter()) "present" else "absent (page from paper list)"});
    writeScale(L("bogus"));
    var buffer: [32]u16 = undefined;
    while (step < order.len) : (step += 1) {
        const failed_before = failures;
        ticks = 0;
        driven = false;
        if (c.SetTimer(null, 0, 50, timerProc) == 0) return error.Timer;
        printing.show(owner, source);
        check(driven, "preview opened and was driven", .{step});
        check(c.IsWindowEnabled(owner) != 0, "owner re-enabled after Esc", .{step});
        var preview: c.HWND = null;
        _ = c.EnumThreadWindows(c.GetCurrentThreadId(), findPreview, @bitCast(@intFromPtr(&preview)));
        check(preview == null, "preview destroyed after Esc", .{step});
        const saved = readIni(&buffer);
        const expected = if (step + 1 < order.len) order[step + 1] else order[step];
        check(eqlAscii(saved, scale_names[@intFromEnum(expected)]), "Kadr.ini [Print] Scale saved as {s}", .{ step, scale_names[@intFromEnum(expected)] });
        try out.print("{s}: preview {d} restored {s}, saved {s}\n", .{
            if (failures == failed_before) "PASS" else "FAIL", step,
            scale_names[@intFromEnum(order[step])], scale_names[@intFromEnum(expected)],
        });
    }
    if (failures != 0) {
        try out.print("FAILED: {d} of {d} checks.\n", .{ failures, checks });
        std.process.exit(1);
    }
    try out.print("PASS: {d} checks; every scale mode restored, laid out and persisted; no print job.\n", .{checks});
}
