//! Prints every resolved catalog entry as JSON (source + 30 texts) to stdout.
//! Used by tests/locale_coverage.py to find strings that fall back to English.
const std = @import("std");
const translations = @import("../../src/translations.zig");

pub fn main() !void {
    var buffer = std.io.bufferedWriter(std.io.getStdOut().writer());
    const out = buffer.writer();
    try out.writeAll("[");
    inline for (translations.entries, 0..) |entry, index| {
        if (index != 0) try out.writeAll(",");
        try out.writeAll("\n[");
        try std.json.encodeJsonString(entry.source, .{}, out);
        for (entry.text) |text| {
            try out.writeAll(",");
            try std.json.encodeJsonString(text, .{}, out);
        }
        try out.writeAll("]");
    }
    try out.writeAll("\n]\n");
    try buffer.flush();
}
