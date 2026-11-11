//! Persistent native back buffer; no DC/bitmap allocation on steady-state paint.
const w = @import("win.zig");
const c = w.c;
pub const Surface = struct {
    dc: c.HDC = null,
    bitmap: c.HBITMAP = null,
    original: c.HGDIOBJ = null,
    width: i32 = 0,
    height: i32 = 0,
    pub fn ensure(self: *Surface, target: c.HDC, width: i32, height: i32) bool {
        if (width <= 0 or height <= 0) return false;
        if (self.dc != null and self.width == width and self.height == height) return true;
        const dc = c.CreateCompatibleDC(target);
        if (dc == null) return false;
        const bitmap = c.CreateCompatibleBitmap(target, width, height);
        if (bitmap == null) {
            _ = c.DeleteDC(dc);
            return false;
        }
        const old = c.SelectObject(dc, bitmap);
        if (old == null or old == c.HGDI_ERROR) {
            _ = c.DeleteObject(bitmap);
            _ = c.DeleteDC(dc);
            return false;
        }
        self.deinit();
        self.* = .{ .dc = dc, .bitmap = bitmap, .original = old, .width = width, .height = height };
        return true;
    }
    pub fn deinit(self: *Surface) void {
        if (self.dc != null) {
            _ = c.SelectObject(self.dc, self.original);
            _ = c.DeleteObject(self.bitmap);
            _ = c.DeleteDC(self.dc);
        }
        self.* = .{};
    }
};
