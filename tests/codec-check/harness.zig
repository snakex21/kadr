const std = @import("std");
const w = @import("../../src/win.zig");
const Image = @import("../../src/image.zig").Image;
const codecs = @import("../../src/codecs.zig");
const formats = @import("../../src/formats.zig");
const cases = @import("cases.zig");
extern "gdiplus" fn GdipBitmapGetPixel(*w.GpImage, i32, i32, *u32) callconv(.Stdcall) i32;
var checks: usize = 0;

fn log(comptime format: []const u8, args: anytype) void {
    var buffer: [1024]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, format, args) catch return;
    var written: u32 = 0;
    _ = w.c.WriteFile(w.c.GetStdHandle(w.c.STD_ERROR_HANDLE), text.ptr, @intCast(text.len), &written, null);
}
pub fn panic(message: []const u8, trace: ?*std.builtin.StackTrace, address: ?usize) noreturn {
    _ = trace;
    _ = address;
    log("panic: {s}\n", .{message});
    w.c.ExitProcess(2);
}
fn check(ok: bool, label: []const u8) !void {
    if (!ok) {
        log("FAIL: {s}\n", .{label});
        return error.CheckFailed;
    }
    checks += 1;
}
pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 0 }){};
    run(gpa.allocator()) catch |err| {
        log("codec harness failure: {s}\n", .{@errorName(err)});
        w.c.ExitProcess(1);
    };
    if (gpa.deinit() == .leak) w.c.ExitProcess(3);
    log("codecs: x86 harness PASS ({d} checks, {d} positive / {d} negative fixtures, no allocator leaks)\n", .{ checks, cases.good.len, cases.bad.len });
}
fn readBytes(allocator: std.mem.Allocator, path: [*:0]const u16) ![]u8 {
    const file = w.c.CreateFileW(path, w.c.GENERIC_READ, w.c.FILE_SHARE_READ, null, w.c.OPEN_EXISTING, w.c.FILE_ATTRIBUTE_NORMAL, null);
    if (file == null or file == @as(w.c.HANDLE, @ptrFromInt(std.math.maxInt(usize)))) return error.OpenFixture;
    defer _ = w.c.CloseHandle(file);
    var high: u32 = 0;
    const length = w.c.GetFileSize(file, &high);
    if (high != 0 or length > codecs.max_file_bytes) return error.FixtureSize;
    const bytes = try allocator.alloc(u8, length);
    errdefer allocator.free(bytes);
    var read: u32 = 0;
    if (w.c.ReadFile(file, bytes.ptr, length, &read, null) == 0 or read != length) return error.ReadFixture;
    return bytes;
}
fn pixel(image: *Image, x: u32, y: u32) !u32 {
    var color: u32 = 0;
    if (GdipBitmapGetPixel(image.handle.?, @intCast(x), @intCast(y), &color) != 0) return error.GetPixel;
    return color;
}
fn mustFail(allocator: std.mem.Allocator, codec: formats.Codec, bytes: []const u8) !void {
    if (codecs.decode(allocator, codec, bytes)) |value| {
        var raster = value;
        raster.deinit();
        try check(false, "malformed/truncated input accepted");
    } else |_| checks += 1;
}
fn registry() !void {
    const accepted = .{ "png", "jpg", "jpeg", "jpe", "jfif", "jif", "bmp", "dib", "gif", "tif", "tiff", "ico", "wmf", "emf", "djvu", "djv", "tga", "targa", "pcx", "psd", "pnm", "pbm", "pgm", "ppm", "qoi" };
    inline for (accepted) |extension| try check(formats.supported(w.L("C:/zażółć/photo." ++ extension)), "registry extension");
    const rejected = .{ "photo.webp", "photo.avif", "photo.heic", "photo.raw", "photo.pdf", "photo.qoi.tmp", "dir.qoi/photo", "photo.", "photo", "photo.ｑｏｉ", "" };
    inline for (rejected) |path| try check(!formats.supported(w.L(path)), "registry does not advertise missing decoders");
    try check(formats.supported(w.L("C:/漢字/ZAŻÓŁĆ.TaRgA")), "case-insensitive Unicode path");
    try check(formats.supported(w.L("C:/JPEG.JFIF")) and formats.supported(w.L("C:/JPEG.JIF")), "JPEG aliases");
    const filter = formats.filter;
    var pos: usize = 0;
    while (pos < 4096 and filter[pos] != 0) : (pos += 1) {}
    try check(pos < 4096, "dialog label terminator");
    pos += 1;
    var begin = pos;
    var patterns: usize = 0;
    while (pos < 4096) : (pos += 1) {
        if (filter[pos] == ';' or filter[pos] == 0) {
            const pattern = filter[begin..pos];
            try check(pattern.len > 2 and pattern[0] == '*' and pattern[1] == '.' and formats.supported(pattern), "filter/registry agree");
            patterns += 1;
            begin = pos + 1;
            if (filter[pos] == 0) break;
        }
    }
    try check(patterns == accepted.len, "filter includes every advertised extension");
    pos += 1;
    var groups: usize = 0;
    while (pos < 4096 and filter[pos] != 0) {
        while (pos < 4096 and filter[pos] != 0) : (pos += 1) {}
        pos += 1;
        begin = pos;
        while (pos < 4096 and filter[pos] != 0) : (pos += 1) {}
        if (pos >= 4096) return error.InvalidFilter;
        const group = filter[begin..pos];
        if (std.mem.eql(u16, group, w.L("*.*"))) {
            try check(filter[pos + 1] == 0, "all-files last and double NUL");
        } else {
            var start: usize = 0;
            for (0..group.len + 1) |end| {
                if (end == group.len or group[end] == ';') {
                    try check(formats.supported(group[start..end]), "grouped filter advertises only supported extensions");
                    start = end + 1;
                }
            }
        }
        pos += 1;
        groups += 1;
    }
    try check(groups == 14, "thirteen format groups and all-files");
}
fn fileLimit(image: *Image) !void {
    const path = w.L("tests/codec-check/oversize-temporary.qoi");
    const file = w.c.CreateFileW(path, w.c.GENERIC_WRITE, 0, null, w.c.CREATE_ALWAYS, w.c.FILE_ATTRIBUTE_TEMPORARY, null);
    if (file == null or file == @as(w.c.HANDLE, @ptrFromInt(std.math.maxInt(usize)))) return error.CreateLimitFixture;
    defer _ = w.c.DeleteFileW(path);
    {
        defer _ = w.c.CloseHandle(file);
        // The temporary file is removed even when a check fails; no large
        // fixture is retained in the repo and no decode allocation is made.
        try check(w.c.SetFilePointer(file, codecs.max_file_bytes, null, w.c.FILE_BEGIN) == codecs.max_file_bytes and w.c.SetEndOfFile(file) != 0, "create boundary-sized input");
    }
    try check(!image.load(path), "128 MiB random/empty input rejected");
    const append = w.c.CreateFileW(path, w.c.GENERIC_WRITE, 0, null, w.c.OPEN_EXISTING, w.c.FILE_ATTRIBUTE_TEMPORARY, null);
    if (append == null or append == @as(w.c.HANDLE, @ptrFromInt(std.math.maxInt(usize)))) return error.CreateLimitFixture;
    {
        defer _ = w.c.CloseHandle(append);
        try check(w.c.SetFilePointer(append, codecs.max_file_bytes + 1, null, w.c.FILE_BEGIN) == codecs.max_file_bytes + 1 and w.c.SetEndOfFile(append) != 0, "create over-limit input");
    }
    try check(!image.load(path) and image.handle == null and image._pixels.len == 0, "input byte limit and failure reset");
}
fn exifOrientation(image: *Image) !void {
    var base: Image = .{};
    defer base.close();
    try check(base.load(w.L("tests/codec-check/fixtures/exif-base.jpg")), "EXIF reference JPEG");
    var expected: [6]u32 = undefined;
    for (&expected, 0..) |*color, i| color.* = try pixel(&base, @intCast(i % 3), @intCast(i / 3));
    inline for (1..10) |orientation| {
        try check(image.load(w.L("tests/codec-check/fixtures/exif-" ++ std.fmt.comptimePrint("{d}", .{orientation}) ++ ".jpg")), "EXIF JPEG load");
        const swapped = orientation >= 5 and orientation <= 8;
        try check(image.width == (if (swapped) @as(u32, 2) else 3) and image.height == (if (swapped) @as(u32, 3) else 2), "EXIF oriented dimensions");
        for (expected, 0..) |color, i| {
            const x: u32 = @intCast(i % 3);
            const y: u32 = @intCast(i / 3);
            const dest: [2]u32 = switch (orientation) {
                2 => .{ 2 - x, y }, 3 => .{ 2 - x, 1 - y },
                4 => .{ x, 1 - y }, 5 => .{ y, x },
                6 => .{ 1 - y, x }, 7 => .{ 1 - y, 2 - x },
                8 => .{ y, 2 - x }, else => .{ x, y },
            };
            try check(try pixel(image, dest[0], dest[1]) == color, "all eight EXIF transformations; invalid value ignored");
        }
    }
    try check(image.load(w.L("tests/codec-check/fixtures/exif-alias.JFIF")) and image.width == 2 and image.height == 3, "EXIF applies to uppercase JFIF alias");
    image.close();
}
fn run(allocator: std.mem.Allocator) !void {
    try registry();
    var token: usize = 0;
    if (w.GdiplusStartup(&token, &w.StartupInput{}, null) != 0) return error.GdiplusStartup;
    defer w.GdiplusShutdown(token);
    var image: Image = .{};
    defer image.close();
    try check(!image.load(w.L("tests/codec-check/fixtures/missing.qoi")), "missing native file");
    var before: u32 = 0;
    try check(w.c.GetProcessHandleCount(w.c.GetCurrentProcess(), &before) != 0, "initial handle count");
    for (cases.good, 0..) |case, n| {
        log("native case {d}: {s} {d}x{d}\n", .{ n + 1, @tagName(case.codec), case.width, case.height });
        const bytes = try readBytes(allocator, case.path);
        defer allocator.free(bytes);
        try check(formats.codec(std.mem.span(case.path)).? == case.codec, "native dispatch");
        var raster = try codecs.decode(allocator, case.codec, bytes);
        defer raster.deinit();
        try check(raster.width == case.width and raster.height == case.height, "raster dimensions");
        for (case.pixels, 0..) |color, i| try check(std.mem.readIntLittle(u32, raster.pixels[i * 4 ..][0..4]) == color, "exact native BGRA pixel/alpha");
        try check(image.load(case.path), "Image.load native format");
        try check(image.width == case.width and image.height == case.height and image._pixels.len == case.width * case.height * 4 and image.pages == 1 and image.frames == 1 and !image.animated and !image.is_djvu, "public Image fields and retained buffer");
        for (case.pixels, 0..) |color, i| {
            const actual = try pixel(&image, @intCast(i % case.width), @intCast(i / case.width));
            if (actual != color) log("pixel {d}: actual={x:0>8}, expected={x:0>8}\n", .{ i, actual, color });
            try check(actual == color, "GDI+ pixel/straight alpha/channel order");
        }
        try check(image.setPage(0) and !image.setPage(1) and image.nextFrame() == 0, "static navigation bounds");
        image.rotate();
        try check(image.width == case.height and image.height == case.width, "native bitmap rotation dimensions");
        for (case.pixels, 0..) |color, i| {
            try check(try pixel(&image, case.height - 1 - @as(u32, @intCast(i / case.width)), @intCast(i % case.width)) == color, "rotated pixel/backing ownership");
        }
        image.rotate(); image.rotate(); image.rotate();
        try check(image.width == case.width and image.height == case.height, "four rotations restore native dimensions");
        image.close(); image.close();
        try check(image.handle == null and image._pixels.len == 0 and image.width == 0 and image.pages == 1, "idempotent native cleanup");
        var empty: [0]u8 = .{};
        var fixed = std.heap.FixedBufferAllocator.init(&empty);
        if (codecs.decode(fixed.allocator(), case.codec, bytes)) |unexpected| {
            var value = unexpected;
            value.deinit();
            try check(false, "allocation failure was not propagated");
        } else |err| try check(err == error.OutOfMemory, "out-of-memory decode cleanup");
        if (case.codec == .pcx) {
            // Output fits, but the second (row) allocation must fail and free it.
            const memory = try allocator.alloc(u8, raster.pixels.len);
            defer allocator.free(memory);
            var exact = std.heap.FixedBufferAllocator.init(memory);
            if (codecs.decode(exact.allocator(), .pcx, bytes)) |unexpected| {
                var value = unexpected;
                value.deinit();
                try check(false, "PCX row allocation failure was not propagated");
            } else |err| try check(err == error.OutOfMemory and exact.end_index == 0, "PCX partial allocation cleanup");
        }
        if (case.strict) {
            for (0..bytes.len) |cut| try mustFail(allocator, case.codec, bytes[0..cut]);
        }
    }
    for (cases.bad) |path| {
        const bytes = try readBytes(allocator, path);
        defer allocator.free(bytes);
        const codec = formats.codec(std.mem.span(path)).?;
        try mustFail(allocator, codec, bytes);
        try check(!image.load(path), "Image rejects malformed/unsupported/oversized native input");
        try check(image.handle == null and image._pixels.len == 0 and image.width == 0 and image.frames == 1 and image.pages == 1 and !image.animated, "decode failure leaves default Image");
    }
    const aliases = .{ "jfif", "jif", "jpe", "dib" };
    inline for (aliases) |extension| {
        try check(image.load(w.L("tests/codec-check/fixtures/alias." ++ extension)), "GDI-supported alias actually loads");
        try check(image.width == 3 and image.height == 2, "alias dimensions");
        image.close();
    }
    try exifOrientation(&image);
    try fileLimit(&image);
    var after: u32 = 0;
    try check(w.c.GetProcessHandleCount(w.c.GetCurrentProcess(), &after) != 0, "warm handle count");
    log("GDI+ lazy initialization handles: {d} -> {d}; measuring steady state\n", .{ before, after });
    before = after;
    for (0..16) |_| {
        for (cases.good) |case| {
            try check(image.load(case.path), "repeated native load");
            image.close();
        }
        for (cases.bad) |path| try check(!image.load(path), "repeated malformed native load");
    }
    try check(w.c.GetProcessHandleCount(w.c.GetCurrentProcess(), &after) != 0 and after <= before, "steady-state native loads do not accumulate handles");
}
