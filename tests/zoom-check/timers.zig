//! Development-only real Win32 timer cadence, not a renderer microbenchmark.
const std = @import("std");
const w = @import("../../src/win.zig");
const c = w.c;
pub fn main() !void {
    const out = std.io.getStdOut().writer();
    for ([_]u32{ 16, 10 }) |interval| {
        const timer = c.SetTimer(null, 0, interval, null);
        if (timer == 0) return error.NoTimer;
        var frequency: c.LARGE_INTEGER = undefined;
        var started: c.LARGE_INTEGER = undefined;
        _ = c.QueryPerformanceFrequency(&frequency);
        _ = c.QueryPerformanceCounter(&started);
        var previous = started.QuadPart;
        var maximum: f64 = 0;
        var samples: usize = 0;
        while (samples < 32) {
            var msg: c.MSG = undefined;
            if (c.GetMessageW(&msg, null, 0, 0) <= 0) return error.QueueEnded;
            if (msg.message == c.WM_TIMER and msg.wParam == timer) {
                var now: c.LARGE_INTEGER = undefined;
                _ = c.QueryPerformanceCounter(&now);
                const elapsed = @as(f64, @floatFromInt(now.QuadPart - previous)) * 1000 / @as(f64, @floatFromInt(frequency.QuadPart));
                maximum = @max(maximum, elapsed);
                previous = now.QuadPart;
                samples += 1;
            } else {
                _ = c.TranslateMessage(&msg);
                _ = c.DispatchMessageW(&msg);
            }
        }
        _ = c.KillTimer(null, timer);
        const mean = @as(f64, @floatFromInt(previous - started.QuadPart)) * 1000 / @as(f64, @floatFromInt(frequency.QuadPart)) / @as(f64, @floatFromInt(samples));
        try out.print("Win32 timer requested {d} ms: actual mean {d:.3} ms, maximum {d:.3} ms ({d} frames)\n", .{ interval, mean, maximum, samples });
    }
}
