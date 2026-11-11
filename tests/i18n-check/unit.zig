const std = @import("std");
const languages = @import("../../src/languages.zig");
const i18n = @import("../../src/i18n.zig");
const translations = @import("../../src/translations.zig");
const w = @import("../../src/win.zig");

const class_name = i18n.L("Kadr.PrintPreview.1");
const filter = i18n.L("Obrazy\x00*.png;*.jpg\x00Wszystkie\x00*.*\x00");

test "30 distinct languages in the catalog index order with XP font metadata" {
    const codes = [_][]const u8{ "pl", "en", "es", "fr", "de", "pt", "ru", "uk", "it", "nl", "cs", "hu", "ro", "tr", "el", "ar", "he", "hi", "bn", "ur", "zh", "ja", "ko", "id", "vi", "th", "fa", "ta", "te", "mr" };
    try std.testing.expectEqual(@as(usize, 30), languages.all.len);
    for (languages.all, 0..) |item, index| {
        try std.testing.expectEqualStrings(codes[index], item.code);
        try std.testing.expectEqual(index, languages.indexForCode(item.code).?);
        try std.testing.expect(item.native_name.len > 0 and item.font_face.len > 0);
        try std.testing.expectEqual(@as(u16, 0), item.native_name_wide[item.native_name_wide.len]);
        try std.testing.expectEqual(@as(u16, 0), item.font_face[item.font_face.len]);
        const rtl = std.mem.eql(u8, item.code, "ar") or std.mem.eql(u8, item.code, "he") or std.mem.eql(u8, item.code, "ur") or std.mem.eql(u8, item.code, "fa");
        try std.testing.expectEqual(rtl, item.rtl);
        for (languages.all[0..index]) |previous| {
            try std.testing.expect(!std.mem.eql(u8, previous.native_name, item.native_name));
            try std.testing.expect(previous.primary_langid != item.primary_langid);
        }
    }
    try std.testing.expectEqual(@as(?usize, 5), languages.indexForCode("PT"));
    for ([_][]const u8{ "", "xx", "eng", "pt-BR", "en_US", " pl", "p\x00" }) |invalid| try std.testing.expect(languages.indexForCode(invalid) == null);
}

test "LANGID primary mapping covers every region and unknown defaults to English" {
    for (languages.all, 0..) |item, index| {
        var sublanguage: u16 = 0;
        while (sublanguage < 64) : (sublanguage += 1) {
            try std.testing.expectEqual(index, languages.indexForLangId(item.primary_langid | (sublanguage << 10)));
        }
    }
    try std.testing.expectEqual(@as(usize, 5), languages.indexForLangId(0x0416)); // pt-BR
    try std.testing.expectEqual(@as(usize, 5), languages.indexForLangId(0x0816)); // pt-PT
    for ([_]u16{ 0, 0xffff, 0x041d, 0x0436 }) |unknown| try std.testing.expectEqual(languages.english_index, languages.indexForLangId(unknown));
}

test "catalog entries are complete, nonempty, unique and selected UTF16 is constant" {
    try std.testing.expectEqual(languages.count, translations.count);
    for (translations.entries, 0..) |entry, index| {
        try std.testing.expectEqual(@as(usize, 30), entry.text.len);
        for (entry.text) |text| {
            try std.testing.expect(entry.source.len == 0 or text.len > 0);
            try std.testing.expect(std.unicode.utf8ValidateSlice(text));
        }
        for (translations.entries[0..index]) |previous| try std.testing.expect(!std.mem.eql(u8, previous.source, entry.source));
    }
    // No init here: the safe pre-init runtime default is English.
    try std.testing.expectEqualStrings("en", i18n.languageCode());
    try std.testing.expectEqualStrings("Open", i18n.utf8("Otwórz"));
    try std.testing.expectEqualSlices(u16, w.L("Open"), i18n.L("Otwórz"));
    try std.testing.expectEqual(@as(u16, 0), i18n.L("Otwórz")[i18n.L("Otwórz").len]);
    try std.testing.expectEqualSlices(u16, w.L("Kadr.PrintPreview.1"), class_name);
    try std.testing.expectEqualSlices(u16, w.L("Obrazy\x00*.png;*.jpg\x00Wszystkie\x00*.*\x00"), filter);
    try std.testing.expectEqual(@as(u16, 0), filter[filter.len]);
    try std.testing.expectEqual(@as(u16, 0), filter[6]);
    try std.testing.expectEqualStrings("unknown\x00literal", i18n.utf8("unknown\x00literal"));
    // Force all current catalog entries through both lookups, including any
    // embedded-NUL filters the coordinator adds later.
    inline for (translations.entries) |entry| {
        try std.testing.expectEqualStrings(entry.text[languages.english_index], i18n.utf8(entry.source));
        try std.testing.expectEqualSlices(u16, w.L(entry.text[languages.english_index]), i18n.L(entry.source));
    }
}
