const std = @import("std");
pub fn L(comptime value: []const u8) *const [blk: {
        @setEvalBranchQuota(30000);
        break :blk std.unicode.calcUtf16LeLen(value) catch unreachable;
    }:0]u16 {
    @setEvalBranchQuota(30000);
    return std.unicode.utf8ToUtf16LeStringLiteral(value);
}
pub const c = @cImport({
    @cDefine("UNICODE", "1");
    @cDefine("_UNICODE", "1");
    @cDefine("WINVER", "0x0501");
    @cDefine("_WIN32_WINNT", "0x0501");
    @cDefine("WIN32_LEAN_AND_MEAN", "1");
    // On x86 Windows int and long are both 32-bit. Avoid Zig 0.11's broken
    // translation of MinGW's token-pasting L suffix on typed integer macros.
    @cDefine("__MSABI_LONG(x)", "x");
    @cInclude("windows.h");
    @cInclude("commdlg.h");
    @cInclude("shellapi.h");
    @cInclude("commctrl.h");
});
pub const GpImage = opaque {};
pub const GpGraphics = opaque {};
pub const Guid = extern struct { a: u32, b: u16, c: u16, d: [8]u8 };
pub const StartupInput = extern struct { version: u32 = 1, callback: ?*anyopaque = null, suppress_thread: i32 = 0, suppress_codecs: i32 = 0 };
pub const PropertyItem = extern struct { id: u32, length: u32, kind: u16, value: ?*anyopaque };
pub const dimension_time = Guid{ .a = 0x6aedbd6d, .b = 0x3fb5, .c = 0x418a, .d = .{ 0x83, 0xa6, 0x7f, 0x45, 0x22, 0x9d, 0xc8, 0x72 } };
pub const dimension_page = Guid{ .a = 0x7462dc86, .b = 0x6180, .c = 0x4c7e, .d = .{ 0x8e, 0x3f, 0xee, 0x73, 0x33, 0xa7, 0xa4, 0x83 } };
pub extern "gdiplus" fn GdiplusStartup(*usize, *const StartupInput, ?*anyopaque) callconv(.Stdcall) i32;
pub extern "gdiplus" fn GdiplusShutdown(usize) callconv(.Stdcall) void;
pub extern "gdiplus" fn GdipLoadImageFromFile([*:0]const u16, *?*GpImage) callconv(.Stdcall) i32;
pub extern "gdiplus" fn GdipDisposeImage(*GpImage) callconv(.Stdcall) i32;
pub extern "gdiplus" fn GdipGetImageWidth(*GpImage, *u32) callconv(.Stdcall) i32;
pub extern "gdiplus" fn GdipGetImageHeight(*GpImage, *u32) callconv(.Stdcall) i32;
pub extern "gdiplus" fn GdipGetImageHorizontalResolution(*GpImage, *f32) callconv(.Stdcall) i32;
pub extern "gdiplus" fn GdipGetImageVerticalResolution(*GpImage, *f32) callconv(.Stdcall) i32;
pub extern "gdiplus" fn GdipImageGetFrameCount(*GpImage, *const Guid, *u32) callconv(.Stdcall) i32;
pub extern "gdiplus" fn GdipImageSelectActiveFrame(*GpImage, *const Guid, u32) callconv(.Stdcall) i32;
pub extern "gdiplus" fn GdipGetPropertyItemSize(*GpImage, u32, *u32) callconv(.Stdcall) i32;
pub extern "gdiplus" fn GdipGetPropertyItem(*GpImage, u32, u32, *PropertyItem) callconv(.Stdcall) i32;
pub extern "gdiplus" fn GdipImageRotateFlip(*GpImage, i32) callconv(.Stdcall) i32;
pub extern "gdiplus" fn GdipCreateFromHDC(c.HDC, *?*GpGraphics) callconv(.Stdcall) i32;
pub extern "gdiplus" fn GdipDeleteGraphics(*GpGraphics) callconv(.Stdcall) i32;
pub extern "gdiplus" fn GdipSetInterpolationMode(*GpGraphics, i32) callconv(.Stdcall) i32;
pub extern "gdiplus" fn GdipSetPageUnit(*GpGraphics, i32) callconv(.Stdcall) i32;
pub extern "gdiplus" fn GdipSetClipRect(*GpGraphics, f32, f32, f32, f32, i32) callconv(.Stdcall) i32;
pub extern "gdiplus" fn GdipDrawImageRectRect(*GpGraphics, *GpImage, f32, f32, f32, f32, f32, f32, f32, f32, i32, ?*anyopaque, ?*anyopaque, ?*anyopaque) callconv(.Stdcall) i32;
pub fn imageRect(dc: c.HDC, image: *GpImage, x: f32, y: f32, width: f32, height: f32, iw: u32, ih: u32) void {
    imageRectClipped(dc, image, x, y, width, height, iw, ih, null);
}
pub fn imageRectClipped(dc: c.HDC, image: *GpImage, x: f32, y: f32, width: f32, height: f32, iw: u32, ih: u32, clip: ?c.RECT) void {
    var graphics: ?*GpGraphics = null;
    if (GdipCreateFromHDC(dc, &graphics) != 0) return;
    defer _ = GdipDeleteGraphics(graphics.?);
    _ = GdipSetPageUnit(graphics.?, 2);
    if (clip) |r| _ = GdipSetClipRect(graphics.?, @floatFromInt(r.left), @floatFromInt(r.top), @floatFromInt(r.right - r.left), @floatFromInt(r.bottom - r.top), 0);
    _ = GdipSetInterpolationMode(graphics.?, 7);
    _ = GdipDrawImageRectRect(graphics.?, image, x, y, width, height, 0, 0, @floatFromInt(iw), @floatFromInt(ih), 2, null, null, null);
}
pub fn text(dc: c.HDC, rect: *c.RECT, value: [*:0]const u16, flags: u32) void {
    _ = c.DrawTextW(dc, value, -1, rect, flags);
}
pub fn setFont(hwnd: c.HWND) void {
    _ = c.SendMessageW(hwnd, c.WM_SETFONT, @intFromPtr(c.GetStockObject(c.DEFAULT_GUI_FONT)), 1);
}
pub fn button(parent: c.HWND, label: [*:0]const u16, id: usize, x: i32, y: i32, width: i32) c.HWND {
    const h = c.CreateWindowExW(0, L("BUTTON"), label, c.WS_CHILD | c.WS_VISIBLE | c.WS_TABSTOP | c.BS_PUSHBUTTON, x, y, width, 30, parent, @ptrFromInt(id), null, null);
    setFont(h);
    return h;
}
pub fn utf16(buffer: []u16, value: []const u8) [:0]const u16 {
    const n = std.unicode.utf8ToUtf16Le(buffer[0 .. buffer.len - 1], value) catch 0;
    buffer[n] = 0;
    return buffer[0..n :0];
}
pub fn message(hwnd: c.HWND, value: [*c]const u16) void {
    _ = c.MessageBoxW(hwnd, value, L("Kadr"), c.MB_OK | c.MB_ICONINFORMATION);
}
pub fn rgb(r: u8, g: u8, b: u8) u32 {
    return @as(u32, r) | (@as(u32, g) << 8) | (@as(u32, b) << 16);
}
