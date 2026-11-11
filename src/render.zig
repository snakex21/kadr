//! UI-thread-only retained raster. Start GDI+ before use; deinit before shutdown.
//! Caller invalidates before replacing/mutating the source (rotate/page/GIF).
//! Destination geometry is snapped to device pixels; checkerboard follows image.
const std = @import("std");
const w = @import("win.zig");
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
    // Full mode: the DIB holds the whole scaled image (width x height).
    // Region mode (scaled image much larger than the viewport): the DIB has
    // the viewport's size and holds only the visible part, so close-zoom cost
    // follows the window, not the zoom. Pans move retained pixels and render
    // only newly exposed strips; zoom gestures stretch the retained pixels.
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
    region: bool = false,
    view_width: f64 = 0,
    view_height: f64 = 0,
    // Valid region in image-relative destination pixels; DIB (0,0) = (u, v).
    region_u: i32 = 0,
    region_v: i32 = 0,
    region_w: i32 = 0,
    region_h: i32 = 0,
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
        const bounds_area = @as(f64, @floatFromInt(bounds.right - bounds.left)) * @as(f64, @floatFromInt(bounds.bottom - bounds.top));
        const use_region = !fits or p.width * p.height > 3 * bounds_area;
        const cached = self.cache_dc != null and self.source == source and self.source_width == iw and self.source_height == ih;
        if (cached and !self.region and p.width == @as(f64, @floatFromInt(self.width)) and p.height == @as(f64, @floatFromInt(self.height))) {
            // Same full raster: settle once in the same DIB/DC, then copy.
            if (!interactive and !self.high_quality and !self.rasterize(source, iw, ih, true, nearest)) self.invalidate();
            if (self.cache_dc != null and self.blit(target, p, visible)) return;
        } else if (cached and interactive and !nearest and !(self.region and p.width == self.view_width and p.height == self.view_height)) {
            // Zoom gesture: keep the retained raster and its real geometry;
            // idle rebuilds at the requested geometry. Pixel art never uses a
            // proxy: its exact cells come from the original.
            if (self.proxy(target, p, visible, raster_source, raster_iw, raster_ih)) return;
        }
        if (use_region) {
            if (self.drawRegion(target, source, iw, ih, raster_source, raster_iw, raster_ih, p, visible, bounds, interactive, nearest)) return;
        } else {
            const cw: u32 = @intFromFloat(p.width);
            const ch: u32 = @intFromFloat(p.height);
            if (self.region or self.source != source or self.source_width != iw or self.source_height != ih or self.width != cw or self.height != ch) {
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
            if (self.cache_dc != null and self.blit(target, p, visible)) return;
        }
        direct(target, raster_source, raster_iw, raster_ih, p, visible, interactive, nearest);
    }

    fn blit(self: *Renderer, target: c.HDC, p: Placement, visible: c.RECT) bool {
        const sx: i32 = @intFromFloat(@as(f64, @floatFromInt(visible.left)) - p.x);
        const sy: i32 = @intFromFloat(@as(f64, @floatFromInt(visible.top)) - p.y);
        return c.BitBlt(target, visible.left, visible.top, visible.right - visible.left, visible.bottom - visible.top, self.cache_dc, sx, sy, c.SRCCOPY) != 0;
    }

    /// Transient zoom frame from retained pixels: no new DIB and no full
    /// resampling. Parts the retained region does not cover are drawn directly
    /// (cost bounded by that uncovered area).
    fn proxy(self: *Renderer, target: c.HDC, p: Placement, visible: c.RECT, raster: *w.GpImage, riw: u32, rih: u32) bool {
        // Full mode is a region covering the whole image at its own geometry.
        const ru: i32 = if (self.region) self.region_u else 0;
        const rv: i32 = if (self.region) self.region_v else 0;
        const rw: i32 = if (self.region) self.region_w else @intCast(self.width);
        const rh: i32 = if (self.region) self.region_h else @intCast(self.height);
        const old_w = if (self.region) self.view_width else @as(f64, @floatFromInt(self.width));
        const old_h = if (self.region) self.view_height else @as(f64, @floatFromInt(self.height));
        if (rw <= 0 or rh <= 0 or old_w <= 0 or old_h <= 0) return false;
        const scale_x = p.width / old_w;
        const scale_y = p.height / old_h;
        const left = p.x + @as(f64, @floatFromInt(ru)) * scale_x;
        const top = p.y + @as(f64, @floatFromInt(rv)) * scale_y;
        const right = p.x + @as(f64, @floatFromInt(ru + rw)) * scale_x;
        const bottom = p.y + @as(f64, @floatFromInt(rv + rh)) * scale_y;
        const limit: f64 = 4 * max_geometry;
        if (@fabs(left) > limit or @fabs(top) > limit or @fabs(right) > limit or @fabs(bottom) > limit) return false;
        const cover = intersect(visible, .{ .left = @intFromFloat(@ceil(left)), .top = @intFromFloat(@ceil(top)), .right = @intFromFloat(@floor(right)), .bottom = @intFromFloat(@floor(bottom)) });
        var pieces: [4]c.RECT = undefined;
        for (subtract(visible, cover, &pieces)) |piece| direct(target, raster, riw, rih, p, piece, true, false);
        if (cover.right <= cover.left or cover.bottom <= cover.top) return true;
        // Copy only the retained pixels that map to the visible cover (whole
        // retained pixels, so the mapping stays exact); destination size is
        // bounded by the viewport, never by the zoomed image.
        const sx0 = @max(0, @floor((@as(f64, @floatFromInt(cover.left)) - left) / scale_x));
        const sy0 = @max(0, @floor((@as(f64, @floatFromInt(cover.top)) - top) / scale_y));
        const sx1 = @min(@as(f64, @floatFromInt(rw)), @ceil((@as(f64, @floatFromInt(cover.right)) - left) / scale_x));
        const sy1 = @min(@as(f64, @floatFromInt(rh)), @ceil((@as(f64, @floatFromInt(cover.bottom)) - top) / scale_y));
        if (sx1 <= sx0 or sy1 <= sy0) return true;
        const saved = c.SaveDC(target);
        if (saved == 0) return false;
        defer _ = c.RestoreDC(target, saved);
        if (c.IntersectClipRect(target, cover.left, cover.top, cover.right, cover.bottom) == c.ERROR or
            c.SetStretchBltMode(target, c.COLORONCOLOR) == 0) return false;
        const dx = @round(left + sx0 * scale_x);
        const dy = @round(top + sy0 * scale_y);
        const dw = @round(left + sx1 * scale_x) - dx;
        const dh = @round(top + sy1 * scale_y) - dy;
        return c.StretchBlt(target, @intFromFloat(dx), @intFromFloat(dy), @intFromFloat(dw), @intFromFloat(dh), self.cache_dc, @intFromFloat(sx0), @intFromFloat(sy0), @intFromFloat(sx1 - sx0), @intFromFloat(sy1 - sy0), c.SRCCOPY) != 0;
    }

    /// Viewport-sized retained raster for close zoom. Returns false only when
    /// the DIB cannot be created (caller then draws directly).
    fn drawRegion(self: *Renderer, target: c.HDC, source: *w.GpImage, iw: u32, ih: u32, raster: *w.GpImage, riw: u32, rih: u32, p: Placement, visible: c.RECT, bounds: c.RECT, interactive: bool, nearest: bool) bool {
        const bw = bounds.right - bounds.left;
        const bh = bounds.bottom - bounds.top;
        if (bw <= 0 or bh <= 0) return false;
        if (!(self.region and self.cache_dc != null and self.source == source and self.source_width == iw and self.source_height == ih and
            self.width == @as(u32, @intCast(bw)) and self.height == @as(u32, @intCast(bh))))
        {
            // Release first: replacement never doubles the raster budget.
            self.invalidate();
            if (!self.create(target, @intCast(bw), @intCast(bh))) return false;
            self.region = true;
            self.source = source;
            self.source_width = iw;
            self.source_height = ih;
        }
        if (self.view_width != p.width or self.view_height != p.height or (!interactive and !self.high_quality)) {
            self.view_width = p.width;
            self.view_height = p.height;
            self.region_w = 0;
            self.region_h = 0;
            self.high_quality = true;
        }
        const vw = visible.right - visible.left;
        const vh = visible.bottom - visible.top;
        const origin_u: i32 = @intFromFloat(@as(f64, @floatFromInt(visible.left)) - p.x);
        const origin_v: i32 = @intFromFloat(@as(f64, @floatFromInt(visible.top)) - p.y);
        const want = c.RECT{ .left = origin_u, .top = origin_v, .right = origin_u + vw, .bottom = origin_v + vh };
        const old = c.RECT{ .left = self.region_u, .top = self.region_v, .right = self.region_u + self.region_w, .bottom = self.region_v + self.region_h };
        const keep = intersect(want, old);
        // Synchronize previous GDI/GDI+ drawing before CPU pixel moves.
        _ = c.GdiFlush();
        if (keep.right > keep.left and keep.bottom > keep.top) self.move(keep.left - old.left, keep.top - old.top, keep.left - want.left, keep.top - want.top, keep.right - keep.left, keep.bottom - keep.top);
        self.region_u = origin_u;
        self.region_v = origin_v;
        self.region_w = vw;
        self.region_h = vh;
        var pieces: [4]c.RECT = undefined;
        const missing = subtract(want, keep, &pieces);
        var area: i64 = 0;
        for (missing) |piece| area += @as(i64, piece.right - piece.left) * (piece.bottom - piece.top);
        // Strips exposed by a pan are small: render them at final quality
        // from the original, so a drag needs no settle pass afterwards.
        // Without a preview the original is small (<=2 MP) and cheap to crop;
        // with one, drag strips come from the preview and idle upgrades them.
        const hq = !interactive or (raster == source and area * 4 <= @as(i64, vw) * vh);
        const place = Placement{ .x = -@as(f64, @floatFromInt(origin_u)), .y = -@as(f64, @floatFromInt(origin_v)), .width = p.width, .height = p.height };
        for (missing) |piece| {
            const rect = c.RECT{ .left = piece.left - origin_u, .top = piece.top - origin_v, .right = piece.right - origin_u, .bottom = piece.bottom - origin_v };
            if (nearest or hq) {
                direct(self.cache_dc, source, iw, ih, place, rect, false, nearest);
            } else {
                direct(self.cache_dc, raster, riw, rih, place, rect, true, false);
            }
        }
        if (!hq and !nearest and missing.len != 0) self.high_quality = false;
        return c.BitBlt(target, visible.left, visible.top, vw, vh, self.cache_dc, 0, 0, c.SRCCOPY) != 0;
    }

    /// Moves a retained w x h block inside the DIB (overlap-safe).
    fn move(self: *Renderer, sx: i32, sy: i32, dx: i32, dy: i32, width: i32, height: i32) void {
        if (sx == dx and sy == dy) return;
        const pixels = self.pixels.?;
        const stride: usize = self.width;
        const n: usize = @intCast(width);
        var row: i32 = 0;
        while (row < height) : (row += 1) {
            const r = if (dy > sy) height - 1 - row else row;
            const from = pixels[@as(usize, @intCast(sy + r)) * stride + @as(usize, @intCast(sx)) ..][0..n];
            const to = pixels[@as(usize, @intCast(dy + r)) * stride + @as(usize, @intCast(dx)) ..][0..n];
            if (dx > sx) std.mem.copyBackwards(u32, to, from) else std.mem.copyForwards(u32, to, from);
        }
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

/// outer minus inner as up to four disjoint rectangles (inner may be empty).
fn subtract(outer: c.RECT, inner_rect: c.RECT, out: *[4]c.RECT) []c.RECT {
    const inner = intersect(outer, inner_rect);
    if (outer.right <= outer.left or outer.bottom <= outer.top) return out[0..0];
    if (inner.right <= inner.left or inner.bottom <= inner.top) {
        out[0] = outer;
        return out[0..1];
    }
    var n: usize = 0;
    const parts = [4]c.RECT{
        .{ .left = outer.left, .top = outer.top, .right = outer.right, .bottom = inner.top },
        .{ .left = outer.left, .top = inner.bottom, .right = outer.right, .bottom = outer.bottom },
        .{ .left = outer.left, .top = inner.top, .right = inner.left, .bottom = inner.bottom },
        .{ .left = inner.right, .top = inner.top, .right = outer.right, .bottom = inner.bottom },
    };
    for (parts) |part| {
        if (part.right > part.left and part.bottom > part.top) {
            out[n] = part;
            n += 1;
        }
    }
    return out[0..n];
}

test "subtract covers the outer rectangle exactly once" {
    var pieces: [4]c.RECT = undefined;
    const outer = c.RECT{ .left = 0, .top = 0, .right = 10, .bottom = 8 };
    for ([_]c.RECT{ .{ .left = 3, .top = 2, .right = 6, .bottom = 5 }, .{ .left = -4, .top = -4, .right = 5, .bottom = 20 }, .{ .left = 20, .top = 20, .right = 30, .bottom = 30 }, outer }) |inner| {
        var hits = [_]u8{0} ** 80;
        for (subtract(outer, inner, &pieces)) |piece| {
            var y = piece.top;
            while (y < piece.bottom) : (y += 1) {
                var x = piece.left;
                while (x < piece.right) : (x += 1) hits[@intCast(y * 10 + x)] += 1;
            }
        }
        const clipped = intersect(outer, inner);
        for (hits, 0..) |count, i| {
            const x: i32 = @intCast(i % 10);
            const y: i32 = @intCast(i / 10);
            const inside = x >= clipped.left and x < clipped.right and y >= clipped.top and y < clipped.bottom;
            try std.testing.expectEqual(@as(u8, if (inside) 0 else 1), count);
        }
    }
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
