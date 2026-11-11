//! Shared, tested zoom policy. A fitted tiny image may already exceed 32x.
const std = @import("std");
pub const Limits = struct { minimum: f32, maximum: f32 };
pub fn limits(width: u32, height: u32, fit: f32, geometry_cap: f32) Limits {
    const longest: f32 = @floatFromInt(@max(1, @max(width, height)));
    const maximum = geometry_cap / longest;
    const fitted = if (std.math.isFinite(fit) and fit > 0) fit else 1;
    return .{ .minimum = @min(maximum, @min(0.01, fitted / 64)), .maximum = maximum };
}
/// Keep only a small grab area visible, rather than tethering the image to its centre.
pub fn panLimit(scaled_extent: f32, viewport_extent: f32) f32 {
    if (!std.math.isFinite(scaled_extent) or !std.math.isFinite(viewport_extent) or scaled_extent <= 0 or viewport_extent <= 0) return 0;
    // Match the renderer's device-pixel rounding, including subpixel images.
    const image_span = @max(1, @round(scaled_extent));
    const viewport = @max(1, @round(viewport_extent));
    const visible = @min(48, @min(image_span, viewport));
    return @max(0, (image_span + viewport) / 2 - visible);
}
test "panning is free across the viewport, not restricted to forty pixels of overscroll" {
    try std.testing.expectEqual(@as(f32, 1452), panLimit(2000, 1000));
    try std.testing.expectEqual(@as(f32, 952), panLimit(1000, 1000));
    try std.testing.expectEqual(@as(f32, 552), panLimit(200, 1000));
    try std.testing.expect(panLimit(2000, 1000) > ((2000 - 1000) / 2 + 40) * 2);
}
test "panning keeps a grab area visible for small, large and fractional images" {
    const cap: f32 = 8_388_608;
    for ([_]f32{ 0.5, 1, 1.4, 2, 3, 8, 32, 64, 200, 800, 1600, 4000, cap }) |extent| {
        for ([_]f32{ 1, 32, 500, 1000, 3840 }) |viewport| {
            const limit = panLimit(extent, viewport);
            const pixels = @max(1, @round(extent));
            const required = @min(48, @min(pixels, viewport));
            for ([_]f32{ -1, 1 }) |sign| {
                const origin = @round((viewport - extent) / 2 + sign * limit);
                const overlap = @max(0, @min(viewport, origin + pixels) - @max(0, origin));
                try std.testing.expect(overlap >= required);
                try std.testing.expect(std.math.fabs(origin) <= cap);
            }
        }
    }
}
test "panning empty or invalid dimensions is neutral" {
    try std.testing.expectEqual(@as(f32, 0), panLimit(0, 1000));
    try std.testing.expectEqual(@as(f32, 0), panLimit(800, 0));
    try std.testing.expectEqual(@as(f32, 0), panLimit(-1, 1000));
    try std.testing.expectEqual(@as(f32, 0), panLimit(std.math.inf(f32), 1000));
}
pub fn nextScale(current: f32, factor: f32, bounds: Limits) f32 {
    if (!std.math.isFinite(current) or current <= 0 or !std.math.isFinite(factor) or factor <= 0) return current;
    const candidate = std.math.clamp(current * factor, bounds.minimum, bounds.maximum);
    // A bound must never turn + into zoom-out or - into zoom-in, including a
    // fitted scale outside a manual range inherited from an older version.
    if (factor > 1) return @max(current, candidate);
    if (factor < 1) return @min(current, candidate);
    return current;
}
pub fn caption(buffer: []u8, scale: f32) []const u8 {
    const value = if (scale >= 100) scale else scale * 100;
    const number = if (value < 0.001) std.fmt.bufPrint(buffer, "{d:.9}", .{value}) catch return "" else if (value < 1) std.fmt.bufPrint(buffer, "{d:.6}", .{value}) catch return "" else std.fmt.bufPrint(buffer, "{d:.3}", .{value}) catch return "";
    var n = number.len;
    while (n > 0 and buffer[n - 1] == '0') : (n -= 1) {}
    if (n > 0 and buffer[n - 1] == '.') n -= 1;
    for (buffer[0..n]) |*ch| {
        if (ch.* == '.') ch.* = ',';
    }
    const suffix = if (scale >= 100) "×" else "%";
    if (n + suffix.len > buffer.len) return "";
    @memcpy(buffer[n..][0..suffix.len], suffix);
    return buffer[0 .. n + suffix.len];
}
fn space(ch: u16) bool {
    return ch == ' ' or ch == '\t' or ch == '\r' or ch == '\n' or ch == 0xa0 or ch == 0x202f;
}
pub fn parse(input: []const u16) error{InvalidZoom}!f32 {
    if (input.len > 128) return error.InvalidZoom;
    var first: usize = 0;
    var end = input.len;
    while (first < end and space(input[first])) : (first += 1) {}
    while (end > first and space(input[end - 1])) : (end -= 1) {}
    if (first == end) return error.InvalidZoom;
    var percent = true;
    const suffix = input[end - 1];
    if (suffix == '%' or suffix == 'x' or suffix == 'X' or suffix == 0xd7) {
        percent = suffix == '%';
        end -= 1;
        while (end > first and space(input[end - 1])) : (end -= 1) {}
    }
    if (first < end and input[first] == '+') first += 1;
    var value: f64 = 0;
    var place: f64 = 0.1;
    var decimal = false;
    var digits: usize = 0;
    for (input[first..end]) |ch| {
        if (ch >= '0' and ch <= '9') {
            const digit: f64 = @floatFromInt(ch - '0');
            digits += 1;
            if (decimal) {
                value += digit * place;
                place *= 0.1;
            } else value = value * 10 + digit;
        } else if ((ch == '.' or ch == ',') and !decimal) {
            decimal = true;
        } else return error.InvalidZoom;
    }
    if (percent) value /= 100;
    if (digits == 0 or value <= 0 or !std.math.isFinite(value) or value > std.math.floatMax(f32)) return error.InvalidZoom;
    const result: f32 = @floatCast(value);
    if (result <= 0) return error.InvalidZoom;
    return result;
}
pub const EditKey = enum { confirm, cancel, select_all, tab, native };
pub fn editKey(key: usize, ctrl: bool) EditKey {
    if (key == 0x0d) return .confirm;
    if (key == 0x1b) return .cancel;
    if (key == 0x09) return .tab;
    if (key == 'A' and ctrl) return .select_all;
    return .native;
}
test "zoom editor owns Enter and Escape, while typing never triggers viewer shortcuts" {
    try std.testing.expectEqual(EditKey.confirm, editKey(0x0d, false));
    try std.testing.expectEqual(EditKey.cancel, editKey(0x1b, false));
    try std.testing.expectEqual(EditKey.tab, editKey(0x09, false));
    try std.testing.expectEqual(EditKey.select_all, editKey('A', true));
    for ([_]usize{ '1', 'R', 'O', 'P', 'A', 'C', 'V', 'X', 'Z', ' ', 0x25, 0x27, 0x24, 0x23, 0xbb, 0xbd }) |key| {
        try std.testing.expectEqual(EditKey.native, editKey(key, false));
        if (key != 'A') try std.testing.expectEqual(EditKey.native, editKey(key, true));
    }
}
pub fn inRange(scale: f32, bounds: Limits) bool {
    return std.math.isFinite(scale) and scale >= bounds.minimum and scale <= bounds.maximum;
}
test "manual percentage, Polish decimals and multiplier input" {
    inline for (.{ .{ "125", 1.25 }, .{ "125%", 1.25 }, .{ "37,5%", 0.375 }, .{ "37.5 %", 0.375 }, .{ "  +125 %  ", 1.25 }, .{ "200×", 200.0 }, .{ "200x", 200.0 }, .{ "1,25X", 1.25 }, .{ ".5%", 0.005 }, .{ "60000%", 600.0 }, .{ "0,0005%", 0.000005 } }) |item| {
        const wide = comptime std.unicode.utf8ToUtf16LeStringLiteral(item[0]);
        try std.testing.expectApproxEqAbs(@as(f32, item[1]), try parse(wide), 0.000001);
    }
}
test "invalid manual values are rejected, never clamped or interpreted as a shortcut" {
    inline for (.{ "", " ", "%", "x", "+", "0", "0%", "-1%", "1e3%", "nan", "inf", "12abc", "1,2.3%", "1 25%", "12%%", "12xx", "9999999999999999999999999999999999999999999999999999x" }) |text| {
        const wide = comptime std.unicode.utf8ToUtf16LeStringLiteral(text);
        try std.testing.expectError(error.InvalidZoom, parse(wide));
    }
    const bounds = limits(2, 3, 174, 8_388_608);
    try std.testing.expect(inRange(217, bounds));
    try std.testing.expect(!inRange(bounds.maximum * 2, bounds));
    try std.testing.expect(!inRange(bounds.minimum / 2, bounds));
}
test "fractional captions keep editable precision and comma" {
    var buffer: [64]u8 = undefined;
    try std.testing.expectEqualStrings("37,5%", caption(&buffer, 0.375));
    try std.testing.expectEqualStrings("125,125%", caption(&buffer, 1.25125));
    try std.testing.expectEqualStrings("650,125×", caption(&buffer, 650.125));
    try std.testing.expectEqualStrings("0,0005%", caption(&buffer, 0.000005));
}
test "captions keep huge tiny-image magnifications readable" {
    var buffer: [32]u8 = undefined;
    try std.testing.expectEqualStrings("125%", caption(&buffer, 1.25));
    try std.testing.expectEqualStrings("650×", caption(&buffer, 650));
}
test "plus never reverses a fitted tiny image, including fits above old 32x cap" {
    const cap: f32 = 8_388_608;
    const sizes = [_][2]u32{ .{ 1, 1 }, .{ 2, 3 }, .{ 8, 8 }, .{ 16, 9 }, .{ 64, 64 }, .{ 4000, 3000 }, .{ 32768, 1 } };
    const viewports = [_][2]f32{ .{ 256, 128 }, .{ 1040, 520 }, .{ 3840, 2000 }, .{ 16000, 9000 } };
    for (sizes) |size| for (viewports) |view| {
        const fit = @min(view[0] / @as(f32, @floatFromInt(size[0])), view[1] / @as(f32, @floatFromInt(size[1])));
        const bounds = limits(size[0], size[1], fit, cap);
        var scale = fit;
        for (0..120) |_| {
            const next = nextScale(scale, 1.25, bounds);
            try std.testing.expect(next >= scale);
            if (scale < bounds.maximum) try std.testing.expect(next > scale);
            try std.testing.expect(next <= bounds.maximum);
            try std.testing.expect(next * @as(f32, @floatFromInt(@max(size[0], size[1]))) <= cap + 1);
            scale = next;
        }
        try std.testing.expectEqual(bounds.maximum, scale);
    };
}
test "minus never reverses and uses a fit-relative lower bound" {
    const bounds = limits(32768, 1, 0.00003, 8_388_608);
    var scale: f32 = 0.00003;
    for (0..120) |_| {
        const next = nextScale(scale, 0.8, bounds);
        try std.testing.expect(next <= scale);
        try std.testing.expect(next >= bounds.minimum);
        scale = next;
    }
    try std.testing.expectEqual(bounds.minimum, scale);
    try std.testing.expectEqual(@as(f32, 0.000001), nextScale(0.000001, 0.8, .{ .minimum = 0.01, .maximum = 100 }));
}
test "plus/minus are reciprocal away from bounds and never retain old 3200 percent ceiling" {
    const bounds = limits(1, 1, 520, 8_388_608);
    const plus = nextScale(520, 1.25, bounds);
    try std.testing.expectEqual(@as(f32, 650), plus);
    try std.testing.expectApproxEqAbs(@as(f32, 520), nextScale(plus, 0.8, bounds), 0.001);
    try std.testing.expect(nextScale(600, 1.25, bounds) > 600);
}
