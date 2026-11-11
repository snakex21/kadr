//! Before/after benchmark of close-zoom frames (zoom animation, settle, pans).
//! Development-only; both renderers draw into identical native DIB surfaces.
const std = @import("std");
const w = @import("../../src/win.zig");
const c = w.c;
const Before = @import("render_before.zig").Renderer;
const After = @import("../../src/render.zig").Renderer;
extern "gdiplus" fn GdipCreateBitmapFromScan0(i32, i32, i32, i32, ?[*]u8, *?*w.GpImage) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipGetImageGraphicsContext(*w.GpImage, *?*w.GpGraphics) callconv(.Stdcall) i32;
var frequency: i64 = 0;

fn log(comptime format: []const u8, args: anytype) void {
    var buffer: [1024]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, format, args) catch return;
    var written: u32 = 0;
    _ = c.WriteFile(c.GetStdHandle(c.STD_ERROR_HANDLE), text.ptr, @intCast(text.len), &written, null);
}
fn ticks() i64 {
    var t: c.LARGE_INTEGER = undefined;
    _ = c.QueryPerformanceCounter(&t);
    return t.QuadPart;
}
fn ms(t: i64) f64 {
    return @as(f64, @floatFromInt(t)) * 1000 / @as(f64, @floatFromInt(frequency));
}
const Surface = struct {
    dc: c.HDC,
    bitmap: c.HBITMAP,
    previous: c.HGDIOBJ,
    fn init(width: i32, height: i32) !Surface {
        const dc = c.CreateCompatibleDC(null) orelse return error.CreateDC;
        var info = std.mem.zeroes(c.BITMAPINFO);
        info.bmiHeader.biSize = @sizeOf(c.BITMAPINFOHEADER);
        info.bmiHeader.biWidth = width;
        info.bmiHeader.biHeight = -height;
        info.bmiHeader.biPlanes = 1;
        info.bmiHeader.biBitCount = 32;
        var bits: ?*anyopaque = null;
        const bitmap = c.CreateDIBSection(dc, &info, c.DIB_RGB_COLORS, &bits, null, 0) orelse return error.CreateDIB;
        return .{ .dc = dc, .bitmap = bitmap, .previous = c.SelectObject(dc, bitmap) };
    }
    fn deinit(self: *Surface) void {
        _ = c.SelectObject(self.dc, self.previous);
        _ = c.DeleteObject(self.bitmap);
        _ = c.DeleteDC(self.dc);
    }
};
fn scaled(source: *w.GpImage, iw: u32, ih: u32, width: i32, height: i32) !*w.GpImage {
    var image: ?*w.GpImage = null;
    if (GdipCreateBitmapFromScan0(width, height, 0, 0x26200a, null, &image) != 0 or image == null) return error.Bitmap;
    var graphics: ?*w.GpGraphics = null;
    if (GdipGetImageGraphicsContext(image.?, &graphics) != 0 or graphics == null) return error.Graphics;
    defer _ = w.GdipDeleteGraphics(graphics.?);
    _ = w.GdipSetPageUnit(graphics.?, 2);
    _ = w.GdipSetInterpolationMode(graphics.?, 7);
    _ = w.GdipDrawImageRectRect(graphics.?, source, 0, 0, @floatFromInt(width), @floatFromInt(height), 0, 0, @floatFromInt(iw), @floatFromInt(ih), 2, null, null, null);
    return image.?;
}
const Stats = struct {
    total: i64 = 0,
    worst: i64 = 0,
    frames: u32 = 0,
    fn add(self: *Stats, elapsed: i64) void {
        self.total += elapsed;
        self.worst = @max(self.worst, elapsed);
        self.frames += 1;
    }
    fn avg(self: Stats) f64 {
        return ms(self.total) / @as(f64, @floatFromInt(@max(self.frames, 1)));
    }
};
const Result = struct { zoom: Stats = .{}, settle: i64 = 0, pan: Stats = .{}, pan_settle: i64 = 0 };

const view_w: f32 = 1280;
const view_h: f32 = 800;
fn frame(r: anytype, s: *Surface, image: *w.GpImage, iw: u32, ih: u32, zoom: f32, pan_x: f32, pan_y: f32, interactive: bool) i64 {
    const dw = @as(f32, @floatFromInt(iw)) * zoom;
    const dh = @as(f32, @floatFromInt(ih)) * zoom;
    const clip = c.RECT{ .left = 0, .top = 0, .right = 1280, .bottom = 800 };
    const start = ticks();
    r.draw(s.dc, image, iw, ih, (view_w - dw) / 2 + pan_x, (view_h - dh) / 2 + pan_y, dw, dh, clip, interactive);
    _ = c.GdiFlush();
    return ticks() - start;
}
/// The application's eased zoom animation (0.38 per 10 ms frame), a settle,
/// then 90 interactive drag frames of 24 px and a final settle.
fn scenario(comptime R: type, s: *Surface, image: *w.GpImage, iw: u32, ih: u32, preview: ?*w.GpImage, pw: u32, ph: u32, from: f32, to: f32) Result {
    var r = R{};
    defer r.deinit();
    if (preview) |p| r.setPreview(p, pw, ph);
    var out = Result{};
    _ = frame(&r, s, image, iw, ih, from, 0, 0, false);
    var zoom = from;
    while (true) {
        zoom += (to - zoom) * 0.38;
        if (@fabs(to - zoom) < @max(0.0001, to * 0.002)) zoom = to;
        out.zoom.add(frame(&r, s, image, iw, ih, zoom, 0, 0, true));
        if (zoom == to) break;
    }
    out.settle = frame(&r, s, image, iw, ih, to, 0, 0, false);
    var px: f32 = 0;
    var py: f32 = 0;
    for (0..90) |i| {
        px -= 24;
        py -= if (i % 3 == 0) 12 else 0;
        out.pan.add(frame(&r, s, image, iw, ih, to, px, py, true));
    }
    out.pan_settle = frame(&r, s, image, iw, ih, to, px, py, false);
    return out;
}
fn report(name: []const u8, before: Result, after: Result) void {
    log("{s}\n", .{name});
    log("  zoom animation: before {d:.2} ms/frame (max {d:.2}, {d} frames); after {d:.2} ms/frame (max {d:.2})\n", .{ before.zoom.avg(), ms(before.zoom.worst), before.zoom.frames, after.zoom.avg(), ms(after.zoom.worst) });
    log("  settle after zoom: before {d:.2} ms; after {d:.2} ms\n", .{ ms(before.settle), ms(after.settle) });
    log("  drag: before {d:.2} ms/frame (max {d:.2}); after {d:.2} ms/frame (max {d:.2})\n", .{ before.pan.avg(), ms(before.pan.worst), after.pan.avg(), ms(after.pan.worst) });
    log("  settle after drag: before {d:.2} ms; after {d:.2} ms\n", .{ ms(before.pan_settle), ms(after.pan_settle) });
}
pub fn main() void {
    var f: c.LARGE_INTEGER = undefined;
    _ = c.QueryPerformanceFrequency(&f);
    frequency = f.QuadPart;
    var token: usize = 0;
    if (w.GdiplusStartup(&token, &w.StartupInput{}, null) != 0) c.ExitProcess(1);
    defer w.GdiplusShutdown(token);
    var photo: ?*w.GpImage = null;
    if (w.GdipLoadImageFromFile(w.L("tests/render-check/fixtures/12mp.png"), &photo) != 0 or photo == null) {
        log("missing tests/render-check/fixtures/12mp.png (run tests/render-check/prepare.py)\n", .{});
        c.ExitProcess(1);
    }
    defer _ = w.GdipDisposeImage(photo.?);
    var s = Surface.init(1280, 800) catch c.ExitProcess(1);
    defer s.deinit();
    // Small photo (<=2 MP): the loader prepares no preview for it.
    const small = scaled(photo.?, 4000, 3000, 1200, 900) catch c.ExitProcess(1);
    defer _ = w.GdipDisposeImage(small);
    const preview = scaled(photo.?, 4000, 3000, 1600, 1200) catch c.ExitProcess(1);
    defer _ = w.GdipDisposeImage(preview);
    const tiny = scaled(photo.?, 4000, 3000, 60, 45) catch c.ExitProcess(1);
    defer _ = w.GdipDisposeImage(tiny);
    log("viewport 1280x800; GdiFlush after every frame\n", .{});
    report("1200x900 photo (no preview), zoom 100% -> 400%:", scenario(Before, &s, small, 1200, 900, null, 0, 0, 1, 4), scenario(After, &s, small, 1200, 900, null, 0, 0, 1, 4));
    report("1200x900 photo (no preview), zoom 100% -> 230%:", scenario(Before, &s, small, 1200, 900, null, 0, 0, 1, 2.3), scenario(After, &s, small, 1200, 900, null, 0, 0, 1, 2.3));
    report("4000x3000 photo + 1600 preview, zoom fit -> 70%:", scenario(Before, &s, photo.?, 4000, 3000, preview, 1600, 1200, 0.2667, 0.7), scenario(After, &s, photo.?, 4000, 3000, preview, 1600, 1200, 0.2667, 0.7));
    report("4000x3000 photo + 1600 preview, zoom fit -> 300%:", scenario(Before, &s, photo.?, 4000, 3000, preview, 1600, 1200, 0.2667, 3), scenario(After, &s, photo.?, 4000, 3000, preview, 1600, 1200, 0.2667, 3));
    report("60x45 pixel art, zoom 1000% -> 4500%:", scenario(Before, &s, tiny, 60, 45, null, 0, 0, 10, 45), scenario(After, &s, tiny, 60, 45, null, 0, 0, 10, 45));
}
