//! UI-thread-only retained raster. Start GDI+ before use; deinit before shutdown.
//! Caller invalidates before replacing/mutating the source (rotate/page/GIF).
//! Destination geometry is snapped to device pixels; checkerboard follows image.
const std = @import("std");
const w = @import("../../src/win.zig");
const c = w.c;

const max_pixels: u64 = 8_000_000;
const max_edge = 8192;
// Device-pixel geometry cap: f32 retains integer precision for origins plus
// extents (<=2^24), and all whole-image GDI StretchBlt arguments fit safely.
// Main may cap uniform zoom at max_geometry / max(source width, height).
pub const max_geometry: f32 = 8_388_608;
const light: u32 = 0xffebebeb;
const dark: u32 = 0xffd2d2d2;
const bilinear = 3;
const high_quality_bicubic = 7;
const nearest_neighbor = 5;
extern "gdiplus" fn GdipSetPixelOffsetMode(*w.GpGraphics, i32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipBitmapGetPixel(*w.GpImage, i32, i32, *u32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipGetImageType(*w.GpImage, *i32) callconv(.Stdcall) i32;
fn isBitmap(image: *w.GpImage) bool {
    var kind: i32 = 0;
    return GdipGetImageType(image, &kind) == 0 and kind == 1;
}

pub const Renderer = struct {
    // Exactly one top-down BI_RGB DIB (<=32,000,000 bytes), one memory DC.
    // No GDI+ image/graphics object or second raster is retained.
    cache_dc: c.HDC = null,
    bitmap: c.HBITMAP = null,
    previous: c.HGDIOBJ = null,
    pixels: ?[*]u32 = null,
    source: ?*w.GpImage = null,
    source_width: u32 = 0,
    source_height: u32 = 0,
    width: u32 = 0,
    height: u32 = 0,
    high_quality: bool = false,
    // Borrowed from the caller. Never disposed by this renderer; only sampled
    // during interaction. invalidate keeps it attached (e.g. caller rotates
    // both images); setPreview(null, 0, 0) detaches before caller frees it.
    preview: ?*w.GpImage = null,
    preview_width: u32 = 0,
    preview_height: u32 = 0,

    pub fn setPreview(self: *Renderer, preview: ?*w.GpImage, width: u32, height: u32) void {
        const image = if (width != 0 and height != 0) preview else null;
        const pw = if (image != null) width else 0;
        const ph = if (image != null) height else 0;
        if (self.preview == image and self.preview_width == pw and self.preview_height == ph) return;
        // A high-quality original raster is still valid. Other cached pixels
        // may have come from the prior preview, so discard them on replacement.
        if (!self.high_quality) self.invalidate();
        self.preview = image;
        self.preview_width = pw;
        self.preview_height = ph;
    }

    pub fn draw(self: *Renderer, target: c.HDC, source: *w.GpImage, iw: u32, ih: u32, x: f32, y: f32, dw: f32, dh: f32, clip: c.RECT, interactive: bool) void {
        if (target == null or iw == 0 or ih == 0) return;
        const p = Placement.init(x, y, dw, dh) orelse return;
        // GDI+ does not inherit the HDC clipping rectangle automatically.
        var bounds = clip;
        var dc_clip: c.RECT = undefined;
        const kind = c.GetClipBox(target, &dc_clip);
        if (kind == c.NULLREGION) return;
        if (kind != c.ERROR) bounds = intersect(bounds, dc_clip);
        const visible = p.visible(bounds) orelse return;
        const nearest = @max(iw, ih) <= 64 and p.width >= 4 * @as(f64, @floatFromInt(iw)) and p.height >= 4 * @as(f64, @floatFromInt(ih)) and isBitmap(source);
        // Pixel art must sample the original, not a filtered worker preview.
        const preview = if (interactive and !nearest) self.preview else null;
        const raster_source = preview orelse source;
        const raster_iw = if (preview != null) self.preview_width else iw;
        const raster_ih = if (preview != null) self.preview_height else ih;

        const fits = p.width <= max_edge and p.height <= max_edge and p.width * p.height <= max_pixels;
        // Preview attachment opts into transient zoom proxies. The cache keeps
        // its real geometry/quality; idle therefore rebuilds the original at
        // the requested geometry. No new DIB, GDI+ object or resampling of the
        // original/preview per step. Checker cells may scale until settling.
        if (fits and preview != null and self.cache_dc != null and self.source == source and self.source_width == iw and self.source_height == ih and
            (p.width != @as(f64, @floatFromInt(self.width)) or p.height != @as(f64, @floatFromInt(self.height))))
        {
            if (self.stretch(target, p, visible)) return;
        }
        if (fits) {
            const cw: u32 = @intFromFloat(p.width);
            const ch: u32 = @intFromFloat(p.height);
            if (self.source != source or self.source_width != iw or self.source_height != ih or self.width != cw or self.height != ch) {
                // Release first: replacement never doubles the raster budget.
                self.invalidate();
                if (self.create(target, cw, ch)) {
                    self.source = source;
                    self.source_width = iw;
                    self.source_height = ih;
                    // A preview-built cache is explicitly low quality, even
                    // at identical geometry: idle must redraw the original.
                    if (!self.rasterize(raster_source, raster_iw, raster_ih, !interactive and preview == null, nearest)) self.invalidate();
                }
            } else if (!interactive and !self.high_quality) {
                // Same DIB/DC: settle once, not once per idle repaint.
                if (!self.rasterize(source, iw, ih, true, nearest)) self.invalidate();
            }
            if (self.cache_dc != null) {
                const sx: i32 = @intFromFloat(@as(f64, @floatFromInt(visible.left)) - p.x);
                const sy: i32 = @intFromFloat(@as(f64, @floatFromInt(visible.top)) - p.y);
                if (c.BitBlt(target, visible.left, visible.top, visible.right - visible.left, visible.bottom - visible.top, self.cache_dc, sx, sy, c.SRCCOPY) != 0) return;
            }
        } else {
            // A large zoom must not retain an unrelated old raster either.
            self.invalidate();
        }
        direct(target, raster_source, raster_iw, raster_ih, p, visible, interactive, nearest);
    }

    pub fn invalidate(self: *Renderer) void {
        if (self.cache_dc != null and self.previous != null) _ = c.SelectObject(self.cache_dc, self.previous);
        if (self.bitmap != null) _ = c.DeleteObject(self.bitmap);
        if (self.cache_dc != null) _ = c.DeleteDC(self.cache_dc);
        self.* = .{ .preview = self.preview, .preview_width = self.preview_width, .preview_height = self.preview_height };
    }

    pub fn deinit(self: *Renderer) void {
        self.invalidate();
        self.* = .{}; // Forget, but never dispose, the borrowed preview.
    }

    fn stretch(self: *Renderer, target: c.HDC, p: Placement, visible: c.RECT) bool {
        const saved = c.SaveDC(target);
        if (saved == 0) return false;
        defer _ = c.RestoreDC(target, saved);
        if (c.IntersectClipRect(target, visible.left, visible.top, visible.right, visible.bottom) == c.ERROR or
            c.SetStretchBltMode(target, c.COLORONCOLOR) == 0) return false;
        // Whole-image mapping preserves pan phase and axes; the destination
        // clip bounds work. The geometry cap bounds all integer conversions.
        return c.StretchBlt(target, @intFromFloat(p.x), @intFromFloat(p.y), @intFromFloat(p.width), @intFromFloat(p.height), self.cache_dc, 0, 0, @intCast(self.width), @intCast(self.height), c.SRCCOPY) != 0;
    }

    fn create(self: *Renderer, target: c.HDC, width: u32, height: u32) bool {
        const dc = c.CreateCompatibleDC(target) orelse return false;
        var info = std.mem.zeroes(c.BITMAPINFO);
        info.bmiHeader.biSize = @sizeOf(c.BITMAPINFOHEADER);
        info.bmiHeader.biWidth = @intCast(width);
        info.bmiHeader.biHeight = -@as(i32, @intCast(height));
        info.bmiHeader.biPlanes = 1;
        info.bmiHeader.biBitCount = 32;
        info.bmiHeader.biCompression = c.BI_RGB;
        var bits: ?*anyopaque = null;
        const bitmap = c.CreateDIBSection(target, &info, c.DIB_RGB_COLORS, &bits, null, 0) orelse {
            _ = c.DeleteDC(dc);
            return false;
        };
        const old = c.SelectObject(dc, bitmap);
        if (old == null or @intFromPtr(old) == std.math.maxInt(usize) or bits == null) {
            _ = c.DeleteDC(dc);
            _ = c.DeleteObject(bitmap);
            return false;
        }
        self.cache_dc = dc;
        self.bitmap = bitmap;
        self.previous = old;
        self.pixels = @ptrCast(@alignCast(bits.?));
        self.width = width;
        self.height = height;
        return true;
    }

    fn rasterize(self: *Renderer, source: *w.GpImage, iw: u32, ih: u32, high_quality: bool, nearest: bool) bool {
        // Synchronize any previous GDI use before CPU writes to the DIB.
        _ = c.GdiFlush();
        const pixels = self.pixels.?;
        var yy: usize = 0;
        while (yy < self.height) : (yy += 1) {
            const row = pixels[yy * self.width ..][0..self.width];
            for (row, 0..) |*pixel, xx| pixel.* = if (((xx >> 4) ^ (yy >> 4)) & 1 == 0) light else dark;
        }
        var graphics: ?*w.GpGraphics = null;
        if (w.GdipCreateFromHDC(self.cache_dc, &graphics) != 0 or graphics == null) return false;
        defer _ = w.GdipDeleteGraphics(graphics.?);
        if (w.GdipSetPageUnit(graphics.?, 2) != 0 or
            w.GdipSetInterpolationMode(graphics.?, if (nearest) nearest_neighbor else if (high_quality) high_quality_bicubic else bilinear) != 0) return false;
        if (nearest and GdipSetPixelOffsetMode(graphics.?, 4) != 0) return false;
        if (w.GdipDrawImageRectRect(graphics.?, source, 0, 0, @floatFromInt(self.width), @floatFromInt(self.height), 0, 0, @floatFromInt(iw), @floatFromInt(ih), 2, null, null, null) != 0) return false;
        self.high_quality = high_quality or nearest; // NN original is final for pixel art.
        return true;
    }
};

const Placement = struct {
    x: f64,
    y: f64,
    width: f64,
    height: f64,

    fn init(x: f32, y: f32, width: f32, height: f32) ?Placement {
        if (!std.math.isFinite(x) or !std.math.isFinite(y) or !std.math.isFinite(width) or !std.math.isFinite(height) or width < 0.5 or height < 0.5 or
            x < -max_geometry or x > max_geometry or y < -max_geometry or y > max_geometry or width > max_geometry or height > max_geometry) return null;
        return .{ .x = @round(@as(f64, x)), .y = @round(@as(f64, y)), .width = @round(@as(f64, width)), .height = @round(@as(f64, height)) };
    }

    fn visible(self: Placement, clip: c.RECT) ?c.RECT {
        // All float->integer conversions are bounded by the caller's i32 clip.
        const left = @max(self.x, @as(f64, @floatFromInt(clip.left)));
        const top = @max(self.y, @as(f64, @floatFromInt(clip.top)));
        const right = @min(self.x + self.width, @as(f64, @floatFromInt(clip.right)));
        const bottom = @min(self.y + self.height, @as(f64, @floatFromInt(clip.bottom)));
        if (right <= left or bottom <= top or right - left > std.math.maxInt(i32) or bottom - top > std.math.maxInt(i32)) return null;
        return .{ .left = @intFromFloat(left), .top = @intFromFloat(top), .right = @intFromFloat(right), .bottom = @intFromFloat(bottom) };
    }
};

fn intersect(a: c.RECT, b: c.RECT) c.RECT {
    return .{ .left = @max(a.left, b.left), .top = @max(a.top, b.top), .right = @min(a.right, b.right), .bottom = @min(a.bottom, b.bottom) };
}

fn checker(target: c.HDC, p: Placement, visible: c.RECT, foreground: ?u32) void {
    // Stock DC_BRUSH needs no allocation. Work is bounded by visible pixels,
    // never by the offscreen image size. Restore caller's DC brush color.
    const brush: c.HBRUSH = @ptrCast(@alignCast(c.GetStockObject(c.DC_BRUSH)));
    const old_color = c.GetDCBrushColor(target);
    defer _ = c.SetDCBrushColor(target, old_color);
    const checker_light = blendColor(foreground, 235);
    const checker_dark = blendColor(foreground, 210);
    const phase_x: i32 = @intFromFloat(@mod(@as(f64, @floatFromInt(visible.left)) - p.x, 32));
    const phase_y: i32 = @intFromFloat(@mod(@as(f64, @floatFromInt(visible.top)) - p.y, 32));
    var yy = visible.top;
    var py = phase_y;
    while (yy < visible.bottom) {
        const bottom = yy + @min(16 - @mod(py, 16), visible.bottom - yy);
        var xx = visible.left;
        var px = phase_x;
        while (xx < visible.right) {
            const right = xx + @min(16 - @mod(px, 16), visible.right - xx);
            const color = if ((@divTrunc(px, 16) ^ @divTrunc(py, 16)) & 1 == 0) checker_light else checker_dark;
            _ = c.SetDCBrushColor(target, color);
            const rect = c.RECT{ .left = xx, .top = yy, .right = right, .bottom = bottom };
            _ = c.FillRect(target, &rect, brush);
            xx = right;
            px = @mod(px + 16 - @mod(px, 16), 32);
        }
        yy = bottom;
        py = @mod(py + 16 - @mod(py, 16), 32);
    }
}

fn blendColor(foreground: ?u32, gray: u32) u32 {
    const rgba = foreground orelse return w.rgb(@intCast(gray), @intCast(gray), @intCast(gray));
    const alpha = rgba >> 24;
    const background = gray * (255 - alpha) + 127;
    return w.rgb(@intCast((((rgba >> 16) & 255) * alpha + background) / 255), @intCast((((rgba >> 8) & 255) * alpha + background) / 255), @intCast(((rgba & 255) * alpha + background) / 255));
}

fn tinyDirect(target: c.HDC, source: *w.GpImage, iw: u32, ih: u32, p: Placement, visible: c.RECT) bool {
    // GDI+ quantizes very narrow fractional source rectangles to empty at
    // extreme zoom. Tiny bitmap cells avoid that path altogether: at most
    // 64x64 cells tested, only visible cells read/painted, no raster allocation.
    const brush: c.HBRUSH = @ptrCast(@alignCast(c.GetStockObject(c.DC_BRUSH)));
    const old_color = c.GetDCBrushColor(target);
    defer _ = c.SetDCBrushColor(target, old_color);
    var sy: u32 = 0;
    while (sy < ih) : (sy += 1) {
        const top = @max(@as(f64, @floatFromInt(visible.top)), @ceil(p.y + @as(f64, @floatFromInt(sy)) * p.height / @as(f64, @floatFromInt(ih)) - 0.5));
        const bottom = @min(@as(f64, @floatFromInt(visible.bottom)), @ceil(p.y + @as(f64, @floatFromInt(sy + 1)) * p.height / @as(f64, @floatFromInt(ih)) - 0.5));
        if (bottom <= top) continue;
        var sx: u32 = 0;
        while (sx < iw) : (sx += 1) {
            const left = @max(@as(f64, @floatFromInt(visible.left)), @ceil(p.x + @as(f64, @floatFromInt(sx)) * p.width / @as(f64, @floatFromInt(iw)) - 0.5));
            const right = @min(@as(f64, @floatFromInt(visible.right)), @ceil(p.x + @as(f64, @floatFromInt(sx + 1)) * p.width / @as(f64, @floatFromInt(iw)) - 0.5));
            if (right <= left) continue;
            var rgba: u32 = 0;
            if (GdipBitmapGetPixel(source, @intCast(sx), @intCast(sy), &rgba) != 0) return false;
            const cell = c.RECT{ .left = @intFromFloat(left), .top = @intFromFloat(top), .right = @intFromFloat(right), .bottom = @intFromFloat(bottom) };
            if (rgba >> 24 == 255) {
                _ = c.SetDCBrushColor(target, blendColor(rgba, 0));
                _ = c.FillRect(target, &cell, brush);
            } else {
                checker(target, p, cell, rgba);
            }
        }
    }
    return true;
}

fn direct(target: c.HDC, source: *w.GpImage, iw: u32, ih: u32, p: Placement, visible: c.RECT, interactive: bool, nearest: bool) void {
    if (nearest and tinyDirect(target, source, iw, ih, p, visible)) return;
    checker(target, p, visible, null);
    var graphics: ?*w.GpGraphics = null;
    if (w.GdipCreateFromHDC(target, &graphics) != 0 or graphics == null) return;
    defer _ = w.GdipDeleteGraphics(graphics.?);
    if (w.GdipSetPageUnit(graphics.?, 2) != 0 or
        w.GdipSetClipRect(graphics.?, @floatFromInt(visible.left), @floatFromInt(visible.top), @floatFromInt(visible.right - visible.left), @floatFromInt(visible.bottom - visible.top), 0) != 0 or
        w.GdipSetInterpolationMode(graphics.?, if (nearest) nearest_neighbor else if (interactive) bilinear else high_quality_bicubic) != 0) return;
    if (nearest and GdipSetPixelOffsetMode(graphics.?, 4) != 0) return;
    // Preserve the original scale/translation, but ask GDI+ to resample only
    // the source interval mapping to the canvas/DC dirty rectangle.
    const sx = (@as(f64, @floatFromInt(visible.left)) - p.x) / p.width * @as(f64, @floatFromInt(iw));
    const sy = (@as(f64, @floatFromInt(visible.top)) - p.y) / p.height * @as(f64, @floatFromInt(ih));
    const sw = @as(f64, @floatFromInt(visible.right - visible.left)) / p.width * @as(f64, @floatFromInt(iw));
    const sh = @as(f64, @floatFromInt(visible.bottom - visible.top)) / p.height * @as(f64, @floatFromInt(ih));
    _ = w.GdipDrawImageRectRect(graphics.?, source, @floatFromInt(visible.left), @floatFromInt(visible.top), @floatFromInt(visible.right - visible.left), @floatFromInt(visible.bottom - visible.top), @floatCast(sx), @floatCast(sy), @floatCast(sw), @floatCast(sh), 2, null, null, null);
}
