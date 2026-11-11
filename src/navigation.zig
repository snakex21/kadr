//! Held-arrow folder browsing. SPDX-License-Identifier: GPL-3.0-or-later
//! Pure state, no Win32: the UI thread feeds key events and asks what to do.
//!
//! Problem it solves: the loader is "latest request wins". Keyboard autorepeat
//! (~30/s) is faster than decoding a large photo (~100 ms), so every repeat
//! made the decode in flight stale - nothing was shown while the key was held,
//! and on release the view jumped to wherever the repeats had got to.
//! Now autorepeats are coalesced while a navigation is in flight; each
//! completed image is shown and the next one is requested at once (decoding
//! overlaps painting). Releasing the key cancels the in-flight request, so
//! the view stays on the image that is on screen.
const std = @import("std");

/// An autorepeat older than this means the key is no longer really held
/// (e.g. the key-up went to another window). Slowest Windows repeat ~400 ms.
pub const repeat_timeout_ms: u32 = 600;

pub const Action = enum { navigate, coalesce };

pub const Held = struct {
    direction: i32 = 0,
    key: usize = 0,
    last_ms: u32 = 0,

    /// A key-down for a navigation key. `repeat` is lParam bit 30.
    /// `in_flight` is the direction of a navigation still being decoded (0 = none).
    pub fn press(self: *Held, key: usize, direction: i32, repeat: bool, in_flight: i32, now_ms: u32) Action {
        if (!repeat) {
            // A fresh press is always honoured (quick taps keep working).
            self.* = .{};
            return .navigate;
        }
        self.* = .{ .direction = direction, .key = key, .last_ms = now_ms };
        return if (in_flight == direction) .coalesce else .navigate;
    }

    /// Key-up. True when it ends held browsing: the caller cancels the request
    /// in flight so the view stops on the image currently shown.
    pub fn release(self: *Held, key: usize) bool {
        if (self.direction == 0 or key != self.key) return false;
        self.* = .{};
        return true;
    }

    /// Focus loss: forget the held state (the key-up will go elsewhere).
    pub fn reset(self: *Held) void {
        self.* = .{};
    }

    /// After an image arrives: should the next one be requested immediately?
    pub fn continues(self: *const Held, direction: i32, now_ms: u32) bool {
        return self.direction != 0 and self.direction == direction and now_ms -% self.last_ms <= repeat_timeout_ms;
    }
};

test "fresh presses always navigate and never start held mode" {
    var h = Held{};
    try std.testing.expectEqual(Action.navigate, h.press(0x27, 1, false, 0, 100));
    try std.testing.expectEqual(Action.navigate, h.press(0x27, 1, false, 1, 120)); // quick taps
    try std.testing.expect(!h.continues(1, 130));
    try std.testing.expect(!h.release(0x27));
}

test "autorepeats coalesce while the same direction is in flight" {
    var h = Held{};
    _ = h.press(0x27, 1, false, 0, 0);
    // 30 repeats while one decode is in flight: none of them re-requests.
    var navigations: usize = 0;
    for (1..31) |i| {
        if (h.press(0x27, 1, true, 1, @intCast(i * 33)) == .navigate) navigations += 1;
    }
    try std.testing.expectEqual(@as(usize, 0), navigations);
    try std.testing.expect(h.continues(1, 1000));
    // Nothing in flight (e.g. previous result already shown): navigate.
    try std.testing.expectEqual(Action.navigate, h.press(0x27, 1, true, 0, 1033));
    // Reversing direction while held is not coalesced.
    try std.testing.expectEqual(Action.navigate, h.press(0x25, -1, true, 1, 1066));
    try std.testing.expect(!h.continues(1, 1070) and h.continues(-1, 1070));
}

test "release cancels only held browsing of the same key; stale repeats stop" {
    var h = Held{};
    _ = h.press(0x27, 1, true, 1, 5000);
    try std.testing.expect(!h.release(0x25));
    try std.testing.expect(h.release(0x27));
    try std.testing.expect(!h.continues(1, 5010));
    try std.testing.expect(!h.release(0x27));
    _ = h.press(0x27, 1, true, 1, 5000);
    try std.testing.expect(h.continues(1, 5000 + repeat_timeout_ms));
    try std.testing.expect(!h.continues(1, 5001 + repeat_timeout_ms)); // key-up lost
    // GetTickCount wrap-around.
    _ = h.press(0x27, 1, true, 1, std.math.maxInt(u32) - 10);
    try std.testing.expect(h.continues(1, 50));
    h.reset();
    try std.testing.expect(!h.continues(1, 50));
}
