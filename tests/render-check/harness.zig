const std = @import("std");
const w = @import("../../src/win.zig");
const c = w.c;
const Renderer = @import("../../src/render.zig").Renderer;
extern "gdiplus" fn GdipBitmapGetPixel(*w.GpImage, i32, i32, *u32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipBitmapSetPixel(*w.GpImage, i32, i32, u32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipCreateBitmapFromScan0(i32, i32, i32, i32, ?[*]u8, *?*w.GpImage) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipGetImageGraphicsContext(*w.GpImage, *?*w.GpGraphics) callconv(.Stdcall) i32;
const MemoryCounters = extern struct {
    cb: u32 = @sizeOf(MemoryCounters), faults: u32 = 0,
    peak_working: usize = 0, working: usize = 0, peak_paged: usize = 0,
    paged: usize = 0, peak_nonpaged: usize = 0, nonpaged: usize = 0,
    pagefile: usize = 0, peak_pagefile: usize = 0, private: usize = 0,
};
extern "psapi" fn GetProcessMemoryInfo(c.HANDLE, *MemoryCounters, u32) callconv(.Stdcall) c.BOOL;
var checks: usize = 0;
var frequency: i64 = 0;
var exhausted: [12000]c.HBITMAP = undefined; // not a 48 KB stack object
const sentinel: u32 = 0xff182028;

fn log(comptime format: []const u8, args: anytype) void {
    var buffer: [1024]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, format, args) catch return;
    var written: u32 = 0;
    _ = c.WriteFile(c.GetStdHandle(c.STD_ERROR_HANDLE), text.ptr, @intCast(text.len), &written, null);
}
pub fn panic(message: []const u8, trace: ?*std.builtin.StackTrace, address: ?usize) noreturn {
    _ = trace; _ = address;
    log("panic: {s}\n", .{message});
    c.ExitProcess(2);
}
fn check(ok: bool, label: []const u8) !void {
    if (!ok) { log("FAIL: {s}\n", .{label}); return error.CheckFailed; }
    checks += 1;
}
pub fn main() void {
    run() catch |err| { log("render harness failure: {s}\n", .{@errorName(err)}); c.ExitProcess(1); };
    log("render: x86 native PASS ({d} checks)\n", .{checks});
}
fn ticks() i64 {
    var t: c.LARGE_INTEGER = undefined;
    _ = c.QueryPerformanceCounter(&t);
    return t.QuadPart;
}
fn ms(t: i64) f64 { return @as(f64, @floatFromInt(t)) * 1000 / @as(f64, @floatFromInt(frequency)); }
fn gdiCount() u32 { return c.GetGuiResources(c.GetCurrentProcess(), c.GR_GDIOBJECTS); }
fn privateBytes() usize {
    var counters = MemoryCounters{};
    if (GetProcessMemoryInfo(c.GetCurrentProcess(), &counters, @sizeOf(MemoryCounters)) == 0) return 0;
    return counters.private;
}
fn handles() u32 {
    var count: u32 = 0;
    _ = c.GetProcessHandleCount(c.GetCurrentProcess(), &count);
    return count;
}
const Surface = struct {
    dc: c.HDC,
    bitmap: c.HBITMAP,
    previous: c.HGDIOBJ,
    pixels: [*]u32,
    width: u32,
    height: u32,
    fn init(width: u32, height: u32) !Surface {
        const dc = c.CreateCompatibleDC(null) orelse return error.CreateDC;
        errdefer _ = c.DeleteDC(dc);
        var info = std.mem.zeroes(c.BITMAPINFO);
        info.bmiHeader.biSize = @sizeOf(c.BITMAPINFOHEADER);
        info.bmiHeader.biWidth = @intCast(width);
        info.bmiHeader.biHeight = -@as(i32, @intCast(height));
        info.bmiHeader.biPlanes = 1;
        info.bmiHeader.biBitCount = 32;
        var bits: ?*anyopaque = null;
        const bitmap = c.CreateDIBSection(dc, &info, c.DIB_RGB_COLORS, &bits, null, 0) orelse return error.CreateDIB;
        errdefer _ = c.DeleteObject(bitmap);
        const old = c.SelectObject(dc, bitmap);
        if (old == null or @intFromPtr(old) == std.math.maxInt(usize)) return error.SelectDIB;
        return .{ .dc = dc, .bitmap = bitmap, .previous = old, .pixels = @ptrCast(@alignCast(bits.?)), .width = width, .height = height };
    }
    fn deinit(self: *Surface) void {
        _ = c.SelectObject(self.dc, self.previous);
        _ = c.DeleteObject(self.bitmap);
        _ = c.DeleteDC(self.dc);
    }
    fn clear(self: *Surface) void {
        _ = c.GdiFlush();
        @memset(self.pixels[0 .. self.width * self.height], sentinel);
    }
    fn pixel(self: Surface, x: usize, y: usize) u32 {
        _ = c.GdiFlush();
        return self.pixels[y * self.width + x] & 0xffffff;
    }
    fn rect(self: Surface) c.RECT { return .{ .left = 0, .top = 0, .right = @intCast(self.width), .bottom = @intCast(self.height) }; }
};
fn load(path: [*:0]const u16) !*w.GpImage {
    var image: ?*w.GpImage = null;
    try check(w.GdipLoadImageFromFile(path, &image) == 0 and image != null, "load PNG fixture with native GDI+");
    return image.?;
}
fn sourcePixel(image: *w.GpImage, x: i32, y: i32) !u32 {
    var pixel: u32 = 0;
    try check(GdipBitmapGetPixel(image, x, y, &pixel) == 0, "read original source RGBA");
    return pixel;
}
fn near(a: u32, b: u32, tolerance: i32) bool {
    inline for (.{ 0, 8, 16 }) |shift| {
        const d = @as(i32, @intCast((a >> shift) & 255)) - @as(i32, @intCast((b >> shift) & 255));
        if (d < -tolerance or d > tolerance) return false;
    }
    return true;
}
fn compare(a: Surface, b: Surface, rect: c.RECT, tolerance: i32) !void {
    _ = c.GdiFlush();
    var yy = rect.top;
    var samples: usize = 0;
    var worst: i32 = 0;
    var mismatches: usize = 0;
    while (yy < rect.bottom) : (yy += 7) {
        var xx = rect.left;
        while (xx < rect.right) : (xx += 7) {
            const i: usize = @intCast(yy * @as(i32, @intCast(a.width)) + xx);
            const pa = a.pixels[i]; const pb = b.pixels[i];
            if (!near(pa, pb, tolerance)) {
                if (mismatches == 0) log("pixel mismatch ({d},{d}) cache={x} reference={x} tolerance={d}\n", .{ xx, yy, pa, pb, tolerance });
                mismatches += 1;
            }
            inline for (.{ 0, 8, 16 }) |shift| {
                const d = @as(i32, @intCast((pa >> shift) & 255)) - @as(i32, @intCast((pb >> shift) & 255));
                worst = @max(worst, if (d < 0) -d else d);
            }
            samples += 1;
        }
    }
    log("pixel reference: {d} RGB samples, max channel error {d}\n", .{ samples, worst });
    if (mismatches != 0) { log("{d} samples outside tolerance\n", .{mismatches}); return error.PixelMismatch; }
    checks += samples;
}
fn outside(surface: Surface, drawn: c.RECT) !void {
    _ = c.GdiFlush();
    for (surface.pixels[0 .. surface.width * surface.height], 0..) |pixel, i| {
        const x: i32 = @intCast(i % surface.width); const y: i32 = @intCast(i / surface.width);
        if (x < drawn.left or x >= drawn.right or y < drawn.top or y >= drawn.bottom) {
            if (pixel != sentinel) { log("outside changed ({d},{d}): {x}\n", .{ x, y, pixel }); return error.OutsideImage; }
        }
    }
    try check(true, "canvas/image exterior not erased");
}
// Independent reference: original whole-image helper + image-anchored checker.
fn reference(surface: *Surface, image: *w.GpImage, iw: u32, ih: u32, x: i32, y: i32, width: i32, height: i32, clip: c.RECT) void {
    const saved = c.SaveDC(surface.dc);
    defer _ = c.RestoreDC(surface.dc, saved);
    _ = c.IntersectClipRect(surface.dc, clip.left, clip.top, clip.right, clip.bottom);
    const brush: c.HBRUSH = @ptrCast(@alignCast(c.GetStockObject(c.DC_BRUSH)));
    var yy = @max(y, clip.top);
    const bottom = @min(y + height, clip.bottom);
    while (yy < bottom) {
        const next_y = @min(bottom, yy + 16 - @mod(yy - y, 16));
        var xx = @max(x, clip.left);
        const right = @min(x + width, clip.right);
        while (xx < right) {
            const next_x = @min(right, xx + 16 - @mod(xx - x, 16));
            const gray: u32 = if ((@divFloor(xx - x, 16) ^ @divFloor(yy - y, 16)) & 1 == 0) 235 else 210;
            _ = c.SetDCBrushColor(surface.dc, w.rgb(@intCast(gray), @intCast(gray), @intCast(gray)));
            const r = c.RECT{ .left = xx, .top = yy, .right = next_x, .bottom = next_y };
            _ = c.FillRect(surface.dc, &r, brush);
            xx = next_x;
        }
        yy = next_y;
    }
    w.imageRectClipped(surface.dc, image, @floatFromInt(x), @floatFromInt(y), @floatFromInt(width), @floatFromInt(height), iw, ih, clip);
}
fn benchmark(photo: *w.GpImage, a: *Surface, b: *Surface) !void {
    var r = Renderer{};
    defer r.deinit();
    const clip = a.rect();
    // Decode and warm the old drawing path before either timed loop.
    for (0..3) |_| w.imageRectClipped(b.dc, photo, -40, -20, 1600, 1000, 4000, 3000, clip);
    _ = c.GdiFlush();
    var start = ticks();
    r.draw(a.dc, photo, 4000, 3000, -40, -20, 1600, 1000, clip, false);
    _ = c.GdiFlush();
    const build = ticks() - start;
    try check(r.width == 1600 and r.height == 1000 and r.high_quality, "HQ cache created");
    const bitmap = r.bitmap; const dc = r.cache_dc; const pixels = r.pixels;
    const before_gdi = gdiCount(); const before_private = privateBytes();
    start = ticks();
    for (0..60) |i| {
        const x: f32 = @floatFromInt(-40 - @as(i32, @intCast(i % 61)));
        const y: f32 = @floatFromInt(-20 - @as(i32, @intCast(i % 37)));
        w.imageRectClipped(b.dc, photo, x, y, 1600, 1000, 4000, 3000, clip);
        _ = c.GdiFlush();
    }
    const old = ticks() - start;
    start = ticks();
    for (0..60) |i| {
        const x: f32 = @floatFromInt(-40 - @as(i32, @intCast(i % 61)));
        const y: f32 = @floatFromInt(-20 - @as(i32, @intCast(i % 37)));
        r.draw(a.dc, photo, 4000, 3000, x, y, 1600, 1000, clip, i % 2 == 0);
        _ = c.GdiFlush();
        try check(r.bitmap == bitmap and r.cache_dc == dc and r.pixels == pixels and r.high_quality, "pan keeps HQ bitmap/DC/storage even interactive");
    }
    const cached = ticks() - start;
    try check(gdiCount() == before_gdi, "no GDI object growth across warm cached pans");
    log("12MP -> 1600x1000, viewport 1280x800, 60 pans, GdiFlush each frame:\n", .{});
    log("  initial HQ build {d:.3} ms; baseline {d:.3} ms ({d:.3}/frame); cached {d:.3} ms ({d:.3}/frame); speedup {d:.2}x\n", .{ ms(build), ms(old), ms(old) / 60, ms(cached), ms(cached) / 60, @as(f64, @floatFromInt(old)) / @as(f64, @floatFromInt(@max(cached, 1))) });
    log("  retained raster {d} bytes; GDI {d}->{d}; private bytes {d}->{d}\n", .{ r.width * r.height * 4, before_gdi, gdiCount(), before_private, privateBytes() });
    try compare(a.*, b.*, .{ .left = 4, .top = 4, .right = 1276, .bottom = 796 }, 1);
}
fn quality(photo: *w.GpImage, a: *Surface, b: *Surface) !void {
    var r = Renderer{};
    defer r.deinit();
    const clip = a.rect();
    a.clear(); b.clear();
    var start = ticks();
    r.draw(a.dc, photo, 4000, 3000, 30, 30, 237, 149, clip, true);
    _ = c.GdiFlush();
    const interactive = ticks() - start;
    try check(r.bitmap != null and !r.high_quality, "interactive creates bilinear cache");
    const bitmap = r.bitmap; const dc = r.cache_dc;
    // Keep the low-quality result, then settle on the other destination.
    _ = c.BitBlt(b.dc, 0, 0, @intCast(a.width), @intCast(a.height), a.dc, 0, 0, c.SRCCOPY);
    start = ticks();
    r.draw(a.dc, photo, 4000, 3000, 30, 30, 237, 149, clip, false);
    _ = c.GdiFlush();
    const settle = ticks() - start;
    try check(r.high_quality and r.bitmap == bitmap and r.cache_dc == dc, "idle upgrade in same DIB/DC");
    var changed: usize = 0;
    for (32..177) |y| for (32..265) |x| { if (!near(a.pixel(x, y), b.pixel(x, y), 2)) changed += 1; };
    try check(changed > 100, "bilinear vs bicubic produces genuinely different pixels");
    b.clear();
    w.imageRectClipped(b.dc, photo, 30, 30, 237, 149, 4000, 3000, clip);
    try compare(a.*, b.*, .{ .left = 33, .top = 33, .right = 264, .bottom = 176 }, 1);
    r.draw(a.dc, photo, 4000, 3000, 31, 29, 237.4, 149.4, clip, true);
    try check(r.bitmap == bitmap and r.high_quality and r.width == 237, "rounded dimensions/HQ reused across interactive pans");
    r.draw(a.dc, photo, 4000, 3000, 31, 29, 237.5, 149.4, clip, true);
    try check(r.bitmap == bitmap and r.width == 237 and r.high_quality, "interactive size change stretches retained raster instead of rebuilding");
    r.draw(a.dc, photo, 4000, 3000, 31, 29, 237.5, 149.4, clip, false);
    try check(r.width == 238 and r.high_quality, "idle rebuilds exact rounded size at final quality");
    log("quality: interactive build {d:.3} ms; idle HQ upgrade {d:.3} ms; {d} changed interior pixels\n", .{ ms(interactive), ms(settle), changed });
}
fn alphaAndClip(alpha: *w.GpImage, a: *Surface, b: *Surface) !void {
    var r = Renderer{};
    defer r.deinit();
    const original = .{ try sourcePixel(alpha, 8, 8), try sourcePixel(alpha, 40, 8), try sourcePixel(alpha, 80, 8) };
    try check((original[1] >> 24) == 128, "source has straight 50% alpha");
    a.clear(); b.clear();
    r.draw(a.dc, alpha, 96, 64, 32, 24, 192, 128, a.rect(), false);
    reference(b, alpha, 96, 64, 32, 24, 192, 128, b.rect());
    try check(a.pixel(40, 32) == 0xebebeb and a.pixel(56, 32) == 0xd2d2d2, "fully transparent RGBA shows 16px checker");
    try check(near(a.pixel(104, 32), 0x75f575, 2), "half-alpha green composited onto opaque checker");
    try check(a.pixel(180, 32) == 0x1428e6, "opaque blue preserved");
    try compare(a.*, b.*, .{ .left = 35, .top = 27, .right = 221, .bottom = 149 }, 1);
    try outside(a.*, .{ .left = 32, .top = 24, .right = 224, .bottom = 152 });
    a.clear();
    const clip = c.RECT{ .left = 50, .top = 40, .right = 180, .bottom = 130 };
    r.draw(a.dc, alpha, 96, 64, 31, 23, 192, 128, clip, true);
    try outside(a.*, clip);
    try check(a.pixel(57, 32 + 16) == 0xebebeb, "checker moves with pan instead of canvas");
    // The original DC's rectangular dirty clip must also be honored.
    a.clear();
    const saved = c.SaveDC(a.dc);
    const dirty = c.RECT{ .left = 60, .top = 60, .right = 90, .bottom = 90 };
    _ = c.IntersectClipRect(a.dc, dirty.left, dirty.top, dirty.right, dirty.bottom);
    r.draw(a.dc, alpha, 96, 64, 32, 24, 192, 128, a.rect(), false);
    _ = c.RestoreDC(a.dc, saved);
    try outside(a.*, dirty);
    inline for (.{ 8, 40, 80 }, 0..) |x, i| try check(try sourcePixel(alpha, x, 8) == original[i], "original RGBA not modified by rendering");
    // Caller invalidates on a same-pointer frame/page/rotation mutation.
    try check(GdipBitmapSetPixel(alpha, 80, 8, 0xffff4000) == 0, "simulate caller frame mutation");
    r.invalidate();
    try check(r.bitmap == null and r.cache_dc == null and r.pixels == null and r.source == null, "invalidate releases all cache ownership");
    r.draw(a.dc, alpha, 96, 64, 0, 0, 96, 64, a.rect(), false);
    try check(a.pixel(80, 8) == 0xff4000, "invalidation observes same-pointer new frame");
    try check(GdipBitmapSetPixel(alpha, 80, 8, original[2]) == 0, "restore test source pixel");
    r.invalidate(); r.invalidate();
}
fn limitsAndFallback(photo: *w.GpImage, alpha: *w.GpImage, a: *Surface, b: *Surface) !void {
    var r = Renderer{};
    defer r.deinit();
    const clip = c.RECT{ .left = 40, .top = 35, .right = 310, .bottom = 220 };
    // Exact area/edge boundaries, including an allowed 8192-pixel edge.
    r.draw(a.dc, photo, 4000, 3000, 0, 0, 4000, 2000, clip, true);
    try check(r.region and r.width == 270 and r.height == 185, "close zoom keeps only a viewport-sized raster");
    r.draw(a.dc, photo, 4000, 3000, 0, 0, 4001, 2000, clip, true);
    try check(r.region and r.width == 270 and r.height == 185, "over 8M pixels stays viewport-sized");
    r.draw(a.dc, photo, 4000, 3000, 0, 0, 8192, 1, a.rect(), true);
    try check(r.region and r.width == 270, "interactive geometry change reuses retained raster as proxy");
    r.draw(a.dc, photo, 4000, 3000, 0, 0, 8192, 1, a.rect(), false);
    try check(!r.region and r.width == 8192 and r.height == 1, "8192 edge allowed when settled");
    r.draw(a.dc, photo, 4000, 3000, 0, 0, 8193, 1, a.rect(), false);
    try check(r.region and r.width == 1280 and r.height == 800, "8193 edge never allocates a full-image raster");
    // Compare clipped-source fallback to the original full-image transform.
    a.clear(); b.clear();
    r.draw(a.dc, photo, 4000, 3000, -200, -150, 4001, 2000, clip, false);
    reference(b, photo, 4000, 3000, -200, -150, 4001, 2000, clip);
    try compare(a.*, b.*, .{ .left = 43, .top = 38, .right = 307, .bottom = 217 }, 2);
    try outside(a.*, clip);
    a.clear(); b.clear();
    r.draw(a.dc, alpha, 96, 64, -3000, -20, 9000, 500, clip, false);
    reference(b, alpha, 96, 64, -3000, -20, 9000, 500, clip);
    try compare(a.*, b.*, .{ .left = 43, .top = 38, .right = 307, .bottom = 217 }, 2);
    try outside(a.*, clip);
    // Independently check the oversized interactive path's bilinear mode.
    a.clear(); b.clear();
    r.draw(a.dc, photo, 4000, 3000, -200, -150, 4001, 2000, clip, true);
    var graphics: ?*w.GpGraphics = null;
    try check(w.GdipCreateFromHDC(b.dc, &graphics) == 0, "create bilinear reference graphics");
    _ = w.GdipSetPageUnit(graphics.?, 2);
    _ = w.GdipSetClipRect(graphics.?, 40, 35, 270, 185, 0);
    _ = w.GdipSetInterpolationMode(graphics.?, 3);
    try check(w.GdipDrawImageRectRect(graphics.?, photo, -200, -150, 4001, 2000, 0, 0, 4000, 3000, 2, null, null, null) == 0, "full-transform bilinear reference");
    _ = w.GdipDeleteGraphics(graphics.?);
    // GDI+ bilinear's fractional crop changes fixed-point sampling phase near
    // sharp lines. Host maximum is 12/255; allow 16 for this interactive path
    // only. Idle bicubic above remains constrained to 2 (observed 1).
    try compare(a.*, b.*, .{ .left = 43, .top = 38, .right = 307, .bottom = 217 }, 16);
    try outside(a.*, clip);
    a.clear();
    const saved = c.SaveDC(a.dc);
    const dirty = c.RECT{ .left = 60, .top = 60, .right = 90, .bottom = 90 };
    _ = c.IntersectClipRect(a.dc, dirty.left, dirty.top, dirty.right, dirty.bottom);
    r.draw(a.dc, alpha, 96, 64, -3000, -20, 9000, 500, clip, false);
    _ = c.RestoreDC(a.dc, saved);
    try outside(a.*, dirty);
    // 30 billion destination pixels must still be bounded by the tiny clip.
    r.invalidate(); // Fresh render, not a transient proxy of the dirty-clip raster.
    a.clear();
    const start = ticks();
    r.draw(a.dc, alpha, 96, 64, -140000, -50000, 200000, 150000, clip, true);
    _ = c.GdiFlush();
    try check(r.region and r.width == 270 and near(a.pixel(100, 100), 0x1428e6, 1), "huge interactive zoom renders visible opaque source crop into viewport raster");
    try outside(a.*, clip);
    log("fallback: 200000x150000 (30G pixels), visible 270x185: {d:.3} ms; retained raster 0 bytes\n", .{ms(ticks() - start)});
    // Invalid/offscreen inputs neither allocate nor touch the viewport.
    r.invalidate();
    a.clear();
    r.draw(a.dc, alpha, 0, 64, 0, 0, 100, 100, a.rect(), false);
    r.draw(a.dc, alpha, 96, 64, 0, 0, std.math.nan(f32), 100, a.rect(), false);
    r.draw(a.dc, alpha, 96, 64, std.math.inf(f32), 0, 100, 100, a.rect(), false);
    r.draw(a.dc, alpha, 96, 64, 0, 0, 0, 100, a.rect(), false);
    r.draw(a.dc, alpha, 96, 64, 10000, 10000, 100, 100, a.rect(), false);
    try outside(a.*, .{ .left = 0, .top = 0, .right = 0, .bottom = 0 });
    try check(r.bitmap == null, "invalid/offscreen geometry did not allocate");
    r.draw(a.dc, alpha, 96, 64, -17, -11, 96, 64, a.rect(), false);
    try check(r.width == 96 and r.source_width == 96, "new image key after fallback");
    // Real dimension change on the same GDI+ source, as with rotation.
    r.invalidate();
    try check(w.GdipImageRotateFlip(alpha, 1) == 0, "rotate source as caller would");
    r.draw(a.dc, alpha, 64, 96, 0, 0, 64, 96, a.rect(), false);
    try check(r.width == 64 and r.height == 96 and r.source_width == 64 and r.source_height == 96, "rotation source dimensions key");
    r.invalidate();
    try check(w.GdipImageRotateFlip(alpha, 3) == 0, "restore test source rotation");
}
fn lifecycle(photo: *w.GpImage, alpha: *w.GpImage, a: *Surface) !void {
    // Warm both source paths before measuring repeated lifecycle stability.
    var r = Renderer{};
    for (0..4) |_| {
        r.draw(a.dc, photo, 4000, 3000, 0, 0, 320, 200, a.rect(), true);
        r.draw(a.dc, alpha, 96, 64, 0, 0, 96, 64, a.rect(), false);
        r.deinit();
    }
    _ = c.GdiFlush();
    const gdi = gdiCount(); const native_handles = handles(); const memory = privateBytes();
    for (0..100) |i| {
        r.draw(a.dc, photo, 4000, 3000, 0, 0, 320, 200, a.rect(), true);
        r.draw(a.dc, photo, 4000, 3000, -10, -10, 320, 200, a.rect(), false);
        try check(r.high_quality and r.width == 320, "settle during lifecycle");
        r.draw(a.dc, alpha, 96, 64, 0, 0, 96, 64, a.rect(), i % 2 == 0);
        try check(r.source == alpha and r.source_width == 96 and r.width == 96, "source/dimensions key replacement");
        r.invalidate(); r.deinit(); r.deinit();
    }
    _ = c.GdiFlush();
    const after_memory = privateBytes();
    log("100 replacement/settle/invalidate/deinit cycles: GDI {d}->{d}; native handles {d}->{d}; private bytes {d}->{d}\n", .{ gdi, gdiCount(), native_handles, handles(), memory, after_memory });
    try check(gdiCount() == gdi, "GDI handle stability after 100 lifecycle cycles");
    try check(handles() == native_handles, "native handle stability after 100 lifecycle cycles");
    try check(after_memory <= memory + 8 * 1024 * 1024, "bounded process memory after warm lifecycle cycles");
}
fn creationFailure(alpha: *w.GpImage, a: *Surface) !void {
    // Real per-process GDI quota exhaustion, no production test hooks. Leave
    // one slot: CreateCompatibleDC can succeed, but CreateDIBSection cannot.
    var n: usize = 0;
    defer { for (exhausted[0..n]) |bitmap| _ = c.DeleteObject(bitmap); }
    const before = gdiCount();
    while (n < exhausted.len) {
        exhausted[n] = c.CreateBitmap(1, 1, 1, 1, null);
        if (exhausted[n] == null) break;
        n += 1;
    }
    try check(n > 100 and n < exhausted.len, "reached real per-process GDI allocation failure");
    n -= 1;
    _ = c.DeleteObject(exhausted[n]);
    a.clear();
    var r = Renderer{};
    defer r.deinit();
    r.draw(a.dc, alpha, 96, 64, 0, 0, 96, 64, a.rect(), false);
    try check(r.bitmap == null and r.cache_dc == null, "resource-creation failure leaves no partial cache");
    try check(near(a.pixel(80, 8), 0x1428e6, 1), "direct fallback still draws after real cache allocation failure");
    for (exhausted[0..n]) |bitmap| _ = c.DeleteObject(bitmap);
    n = 0;
    try check(gdiCount() == before, "failed cache creation and quota test leak no GDI resources");
    log("real GDI quota exhaustion: cache creation failed safely, direct pixels passed, GDI restored to {d}\n", .{before});
}
// Native 32-bit ARGB preview, prepared outside interactive timing as the
// loader worker would. No PNG decoding or Python drawing in the timed path.
fn makePreview(source: *w.GpImage) !*w.GpImage {
    var image: ?*w.GpImage = null;
    try check(GdipCreateBitmapFromScan0(1600, 1200, 0, 0x26200a, null, &image) == 0 and image != null, "native ARGB preview bitmap");
    errdefer _ = w.GdipDisposeImage(image.?);
    var graphics: ?*w.GpGraphics = null;
    try check(GdipGetImageGraphicsContext(image.?, &graphics) == 0, "native preview graphics");
    defer _ = w.GdipDeleteGraphics(graphics.?);
    _ = w.GdipSetPageUnit(graphics.?, 2);
    _ = w.GdipSetInterpolationMode(graphics.?, 7);
    try check(w.GdipDrawImageRectRect(graphics.?, source, 0, 0, 1600, 1200, 0, 0, 4000, 3000, 2, null, null, null) == 0, "prepare native 1600-long-edge preview from 12MP original");
    return image.?;
}
fn tinyImage(width: u32, height: u32, colors: []const u32) !*w.GpImage {
    var image: ?*w.GpImage = null;
    try check(GdipCreateBitmapFromScan0(@intCast(width), @intCast(height), 0, 0x26200a, null, &image) == 0 and image != null, "native tiny ARGB bitmap");
    errdefer _ = w.GdipDisposeImage(image.?);
    for (colors, 0..) |color, i| try check(GdipBitmapSetPixel(image.?, @intCast(i % width), @intCast(i / width), color) == 0, "tiny fixture source pixel");
    return image.?;
}
fn blocks(surface: Surface, colors: []const u32, iw: u32, ih: u32, scale: u32, x: i32, y: i32, clip: c.RECT) !void {
    _ = c.GdiFlush();
    const rect = c.RECT{ .left = @max(x, clip.left), .top = @max(y, clip.top), .right = @min(x + @as(i32, @intCast(iw * scale)), clip.right), .bottom = @min(y + @as(i32, @intCast(ih * scale)), clip.bottom) };
    var yy = rect.top;
    while (yy < rect.bottom) : (yy += 1) {
        var xx = rect.left;
        while (xx < rect.right) : (xx += 1) {
            const sx: usize = @intCast(@divFloor(xx - x, @as(i32, @intCast(scale))));
            const sy: usize = @intCast(@divFloor(yy - y, @as(i32, @intCast(scale))));
            const expected = colors[sy * iw + sx] & 0xffffff;
            const actual = surface.pixels[@as(usize, @intCast(yy)) * surface.width + @as(usize, @intCast(xx))] & 0xffffff;
            if (actual != expected) {
                log("tiny {d}x{d} scale {d} at ({d},{d}), source ({d},{d}): expected {x}, got {x}\n", .{ iw, ih, scale, xx, yy, sx, sy, expected, actual });
                return error.TinyPixelMismatch;
            }
        }
    }
    try check(true, "tiny nearest blocks exactly match original, including edge pixels");
    try outside(surface, rect);
}
fn tinyChecks(alpha: *w.GpImage) !void {
    var surface = try Surface.init(320, 240); defer surface.deinit();
    const clip = c.RECT{ .left = 3, .top = 5, .right = 285, .bottom = 205 };
    const start = ticks();
    var sample_colors: [64]u32 = undefined;
    for ([_][2]u32{ .{ 1, 1 }, .{ 2, 3 }, .{ 8, 8 } }) |dimensions| {
        const iw = dimensions[0]; const ih = dimensions[1];
        for (sample_colors[0 .. iw * ih], 0..) |*color, i| {
            const x: u32 = @intCast(i % iw); const y: u32 = @intCast(i / iw);
            color.* = 0xff000000 | ((x * 29 + 11) << 16) | ((y * 31 + 17) << 8) | (x * 13 + y * 7 + 37);
        }
        const colors = sample_colors[0 .. iw * ih];
        const image = try tinyImage(iw, ih, colors); defer _ = w.GdipDisposeImage(image);
        var r = Renderer{}; defer r.deinit();
        r.setPreview(alpha, 96, 64); // Must not blur tiny originals through preview/proxy.
        for ([_]u32{ 4, 32, 600 }) |scale| {
            const width = iw * scale; const height = ih * scale;
            const positions = [_][2]i32{ .{ 13, 17 }, .{ 31 - @as(i32, @intCast(width)), 37 - @as(i32, @intCast(height)) } };
            for (positions) |position| for ([_]bool{ true, false }) |interactive| {
                surface.clear();
                r.draw(surface.dc, image, iw, ih, @floatFromInt(position[0]), @floatFromInt(position[1]), @floatFromInt(width), @floatFromInt(height), clip, interactive);
                try blocks(surface, colors, iw, ih, scale, position[0], position[1], clip);
                if (r.region) {
                    try check(r.width == 282 and r.height == 200 and r.high_quality, "tiny close zoom keeps exact NN cells in a viewport raster");
                } else if (@as(u64, width) * height <= 8_000_000) try check(r.width == width and r.height == height and r.high_quality, "tiny original NN is final quality, never a geometry proxy");
            };
        }
        // At 60000%, pan every source pixel through the visible canvas. For
        // 8x8 this is direct fractional source cropping (23.04M destination).
        for (colors, 0..) |_, i| {
            const x = 60 - @as(i32, @intCast(i % iw)) * 600 - 300;
            const y = 50 - @as(i32, @intCast(i / iw)) * 600 - 300;
            surface.clear();
            r.draw(surface.dc, image, iw, ih, @floatFromInt(x), @floatFromInt(y), @floatFromInt(iw * 600), @floatFromInt(ih * 600), clip, true);
            try blocks(surface, colors, iw, ih, 600, x, y, clip);
        }
        if (iw == 8) {
            try check(r.region and r.width == 282 and r.height == 200, "60000% 8x8 uses a viewport raster, never a giant bitmap");
            const gdi = gdiCount();
            var total: i64 = 0; var slowest: i64 = 0;
            for (0..60) |i| {
                const x: f32 = @floatFromInt(-1187 - @as(i32, @intCast(i % 64)));
                const t = ticks();
                r.draw(surface.dc, image, iw, ih, x, -1783, 4800, 4800, clip, true);
                _ = c.GdiFlush();
                const elapsed = ticks() - t;
                total += elapsed; slowest = @max(slowest, elapsed);
            }
            try check(r.region and r.width == 282 and gdiCount() == gdi, "60000% tiny pans keep one viewport raster and stable GDI count");
            log("tiny 8x8 at 60000%, 60 cropped pans: {d:.3} ms/frame, max {d:.3}; raster 0 bytes; GDI {d}->{d}\n", .{ ms(total) / 60, ms(slowest), gdi, gdiCount() });
        }
        try check(try sourcePixel(image, 0, 0) == colors[0] and try sourcePixel(image, @intCast(iw - 1), @intCast(ih - 1)) == colors[colors.len - 1], "tiny source RGBA unchanged");
    }
    const one = try tinyImage(1, 1, &.{0xffe33971}); defer _ = w.GdipDisposeImage(one);
    var r = Renderer{}; defer r.deinit();
    surface.clear();
    const limit = @import("../../src/render.zig").max_geometry;
    r.draw(surface.dc, one, 1, 1, -limit / 2, -limit / 2, limit, limit, clip, true);
    try check(surface.pixel(20, 20) == 0xe33971 and r.width == 282, "geometry cap supports huge clipped nearest source without empty/black output");
    try outside(surface, clip);
    surface.clear();
    r.draw(surface.dc, one, 1, 1, 0, 0, limit + 1, limit, clip, true);
    r.draw(surface.dc, one, 1, 1, limit + 1, 0, 10, 10, clip, true);
    try outside(surface, .{ .left = 0, .top = 0, .right = 0, .bottom = 0 });
    try check(r.width <= 282, "outside documented geometry cap is a safe no-op");
    const translucent = try tinyImage(1, 1, &.{0x8000ff00}); defer _ = w.GdipDisposeImage(translucent);
    surface.clear();
    r.draw(surface.dc, translucent, 1, 1, 13, 17, 600, 600, clip, false);
    try check(near(surface.pixel(21, 25), 0x75f575, 2) and near(surface.pixel(37, 25), 0x69e969, 2), "tiny nearest keeps alpha appearance and 16px checker");
    r.invalidate();
    surface.clear();
    r.draw(surface.dc, translucent, 1, 1, -limit / 2, -limit / 2, limit, limit, clip, false);
    try check(r.width == 282 and near(surface.pixel(20, 20), 0x75f575, 2) and near(surface.pixel(36, 20), 0x69e969, 2), "extreme tiny direct cells retain alpha/checker without fractional-crop emptiness");
    try check(try sourcePixel(translucent, 0, 0) == 0x8000ff00, "tiny direct alpha source stays unchanged");
    log("tiny pixel art: 1x1 / 2x3 / 8x8, 4x/32x/600x, all source cells/cropped edges exact; {d:.3} ms including checks; geometry cap {d}\n", .{ ms(ticks() - start), @as(u32, @intFromFloat(limit)) });
}
fn proxyChecks(alpha: *w.GpImage, a: *Surface) !void {
    var r = Renderer{}; defer r.deinit();
    r.setPreview(alpha, 96, 64);
    r.draw(a.dc, alpha, 96, 64, 32, 24, 192, 128, a.rect(), false);
    const bitmap = r.bitmap; const dc = r.cache_dc;
    const mode = c.SetStretchBltMode(a.dc, c.HALFTONE);
    defer _ = c.SetStretchBltMode(a.dc, mode);
    a.clear();
    const clip = c.RECT{ .left = 40, .top = 35, .right = 310, .bottom = 220 };
    r.draw(a.dc, alpha, 96, 64, 32, 24, 384, 256, clip, true);
    try check(r.bitmap == bitmap and r.cache_dc == dc and r.width == 192 and r.high_quality, "original HQ raster reused as proxy with real cache geometry intact");
    try check(c.GetStretchBltMode(a.dc) == c.HALFTONE, "proxy restores caller DC stretching state");
    try outside(a.*, clip);
    try check(a.pixel(56, 36) == 0xebebeb, "checker may transiently scale with proxy");
    a.clear();
    r.draw(a.dc, alpha, 96, 64, 32, 24, 384, 256, clip, false);
    try check(r.width == 384 and r.height == 256 and r.high_quality and a.pixel(56, 36) == 0xd2d2d2, "idle restores destination geometry and 16px checker");
    try outside(a.*, clip);
    // Oversized geometry retains the original visible-crop fallback instead
    // of attempting an enormous whole-image GDI stretch.
    a.clear();
    const t = ticks();
    r.draw(a.dc, alpha, 96, 64, -140000, -50000, 200000, 150000, clip, true);
    _ = c.GdiFlush();
    try check((!r.region and r.width == 384 and r.height == 256) or (r.region and r.width == 270), "oversized transient zoom reuses the settled bounded raster, never a giant allocation");
    try check(r.width * r.height <= 384 * 256 and near(a.pixel(100, 100), 0x1428e6, 1), "oversized transient zoom draws visible opaque pixels, not black output");
    try outside(a.*, clip);
    log("oversized transient crop 200000x150000, visible 270x185: {d:.3} ms including checks; raster {d} bytes\n", .{ms(ticks() - t), r.width * r.height * 4});
    r.draw(a.dc, alpha, 96, 64, -140000, -50000, 200000, 150000, clip, false);
    try check(r.region and r.width == 270 and r.high_quality, "idle oversized geometry settles from the original in the viewport raster");
}
fn previewChecks(photo: *w.GpImage, alpha: *w.GpImage, a: *Surface, b: *Surface) !void {
    const build_start = ticks();
    const preview = try makePreview(photo);
    defer _ = w.GdipDisposeImage(preview); // Only caller owns/disposes it.
    const build_time = ticks() - build_start;
    const original = try sourcePixel(photo, 200, 200);
    const preview_pixel = try sourcePixel(preview, 200, 200);
    var r = Renderer{}; defer r.deinit();
    var ref = Renderer{}; defer ref.deinit();
    const clip = a.rect();
    r.setPreview(preview, 1600, 1200);
    a.clear(); b.clear();
    r.draw(a.dc, photo, 4000, 3000, 30, 30, 237, 149, clip, true);
    ref.draw(b.dc, preview, 1600, 1200, 30, 30, 237, 149, clip, true);
    try check(!r.high_quality and r.source == photo and r.source_width == 4000 and r.source_height == 3000, "preview pixels use original identity/dimension key and stay low quality");
    try compare(a.*, b.*, .{ .left = 33, .top = 33, .right = 264, .bottom = 176 }, 0);
    const bitmap = r.bitmap;
    r.setPreview(preview, 1600, 1200);
    try check(r.bitmap == bitmap, "same borrowed preview does not discard cache");
    // Idle at the exact same geometry must still use original HQ, in place.
    r.draw(a.dc, photo, 4000, 3000, 30, 30, 237, 149, clip, false);
    b.clear();
    w.imageRectClipped(b.dc, photo, 30, 30, 237, 149, 4000, 3000, clip);
    try check(r.bitmap == bitmap and r.high_quality, "preview-built raster upgrades from original in same DIB");
    try compare(a.*, b.*, .{ .left = 33, .top = 33, .right = 264, .bottom = 176 }, 1);
    r.draw(a.dc, photo, 4000, 3000, 31, 29, 237, 149, clip, true);
    r.setPreview(null, 0, 0);
    try check(r.bitmap == bitmap and r.high_quality and r.preview == null, "detaching preview preserves valid original HQ cache");
    r.setPreview(preview, 1600, 1200);
    r.invalidate();
    try check(r.preview == preview and r.preview_width == 1600 and r.bitmap == null, "invalidate keeps borrowed preview attached");
    // A deliberately distinct RGBA preview proves its own dimensions are
    // used for the source rectangle, not the original's 4000x3000 dimensions.
    r.draw(a.dc, photo, 4000, 3000, 0, 0, 320, 200, clip, true);
    r.setPreview(alpha, 96, 64);
    try check(r.bitmap == null, "replacing preview discards low-quality pixels");
    a.clear();
    r.draw(a.dc, photo, 4000, 3000, 32, 24, 192, 128, clip, true);
    try check(a.pixel(40, 32) == 0xebebeb and near(a.pixel(104, 32), 0x75f575, 2) and a.pixel(180, 32) == 0x1428e6, "borrowed preview source dimensions and alpha/checker appearance");
    try outside(a.*, .{ .left = 32, .top = 24, .right = 224, .bottom = 152 });
    a.clear(); b.clear();
    const small_clip = c.RECT{ .left = 40, .top = 35, .right = 310, .bottom = 220 };
    r.invalidate(); // Exercise direct crop, not the new retained zoom proxy.
    r.draw(a.dc, photo, 4000, 3000, -3000, -20, 9000, 500, small_clip, true);
    ref.draw(b.dc, alpha, 96, 64, -3000, -20, 9000, 500, small_clip, true);
    try check(r.region and r.width == 270 and r.preview == alpha, "oversized zoom keeps preview and only a viewport-sized cache");
    try compare(a.*, b.*, .{ .left = 43, .top = 38, .right = 307, .bottom = 217 }, 0);
    try outside(a.*, small_clip);
    // Idle direct fallback must ignore even this visibly different preview.
    a.clear(); b.clear();
    r.draw(a.dc, photo, 4000, 3000, -200, -150, 4001, 2000, small_clip, false);
    ref.draw(b.dc, photo, 4000, 3000, -200, -150, 4001, 2000, small_clip, false);
    try compare(a.*, b.*, .{ .left = 43, .top = 38, .right = 307, .bottom = 217 }, 0);
    r.setPreview(alpha, 0, 64);
    try check(r.preview == null and r.preview_width == 0 and r.preview_height == 0, "zero preview dimensions safely detach");
    r.setPreview(preview, 1600, 1200);
    r.deinit();
    try check(r.preview == null and try sourcePixel(preview, 200, 200) == preview_pixel, "deinit forgets borrowed preview without disposing or modifying it");
    // Each step changes dimensions, so these are actual interactive misses,
    // including DIB/DC replacement and checker fill, not retained pan hits.
    var full = Renderer{}; defer full.deinit();
    var fast = Renderer{}; defer fast.deinit();
    var proxy = Renderer{}; defer proxy.deinit();
    fast.setPreview(preview, 1600, 1200);
    proxy.setPreview(preview, 1600, 1200);
    full.draw(a.dc, photo, 4000, 3000, -30, -20, 650, 488, clip, true);
    fast.draw(b.dc, photo, 4000, 3000, -30, -20, 650, 488, clip, true);
    proxy.draw(b.dc, photo, 4000, 3000, -30, -20, 650, 488, clip, true);
    _ = c.GdiFlush();
    const proxy_bitmap = proxy.bitmap; const proxy_dc = proxy.cache_dc; const proxy_pixels = proxy.pixels;
    var full_ticks: i64 = 0; var fast_ticks: i64 = 0; var proxy_ticks: i64 = 0;
    var full_max: i64 = 0; var fast_max: i64 = 0; var proxy_max: i64 = 0;
    for (0..12) |i| {
        const width: u32 = 700 + @as(u32, @intCast(i)) * 65;
        const height = width * 3 / 4;
        var start = ticks();
        full.invalidate(); // Baseline: force the 12MP original cache-miss path.
        full.draw(a.dc, photo, 4000, 3000, -30, -20, @floatFromInt(width), @floatFromInt(height), clip, true);
        _ = c.GdiFlush();
        const old = ticks() - start;
        full_ticks += old; full_max = @max(full_max, old);
        start = ticks();
        fast.invalidate(); // Baseline: force the prior preview cache-miss path.
        fast.draw(b.dc, photo, 4000, 3000, -30, -20, @floatFromInt(width), @floatFromInt(height), clip, true);
        _ = c.GdiFlush();
        const quick = ticks() - start;
        fast_ticks += quick; fast_max = @max(fast_max, quick);
        start = ticks();
        proxy.draw(b.dc, photo, 4000, 3000, -30, -20, @floatFromInt(width), @floatFromInt(height), clip, true);
        _ = c.GdiFlush();
        const transient = ticks() - start;
        proxy_ticks += transient; proxy_max = @max(proxy_max, transient);
        try check(full.width == width and fast.width == width and !fast.high_quality and fast.source == photo and fast.preview == preview, "forced preview cache miss retains original key");
        try check(proxy.bitmap == proxy_bitmap and proxy.cache_dc == proxy_dc and proxy.pixels == proxy_pixels and proxy.width == 650 and proxy.height == 488, "changing-size proxy retains exact DIB/DC/storage and real cache geometry");
    }
    log("interactive zoom: 12 changing sizes 700x525 -> 1415x1061, includes allocation/checker/GdiFlush:\n", .{});
    log("  12MP source {d:.3} ms total, {d:.3}/step, max {d:.3}; 1600x1200 native preview {d:.3} ms total, {d:.3}/step, max {d:.3}; speedup {d:.2}x\n", .{ ms(full_ticks), ms(full_ticks) / 12, ms(full_max), ms(fast_ticks), ms(fast_ticks) / 12, ms(fast_max), @as(f64, @floatFromInt(full_ticks)) / @as(f64, @floatFromInt(@max(fast_ticks, 1))) });
    log("  retained StretchBlt proxy {d:.3} ms total, {d:.3}/step, max {d:.3}; speedup vs preview misses {d:.2}x\n", .{ ms(proxy_ticks), ms(proxy_ticks) / 12, ms(proxy_max), @as(f64, @floatFromInt(fast_ticks)) / @as(f64, @floatFromInt(@max(proxy_ticks, 1))) });
    const gdi = gdiCount(); const memory = privateBytes();
    var zoom_ticks: i64 = 0; var pan_ticks: i64 = 0; var gesture_max: i64 = 0;
    for (0..60) |i| {
        const width: u32 = 700 + @as(u32, @intCast(i % 12)) * 65;
        const height = width * 3 / 4;
        const dx: f32 = @floatFromInt(-30 - @as(i32, @intCast(i % 31)));
        var start = ticks();
        proxy.draw(b.dc, photo, 4000, 3000, dx, -20, @floatFromInt(width), @floatFromInt(height), clip, true);
        _ = c.GdiFlush();
        const zoom = ticks() - start;
        zoom_ticks += zoom; gesture_max = @max(gesture_max, zoom);
        start = ticks();
        proxy.draw(b.dc, photo, 4000, 3000, dx - 8, -27, @floatFromInt(width), @floatFromInt(height), clip, true);
        _ = c.GdiFlush();
        const pan = ticks() - start;
        pan_ticks += pan; gesture_max = @max(gesture_max, pan);
        try check(proxy.bitmap == proxy_bitmap and proxy.cache_dc == proxy_dc and proxy.pixels == proxy_pixels and proxy.width == 650, "60 zoom+pan pairs never replace retained proxy storage");
    }
    log("  60 zoom+pan pairs: zoom {d:.3} ms/frame, pan {d:.3} ms/frame, max {d:.3}; GDI {d}->{d}; private bytes {d}->{d}\n", .{ ms(zoom_ticks) / 60, ms(pan_ticks) / 60, ms(gesture_max), gdi, gdiCount(), memory, privateBytes() });
    try check(gdiCount() == gdi and privateBytes() <= memory + 1024 * 1024, "proxy gesture has stable GDI count and bounded private bytes");
    const settle_start = ticks();
    proxy.draw(b.dc, photo, 4000, 3000, -30, -20, 1415, 1061, clip, false);
    _ = c.GdiFlush();
    const settle_ticks = ticks() - settle_start;
    try check(proxy.width == 1415 and proxy.height == 1061 and proxy.high_quality, "idle restores exact geometry and original HQ after proxy gesture");
    w.imageRectClipped(a.dc, photo, -30, -20, 1415, 1061, 4000, 3000, clip);
    // Different HQ scaling geometry can differ by two channel levels between
    // the origin-zero DIB render and translated whole-image GDI+ reference.
    try compare(a.*, b.*, .{ .left = 4, .top = 4, .right = 1276, .bottom = 796 }, 2);
    log("  idle original-HQ settle {d:.3} ms; preview preparation outside gesture {d:.3} ms; borrowed preview 7,680,000 bytes; raster budget unchanged\n", .{ ms(settle_ticks), ms(build_time) });
    try check(try sourcePixel(photo, 200, 200) == original and try sourcePixel(preview, 200, 200) == preview_pixel, "preview zoom leaves original and borrowed source pixels unchanged");
    fast.invalidate();
    try check(fast.preview == preview and fast.bitmap == null, "zoom invalidation retains borrowed preview with no raster");
    fast.setPreview(null, 0, 0);
    try check(fast.preview == null, "explicit detach before caller disposal");
}
fn run() !void {
    var f: c.LARGE_INTEGER = undefined;
    try check(c.QueryPerformanceFrequency(&f) != 0, "performance counter");
    frequency = f.QuadPart;
    var token: usize = 0;
    try check(w.GdiplusStartup(&token, &w.StartupInput{}, null) == 0, "GDI+ startup");
    defer w.GdiplusShutdown(token);
    const photo = try load(w.L("tests/render-check/fixtures/12mp.png"));
    defer _ = w.GdipDisposeImage(photo);
    const alpha = try load(w.L("tests/render-check/fixtures/alpha.png"));
    defer _ = w.GdipDisposeImage(alpha);
    var width: u32 = 0; var height: u32 = 0;
    _ = w.GdipGetImageWidth(photo, &width); _ = w.GdipGetImageHeight(photo, &height);
    try check(width == 4000 and height == 3000, "actual decoded 12MP fixture");
    var a = try Surface.init(1280, 800); defer a.deinit();
    var b = try Surface.init(1280, 800); defer b.deinit();
    a.clear(); b.clear();
    var focused: [2]u16 = undefined;
    if (c.GetEnvironmentVariableW(w.L("KADR_RENDER_FOCUSED"), &focused, focused.len) != 0) {
        log("focused proxy/tiny checks only (full benchmark skipped)\n", .{});
        try proxyChecks(alpha, &a);
        try tinyChecks(alpha);
        return;
    }
    var empty = Renderer{}; empty.deinit(); empty.invalidate();
    try benchmark(photo, &a, &b);
    try quality(photo, &a, &b);
    try alphaAndClip(alpha, &a, &b);
    try limitsAndFallback(photo, alpha, &a, &b);
    try previewChecks(photo, alpha, &a, &b);
    try proxyChecks(alpha, &a);
    try tinyChecks(alpha);
    try lifecycle(photo, alpha, &a);
    try creationFailure(alpha, &a);
}
