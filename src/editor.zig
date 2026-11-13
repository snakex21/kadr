// Photo editor: live crop, markers, shapes and text. SPDX-License-Identifier: GPL-3.0-or-later
//! UI-thread only. show() returns the edited raster (or null when nothing
//! changed) plus an optional follow-up action; null on Cancel/error.
//! The caller's image and source file are never modified here.
const std = @import("std");
const w = @import("win.zig");
const c = w.c;
const Image = @import("image.zig").Image;
const output = @import("output.zig");
const ui = @import("ui.zig");
const theme = @import("theme.zig");
const i18n = @import("i18n.zig");
const L = i18n.L;
const class_name = L("KadrEditorWindow");
const canvas_class = L("KadrEditorCanvas");
const palette_class = L("KadrEditorPalette");
const argb = 0x0026200a;
const allocator = std.heap.page_allocator;
const Rect = extern struct { x: i32, y: i32, width: i32, height: i32 };
const BitmapData = extern struct { width: u32, height: u32, stride: i32, format: i32, scan0: ?[*]u8, reserved: usize };
extern "gdiplus" fn GdipBitmapLockBits(*w.GpImage, *const Rect, u32, i32, *BitmapData) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipBitmapUnlockBits(*w.GpImage, *BitmapData) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipCloneBitmapAreaI(i32, i32, i32, i32, i32, *w.GpImage, *?*w.GpImage) callconv(.Stdcall) i32;

// ---------------------------------------------------------------- pixel ops

pub const Adjustments = struct {
    brightness: i32 = 0,
    contrast: i32 = 0,
    saturation: i32 = 0,
    grayscale: bool = false,
    pub fn neutral(self: Adjustments) bool {
        return self.brightness == 0 and self.contrast == 0 and self.saturation == 0 and !self.grayscale;
    }
};
fn channel(value: f64) u8 {
    return @intFromFloat(@round(std.math.clamp(value, 0, 255)));
}
/// BGRA, straight alpha. Neutral settings preserve every channel exactly.
pub fn adjusted(pixel: [4]u8, a: Adjustments) [4]u8 {
    if (a.neutral()) return pixel;
    const contrast: f64 = @floatFromInt(std.math.clamp(a.contrast, -100, 100));
    const factor = if (contrast >= 0) 1 + contrast * 0.03 else 1 + contrast * 0.01;
    const brightness = @as(f64, @floatFromInt(std.math.clamp(a.brightness, -100, 100))) * 2.55;
    const saturation = if (a.grayscale) 0 else 1 + @as(f64, @floatFromInt(std.math.clamp(a.saturation, -100, 100))) * 0.01;
    const b = (@as(f64, @floatFromInt(pixel[0])) - 127.5) * factor + 127.5 + brightness;
    const g = (@as(f64, @floatFromInt(pixel[1])) - 127.5) * factor + 127.5 + brightness;
    const r = (@as(f64, @floatFromInt(pixel[2])) - 127.5) * factor + 127.5 + brightness;
    const gray = b * 0.114 + g * 0.587 + r * 0.299;
    return .{ channel(gray + (b - gray) * saturation), channel(gray + (g - gray) * saturation), channel(gray + (r - gray) * saturation), pixel[3] };
}
pub fn adjust(image: *Image, a: Adjustments) bool {
    if (a.neutral()) return image.handle != null;
    const handle = image.handle orelse return false;
    const rect = Rect{ .x = 0, .y = 0, .width = @intCast(image.width), .height = @intCast(image.height) };
    var data = std.mem.zeroes(BitmapData);
    if (GdipBitmapLockBits(handle, &rect, 3, argb, &data) != 0) return false;
    defer _ = GdipBitmapUnlockBits(handle, &data);
    const scan = data.scan0 orelse return false;
    for (0..image.height) |y| {
        const address = @as(i64, @intCast(@intFromPtr(scan))) + @as(i64, data.stride) * @as(i64, @intCast(y));
        const row: [*]u8 = @ptrFromInt(@as(usize, @intCast(address)));
        for (0..image.width) |x| {
            const p = row[x * 4 ..][0..4];
            p.* = adjusted(p.*, a);
        }
    }
    return true;
}

pub const Crop = struct { x: u32, y: u32, width: u32, height: u32 };
pub fn validCrop(crop: Crop, width: u32, height: u32) bool {
    return crop.width > 0 and crop.height > 0 and crop.x < width and crop.y < height and crop.width <= width - crop.x and crop.height <= height - crop.y;
}
pub fn cropped(source: *const Image, crop: Crop) ?Image {
    const handle = source.handle orelse return null;
    if (!validCrop(crop, source.width, source.height)) return null;
    var result = Image{ .width = crop.width, .height = crop.height };
    if (GdipCloneBitmapAreaI(@intCast(crop.x), @intCast(crop.y), @intCast(crop.width), @intCast(crop.height), argb, handle, &result.handle) != 0 or result.handle == null) {
        result.close();
        return null;
    }
    return result;
}
pub fn transform(image: *Image, kind: i32) bool {
    const handle = image.handle orelse return false;
    if (kind != 1 and kind != 3 and kind != 4 and kind != 6) return false;
    if (w.GdipImageRotateFlip(handle, kind) != 0) return false;
    if (kind == 1 or kind == 3) std.mem.swap(u32, &image.width, &image.height);
    return true;
}

// ---------------------------------------------------------------- crop geometry

/// Crop selection in image pixels (floating point while dragging).
pub const Box = struct {
    x: f64,
    y: f64,
    w: f64,
    h: f64,
    pub fn right(b: Box) f64 {
        return b.x + b.w;
    }
    pub fn bottom(b: Box) f64 {
        return b.y + b.h;
    }
    pub fn toCrop(b: Box, width: u32, height: u32) ?Crop {
        const fw: f64 = @floatFromInt(width);
        const fh: f64 = @floatFromInt(height);
        const x0 = std.math.clamp(@round(b.x), 0, fw);
        const y0 = std.math.clamp(@round(b.y), 0, fh);
        const x1 = std.math.clamp(@round(b.right()), 0, fw);
        const y1 = std.math.clamp(@round(b.bottom()), 0, fh);
        if (x1 - x0 < 1 or y1 - y0 < 1) return null;
        const crop = Crop{ .x = @intFromFloat(x0), .y = @intFromFloat(y0), .width = @intFromFloat(x1 - x0), .height = @intFromFloat(y1 - y0) };
        return if (validCrop(crop, width, height)) crop else null;
    }
};

/// Largest box with the given aspect (width / height), centred in the image.
pub fn fitAspect(width: f64, height: f64, aspect: ?f64) Box {
    const a = aspect orelse return .{ .x = 0, .y = 0, .w = width, .h = height };
    var bw = width;
    var bh = width / a;
    if (bh > height) {
        bh = height;
        bw = height * a;
    }
    return .{ .x = (width - bw) / 2, .y = (height - bh) / 2, .w = bw, .h = bh };
}

pub const Handle = enum { none, new, move, n, s, e, w, ne, nw, se, sw };

/// Resize a box by dragging one of its handles to (mx, my), keeping the
/// opposite corner/edge fixed, preserving aspect (if any) and image bounds.
pub fn resizeBox(start: Box, handle: Handle, mx: f64, my: f64, width: f64, height: f64, aspect: ?f64) Box {
    const px = std.math.clamp(mx, 0, width);
    const py = std.math.clamp(my, 0, height);
    var ax: f64 = start.x; // anchor
    var ay: f64 = start.y;
    var bx: f64 = start.right(); // moving corner
    var by: f64 = start.bottom();
    switch (handle) {
        .e => bx = px,
        .s => by = py,
        .w => {
            ax = start.right();
            bx = px;
        },
        .n => {
            ay = start.bottom();
            by = py;
        },
        .se, .new => {
            bx = px;
            by = py;
        },
        .sw => {
            ax = start.right();
            bx = px;
            by = py;
        },
        .ne => {
            ay = start.bottom();
            bx = px;
            by = py;
        },
        .nw => {
            ax = start.right();
            ay = start.bottom();
            bx = px;
            by = py;
        },
        .none, .move => return start,
    }
    if (handle == .new) {
        ax = start.x;
        ay = start.y;
    }
    const dx: f64 = if (bx >= ax) 1 else -1;
    const dy: f64 = if (by >= ay) 1 else -1;
    var bw = @fabs(bx - ax);
    var bh = @fabs(by - ay);
    const max_w = if (dx > 0) width - ax else ax;
    const max_h = if (dy > 0) height - ay else ay;
    if (aspect) |a| {
        const vertical_only = handle == .n or handle == .s;
        const horizontal_only = handle == .e or handle == .w;
        if (vertical_only) {
            bw = bh * a;
        } else if (horizontal_only) {
            bh = bw / a;
        } else if (bh == 0 or bw / bh > a) bw = bh * a else bh = bw / a;
        if (bw > max_w) {
            bw = max_w;
            bh = bw / a;
        }
        if (bh > max_h) {
            bh = max_h;
            bw = bh * a;
        }
        // Edge drags with a fixed aspect keep the perpendicular edge anchored
        // at the start box, but must not leave the image either.
        if (vertical_only and ax + bw > width) ax = width - bw;
        if (horizontal_only and ay + bh > height) ay = height - bh;
    } else {
        bw = @min(bw, max_w);
        bh = @min(bh, max_h);
        if (handle == .n or handle == .s) bw = start.w;
        if (handle == .e or handle == .w) bh = start.h;
    }
    bw = @max(bw, 1);
    bh = @max(bh, 1);
    const x = if (dx > 0) ax else ax - bw;
    const y = if (dy > 0) ay else ay - bh;
    return .{ .x = @max(0, x), .y = @max(0, y), .w = @min(bw, width), .h = @min(bh, height) };
}

pub fn moveBox(start: Box, dx: f64, dy: f64, width: f64, height: f64) Box {
    return .{ .x = std.math.clamp(start.x + dx, 0, @max(0, width - start.w)), .y = std.math.clamp(start.y + dy, 0, @max(0, height - start.h)), .w = start.w, .h = start.h };
}

// ---------------------------------------------------------------- drawing ops

const Graphics = w.GpGraphics;
const Pen = opaque {};
const Brush = opaque {};
const Font = opaque {};
const FontFamily = opaque {};
pub const PointF = extern struct { x: f32, y: f32 };
const RectF = extern struct { x: f32, y: f32, width: f32, height: f32 };
extern "gdiplus" fn GdipCreateBitmapFromScan0(i32, i32, i32, i32, ?[*]u8, *?*w.GpImage) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipGetImageGraphicsContext(*w.GpImage, *?*Graphics) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipGraphicsClear(*Graphics, u32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipSetCompositingMode(*Graphics, i32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipSetSmoothingMode(*Graphics, i32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipSetPixelOffsetMode(*Graphics, i32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipSetTextRenderingHint(*Graphics, i32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipCreatePen1(u32, f32, i32, *?*Pen) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipDeletePen(*Pen) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipSetPenStartCap(*Pen, i32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipSetPenEndCap(*Pen, i32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipSetPenLineJoin(*Pen, i32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipDrawLines(*Graphics, *Pen, [*]const PointF, i32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipDrawLine(*Graphics, *Pen, f32, f32, f32, f32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipDrawRectangle(*Graphics, *Pen, f32, f32, f32, f32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipCreateSolidFill(u32, *?*Brush) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipDeleteBrush(*Brush) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipFillEllipse(*Graphics, *Brush, f32, f32, f32, f32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipFillPolygon(*Graphics, *Brush, [*]const PointF, i32, i32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipFillRectangle(*Graphics, *Brush, f32, f32, f32, f32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipCreateFontFamilyFromName([*:0]const u16, ?*anyopaque, *?*FontFamily) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipDeleteFontFamily(*FontFamily) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipCreateFont(*FontFamily, f32, i32, i32, *?*Font) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipDeleteFont(*Font) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipDrawString(*Graphics, [*]const u16, i32, *Font, *const RectF, ?*anyopaque, *Brush) callconv(.Stdcall) i32;

pub const Tool = enum { crop, pen, highlighter, eraser, line, arrow, rect, text };
pub const Op = struct {
    tool: Tool,
    color: u32, // ARGB
    width: f32, // image pixels
    points: []const PointF, // image pixels
    text: []const u16 = &.{},
};

const highlighter_alpha: u32 = 0x66;

fn newPen(color: u32, width: f32) ?*Pen {
    var pen: ?*Pen = null;
    if (GdipCreatePen1(color, @max(0.5, width), 2, &pen) != 0) return null;
    _ = GdipSetPenStartCap(pen.?, 2); // round
    _ = GdipSetPenEndCap(pen.?, 2);
    _ = GdipSetPenLineJoin(pen.?, 2);
    return pen;
}

/// Draws one op. Coordinates are image pixels * scale + (ox, oy).
pub fn drawOp(g: *Graphics, op: Op, scale: f32, ox: f32, oy: f32) void {
    if (op.points.len == 0) return;
    var buffer: [512]PointF = undefined;
    const width = op.width * scale;
    const color = switch (op.tool) {
        .highlighter => (op.color & 0x00ffffff) | (highlighter_alpha << 24),
        .eraser => 0,
        else => op.color,
    };
    if (op.tool == .eraser) _ = GdipSetCompositingMode(g, 1); // SourceCopy: clear to transparent
    defer if (op.tool == .eraser) {
        _ = GdipSetCompositingMode(g, 0);
    };
    const p0 = PointF{ .x = op.points[0].x * scale + ox, .y = op.points[0].y * scale + oy };
    switch (op.tool) {
        .pen, .highlighter, .eraser => {
            if (op.points.len == 1) {
                var brush: ?*Brush = null;
                if (GdipCreateSolidFill(color, &brush) != 0) return;
                defer _ = GdipDeleteBrush(brush.?);
                _ = GdipFillEllipse(g, brush.?, p0.x - width / 2, p0.y - width / 2, width, width);
                return;
            }
            const pen = newPen(color, width) orelse return;
            defer _ = GdipDeletePen(pen);
            // Draw in chunks that overlap by one point; whole short strokes
            // are a single figure, so a highlighter does not darken itself.
            var start: usize = 0;
            while (start + 1 < op.points.len) {
                const end = @min(op.points.len, start + buffer.len);
                for (op.points[start..end], 0..) |p, i| buffer[i] = .{ .x = p.x * scale + ox, .y = p.y * scale + oy };
                _ = GdipDrawLines(g, pen, &buffer, @intCast(end - start));
                start = end - 1;
            }
        },
        .line, .arrow => {
            if (op.points.len < 2) return;
            const p1 = PointF{ .x = op.points[1].x * scale + ox, .y = op.points[1].y * scale + oy };
            const pen = newPen(color, width) orelse return;
            defer _ = GdipDeletePen(pen);
            if (op.tool == .line) {
                _ = GdipDrawLine(g, pen, p0.x, p0.y, p1.x, p1.y);
                return;
            }
            const dx = p1.x - p0.x;
            const dy = p1.y - p0.y;
            const length = @sqrt(dx * dx + dy * dy);
            if (length < 0.5) return;
            const head = @min(length, @max(width * 4, 10 * scale));
            const ux = dx / length;
            const uy = dy / length;
            const base = PointF{ .x = p1.x - ux * head, .y = p1.y - uy * head };
            _ = GdipDrawLine(g, pen, p0.x, p0.y, base.x + ux * head * 0.2, base.y + uy * head * 0.2);
            const half = head * 0.55;
            const triangle = [_]PointF{ p1, .{ .x = base.x - uy * half, .y = base.y + ux * half }, .{ .x = base.x + uy * half, .y = base.y - ux * half } };
            var brush: ?*Brush = null;
            if (GdipCreateSolidFill(color, &brush) != 0) return;
            defer _ = GdipDeleteBrush(brush.?);
            _ = GdipFillPolygon(g, brush.?, &triangle, 3, 0);
        },
        .rect => {
            if (op.points.len < 2) return;
            const p1 = PointF{ .x = op.points[1].x * scale + ox, .y = op.points[1].y * scale + oy };
            const pen = newPen(color, width) orelse return;
            defer _ = GdipDeletePen(pen);
            _ = GdipSetPenLineJoin(pen, 0); // miter: crisp corners
            _ = GdipDrawRectangle(g, pen, @min(p0.x, p1.x), @min(p0.y, p1.y), @fabs(p1.x - p0.x), @fabs(p1.y - p0.y));
        },
        .text => {
            if (op.text.len == 0) return;
            var family: ?*FontFamily = null;
            if (GdipCreateFontFamilyFromName(w.L("Arial"), null, &family) != 0 or family == null) {
                if (GdipCreateFontFamilyFromName(w.L("Tahoma"), null, &family) != 0 or family == null) return;
            }
            defer _ = GdipDeleteFontFamily(family.?);
            var font: ?*Font = null;
            if (GdipCreateFont(family.?, @max(1, width), 1, 2, &font) != 0) return; // bold, pixels
            defer _ = GdipDeleteFont(font.?);
            var brush: ?*Brush = null;
            if (GdipCreateSolidFill(color, &brush) != 0) return;
            defer _ = GdipDeleteBrush(brush.?);
            _ = GdipSetTextRenderingHint(g, 4); // antialias
            const layout = RectF{ .x = p0.x, .y = p0.y, .width = 0, .height = 0 };
            _ = GdipDrawString(g, op.text.ptr, @intCast(op.text.len), font.?, &layout, null, brush.?);
        },
        .crop => {},
    }
}

fn newBitmap(width: u32, height: u32) ?*w.GpImage {
    var bitmap: ?*w.GpImage = null;
    if (GdipCreateBitmapFromScan0(@intCast(width), @intCast(height), 0, argb, null, &bitmap) != 0) return null;
    return bitmap;
}

fn imageGraphics(image: *w.GpImage) ?*Graphics {
    var g: ?*Graphics = null;
    if (GdipGetImageGraphicsContext(image, &g) != 0 or g == null) return null;
    _ = w.GdipSetPageUnit(g.?, 2);
    _ = GdipSetSmoothingMode(g.?, 4);
    return g;
}

/// Renders ops on a transparent layer, then composites the layer over target.
/// The layer makes the eraser remove drawings only, never photo pixels.
pub fn composeOps(target: *Image, ops: []const Op) bool {
    if (ops.len == 0) return true;
    const handle = target.handle orelse return false;
    const tg = imageGraphics(handle) orelse return false;
    defer _ = w.GdipDeleteGraphics(tg);
    if (newBitmap(target.width, target.height)) |layer| {
        defer _ = w.GdipDisposeImage(layer);
        const lg = imageGraphics(layer) orelse return false;
        _ = GdipGraphicsClear(lg, 0);
        for (ops) |op| drawOp(lg, op, 1, 0, 0);
        _ = w.GdipDeleteGraphics(lg);
        _ = w.GdipSetInterpolationMode(tg, 5);
        _ = GdipSetPixelOffsetMode(tg, 4);
        const fw: f32 = @floatFromInt(target.width);
        const fh: f32 = @floatFromInt(target.height);
        return w.GdipDrawImageRectRect(tg, layer, 0, 0, fw, fh, 0, 0, fw, fh, 2, null, null, null) == 0;
    }
    // Not enough memory for a layer: draw directly, skipping eraser strokes.
    for (ops) |op| if (op.tool != .eraser) drawOp(tg, op, 1, 0, 0);
    return true;
}

// ---------------------------------------------------------------- editor state

pub const Then = enum { none, save, print };
pub const Outcome = struct { image: ?Image, then: Then };

const Step = union(enum) { draw: Op, base: Image };

const palette = [_]u32{ 0xff000000, 0xffffffff, 0xffe53935, 0xfffb8c00, 0xffffeb3b, 0xff43a047, 0xff1e88e5, 0xff3949ab, 0xff8e24aa, 0xff9e9e9e };
const tools = [_]Tool{ .crop, .pen, .highlighter, .eraser, .line, .arrow, .rect, .text };
const aspects = [_]?f64{ null, 1, 4.0 / 3.0, 3.0 / 4.0, 3.0 / 2.0, 2.0 / 3.0, 16.0 / 9.0, 210.0 / 297.0, 297.0 / 210.0 };

const ID = struct {
    const left = 201;
    const right = 202;
    const flip_h = 203;
    const flip_v = 204;
    const crop = 205;
    const reset = 206;
    const gray = 207;
    const brightness = 210;
    const contrast = 211;
    const saturation = 212;
    const crop_x = 220;
    const crop_y = 221;
    const crop_w = 222;
    const crop_h = 223;
    const status = 230;
    const canvas = 231;
    const hint = 232;
    const value0 = 240;
    const tool0 = 300;
    const palette = 320;
    const thickness = 321;
    const thickness_value = 322;
    const aspect = 323;
    const whole = 324;
    const undo = 330;
    const redo = 331;
    const save = 340;
    const print = 341;
    const text_edit = 350;
};

const left_width = 156;
const right_width = 236;
const margin = 16;

const State = struct {
    hwnd: c.HWND = null,
    canvas: c.HWND = null,
    source: *const Image,
    original: Image,
    steps: std.ArrayListUnmanaged(Step) = .{},
    pos: usize = 0,
    arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(allocator),
    stroke: std.ArrayListUnmanaged(PointF) = .{},
    current: ?Op = null,
    tool: Tool = .pen,
    color: u32 = 0xffe53935,
    marker_color: u32 = 0xffffeb3b, // highlighter keeps its own colour

    thickness: u32 = 4,
    settings: Adjustments = .{},
    result: ?Image = null,
    then: Then = .none,
    accepted: bool = false,
    done: bool = false,
    // view
    thumbnail: Image = .{},
    shown: Image = .{},
    layer: ?*w.GpImage = null,
    layer_w: u32 = 0,
    layer_h: u32 = 0,
    scale: f64 = 1,
    ox: i32 = 0,
    oy: i32 = 0,
    // crop
    crop: Box = .{ .x = 0, .y = 0, .w = 1, .h = 1 },
    aspect: ?f64 = null,
    drag: Handle = .none,
    drag_box: Box = .{ .x = 0, .y = 0, .w = 1, .h = 1 },
    drag_x: f64 = 0,
    drag_y: f64 = 0,
    syncing: bool = false,
    // text
    text_edit: c.HWND = null,
    text_at: PointF = .{ .x = 0, .y = 0 },
    text_font: c.HFONT = null,
    // layout
    headings: [6]struct { y: i32, x: i32, text: [:0]const u16 } = undefined,
    heading_count: usize = 0,

    fn get(self: *State, id: i32) c.HWND {
        return c.GetDlgItem(self.hwnd, id);
    }
    fn status(self: *State, value: [*:0]const u16) void {
        _ = c.SetDlgItemTextW(self.hwnd, ID.status, value);
    }
    fn base(self: *State) *const Image {
        var i = self.pos;
        while (i > 0) : (i -= 1) {
            switch (self.steps.items[i - 1]) {
                .base => |*image| return image,
                .draw => {},
            }
        }
        return &self.original;
    }
    /// Draw ops on top of the current base (after the last geometry step).
    fn opsStart(self: *State) usize {
        var i = self.pos;
        while (i > 0) : (i -= 1) {
            if (self.steps.items[i - 1] == .base) return i;
        }
        return 0;
    }
    fn collectOps(self: *State, out: *std.ArrayListUnmanaged(Op)) bool {
        for (self.steps.items[self.opsStart()..self.pos]) |step| {
            out.append(allocator, step.draw) catch return false;
        }
        return true;
    }
    fn hasOps(self: *State) bool {
        return self.opsStart() < self.pos;
    }
    fn changed(self: *State) bool {
        return self.pos > 0 or !self.settings.neutral();
    }
    fn unit(self: *State) f32 {
        const b = self.base();
        return @max(1, @as(f32, @floatFromInt(@max(b.width, b.height))) / 1000);
    }
    fn truncate(self: *State) void {
        for (self.steps.items[self.pos..]) |*step| switch (step.*) {
            .base => |*image| image.close(),
            .draw => {},
        };
        self.steps.shrinkRetainingCapacity(self.pos);
    }
    fn push(self: *State, step: Step) bool {
        self.truncate();
        self.steps.append(allocator, step) catch return false;
        self.pos += 1;
        return true;
    }
    fn deinit(self: *State) void {
        self.pos = 0;
        self.truncate();
        self.steps.deinit(allocator);
        self.stroke.deinit(allocator);
        self.arena.deinit();
        self.original.close();
        self.thumbnail.close();
        self.shown.close();
        if (self.layer) |layer| _ = w.GdipDisposeImage(layer);
        if (self.text_font != null) _ = c.DeleteObject(self.text_font);
    }

    /// Base image + drawings (without colour adjustments): used before
    /// geometry changes and, with adjustments, for the final result.
    fn compose(self: *State, with_adjustments: bool) ?Image {
        var result = output.snapshot(self.base()) orelse return null;
        if (with_adjustments and !adjust(&result, self.settings)) {
            result.close();
            return null;
        }
        var ops = std.ArrayListUnmanaged(Op){};
        defer ops.deinit(allocator);
        if (!self.collectOps(&ops) or !composeOps(&result, ops.items)) {
            result.close();
            return null;
        }
        return result;
    }

    // ---- view
    fn canvasSize(self: *State) [2]i32 {
        var r: c.RECT = undefined;
        _ = c.GetClientRect(self.canvas, &r);
        return .{ r.right, r.bottom };
    }
    fn rebuild(self: *State, resample: bool) bool {
        const b = self.base();
        if (resample or self.thumbnail.handle == null) {
            const size = self.canvasSize();
            const cw: f64 = @floatFromInt(@max(32, size[0] - 24));
            const ch: f64 = @floatFromInt(@max(32, size[1] - 24));
            const bw: f64 = @floatFromInt(b.width);
            const bh: f64 = @floatFromInt(b.height);
            self.scale = @min(4, @min(cw / bw, ch / bh));
            const tw: u32 = @max(1, @as(u32, @intFromFloat(@round(bw * self.scale))));
            const th: u32 = @max(1, @as(u32, @intFromFloat(@round(bh * self.scale))));
            const thumb = output.scaledSnapshot(b, tw, th) orelse return false;
            self.thumbnail.close();
            self.thumbnail = thumb;
            self.ox = @divTrunc(size[0] - @as(i32, @intCast(tw)), 2);
            self.oy = @divTrunc(size[1] - @as(i32, @intCast(th)), 2);
        }
        var next = output.snapshot(&self.thumbnail) orelse return false;
        if (!adjust(&next, self.settings)) {
            next.close();
            return false;
        }
        self.shown.close();
        self.shown = next;
        _ = c.InvalidateRect(self.canvas, null, 0);
        return true;
    }
    fn refreshView(self: *State, resample: bool) void {
        if (!self.rebuild(resample)) self.status(L("Nie udało się przygotować podglądu."));
    }
    fn toImage(self: *State, x: i32, y: i32) PointF {
        return .{
            .x = @floatCast(@as(f64, @floatFromInt(x - self.ox)) / self.scale),
            .y = @floatCast(@as(f64, @floatFromInt(y - self.oy)) / self.scale),
        };
    }
    fn screenBox(self: *State, b: Box) c.RECT {
        return .{
            .left = self.ox + @as(i32, @intFromFloat(@round(b.x * self.scale))),
            .top = self.oy + @as(i32, @intFromFloat(@round(b.y * self.scale))),
            .right = self.ox + @as(i32, @intFromFloat(@round(b.right() * self.scale))),
            .bottom = self.oy + @as(i32, @intFromFloat(@round(b.bottom() * self.scale))),
        };
    }

    // ---- crop
    fn resetCrop(self: *State) void {
        const b = self.base();
        self.crop = fitAspect(@floatFromInt(b.width), @floatFromInt(b.height), self.aspect);
        self.syncCropFields();
        _ = c.InvalidateRect(self.canvas, null, 0);
    }
    fn syncCropFields(self: *State) void {
        const b = self.base();
        const crop = self.crop.toCrop(b.width, b.height) orelse return;
        self.syncing = true;
        defer self.syncing = false;
        _ = c.SetDlgItemInt(self.hwnd, ID.crop_x, crop.x, 0);
        _ = c.SetDlgItemInt(self.hwnd, ID.crop_y, crop.y, 0);
        _ = c.SetDlgItemInt(self.hwnd, ID.crop_w, crop.width, 0);
        _ = c.SetDlgItemInt(self.hwnd, ID.crop_h, crop.height, 0);
    }
    fn readCropFields(self: *State) ?Crop {
        var values: [4]u32 = undefined;
        for (&values, 0..) |*value, index| {
            var ok: c.BOOL = 0;
            value.* = c.GetDlgItemInt(self.hwnd, ID.crop_x + @as(i32, @intCast(index)), &ok, 0);
            if (ok == 0) return null;
        }
        const crop = Crop{ .x = values[0], .y = values[1], .width = values[2], .height = values[3] };
        const b = self.base();
        return if (validCrop(crop, b.width, b.height)) crop else null;
    }
    fn hitCrop(self: *State, x: i32, y: i32) Handle {
        const r = self.screenBox(self.crop);
        const t = 9;
        const near_l = absI(x - r.left) <= t;
        const near_r = absI(x - r.right) <= t;
        const near_t = absI(y - r.top) <= t;
        const near_b = absI(y - r.bottom) <= t;
        const in_x = x > r.left - t and x < r.right + t;
        const in_y = y > r.top - t and y < r.bottom + t;
        if (near_l and near_t) return .nw;
        if (near_r and near_t) return .ne;
        if (near_l and near_b) return .sw;
        if (near_r and near_b) return .se;
        if (near_l and in_y) return .w;
        if (near_r and in_y) return .e;
        if (near_t and in_x) return .n;
        if (near_b and in_x) return .s;
        if (x > r.left and x < r.right and y > r.top and y < r.bottom) return .move;
        return .new;
    }
    fn applyCrop(self: *State) void {
        const b = self.base();
        const crop = self.crop.toCrop(b.width, b.height) orelse {
            self.status(L("Podaj obszar mieszczący się w zdjęciu (w pikselach)."));
            return;
        };
        if (crop.x == 0 and crop.y == 0 and crop.width == b.width and crop.height == b.height) {
            self.status(L("Zaznacz mniejszy obszar — ramka obejmuje całe zdjęcie."));
            return;
        }
        var baked = self.compose(false) orelse return self.failed();
        defer baked.close();
        const next = cropped(&baked, crop) orelse return self.failed();
        if (!self.push(.{ .base = next })) {
            var copy = next;
            copy.close();
            return self.failed();
        }
        self.afterGeometry();
        self.status(L("Przycięto. Ctrl+Z cofa zmianę."));
    }
    fn reorient(self: *State, kind: i32) void {
        var next = self.compose(false) orelse return self.failed();
        if (!transform(&next, kind) or !self.push(.{ .base = next })) {
            next.close();
            return self.failed();
        }
        self.afterGeometry();
    }
    fn afterGeometry(self: *State) void {
        self.refreshView(true);
        self.resetCrop();
        self.updateButtons();
    }
    fn failed(self: *State) void {
        self.status(L("Nie udało się zastosować zmian. Obraz źródłowy jest nietknięty."));
    }

    // ---- history
    fn undo(self: *State) void {
        self.finishText(true);
        if (self.pos == 0) return;
        const was_base = self.steps.items[self.pos - 1] == .base;
        self.pos -= 1;
        if (was_base) self.afterGeometry() else _ = c.InvalidateRect(self.canvas, null, 0);
        self.updateButtons();
    }
    fn redo(self: *State) void {
        self.finishText(true);
        if (self.pos >= self.steps.items.len) return;
        const is_base = self.steps.items[self.pos] == .base;
        self.pos += 1;
        if (is_base) self.afterGeometry() else _ = c.InvalidateRect(self.canvas, null, 0);
        self.updateButtons();
    }
    fn updateButtons(self: *State) void {
        _ = c.EnableWindow(self.get(ID.undo), @intFromBool(self.pos > 0));
        _ = c.EnableWindow(self.get(ID.redo), @intFromBool(self.pos < self.steps.items.len));
    }
    fn addOp(self: *State, op: Op) void {
        const a = self.arena.allocator();
        var copy = op;
        copy.points = a.dupe(PointF, op.points) catch return self.failed();
        if (op.text.len != 0) copy.text = a.dupe(u16, op.text) catch return self.failed();
        if (!self.push(.{ .draw = copy })) return self.failed();
        self.updateButtons();
        self.status(L("Zmiany są w pamięci. Plik zmieni się dopiero po zapisaniu."));
    }

    // ---- tools
    fn opWidth(self: *State, tool: Tool) f32 {
        const t: f32 = @floatFromInt(self.thickness);
        const u = self.unit();
        return switch (tool) {
            .highlighter => t * 3 * u + 4 * u,
            .eraser => t * 3 * u + 2 * u,
            .text => (t * 3 + 12) * u,
            else => t * u,
        };
    }
    fn toolColor(self: *State) u32 {
        return if (self.tool == .highlighter) self.marker_color else self.color;
    }
    fn setTool(self: *State, tool: Tool) void {
        self.finishText(true);
        self.tool = tool;
        for (tools, 0..) |t, i| ui.state(self.get(ID.tool0 + @as(i32, @intCast(i))), t == tool, null);
        const crop = tool == .crop;
        for ([_]i32{ ID.aspect, ID.crop_x, ID.crop_y, ID.crop_w, ID.crop_h, ID.crop, ID.whole, 260, 261, 262, 263 }) |id| _ = c.ShowWindow(self.get(id), if (crop) c.SW_SHOW else c.SW_HIDE);
        for ([_]i32{ ID.palette, ID.thickness, ID.thickness_value }) |id| _ = c.ShowWindow(self.get(id), if (crop) c.SW_HIDE else c.SW_SHOW);
        if (crop) self.resetCrop();
        _ = c.InvalidateRect(self.get(ID.palette), null, 0);
        _ = c.SetDlgItemTextW(self.hwnd, ID.hint, switch (tool) {
            .crop => L("Ustaw ramkę — przyciemnione pole zostanie odcięte."),
            .pen => L("Pisak: rysuj myszą po zdjęciu. Kolor i grubość wybierz po lewej."),
            .highlighter => L("Zakreślacz: półprzezroczysty flamaster — tekst pod nim pozostaje widoczny."),
            .eraser => L("Gumka: ściera rysunki i napisy, zdjęcie pozostaje nietknięte."),
            .line => L("Linia: przeciągnij od początku do końca."),
            .arrow => L("Strzałka: przeciągnij od początku do grotu."),
            .rect => L("Prostokąt: przeciągnij po przekątnej."),
            .text => L("Tekst: kliknij miejsce na zdjęciu i pisz. Enter — gotowe, Esc — anuluj."),
        });
        self.layout();
        _ = c.InvalidateRect(self.hwnd, null, 1);
        _ = c.InvalidateRect(self.canvas, null, 0);
    }
    fn startText(self: *State, x: i32, y: i32) void {
        self.finishText(true);
        self.text_at = self.toImage(x, y);
        const px: i32 = @intFromFloat(@max(12, @round(self.opWidth(.text) * @as(f32, @floatCast(self.scale)))));
        if (self.text_font != null) _ = c.DeleteObject(self.text_font);
        self.text_font = c.CreateFontW(-px, 0, 0, 0, c.FW_BOLD, 0, 0, 0, c.DEFAULT_CHARSET, c.OUT_DEFAULT_PRECIS, c.CLIP_DEFAULT_PRECIS, c.CLEARTYPE_QUALITY, c.DEFAULT_PITCH, w.L("Arial"));
        const size = self.canvasSize();
        const width = @max(120, @min(520, size[0] - x - 4));
        self.text_edit = c.CreateWindowExW(0, w.L("EDIT"), w.L(""), c.WS_CHILD | c.WS_VISIBLE | c.WS_BORDER | c.ES_AUTOHSCROLL, x, y, width, px + 10, self.canvas, intResource(c.HMENU, ID.text_edit), c.GetModuleHandleW(null), null);
        if (self.text_edit == null) return;
        _ = c.SendMessageW(self.text_edit, c.WM_SETFONT, @intFromPtr(self.text_font), 1);
        _ = c.SetFocus(self.text_edit);
    }
    fn finishText(self: *State, commit: bool) void {
        const edit = self.text_edit orelse return;
        self.text_edit = null; // re-entrancy guard (focus loss during destroy)
        var buffer: [512]u16 = undefined;
        const n = c.GetWindowTextW(edit, &buffer, buffer.len);
        _ = c.DestroyWindow(edit);
        if (commit and n > 0) {
            const points = [_]PointF{self.text_at};
            self.addOp(.{ .tool = .text, .color = self.color, .width = self.opWidth(.text), .points = &points, .text = buffer[0..@intCast(n)] });
        }
        _ = c.InvalidateRect(self.canvas, null, 0);
    }

    // ---- result
    fn finish(self: *State, then: Then) void {
        self.finishText(true);
        self.then = then;
        if (!self.changed()) {
            self.accepted = true;
            _ = c.DestroyWindow(self.hwnd);
            return;
        }
        _ = c.SetCursor(cursor(32514));
        defer _ = c.SetCursor(cursor(32512));
        self.result = self.compose(true) orelse return self.failed();
        self.accepted = true;
        _ = c.DestroyWindow(self.hwnd);
    }
    fn cancel(self: *State) void {
        if (self.text_edit != null) return self.finishText(false);
        if (self.changed() and c.MessageBoxW(self.hwnd, L("Odrzucić zmiany wprowadzone w edytorze?"), L("Kadr — edycja zdjęcia"), c.MB_YESNO | c.MB_ICONQUESTION | c.MB_DEFBUTTON2) != c.IDYES) return;
        _ = c.DestroyWindow(self.hwnd);
    }
    fn readSliders(self: *State) void {
        self.settings.brightness = @as(i32, @intCast(c.SendDlgItemMessageW(self.hwnd, ID.brightness, c.TBM_GETPOS, 0, 0))) - 100;
        self.settings.contrast = @as(i32, @intCast(c.SendDlgItemMessageW(self.hwnd, ID.contrast, c.TBM_GETPOS, 0, 0))) - 100;
        self.settings.saturation = @as(i32, @intCast(c.SendDlgItemMessageW(self.hwnd, ID.saturation, c.TBM_GETPOS, 0, 0))) - 100;
        for ([_]i32{ self.settings.brightness, self.settings.contrast, self.settings.saturation }, 0..) |value, index| {
            _ = c.SetDlgItemInt(self.hwnd, ID.value0 + @as(i32, @intCast(index)), @bitCast(value), 1);
        }
        // Coalesce rapid slider events; full-resolution work is only done on Apply.
        _ = c.SetTimer(self.hwnd, 1, 40, null);
    }

    // ---- layout
    fn heading(self: *State, x: i32, y: i32, text: [:0]const u16) void {
        if (self.heading_count >= self.headings.len) return;
        self.headings[self.heading_count] = .{ .x = x, .y = y, .text = text };
        self.heading_count += 1;
    }
    fn place(self: *State, id: i32, x: i32, y: i32, width: i32, height: i32) void {
        const hwnd = self.get(id);
        if (hwnd == null) return;
        if (ui.font != null and c.GetWindowLongW(hwnd, c.GWL_STYLE) & c.BS_TYPEMASK == c.BS_OWNERDRAW) {
            ui.place(hwnd, x, y, width, height, false);
        } else _ = c.MoveWindow(hwnd, x, y, width, height, c.TRUE);
    }
    fn layout(self: *State) void {
        var r: c.RECT = undefined;
        _ = c.GetClientRect(self.hwnd, &r);
        const cw = r.right;
        const ch = r.bottom;
        self.heading_count = 0;
        // Left: tools and their options.
        const lx = margin;
        self.heading(lx, 12, L("Narzędzia"));
        for (tools, 0..) |_, i| self.place(ID.tool0 + @as(i32, @intCast(i)), lx, 36 + @as(i32, @intCast(i)) * 42, left_width, 38);
        const oy = 36 + 8 * 42 + 6;
        if (self.tool == .crop) {
            self.heading(lx, oy, L("Proporcje"));
            self.place(ID.aspect, lx, oy + 22, left_width, 300);
            self.heading(lx, oy + 58, L("Zaznaczenie (px)"));
            const half = @divTrunc(left_width - 8, 2);
            self.place(260, lx, oy + 80, half, 16);
            self.place(ID.crop_x, lx, oy + 96, half, 22);
            self.place(261, lx + half + 8, oy + 80, half, 16);
            self.place(ID.crop_y, lx + half + 8, oy + 96, half, 22);
            self.place(262, lx, oy + 122, half, 16);
            self.place(ID.crop_w, lx, oy + 138, half, 22);
            self.place(263, lx + half + 8, oy + 122, half, 16);
            self.place(ID.crop_h, lx + half + 8, oy + 138, half, 22);
        } else {
            self.heading(lx, oy, L("Kolor"));
            self.place(ID.palette, lx, oy + 22, left_width, 62);
            self.heading(lx, oy + 92, L("Grubość"));
            self.place(ID.thickness, lx - 4, oy + 112, left_width - 34, 30);
            self.place(ID.thickness_value, lx + left_width - 32, oy + 116, 32, 20);
        }
        // Right: image operations and colour adjustments.
        const rx = cw - margin - right_width;
        const bw = @divTrunc(right_width - 8, 2);
        self.heading(rx, 12, L("Obraz"));
        self.place(ID.undo, rx, 36, bw, 36);
        self.place(ID.redo, rx + bw + 8, 36, bw, 36);
        self.place(ID.left, rx, 78, right_width, 34);
        self.place(ID.right, rx, 114, right_width, 34);
        self.place(ID.flip_h, rx, 150, right_width, 34);
        self.place(ID.flip_v, rx, 186, right_width, 34);
        self.heading(rx, 230, L("Kolory i światło"));
        for (0..3) |i| {
            const y = 254 + @as(i32, @intCast(i)) * 52;
            self.place(250 + @as(i32, @intCast(i)), rx, y, right_width - 50, 18);
            self.place(ID.value0 + @as(i32, @intCast(i)), rx + right_width - 48, y, 48, 18);
            self.place(ID.brightness + @as(i32, @intCast(i)), rx - 4, y + 20, right_width + 8, 30);
        }
        self.place(ID.gray, rx, 410, right_width, 24);
        self.place(ID.reset, rx, 442, right_width, 36);
        // Centre: hint bar, canvas.
        const cx = lx + left_width + margin;
        const cr = rx - margin;
        const crop_buttons: i32 = if (self.tool == .crop) 250 else 0;
        self.place(ID.hint, cx, 10, @max(10, cr - cx - crop_buttons), 36);
        if (self.tool == .crop) {
            self.place(ID.whole, cr - 240, 10, 126, 36);
            self.place(ID.crop, cr - 106, 10, 106, 36);
        }
        _ = c.MoveWindow(self.canvas, cx, 54, @max(32, cr - cx), @max(32, ch - 54 - 72), c.TRUE);
        // Bottom bar.
        const by = ch - 56;
        self.place(c.IDOK, cw - margin - 136, by, 136, 40);
        self.place(ID.print, cw - margin - 136 - 8 - 120, by, 120, 40);
        self.place(ID.save, cw - margin - 136 - 8 - 120 - 8 - 140, by, 140, 40);
        self.place(c.IDCANCEL, cw - margin - 136 - 8 - 120 - 8 - 140 - 8 - 110, by, 110, 40);
        self.place(ID.status, margin, by + 2, @max(10, cw - 2 * margin - 554 - 16), 36);
    }
};

// ---------------------------------------------------------------- controls

/// MAKEINTRESOURCE / integer HMENU: encoded values, not real pointers, so
/// they need not satisfy the C header structs' alignment.
fn intResource(comptime T: type, value: usize) T {
    @setRuntimeSafety(false);
    return @ptrFromInt(value);
}
fn cursor(id: usize) c.HCURSOR {
    return c.LoadCursorW(null, intResource([*c]const u16, id));
}
fn absI(value: i32) i32 {
    return if (value < 0) -value else value;
}
fn guiFont() c.HFONT {
    return ui.font orelse @ptrCast(@alignCast(c.GetStockObject(c.DEFAULT_GUI_FONT)));
}
fn child(parent: c.HWND, class: [*:0]const u16, label: [*:0]const u16, style: u32, id: i32) c.HWND {
    const hwnd = c.CreateWindowExW(0, class, label, @as(c.DWORD, @bitCast(@as(i32, c.WS_CHILD | c.WS_VISIBLE))) | style, 0, 0, 10, 10, parent, intResource(c.HMENU, @intCast(id)), c.GetModuleHandleW(null), null);
    _ = c.SendMessageW(hwnd, c.WM_SETFONT, @intFromPtr(guiFont()), 0);
    return hwnd;
}
fn button(parent: c.HWND, label: [*:0]const u16, tip: [*:0]const u16, id: i32, icon: ui.Icon, primary: bool) c.HWND {
    if (ui.font == null) return child(parent, w.L("BUTTON"), label, @as(u32, c.WS_TABSTOP) | @as(u32, if (primary) c.BS_DEFPUSHBUTTON else 0), id);
    return ui.button(parent, label, tip, @intCast(id), icon, primary);
}
fn controls(s: *State) bool {
    const h = s.hwnd;
    s.canvas = c.CreateWindowExW(0, canvas_class, w.L(""), c.WS_CHILD | c.WS_VISIBLE | c.WS_CLIPCHILDREN, 0, 0, 10, 10, h, intResource(c.HMENU, ID.canvas), c.GetModuleHandleW(null), null);
    if (s.canvas == null) return false;
    _ = c.SetWindowLongPtrW(s.canvas, c.GWLP_USERDATA, @bitCast(@intFromPtr(s)));
    const tool_labels = [_][*:0]const u16{ L("Kadruj"), L("Pisak"), L("Zakreślacz"), L("Gumka"), L("Linia"), L("Strzałka"), L("Prostokąt"), L("Tekst") };
    const tool_tips = [_][*:0]const u16{
        L("Kadrowanie z podglądem na żywo (C)"),         L("Pisak / flamaster (P)"),
        L("Zakreślacz — półprzezroczysty (H)"),           L("Gumka — ściera rysunki (E)"),
        L("Prosta linia (L)"),                            L("Strzałka (A)"),
        L("Prostokąt (B)"),                               L("Napis na zdjęciu (T)"),
    };
    const tool_icons = [_]ui.Icon{ .crop, .edit, .highlighter, .eraser, .line, .arrow, .rect, .text };
    for (tool_labels, 0..) |label, i| {
        if (button(h, label, tool_tips[i], ID.tool0 + @as(i32, @intCast(i)), tool_icons[i], false) == null) return false;
    }
    // Tool options.
    const pal = c.CreateWindowExW(0, palette_class, w.L(""), c.WS_CHILD | c.WS_VISIBLE, 0, 0, 10, 10, h, intResource(c.HMENU, ID.palette), c.GetModuleHandleW(null), null);
    if (pal == null) return false;
    _ = c.SetWindowLongPtrW(pal, c.GWLP_USERDATA, @bitCast(@intFromPtr(s)));
    const thick = child(h, w.L("msctls_trackbar32"), w.L(""), c.WS_TABSTOP | c.TBS_NOTICKS, ID.thickness);
    _ = c.SendMessageW(thick, c.TBM_SETRANGE, 1, 1 | (20 << 16));
    _ = c.SendMessageW(thick, c.TBM_SETPOS, 1, @intCast(s.thickness));
    _ = child(h, w.L("STATIC"), w.L("4"), c.SS_RIGHT, ID.thickness_value);
    const aspect = child(h, w.L("COMBOBOX"), w.L(""), c.WS_TABSTOP | c.WS_VSCROLL | c.CBS_DROPDOWNLIST, ID.aspect);
    for ([_][*:0]const u16{ L("Dowolne"), L("Kwadrat 1:1"), L("4:3 poziomo"), L("3:4 pionowo"), L("3:2 (10×15 poziomo)"), L("2:3 (10×15 pionowo)"), L("16:9"), L("A4 pionowo"), L("A4 poziomo") }) |item| {
        _ = c.SendMessageW(aspect, c.CB_ADDSTRING, 0, @bitCast(@intFromPtr(item)));
    }
    _ = c.SendMessageW(aspect, c.CB_SETCURSEL, 0, 0);
    for ([_][*:0]const u16{ L("X:"), L("Y:"), L("Szerokość:"), L("Wysokość:") }, 0..) |label, i| {
        _ = child(h, w.L("STATIC"), label, 0, 260 + @as(i32, @intCast(i)));
        _ = child(h, w.L("EDIT"), w.L(""), c.WS_TABSTOP | c.WS_BORDER | c.ES_NUMBER | c.ES_AUTOHSCROLL, ID.crop_x + @as(i32, @intCast(i)));
    }
    if (button(h, L("Przytnij"), L("Odetnij przyciemnioną część (Enter)"), ID.crop, .check, true) == null) return false;
    if (button(h, L("Całe zdjęcie"), L("Zaznacz całe zdjęcie"), ID.whole, .fit, false) == null) return false;
    _ = child(h, w.L("STATIC"), w.L(""), c.SS_LEFT, ID.hint);
    // Image operations.
    const ops = [_]struct { label: [*:0]const u16, tip: [*:0]const u16, id: i32, icon: ui.Icon }{
        .{ .label = L("Cofnij"), .tip = L("Cofnij (Ctrl+Z)"), .id = ID.undo, .icon = .undo },
        .{ .label = L("Ponów"), .tip = L("Ponów (Ctrl+Y)"), .id = ID.redo, .icon = .redo },
        .{ .label = L("Obróć w lewo"), .tip = L("Obróć o 90° w lewo"), .id = ID.left, .icon = .rotate_left },
        .{ .label = L("Obróć w prawo"), .tip = L("Obróć o 90° w prawo"), .id = ID.right, .icon = .rotate },
        .{ .label = L("Odbij poziomo"), .tip = L("Odbicie lustrzane w poziomie"), .id = ID.flip_h, .icon = .flip_h },
        .{ .label = L("Odbij pionowo"), .tip = L("Odbicie lustrzane w pionie"), .id = ID.flip_v, .icon = .flip_v },
    };
    for (ops) |o| if (button(h, o.label, o.tip, o.id, o.icon, false) == null) return false;
    const labels = [_][*:0]const u16{ L("Jasność"), L("Kontrast"), L("Nasycenie") };
    for (labels, 0..) |label, index| {
        const i: i32 = @intCast(index);
        _ = child(h, w.L("STATIC"), label, 0, 250 + i);
        _ = child(h, w.L("STATIC"), w.L("0"), c.SS_RIGHT, ID.value0 + i);
        const slider = child(h, w.L("msctls_trackbar32"), w.L(""), c.WS_TABSTOP | c.TBS_AUTOTICKS, ID.brightness + i);
        if (slider == null) return false;
        _ = c.SendMessageW(slider, c.TBM_SETRANGE, 1, 200 << 16);
        _ = c.SendMessageW(slider, c.TBM_SETPOS, 1, 100);
        _ = c.SendMessageW(slider, c.TBM_SETTICFREQ, 100, 0);
    }
    _ = child(h, w.L("BUTTON"), L("Czarno-białe"), c.WS_TABSTOP | c.BS_AUTOCHECKBOX, ID.gray);
    if (button(h, L("Resetuj wszystko"), L("Przywróć oryginalne zdjęcie (można cofnąć)"), ID.reset, .undo, false) == null) return false;
    // Bottom bar.
    _ = child(h, w.L("STATIC"), L("Zmiany są w pamięci. Plik zmieni się dopiero po zapisaniu."), 0, ID.status);
    if (button(h, L("Anuluj"), L("Zamknij edytor bez zmian (Esc)"), c.IDCANCEL, .previous, false) == null) return false;
    if (button(h, L("Zapisz jako…"), L("Zastosuj zmiany i zapisz kopię pod nową nazwą"), ID.save, .save, false) == null) return false;
    if (button(h, L("Drukuj…"), L("Zastosuj zmiany i przejdź do podglądu wydruku"), ID.print, .printer, false) == null) return false;
    if (button(h, L("Zastosuj"), L("Zastosuj zmiany i wróć do przeglądarki"), c.IDOK, .check, true) == null) return false;
    s.setTool(.pen);
    s.updateButtons();
    return true;
}

fn stateOf(hwnd: c.HWND) ?*State {
    const address = c.GetWindowLongPtrW(hwnd, c.GWLP_USERDATA);
    return if (address == 0) null else @ptrFromInt(@as(usize, @bitCast(address)));
}
fn mouse(lp: c.LPARAM) struct { x: i32, y: i32 } {
    const bits: usize = @bitCast(lp);
    return .{ .x = @as(i16, @bitCast(@as(u16, @truncate(bits)))), .y = @as(i16, @bitCast(@as(u16, @truncate(bits >> 16)))) };
}

// ---------------------------------------------------------------- canvas

fn screenGraphics(dc: c.HDC) ?*Graphics {
    var g: ?*Graphics = null;
    if (w.GdipCreateFromHDC(dc, &g) != 0 or g == null) return null;
    _ = w.GdipSetPageUnit(g.?, 2);
    _ = GdipSetSmoothingMode(g.?, 4);
    return g;
}

fn paintCanvas(s: *State, dc: c.HDC, width: i32, height: i32) void {
    ui.fill(dc, .{ .left = 0, .top = 0, .right = width, .bottom = height }, ui.canvas_dark);
    const shown = s.shown.handle orelse return;
    const sw: i32 = @intCast(s.shown.width);
    const sh: i32 = @intCast(s.shown.height);
    ui.fill(dc, .{ .left = s.ox, .top = s.oy, .right = s.ox + sw, .bottom = s.oy + sh }, w.rgb(255, 255, 255));
    w.imageRect(dc, shown, @floatFromInt(s.ox), @floatFromInt(s.oy), @floatFromInt(sw), @floatFromInt(sh), s.shown.width, s.shown.height);
    const g = screenGraphics(dc) orelse return;
    defer _ = w.GdipDeleteGraphics(g);
    // Drawings: rendered on a transparent layer so the eraser works live.
    if (s.hasOps() or s.current != null) {
        if (s.layer == null or s.layer_w != s.shown.width or s.layer_h != s.shown.height) {
            if (s.layer) |layer| _ = w.GdipDisposeImage(layer);
            s.layer = newBitmap(s.shown.width, s.shown.height);
            s.layer_w = s.shown.width;
            s.layer_h = s.shown.height;
        }
        if (s.layer) |layer| {
            if (imageGraphics(layer)) |lg| {
                _ = GdipGraphicsClear(lg, 0);
                const k: f32 = @floatCast(s.scale);
                for (s.steps.items[s.opsStart()..s.pos]) |step| drawOp(lg, step.draw, k, 0, 0);
                if (s.current) |op| drawOp(lg, op, k, 0, 0);
                _ = w.GdipDeleteGraphics(lg);
            }
            _ = w.GdipDrawImageRectRect(g, layer, @floatFromInt(s.ox), @floatFromInt(s.oy), @floatFromInt(sw), @floatFromInt(sh), 0, 0, @floatFromInt(sw), @floatFromInt(sh), 2, null, null, null);
        }
    }
    if (s.tool != .crop) return;
    // Live crop: everything outside the frame is dimmed - what stays bright
    // is exactly the result.
    const r = s.screenBox(s.crop);
    var shade: ?*Brush = null;
    if (GdipCreateSolidFill(0xb4000000, &shade) == 0) {
        defer _ = GdipDeleteBrush(shade.?);
        const left: f32 = @floatFromInt(s.ox);
        const top: f32 = @floatFromInt(s.oy);
        const right: f32 = @floatFromInt(s.ox + sw);
        const bottom: f32 = @floatFromInt(s.oy + sh);
        const rl: f32 = @floatFromInt(r.left);
        const rt: f32 = @floatFromInt(r.top);
        const rr: f32 = @floatFromInt(r.right);
        const rb: f32 = @floatFromInt(r.bottom);
        _ = GdipFillRectangle(g, shade.?, left, top, right - left, rt - top);
        _ = GdipFillRectangle(g, shade.?, left, rb, right - left, bottom - rb);
        _ = GdipFillRectangle(g, shade.?, left, rt, rl - left, rb - rt);
        _ = GdipFillRectangle(g, shade.?, rr, rt, right - rr, rb - rt);
    }
    if (newPen(0x90ffffff, 1)) |thirds| {
        defer _ = GdipDeletePen(thirds);
        const fw: f32 = @floatFromInt(r.right - r.left);
        const fh: f32 = @floatFromInt(r.bottom - r.top);
        for ([_]f32{ 1.0 / 3.0, 2.0 / 3.0 }) |t| {
            const x = @as(f32, @floatFromInt(r.left)) + fw * t;
            const y = @as(f32, @floatFromInt(r.top)) + fh * t;
            _ = GdipDrawLine(g, thirds, x, @floatFromInt(r.top), x, @floatFromInt(r.bottom));
            _ = GdipDrawLine(g, thirds, @floatFromInt(r.left), y, @floatFromInt(r.right), y);
        }
    }
    if (newPen(0xffffffff, 2)) |frame| {
        defer _ = GdipDeletePen(frame);
        _ = GdipSetPenLineJoin(frame, 0);
        _ = GdipDrawRectangle(g, frame, @floatFromInt(r.left), @floatFromInt(r.top), @floatFromInt(r.right - r.left), @floatFromInt(r.bottom - r.top));
    }
    var handle_brush: ?*Brush = null;
    if (GdipCreateSolidFill(0xffffffff, &handle_brush) == 0) {
        defer _ = GdipDeleteBrush(handle_brush.?);
        const mx = @divTrunc(r.left + r.right, 2);
        const my = @divTrunc(r.top + r.bottom, 2);
        for ([_][2]i32{ .{ r.left, r.top }, .{ mx, r.top }, .{ r.right, r.top }, .{ r.left, my }, .{ r.right, my }, .{ r.left, r.bottom }, .{ mx, r.bottom }, .{ r.right, r.bottom } }) |p| {
            _ = GdipFillRectangle(g, handle_brush.?, @floatFromInt(p[0] - 5), @floatFromInt(p[1] - 5), 10, 10);
        }
    }
    // Result size label.
    const b = s.base();
    if (s.crop.toCrop(b.width, b.height)) |crop| {
        var ascii: [48]u8 = undefined;
        var wide: [48]u16 = undefined;
        const text = std.fmt.bufPrint(&ascii, "{d} × {d} px", .{ crop.width, crop.height }) catch return;
        const label_rect = c.RECT{ .left = r.left + 6, .top = r.top + 6, .right = r.left + 160, .bottom = r.top + 28 };
        ui.fill(dc, label_rect, theme.colors.primary);
        ui.text(dc, label_rect, w.utf16(&wide, text).ptr, guiFont(), w.rgb(255, 255, 255), c.DT_CENTER | c.DT_VCENTER | c.DT_SINGLELINE);
    }
}

fn canvasProc(hwnd: c.HWND, msg: c.UINT, wp: c.WPARAM, lp: c.LPARAM) callconv(.Stdcall) c.LRESULT {
    const s = stateOf(hwnd) orelse return c.DefWindowProcW(hwnd, msg, wp, lp);
    switch (msg) {
        c.WM_ERASEBKGND => return 1,
        c.WM_SIZE => {
            s.refreshView(true);
            return 0;
        },
        c.WM_PAINT, c.WM_PRINTCLIENT => {
            var painting = theme.Paint.begin(hwnd, msg, wp);
            defer painting.end();
            const dc = painting.dc;
            var rect: c.RECT = undefined;
            _ = c.GetClientRect(hwnd, &rect);
            const memory = c.CreateCompatibleDC(dc);
            const bitmap = if (memory != null) c.CreateCompatibleBitmap(dc, rect.right, rect.bottom) else null;
            if (memory == null or bitmap == null) {
                if (memory != null) _ = c.DeleteDC(memory);
                paintCanvas(s, dc, rect.right, rect.bottom);
                return 0;
            }
            const old = c.SelectObject(memory, bitmap);
            paintCanvas(s, memory, rect.right, rect.bottom);
            _ = c.BitBlt(dc, 0, 0, rect.right, rect.bottom, memory, 0, 0, c.SRCCOPY);
            _ = c.SelectObject(memory, old);
            _ = c.DeleteObject(bitmap);
            _ = c.DeleteDC(memory);
            return 0;
        },
        c.WM_SETCURSOR => {
            if ((lp & 0xffff) == c.HTCLIENT) {
                var p: c.POINT = undefined;
                _ = c.GetCursorPos(&p);
                _ = c.ScreenToClient(hwnd, &p);
                const shape: usize = switch (s.tool) {
                    .text => 32513,
                    .crop => switch (if (s.drag != .none) s.drag else s.hitCrop(p.x, p.y)) {
                        .move => 32646,
                        .nw, .se => 32642,
                        .ne, .sw => 32643,
                        .e, .w => 32644,
                        .n, .s => 32645,
                        else => 32515,
                    },
                    else => 32515,
                };
                _ = c.SetCursor(cursor(shape));
                return 1;
            }
        },
        c.WM_LBUTTONDOWN => {
            const m = mouse(lp);
            if (s.text_edit != null) {
                s.finishText(true);
                return 0;
            }
            _ = c.SetFocus(hwnd);
            const p = s.toImage(m.x, m.y);
            const b = s.base();
            const fw: f32 = @floatFromInt(b.width);
            const fh: f32 = @floatFromInt(b.height);
            const inside = p.x >= 0 and p.y >= 0 and p.x <= fw and p.y <= fh;
            switch (s.tool) {
                .crop => {
                    s.drag = s.hitCrop(m.x, m.y);
                    s.drag_box = s.crop;
                    s.drag_x = std.math.clamp(@as(f64, p.x), 0, @as(f64, fw));
                    s.drag_y = std.math.clamp(@as(f64, p.y), 0, @as(f64, fh));
                    if (s.drag == .new) s.drag_box = .{ .x = s.drag_x, .y = s.drag_y, .w = 0, .h = 0 };
                    _ = c.SetCapture(hwnd);
                },
                .text => if (inside) s.startText(m.x, m.y),
                else => if (inside) {
                    s.stroke.clearRetainingCapacity();
                    s.stroke.append(allocator, p) catch return 0;
                    if (s.tool == .line or s.tool == .arrow or s.tool == .rect) s.stroke.append(allocator, p) catch return 0;
                    s.current = .{ .tool = s.tool, .color = s.toolColor(), .width = s.opWidth(s.tool), .points = s.stroke.items };
                    _ = c.SetCapture(hwnd);
                    _ = c.InvalidateRect(hwnd, null, 0);
                },
            }
            return 0;
        },
        c.WM_MOUSEMOVE => {
            const m = mouse(lp);
            const p = s.toImage(m.x, m.y);
            const px: f64 = p.x;
            const py: f64 = p.y;
            const b = s.base();
            const fw: f64 = @floatFromInt(b.width);
            const fh: f64 = @floatFromInt(b.height);
            if (s.tool == .crop and s.drag != .none) {
                s.crop = if (s.drag == .move)
                    moveBox(s.drag_box, px - s.drag_x, py - s.drag_y, fw, fh)
                else
                    resizeBox(s.drag_box, s.drag, px, py, fw, fh, s.aspect);
                s.syncCropFields();
                _ = c.InvalidateRect(hwnd, null, 0);
            } else if (s.current) |*op| {
                const q = PointF{ .x = @floatCast(std.math.clamp(px, -fw, 2 * fw)), .y = @floatCast(std.math.clamp(py, -fh, 2 * fh)) };
                if (op.tool == .line or op.tool == .arrow or op.tool == .rect) {
                    s.stroke.items[1] = q;
                } else {
                    const last = s.stroke.items[s.stroke.items.len - 1];
                    const d = @fabs(last.x - q.x) + @fabs(last.y - q.y);
                    if (d * @as(f32, @floatCast(s.scale)) >= 1) s.stroke.append(allocator, q) catch {};
                }
                op.points = s.stroke.items;
                _ = c.InvalidateRect(hwnd, null, 0);
            }
            return 0;
        },
        c.WM_LBUTTONUP => {
            if (s.tool == .crop and s.drag != .none) {
                if (s.drag == .new and (s.crop.w < 2 or s.crop.h < 2)) s.resetCrop();
                s.drag = .none;
                _ = c.ReleaseCapture();
                _ = c.InvalidateRect(hwnd, null, 0);
            } else if (s.current) |op| {
                s.current = null;
                _ = c.ReleaseCapture();
                s.addOp(op);
                _ = c.InvalidateRect(hwnd, null, 0);
            }
            return 0;
        },
        c.WM_LBUTTONDBLCLK => {
            if (s.tool == .crop) s.applyCrop();
            return 0;
        },
        c.WM_CAPTURECHANGED => {
            if (s.current) |op| {
                s.current = null;
                s.addOp(op);
            }
            s.drag = .none;
            _ = c.InvalidateRect(hwnd, null, 0);
            return 0;
        },
        c.WM_COMMAND => {
            if ((wp & 0xffff) == ID.text_edit and ((wp >> 16) & 0xffff) == c.EN_KILLFOCUS)
                _ = c.PostMessageW(hwnd, c.WM_APP + 1, 0, 0);
            return 0;
        },
        c.WM_APP + 1 => {
            s.finishText(true);
            return 0;
        },
        c.WM_CTLCOLOREDIT => {
            const dc = intResource(c.HDC, wp);
            const color = s.color;
            const light = ((color >> 16) & 255) > 0xd0 and ((color >> 8) & 255) > 0xd0 and (color & 255) > 0x80;
            _ = c.SetTextColor(dc, w.rgb(@truncate(color >> 16), @truncate(color >> 8), @truncate(color)));
            _ = c.SetBkColor(dc, if (light) w.rgb(64, 64, 64) else w.rgb(255, 255, 255));
            return @bitCast(@intFromPtr(c.GetStockObject(if (light) c.DKGRAY_BRUSH else c.WHITE_BRUSH)));
        },
        else => {},
    }
    return c.DefWindowProcW(hwnd, msg, wp, lp);
}

fn paletteProc(hwnd: c.HWND, msg: c.UINT, wp: c.WPARAM, lp: c.LPARAM) callconv(.Stdcall) c.LRESULT {
    const s = stateOf(hwnd) orelse return c.DefWindowProcW(hwnd, msg, wp, lp);
    const size = 26;
    const gap = 6;
    switch (msg) {
        c.WM_ERASEBKGND => return 1,
        c.WM_PAINT, c.WM_PRINTCLIENT => {
            var painting = theme.Paint.begin(hwnd, msg, wp);
            defer painting.end();
            var rect: c.RECT = undefined;
            _ = c.GetClientRect(hwnd, &rect);
            if (rect.right <= 0 or rect.bottom <= 0) return 0;
            // Off-screen, so the swatches never flash behind the fill.
            const memory = c.CreateCompatibleDC(painting.dc);
            defer if (memory != null) {
                _ = c.DeleteDC(memory);
            };
            const bitmap = if (memory != null) c.CreateCompatibleBitmap(painting.dc, rect.right, rect.bottom) else null;
            const old = if (bitmap != null) c.SelectObject(memory, bitmap) else null;
            defer if (bitmap != null) {
                _ = c.BitBlt(painting.dc, 0, 0, rect.right, rect.bottom, memory, 0, 0, c.SRCCOPY);
                _ = c.SelectObject(memory, old);
                _ = c.DeleteObject(bitmap);
            };
            const dc = if (bitmap != null) memory else painting.dc;
            ui.fill(dc, rect, ui.shell);
            for (palette, 0..) |color, index| {
                const i: i32 = @intCast(index);
                const x = @mod(i, 5) * (size + gap) + 2;
                const y = @divTrunc(i, 5) * (size + gap) + 2;
                const selected = (color & 0xffffff) == (s.toolColor() & 0xffffff);
                if (selected) ui.rounded(dc, .{ .left = x - 2, .top = y - 2, .right = x + size + 2, .bottom = y + size + 2 }, 7, ui.accent, null);
                ui.rounded(dc, .{ .left = x, .top = y, .right = x + size, .bottom = y + size }, 6, w.rgb(@truncate(color >> 16), @truncate(color >> 8), @truncate(color)), theme.colors.swatch_border);
            }
            return 0;
        },
        c.WM_LBUTTONDOWN => {
            const m = mouse(lp);
            const col = @divTrunc(m.x - 2, size + gap);
            const row = @divTrunc(m.y - 2, size + gap);
            if (col >= 0 and col < 5 and row >= 0 and row < 2) {
                const chosen = palette[@intCast(row * 5 + col)];
                if (s.tool == .highlighter) s.marker_color = chosen else s.color = chosen;
                if (s.tool == .eraser or s.tool == .crop) s.setTool(.pen);
                _ = c.InvalidateRect(hwnd, null, 0);
                if (s.text_edit) |edit| _ = c.InvalidateRect(edit, null, 1);
            }
            return 0;
        },
        else => {},
    }
    return c.DefWindowProcW(hwnd, msg, wp, lp);
}

// ---------------------------------------------------------------- window

fn paintWindow(s: *State, msg: c.UINT, wp: c.WPARAM) void {
    var painting = theme.Paint.begin(s.hwnd, msg, wp);
    defer painting.end();
    const dc = painting.dc;
    var r: c.RECT = undefined;
    _ = c.GetClientRect(s.hwnd, &r);
    ui.fill(dc, r, ui.shell);
    for (s.headings[0..s.heading_count]) |h| {
        ui.text(dc, .{ .left = h.x, .top = h.y, .right = h.x + right_width, .bottom = h.y + 20 }, h.text.ptr, guiFont(), ui.accent, c.DT_SINGLELINE | c.DT_VCENTER);
    }
    ui.rule(dc, margin, r.bottom - 68, r.right - 2 * margin);
}

fn windowProc(hwnd: c.HWND, msg: c.UINT, wp: c.WPARAM, lp: c.LPARAM) callconv(.Stdcall) c.LRESULT {
    if (msg == c.WM_NCCREATE) {
        const cs: *const c.CREATESTRUCTW = @ptrFromInt(@as(usize, @bitCast(lp)));
        _ = c.SetWindowLongPtrW(hwnd, c.GWLP_USERDATA, @bitCast(@intFromPtr(cs.lpCreateParams)));
    }
    const s = stateOf(hwnd) orelse return c.DefWindowProcW(hwnd, msg, wp, lp);
    switch (msg) {
        c.WM_CREATE => {
            s.hwnd = hwnd;
            return if (controls(s)) 0 else -1;
        },
        c.WM_SIZE => {
            s.layout();
            _ = c.InvalidateRect(hwnd, null, 1);
            return 0;
        },
        c.WM_NCPAINT, c.WM_NCACTIVATE => {
            // Hidden frame edge sampled by DPI scaling (theme.paintFrameEdge).
            const result = c.DefWindowProcW(hwnd, msg, wp, lp);
            theme.paintFrameEdge(hwnd, theme.colors.shell);
            return result;
        },
        c.WM_GETMINMAXINFO => {
            const info: *c.MINMAXINFO = @ptrFromInt(@as(usize, @bitCast(lp)));
            info.ptMinTrackSize.x = 1000;
            info.ptMinTrackSize.y = 660;
            return 0;
        },
        c.WM_ERASEBKGND => return 1,
        c.WM_PAINT, c.WM_PRINTCLIENT => {
            paintWindow(s, msg, wp);
            return 0;
        },
        c.WM_DRAWITEM => {
            if (lp != 0) {
                const item: *const c.DRAWITEMSTRUCT = @ptrFromInt(@as(usize, @bitCast(lp)));
                if (ui.drawButton(item)) return c.TRUE;
            }
        },
        c.WM_CTLCOLORSTATIC => {
            const dc = intResource(c.HDC, wp);
            _ = c.SetBkColor(dc, ui.shell);
            const control: usize = @bitCast(lp);
            _ = c.SetTextColor(dc, if (control == @intFromPtr(s.get(ID.hint)) or control == @intFromPtr(s.get(ID.status))) ui.muted else ui.ink);
            return @bitCast(@intFromPtr(ui.background_brush orelse c.GetSysColorBrush(c.COLOR_BTNFACE)));
        },
        c.WM_CTLCOLOREDIT, c.WM_CTLCOLORLISTBOX, c.WM_CTLCOLORBTN => {
            if (theme.dialogColor(msg, wp)) |brush| return brush;
        },
        theme.changed_message => {
            _ = c.InvalidateRect(hwnd, null, c.TRUE);
            _ = c.InvalidateRect(s.canvas, null, c.FALSE);
            return 0;
        },
        c.DM_GETDEFID => return (@as(c.LRESULT, c.DC_HASDEFID) << 16) | c.IDOK,
        c.WM_HSCROLL => {
            if (lp != 0 and @as(usize, @bitCast(lp)) == @intFromPtr(s.get(ID.thickness))) {
                s.thickness = @intCast(std.math.clamp(c.SendDlgItemMessageW(hwnd, ID.thickness, c.TBM_GETPOS, 0, 0), 1, 20));
                _ = c.SetDlgItemInt(hwnd, ID.thickness_value, s.thickness, 0);
            } else s.readSliders();
            return 0;
        },
        c.WM_TIMER => {
            _ = c.KillTimer(hwnd, 1);
            s.refreshView(false);
            return 0;
        },
        c.WM_COMMAND => {
            const id: i32 = @intCast(wp & 0xffff);
            const event = (wp >> 16) & 0xffff;
            if (id >= ID.tool0 and id < ID.tool0 + tools.len) {
                s.setTool(tools[@intCast(id - ID.tool0)]);
                return 0;
            }
            switch (id) {
                c.IDCANCEL => s.cancel(),
                c.IDOK => s.finish(.none),
                ID.save => s.finish(.save),
                ID.print => s.finish(.print),
                ID.undo => s.undo(),
                ID.redo => s.redo(),
                ID.gray => {
                    s.settings.grayscale = c.IsDlgButtonChecked(hwnd, ID.gray) == c.BST_CHECKED;
                    s.refreshView(false);
                },
                ID.left => s.reorient(3),
                ID.right => s.reorient(1),
                ID.flip_h => s.reorient(4),
                ID.flip_v => s.reorient(6),
                ID.crop => s.applyCrop(),
                ID.whole => s.resetCrop(),
                ID.aspect => if (event == c.CBN_SELCHANGE) {
                    const index = c.SendDlgItemMessageW(hwnd, ID.aspect, c.CB_GETCURSEL, 0, 0);
                    if (index >= 0 and index < aspects.len) s.aspect = aspects[@intCast(index)];
                    s.resetCrop();
                },
                ID.crop_x, ID.crop_y, ID.crop_w, ID.crop_h => if (event == c.EN_CHANGE and !s.syncing) {
                    if (s.readCropFields()) |crop| {
                        s.crop = .{ .x = @floatFromInt(crop.x), .y = @floatFromInt(crop.y), .w = @floatFromInt(crop.width), .h = @floatFromInt(crop.height) };
                        _ = c.InvalidateRect(s.canvas, null, 0);
                    }
                },
                ID.reset => {
                    s.finishText(true);
                    var next = output.snapshot(s.source) orelse return 0;
                    if (!s.push(.{ .base = next })) {
                        next.close();
                        s.failed();
                        return 0;
                    }
                    s.settings = .{};
                    for ([_]i32{ ID.brightness, ID.contrast, ID.saturation }) |slider| _ = c.SendDlgItemMessageW(hwnd, slider, c.TBM_SETPOS, 1, 100);
                    _ = c.CheckDlgButton(hwnd, ID.gray, c.BST_UNCHECKED);
                    for (0..3) |i| _ = c.SetDlgItemInt(hwnd, ID.value0 + @as(i32, @intCast(i)), 0, 1);
                    s.afterGeometry();
                },
                else => {},
            }
            return 0;
        },
        c.WM_CLOSE => {
            s.cancel();
            return 0;
        },
        c.WM_DESTROY => {
            _ = c.KillTimer(hwnd, 1);
            s.done = true;
            return 0;
        },
        else => {},
    }
    return c.DefWindowProcW(hwnd, msg, wp, lp);
}

/// Editor-wide keyboard shortcuts. Returns true when the key was consumed.
fn shortcut(s: *State, msg: *const c.MSG) bool {
    if (msg.message != c.WM_KEYDOWN) return false;
    const key = msg.wParam;
    const focus = c.GetFocus();
    if (s.text_edit != null and focus == s.text_edit) {
        if (key == c.VK_RETURN or key == c.VK_ESCAPE) {
            s.finishText(key == c.VK_RETURN);
            _ = c.SetFocus(s.canvas);
            return true;
        }
        return false;
    }
    const ctrl = c.GetKeyState(c.VK_CONTROL) < 0;
    const shift = c.GetKeyState(c.VK_SHIFT) < 0;
    if (ctrl and key == 'Z') {
        if (shift) s.redo() else s.undo();
        return true;
    }
    if (ctrl and key == 'Y') {
        s.redo();
        return true;
    }
    if (key == c.VK_RETURN and s.tool == .crop) {
        s.applyCrop();
        return true;
    }
    // Single-letter tool keys only when focus is not in a text/number field.
    var class: [16]u16 = undefined;
    const n = if (focus != null) c.GetClassNameW(focus, &class, class.len) else 0;
    const in_field = (n == 4 and class[0] == 'E' and class[1] == 'd') or (n == 8 and class[0] == 'C' and class[1] == 'o');
    if (!ctrl and !in_field) {
        const tool: ?Tool = switch (key) {
            'C' => .crop, 'P' => .pen, 'H' => .highlighter, 'E' => .eraser,
            'L' => .line, 'A' => .arrow, 'B' => .rect, 'T' => .text,
            else => null,
        };
        if (tool) |t| {
            s.setTool(t);
            return true;
        }
    }
    return false;
}

pub fn show(owner: c.HWND, source: *const Image) ?Outcome {
    if (source.handle == null) return null;
    var s = State{ .source = source, .original = output.snapshot(source) orelse return null };
    defer s.deinit();
    const instance = c.GetModuleHandleW(null);
    var wc = std.mem.zeroes(c.WNDCLASSW);
    wc.lpfnWndProc = windowProc;
    wc.hInstance = instance;
    wc.hCursor = cursor(32512);
    wc.hIcon = c.LoadIconW(instance, @ptrFromInt(4));
    wc.lpszClassName = class_name;
    if (c.RegisterClassW(&wc) == 0 and c.GetLastError() != c.ERROR_CLASS_ALREADY_EXISTS) return null;
    wc.lpfnWndProc = canvasProc;
    wc.lpszClassName = canvas_class;
    wc.style = c.CS_DBLCLKS;
    wc.hIcon = null;
    if (c.RegisterClassW(&wc) == 0 and c.GetLastError() != c.ERROR_CLASS_ALREADY_EXISTS) return null;
    wc.lpfnWndProc = paletteProc;
    wc.lpszClassName = palette_class;
    wc.style = 0;
    wc.hCursor = cursor(32649); // hand
    if (c.RegisterClassW(&wc) == 0 and c.GetLastError() != c.ERROR_CLASS_ALREADY_EXISTS) return null;
    var common = c.INITCOMMONCONTROLSEX{ .dwSize = @sizeOf(c.INITCOMMONCONTROLSEX), .dwICC = c.ICC_BAR_CLASSES };
    _ = c.InitCommonControlsEx(&common);
    var work = c.RECT{ .left = 0, .top = 0, .right = 1280, .bottom = 800 };
    _ = c.SystemParametersInfoW(c.SPI_GETWORKAREA, 0, &work, 0);
    const width = @max(1000, @min(1440, @divTrunc((work.right - work.left) * 92, 100)));
    const height = @max(660, @min(940, @divTrunc((work.bottom - work.top) * 92, 100)));
    const style = c.WS_OVERLAPPEDWINDOW | c.WS_CLIPCHILDREN;
    const hwnd = c.CreateWindowExW(c.WS_EX_CONTROLPARENT, class_name, L("Kadr — edycja zdjęcia"), style, work.left + @divTrunc(work.right - work.left - width, 2), work.top + @divTrunc(work.bottom - work.top - height, 2), width, height, owner, null, instance, &s);
    if (hwnd == null) return null;
    const disable_owner = owner != null and c.IsWindowEnabled(owner) != 0;
    if (disable_owner) _ = c.EnableWindow(owner, 0);
    defer {
        if (c.IsWindow(hwnd) != 0) _ = c.DestroyWindow(hwnd);
        if (disable_owner and c.IsWindow(owner) != 0) {
            _ = c.EnableWindow(owner, 1);
            _ = c.SetActiveWindow(owner);
        }
    }
    s.layout();
    if (!s.rebuild(true)) {
        _ = c.MessageBoxW(hwnd, L("Nie udało się przygotować podglądu."), L("Kadr — edycja zdjęcia"), c.MB_OK | c.MB_ICONERROR);
        return null;
    }
    s.resetCrop();
    theme.applyWindow(hwnd);
    _ = c.ShowWindow(hwnd, c.SW_SHOW);
    _ = c.SetFocus(s.canvas);
    var message: c.MSG = undefined;
    while (!s.done) {
        const result = c.GetMessageW(&message, null, 0, 0);
        if (result <= 0) {
            if (result == 0) c.PostQuitMessage(@intCast(message.wParam));
            break;
        }
        if (shortcut(&s, &message)) continue;
        if (c.IsDialogMessageW(hwnd, &message) == 0) {
            _ = c.TranslateMessage(&message);
            _ = c.DispatchMessageW(&message);
        }
    }
    if (!s.accepted) return null;
    const image = s.result;
    s.result = null;
    return .{ .image = image, .then = s.then };
}

// ---------------------------------------------------------------- tests

test "neutral adjustments preserve straight alpha exactly" {
    try std.testing.expectEqual([4]u8{ 17, 125, 230, 31 }, adjusted(.{ 17, 125, 230, 31 }, .{}));
}
test "grayscale and zero saturation agree and preserve alpha" {
    const p = [4]u8{ 20, 100, 240, 77 };
    const gray = adjusted(p, .{ .grayscale = true });
    try std.testing.expectEqual(gray[0], gray[1]);
    try std.testing.expectEqual(gray[1], gray[2]);
    try std.testing.expectEqual(@as(u8, 77), gray[3]);
    try std.testing.expectEqual(gray, adjusted(p, .{ .saturation = -100 }));
}
test "brightness and contrast clamp safely at both extremes" {
    try std.testing.expectEqual([4]u8{ 255, 255, 255, 19 }, adjusted(.{ 0, 20, 255, 19 }, .{ .brightness = 100 }));
    try std.testing.expectEqual([4]u8{ 0, 0, 0, 19 }, adjusted(.{ 0, 20, 255, 19 }, .{ .brightness = -100 }));
    try std.testing.expectEqual([4]u8{ 128, 128, 128, 19 }, adjusted(.{ 0, 20, 255, 19 }, .{ .contrast = -100 }));
}
test "crop validation rejects empty outside and overflowing bounds" {
    try std.testing.expect(validCrop(.{ .x = 2, .y = 1, .width = 8, .height = 4 }, 10, 5));
    try std.testing.expect(!validCrop(.{ .x = 0, .y = 0, .width = 0, .height = 1 }, 10, 5));
    try std.testing.expect(!validCrop(.{ .x = 9, .y = 0, .width = 2, .height = 1 }, 10, 5));
    try std.testing.expect(!validCrop(.{ .x = 1, .y = 1, .width = std.math.maxInt(u32), .height = 1 }, 10, 5));
    try std.testing.expect(!validCrop(.{ .x = 0, .y = 0, .width = 1, .height = 1 }, 0, 0));
}
test "aspect presets give the largest centred box" {
    const sq = fitAspect(800, 500, 1);
    try std.testing.expectEqual(Box{ .x = 150, .y = 0, .w = 500, .h = 500 }, sq);
    const a4 = fitAspect(800, 500, 210.0 / 297.0);
    try std.testing.expectApproxEqAbs(@as(f64, 500), a4.h, 1e-9);
    try std.testing.expectApproxEqAbs(@as(f64, 500 * 210.0 / 297.0), a4.w, 1e-9);
    try std.testing.expectEqual(Box{ .x = 0, .y = 0, .w = 800, .h = 500 }, fitAspect(800, 500, null));
}
test "crop handles resize from the opposite anchor, stay in bounds and keep aspect" {
    const start = Box{ .x = 100, .y = 100, .w = 200, .h = 100 };
    const se = resizeBox(start, .se, 500, 260, 800, 500, null);
    try std.testing.expectEqual(Box{ .x = 100, .y = 100, .w = 400, .h = 160 }, se);
    const nw = resizeBox(start, .nw, -50, -50, 800, 500, null);
    try std.testing.expectEqual(Box{ .x = 0, .y = 0, .w = 300, .h = 200 }, nw);
    const e = resizeBox(start, .e, 2000, 999, 800, 500, null);
    try std.testing.expectEqual(Box{ .x = 100, .y = 100, .w = 700, .h = 100 }, e);
    const locked = resizeBox(start, .se, 700, 120, 800, 500, 2);
    try std.testing.expectApproxEqAbs(@as(f64, 2), locked.w / locked.h, 1e-9);
    try std.testing.expect(locked.right() <= 800 and locked.bottom() <= 500);
    const fresh = resizeBox(.{ .x = 400, .y = 300, .w = 0, .h = 0 }, .new, 100, 100, 800, 500, 1);
    try std.testing.expectApproxEqAbs(fresh.w, fresh.h, 1e-9);
    try std.testing.expectEqual(@as(f64, 400), fresh.right());
    const moved = moveBox(start, 1000, -1000, 800, 500);
    try std.testing.expectEqual(Box{ .x = 600, .y = 0, .w = 200, .h = 100 }, moved);
    try std.testing.expectEqual(Crop{ .x = 600, .y = 0, .width = 200, .height = 100 }, moved.toCrop(800, 500).?);
}

extern "gdiplus" fn GdipBitmapGetPixel(*w.GpImage, i32, i32, *u32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipBitmapSetPixel(*w.GpImage, i32, i32, u32) callconv(.Stdcall) i32;

test "pen, highlighter, shapes and text are composited; eraser removes only drawings" {
    var token: usize = 0;
    try std.testing.expectEqual(@as(i32, 0), w.GdiplusStartup(&token, &w.StartupInput{}, null));
    defer w.GdiplusShutdown(token);
    var image = Image{ .width = 200, .height = 100, .handle = newBitmap(200, 100) };
    defer image.close();
    for (0..100) |y| for (0..200) |x| {
        _ = GdipBitmapSetPixel(image.handle.?, @intCast(x), @intCast(y), 0xff808080);
    };
    const pen = [_]PointF{ .{ .x = 10, .y = 50 }, .{ .x = 190, .y = 50 } };
    const marker = [_]PointF{ .{ .x = 10, .y = 20 }, .{ .x = 190, .y = 20 } };
    const erase = [_]PointF{ .{ .x = 100, .y = 40 }, .{ .x = 100, .y = 60 } };
    const box = [_]PointF{ .{ .x = 5, .y = 70 }, .{ .x = 60, .y = 95 } };
    const label = [_]PointF{.{ .x = 120, .y = 62 }};
    const ops = [_]Op{
        .{ .tool = .pen, .color = 0xffff0000, .width = 6, .points = &pen },
        .{ .tool = .highlighter, .color = 0xffffff00, .width = 10, .points = &marker },
        .{ .tool = .eraser, .color = 0, .width = 12, .points = &erase },
        .{ .tool = .rect, .color = 0xff0000ff, .width = 3, .points = &box },
        .{ .tool = .text, .color = 0xff000000, .width = 30, .points = &label, .text = w.L("AB") },
    };
    try std.testing.expect(composeOps(&image, &ops));
    var p: u32 = 0;
    _ = GdipBitmapGetPixel(image.handle.?, 40, 50, &p);
    try std.testing.expectEqual(@as(u32, 0xffff0000), p); // pen
    _ = GdipBitmapGetPixel(image.handle.?, 100, 50, &p);
    try std.testing.expectEqual(@as(u32, 0xff808080), p); // erased stroke shows the photo
    _ = GdipBitmapGetPixel(image.handle.?, 40, 20, &p);
    try std.testing.expect(p != 0xff808080 and p != 0xffffff00); // translucent yellow over gray
    try std.testing.expect(((p >> 16) & 255) > 0x80 and (p & 255) < 0x80);
    _ = GdipBitmapGetPixel(image.handle.?, 5, 80, &p);
    try std.testing.expectEqual(@as(u32, 0xff0000ff), p); // rectangle edge
    var dark: usize = 0;
    for (120..170) |x| for (62..95) |y| {
        _ = GdipBitmapGetPixel(image.handle.?, @intCast(x), @intCast(y), &p);
        if (p & 0xffffff < 0x303030) dark += 1;
    };
    try std.testing.expect(dark > 30); // text glyphs
}
test "editor window entry point and its whole UI path compile" {
    const entry: *const fn (c.HWND, *const Image) ?Outcome = &show;
    std.mem.doNotOptimizeAway(entry);
}
