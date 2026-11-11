// Compact native control layout. SPDX-License-Identifier: GPL-3.0-or-later
const std = @import("std");
const w = @import("win.zig");
const c = w.c;
const ui = @import("ui.zig");

pub const height: i32 = 64;
pub const status_height: i32 = 48;
pub const Controls = struct {
    buttons: []const c.HWND,
    counter: c.HWND,
    zoom_name: c.HWND,
    zoom_edit: c.HWND,
    status: c.HWND,
    page_label: c.HWND,
};

const Geometry = struct {
    buttons: [19]c.RECT,
    counter: c.RECT,
    zoom_name: c.RECT,
    zoom_edit: c.RECT,
    status: c.RECT,
    page_label: c.RECT,
    zoom_frame: c.RECT,
    compact: bool,
};
fn rect(x: i32, y: i32, width: i32, h: i32) c.RECT {
    return .{ .left = x, .top = y, .right = x + width, .bottom = y + h };
}
fn advance(x: *i32, y: i32, width: i32, gap: i32) c.RECT {
    const r = rect(x.*, y, width, 36);
    x.* += width + gap;
    return r;
}
/// Buttons labelled with text (Open, Fit, Edit, Print) when there is room.
pub const labelled = [_]usize{ 0, 3, 18, 9 };
/// Not on the toolbar (reachable from the "Więcej" menu and shortcuts).
pub const menu_only = [_]usize{ 4, 14 };
fn geometry(client: c.RECT, canvas: c.RECT) Geometry {
    var g: Geometry = undefined;
    const width = client.right - client.left;
    g.compact = width < 1000;
    const y = client.top + 14;
    var x = client.left + 12;
    // Navigation.
    g.buttons[0] = advance(&x, y, if (g.compact) 40 else 100, 8);
    g.buttons[1] = advance(&x, y, 36, 4);
    g.buttons[2] = advance(&x, y, 36, 4);
    g.counter = advance(&x, y, 60, 8);
    // View.
    g.buttons[3] = advance(&x, y, if (g.compact) 36 else 100, 12);
    g.buttons[5] = advance(&x, y, 32, 4);
    // Refresh may show this label again; zero width keeps it out of the row.
    g.zoom_name = rect(x, y, 0, 36);
    g.zoom_frame = rect(x, y + 2, 78, 32);
    g.zoom_edit = rect(x + 4, y + 5, 70, 26);
    x += 82;
    g.buttons[16] = advance(&x, y, 28, 4);
    g.buttons[6] = advance(&x, y, 32, 12);
    g.buttons[7] = advance(&x, y, 36, 12);
    // Main actions: edit, print, save.
    g.buttons[18] = advance(&x, y, if (g.compact) 40 else 96, 4);
    g.buttons[9] = advance(&x, y, if (g.compact) 40 else 96, 4);
    g.buttons[17] = advance(&x, y, 36, 12);
    g.buttons[10] = advance(&x, y, 36, 4);
    g.buttons[11] = advance(&x, y, 36, 4);
    // Pause is visible only for animations, so it sits last: no gap otherwise.
    g.buttons[8] = advance(&x, y, 36, 4);
    for (menu_only) |index| g.buttons[index] = rect(client.left, client.top, 0, 0);

    // Reserve the right side for page navigation (or the empty-view hint).
    g.status = rect(client.left + 16, client.bottom - 42, @max(0, width - 256), 32);
    g.buttons[12] = rect(client.right - 208, client.bottom - 41, 36, 32);
    g.page_label = rect(client.right - 166, client.bottom - 41, 92, 32);
    g.buttons[13] = rect(client.right - 68, client.bottom - 41, 36, 32);
    const cx = @divTrunc(canvas.left + canvas.right, 2);
    const cy = @divTrunc(canvas.top + canvas.bottom, 2);
    g.buttons[15] = rect(cx - 94, cy + 52, 188, 44);
    return g;
}
fn move(hwnd: c.HWND, r: c.RECT) void {
    _ = c.MoveWindow(hwnd, r.left, r.top, r.right - r.left, r.bottom - r.top, c.TRUE);
}
// Placement only: visibility, state, refresh and invalidation belong to main.
pub fn place(client: c.RECT, canvas: c.RECT, controls: Controls) c.RECT {
    const g = geometry(client, canvas);
    std.debug.assert(controls.buttons.len >= g.buttons.len);
    for (g.buttons, 0..) |r, index| {
        const compact = if (index == 15) false else if (std.mem.indexOfScalar(usize, &labelled, index) != null) g.compact else true;
        ui.place(controls.buttons[index], r.left, r.top, r.right - r.left, r.bottom - r.top, compact);
    }
    move(controls.counter, g.counter);
    move(controls.zoom_name, g.zoom_name);
    move(controls.zoom_edit, g.zoom_edit);
    move(controls.status, g.status);
    move(controls.page_label, g.page_label);
    return g.zoom_frame;
}

test "single row fits minimum client width and label breakpoint without overlaps" {
    for ([_]i32{ 784, 800, 999, 1000, 1024, 1280 }) |width| {
        const client = rect(0, 0, width, 600);
        const canvas = rect(16, height, width - 32, 600 - height - status_height);
        const g = geometry(client, canvas);
        const row = [_]c.RECT{
            g.buttons[0],  g.buttons[1],  g.buttons[2],  g.counter,
            g.buttons[3],  g.buttons[5],  g.zoom_frame,  g.buttons[16],
            g.buttons[6],  g.buttons[7],  g.buttons[18], g.buttons[9],
            g.buttons[17], g.buttons[10], g.buttons[11], g.buttons[8],
        };
        var right: i32 = client.left;
        for (row) |r| {
            try std.testing.expect(r.left >= right);
            try std.testing.expect(r.right > r.left);
            try std.testing.expect(r.right <= client.right - 12);
            try std.testing.expect(r.top >= client.top and r.bottom < client.top + height);
            right = r.right;
        }
        for (menu_only) |index| try std.testing.expectEqual(g.buttons[index].left, g.buttons[index].right);
        try std.testing.expectEqual(width < 1000, g.compact);
        try std.testing.expectEqual(@as(i32, if (g.compact) 40 else 100), g.buttons[0].right - g.buttons[0].left);
        try std.testing.expectEqual(@as(i32, if (g.compact) 36 else 100), g.buttons[3].right - g.buttons[3].left);
        try std.testing.expectEqual(@as(i32, if (g.compact) 40 else 96), g.buttons[18].right - g.buttons[18].left);
        try std.testing.expectEqual(@as(i32, if (g.compact) 40 else 96), g.buttons[9].right - g.buttons[9].left);
        try std.testing.expectEqual(g.zoom_name.left, g.zoom_name.right);
        try std.testing.expectEqual(@as(i32, 78), g.zoom_frame.right - g.zoom_frame.left);
        try std.testing.expectEqual(@as(i32, 70), g.zoom_edit.right - g.zoom_edit.left);
        try std.testing.expectEqual(@as(i32, 19), g.zoom_edit.top);
        try std.testing.expectEqual(@as(i32, 26), g.zoom_edit.bottom - g.zoom_edit.top);
        try std.testing.expect(g.zoom_edit.left > g.zoom_frame.left and g.zoom_edit.right < g.zoom_frame.right);
        try std.testing.expect(g.zoom_edit.top > g.zoom_frame.top and g.zoom_edit.bottom < g.zoom_frame.bottom);
    }
}

test "footer and empty-view button keep their own space" {
    const client = rect(0, 0, 784, 600);
    const canvas = rect(16, height, 752, 600 - height - status_height);
    const g = geometry(client, canvas);
    try std.testing.expectEqual(@as(i32, 16), g.status.left);
    try std.testing.expectEqual(client.bottom - 42, g.status.top);
    try std.testing.expectEqual(@as(i32, 32), g.status.bottom - g.status.top);
    const footer = [_]c.RECT{ g.status, g.buttons[12], g.page_label, g.buttons[13] };
    var right: i32 = client.left;
    for (footer) |r| {
        try std.testing.expect(r.left >= right);
        try std.testing.expect(r.top > client.bottom - status_height);
        try std.testing.expect(r.bottom <= client.bottom);
        right = r.right;
    }
    try std.testing.expectEqual(client.right - 208, g.buttons[12].left);
    try std.testing.expectEqual(client.bottom - 41, g.buttons[12].top);
    try std.testing.expectEqual(@as(i32, 32), g.buttons[12].bottom - g.buttons[12].top);
    const empty_button = g.buttons[15];
    try std.testing.expectEqual(@divTrunc(canvas.left + canvas.right, 2) - 94, empty_button.left);
    try std.testing.expectEqual(@divTrunc(canvas.top + canvas.bottom, 2) + 52, empty_button.top);
    try std.testing.expectEqual(@as(i32, 188), empty_button.right - empty_button.left);
    try std.testing.expectEqual(@as(i32, 44), empty_button.bottom - empty_button.top);
}

test "native placement and drawing APIs compile" {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(ui);
}
