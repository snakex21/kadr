const std = @import("std");
const w = @import("../../src/win.zig");
const c = w.c;
const loader = @import("../../src/loader.zig");
const Image = @import("../../src/image.zig").Image;
extern "gdiplus" fn GdipBitmapGetPixel(*w.GpImage, i32, i32, *u32) callconv(.Stdcall) i32;
var checks: usize = 0;
var notifications: u32 = 0;
var pings: u32 = 0;
var accepted: u32 = 0;
const ping_message = c.WM_APP + 11;
const unicode_path = w.L("tests/loader-check/fixtures/zażółć-漢字.QOI");
const broken_path = w.L("tests/loader-check/fixtures/broken.qoi");
const large_path = w.L("tests/loader-check/fixtures/large.qoi");

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
    if (!ok) {
        log("FAIL: {s}\n", .{label});
        return error.CheckFailed;
    }
    checks += 1;
}
pub fn main() void {
    run() catch |err| {
        log("loader harness failure: {s}\n", .{@errorName(err)});
        c.ExitProcess(1);
    };
    log("loader: x86 harness PASS ({d} checks)\n", .{checks});
}
fn proc(hwnd: c.HWND, message: c.UINT, wp: c.WPARAM, lp: c.LPARAM) callconv(.Stdcall) c.LRESULT {
    if (message == loader.result_message) {
        notifications +%= 1;
        return 0;
    }
    if (message == ping_message) {
        pings +%= 1;
        return 0;
    }
    return c.DefWindowProcW(hwnd, message, wp, lp);
}
fn pump() void {
    var message: c.MSG = undefined;
    while (c.PeekMessageW(&message, null, 0, 0, c.PM_REMOVE) != 0) {
        _ = c.TranslateMessage(&message);
        _ = c.DispatchMessageW(&message);
    }
}
fn enqueue(path: [*:0]const u16) bool {
    if (!loader.request(path)) return false;
    accepted +%= 1;
    if (accepted == 0) accepted = 1;
    return true;
}
fn enqueuePage(path: [*:0]const u16, page: u32) bool {
    if (!loader.requestPage(path, page)) return false;
    accepted +%= 1;
    if (accepted == 0) accepted = 1;
    return true;
}
fn start(hwnd: c.HWND) !void {
    try check(loader.init(hwnd), "native worker init");
    accepted = 0;
    pump();
}
fn awaitResult() !*loader.Result {
    const start_time = c.GetTickCount();
    while (c.GetTickCount() -% start_time < 30_000) {
        pump();
        if (loader.take()) |result| return result;
        c.Sleep(1);
    }
    return error.ResultTimeout;
}
fn awaitNotification(previous: u32) !void {
    const start_time = c.GetTickCount();
    while (c.GetTickCount() -% start_time < 30_000) {
        pump();
        if (notifications != previous) return;
        c.Sleep(1);
    }
    return error.NotificationTimeout;
}
fn samePath(result: *loader.Result, path: [*:0]const u16) bool {
    return std.mem.eql(u16, std.mem.sliceTo(&result.path, 0), std.mem.span(path));
}
fn pixel(image: *Image, x: i32, y: i32) !u32 {
    var color: u32 = 0;
    if (GdipBitmapGetPixel(image.handle.?, x, y, &color) != 0) return error.GetPixel;
    return color;
}
fn verifySampling(result: *loader.Result) !void {
    try check(result.success and result.preview.width == 1600 and result.preview.height == 800 and result.preview._pixels.len == 1600 * 800 * 4, "mixed-alpha software preview owned buffer");
    for ([_]u32{ 0, 1, 257, 799, 1599 }) |x| {
        for ([_]u32{ 0, 1, 127, 399, 799 }) |y| {
            // Independent scalar float reference, same 1/256-pixel centers.
            const px = @max(0, (@as(f64, @floatFromInt(x)) + 0.5) * @as(f64, @floatFromInt(result.image.width)) / 1600 - 0.5);
            const py = @max(0, (@as(f64, @floatFromInt(y)) + 0.5) * @as(f64, @floatFromInt(result.image.height)) / 800 - 0.5);
            const x0: u32 = @intFromFloat(@floor(px));
            const y0: u32 = @intFromFloat(@floor(py));
            const fx = @floor((px - @floor(px)) * 256) / 256;
            const fy = @floor((py - @floor(py)) * 256) / 256;
            const weights = [4]f64{ (1 - fx) * (1 - fy), fx * (1 - fy), (1 - fx) * fy, fx * fy };
            const colors = [4]u32{
                try pixel(&result.image, @intCast(x0), @intCast(y0)),
                try pixel(&result.image, @intCast(@min(x0 + 1, result.image.width - 1)), @intCast(y0)),
                try pixel(&result.image, @intCast(x0), @intCast(@min(y0 + 1, result.image.height - 1))),
                try pixel(&result.image, @intCast(@min(x0 + 1, result.image.width - 1)), @intCast(@min(y0 + 1, result.image.height - 1))),
            };
            const actual = try pixel(&result.preview, @intCast(x), @intCast(y));
            var alpha: f64 = 0;
            for (colors, weights) |color, weight| alpha += @as(f64, @floatFromInt(color >> 24)) * weight;
            const expected_alpha: u32 = @intFromFloat(@floor(alpha + 0.5));
            try check(actual >> 24 == expected_alpha, "mixed-alpha coverage matches float reference");
            inline for (.{ @as(u5, 0), @as(u5, 8), @as(u5, 16) }) |shift| {
                var channel: f64 = 0;
                for (colors, weights) |color, weight| channel += @as(f64, @floatFromInt((color >> shift) & 255)) * @as(f64, @floatFromInt(color >> 24)) * weight;
                const expected: i32 = if (expected_alpha == 0) 0 else @intFromFloat(@floor(channel / alpha + 0.5));
                const difference = @as(i32, @intCast((actual >> shift) & 255)) - expected;
                try check(difference >= -2 and difference <= 2, "premultiplied preview RGB within explicit 2/255 tolerance");
            }
        }
    }
}
fn handles() !u32 {
    var value: u32 = 0;
    if (c.GetProcessHandleCount(c.GetCurrentProcess(), &value) == 0) return error.HandleCount;
    return value;
}
fn heapBytes() !u64 {
    const heap = c.GetProcessHeap();
    if (c.HeapLock(heap) == 0) return error.HeapLock;
    defer _ = c.HeapUnlock(heap);
    var entry = std.mem.zeroes(c.PROCESS_HEAP_ENTRY);
    var bytes: u64 = 0;
    while (c.HeapWalk(heap, &entry) != 0) {
        if (entry.wFlags & c.PROCESS_HEAP_ENTRY_BUSY != 0) bytes += entry.cbData;
    }
    return bytes;
}
fn run() !void {
    var token: usize = 0;
    if (w.GdiplusStartup(&token, &w.StartupInput{}, null) != 0) return error.GdiplusStartup;
    defer w.GdiplusShutdown(token);
    const class_name = w.L("KadrLoaderCheck");
    var wc = std.mem.zeroes(c.WNDCLASSW);
    wc.lpfnWndProc = proc;
    wc.hInstance = c.GetModuleHandleW(null);
    wc.lpszClassName = class_name;
    if (c.RegisterClassW(&wc) == 0) return error.RegisterClass;
    defer _ = c.UnregisterClassW(class_name, wc.hInstance);
    const hwnd = c.CreateWindowExW(0, class_name, class_name, 0, 0, 0, 0, 0, null, null, wc.hInstance, null) orelse return error.CreateWindow;
    defer _ = c.DestroyWindow(hwnd);
    defer loader.shutdown();
    try check(loader.result_message == c.WM_APP + 10, "notification contract");
    try check(!loader.init(null), "null window rejected");
    try check(!loader.request(unicode_path) and loader.take() == null, "before-init calls safe");
    loader.shutdown(); loader.shutdown();
    try start(hwnd);
    try check(!loader.init(hwnd), "duplicate init rejected");
    try check(!loader.request(w.L("")), "empty path rejected");

    // The request owns a copy, not the caller's mutable input buffer.
    const path_mem = c.HeapAlloc(c.GetProcessHeap(), 0, 32769 * 2) orelse return error.OutOfMemory;
    defer _ = c.HeapFree(c.GetProcessHeap(), 0, path_mem);
    const path: [*]u16 = @ptrCast(@alignCast(path_mem));
    @memcpy(path[0..unicode_path.len], unicode_path);
    path[unicode_path.len] = 0;
    const notice = notifications;
    try check(enqueue(@ptrCast(path)), "Unicode request copied");
    @memset(path[0..unicode_path.len], 'X');
    try awaitNotification(notice);
    const first = try awaitResult();
    var current: Image = .{};
    defer current.close();
    try check(first.success and samePath(first, unicode_path) and first.token == accepted and first.requested_page == 0 and first.preview.handle == null, "Unicode result + generation + path ownership + default page + small-image preview skip");
    try check(first.image.width == 2 and first.image.height == 1 and try pixel(&first.image, 0, 0) == 0xffff0000 and try pixel(&first.image, 1, 0) == 0x8000ff00, "worker decoded pixels and alpha");
    current = first.image;
    first.image = .{};
    loader.release(first);
    try check(try pixel(&current, 0, 0) == 0xffff0000, "moved image survives result release");

    // Long paths are checked without a large stack node, and invalid requests
    // must not invalidate an already accepted request/generation.
    @memset(path[0..32768], 'a');
    path[32768] = 0;
    try check(!loader.request(@ptrCast(path)), "overlength UTF-16 path rejected");
    path[32767] = 0;
    try check(enqueue(@ptrCast(path)), "maximum path accepted/copied");
    const long = try awaitResult();
    try check(!long.success and long.token == accepted and std.mem.sliceTo(&long.path, 0).len == 32767, "maximum path fails cleanly at OS decoder");
    loader.release(long);

    try check(enqueue(broken_path), "malformed request accepted asynchronously");
    const failed = try awaitResult();
    try check(!failed.success and failed.image.handle == null and failed.image.width == 0 and failed.image.pages == 1 and failed.preview.handle == null and samePath(failed, broken_path), "failure completion preserves default images");
    loader.release(failed);
    try check(try pixel(&current, 0, 0) == 0xffff0000, "old current image retained during failed load");

    // A completed but untaken node must become stale immediately on request.
    pump();
    const before_notice = notifications;
    try check(enqueue(unicode_path), "create untaken completion");
    try awaitNotification(before_notice);
    try check(enqueue(broken_path), "replace completed request");
    const latest_failure = try awaitResult();
    try check(!latest_failure.success and samePath(latest_failure, broken_path) and latest_failure.token == accepted, "stale completed success is never returned");
    loader.release(latest_failure);

    // Native 12 MP decode stays off the UI; message pumping continues and the
    // old image remains usable. Timing is evidence, not a hard realtime claim.
    const begin = c.GetTickCount();
    try check(enqueue(large_path), "large decode request");
    const request_ms = c.GetTickCount() -% begin;
    const old_pings = pings;
    try check(c.PostMessageW(hwnd, ping_message, 0, 0) != 0, "post UI responsiveness probe");
    pump();
    try check(pings == old_pings + 1, "UI dispatched message without waiting for decode");
    current.rotate(); current.rotate(); current.rotate(); current.rotate();
    try check(try pixel(&current, 0, 0) == 0xffff0000, "UI uses old image while worker decodes separate image");
    const large = try awaitResult();
    try check(large.success and large.image.width == 4000 and large.image.height == 3000 and large.token == accepted, "actual large decode completes");
    try check(large.preview.handle != null and large.preview.width == 1600 and large.preview.height == 1200 and large.preview._pixels.len == 1600 * 1200 * 4, "retained software preview with 4:3 aspect and 1600 edge");
    try check(try pixel(&large.preview, 800, 300) == 0xffff0000 and try pixel(&large.preview, 800, 900) == 0x800000ff, "preview full-source top-down color and alpha");
    try check(try pixel(&large.image, 2000, 750) == 0xffff0000 and try pixel(&large.image, 2000, 2250) == 0x800000ff and large.image.page == 0, "preview does not mutate original pixels/page");
    var display_preview = large.preview;
    large.preview = .{};
    loader.release(large); // destroy original; moved preview must remain valid
    try check(try pixel(&display_preview, 800, 900) == 0x800000ff, "preview move/reset/release survives original destruction");
    display_preview.close(); display_preview.close();
    log("nonblocking request: {d} ms; 12 MP completion + preview incl. pump: {d} ms\n", .{ request_ms, c.GetTickCount() -% begin });
    try check(enqueue(w.L("tests/loader-check/fixtures/portrait.qoi")), "portrait preview request");
    const portrait = try awaitResult();
    try check(portrait.success and portrait.image.width == 1001 and portrait.image.height == 2001 and portrait.preview.width == 800 and portrait.preview.height == 1600 and try pixel(&portrait.preview, 400, 800) == 0xffff0000, "portrait aspect rounding and full color");
    loader.release(portrait);
    try check(enqueue(w.L("tests/loader-check/fixtures/threshold.qoi")), "exactly two-megapixel request");
    const threshold = try awaitResult();
    try check(threshold.success and threshold.image.width * threshold.image.height == 2_000_000 and threshold.preview.handle == null, "no preview at exact 2 MP threshold");
    loader.release(threshold);
    try check(enqueue(w.L("tests/loader-check/fixtures/large-animated.gif")), "large animation request");
    const animation = try awaitResult();
    try check(animation.success and animation.image.animated and animation.image.width * animation.image.height > 2_000_000 and animation.preview.handle == null, "no stale-frame preview for animation above threshold");
    loader.release(animation);
    inline for (.{ "mixed.qoi", "mixed.png" }) |name| {
        log("verify mixed-alpha software preview: {s}\n", .{name});
        try check(enqueue(w.L("tests/loader-check/fixtures/" ++ name)), "actual mixed-color/alpha source request");
        const mixed = try awaitResult();
        try verifySampling(mixed);
        loader.release(mixed);
    }
    // A vector cannot expose BitmapLockBits: verify the original drawing path.
    const frame = c.RECT{ .left = 0, .top = 0, .right = 105833, .bottom = 79375 };
    const emf_dc = c.CreateEnhMetaFileW(null, w.L("tests/loader-check/fixtures/vector.emf"), &frame, null) orelse return error.Metafile;
    _ = c.Rectangle(emf_dc, 0, 0, 4000, 3000);
    const emf = c.CloseEnhMetaFile(emf_dc) orelse return error.Metafile;
    _ = c.DeleteEnhMetaFile(emf);
    try check(enqueue(w.L("tests/loader-check/fixtures/vector.emf")), "vector preview fallback request");
    const vector = try awaitResult();
    try check(vector.success and vector.image.width * vector.image.height > 2_000_000 and vector.preview.handle != null and vector.preview._pixels.len == 0 and @max(vector.preview.width, vector.preview.height) == 1600, "LockBits-incompatible vector keeps GDI+ fallback");
    loader.release(vector);

    // Queue replacement while a real codec is busy: no intermediate result may
    // escape once the last request is accepted, even if notifications pile up.
    try check(enqueue(large_path), "start superseded active decode");
    c.Sleep(5);
    const burst_start = c.GetTickCount();
    for (0..1000) |i| try check(enqueue(if (i % 2 == 0) broken_path else unicode_path), "latest-pending burst accepted");
    const last = try awaitResult();
    try check(last.success and last.token == accepted and samePath(last, unicode_path), "latest request wins after 1000 replacements");
    loader.release(last);
    pump();
    try check(loader.take() == null, "stale queued notifications do not duplicate results");
    log("1000 latest-pending requests + completion: {d} ms\n", .{c.GetTickCount() -% burst_start});

    // ICO stream ownership crosses to the UI and outlives worker COM teardown.
    try check(enqueue(w.L("tests/fixtures/07-ikona.ico")), "worker ICO stream decode");
    const icon = try awaitResult();
    try check(icon.success and icon.image.width > 0, "cross-thread ICO decoded");
    loader.shutdown();
    try check(try pixel(&icon.image, 0, 0) >= 0, "taken ICO usable after worker shutdown");
    loader.release(icon);
    try check(loader.take() == null and !loader.request(unicode_path), "after-shutdown calls safe");
    loader.shutdown();
    current.close();

    // The first DjVu API-cache initialization happens only on the worker. UI
    // navigation/close uses its already-published API while another doc loads.
    try start(hwnd);
    try check(enqueue(w.L("tests/image-check/książka.DJV")), "worker-only first DjVu initialization");
    const book = try awaitResult();
    try check(book.success and book.image.is_djvu and book.image.pages > 1, "worker DjVu result");
    current = book.image;
    book.image = .{};
    loader.release(book);
    try check(enqueue(w.L("tests/image-check/book.djvu")), "concurrent distinct DjVu document request");
    try check(current.setPage(current.pages - 1), "UI navigates previously transferred DjVu");
    current.close();
    const another = try awaitResult();
    try check(another.success and another.image.is_djvu, "worker cache reuse independent of UI close");
    loader.release(another);

    // Page requests use the same worker/generation, never UI setPage. Exercise
    // the third page (index 2) and last page of the retained 57-page DjVu book.
    const page_begin = c.GetTickCount();
    try check(enqueuePage(w.L("tests/image-check/book.djvu"), 2), "requestPage DjVu page index 2");
    const page_request_ms = c.GetTickCount() -% page_begin;
    const page_pings = pings;
    try check(c.PostMessageW(hwnd, ping_message, 0, 0) != 0, "post page-loading UI probe");
    pump();
    try check(pings == page_pings + 1, "UI message dispatched while page request pending");
    const third = try awaitResult();
    try check(third.success and third.requested_page == 2 and third.image.page == 2 and third.image.pages == 57 and third.token == accepted, "DjVu requested page index 2/57 selected on worker");
    try check(third.preview.handle != null and @max(third.preview.width, third.preview.height) == 1600 and third.preview._pixels.len == third.preview.width * third.preview.height * 4, "selected DjVu page preview owns retained raster");
    loader.release(third);
    log("nonblocking DjVu page request: {d} ms\n", .{page_request_ms});
    try check(enqueuePage(w.L("tests/image-check/książka.DJV"), 56), "Unicode requestPage DjVu last page");
    const last_page = try awaitResult();
    try check(last_page.success and last_page.image.page == 56 and last_page.image.pages == 57 and last_page.requested_page == 56, "DjVu last page selected");
    loader.release(last_page);
    try check(enqueuePage(w.L("tests/image-check/book.djvu"), 57), "out-of-bounds DjVu page request accepted asynchronously");
    const out_of_bounds = try awaitResult();
    try check(out_of_bounds.success and out_of_bounds.requested_page == 57 and out_of_bounds.image.page == 0 and out_of_bounds.image.handle != null, "invalid DjVu page falls back to valid page zero");
    loader.release(out_of_bounds);

    try check(enqueuePage(w.L("tests/fixtures/04-strony.tiff"), 1), "requestPage TIFF second page");
    const tiff = try awaitResult();
    try check(tiff.success and tiff.image.page == 1 and tiff.image.pages == 2 and tiff.image.width == 500 and tiff.image.height == 800 and tiff.requested_page == 1, "TIFF worker selects second page dimensions");
    loader.release(tiff);
    try check(enqueuePage(w.L("tests/fixtures/04-strony.tiff"), 0xffffffff), "out-of-bounds TIFF page request");
    const bad_tiff = try awaitResult();
    try check(bad_tiff.success and bad_tiff.image.page == 0 and bad_tiff.image.width == 800 and bad_tiff.image.height == 500 and bad_tiff.requested_page == 0xffffffff, "invalid TIFF page falls back to first page");
    loader.release(bad_tiff);
    try check(enqueuePage(broken_path, 2), "malformed paged request");
    const bad_page = try awaitResult();
    try check(!bad_page.success and bad_page.image.handle == null and bad_page.requested_page == 2, "load failure remains failure for requestPage");
    loader.release(bad_page);
    try check(enqueuePage(large_path, 100), "superseded paged decode");
    try check(enqueuePage(w.L("tests/fixtures/04-strony.tiff"), 1), "latest page request replaces queue");
    const latest_page = try awaitResult();
    try check(latest_page.success and latest_page.token == accepted and latest_page.requested_page == 1 and latest_page.image.page == 1 and samePath(latest_page, w.L("tests/fixtures/04-strony.tiff")), "page requests share latest-wins generation");
    loader.release(latest_page);
    try check(enqueue(w.L("tests/fixtures/04-strony.tiff")), "legacy request still means page zero");
    const default_page = try awaitResult();
    try check(default_page.success and default_page.requested_page == 0 and default_page.image.page == 0, "request wrapper remains backward compatible");
    loader.release(default_page);
    loader.shutdown();
    pump();
    c.Sleep(100); // DjVu's own released jobs finish asynchronously.

    // Warm COM/GDI+ once before steady-state handle/OS-heap measurements.
    for (0..4) |_| {
        try start(hwnd);
        try check(enqueue(unicode_path), "warm lifecycle request");
        loader.release(try awaitResult());
        loader.shutdown();
        pump();
    }
    const base_handles = try handles();
    const base_gdi = c.GetGuiResources(c.GetCurrentProcess(), 0);
    const base_heap = try heapBytes();
    for (0..32) |_| {
        try start(hwnd);
        for (0..32) |i| try check(enqueue(if (i % 2 == 0) broken_path else unicode_path), "lifecycle queue replacement");
        try check(enqueue(w.L("tests/loader-check/fixtures/portrait.qoi")), "lifecycle preview creation");
        const result = try awaitResult();
        try check(result.success and result.token == accepted and result.preview.handle != null, "lifecycle latest request owns a preview");
        loader.release(result);
        // Both pending and possibly in-flight images are owned by shutdown.
        try check(enqueue(large_path) and enqueue(unicode_path), "shutdown with active/pending requests");
        loader.shutdown();
        pump();
        try check(loader.take() == null, "shutdown drains pending/ready/active ownership");
    }
    const final_handles = try handles();
    const final_gdi = c.GetGuiResources(c.GetCurrentProcess(), 0);
    const final_heap = try heapBytes();
    log("preview GDI resources: {d}->{d}\n", .{ base_gdi, final_gdi });
    try check(final_gdi <= base_gdi, "no GDI object leak across repeated preview create/release/shutdown");
    log("steady state: handles {d}->{d}; busy OS heap bytes {d}->{d}\n", .{ base_handles, final_handles, base_heap, final_heap });
    try check(final_handles <= base_handles, "no native event/thread/file handle leak");
    // Allow small native library/heap caches, but not one leaked 64 KiB node.
    try check(final_heap <= base_heap + 32768, "no accumulated Result node or image heap leak");
}
