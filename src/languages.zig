//! Stable language indices shared with translations.zig. No OS state or I/O here.
//! SPDX-License-Identifier: GPL-3.0-or-later
const std = @import("std");
const w = @import("win.zig");

pub const count = 30;
pub const english_index: usize = 1;
pub const Language = struct {
    code: []const u8,
    native_name: []const u8,
    primary_langid: u16,
    rtl: bool,
    font_face: [:0]const u16,
    native_name_wide: [:0]const u16,
    code_wide: [:0]const u16,
};

fn language(comptime code: []const u8, comptime name: []const u8, primary: u16, rtl: bool, comptime face: []const u8) Language {
    return .{ .code = code, .native_name = name, .primary_langid = primary, .rtl = rtl, .font_face = w.L(face), .native_name_wide = w.L(name), .code_wide = w.L(code) };
}

// Do not sort: this is the translations.Entry.text index contract.
// XP may require its optional complex-script/East-Asian font packs. These are
// XP-era families, not Vista+ fonts; the selector also uses each row's family.
pub const all = [_]Language{
    language("pl", "Polski", 0x15, false, "Tahoma"),
    language("en", "English", 0x09, false, "Tahoma"),
    language("es", "Español", 0x0a, false, "Tahoma"),
    language("fr", "Français", 0x0c, false, "Tahoma"),
    language("de", "Deutsch", 0x07, false, "Tahoma"),
    language("pt", "Português", 0x16, false, "Tahoma"),
    language("ru", "Русский", 0x19, false, "Tahoma"),
    language("uk", "Українська", 0x22, false, "Tahoma"),
    language("it", "Italiano", 0x10, false, "Tahoma"),
    language("nl", "Nederlands", 0x13, false, "Tahoma"),
    language("cs", "Čeština", 0x05, false, "Tahoma"),
    language("hu", "Magyar", 0x0e, false, "Tahoma"),
    language("ro", "Română", 0x18, false, "Tahoma"),
    language("tr", "Türkçe", 0x1f, false, "Tahoma"),
    language("el", "Ελληνικά", 0x08, false, "Tahoma"),
    language("ar", "العربية", 0x01, true, "Tahoma"),
    language("he", "עברית", 0x0d, true, "Tahoma"),
    language("hi", "हिन्दी", 0x39, false, "Mangal"),
    language("bn", "বাংলা", 0x45, false, "Vrinda"),
    language("ur", "اردو", 0x20, true, "Tahoma"),
    language("zh", "中文", 0x04, false, "SimSun"),
    language("ja", "日本語", 0x11, false, "MS UI Gothic"),
    language("ko", "한국어", 0x12, false, "Gulim"),
    language("id", "Bahasa Indonesia", 0x21, false, "Tahoma"),
    language("vi", "Tiếng Việt", 0x2a, false, "Tahoma"),
    language("th", "ไทย", 0x1e, false, "Tahoma"),
    language("fa", "فارسی", 0x29, true, "Tahoma"),
    language("ta", "தமிழ்", 0x49, false, "Latha"),
    language("te", "తెలుగు", 0x4a, false, "Gautami"),
    language("mr", "मराठी", 0x4e, false, "Mangal"),
};

/// Only canonical two-letter catalog codes (ASCII case-insensitive), not locale
/// names such as pt-BR. Null lets the INI caller distinguish invalid from English.
pub fn indexForCode(code: []const u8) ?usize {
    for (all, 0..) |item, index| {
        if (std.ascii.eqlIgnoreCase(code, item.code)) return index;
    }
    return null;
}

/// PRIMARYLANGID: all regional/sublanguage variants select the same UI language.
/// An unsupported or neutral Windows UI language falls back to English.
pub fn indexForLangId(langid: u16) usize {
    const primary = langid & 0x03ff;
    for (all, 0..) |item, index| {
        if (item.primary_langid == primary) return index;
    }
    return english_index;
}

comptime {
    if (all.len != count) @compileError("language metadata must have 30 entries");
}
