//! Opt-in worker timings: root.loaderProfile is compiled out of normal app builds.
const std = @import("std");
const w = @import("../../src/win.zig");
const c = w.c;
const loader = @import("../../src/loader.zig");
extern "kernel32" fn QueryPerformanceCounter(*i64) callconv(.Stdcall) c.BOOL;
extern "kernel32" fn QueryPerformanceFrequency(*i64) callconv(.Stdcall) c.BOOL;
var lock: c.CRITICAL_SECTION = undefined;
var last: struct { token: u32 = 0, load: i64 = 0, preview: i64 = 0, access: i64 = 0, sample: i64 = 0, method: u32 = 0 } = .{};
var frequency: i64 = 0;
pub fn loaderProfile(token: u32, load: i64, preview: i64, access: i64, sample: i64, method: u32) void {
    c.EnterCriticalSection(&lock);
    last = .{ .token = token, .load = load, .preview = preview, .access = access, .sample = sample, .method = method };
    c.LeaveCriticalSection(&lock);
}
fn print(comptime format: []const u8, args: anytype) void {
    var buffer: [1024]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, format, args) catch return;
    var written: u32 = 0;
    _ = c.WriteFile(c.GetStdHandle(c.STD_OUTPUT_HANDLE), text.ptr, @intCast(text.len), &written, null);
}
pub fn panic(message: []const u8, trace: ?*std.builtin.StackTrace, address: ?usize) noreturn {
    _ = trace; _ = address;
    print("FAIL,{s}\n", .{message});
    c.ExitProcess(2);
}
pub fn main() void {
    run() catch |err| {
        print("FAIL,{s}\n", .{@errorName(err)});
        c.ExitProcess(1);
    };
}
fn clock() i64 { var value: i64 = 0; _ = QueryPerformanceCounter(&value); return value; }
fn ms(value: i64) f64 { return @as(f64, @floatFromInt(value)) * 1000 / @as(f64, @floatFromInt(frequency)); }
fn proc(hwnd: c.HWND, message: c.UINT, wp: c.WPARAM, lp: c.LPARAM) callconv(.Stdcall) c.LRESULT {
    return c.DefWindowProcW(hwnd, message, wp, lp);
}
fn run() !void {
    if (QueryPerformanceFrequency(&frequency) == 0 or c.InitializeCriticalSectionAndSpinCount(&lock, 0) == 0) return error.ClockOrLock;
    defer c.DeleteCriticalSection(&lock);
    var gdi: usize = 0;
    if (w.GdiplusStartup(&gdi, &w.StartupInput{}, null) != 0) return error.Gdi;
    defer w.GdiplusShutdown(gdi);
    var wc = std.mem.zeroes(c.WNDCLASSW);
    wc.lpfnWndProc = proc;
    wc.hInstance = c.GetModuleHandleW(null);
    wc.lpszClassName = w.L("KadrLoaderProfile");
    if (c.RegisterClassW(&wc) == 0) return error.Class;
    defer _ = c.UnregisterClassW(wc.lpszClassName, wc.hInstance);
    const hwnd = c.CreateWindowExW(0, wc.lpszClassName, wc.lpszClassName, 0, 0, 0, 0, 0, null, null, wc.hInstance, null) orelse return error.Window;
    defer _ = c.DestroyWindow(hwnd);
    if (!loader.init(hwnd)) return error.Loader;
    defer loader.shutdown();
    print("format,iteration,load_ms,preview_ms,access_ms,sample_ms,total_ms,method\n", .{});
    const paths = .{ .{ "JPEG", w.L("tests/loader-check/fixtures/photo-12mp.jpg") }, .{ "PNG", w.L("tests/loader-check/fixtures/photo-12mp.png") }, .{ "QOI", w.L("tests/loader-check/fixtures/large.qoi") } };
    inline for (paths) |path| {
        for (0..4) |iteration| {
            const start = clock();
            if (!loader.request(path[1])) return error.Request;
            var result: ?*loader.Result = null;
            while (ms(clock() - start) < 30000) {
                var message: c.MSG = undefined;
                while (c.PeekMessageW(&message, null, 0, 0, c.PM_REMOVE) != 0) { _ = c.DispatchMessageW(&message); }
                result = loader.take();
                if (result != null) break;
                c.Sleep(1);
            }
            const completed = clock();
            const node = result orelse return error.Timeout;
            defer loader.release(node);
            if (!node.success or node.image.width != 4000 or node.image.height != 3000 or node.preview.width != 1600 or node.preview.height != 1200) return error.Image;
            c.EnterCriticalSection(&lock);
            const row = last;
            c.LeaveCriticalSection(&lock);
            if (row.token != node.token) return error.Token;
            print("{s},{d},{d:.3},{d:.3},{d:.3},{d:.3},{d:.3},{d}\n", .{ path[0], iteration, ms(row.load), ms(row.preview), ms(row.access), ms(row.sample), ms(completed - start), row.method });
        }
    }
}
