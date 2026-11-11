const std = @import("std");
const w = @import("../../src/win.zig");
const Image = @import("../../src/image.zig").Image;

extern "gdiplus" fn GdipBitmapGetPixel(*w.GpImage, i32, i32, *u32) callconv(.Stdcall) i32;
var checks: usize = 0;
fn check(ok: bool, label: []const u8) !void {
    if (!ok) {
        log("FAIL: {s}\n", .{label});
        return error.CheckFailed;
    }
    checks += 1;
}
fn pixel(image: *Image, x: i32, y: i32) !u32 {
    var color: u32 = 0;
    if (GdipBitmapGetPixel(image.handle.?, x, y, &color) != 0) return error.GetPixel;
    return color;
}

fn log(comptime format: []const u8, args: anytype) void {
    var buffer: [512]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, format, args) catch return;
    var written: u32 = 0;
    _ = w.c.WriteFile(w.c.GetStdHandle(w.c.STD_ERROR_HANDLE), text.ptr, @intCast(text.len), &written, null);
}
pub fn panic(message: []const u8, trace: ?*std.builtin.StackTrace, address: ?usize) noreturn {
    _ = trace; _ = address;
    log("panic: {s}\n", .{message});
    w.c.ExitProcess(2);
}
pub fn main() void {
    run() catch |err| {
        log("harness failure: {s}\n", .{@errorName(err)});
        w.c.ExitProcess(1);
    };
}
fn run() !void {
    var token: usize = 0;
    if (w.GdiplusStartup(&token, &w.StartupInput{}, null) != 0) return error.GdiplusStartup;
    defer w.GdiplusShutdown(token);
    var image: Image = .{};
    defer image.close();
    try check(!image.load(w.L("does-not-exist.png")), "missing PNG");
    try check(image.nextFrame() == 0 and !image.setPage(0), "empty navigation");
    try check(image.frameDelay() == 100, "default frame delay");
    image.rotate();
    try check(!image.load(w.L("tests/fixtures/broken.png")), "broken PNG");
    try check(image.handle == null and image.width == 0 and image.pages == 1, "failed load reset");
    const ordinary = [_][*:0]const u16{
        w.L("tests/fixtures/01-krajobraz.png"),
        w.L("tests/fixtures/02-zdjecie.jpg"),
        w.L("tests/fixtures/03-obraz.bmp"),
        w.L("tests/fixtures/08-zażółć-gęślą.png"),
    };
    for (ordinary) |path| {
        try check(image.load(path), "ordinary format/Unicode load");
        try check(image.width == 800 and image.height == 500 and image.pages == 1 and !image.animated and !image.is_djvu, "ordinary fields");
        try check(image.setPage(0) and !image.setPage(1), "ordinary page bounds");
        image.rotate();
        try check(image.width == 500 and image.height == 800, "clockwise rotation dimensions");
        image.rotate(); image.rotate(); image.rotate();
        try check(image.width == 800 and image.height == 500, "four rotations");
    }
    try check(image.load(w.L("tests/fixtures/06-przezroczystosc.png")), "alpha PNG");
    try check(image.width == 320 and image.height == 240, "alpha dimensions");
    {
        var icon: ?*w.GpImage = null;
        const status = w.GdipLoadImageFromFile(w.L("tests/fixtures/07-ikona.ico"), &icon);
        log("ICO direct load status={d} handle={any}\n", .{status, icon});
        if (icon) |handle| {
            var a: u32 = 0; var b: u32 = 0;
            const sa = w.GdipGetImageWidth(handle, &a); const sb = w.GdipGetImageHeight(handle, &b);
            log("ICO dims status={d}/{d} {d}x{d}\n", .{sa,sb,a,b});
            _ = w.GdipDisposeImage(handle);
        }
    }
    try check(image.load(w.L("tests/fixtures/07-ikona.ico")), "ICO");
    try check(image.width > 0 and image.height > 0, "ICO dimensions");
    try check(image.load(w.L("tests/image-check/classic.ico")), "classic DIB-based ICO");
    try check(image.width == 32 and image.height == 32, "classic icon dimensions");
    try check(image.load(w.L("tests/fixtures/05-animacja.gif")), "GIF");
    try check(image.animated and image.frames == 3 and image.frame == 0 and image.width == 320 and image.height == 200, "GIF fields");
    try check(image.frameDelay() == 120, "initial GIF property delay");
    try check(image.nextFrame() == 240 and image.frame == 1, "GIF 240ms delay");
    try check(image.nextFrame() == 360 and image.frame == 2, "GIF 360ms delay");
    try check(image.nextFrame() == 120 and image.frame == 0, "GIF 120ms delay and wrap");
    try check(image.load(w.L("tests/image-check/short-delays.gif")), "GIF zero/short delays");
    try check(image.frameDelay() == 100 and image.frame == 0, "zero GIF delay defaults to 100ms without advancing");
    try check(image.nextFrame() == 20 and image.frame == 1, "10ms GIF delay clamps to 20ms");
    try check(image.nextFrame() == 240, "nonzero normal GIF delay preserved");
    try check(image.nextFrame() == 100, "zero GIF delay default after wrap");
    try check(image.load(w.L("tests/fixtures/04-strony.tiff")), "TIFF");
    try check(image.pages == 2 and image.page == 0 and !image.animated, "TIFF page count");
    try check(image.setPage(1) and image.page == 1 and image.width == 500 and image.height == 800, "TIFF second page");
    try check(!image.setPage(2) and image.page == 1 and image.handle != null, "TIFF out-of-range preserves page");
    try check(image.setPage(0) and image.width == 800 and image.height == 500, "TIFF first page");
    try check(!image.load(w.L("does-not-exist.djvu")), "missing DjVu");
    try std.fs.cwd().writeFile("tests/image-check/broken.djvu", "not a DjVu image");
    try check(!image.load(w.L("tests/image-check/broken.djvu")), "malformed DjVu asynchronous error");
    try check(image.handle == null and !image.is_djvu, "DjVu error cleanup/reset");
    try check(image.load(w.L("tests/image-check/book.djvu")), "official bundled DjVu book");
    log("DjVu: {d} pages, page 0 render {d}x{d}\n", .{image.pages, image.width, image.height});
    try check(image.is_djvu and image.pages > 1 and image.width > 0 and image.width <= 6000 and image.height > 0 and image.height <= 6000, "DjVu fields and render bounds");
    try check(image.setPage(image.pages - 1) and image.page == image.pages - 1, "DjVu last page");
    const old_handle = image.handle;
    try check(!image.setPage(image.pages) and image.handle == old_handle, "DjVu invalid page preserves bitmap");
    try check(image.setPage(0), "DjVu first page");
    const old_width = image.width;
    const old_height = image.height;
    image.rotate();
    try check(image.width == old_height and image.height == old_width, "DjVu bitmap rotation");
    try check(image.load(w.L("tests/image-check/książka.DJV")), "Unicode and uppercase DjVu extension");
    try check(image.pages > 1, "Unicode DjVu page count");
    try check(image.load(w.L("tests/image-check/large.djvu")), "large generated DjVu");
    try check(image.width == 6000 and image.height == 50, "12000x100 DjVu bounded to 6000x50");
    const top = try pixel(&image, 10, 0);
    const bottom = try pixel(&image, 10, 49);
    try check(((top >> 16) & 255) > 200 and (top & 255) < 50, "RGB32 red channel/top-down row order");
    try check((bottom & 255) > 200 and ((bottom >> 16) & 255) < 50, "RGB32 blue channel/bottom row");
    image.rotate();
    try check(image.width == 50 and image.height == 6000, "backed bitmap rotation");
    const rotated = try pixel(&image, 49, 10);
    try check(((rotated >> 16) & 255) > 200 and (rotated & 255) < 50, "backing buffer remains valid after rotation");
    for (0..3) |_| {
        try check(image.load(w.L("tests/image-check/book.djvu")), "repeat DjVu load");
        try check(image.load(w.L("tests/fixtures/05-animacja.gif")), "DjVu-to-GIF resource transition");
        try check(image.nextFrame() == 240, "GIF delay after resource transition");
        image.close(); image.close();
        try check(image.handle == null and image.width == 0 and image.frames == 1 and image.pages == 1 and !image.is_djvu and !image.animated, "idempotent close and defaults");
    }
    log("image: x86 XP harness PASS ({d} checks)\n", .{checks});
}
