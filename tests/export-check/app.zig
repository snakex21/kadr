// Dedicated native-dialog harness, never production Kadr.exe. No wallpaper SET.
const std = @import("std");
const w = @import("../../src/win.zig");
const c = w.c;
const Image = @import("../../src/image.zig").Image;
const output = @import("../../src/output.zig");
const dialog = @import("../../src/export_dialog.zig");
extern "gdiplus" fn GdipCreateBitmapFromScan0(i32, i32, i32, i32, ?[*]u8, *?*w.GpImage) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipBitmapSetPixel(*w.GpImage, i32, i32, u32) callconv(.Stdcall) i32;

pub fn main() !void {
    @import("../../src/i18n.zig").init();
    const a = std.heap.page_allocator;
    const args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);
    if (args.len != 2) return error.ExpectedTestSourcePath;
    const path = try std.unicode.utf8ToUtf16LeWithNull(a, args[1]);
    defer a.free(path);
    var token: usize = 0;
    if (w.GdiplusStartup(&token, &w.StartupInput{}, null) != 0) return error.GdiStartup;
    defer w.GdiplusShutdown(token);
    var image = Image{ .width = 12, .height = 8 };
    defer image.close();
    if (GdipCreateBitmapFromScan0(12, 8, 0, 0x0026200a, null, &image.handle) != 0) return error.Bitmap;
    var y: i32 = 0;
    while (y < 8) : (y += 1) {
        var x: i32 = 0;
        while (x < 12) : (x += 1) _ = GdipBitmapSetPixel(image.handle.?, x, y, if (x < 6) 0x800000ff else 0xffff0000);
    }
    // Only a new generated path supplied by the test runner may be created.
    if (c.GetFileAttributesW(path) != c.INVALID_FILE_ATTRIBUTES) return error.SourceMustNotExist;
    if (!output.save(&image, path, .png)) return error.SaveFixture;
    image.close();
    // Real loaded source file remains held by GDI+ throughout show().
    if (w.GdipLoadImageFromFile(path, &image.handle) != 0) return error.LoadFixture;
    image.width = 12;
    image.height = 8;
    image.rotate();
    const owner = c.CreateWindowExW(0, w.L("STATIC"), w.L("Kadr export-check owner"), c.WS_OVERLAPPEDWINDOW, 0, 0, 640, 500, null, null, c.GetModuleHandleW(null), null);
    if (owner == null) return error.Owner;
    defer _ = c.DestroyWindow(owner);
    std.debug.print("READY native export test\n", .{});
    const saved = dialog.show(owner, &image, path);
    std.debug.print("RESULT saved={any}, source={d}x{d}, owner_enabled={d}\n", .{ saved, image.width, image.height, c.IsWindowEnabled(owner) });
}
