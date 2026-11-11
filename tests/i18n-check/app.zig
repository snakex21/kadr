//! Production-like link/import probe: no std.testing, CLI framework, or file I/O.
//! Includes the entire selector and runtime accessors but is NEVER run directly.
const w = @import("../../src/win.zig");
const i18n = @import("../../src/i18n.zig");
pub export fn wWinMainCRTStartup() callconv(.C) noreturn {
    i18n.init();
    if (w.c.GetCommandLineW()[0] == '-') i18n.choose(null);
    _ = w.c.MessageBoxW(null, i18n.L("Otwórz").ptr, i18n.fontFace().ptr, if (i18n.isRtl()) w.c.MB_RTLREADING else 0);
    w.c.ExitProcess(@intCast(i18n.languageIndex()));
}
