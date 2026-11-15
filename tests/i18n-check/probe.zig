//! Dedicated disposable XP/x86 probe, never the production viewer.
const std = @import("std");
const w = @import("../../src/win.zig");
const c = w.c;
const i18n = @import("../../src/i18n.zig");
const translations = @import("../../src/translations.zig");

const class_name = i18n.L("Kadr.PrintPreview.1");
const filter = i18n.L("Obrazy\x00*.png\x00\x00");
var output: [131072]u8 = undefined;
var used: usize = 0;

fn print(comptime fmt: []const u8, args: anytype) void {
    const text = std.fmt.bufPrint(output[used..], fmt, args) catch return;
    used += text.len;
}
fn wide(comptime key: []const u8, text: [:0]const u16) void {
    print(key ++ "=", .{});
    for (text) |unit| print("{x:0>4}", .{unit});
    print("\nsentinel_" ++ key ++ "={d}\n", .{text[text.len]});
}
fn snapshot() void {
    print("code={s}\nindex={d}\nrtl={d}\nerror={d}\nos_langid={d}\n", .{ i18n.languageCode(), i18n.languageIndex(), @intFromBool(i18n.isRtl()), @intFromBool(i18n.hasSettingsError()), c.GetUserDefaultUILanguage() });
    wide("path", i18n.settingsPath());
    wide("font", i18n.fontFace());
    wide("open", i18n.L("Otwórz"));
    wide("class", class_name);
    wide("filter", filter);
    print("open_utf8={s}\n", .{i18n.utf8("Otwórz")});
    print("catalog_entries={d}\n", .{translations.entries.len});
    // Compare the cached UTF-16 from L against an independent std conversion.
    var converted: [8192]u16 = undefined;
    var valid = true;
    inline for (translations.entries) |entry| {
        const text = entry.text[i18n.languageIndex()];
        const n = std.unicode.utf8ToUtf16Le(&converted, text) catch 0;
        const translated = i18n.L(entry.source);
        if (!std.mem.eql(u16, converted[0..n], translated) or translated[translated.len] != 0 or !std.mem.eql(u8, text, i18n.utf8(entry.source))) valid = false;
    }
    print("catalog_valid={d}\n", .{@intFromBool(valid)});
}

pub export fn wWinMainCRTStartup() callconv(.C) noreturn {
    const command = std.mem.span(c.GetCommandLineW());
    i18n.init();
    if (std.mem.endsWith(u16, command, w.L(" --choose"))) i18n.choose(null);
    i18n.init(); // Must not apply a pending selector change in the same process.
    snapshot();
    var written: c.DWORD = 0;
    _ = c.WriteFile(c.GetStdHandle(c.STD_OUTPUT_HANDLE), &output, @intCast(used), &written, null);
    c.ExitProcess(0);
}
