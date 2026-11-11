// Image export and clipboard backend. SPDX-License-Identifier: GPL-3.0-or-later
//! Call after GdiplusStartup, on the same thread as other access to the Image.
//! Snapshots are owned Images: close them before GdiplusShutdown. Only the
//! currently visible frame/page is exported, never a viewport or source metadata.
const std = @import("std");
const w = @import("win.zig");
const c = w.c;
const Image = @import("image.zig").Image;

pub const Format = enum { png, jpeg, bmp, tiff, gif };

extern "gdiplus" fn GdipCreateBitmapFromScan0(i32, i32, i32, i32, ?[*]u8, *?*w.GpImage) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipGetImageGraphicsContext(*w.GpImage, *?*w.GpGraphics) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipGraphicsClear(*w.GpGraphics, u32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipSetCompositingMode(*w.GpGraphics, i32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipSetPixelOffsetMode(*w.GpGraphics, i32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipDrawImageRectRectI(*w.GpGraphics, *w.GpImage, i32, i32, i32, i32, i32, i32, i32, i32, i32, ?*anyopaque, ?*anyopaque, ?*anyopaque) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipBitmapLockBits(*w.GpImage, *const Rect, u32, i32, *BitmapData) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipBitmapUnlockBits(*w.GpImage, *BitmapData) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipSaveImageToFile(*w.GpImage, [*:0]const u16, *const w.Guid, ?*const EncoderParameters) callconv(.Stdcall) i32;
const ImageAttributes = opaque {};
extern "gdiplus" fn GdipCreateImageAttributes(*?*ImageAttributes) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipSetImageAttributesWrapMode(*ImageAttributes, i32, u32, i32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipDisposeImageAttributes(*ImageAttributes) callconv(.Stdcall) i32;

const pixel_format_32bpp_argb = 0x0026200a;
const Rect = extern struct { x: i32, y: i32, width: i32, height: i32 };
const BitmapData = extern struct {
    width: u32,
    height: u32,
    stride: i32,
    pixel_format: i32,
    scan0: ?[*]u8,
    reserved: usize,
};
const EncoderParameter = extern struct {
    guid: w.Guid,
    count: u32,
    kind: u32,
    value: *const anyopaque,
};
const EncoderParameters = extern struct { count: u32, parameter: [1]EncoderParameter };
const encoder_quality = w.Guid{ .a = 0x1d5be4b5, .b = 0xfa4a, .c = 0x452d, .d = .{ 0x9c, 0xdd, 0x5d, 0xb3, 0x51, 0x05, 0xe7, 0xeb } };

/// Recognizes only the supported filename suffixes (ASCII case-insensitive).
pub fn format(path: []const u16) ?Format {
    const extensions = [_]struct { suffix: []const u8, kind: Format }{
        .{ .suffix = ".png", .kind = .png },
        .{ .suffix = ".jpg", .kind = .jpeg },
        .{ .suffix = ".jpeg", .kind = .jpeg },
        .{ .suffix = ".jpe", .kind = .jpeg },
        .{ .suffix = ".bmp", .kind = .bmp },
        .{ .suffix = ".tif", .kind = .tiff },
        .{ .suffix = ".tiff", .kind = .tiff },
        .{ .suffix = ".gif", .kind = .gif },
    };
    for (extensions) |extension| {
        if (path.len < extension.suffix.len) continue;
        const tail = path[path.len - extension.suffix.len ..];
        for (tail, extension.suffix) |wide, ascii| {
            const lower = if (wide >= 'A' and wide <= 'Z') wide + ('a' - 'A') else wide;
            if (lower != ascii) break;
        } else return extension.kind;
    }
    return null;
}

const Size = struct { width: i32, height: i32, row_bytes: usize, pixel_bytes: usize };
fn sizeOf(source: *const Image) ?Size {
    if (source.width == 0 or source.height == 0 or source.width > std.math.maxInt(i32) or source.height > std.math.maxInt(i32)) return null;
    const row_bytes = std.math.mul(usize, source.width, 4) catch return null;
    if (row_bytes > std.math.maxInt(i32)) return null;
    const pixel_bytes = std.math.mul(usize, row_bytes, source.height) catch return null;
    if (pixel_bytes > std.math.maxInt(u32)) return null;
    return .{ .width = @intCast(source.width), .height = @intCast(source.height), .row_bytes = row_bytes, .pixel_bytes = pixel_bytes };
}

/// Renders into fresh GDI+-owned storage, breaking file/stream/backing-buffer
/// dependencies. Physical rotation is already in source.handle; no EXIF
/// orientation, animation, page state, or other metadata is copied.
pub fn snapshot(source: *const Image) ?Image {
    return renderSize(source, source.width, source.height);
}

/// Custom exports are bounded independently of the legacy, unscaled save API.
/// All dimensions are positive integer pixels; invalid values are never clamped.
pub const max_export_pixels: u64 = 64_000_000;
pub const ExportOptions = struct {
    width: u32,
    height: u32,
    jpeg_quality: u32 = 90,
};

pub fn validExportDimensions(width: u32, height: u32) bool {
    if (width == 0 or height == 0 or @as(u64, width) * height > max_export_pixels) return false;
    return sizeOf(&Image{ .width = width, .height = height }) != null;
}

pub fn validOptions(source: *const Image, options: ExportOptions) bool {
    return source.handle != null and sizeOf(source) != null and
        validExportDimensions(options.width, options.height) and
        options.jpeg_quality >= 1 and options.jpeg_quality <= 100;
}

/// Rounded aspect-ratio companion dimension, using checked integer arithmetic.
/// Zero and unrepresentable results are errors, not silently changed to one.
pub fn aspectDimension(changed: u32, original_changed: u32, original_other: u32) ?u32 {
    if (changed == 0 or original_changed == 0 or original_other == 0) return null;
    const product = @as(u64, changed) * original_other;
    const rounded = (product + original_changed / 2) / original_changed;
    if (rounded == 0 or rounded > std.math.maxInt(u32)) return null;
    return @intCast(rounded);
}

/// A private, alpha-preserving bitmap; rotations already baked in the handle
/// are resampled as seen, without copying Image ownership or source metadata.
pub fn scaledSnapshot(source: *const Image, width: u32, height: u32) ?Image {
    if (!validExportDimensions(width, height)) return null;
    return renderSize(source, width, height);
}

fn renderSize(source: *const Image, width: u32, height: u32) ?Image {
    const handle = source.handle orelse return null;
    const size = sizeOf(source) orelse return null;
    var result = Image{ .width = width, .height = height };
    const target = sizeOf(&result) orelse return null;
    var success = false;
    defer if (!success) result.close();
    if (GdipCreateBitmapFromScan0(target.width, target.height, 0, pixel_format_32bpp_argb, null, &result.handle) != 0) return null;
    const bitmap = result.handle orelse return null;
    var graphics: ?*w.GpGraphics = null;
    defer if (graphics) |g| {
        _ = w.GdipDeleteGraphics(g);
    };
    if (GdipGetImageGraphicsContext(bitmap, &graphics) != 0) return null;
    const g = graphics orelse return null;
    // Explicit pixel units/bounds avoid source DPI scaling. Nearest-neighbor
    // at 1:1 avoids interpolation fringes; SourceCopy retains the alpha plane.
    const unscaled = width == source.width and height == source.height;
    var attributes: ?*ImageAttributes = null;
    defer if (attributes) |a| { _ = GdipDisposeImageAttributes(a); };
    if (!unscaled) {
        if (GdipCreateImageAttributes(&attributes) != 0 or attributes == null) return null;
        // Mirror edge pixels: bicubic sampling must not invent transparent rims.
        if (GdipSetImageAttributesWrapMode(attributes.?, 3, 0, 0) != 0) return null;
    }
    if (w.GdipSetPageUnit(g, 2) != 0 or
        w.GdipSetInterpolationMode(g, if (unscaled) 5 else 7) != 0 or
        GdipSetPixelOffsetMode(g, 4) != 0 or
        GdipGraphicsClear(g, 0) != 0 or
        GdipSetCompositingMode(g, 1) != 0) return null;
    if (GdipDrawImageRectRectI(g, handle, 0, 0, target.width, target.height, 0, 0, size.width, size.height, 2, attributes, null, null) != 0) return null;
    success = true;
    return result;
}

fn encoder(kind: Format) w.Guid {
    return .{
        .a = switch (kind) {
            .bmp => 0x557cf400,
            .jpeg => 0x557cf401,
            .gif => 0x557cf402,
            .tiff => 0x557cf405,
            .png => 0x557cf406,
        },
        .b = 0x1a04,
        .c = 0x11d3,
        .d = .{ 0x9a, 0x73, 0x00, 0x00, 0xf8, 0x1e, 0xf3, 0x2e },
    };
}

/// Writes a single-frame image to the caller's private temporary file, including
/// an empty file already reserved by GetTempFileNameW. Never pass an original:
/// the caller handles confirmation and atomic replacement after successful export.
pub fn save(source: *const Image, path: [*:0]const u16, kind: Format) bool {
    if (source.handle == null or path[0] == 0) return false;
    var bitmap = snapshot(source) orelse return false;
    defer bitmap.close();
    return encodePrivate(&bitmap, path, kind, 92);
}

/// Same temporary-file contract as save(), with explicit resize and JPEG
/// quality (default 90). The legacy save() remains unrestricted and quality 92.
pub fn saveOptions(source: *const Image, path: [*:0]const u16, kind: Format, options: ExportOptions) bool {
    if (path[0] == 0 or !validOptions(source, options)) return false;
    var bitmap = scaledSnapshot(source, options.width, options.height) orelse return false;
    defer bitmap.close();
    return encodePrivate(&bitmap, path, kind, options.jpeg_quality);
}

fn encodePrivate(bitmap: *Image, path: [*:0]const u16, kind: Format, quality: u32) bool {
    // JPEG has no alpha channel. Flatten the private copy, never the source.
    if (kind == .jpeg and !flattenWhite(bitmap)) return false;
    const clsid = encoder(kind);
    const parameters = EncoderParameters{
        .count = 1,
        .parameter = .{.{
            .guid = encoder_quality,
            .count = 1,
            .kind = 4, // EncoderParameterValueTypeLong (ULONG, including on x86).
            .value = &quality,
        }},
    };
    return GdipSaveImageToFile(bitmap.handle.?, path, &clsid, if (kind == .jpeg) &parameters else null) == 0;
}

fn lockPixels(bitmap: *const Image, flags: u32) ?BitmapData {
    const handle = bitmap.handle orelse return null;
    const size = sizeOf(bitmap) orelse return null;
    const rect = Rect{ .x = 0, .y = 0, .width = size.width, .height = size.height };
    var data = std.mem.zeroes(BitmapData);
    if (GdipBitmapLockBits(handle, &rect, flags, pixel_format_32bpp_argb, &data) != 0) return null;
    const stride: usize = @intCast(if (data.stride < 0) -@as(i64, data.stride) else data.stride);
    const length = std.math.mul(usize, stride, bitmap.height) catch 0;
    if (data.scan0 == null or data.width != bitmap.width or data.height != bitmap.height or
        stride < size.row_bytes or length == 0)
    {
        _ = GdipBitmapUnlockBits(handle, &data);
        return null;
    }
    return data;
}

fn pixelRow(data: *const BitmapData, y: u32) [*]u8 {
    const base = @intFromPtr(data.scan0.?);
    const stride: usize = @intCast(if (data.stride < 0) -@as(i64, data.stride) else data.stride);
    const offset = stride * @as(usize, y);
    return @ptrFromInt(if (data.stride < 0) base - offset else base + offset);
}

// LockBits requests straight (not premultiplied) BGRA. Round the composite
// over white to the nearest byte, and make the unused DIB alpha byte opaque.
fn whitePixel(pixel: []u8) void {
    const alpha: u32 = pixel[3];
    for (pixel[0..3]) |*channel| {
        channel.* = @intCast((@as(u32, channel.*) * alpha + 255 * (255 - alpha) + 127) / 255);
    }
    pixel[3] = 255;
}

fn flattenWhite(bitmap: *const Image) bool {
    const size = sizeOf(bitmap) orelse return false;
    var data = lockPixels(bitmap, 3) orelse return false; // ImageLockModeRead | Write
    var y: u32 = 0;
    while (y < bitmap.height) : (y += 1) {
        const row = pixelRow(&data, y)[0..size.row_bytes];
        var x: usize = 0;
        while (x < row.len) : (x += 4) whitePixel(row[x..][0..4]);
    }
    return GdipBitmapUnlockBits(bitmap.handle.?, &data) == 0;
}

fn writeDib(memory: c.HGLOBAL, bitmap: *const Image, size: Size) bool {
    const address = c.GlobalLock(memory) orelse return false;
    defer _ = c.GlobalUnlock(memory);
    const header: *c.BITMAPINFOHEADER = @ptrCast(@alignCast(address));
    header.* = std.mem.zeroes(c.BITMAPINFOHEADER);
    header.biSize = @sizeOf(c.BITMAPINFOHEADER);
    header.biWidth = size.width;
    header.biHeight = size.height; // Positive height: bottom-up, widely supported CF_DIB.
    header.biPlanes = 1;
    header.biBitCount = 32;
    header.biCompression = c.BI_RGB;
    header.biSizeImage = @intCast(size.pixel_bytes);
    const pixels = @as([*]u8, @ptrCast(address)) + @sizeOf(c.BITMAPINFOHEADER);
    var data = lockPixels(bitmap, 1) orelse return false; // ImageLockModeRead
    var y: u32 = 0;
    while (y < bitmap.height) : (y += 1) {
        const row = (pixels + @as(usize, bitmap.height - 1 - y) * size.row_bytes)[0..size.row_bytes];
        @memcpy(row, pixelRow(&data, y)[0..size.row_bytes]);
        var x: usize = 0;
        while (x < row.len) : (x += 4) whitePixel(row[x..][0..4]);
    }
    return GdipBitmapUnlockBits(bitmap.handle.?, &data) == 0;
}

// Returns an unlocked movable allocation; the caller owns it until a
// successful SetClipboardData. Preparing it first leaves the clipboard alone
// on allocation/rendering failures and keeps OpenClipboard's duration short.
fn clipboardDib(source: *const Image) c.HGLOBAL {
    var bitmap = snapshot(source) orelse return null;
    defer bitmap.close();
    const size = sizeOf(&bitmap) orelse return null;
    const total = std.math.add(usize, @sizeOf(c.BITMAPINFOHEADER), size.pixel_bytes) catch return null;
    const memory = c.GlobalAlloc(c.GMEM_MOVEABLE, total) orelse return null;
    var success = false;
    defer if (!success) {
        _ = c.GlobalFree(memory);
    };
    if (!writeDib(memory, &bitmap, size)) return null;
    success = true;
    return memory;
}

/// Publishes a full, white-flattened 32-bit BI_RGB CF_DIB. Requires a real owner
/// window: EmptyClipboard with a null owner prevents SetClipboardData on XP.
pub fn copyClipboard(owner: c.HWND, source: *const Image) bool {
    if (owner == null) return false;
    const memory = clipboardDib(source) orelse return false;
    var transferred = false;
    defer if (!transferred) {
        _ = c.GlobalFree(memory);
    };
    if (c.OpenClipboard(owner) == 0) return false;
    defer _ = c.CloseClipboard();
    if (c.EmptyClipboard() == 0) return false;
    if (c.SetClipboardData(c.CF_DIB, memory) == null) return false;
    transferred = true; // Windows now owns memory; never GlobalFree it here.
    return true;
}

test "output suffixes are ASCII case-insensitive and must terminate the path" {
    const cases = [_]struct { path: []const u16, kind: ?Format }{
        .{ .path = w.L("photo.png"), .kind = .png },
        .{ .path = w.L("C:\\Zdjęcia\\Żółw.PnG"), .kind = .png },
        .{ .path = w.L("x.JPG"), .kind = .jpeg },
        .{ .path = w.L("x.JpEg"), .kind = .jpeg },
        .{ .path = w.L("x.jPe"), .kind = .jpeg },
        .{ .path = w.L("x.BmP"), .kind = .bmp },
        .{ .path = w.L("x.TIF"), .kind = .tiff },
        .{ .path = w.L("x.tIfF"), .kind = .tiff },
        .{ .path = w.L("x.GiF"), .kind = .gif },
        .{ .path = w.L(".png"), .kind = .png },
        .{ .path = w.L(""), .kind = null },
        .{ .path = w.L("png"), .kind = null },
        .{ .path = w.L("x.webp"), .kind = null },
        .{ .path = w.L("x.png.bak"), .kind = null },
        .{ .path = w.L("x.png "), .kind = null },
        .{ .path = w.L("x.png\\child"), .kind = null },
        .{ .path = w.L("x.ｐｎｇ"), .kind = null },
    };
    for (cases) |case| try std.testing.expectEqual(case.kind, format(case.path));
}

test "empty image paths are safe without GDI+ or clipboard initialization" {
    const empty = Image{};
    try std.testing.expect(snapshot(&empty) == null);
    try std.testing.expect(!save(&empty, w.L("not-created.png"), .png));
    try std.testing.expect(!save(&empty, w.L(""), .jpeg));
    try std.testing.expect(!copyClipboard(null, &empty));
    try std.testing.expect(clipboardDib(&empty) == null);
    try std.testing.expect(sizeOf(&Image{ .width = 0xffffffff, .height = 1 }) == null);
    try std.testing.expect(sizeOf(&Image{ .width = 65536, .height = 65536 }) == null);
}

// These tests exercise the real XP-era GDI+ and global-memory paths, but do
// not open or change the system clipboard and do not use repository fixtures.
extern "gdiplus" fn GdipBitmapSetPixel(*w.GpImage, i32, i32, u32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipBitmapGetPixel(*w.GpImage, i32, i32, *u32) callconv(.Stdcall) i32;

fn testBitmap(width: u32, height: u32) !Image {
    var bitmap = Image{ .width = width, .height = height };
    errdefer bitmap.close();
    try std.testing.expectEqual(@as(i32, 0), GdipCreateBitmapFromScan0(@intCast(width), @intCast(height), 0, pixel_format_32bpp_argb, null, &bitmap.handle));
    try std.testing.expect(bitmap.handle != null);
    return bitmap;
}

fn testPixel(bitmap: *const Image, x: i32, y: i32, expected: u32) !void {
    var value: u32 = 0;
    try std.testing.expectEqual(@as(i32, 0), GdipBitmapGetPixel(bitmap.handle.?, x, y, &value));
    try std.testing.expectEqual(expected, value);
}

test "snapshot detaches rotated pixels and DIB is bottom-up opaque white" {
    var token: usize = 0;
    try std.testing.expectEqual(@as(i32, 0), w.GdiplusStartup(&token, &w.StartupInput{}, null));
    defer w.GdiplusShutdown(token);
    var original = try testBitmap(3, 2);
    defer original.close();
    const colors = [_]u32{ 0x00000000, 0xffff0000, 0x800000ff, 0xff00ff00, 0xffffffff, 0xff000000 };
    for (colors, 0..) |color, i| {
        try std.testing.expectEqual(@as(i32, 0), GdipBitmapSetPixel(original.handle.?, @intCast(i % 3), @intCast(i / 3), color));
    }
    original.rotate();
    var detached = snapshot(&original) orelse return error.SnapshotFailed;
    defer detached.close();
    try std.testing.expect(detached.handle != original.handle);
    original.close();
    try std.testing.expectEqual(@as(u32, 2), detached.width);
    try std.testing.expectEqual(@as(u32, 3), detached.height);
    try std.testing.expect(detached._pixels.len == 0 and detached._stream == null);
    try testPixel(&detached, 0, 0, 0xff00ff00);
    try testPixel(&detached, 1, 0, 0x00000000);
    try testPixel(&detached, 1, 1, 0xffff0000);
    try testPixel(&detached, 1, 2, 0x800000ff);
    var property_size: u32 = 0;
    try std.testing.expect(w.GdipGetPropertyItemSize(detached.handle.?, 0x0112, &property_size) != 0);
    const memory = clipboardDib(&detached) orelse return error.DibFailed;
    defer _ = c.GlobalFree(memory);
    const address = c.GlobalLock(memory) orelse return error.GlobalLockFailed;
    defer _ = c.GlobalUnlock(memory);
    const header: *const c.BITMAPINFOHEADER = @ptrCast(@alignCast(address));
    try std.testing.expectEqual(@as(c.LONG, 2), header.biWidth);
    try std.testing.expectEqual(@as(c.LONG, 3), header.biHeight);
    try std.testing.expectEqual(@as(c.WORD, 32), header.biBitCount);
    try std.testing.expectEqual(@as(c.DWORD, 24), header.biSizeImage);
    const bytes = (@as([*]const u8, @ptrCast(address)) + @sizeOf(c.BITMAPINFOHEADER))[0..24];
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 255, 255, 127, 127, 255 }, bytes[0..8]);
    try std.testing.expectEqualSlices(u8, &.{ 0, 255, 0, 255, 255, 255, 255, 255 }, bytes[16..24]);
    try testPixel(&detached, 1, 2, 0x800000ff); // DIB preparation did not flatten the source.
}

test "all encoders save independently; PNG alpha and JPEG white survive reload" {
    var token: usize = 0;
    try std.testing.expectEqual(@as(i32, 0), w.GdiplusStartup(&token, &w.StartupInput{}, null));
    defer w.GdiplusShutdown(token);
    var bitmap = try testBitmap(2, 3);
    defer bitmap.close();
    // Uniform half-transparent blue makes JPEG white compositing measurable
    // without chroma-subsampling artifacts from adjacent different colors.
    var y: i32 = 0;
    while (y < 3) : (y += 1) {
        var x: i32 = 0;
        while (x < 2) : (x += 1) {
            try std.testing.expectEqual(@as(i32, 0), GdipBitmapSetPixel(bitmap.handle.?, x, y, 0x800000ff));
        }
    }
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    const directory = try temporary.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(directory);
    const cases = [_]struct { name: []const u8, kind: Format }{
        .{ .name = "output.png", .kind = .png },
        .{ .name = "output.jpg", .kind = .jpeg },
        .{ .name = "output.bmp", .kind = .bmp },
        .{ .name = "output.tiff", .kind = .tiff },
        .{ .name = "output.gif", .kind = .gif },
    };
    for (cases) |case| {
        const path = try std.fs.path.join(std.testing.allocator, &.{ directory, case.name });
        defer std.testing.allocator.free(path);
        const wide = try std.unicode.utf8ToUtf16LeWithNull(std.testing.allocator, path);
        defer std.testing.allocator.free(wide);
        // Match the GUI's reserved GetTempFileNameW path, not just a fresh name.
        const reserved = try temporary.dir.createFile(case.name, .{});
        reserved.close();
        try std.testing.expect(save(&bitmap, wide, case.kind));
        var loaded = Image{};
        defer loaded.close();
        try std.testing.expectEqual(@as(i32, 0), w.GdipLoadImageFromFile(wide, &loaded.handle));
        try std.testing.expect(loaded.handle != null);
        try std.testing.expectEqual(@as(i32, 0), w.GdipGetImageWidth(loaded.handle.?, &loaded.width));
        try std.testing.expectEqual(@as(i32, 0), w.GdipGetImageHeight(loaded.handle.?, &loaded.height));
        try std.testing.expectEqual(bitmap.width, loaded.width);
        try std.testing.expectEqual(bitmap.height, loaded.height);
        if (case.kind == .png) try testPixel(&loaded, 0, 0, 0x800000ff);
        if (case.kind == .jpeg) {
            var pixel: u32 = 0;
            try std.testing.expectEqual(@as(i32, 0), GdipBitmapGetPixel(loaded.handle.?, 0, 0, &pixel));
            try std.testing.expect(pixel >> 24 == 255);
            try std.testing.expect((pixel & 255) >= 250);
            try std.testing.expect(((pixel >> 8) & 255) >= 124 and ((pixel >> 8) & 255) <= 130);
            try std.testing.expect(((pixel >> 16) & 255) >= 124 and ((pixel >> 16) & 255) <= 130);
        }
        var independent = snapshot(&loaded) orelse return error.SnapshotFailed;
        defer independent.close();
        loaded.close();
        try temporary.dir.deleteFile(case.name); // No GDI+ file lock remains in the snapshot.
        if (case.kind == .png) try testPixel(&independent, 0, 0, 0x800000ff);
    }
    try testPixel(&bitmap, 0, 0, 0x800000ff); // JPEG save did not flatten the original.
}
