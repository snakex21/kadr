const std = @import("std");
const w = @import("../../src/win.zig");
const c = w.c;
const Image = @import("../../src/image.zig").Image;
const output = @import("../../src/output.zig");
const dialog = @import("../../src/export_dialog.zig");
const tools = @import("../../src/file_tools.zig");
const a = std.testing.allocator;
extern "gdiplus" fn GdipCreateBitmapFromScan0(i32, i32, i32, i32, ?[*]u8, *?*w.GpImage) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipBitmapSetPixel(*w.GpImage, i32, i32, u32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipBitmapGetPixel(*w.GpImage, i32, i32, *u32) callconv(.Stdcall) i32;

fn bitmap(width: u32, height: u32, color: u32) !Image {
    var image = Image{ .width = width, .height = height };
    errdefer image.close();
    try std.testing.expectEqual(@as(i32, 0), GdipCreateBitmapFromScan0(@intCast(width), @intCast(height), 0, 0x0026200a, null, &image.handle));
    var y: u32 = 0;
    while (y < height) : (y += 1) {
        var x: u32 = 0;
        while (x < width) : (x += 1) try std.testing.expectEqual(@as(i32, 0), GdipBitmapSetPixel(image.handle.?, @intCast(x), @intCast(y), color));
    }
    return image;
}
fn pixel(image: *const Image, x: i32, y: i32) !u32 {
    var value: u32 = 0;
    try std.testing.expectEqual(@as(i32, 0), GdipBitmapGetPixel(image.handle.?, x, y, &value));
    return value;
}
fn path(folder: []const u8, name: []const u8) ![:0]u16 {
    const narrow = try std.fs.path.join(a, &.{ folder, name });
    defer a.free(narrow);
    return std.unicode.utf8ToUtf16LeWithNull(a, narrow);
}
fn startup() !usize {
    var token: usize = 0;
    try std.testing.expectEqual(@as(i32, 0), w.GdiplusStartup(&token, &w.StartupInput{}, null));
    return token;
}
fn load(p: [*:0]const u16) !Image {
    var image = Image{};
    errdefer image.close();
    try std.testing.expectEqual(@as(i32, 0), w.GdipLoadImageFromFile(p, &image.handle));
    try std.testing.expectEqual(@as(i32, 0), w.GdipGetImageWidth(image.handle.?, &image.width));
    try std.testing.expectEqual(@as(i32, 0), w.GdipGetImageHeight(image.handle.?, &image.height));
    return image;
}

test "export integer validation and aspect arithmetic reject instead of clamp" {
    std.testing.refAllDecls(dialog);
    std.testing.refAllDecls(tools);
    for ([_][]const u16{ w.L(""), w.L("0"), w.L("-1"), w.L("+1"), w.L(" 1"), w.L("1.0"), w.L("NaN"), w.L("Inf"), w.L("4294967296") }) |value| try std.testing.expect(dialog.positiveInteger(value) == null);
    try std.testing.expectEqual(@as(?u32, 4294967295), dialog.positiveInteger(w.L("4294967295")));
    try std.testing.expectEqual(@as(?u32, 4), output.aspectDimension(6, 3, 2));
    try std.testing.expectEqual(@as(?u32, 3), output.aspectDimension(2, 2, 3));
    try std.testing.expect(output.aspectDimension(1, 4294967295, 1) == null);
    try std.testing.expect(output.aspectDimension(4294967295, 1, 4294967295) == null);
    try std.testing.expect(!output.validExportDimensions(0, 1));
    try std.testing.expect(!output.validExportDimensions(8001, 8000));
    try std.testing.expect(output.validExportDimensions(8000, 8000));
    try std.testing.expect(!output.validExportDimensions(0xffffffff, 0xffffffff));
}

test "resize follows baked rotation, preserves alpha, private ownership and source" {
    const token = try startup();
    defer w.GdiplusShutdown(token);
    var image = try bitmap(12, 8, 0xffff0000);
    defer image.close();
    var y: i32 = 0;
    while (y < 8) : (y += 1) {
        var x: i32 = 6;
        while (x < 12) : (x += 1) _ = GdipBitmapSetPixel(image.handle.?, x, y, 0xff0000ff);
    }
    image.rotate();
    const handle = image.handle;
    var up = output.scaledSnapshot(&image, 16, 24) orelse return error.ResizeFailed;
    defer up.close();
    var down = output.scaledSnapshot(&image, 4, 6) orelse return error.ResizeFailed;
    defer down.close();
    try std.testing.expect(up.handle != handle and down.handle != handle);
    try std.testing.expectEqual(@as(u32, 16), up.width);
    try std.testing.expectEqual(@as(u32, 24), up.height);
    try std.testing.expectEqual(@as(u32, 0xffff0000), try pixel(&up, 8, 2));
    try std.testing.expectEqual(@as(u32, 0xff0000ff), try pixel(&up, 8, 21));
    try std.testing.expectEqual(@as(u32, 0xffff0000), try pixel(&down, 2, 0));
    try std.testing.expectEqual(@as(u32, 0xff0000ff), try pixel(&down, 2, 5));
    try std.testing.expectEqual(handle, image.handle);
    try std.testing.expectEqual(@as(u32, 8), image.width);
    try std.testing.expectEqual(@as(u32, 12), image.height);
    try std.testing.expectEqual(@as(u32, 0xffff0000), try pixel(&image, 4, 1));
    var alpha = try bitmap(5, 3, 0x800000ff);
    defer alpha.close();
    var scaled_alpha = output.scaledSnapshot(&alpha, 10, 6) orelse return error.ResizeFailed;
    defer scaled_alpha.close();
    try std.testing.expectEqual(@as(u32, 0x800000ff), try pixel(&scaled_alpha, 0, 0));
    try std.testing.expectEqual(@as(u32, 0x800000ff), try pixel(&scaled_alpha, 5, 3));
    try std.testing.expectEqual(@as(u32, 0x800000ff), try pixel(&alpha, 0, 0));
    try std.testing.expect(!output.validOptions(&alpha, .{ .width = 3, .height = 2, .jpeg_quality = 0 }));
    try std.testing.expect(!output.validOptions(&alpha, .{ .width = 3, .height = 2, .jpeg_quality = 101 }));
}

test "JPEG quality changes encoded bytes; legacy 92; PNG and TIFF alpha roundtrip" {
    const token = try startup();
    defer w.GdiplusShutdown(token);
    var image = try bitmap(128, 96, 0x800000ff);
    defer image.close();
    var y: i32 = 0;
    while (y < 96) : (y += 1) {
        var x: i32 = 0;
        while (x < 128) : (x += 1) {
            const seed: u32 = @intCast(x * 3571 + y * 7919);
            _ = GdipBitmapSetPixel(image.handle.?, x, y, 0x80000000 | ((seed *% 2654435761) & 0xffffff));
        }
    }
    const before = try pixel(&image, 40, 30);
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const folder = try tmp.dir.realpathAlloc(a, ".");
    defer a.free(folder);
    const low = try path(folder, "low.jpg"); defer a.free(low);
    const high = try path(folder, "high.jpg"); defer a.free(high);
    const legacy = try path(folder, "legacy.jpg"); defer a.free(legacy);
    const q92 = try path(folder, "q92.jpg"); defer a.free(q92);
    try std.testing.expect(output.saveOptions(&image, low, .jpeg, .{ .width = 128, .height = 96, .jpeg_quality = 5 }));
    try std.testing.expect(output.saveOptions(&image, high, .jpeg, .{ .width = 128, .height = 96, .jpeg_quality = 100 }));
    try std.testing.expect(output.save(&image, legacy, .jpeg));
    try std.testing.expect(output.saveOptions(&image, q92, .jpeg, .{ .width = 128, .height = 96, .jpeg_quality = 92 }));
    const lb = try tmp.dir.readFileAlloc(a, "low.jpg", 1000000); defer a.free(lb);
    const hb = try tmp.dir.readFileAlloc(a, "high.jpg", 1000000); defer a.free(hb);
    const ob = try tmp.dir.readFileAlloc(a, "legacy.jpg", 1000000); defer a.free(ob);
    const qb = try tmp.dir.readFileAlloc(a, "q92.jpg", 1000000); defer a.free(qb);
    try std.testing.expect(hb.len > lb.len);
    try std.testing.expect(!std.mem.eql(u8, lb, hb));
    try std.testing.expectEqualSlices(u8, ob, qb);
    std.debug.print("quality bytes: q5={d}, q100={d}, legacy92={d}\n", .{ lb.len, hb.len, ob.len });
    var alpha = try bitmap(5, 3, 0x800000ff); defer alpha.close();
    for ([_]output.Format{ .png, .tiff }) |kind| {
        const p = try path(folder, if (kind == .png) "alpha.png" else "alpha.tif"); defer a.free(p);
        // Reserved existing empty temp is deliberately accepted by saveOptions.
        const file = c.CreateFileW(p, c.GENERIC_WRITE, 0, null, c.CREATE_NEW, 0, null);
        try std.testing.expect(file != c.INVALID_HANDLE_VALUE);
        _ = c.CloseHandle(file);
        try std.testing.expect(output.saveOptions(&alpha, p, kind, .{ .width = 10, .height = 6 }));
        var result = try load(p); defer result.close();
        try std.testing.expectEqual(@as(u32, 10), result.width);
        try std.testing.expectEqual(@as(u32, 6), result.height);
        try std.testing.expectEqual(@as(u32, 0x800000ff), try pixel(&result, 5, 3));
    }
    try std.testing.expectEqual(before, try pixel(&image, 40, 30));
    try std.testing.expectEqual(@as(u32, 0x800000ff), try pixel(&alpha, 0, 0));
}

test "safe copy rejects source aliases, overwrite without authorization and bad dimensions" {
    const token = try startup(); defer w.GdiplusShutdown(token);
    var image = try bitmap(4, 2, 0xff00ff00); defer image.close();
    var tmp = std.testing.tmpDir(.{}); defer tmp.cleanup();
    const folder = try tmp.dir.realpathAlloc(a, "."); defer a.free(folder);
    const original = try path(folder, "źródło.png"); defer a.free(original);
    const target = try path(folder, "nowa-kopia.png"); defer a.free(target);
    const alias = try path(folder, "alias.png"); defer a.free(alias);
    try std.testing.expect(output.save(&image, original, .png));
    const before = try tmp.dir.readFileAlloc(a, "źródło.png", 1000000); defer a.free(before);
    const options = output.ExportOptions{ .width = 8, .height = 4 };
    try std.testing.expectError(error.SameSource, dialog.saveCopy(&image, original, original, .png, options, true));
    try std.testing.expect(c.CreateHardLinkW(alias, original, null) != 0);
    try std.testing.expectError(error.SameSource, dialog.saveCopy(&image, original, alias, .png, options, true));
    try dialog.saveCopy(&image, original, target, .png, options, false);
    try std.testing.expectError(error.TargetExists, dialog.saveCopy(&image, original, target, .png, options, false));
    try std.testing.expectError(error.InvalidOptions, dialog.saveCopy(&image, original, target, .png, .{ .width = 0, .height = 1 }, true));
    var loaded = try load(target); defer loaded.close();
    try std.testing.expectEqual(@as(u32, 8), loaded.width);
    try std.testing.expectEqual(@as(u32, 4), loaded.height);
    loaded.close();
    // Failure after successful encoding must leave the destination intact and
    // remove the reserved temp. Read-only applies to this generated file only.
    const target_before = try tmp.dir.readFileAlloc(a, "nowa-kopia.png", 1000000); defer a.free(target_before);
    try std.testing.expect(c.SetFileAttributesW(target, c.FILE_ATTRIBUTE_READONLY) != 0);
    defer _ = c.SetFileAttributesW(target, c.FILE_ATTRIBUTE_NORMAL);
    try std.testing.expectError(error.CommitFailed, dialog.saveCopy(&image, original, target, .png, options, true));
    const target_after = try tmp.dir.readFileAlloc(a, "nowa-kopia.png", 1000000); defer a.free(target_after);
    try std.testing.expectEqualSlices(u8, target_before, target_after);
    try std.testing.expect(c.SetFileAttributesW(target, c.FILE_ATTRIBUTE_NORMAL) != 0);
    const after = try tmp.dir.readFileAlloc(a, "źródło.png", 1000000); defer a.free(after);
    try std.testing.expectEqualSlices(u8, before, after);
    var default_buffer: [260]u16 = undefined;
    const def = dialog.defaultPath(original, .jpeg, &default_buffer) orelse return error.DefaultPathFailed;
    try std.testing.expect(std.mem.endsWith(u16, def, w.L("źródło-export.jpg")));
    var iterable = try tmp.dir.openIterableDir(".", .{}); defer iterable.close();
    var iterator = iterable.iterate();
    var count: usize = 0;
    while (try iterator.next()) |entry| { try std.testing.expect(!std.mem.endsWith(u8, entry.name, ".tmp")); count += 1; }
    try std.testing.expectEqual(@as(usize, 3), count);
}

test "copy path contains actual unquoted full Unicode CF_UNICODETEXT" {
    const owner = c.CreateWindowExW(0, w.L("STATIC"), w.L("Kadr test clipboard owner"), c.WS_OVERLAPPED, 0, 0, 100, 100, null, null, c.GetModuleHandleW(null), null);
    try std.testing.expect(owner != null);
    defer _ = c.DestroyWindow(owner);
    const value = w.L("C:\\Zdjęcia próbne\\Zażółć gęślą jaźń — 🐢.png");
    try std.testing.expect(tools.copyPath(owner, value));
    try std.testing.expect(c.OpenClipboard(owner) != 0);
    defer _ = c.CloseClipboard();
    defer _ = c.EmptyClipboard(); // Remove the generated test path, not a fixture.
    const memory = c.GetClipboardData(c.CF_UNICODETEXT) orelse return error.NoUnicodeClipboard;
    const data = c.GlobalLock(memory) orelse return error.LockFailed;
    defer _ = c.GlobalUnlock(memory);
    const actual: [*:0]const u16 = @ptrCast(@alignCast(data));
    try std.testing.expectEqualSlices(u16, value, std.mem.span(actual));
    try std.testing.expect(!tools.copyPath(null, value));
}

test "wallpaper compositor fit fill center stretch, alpha and source stay unchanged; no SPI SET" {
    const token = try startup(); defer w.GdiplusShutdown(token);
    var image = try bitmap(8, 4, 0xffff0000); defer image.close();
    var y: i32 = 0;
    while (y < 4) : (y += 1) {
        var x: i32 = 4;
        while (x < 8) : (x += 1) _ = GdipBitmapSetPixel(image.handle.?, x, y, 0xff0000ff);
    }
    const handle = image.handle;
    var tmp = std.testing.tmpDir(.{}); defer tmp.cleanup();
    const folder = try tmp.dir.realpathAlloc(a, "."); defer a.free(folder);
    for ([_]tools.WallpaperMode{ .fit, .fill, .center, .stretch }) |mode| {
        const name = try std.fmt.allocPrint(a, "{s}.bmp", .{@tagName(mode)}); defer a.free(name);
        const p = try path(folder, name); defer a.free(p);
        try std.testing.expect(tools.writeWallpaper(&image, p, 12, 12, mode));
        var result = try load(p); defer result.close();
        try std.testing.expectEqual(@as(u32, 12), result.width);
        try std.testing.expectEqual(@as(u32, 12), result.height);
        if (mode == .fit) {
            try std.testing.expectEqual(@as(u32, 0xffffffff), try pixel(&result, 6, 1));
            try std.testing.expectEqual(@as(u32, 0xffff0000), try pixel(&result, 1, 5));
            try std.testing.expectEqual(@as(u32, 0xff0000ff), try pixel(&result, 10, 5));
            try std.testing.expectEqual(@as(u32, 0xffffffff), try pixel(&result, 6, 10));
        } else if (mode == .center) {
            try std.testing.expectEqual(@as(u32, 0xffffffff), try pixel(&result, 1, 5));
            try std.testing.expectEqual(@as(u32, 0xffff0000), try pixel(&result, 2, 4));
            try std.testing.expectEqual(@as(u32, 0xff0000ff), try pixel(&result, 9, 7));
            try std.testing.expectEqual(@as(u32, 0xffffffff), try pixel(&result, 10, 5));
        } else {
            try std.testing.expectEqual(@as(u32, 0xffff0000), try pixel(&result, 0, 0));
            try std.testing.expectEqual(@as(u32, 0xff0000ff), try pixel(&result, 11, 11));
        }
    }
    try std.testing.expectEqual(handle, image.handle);
    try std.testing.expectEqual(@as(u32, 0xffff0000), try pixel(&image, 0, 0));
    try std.testing.expectEqual(@as(u32, 0xff0000ff), try pixel(&image, 7, 3));
    var alpha = try bitmap(2, 2, 0x800000ff); defer alpha.close();
    const p = try path(folder, "alpha.bmp"); defer a.free(p);
    try std.testing.expect(tools.writeWallpaper(&alpha, p, 4, 4, .center));
    var result = try load(p); defer result.close();
    try std.testing.expectEqual(@as(u32, 0xff7f7fff), try pixel(&result, 1, 1));
    try std.testing.expectEqual(@as(u32, 0x800000ff), try pixel(&alpha, 0, 0));
    try std.testing.expect(!tools.writeWallpaper(&image, p, 0, 4, .fit));
}

test "wallpaper cache paths are bounded beside EXE and skip active slot" {
    var module: [260]u16 = undefined;
    const n = c.GetModuleFileNameW(null, &module, module.len);
    try std.testing.expect(n > 0 and n < module.len);
    const slash = std.mem.lastIndexOfScalar(u16, module[0..n], '\\') orelse return error.NoExeDirectory;
    var buffer: [260]u16 = undefined;
    const cache = tools.wallpaperCachePath(&buffer, w.L(""), 0) orelse return error.NoCachePath;
    try std.testing.expectEqualSlices(u16, module[0 .. slash + 1], cache[0 .. slash + 1]);
    try std.testing.expect(std.mem.endsWith(u16, cache, w.L("kadr-wallpaper-0.bmp")));
    var other: [260]u16 = undefined;
    try std.testing.expect(tools.wallpaperCachePath(&other, cache.ptr, 0) == null);
    try std.testing.expect(tools.wallpaperCachePath(&other, cache.ptr, 1) != null);
    try std.testing.expect(tools.wallpaperCachePath(&other, w.L(""), 8) == null);
}
