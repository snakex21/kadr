//! Single native XP worker; public control calls belong to the UI thread.
//! Call init after GdiplusStartup, shutdown BEFORE GdiplusShutdown/window teardown.
//! No std.Thread, TLS, Zig atomics, CRT, or change to -fsingle-threaded is needed.
//! Zig 0.11's Windows page_allocator uses stateless VirtualAlloc/VirtualFree.
//! All Image.load / DjVu API-cache initialization must run on this worker; UI
//! may use/close transferred images (separate GDI+/DjVu objects, not shared ones).
const std = @import("std");
const w = @import("win.zig");
const c = w.c;
const Image = @import("image.zig").Image;
const profiling = @hasDecl(@import("root"), "loaderProfile");
extern "kernel32" fn QueryPerformanceCounter(*i64) callconv(.Stdcall) c.BOOL;
fn profileClock() i64 {
    if (!profiling) return 0;
    var ticks: i64 = 0;
    _ = QueryPerformanceCounter(&ticks);
    return ticks;
}
const PreviewStats = struct { access: i64 = 0, sample: i64 = 0, method: u32 = 0 };
// WIN32_LEAN_AND_MEAN deliberately omits COM declarations from win.zig.
extern "ole32" fn CoInitializeEx(?*anyopaque, u32) callconv(.Stdcall) i32;
extern "ole32" fn CoUninitialize() callconv(.Stdcall) void;
extern "gdiplus" fn GdipCreateBitmapFromScan0(i32, i32, i32, i32, ?[*]u8, *?*w.GpImage) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipGetImageGraphicsContext(*w.GpImage, *?*w.GpGraphics) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipSetCompositingMode(*w.GpGraphics, i32) callconv(.Stdcall) i32;
const Rect = extern struct { x: i32 = 0, y: i32 = 0, width: i32, height: i32 };
const BitmapData = extern struct { width: u32 = 0, height: u32 = 0, stride: i32 = 0, format: i32 = 0, scan0: ?*anyopaque = null, reserved: usize = 0 };
extern "gdiplus" fn GdipBitmapLockBits(*w.GpImage, *const Rect, u32, i32, *BitmapData) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipBitmapUnlockBits(*w.GpImage, *BitmapData) callconv(.Stdcall) i32;
extern "gdiplus" fn GdipGetImageType(*w.GpImage, *i32) callconv(.Stdcall) i32;
const argb = 0x0026200a;
const max_source_pixels: u64 = 80_000_000;
const max_source_bytes: u64 = max_source_pixels * 4;

pub const result_message = c.WM_APP + 10;
pub const Result = struct {
    image: Image,
    path: [32768]u16,
    success: bool,
    /// Nonzero request generation, wrapping at 2^32. Notification WPARAM matches.
    token: u32,
    /// Zero-based requested page; image.page reports the actual selected page.
    requested_page: u32 = 0,
    /// Optional independent display raster of the oriented/selected image.
    /// Max long edge 1600; absent for animation, <=2 MP, failure or stale work.
    preview: Image = .{},
};

// Only the UI reads/writes initialized and the thread handle. The worker starts
// after immutable hwnd/wake initialization and exits before they are cleared.
var initialized = false;
var thread: c.HANDLE = null;
var wake: c.HANDLE = null;
var window: c.HWND = null;
var mutex: c.CRITICAL_SECTION = undefined;
// Everything below is protected by mutex while the worker exists.
var stopping = false;
var generation: u32 = 0;
var pending: ?*Result = null;
var ready: ?*Result = null;

/// One loader per process; duplicate init or a null/destroyed HWND is rejected.
/// Lifecycle/control calls must be serialized on the window's UI thread.
pub fn init(hwnd: c.HWND) bool {
    if (initialized or hwnd == null or c.IsWindow(hwnd) == 0) return false;
    if (c.InitializeCriticalSectionAndSpinCount(&mutex, 0) == 0) return false;
    wake = c.CreateEventW(null, 0, 0, null); // auto-reset: no lost wakeups
    if (wake == null) {
        c.DeleteCriticalSection(&mutex);
        return false;
    }
    window = hwnd;
    stopping = false;
    generation = 0;
    pending = null;
    ready = null;
    thread = c.CreateThread(null, 0, workerMain, null, 0, null);
    if (thread == null) {
        _ = c.CloseHandle(wake);
        wake = null;
        window = null;
        c.DeleteCriticalSection(&mutex);
        return false;
    }
    initialized = true;
    return true;
}

/// Copies a nonempty, NUL-terminated path (max 32767 UTF-16 units). Never waits
/// for decoding: one in-flight job + latest pending job, not an unbounded queue.
/// False leaves the previous request/generation intact (invalid path/OOM/state).
pub fn request(path: [*:0]const u16) bool {
    return requestPage(path, 0);
}

/// Same latest-wins queue, with zero-based page selection on the worker. If a
/// page is invalid/unrenderable, retain the valid first page when possible;
/// image.page, not requested_page, is authoritative. A closed image is failure.
pub fn requestPage(path: [*:0]const u16, page: u32) bool {
    if (!initialized) return false;
    var length: usize = 0;
    while (length < 32768 and path[length] != 0) : (length += 1) {}
    if (length == 0 or length == 32768) return false;
    const allocation = c.HeapAlloc(c.GetProcessHeap(), 0, @sizeOf(Result)) orelse return false;
    const node: *Result = @ptrCast(@alignCast(allocation));
    // Initialize directly on the OS heap; never put a 64 KiB Result on a stack.
    node.image = .{};
    node.preview = .{};
    node.success = false;
    node.requested_page = page;
    @memcpy(node.path[0..length], path[0..length]);
    node.path[length] = 0;
    c.EnterCriticalSection(&mutex);
    generation +%= 1;
    if (generation == 0) generation = 1;
    node.token = generation;
    const previous = pending;
    pending = node;
    // Signal while locked, so the worker can only observe the committed node.
    _ = c.SetEvent(wake);
    c.LeaveCriticalSection(&mutex);
    // A replaced pending node has NEVER been decoded: no slow image cleanup
    // on the UI request path. Stale decoded results are freed by the worker.
    if (previous) |old| release(old);
    return true;
}

/// Drops the pending request and invalidates the one being decoded (its
/// result is freed by the worker, never shown). Does not wait for the decoder.
pub fn cancel() void {
    if (!initialized) return;
    c.EnterCriticalSection(&mutex);
    generation +%= 1;
    if (generation == 0) generation = 1;
    const previous = pending;
    pending = null;
    // Wake the worker so it frees a now-stale ready node promptly.
    _ = c.SetEvent(wake);
    c.LeaveCriticalSection(&mutex);
    if (previous) |old| release(old);
}

/// Transfers the latest completed node to the UI, or null. Messages are only
/// wakeups, NOT result pointers: old queued messages may legitimately find null.
/// A stale ready node stays worker-owned for off-UI cleanup and is never shown.
pub fn take() ?*Result {
    if (!initialized) return null;
    c.EnterCriticalSection(&mutex);
    defer c.LeaveCriticalSection(&mutex);
    const result = ready orelse return null;
    if (stopping or result.token != generation) return null;
    ready = null;
    return result;
}

/// Frees an owned result and BOTH images. After moving image and/or preview,
/// reset each moved field to .{} BEFORE release to avoid double-free.
/// Taken nodes belong to the caller, including across shutdown; never copy them.
pub fn release(result: *Result) void {
    result.preview.close();
    result.image.close();
    _ = c.HeapFree(c.GetProcessHeap(), 0, result);
}

/// No thread termination/cancellation: joins the active Image.load, then frees
/// all loader-owned pending/ready jobs and native synchronization handles.
/// Active decoder/IO completion can delay shutdown; this is not a hard deadline.
/// The caller must separately release any nodes/images already taken from us.
pub fn shutdown() void {
    if (!initialized) return;
    c.EnterCriticalSection(&mutex);
    stopping = true;
    _ = c.SetEvent(wake);
    c.LeaveCriticalSection(&mutex);
    _ = c.WaitForSingleObject(thread, c.INFINITE);
    _ = c.CloseHandle(thread);
    _ = c.CloseHandle(wake);
    c.DeleteCriticalSection(&mutex);
    thread = null;
    wake = null;
    window = null;
    initialized = false;
}

// Scan0 points at logical row zero even for a negative stride. Validate the
// whole address span before signed row arithmetic; external GDI+ owns the lock.
const Pixels = struct {
    base: usize, stride: usize, negative: bool, force_opaque: bool,
    fn init(base: usize, stride: i32, width: u32, height: u32, force_opaque: bool) ?Pixels {
        if (width == 0 or height == 0 or @as(u64, width) * height > max_source_pixels) return null;
        const step: u64 = @intCast(if (stride < 0) -@as(i64, stride) else stride);
        const row_bytes = @as(u64, width) * 4;
        const span = step * (height - 1);
        if (step < row_bytes or span + row_bytes > max_source_bytes) return null;
        if (stride < 0) {
            if (base < span or base > std.math.maxInt(usize) - row_bytes) return null;
        } else if (base > std.math.maxInt(usize) - (span + row_bytes)) return null;
        return .{ .base = base, .stride = @intCast(step), .negative = stride < 0, .force_opaque = force_opaque };
    }
    inline fn row(self: Pixels, y: usize) [*]align(1) const u32 {
        return @ptrFromInt(if (self.negative) self.base - y * self.stride else self.base + y * self.stride);
    }
};
const Axis = struct {
    first: usize, next: usize, weight: u32,
    fn at(index: u32, source: u32, target: u32) Axis {
        const center = ((@as(u64, index) * 2 + 1) * source * 256) / (@as(u64, target) * 2);
        const position = center -| 128;
        const first = @min(position >> 8, source - 1);
        return .{ .first = @intCast(first), .next = @intCast(@min(first + 1, source - 1)), .weight = if (first == source - 1) 0 else @intCast(position & 255) };
    }
};
// Two packed 16-bit lanes per multiply. Each horizontal/vertical rounding is
// <=1 channel unit; common equal-alpha pixels avoid divisions entirely.
inline fn lane(a: u32, b: u32, weight: u32) u32 {
    // Modular form of a*(256-w)+b*w: one multiply, not two. Each
    // 16-bit lane's final weighted sum + rounding is <=65408 (no carry).
    return (((a << 8) +% ((b -% a) *% weight) +% 0x00800080) >> 8) & 0x00ff00ff;
}
inline fn blend(a: u32, b: u32, c0: u32, d: u32, x: u32, y: u32) u32 {
    const rb = lane(lane(a & 0x00ff00ff, b & 0x00ff00ff, x), lane(c0 & 0x00ff00ff, d & 0x00ff00ff, x), y);
    const ga = lane(lane((a >> 8) & 0x00ff00ff, (b >> 8) & 0x00ff00ff, x), lane((c0 >> 8) & 0x00ff00ff, (d >> 8) & 0x00ff00ff, x), y);
    return rb | (ga << 8);
}
inline fn sample(a: u32, b: u32, c0: u32, d: u32, x: u32, y: u32, force_opaque: bool) u32 {
    if (force_opaque) return blend(a, b, c0, d, x, y) | 0xff000000;
    if (((a ^ b) | (a ^ c0) | (a ^ d)) & 0xff000000 == 0) {
        if (a >> 24 == 0) return 0;
        return blend(a, b, c0, d, x, y);
    }
    const weights = [4]u32{ (256 - x) * (256 - y), x * (256 - y), (256 - x) * y, x * y };
    const colors = [4]u32{ a, b, c0, d };
    var alpha: u32 = 0;
    var blue: u32 = 0;
    var green: u32 = 0;
    var red: u32 = 0;
    inline for (0..4) |i| {
        const aw = (colors[i] >> 24) * weights[i];
        alpha += aw;
        blue += (colors[i] & 255) * aw;
        green += ((colors[i] >> 8) & 255) * aw;
        red += ((colors[i] >> 16) & 255) * aw;
    }
    const result_alpha = (alpha + 32768) >> 16;
    if (result_alpha == 0) return 0;
    return (result_alpha << 24) | (((red + alpha / 2) / alpha) << 16) | (((green + alpha / 2) / alpha) << 8) | ((blue + alpha / 2) / alpha);
}

// Fresh worker-loaded native rasters have top-down BGRA backing; DjVu backing
// is RGB32 (ignore its padding alpha). Other formats lock an oriented/selected
// read-only ARGB view. No original storage or GDI+ image property is changed.
fn softwarePreview(node: *Result, width: u32, height: u32, stats: *PreviewStats) bool {
    const source = &node.image;
    const access_start = profileClock();
    var lock_data = BitmapData{};
    var locked = false;
    defer if (locked) { _ = GdipBitmapUnlockBits(source.handle.?, &lock_data); };
    const direct = source._pixels.len == @as(u64, source.width) * source.height * 4;
    var input: Pixels = undefined;
    if (direct) {
        input = Pixels.init(@intFromPtr(source._pixels.ptr), @intCast(source.width * 4), source.width, source.height, source.is_djvu) orelse return false;
    } else {
        // LockBits requires GpBitmap, not merely GpImage. Some GDI+ versions
        // crash rather than reject a metafile cast, so check before calling.
        var image_type: i32 = 0;
        if (GdipGetImageType(source.handle.?, &image_type) != 0 or image_type != 1) return false;
        const rect = Rect{ .width = @intCast(source.width), .height = @intCast(source.height) };
        if (GdipBitmapLockBits(source.handle.?, &rect, 1, argb, &lock_data) != 0) return false;
        locked = true;
        if (lock_data.width != source.width or lock_data.height != source.height or lock_data.format != argb or lock_data.scan0 == null) return false;
        input = Pixels.init(@intFromPtr(lock_data.scan0.?), lock_data.stride, source.width, source.height, false) orelse return false;
    }
    stats.access = profileClock() - access_start;
    const sample_start = profileClock();
    const allocator = std.heap.page_allocator; // Image.close uses this allocator
    if (width == 0 or height == 0 or width > 1600 or height > 1600) return false;
    const buffer = allocator.alloc(u8, @as(usize, width) * height * 4) catch return false;
    var bitmap: ?*w.GpImage = null;
    var keep = false;
    defer if (!keep) {
        if (bitmap) |partial| _ = w.GdipDisposeImage(partial);
        allocator.free(buffer);
    };
    // 19.2 KiB maximum, on the heap rather than the worker's stack.
    const axes = allocator.alloc(Axis, width) catch return false;
    defer allocator.free(axes);
    for (axes, 0..) |*axis, x| axis.* = Axis.at(@intCast(x), source.width, width);
    const output: [*]align(1) u32 = @ptrCast(buffer.ptr);
    for (0..height) |y| {
        const ay = Axis.at(@intCast(y), source.height, height);
        const top = input.row(ay.first);
        const bottom = input.row(ay.next);
        for (axes, 0..) |ax, x| output[y * width + x] = sample(top[ax.first], top[ax.next], bottom[ax.first], bottom[ax.next], ax.weight, ay.weight, input.force_opaque);
    }
    if (GdipCreateBitmapFromScan0(@intCast(width), @intCast(height), @intCast(width * 4), argb, buffer.ptr, &bitmap) != 0 or bitmap == null) return false;
    node.preview.handle = bitmap;
    node.preview.width = width;
    node.preview.height = height;
    node.preview._pixels = buffer;
    keep = true;
    stats.sample = profileClock() - sample_start;
    stats.method = if (direct) 1 else 2;
    return true;
}

// Full source only, never an EXIF thumbnail. Keep the original GDI+ drawing
// fallback for vectors/unsupported LockBits views or software allocation failure.
fn makePreview(node: *Result, stats: *PreviewStats) void {
    const source = &node.image;
    const count = @as(u64, source.width) * source.height;
    if (!node.success or source.animated or count <= 2_000_000 or count > max_source_pixels or source.width > std.math.maxInt(i32) or source.height > std.math.maxInt(i32)) return;
    const original = source.handle orelse return;
    c.EnterCriticalSection(&mutex);
    const current = !stopping and node.token == generation;
    c.LeaveCriticalSection(&mutex);
    if (!current) return;
    const long: u32 = @max(source.width, source.height);
    const edge: u32 = @min(long, 1600); // never upscale
    const width: u32 = @intCast(@max(1, (@as(u64, source.width) * edge + long / 2) / long));
    const height: u32 = @intCast(@max(1, (@as(u64, source.height) * edge + long / 2) / long));
    if (softwarePreview(node, width, height, stats)) return;
    var bitmap: ?*w.GpImage = null;
    var keep = false;
    defer if (!keep) { if (bitmap) |partial| _ = w.GdipDisposeImage(partial); };
    if (GdipCreateBitmapFromScan0(@intCast(width), @intCast(height), 0, 0x0026200a, null, &bitmap) != 0 or bitmap == null) return;
    var graphics: ?*w.GpGraphics = null;
    const status = GdipGetImageGraphicsContext(bitmap.?, &graphics);
    defer if (graphics) |context| { _ = w.GdipDeleteGraphics(context); };
    if (status != 0 or graphics == null) return;
    if (w.GdipSetPageUnit(graphics.?, 2) != 0 or
        GdipSetCompositingMode(graphics.?, 1) != 0 or // SourceCopy preserves alpha
        w.GdipSetInterpolationMode(graphics.?, 3) != 0) return; // Bilinear
    if (w.GdipDrawImageRectRect(graphics.?, original, 0, 0, @floatFromInt(width), @floatFromInt(height), 0, 0, @floatFromInt(source.width), @floatFromInt(source.height), 2, null, null, null) != 0) return;
    node.preview.handle = bitmap;
    node.preview.width = width;
    node.preview.height = height;
    keep = true;
}

test "preview negative stride, address bounds and premultiplied alpha" {
    const top_down = [_]u32{ 0xffff0000, 0x0000ff00, 0x800000ff, 0xffffffff };
    const bottom_up = [_]u32{ 0x800000ff, 0xffffffff, 0xffff0000, 0x0000ff00 };
    const positive = Pixels.init(@intFromPtr(&top_down), 8, 2, 2, false).?;
    const negative = Pixels.init(@intFromPtr(&bottom_up[2]), -8, 2, 2, false).?;
    try std.testing.expectEqual(@as(u32, 0xa0cc6699), sample(positive.row(0)[0], positive.row(0)[1], positive.row(1)[0], positive.row(1)[1], 128, 128, false));
    try std.testing.expectEqual(sample(top_down[0], top_down[1], top_down[2], top_down[3], 128, 128, false), sample(negative.row(0)[0], negative.row(0)[1], negative.row(1)[0], negative.row(1)[1], 128, 128, false));
    try std.testing.expectEqual(@as(u32, 0xff808080), sample(0x00ff0000, 0x0000ff00, 0x000000ff, 0x00ffffff, 128, 128, true));
    try std.testing.expect(Pixels.init(4, -8, 2, 2, false) == null);
    try std.testing.expect(Pixels.init(std.math.maxInt(usize), 8, 2, 2, false) == null);
    try std.testing.expect(Pixels.init(@intFromPtr(&top_down), 4, 2, 2, false) == null);
    try std.testing.expect(Pixels.init(@intFromPtr(&top_down), std.math.minInt(i32), 2, 2, false) == null);
    try std.testing.expect(Pixels.init(@intFromPtr(&top_down), 8, 2, 0, false) == null);
    const center = Axis.at(0, 2, 1);
    try std.testing.expect(center.first == 0 and center.next == 1 and center.weight == 128);
    try std.testing.expect(Axis.at(0, 1, 1).next == 0);
    try std.testing.expectEqual(@as(u32, 0x0000ff00), top_down[1]); // no mutation
}

test "preview mixed-alpha sampling within two units of independent float reference" {
    var random = std.rand.DefaultPrng.init(0x12345678);
    for (0..4096) |iteration| {
        var colors: [4]u32 = undefined;
        for (&colors) |*color| color.* = random.random().int(u32);
        if (iteration % 2 == 0) { // also exercise the opaque packed fast path
            for (&colors) |*color| color.* |= 0xff000000;
        }
        const x: u32 = random.random().int(u8);
        const y: u32 = random.random().int(u8);
        const actual = sample(colors[0], colors[1], colors[2], colors[3], x, y, false);
        const fx: f64 = @as(f64, @floatFromInt(x)) / 256;
        const fy: f64 = @as(f64, @floatFromInt(y)) / 256;
        const weights = [4]f64{ (1 - fx) * (1 - fy), fx * (1 - fy), (1 - fx) * fy, fx * fy };
        var alpha: f64 = 0;
        for (colors, weights) |color, weight| alpha += @as(f64, @floatFromInt(color >> 24)) * weight;
        const expected_alpha: u32 = @intFromFloat(@floor(alpha + 0.5));
        try std.testing.expectEqual(expected_alpha, actual >> 24);
        inline for (.{ @as(u5, 0), @as(u5, 8), @as(u5, 16) }) |shift| {
            var premultiplied: f64 = 0;
            for (colors, weights) |color, weight| premultiplied += @as(f64, @floatFromInt((color >> shift) & 255)) * @as(f64, @floatFromInt(color >> 24)) * weight;
            const expected: i32 = if (expected_alpha == 0) 0 else @intFromFloat(@floor(premultiplied / alpha + 0.5));
            const difference = @as(i32, @intCast((actual >> shift) & 255)) - expected;
            try std.testing.expect(difference >= -2 and difference <= 2);
        }
    }
}

fn workerMain(_: ?*anyopaque) callconv(.Stdcall) c.DWORD {
    // Stream-based ICO fallback uses OLE's IStream. Each native worker gets
    // its own COM MTA initialization; distinct image objects cross by ownership.
    const com = CoInitializeEx(null, 0); // COINIT_MULTITHREADED
    defer if (com >= 0) CoUninitialize();
    while (true) {
        _ = c.WaitForSingleObject(wake, c.INFINITE);
        while (true) {
            c.EnterCriticalSection(&mutex);
            const stop = stopping;
            var stale: ?*Result = null;
            if (ready) |old| {
                if (stop or old.token != generation) {
                    stale = old;
                    ready = null;
                }
            }
            const job = pending;
            pending = null;
            c.LeaveCriticalSection(&mutex);
            if (stale) |old| release(old);
            if (stop) {
                if (job) |old| release(old);
                return 0;
            }
            const node = job orelse break;
            const work_start = profileClock();
            node.success = node.image.load(@ptrCast(&node.path));
            if (node.success and node.requested_page != 0) {
                _ = node.image.setPage(node.requested_page);
                node.success = node.image.handle != null;
            }
            const loaded = profileClock();
            var stats = PreviewStats{};
            makePreview(node, &stats); // best effort; never changes original success
            if (profiling) @import("root").loaderProfile(node.token, loaded - work_start, profileClock() - loaded, stats.access, stats.sample, stats.method);
            c.EnterCriticalSection(&mutex);
            const publish = !stopping and node.token == generation;
            if (publish) {
                // Only this worker publishes; a previous ready node, if any,
                // is stale and must not outlive a newer completion.
                stale = ready;
                ready = node;
                // PostMessage is asynchronous, never SendMessage. On a full
                // queue/destroyed HWND a caller can still poll take(); shutdown
                // owns and frees an unclaimed result. Keep the HWND alive.
                _ = c.PostMessageW(window, result_message, node.token, 0);
            }
            c.LeaveCriticalSection(&mutex);
            if (publish) {
                if (stale) |old| release(old);
            } else release(node);
        }
    }
}
