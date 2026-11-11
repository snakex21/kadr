//! GDI+ owns ordinary images; DjVu/native rasters retain their backing buffers.
//! Call after GdiplusStartup, and close all Images before GdiplusShutdown.
//! Image owns its resources: do not copy a loaded Image by value.
const std = @import("std");
const w = @import("win.zig");
const djvu = @import("djvu.zig");
const formats = @import("formats.zig");
const codecs = @import("codecs.zig");
const allocator = std.heap.page_allocator;

extern "gdiplus" fn GdipCreateBitmapFromScan0(i32, i32, i32, i32, ?[*]u8, *?*w.GpImage) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipCreateBitmapFromHICON(w.c.HICON, *?*w.GpImage) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipLoadImageFromStream(*Stream, *?*w.GpImage) callconv(.Stdcall) i32;
extern "ole32" fn CreateStreamOnHGlobal(w.c.HGLOBAL, w.c.BOOL, *?*Stream) callconv(.Stdcall) w.c.HRESULT;
const Stream = extern struct {
    vtable: *const extern struct {
        query_interface: *const anyopaque,
        add_ref: *const anyopaque,
        release: *const fn (*Stream) callconv(.Stdcall) u32,
    },
};
const pixel_format_32bpp_rgb = 0x00022009;
const pixel_format_32bpp_argb = 0x0026200a;
const frame_delay_property = 0x5100;
const max_frames: u32 = 100000;
const default_delay_ms: u32 = 100;

pub const Image = struct {
    handle: ?*w.GpImage = null,
    width: u32 = 0,
    height: u32 = 0,
    frame: u32 = 0,
    frames: u32 = 1,
    page: u32 = 0,
    pages: u32 = 1,
    animated: bool = false,
    is_djvu: bool = false,

    _delays: []u32 = &.{},
    _pixels: []u8 = &.{},
    _stream: ?*Stream = null,
    _document: djvu.Document = .{},

    pub fn load(self: *Image, path: [*:0]const u16) bool {
        self.close();
        if (hasExtension(path, ".djvu") or hasExtension(path, ".djv")) {
            if (!self._document.open(path)) return false;
            self.is_djvu = true;
            self.pages = self._document.pages;
            if (!self.replaceDjvuPage(0)) {
                self.close();
                return false;
            }
            return true;
        }

        if (formats.codec(std.mem.span(path))) |codec| return self.loadRaster(path, codec);

        var success = false;
        defer if (!success) self.close();
        if (w.GdipLoadImageFromFile(path, &self.handle) != 0) {
            if (self.handle) |partial| _ = w.GdipDisposeImage(partial);
            self.handle = null;
            // GDI+ cannot open PNG-compressed ICO containers, including Pillow's
            // default icons. Decode their PNG payload using XP's GDI+ PNG codec;
            // use CreateIconFromResourceEx for classic DIB-based icons.
            if (!hasExtension(path, ".ico") or !self.loadIcon(path)) return false;
        }
        const handle = self.handle orelse return false;
        orientJpeg(handle, std.mem.span(path));
        const size = dimensions(handle) orelse return false;
        self.width = size.width;
        self.height = size.height;

        // Unsupported dimensions normally return InvalidParameter; only counts
        // returned successfully are used. Zero or unreasonable counts are bad
        // metadata, not a reason to index frame zero of an empty image.
        var count: u32 = 1;
        if (w.GdipImageGetFrameCount(handle, &w.dimension_time, &count) == 0) {
            if (count == 0 or count > max_frames) return false;
            self.frames = count;
        }
        count = 1;
        if (w.GdipImageGetFrameCount(handle, &w.dimension_page, &count) == 0) {
            if (count == 0 or count > djvu.max_pages) return false;
            self.pages = count;
        }
        self.animated = self.frames > 1;
        if (self.animated and !self.readDelays()) return false;
        success = true;
        return true;
    }

    pub fn close(self: *Image) void {
        // Scan0 bitmaps may still refer to _pixels, including after rotation.
        if (self.handle) |handle| _ = w.GdipDisposeImage(handle);
        if (self._stream) |stream| _ = stream.vtable.release(stream);
        if (self._pixels.len != 0) allocator.free(self._pixels);
        if (self._delays.len != 0) allocator.free(self._delays);
        self._document.close();
        self.* = .{};
    }

    /// Advance one GIF frame and return that newly visible frame's delay in
    /// milliseconds. Return zero when no animation/timer should be running.
    pub fn nextFrame(self: *Image) u32 {
        const handle = self.handle orelse return 0;
        if (!self.animated or self.frames < 2 or self.frame >= self.frames) return 0;
        const index = if (self.frame + 1 == self.frames) 0 else self.frame + 1;
        if (w.GdipImageSelectActiveFrame(handle, &w.dimension_time, index) != 0) {
            self.animated = false;
            return 0;
        }
        const size = dimensions(handle) orelse {
            self.close();
            return 0;
        };
        self.frame = index;
        self.width = size.width;
        self.height = size.height;
        return self.frameDelay();
    }

    /// Optional timer helper for the initial GIF frame and pause/resume. The
    /// required nextFrame method returns this value after advancing a frame.
    pub fn frameDelay(self: *const Image) u32 {
        const delay = if (self.frame < self._delays.len) self._delays[self.frame] else default_delay_ms;
        return @max(20, delay);
    }

    /// Zero-based TIFF/DjVu page navigation. A failed change preserves the old
    /// page whenever possible; a failed GDI+ rollback closes the invalid image.
    pub fn setPage(self: *Image, index: u32) bool {
        const handle = self.handle orelse return false;
        if (index >= self.pages) return false;
        if (index == self.page) return true;
        if (self.is_djvu) return self.replaceDjvuPage(index);
        if (w.GdipImageSelectActiveFrame(handle, &w.dimension_page, index) != 0) return false;
        const size = dimensions(handle) orelse {
            if (w.GdipImageSelectActiveFrame(handle, &w.dimension_page, self.page) != 0 or dimensions(handle) == null) self.close();
            return false;
        };
        self.page = index;
        self.width = size.width;
        self.height = size.height;
        return true;
    }

    /// Rotate the current image clockwise by 90 degrees (Rotate90FlipNone).
    /// 90° clockwise.
    pub fn rotate(self: *Image) void {
        self.rotateBy(1);
    }
    /// 90° counter-clockwise (one GDI+ operation, not three right turns).
    pub fn rotateLeft(self: *Image) void {
        self.rotateBy(3);
    }
    fn rotateBy(self: *Image, kind: i32) void {
        const handle = self.handle orelse return;
        if (w.GdipImageRotateFlip(handle, kind) != 0) return;
        const size = dimensions(handle) orelse {
            self.close();
            return;
        };
        self.width = size.width;
        self.height = size.height;
    }

    fn replaceDjvuPage(self: *Image, index: u32) bool {
        var raster = self._document.render(index) orelse return false;
        var success = false;
        defer if (!success) raster.deinit();
        var handle: ?*w.GpImage = null;
        const status = GdipCreateBitmapFromScan0(@intCast(raster.width), @intCast(raster.height), @intCast(raster.width * 4), pixel_format_32bpp_rgb, raster.pixels.ptr, &handle);
        if (status != 0 or handle == null) {
            if (handle) |image| _ = w.GdipDisposeImage(image);
            return false;
        }
        const size = dimensions(handle.?) orelse {
            _ = w.GdipDisposeImage(handle.?);
            return false;
        };
        if (size.width != raster.width or size.height != raster.height) {
            _ = w.GdipDisposeImage(handle.?);
            return false;
        }
        // Commit only after both decoding and GDI+ creation have succeeded.
        if (self.handle) |old| _ = w.GdipDisposeImage(old);
        if (self._pixels.len != 0) allocator.free(self._pixels);
        self.handle = handle;
        self._pixels = raster.pixels;
        self.width = size.width;
        self.height = size.height;
        self.page = index;
        self.frame = 0;
        success = true;
        return true;
    }

    fn loadRaster(self: *Image, path: [*:0]const u16, codec: formats.Codec) bool {
        // Explicit Win32 wide IO keeps Unicode paths and XP imports independent
        // of the host CRT. Input and output have separate hard limits.
        const file = w.c.CreateFileW(path, w.c.GENERIC_READ, w.c.FILE_SHARE_READ, null, w.c.OPEN_EXISTING, w.c.FILE_ATTRIBUTE_NORMAL, null);
        if (file == null or file == @as(w.c.HANDLE, @ptrFromInt(std.math.maxInt(usize)))) return false;
        defer _ = w.c.CloseHandle(file);
        var high: u32 = 0;
        const length = w.c.GetFileSize(file, &high);
        if (high != 0 or length == 0 or length > codecs.max_file_bytes) return false;
        const buffer = allocator.alloc(u8, length) catch return false;
        defer allocator.free(buffer);
        var read: u32 = 0;
        if (w.c.ReadFile(file, buffer.ptr, length, &read, null) == 0 or read != length) return false;
        var raster = codecs.decode(allocator, codec, buffer) catch return false;
        var success = false;
        defer if (!success) raster.deinit();
        var handle: ?*w.GpImage = null;
        if (GdipCreateBitmapFromScan0(@intCast(raster.width), @intCast(raster.height), @intCast(raster.width * 4), pixel_format_32bpp_argb, raster.pixels.ptr, &handle) != 0 or handle == null) {
            if (handle) |partial| _ = w.GdipDisposeImage(partial);
            return false;
        }
        const size = dimensions(handle.?) orelse {
            _ = w.GdipDisposeImage(handle.?);
            return false;
        };
        if (size.width != raster.width or size.height != raster.height) {
            _ = w.GdipDisposeImage(handle.?);
            return false;
        }
        self.handle = handle;
        self._pixels = raster.pixels;
        self.width = size.width;
        self.height = size.height;
        success = true;
        return true;
    }

    fn loadIcon(self: *Image, path: [*:0]const u16) bool {
        const file = w.c.CreateFileW(path, w.c.GENERIC_READ, w.c.FILE_SHARE_READ, null, w.c.OPEN_EXISTING, w.c.FILE_ATTRIBUTE_NORMAL, null);
        if (file == null or file == @as(w.c.HANDLE, @ptrFromInt(std.math.maxInt(usize)))) return false;
        defer _ = w.c.CloseHandle(file);
        var high: u32 = 0;
        const length = w.c.GetFileSize(file, &high);
        if (high != 0 or length < 22 or length > 16 * 1024 * 1024) return false;
        const buffer = allocator.alloc(u8, length) catch return false;
        defer allocator.free(buffer);
        var read: u32 = 0;
        if (w.c.ReadFile(file, buffer.ptr, length, &read, null) == 0 or read != length) return false;
        if (std.mem.readIntLittle(u16, buffer[0..2]) != 0 or std.mem.readIntLittle(u16, buffer[2..4]) != 1) return false;
        const count = std.mem.readIntLittle(u16, buffer[4..6]);
        if (count == 0 or count > 4096 or 6 + @as(u32, count) * 16 > length) return false;
        var best: ?[]const u8 = null;
        var best_width: u32 = 0;
        var best_height: u32 = 0;
        for (0..count) |i| {
            const entry = buffer[6 + i * 16 ..][0..16];
            const width: u32 = if (entry[0] == 0) 256 else entry[0];
            const height: u32 = if (entry[1] == 0) 256 else entry[1];
            const size = std.mem.readIntLittle(u32, entry[8..12]);
            const offset = std.mem.readIntLittle(u32, entry[12..16]);
            if (offset < 6 + @as(u32, count) * 16 or offset > length or size > length - offset or size < 24) continue;
            if (width * height <= best_width * best_height) continue;
            best = buffer[offset..][0..size];
            best_width = width;
            best_height = height;
        }
        const payload = best orelse return false;
        if (std.mem.eql(u8, payload[0..8], "\x89PNG\r\n\x1a\n")) {
            // Bound the embedded image before giving it to the decoder.
            if (!std.mem.eql(u8, payload[12..16], "IHDR") or std.mem.readIntBig(u32, payload[16..20]) != best_width or std.mem.readIntBig(u32, payload[20..24]) != best_height) return false;
            const global = w.c.GlobalAlloc(w.c.GMEM_MOVEABLE, payload.len) orelse return false;
            const memory = w.c.GlobalLock(global) orelse {
                _ = w.c.GlobalFree(global);
                return false;
            };
            @memcpy(@as([*]u8, @ptrCast(memory))[0..payload.len], payload);
            _ = w.c.GlobalUnlock(global);
            var stream: ?*Stream = null;
            if (CreateStreamOnHGlobal(global, 1, &stream) != 0 or stream == null) {
                if (stream) |s| {
                    _ = s.vtable.release(s);
                } else {
                    _ = w.c.GlobalFree(global);
                }
                return false;
            }
            self._stream = stream;
            // GDI+ requires IStream to remain alive until the image is disposed.
            return GdipLoadImageFromStream(stream.?, &self.handle) == 0 and self.handle != null;
        }
        const icon = w.c.CreateIconFromResourceEx(@constCast(payload.ptr), @intCast(payload.len), 1, 0x00030000, @intCast(best_width), @intCast(best_height), 0) orelse return false;
        defer _ = w.c.DestroyIcon(icon);
        return GdipCreateBitmapFromHICON(icon, &self.handle) == 0 and self.handle != null;
    }

    fn readDelays(self: *Image) bool {
        self._delays = allocator.alloc(u32, self.frames) catch return false;
        @memset(self._delays, default_delay_ms);
        const handle = self.handle.?;
        var size: u32 = 0;
        if (w.GdipGetPropertyItemSize(handle, frame_delay_property, &size) != 0) return true;
        if (size < @sizeOf(w.PropertyItem) or size > @sizeOf(w.PropertyItem) + @as(u64, max_frames) * 4) return true;
        const buffer = allocator.alignedAlloc(u8, @alignOf(w.PropertyItem), size) catch return false;
        defer allocator.free(buffer);
        const item: *w.PropertyItem = @ptrCast(buffer.ptr);
        if (w.GdipGetPropertyItem(handle, frame_delay_property, size, item) != 0) return true;
        if (item.id != frame_delay_property or item.kind != 4 or item.length % 4 != 0) return true;
        const value = item.value orelse return true;
        const base = @intFromPtr(buffer.ptr);
        const address = @intFromPtr(value);
        // PropertyItem.value must point into this returned buffer. Check before
        // reading, and tolerate missing/truncated metadata with 100 ms defaults.
        if (address < base or address - base > buffer.len) return true;
        if (item.length > buffer.len - (address - base)) return true;
        const bytes: [*]const u8 = @ptrCast(value);
        const count = @min(self.frames, item.length / 4);
        for (self._delays[0..count], 0..) |*delay, i| {
            const hundredths = std.mem.readIntLittle(u32, bytes[i * 4 ..][0..4]);
            // Preserve nonzero GIF delays (including 10 ms); zero is conventionally
            // 100 ms. Saturate only at the largest Windows timer interval.
            delay.* = if (hundredths == 0) default_delay_ms else @intCast(@min(@as(u64, hundredths) * 10, 0x7fffffff));
        }
        return true;
    }
};

// GDI+ reports EXIF SHORT values in native byte order. Metadata is optional:
// malformed/oversized tags are ignored, never dereferenced outside this buffer.
fn orientJpeg(handle: *w.GpImage, path: []const u16) void {
    const jpeg = .{ ".jpg", ".jpeg", ".jpe", ".jfif", ".jif" };
    var is_jpeg = false;
    inline for (jpeg) |extension| is_jpeg = is_jpeg or formats.hasExtension(path, extension);
    if (!is_jpeg) return;
    const tag = 0x0112;
    var size: u32 = 0;
    var buffer: [128]u8 align(@alignOf(w.PropertyItem)) = undefined;
    if (w.GdipGetPropertyItemSize(handle, tag, &size) != 0 or size < @sizeOf(w.PropertyItem) + 2 or size > buffer.len) return;
    const item: *w.PropertyItem = @ptrCast(&buffer);
    if (w.GdipGetPropertyItem(handle, tag, size, item) != 0 or item.id != tag or item.kind != 3 or item.length != 2) return;
    const value = item.value orelse return;
    const base = @intFromPtr(&buffer);
    const address = @intFromPtr(value);
    if (address < base or address - base > size or size - (address - base) < 2) return;
    const bytes: [*]const u8 = @ptrCast(value);
    const orientation = std.mem.readIntLittle(u16, bytes[0..2]);
    const rotate_flip: i32 = switch (orientation) {
        2 => 4, 3 => 2, 4 => 6, 5 => 5, 6 => 1, 7 => 7, 8 => 3,
        else => return,
    };
    _ = w.GdipImageRotateFlip(handle, rotate_flip);
}

const Size = struct { width: u32, height: u32 };
fn dimensions(handle: *w.GpImage) ?Size {
    var size: Size = .{ .width = 0, .height = 0 };
    if (w.GdipGetImageWidth(handle, &size.width) != 0 or w.GdipGetImageHeight(handle, &size.height) != 0) return null;
    // Prevent signed GDI coordinate conversions and pixel-size multiplication
    // from overflowing on x86. Native photos are not unnecessarily downscaled;
    // DjVu's separately allocated render is also limited to 6000 px per side.
    if (size.width == 0 or size.height == 0 or size.width > std.math.maxInt(i32) or size.height > std.math.maxInt(i32)) return null;
    if (@as(u64, size.width) * size.height > djvu.max_pixels) return null;
    return size;
}

fn hasExtension(path: [*:0]const u16, extension: []const u8) bool {
    return formats.hasExtension(std.mem.span(path), extension);
}

extern "gdiplus" fn GdipBitmapSetPixel(*w.GpImage, i32, i32, u32) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipBitmapGetPixel(*w.GpImage, i32, i32, *u32) callconv(.Stdcall) i32;
test "rotateLeft is a counter-clockwise quarter turn and undoes rotate" {
    var token: usize = 0;
    try std.testing.expectEqual(@as(i32, 0), w.GdiplusStartup(&token, &w.StartupInput{}, null));
    defer w.GdiplusShutdown(token);
    var image = Image{ .width = 3, .height = 2 };
    try std.testing.expectEqual(@as(i32, 0), GdipCreateBitmapFromScan0(3, 2, 0, pixel_format_32bpp_argb, null, &image.handle));
    defer image.close();
    _ = GdipBitmapSetPixel(image.handle.?, 2, 0, 0xffff0000); // top-right marker
    image.rotateLeft();
    try std.testing.expectEqual(@as(u32, 2), image.width);
    try std.testing.expectEqual(@as(u32, 3), image.height);
    var p: u32 = 0;
    _ = GdipBitmapGetPixel(image.handle.?, 0, 0, &p); // top-right -> top-left
    try std.testing.expectEqual(@as(u32, 0xffff0000), p);
    image.rotate();
    try std.testing.expectEqual(@as(u32, 3), image.width);
    _ = GdipBitmapGetPixel(image.handle.?, 2, 0, &p);
    try std.testing.expectEqual(@as(u32, 0xffff0000), p);
}
