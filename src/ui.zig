// Native, XP-compatible visual layer. SPDX-License-Identifier: GPL-3.0-or-later
const std = @import("std");
const w = @import("win.zig");
const c = w.c;
const i18n = @import("i18n.zig");
const L = i18n.L;
const theme = @import("theme.zig");
// Current palette (light by default); see theme.zig and applyTheme().
pub var shell: u32 = theme.light_palette.shell;
pub var paper: u32 = theme.light_palette.paper;
pub var line_color: u32 = theme.light_palette.line;
pub var ink: u32 = theme.light_palette.ink;
pub var muted: u32 = theme.light_palette.muted;
pub var accent: u32 = theme.light_palette.accent;
pub var canvas_dark: u32 = theme.light_palette.canvas;
pub var font: c.HFONT = null;
pub var small_font: c.HFONT = null;
pub var title_font: c.HFONT = null;
pub var brand_font: c.HFONT = null;
pub var background_brush: c.HBRUSH = null;
pub var keyboard_activation = false;
var tips: c.HWND = null;
var buttons: [64]Button = [_]Button{.{}} ** 64;
const Button = struct { hwnd: c.HWND = null, old: c.WNDPROC = null, icon: Icon = .folder, primary: bool = false, selected: bool = false, hover: bool = false, compact: bool = false };
pub const Icon = enum { folder, previous, next, fit, actual, minus, plus, rotate, pause, play, printer, fullscreen, help, slide, photo, check, save, more, edit, crop, undo, flip_h, flip_v, rotate_left, adjust, highlighter, eraser, line, arrow, rect, text, redo };
const Graphics = w.GpGraphics;
const Pen = opaque {};
const Brush = opaque {};
const Path = opaque {};
const Point = extern struct { x: f32, y: f32 };
extern "gdiplus" fn GdipSetSmoothingMode(*Graphics, i32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipCreatePen1(u32, f32, i32, *?*Pen) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipDeletePen(*Pen) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipSetPenStartCap(*Pen, i32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipSetPenEndCap(*Pen, i32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipSetPenLineJoin(*Pen, i32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipDrawLine(*Graphics, *Pen, f32, f32, f32, f32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipDrawLines(*Graphics, *Pen, [*]const Point, i32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipDrawRectangle(*Graphics, *Pen, f32, f32, f32, f32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipDrawEllipse(*Graphics, *Pen, f32, f32, f32, f32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipDrawArc(*Graphics, *Pen, f32, f32, f32, f32, f32, f32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipCreateSolidFill(u32, *?*Brush) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipDeleteBrush(*Brush) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipFillEllipse(*Graphics, *Brush, f32, f32, f32, f32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipFillRectangle(*Graphics, *Brush, f32, f32, f32, f32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipFillPolygon(*Graphics, *Brush, [*]const Point, i32, i32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipCreatePath(i32, *?*Path) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipAddPathArc(*Path, f32, f32, f32, f32, f32, f32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipClosePathFigure(*Path) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipFillPath(*Graphics, *Brush, *Path) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipDrawPath(*Graphics, *Pen, *Path) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipDeletePath(*Path) callconv(.Stdcall) i32;
fn argb(color: u32) u32 {
    return 0xff000000 | ((color & 0xff) << 16) | (color & 0xff00) | ((color >> 16) & 0xff);
}
fn graphics(dc: c.HDC) ?*Graphics {
    var g: ?*Graphics = null;
    if (w.GdipCreateFromHDC(dc, &g) != 0) return null;
    _ = GdipSetSmoothingMode(g.?, 4);
    _ = w.GdipSetPageUnit(g.?, 2);
    return g;
}
pub fn fill(dc: c.HDC, r: c.RECT, color: u32) void {
    const b = c.CreateSolidBrush(color);
    defer _ = c.DeleteObject(b);
    _ = c.FillRect(dc, &r, b);
}
pub fn rule(dc: c.HDC, x: i32, y: i32, width: i32) void {
    fill(dc, .{ .left = x, .top = y, .right = x + width, .bottom = y + 1 }, line_color);
}
pub fn rounded(dc: c.HDC, r: c.RECT, radius: f32, color: u32, border: ?u32) void {
    if (r.right <= r.left or r.bottom <= r.top) return;
    if (radius <= 0) {
        fill(dc, r, color);
        return;
    }
    const g = graphics(dc) orelse return;
    defer _ = w.GdipDeleteGraphics(g);
    const x: f32 = @as(f32, @floatFromInt(r.left)) + 0.5;
    const y: f32 = @as(f32, @floatFromInt(r.top)) + 0.5;
    const width: f32 = @floatFromInt(r.right - r.left - 1);
    const height: f32 = @floatFromInt(r.bottom - r.top - 1);
    const d = @min(radius * 2, @min(width, height));
    var path: ?*Path = null;
    if (GdipCreatePath(0, &path) != 0) return;
    defer _ = GdipDeletePath(path.?);
    _ = GdipAddPathArc(path.?, x, y, d, d, 180, 90);
    _ = GdipAddPathArc(path.?, x + width - d, y, d, d, 270, 90);
    _ = GdipAddPathArc(path.?, x + width - d, y + height - d, d, d, 0, 90);
    _ = GdipAddPathArc(path.?, x, y + height - d, d, d, 90, 90);
    _ = GdipClosePathFigure(path.?);
    var brush: ?*Brush = null;
    if (GdipCreateSolidFill(argb(color), &brush) == 0) {
        _ = GdipFillPath(g, brush.?, path.?);
        _ = GdipDeleteBrush(brush.?);
    }
    if (border) |b| {
        var pen: ?*Pen = null;
        if (GdipCreatePen1(argb(b), 1, 2, &pen) == 0) {
            _ = GdipDrawPath(g, pen.?, path.?);
            _ = GdipDeletePen(pen.?);
        }
    }
}
pub fn text(dc: c.HDC, r: c.RECT, value: [*c]const u16, selected_font: c.HFONT, color: u32, flags: u32) void {
    const old = c.SelectObject(dc, selected_font);
    defer _ = c.SelectObject(dc, old);
    _ = c.SetBkMode(dc, c.TRANSPARENT);
    _ = c.SetTextColor(dc, color);
    var rect = r;
    const direction: u32 = if (i18n.isRtl()) @as(u32, c.DT_RTLREADING) else 0;
    _ = c.DrawTextW(dc, value, -1, &rect, flags | c.DT_NOPREFIX | direction);
}
fn makeFont(height: i32, weight: i32) c.HFONT {
    return c.CreateFontW(-height, 0, 0, 0, weight, 0, 0, 0, c.DEFAULT_CHARSET, c.OUT_DEFAULT_PRECIS, c.CLIP_DEFAULT_PRECIS, c.CLEARTYPE_QUALITY, c.DEFAULT_PITCH, i18n.fontFace().ptr);
}
/// Copy the active theme palette and rebuild the shared background brush.
pub fn applyTheme() void {
    const p = &theme.colors;
    shell = p.shell;
    paper = p.paper;
    line_color = p.line;
    ink = p.ink;
    muted = p.muted;
    accent = p.accent;
    canvas_dark = p.canvas;
    if (background_brush != null) {
        _ = c.DeleteObject(background_brush);
        background_brush = c.CreateSolidBrush(shell);
    }
    if (tips != null) theme.applyTooltip(tips);
}
pub fn init(parent: c.HWND) void {
    applyTheme();
    background_brush = c.CreateSolidBrush(shell);
    font = makeFont(14, c.FW_NORMAL);
    small_font = makeFont(12, c.FW_NORMAL);
    title_font = makeFont(27, c.FW_BOLD);
    brand_font = makeFont(23, c.FW_BOLD);
    var init_data = c.INITCOMMONCONTROLSEX{ .dwSize = @sizeOf(c.INITCOMMONCONTROLSEX), .dwICC = c.ICC_WIN95_CLASSES };
    _ = c.InitCommonControlsEx(&init_data);
    tips = c.CreateWindowExW(c.WS_EX_TOPMOST, L("tooltips_class32"), null, c.WS_POPUP | c.TTS_ALWAYSTIP | c.TTS_NOPREFIX, c.CW_USEDEFAULT, c.CW_USEDEFAULT, c.CW_USEDEFAULT, c.CW_USEDEFAULT, parent, null, null, null);
    _ = c.SendMessageW(tips, c.TTM_SETMAXTIPWIDTH, 0, 300);
    _ = c.SendMessageW(tips, c.TTM_SETDELAYTIME, c.TTDT_INITIAL, 450);
    theme.applyTooltip(tips);
}
pub fn deinit() void {
    if (background_brush != null) _ = c.DeleteObject(background_brush);
    if (tips != null) _ = c.DestroyWindow(tips);
    for ([_]c.HFONT{ font, small_font, title_font, brand_font }) |f| {
        if (f != null) _ = c.DeleteObject(f);
    }
}
fn find(hwnd: c.HWND) ?*Button {
    for (&buttons) |*b| {
        if (b.hwnd == hwnd and hwnd != null) return b;
    }
    return null;
}
/// comctl32 5.8 (XP without a v6 manifest) rejects the newer TOOLINFOW size,
/// silently registering no tooltips. The V2 size is accepted by v5 and v6.
pub const tool_size: c.UINT = if (@hasField(c.TOOLINFOW, "lpReserved")) @offsetOf(c.TOOLINFOW, "lpReserved") else @sizeOf(c.TOOLINFOW);
pub fn button(parent: c.HWND, label: [*c]const u16, tip: [*c]const u16, id: usize, icon: Icon, primary: bool) c.HWND {
    const hwnd = c.CreateWindowExW(0, L("BUTTON"), label, c.WS_CHILD | c.WS_VISIBLE | c.WS_TABSTOP | c.BS_OWNERDRAW, 0, 0, 40, 40, parent, @ptrFromInt(id), null, null);
    if (hwnd == null) return null;
    for (&buttons) |*b| {
        if (b.hwnd == null) {
            b.* = .{ .hwnd = hwnd, .icon = icon, .primary = primary };
            b.old = @ptrFromInt(@as(usize, @bitCast(c.SetWindowLongPtrW(hwnd, c.GWLP_WNDPROC, @bitCast(@intFromPtr(&buttonProc))))));
            break;
        }
    }
    _ = c.SendMessageW(hwnd, c.WM_SETFONT, @intFromPtr(font), 0);
    var tool = std.mem.zeroes(c.TOOLINFOW);
    tool.cbSize = tool_size;
    tool.uFlags = c.TTF_IDISHWND | c.TTF_SUBCLASS;
    tool.hwnd = parent;
    tool.uId = @intFromPtr(hwnd);
    tool.lpszText = @constCast(tip);
    _ = c.SendMessageW(tips, c.TTM_ADDTOOLW, 0, @bitCast(@intFromPtr(&tool)));
    return hwnd;
}
pub fn state(hwnd: c.HWND, selected: bool, icon: ?Icon) void {
    if (find(hwnd)) |b| {
        b.selected = selected;
        if (icon) |i| b.icon = i;
        _ = c.InvalidateRect(hwnd, null, c.FALSE);
    }
}
pub fn place(hwnd: c.HWND, x: i32, y: i32, width: i32, height: i32, compact: bool) void {
    if (find(hwnd)) |b| b.compact = compact;
    _ = c.MoveWindow(hwnd, x, y, width, height, c.TRUE);
}
fn buttonProc(hwnd: c.HWND, msg: c.UINT, wp: c.WPARAM, lp: c.LPARAM) callconv(.Stdcall) c.LRESULT {
    const b = find(hwnd) orelse return c.DefWindowProcW(hwnd, msg, wp, lp);
    const old = b.old;
    if ((msg == c.WM_KEYDOWN or msg == c.WM_KEYUP) and wp == c.VK_SPACE) {
        const previous = keyboard_activation;
        keyboard_activation = true;
        defer keyboard_activation = previous;
        return c.CallWindowProcW(old, hwnd, msg, wp, lp);
    }
    switch (msg) {
        // The owner-draw BUTTON erases with the WM_CTLCOLORBTN brush (system
        // grey by default) before WM_DRAWITEM; that grey field could reach
        // the screen on its own. drawButton covers every pixel.
        c.WM_ERASEBKGND => return 1,
        c.WM_MOUSEMOVE => {
            if (!b.hover) {
                b.hover = true;
                _ = c.InvalidateRect(hwnd, null, c.FALSE);
                var tracking = c.TRACKMOUSEEVENT{ .cbSize = @sizeOf(c.TRACKMOUSEEVENT), .dwFlags = c.TME_LEAVE, .hwndTrack = hwnd, .dwHoverTime = 0 };
                _ = c.TrackMouseEvent(&tracking);
            }
        },
        c.WM_MOUSELEAVE => {
            b.hover = false;
            _ = c.InvalidateRect(hwnd, null, c.FALSE);
        },
        c.WM_ENABLE, c.WM_SETFOCUS, c.WM_KILLFOCUS => {
            _ = c.InvalidateRect(hwnd, null, c.FALSE);
        },
        c.WM_NCDESTROY => {
            b.* = .{};
            return c.CallWindowProcW(old, hwnd, msg, wp, lp);
        },
        else => {},
    }
    return c.CallWindowProcW(old, hwnd, msg, wp, lp);
}
pub fn drawButton(item: *const c.DRAWITEMSTRUCT) bool {
    const b = find(item.hwndItem) orelse return false;
    // Drawn off-screen and copied in one BitBlt: painted straight onto the
    // window, the background fill, the GDI+ field and the icon reach the
    // screen as separate frames (a flash on hover, press and theme changes).
    const r = item.rcItem;
    const width = r.right - r.left;
    const height = r.bottom - r.top;
    if (width <= 0 or height <= 0) return true;
    const memory = c.CreateCompatibleDC(item.hDC);
    const bitmap = if (memory != null) c.CreateCompatibleBitmap(item.hDC, width, height) else null;
    if (bitmap == null) {
        if (memory != null) _ = c.DeleteDC(memory);
        paintButton(b, item, item.hDC, r);
        return true;
    }
    defer {
        _ = c.DeleteObject(bitmap);
        _ = c.DeleteDC(memory);
    }
    const old = c.SelectObject(memory, bitmap);
    defer _ = c.SelectObject(memory, old);
    paintButton(b, item, memory, .{ .left = 0, .top = 0, .right = width, .bottom = height });
    _ = c.BitBlt(item.hDC, r.left, r.top, width, height, memory, 0, 0, c.SRCCOPY);
    return true;
}
fn paintButton(b: *const Button, item: *const c.DRAWITEMSTRUCT, dc: c.HDC, r: c.RECT) void {
    const disabled = (item.itemState & c.ODS_DISABLED) != 0;
    const pressed = (item.itemState & c.ODS_SELECTED) != 0;
    const focus = (item.itemState & c.ODS_FOCUS) != 0;
    const p = &theme.colors;
    fill(dc, r, shell);
    const bg = if (disabled) shell else if (b.primary) (if (pressed) p.primary_pressed else if (b.hover) p.primary_hover else p.primary) else if (pressed) p.pressed else if (b.selected) p.selected else if (b.hover) p.hover else shell;
    const fg = if (disabled) p.disabled else if (b.primary) p.on_primary else if (b.selected) accent else ink;
    rounded(dc, r, 8, bg, if (focus) accent else if (b.selected) p.selected_border else null);
    var label: [128]u16 = undefined;
    const n = c.GetWindowTextW(item.hwndItem, &label, label.len);
    const has_label = !b.compact and r.right - r.left > 58 and n > 0;
    const size: i32 = 20;
    const x = if (has_label) r.left + 13 else r.left + @divTrunc(r.right - r.left - size, 2);
    const y = r.top + @divTrunc(r.bottom - r.top - size, 2);
    if (b.icon == .actual and !has_label) {
        text(dc, r, L("1:1"), font, fg, c.DT_CENTER | c.DT_SINGLELINE | c.DT_VCENTER);
    } else drawIcon(dc, b.icon, @floatFromInt(x), @floatFromInt(y), @floatFromInt(size), fg);
    if (has_label) text(dc, .{ .left = x + 29, .top = r.top, .right = r.right - 8, .bottom = r.bottom }, @ptrCast(&label), font, fg, c.DT_SINGLELINE | c.DT_VCENTER | c.DT_END_ELLIPSIS);
    if (focus and !disabled) {
        var focus_rect = r;
        _ = c.InflateRect(&focus_rect, -4, -4);
        _ = c.DrawFocusRect(dc, &focus_rect);
    }
}
const IconPainter = struct {
    g: *Graphics,
    pen: *Pen,
    x: f32,
    y: f32,
    s: f32,
    fn p(self: IconPainter, x: f32, y: f32) Point {
        return .{ .x = self.x + x * self.s, .y = self.y + y * self.s };
    }
    fn line(self: IconPainter, x1: f32, y1: f32, x2: f32, y2: f32) void {
        const a = self.p(x1, y1);
        const b = self.p(x2, y2);
        _ = GdipDrawLine(self.g, self.pen, a.x, a.y, b.x, b.y);
    }
    fn poly(self: IconPainter, points: []const [2]f32) void {
        var ps: [16]Point = undefined;
        for (points, 0..) |p_, i| ps[i] = self.p(p_[0], p_[1]);
        _ = GdipDrawLines(self.g, self.pen, &ps, @intCast(points.len));
    }
    fn rect(self: IconPainter, x: f32, y: f32, width: f32, height: f32) void {
        const a = self.p(x, y);
        _ = GdipDrawRectangle(self.g, self.pen, a.x, a.y, width * self.s, height * self.s);
    }
    fn ellipse(self: IconPainter, x: f32, y: f32, width: f32, height: f32) void {
        const a = self.p(x, y);
        _ = GdipDrawEllipse(self.g, self.pen, a.x, a.y, width * self.s, height * self.s);
    }
};
pub fn drawIcon(dc: c.HDC, icon: Icon, x: f32, y: f32, size: f32, color: u32) void {
    const g = graphics(dc) orelse return;
    defer _ = w.GdipDeleteGraphics(g);
    var pen: ?*Pen = null;
    if (GdipCreatePen1(argb(color), @max(1.5, size / 13), 2, &pen) != 0) return;
    defer _ = GdipDeletePen(pen.?);
    _ = GdipSetPenStartCap(pen.?, 2);
    _ = GdipSetPenEndCap(pen.?, 2);
    _ = GdipSetPenLineJoin(pen.?, 2);
    const p = IconPainter{ .g = g, .pen = pen.?, .x = x, .y = y, .s = size / 24 };
    switch (icon) {
        .folder => {
            p.poly(&.{ .{ 3, 7 }, .{ 3, 4 }, .{ 9, 4 }, .{ 12, 7 }, .{ 21, 7 }, .{ 21, 11 } });
            p.poly(&.{ .{ 3, 10 }, .{ 22, 10 }, .{ 19, 20 }, .{ 2, 20 }, .{ 3, 10 } });
        },
        .previous => p.poly(&.{ .{ 15, 5 }, .{ 8, 12 }, .{ 15, 19 } }),
        .next => p.poly(&.{ .{ 9, 5 }, .{ 16, 12 }, .{ 9, 19 } }),
        .fit => {
            p.poly(&.{ .{ 3, 9 }, .{ 3, 4 }, .{ 8, 4 } });
            p.poly(&.{ .{ 16, 4 }, .{ 21, 4 }, .{ 21, 9 } });
            p.poly(&.{ .{ 3, 15 }, .{ 3, 20 }, .{ 8, 20 } });
            p.poly(&.{ .{ 16, 20 }, .{ 21, 20 }, .{ 21, 15 } });
            p.rect(7, 8, 10, 8);
        },
        .actual => {
            p.line(5, 8, 8, 5);
            p.line(8, 5, 8, 19);
            p.line(5, 19, 11, 19);
            p.line(16, 8, 19, 5);
            p.line(19, 5, 19, 19);
            p.line(16, 19, 22, 19);
            p.ellipse(12, 9, 0.1, 0.1);
            p.ellipse(12, 15, 0.1, 0.1);
        },
        .check => p.poly(&.{ .{ 5, 12 }, .{ 10, 17 }, .{ 20, 6 } }),
        .minus => p.line(5, 12, 19, 12),
        .plus => {
            p.line(5, 12, 19, 12);
            p.line(12, 5, 12, 19);
        },
        .rotate => {
            _ = GdipDrawArc(g, pen.?, x + 4 * p.s, y + 4 * p.s, 16 * p.s, 16 * p.s, 20, 285);
            p.poly(&.{ .{ 15, 2 }, .{ 20, 6 }, .{ 14, 8 } });
        },
        .pause => {
            p.line(8, 5, 8, 19);
            p.line(16, 5, 16, 19);
        },
        .play, .slide => {
            p.poly(&.{ .{ 8, 5 }, .{ 19, 12 }, .{ 8, 19 }, .{ 8, 5 } });
            if (icon == .slide) {
                p.line(3, 6, 3, 18);
            }
        },
        .save => {
            p.poly(&.{ .{ 3, 3 }, .{ 17, 3 }, .{ 21, 7 }, .{ 21, 21 }, .{ 3, 21 }, .{ 3, 3 } });
            p.rect(7, 3, 9, 6);
            p.line(13, 5, 13, 7);
            p.rect(7, 14, 10, 7);
        },
        .printer => {
            p.rect(7, 3, 10, 5);
            p.poly(&.{ .{ 6, 17 }, .{ 3, 17 }, .{ 3, 9 }, .{ 21, 9 }, .{ 21, 17 }, .{ 18, 17 } });
            p.rect(7, 14, 10, 7);
            p.line(17, 11, 18, 11);
        },
        .fullscreen => {
            p.poly(&.{ .{ 3, 9 }, .{ 3, 3 }, .{ 9, 3 } });
            p.poly(&.{ .{ 15, 3 }, .{ 21, 3 }, .{ 21, 9 } });
            p.poly(&.{ .{ 3, 15 }, .{ 3, 21 }, .{ 9, 21 } });
            p.poly(&.{ .{ 15, 21 }, .{ 21, 21 }, .{ 21, 15 } });
        },
        .help => {
            p.ellipse(3, 3, 18, 18);
            _ = GdipDrawArc(g, pen.?, x + 9 * p.s, y + 6 * p.s, 6 * p.s, 6 * p.s, 180, 230);
            p.line(12, 12, 12, 14);
            p.line(12, 18, 12, 18.1);
        },
        .more => {
            p.ellipse(4, 11, 2, 2);
            p.ellipse(11, 11, 2, 2);
            p.ellipse(18, 11, 2, 2);
        },
        .photo => {
            p.rect(3, 4, 18, 16);
            p.ellipse(14, 7, 3, 3);
            p.poly(&.{ .{ 4, 17 }, .{ 9, 11 }, .{ 14, 17 }, .{ 17, 14 }, .{ 20, 18 } });
        },
        .edit => {
            p.poly(&.{ .{ 4, 20 }, .{ 5, 15 }, .{ 16, 4 }, .{ 20, 8 }, .{ 9, 19 }, .{ 4, 20 } });
            p.line(13, 7, 17, 11);
        },
        .crop => {
            p.poly(&.{ .{ 6, 2 }, .{ 6, 18 }, .{ 22, 18 } });
            p.poly(&.{ .{ 2, 6 }, .{ 18, 6 }, .{ 18, 22 } });
        },
        .undo => {
            p.poly(&.{ .{ 9, 5 }, .{ 4, 10 }, .{ 9, 15 } });
            p.line(4, 10, 14, 10);
            _ = GdipDrawArc(g, pen.?, x + 9 * p.s, y + 10 * p.s, 10 * p.s, 10 * p.s, 270, 180);
            p.line(14, 20, 8, 20);
        },
        .flip_h => {
            p.line(12, 3, 12, 21);
            p.poly(&.{ .{ 9, 6 }, .{ 3, 18 }, .{ 9, 18 }, .{ 9, 6 } });
            p.poly(&.{ .{ 15, 6 }, .{ 21, 18 }, .{ 15, 18 }, .{ 15, 6 } });
        },
        .flip_v => {
            p.line(3, 12, 21, 12);
            p.poly(&.{ .{ 6, 9 }, .{ 18, 3 }, .{ 18, 9 }, .{ 6, 9 } });
            p.poly(&.{ .{ 6, 15 }, .{ 18, 21 }, .{ 18, 15 }, .{ 6, 15 } });
        },
        .rotate_left => {
            _ = GdipDrawArc(g, pen.?, x + 4 * p.s, y + 4 * p.s, 16 * p.s, 16 * p.s, 160, -285);
            p.poly(&.{ .{ 9, 2 }, .{ 4, 6 }, .{ 10, 8 } });
        },
        .adjust => {
            p.line(3, 7, 21, 7);
            p.line(3, 17, 21, 17);
            p.ellipse(12, 4, 6, 6);
            p.ellipse(5, 14, 6, 6);
        },
        .highlighter => {
            p.poly(&.{ .{ 6, 15 }, .{ 15, 4 }, .{ 20, 9 }, .{ 11, 18 }, .{ 6, 15 } });
            p.poly(&.{ .{ 6, 15 }, .{ 4, 19 }, .{ 8, 19 }, .{ 11, 18 } });
            p.line(3, 22, 21, 22);
        },
        .eraser => {
            p.poly(&.{ .{ 3, 15 }, .{ 13, 5 }, .{ 20, 12 }, .{ 11, 21 }, .{ 7, 21 }, .{ 3, 17 }, .{ 3, 15 } });
            p.line(8, 10, 15, 17);
            p.line(11, 21, 21, 21);
        },
        .line => p.line(4, 20, 20, 4),
        .arrow => {
            p.line(4, 20, 19, 5);
            p.poly(&.{ .{ 11, 5 }, .{ 19, 5 }, .{ 19, 13 } });
        },
        .rect => p.rect(3, 6, 18, 12),
        .text => {
            p.line(5, 5, 19, 5);
            p.line(12, 5, 12, 20);
            p.line(9, 20, 15, 20);
        },
        .redo => {
            p.poly(&.{ .{ 15, 5 }, .{ 20, 10 }, .{ 15, 15 } });
            p.line(20, 10, 10, 10);
            _ = GdipDrawArc(g, pen.?, x + 5 * p.s, y + 10 * p.s, 10 * p.s, 10 * p.s, 90, 180);
            p.line(10, 20, 16, 20);
        },
    }
}
pub fn logo(dc: c.HDC, x: i32, y: i32, size: i32) void {
    rounded(dc, .{ .left = x, .top = y, .right = x + size, .bottom = y + size }, @as(f32, @floatFromInt(size)) * 0.25, theme.colors.primary, null);
    drawIcon(dc, .photo, @as(f32, @floatFromInt(x)) + @as(f32, @floatFromInt(size)) * 0.18, @as(f32, @floatFromInt(y)) + @as(f32, @floatFromInt(size)) * 0.18, @as(f32, @floatFromInt(size)) * 0.64, w.rgb(248, 252, 240));
}
pub fn chrome(dc: c.HDC, client: c.RECT, name: []const u16, path: []const u16, loaded: bool) void {
    // The native title already carries the filename; leave this row for controls.
    _ = name;
    _ = path;
    fill(dc, .{ .left = client.left, .top = client.top, .right = client.right, .bottom = client.top + 64 }, shell);
    rule(dc, client.left + 16, client.top + 63, client.right - client.left - 32);
    rule(dc, client.left + 16, client.bottom - 48, client.right - client.left - 32);
    if (!loaded) text(dc, .{ .left = client.right - 230, .top = client.bottom - 42, .right = client.right - 24, .bottom = client.bottom - 10 }, L("Ctrl+O — otwórz   ·   F1 — pomoc"), small_font, muted, c.DT_RIGHT | c.DT_VCENTER | c.DT_SINGLELINE);
}
pub fn empty(dc: c.HDC, canvas: c.RECT) void {
    const cx = @divTrunc(canvas.left + canvas.right, 2);
    const cy = @divTrunc(canvas.top + canvas.bottom, 2);
    const half = @min(285, @divTrunc(canvas.right - canvas.left - 32, 2));
    rounded(dc, .{ .left = cx - half, .top = cy - 169, .right = cx + half, .bottom = cy + 171 }, 18, paper, line_color);
    logo(dc, cx - 30, cy - 132, 60);
    text(dc, .{ .left = cx - half + 10, .top = cy - 51, .right = cx + half - 10, .bottom = cy - 10 }, L("Miejsce na Twoje zdjęcia"), title_font, ink, c.DT_CENTER | c.DT_SINGLELINE);
    text(dc, .{ .left = cx - half + 10, .top = cy + 1, .right = cx + half - 10, .bottom = cy + 28 }, L("Przeciągnij plik tutaj lub wybierz zdjęcie z dysku."), font, muted, c.DT_CENTER | c.DT_SINGLELINE);
    const names = [_][:0]const u16{ L("JPG"), L("PNG"), L("GIF"), L("TIFF"), L("TGA"), L("DJVU") };
    var x = cx - 177;
    for (names) |name| {
        rounded(dc, .{ .left = x, .top = cy + 118, .right = x + 54, .bottom = cy + 144 }, 6, theme.colors.chip, null);
        text(dc, .{ .left = x, .top = cy + 118, .right = x + 54, .bottom = cy + 144 }, name, small_font, accent, c.DT_CENTER | c.DT_VCENTER | c.DT_SINGLELINE);
        x += 60;
    }
}
