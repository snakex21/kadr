//! Printer-independent geometry. All page coordinates are millimetres measured
//! from the physical sheet's top-left, NOT from the printer DC's origin.
const std = @import("std");

// Keep the original four tags/order for callers; metric photos are NOT inches.
pub const Paper = enum { a4, a5, letter, photo_10x15, a3, a6, b4, b5, legal, executive, tabloid, photo_13x18, photo_15x20, photo_20x25, inch_4x6, inch_5x7, inch_8x10 };
pub const Orientation = enum { portrait, landscape };
/// Order = print-preview combo order. `stretch` fills the whole clip area
/// ignoring aspect ratio (IrfanView-like "keep aspect ratio" off).
pub const Scale = enum { fit, fill, stretch, actual_96dpi, percent, width_mm, height_mm };
pub const Position = struct { x: f64, y: f64 };
pub const min_media_mm = 10.0;
pub const max_media_mm = 3276.7; // DEVMODE signed SHORT, tenths of a mm.
pub const ImageSize = struct { width: u32, height: u32 };

pub const Rect = struct {
    x: f64,
    y: f64,
    width: f64,
    height: f64,

    pub fn right(self: Rect) f64 {
        return self.x + self.width;
    }
    pub fn bottom(self: Rect) f64 {
        return self.y + self.height;
    }
};

pub const Margins = struct {
    left: f64 = 10,
    top: f64 = 10,
    right: f64 = 10,
    bottom: f64 = 10,
};
pub const Settings = struct {
    scale: Scale = .fit,
    margins: Margins = .{},
    center: bool = true,
    /// Absolute physical-sheet top-left in mm; overrides legacy center.
    position: ?Position = null,
    percent: f64 = 100, // Relative to 96 DPI, NOT to Fit.
    physical_mm: f64 = 100, // width_mm/height_mm; aspect is always locked.
};
pub const Page = struct {
    width: f64,
    height: f64,
    printable: Rect,
};

/// These values come directly from GetDeviceCaps, including both physical
/// offsets. In particular HORZRES/VERTRES are NOT the physical paper size.
pub const DeviceCaps = struct {
    dpi_x: i32,
    dpi_y: i32,
    physical_width: i32,
    physical_height: i32,
    offset_x: i32,
    offset_y: i32,
    printable_width: i32,
    printable_height: i32,
};

pub const Placement = struct {
    image: Rect,
    /// Intersection of requested margins, physical sheet and printable area.
    clip: Rect,
};

/// Pixel coordinates = mm * scale + origin. The same placement is used for
/// preview and printing; only this transform changes (including DC offsets).
pub const Transform = struct {
    scale_x: f64,
    scale_y: f64,
    origin_x: f64 = 0,
    origin_y: f64 = 0,

    pub fn deltaMM(self: Transform, dx: f64, dy: f64) Position {
        return .{ .x = dx / self.scale_x, .y = dy / self.scale_y };
    }

    pub fn rect(self: Transform, r: Rect) Rect {
        return .{
            .x = r.x * self.scale_x + self.origin_x,
            .y = r.y * self.scale_y + self.origin_y,
            .width = r.width * self.scale_x,
            .height = r.height * self.scale_y,
        };
    }
};

pub fn printerTransform(caps: DeviceCaps) Transform {
    return .{
        .scale_x = @as(f64, @floatFromInt(caps.dpi_x)) / 25.4,
        .scale_y = @as(f64, @floatFromInt(caps.dpi_y)) / 25.4,
        .origin_x = -@as(f64, @floatFromInt(caps.offset_x)),
        .origin_y = -@as(f64, @floatFromInt(caps.offset_y)),
    };
}

/// Used only until an actual printer DC is available. Its printable area is
/// deliberately the whole sheet: the UI must label the hardware area unknown.
pub fn paperPage(paper: Paper, orientation: Orientation) Page {
    const dimensions: [2]f64 = switch (paper) {
        .a4 => .{ 210, 297 },
        .a5 => .{ 148, 210 },
        .letter => .{ 215.9, 279.4 },
        .photo_10x15 => .{ 100, 150 },
        .a3 => .{ 297, 420 },
        .a6 => .{ 105, 148 },
        .b4 => .{ 250, 353 }, // ISO, not JIS
        .b5 => .{ 176, 250 },
        .legal => .{ 215.9, 355.6 },
        .executive => .{ 184.15, 266.7 },
        .tabloid => .{ 279.4, 431.8 },
        .photo_13x18 => .{ 130, 180 },
        .photo_15x20 => .{ 150, 200 },
        .photo_20x25 => .{ 200, 250 },
        .inch_4x6 => .{ 101.6, 152.4 },
        .inch_5x7 => .{ 127, 177.8 },
        .inch_8x10 => .{ 203.2, 254 },
    };
    return customPage(dimensions[0], dimensions[1], orientation).?;
}

pub fn customPage(width_mm: f64, height_mm: f64, orientation: Orientation) ?Page {
    if (!std.math.isFinite(width_mm) or !std.math.isFinite(height_mm) or
        width_mm < min_media_mm or height_mm < min_media_mm or
        width_mm > max_media_mm or height_mm > max_media_mm) return null;
    const width = if (orientation == .portrait) width_mm else height_mm;
    const height = if (orientation == .portrait) height_mm else width_mm;
    return .{ .width = width, .height = height, .printable = .{ .x = 0, .y = 0, .width = width, .height = height } };
}

pub fn bestFitOrientation(width_px: u32, height_px: u32, media: Page, margins: Margins, preferred: Orientation) Orientation {
    if (width_px == 0 or height_px == 0 or
        !std.math.isFinite(media.width) or !std.math.isFinite(media.height)) return preferred;
    if (!nonnegative(margins.left) or !nonnegative(margins.top) or
        !nonnegative(margins.right) or !nonnegative(margins.bottom)) return preferred;
    const page = customPage(@min(media.width, media.height), @max(media.width, media.height), .portrait) orelse return preferred;
    const portrait_width = page.width - margins.left - margins.right;
    const portrait_height = page.height - margins.top - margins.bottom;
    const landscape_width = page.height - margins.left - margins.right;
    const landscape_height = page.width - margins.top - margins.bottom;
    const iw = @as(f64, @floatFromInt(width_px));
    const ih = @as(f64, @floatFromInt(height_px));
    const portrait_scale = if (portrait_width > 0 and portrait_height > 0) @min(portrait_width / iw, portrait_height / ih) else 0;
    const landscape_scale = if (landscape_width > 0 and landscape_height > 0) @min(landscape_width / iw, landscape_height / ih) else 0;
    // Keep the preference when the FIT scales differ only by numerical noise.
    if (@fabs(portrait_scale - landscape_scale) <= @max(portrait_scale, landscape_scale) * 1e-12) return preferred;
    return if (landscape_scale > portrait_scale) .landscape else .portrait;
}

pub fn intersection(a: Rect, b: Rect) ?Rect {
    const x = @max(a.x, b.x);
    const y = @max(a.y, b.y);
    const right = @min(a.right(), b.right());
    const bottom = @min(a.bottom(), b.bottom());
    if (right <= x or bottom <= y) return null;
    return .{ .x = x, .y = y, .width = right - x, .height = bottom - y };
}

pub fn pageFromDevice(caps: DeviceCaps) ?Page {
    if (caps.dpi_x <= 0 or caps.dpi_y <= 0 or caps.physical_width <= 0 or
        caps.physical_height <= 0 or caps.offset_x < 0 or caps.offset_y < 0 or
        caps.printable_width <= 0 or caps.printable_height <= 0) return null;
    const x_mm = 25.4 / @as(f64, @floatFromInt(caps.dpi_x));
    const y_mm = 25.4 / @as(f64, @floatFromInt(caps.dpi_y));
    const width = @as(f64, @floatFromInt(caps.physical_width)) * x_mm;
    const height = @as(f64, @floatFromInt(caps.physical_height)) * y_mm;
    const printable = intersection(.{ .x = 0, .y = 0, .width = width, .height = height }, .{
        .x = @as(f64, @floatFromInt(caps.offset_x)) * x_mm,
        .y = @as(f64, @floatFromInt(caps.offset_y)) * y_mm,
        .width = @as(f64, @floatFromInt(caps.printable_width)) * x_mm,
        .height = @as(f64, @floatFromInt(caps.printable_height)) * y_mm,
    }) orelse return null;
    return .{ .width = width, .height = height, .printable = printable };
}

fn nonnegative(value: f64) bool {
    return std.math.isFinite(value) and value >= 0;
}

fn validRect(r: Rect) bool {
    return std.math.isFinite(r.x) and std.math.isFinite(r.y) and
        std.math.isFinite(r.width) and std.math.isFinite(r.height) and
        r.width > 0 and r.height > 0;
}

pub fn place(page: Page, image: ImageSize, settings: Settings) ?Placement {
    if (image.width == 0 or image.height == 0 or
        !std.math.isFinite(page.width) or !std.math.isFinite(page.height) or
        page.width <= 0 or page.height <= 0 or !validRect(page.printable)) return null;
    const m = settings.margins;
    if (!nonnegative(m.left) or !nonnegative(m.top) or
        !nonnegative(m.right) or !nonnegative(m.bottom)) return null;
    const margin_box = Rect{ .x = m.left, .y = m.top, .width = page.width - m.left - m.right, .height = page.height - m.top - m.bottom };
    if (margin_box.width <= 0 or margin_box.height <= 0) return null;
    const sheet = Rect{ .x = 0, .y = 0, .width = page.width, .height = page.height };
    const printable = intersection(sheet, page.printable) orelse return null;
    const clip = intersection(margin_box, printable) orelse return null;
    // "100%" explicitly means one image pixel per 1/96 inch, independent of
    // image metadata and of the (possibly non-square) printer resolution.
    // Stretch: exactly the usable area; position/centering do not apply.
    if (settings.scale == .stretch) return .{ .clip = clip, .image = clip };
    const iw = @as(f64, @floatFromInt(image.width)) * 25.4 / 96;
    const ih = @as(f64, @floatFromInt(image.height)) * 25.4 / 96;
    const factor = switch (settings.scale) {
        .stretch => unreachable,
        .fit => @min(clip.width / iw, clip.height / ih),
        .fill => @max(clip.width / iw, clip.height / ih),
        .actual_96dpi => 1,
        .percent => if (std.math.isFinite(settings.percent) and settings.percent >= 0.1 and settings.percent <= 1000) settings.percent / 100 else return null,
        .width_mm => if (validPhysical(settings.physical_mm)) settings.physical_mm / iw else return null,
        .height_mm => if (validPhysical(settings.physical_mm)) settings.physical_mm / ih else return null,
    };
    const width = iw * factor;
    const height = ih * factor;
    if (!std.math.isFinite(width) or !std.math.isFinite(height) or width > 100000 or height > 100000) return null;
    const position = settings.position orelse Position{
        .x = clip.x + if (settings.center) (clip.width - width) / 2 else 0,
        .y = clip.y + if (settings.center) (clip.height - height) / 2 else 0,
    };
    if (!std.math.isFinite(position.x) or !std.math.isFinite(position.y) or
        @fabs(position.x) > 10000 or @fabs(position.y) > 10000) return null;
    const image_rect = Rect{ .x = position.x, .y = position.y, .width = width, .height = height };
    // A completely invisible image must never produce an enabled Print action.
    _ = intersection(image_rect, clip) orelse return null;
    return .{ .clip = clip, .image = image_rect };
}

fn validPhysical(value: f64) bool {
    return std.math.isFinite(value) and value >= 0.1 and value <= 10000;
}

/// Keep a recoverable grab area while dragging, including very large Fill images.
pub fn dragPosition(p: Placement, delta: Position) Position {
    const grab_x = @min(5, @min(p.image.width, p.clip.width) / 2);
    const grab_y = @min(5, @min(p.image.height, p.clip.height) / 2);
    return .{
        .x = std.math.clamp(p.image.x + delta.x, @max(-10000, p.clip.x + grab_x - p.image.width), @min(10000, p.clip.right() - grab_x)),
        .y = std.math.clamp(p.image.y + delta.y, @max(-10000, p.clip.y + grab_y - p.image.height), @min(10000, p.clip.bottom() - grab_y)),
    };
}

fn near(actual: f64, expected: f64) !void {
    try std.testing.expectApproxEqAbs(expected, actual, 0.000001);
}

const sample_caps = DeviceCaps{
    .dpi_x = 254, .dpi_y = 508,
    .physical_width = 2100, .physical_height = 5940,
    .offset_x = 50, .offset_y = 140,
    .printable_width = 2000, .printable_height = 5600,
};

test "all papers and both orientations have physical dimensions" {
    const widths = [_]f64{ 210, 148, 215.9, 100, 297, 105, 250, 176, 215.9, 184.15, 279.4, 130, 150, 200, 101.6, 127, 203.2 };
    const heights = [_]f64{ 297, 210, 279.4, 150, 420, 148, 353, 250, 355.6, 266.7, 431.8, 180, 200, 250, 152.4, 177.8, 254 };
    for (std.enums.values(Paper), 0..) |paper, i| {
        const portrait = paperPage(paper, .portrait);
        const landscape = paperPage(paper, .landscape);
        try near(portrait.width, widths[i]);
        try near(portrait.height, heights[i]);
        try near(landscape.width, heights[i]);
        try near(landscape.height, widths[i]);
        try near(landscape.printable.width, landscape.width);
    }
}

test "best fit uses pixel aspect independent of resolution and baked rotation" {
    const media = paperPage(.a4, .portrait);
    for ([_]u32{ 1, 10, 1000, 1000000 }) |resolution| {
        try std.testing.expectEqual(Orientation.landscape, bestFitOrientation(4 * resolution, 3 * resolution, media, .{}, .portrait));
        try std.testing.expectEqual(Orientation.portrait, bestFitOrientation(3 * resolution, 4 * resolution, media, .{}, .landscape));
    }
    for (std.enums.values(Orientation)) |preferred| {
        try std.testing.expectEqual(preferred, bestFitOrientation(1000, 1000, media, .{}, preferred));
    }
}

test "best fit normalizes swapped custom media and preserves numerical ties" {
    for ([_]Page{
        paperPage(.a4, .portrait), paperPage(.a4, .landscape),
        customPage(320, 180, .portrait).?, customPage(180, 320, .landscape).?,
    }) |media| {
        try std.testing.expectEqual(Orientation.landscape, bestFitOrientation(400, 200, media, .{}, .portrait));
        try std.testing.expectEqual(Orientation.portrait, bestFitOrientation(200, 400, media, .{}, .landscape));
    }
    for (std.enums.values(Orientation)) |preferred| {
        const square = customPage(200, 200, .portrait).?;
        try std.testing.expectEqual(preferred, bestFitOrientation(400, 200, square, .{}, preferred));
        try std.testing.expectEqual(preferred, bestFitOrientation(200, 400, square, .{}, preferred));
        const almost_square = customPage(200, 200 + 1e-12, .portrait).?;
        try std.testing.expectEqual(preferred, bestFitOrientation(400, 200, almost_square, .{}, preferred));
    }
}

test "best fit compares usable FIT scale with asymmetric margins" {
    const media = paperPage(.a4, .portrait);
    try std.testing.expectEqual(Orientation.portrait, bestFitOrientation(400, 300, media, .{ .left = 5, .top = 70, .right = 15, .bottom = 80 }, .landscape));
    try std.testing.expectEqual(Orientation.landscape, bestFitOrientation(300, 400, media, .{ .left = 70, .top = 5, .right = 80, .bottom = 15 }, .portrait));
}

test "best fit selects the remaining usable orientation when margins exhaust only one" {
    const page = paperPage(.a4, .portrait);
    try std.testing.expectEqual(Orientation.landscape, bestFitOrientation(1600, 900, page, .{ .left = 110, .right = 110 }, .portrait));
    try std.testing.expectEqual(Orientation.portrait, bestFitOrientation(1600, 900, page, .{ .top = 110, .bottom = 110 }, .landscape));
}

test "best fit preserves preference for invalid dimensions and invalid or exhausted margins" {
    const media = paperPage(.a4, .portrait);
    for (std.enums.values(Orientation)) |preferred| {
        try std.testing.expectEqual(preferred, bestFitOrientation(0, 200, media, .{}, preferred));
        try std.testing.expectEqual(preferred, bestFitOrientation(200, 0, media, .{}, preferred));
        for ([_]f64{ 0, -1, 9, max_media_mm + 1, std.math.nan(f64), std.math.inf(f64) }) |value| {
            var invalid = media;
            invalid.width = value;
            try std.testing.expectEqual(preferred, bestFitOrientation(400, 200, invalid, .{}, preferred));
            invalid = media;
            invalid.height = value;
            try std.testing.expectEqual(preferred, bestFitOrientation(400, 200, invalid, .{}, preferred));
        }
        for ([_]f64{ -1, std.math.nan(f64), std.math.inf(f64), 287, 297, 1e308 }) |value| {
            for ([_]Margins{ .{ .left = value }, .{ .top = value }, .{ .right = value }, .{ .bottom = value } }) |margins| {
                try std.testing.expectEqual(preferred, bestFitOrientation(400, 200, media, margins, preferred));
            }
        }
    }
}

test "fit preserves aspect and centers within margins" {
    const p = place(paperPage(.a4, .portrait), .{ .width = 400, .height = 200 }, .{}) orelse return error.NoPlacement;
    try near(p.image.width, 190);
    try near(p.image.height, 95);
    try near(p.image.x, 10);
    try near(p.image.y, 101);
    try near(p.clip.height, 277);
}

test "fill covers content and crops centered overflow" {
    const p = place(paperPage(.a4, .portrait), .{ .width = 400, .height = 200 }, .{ .scale = .fill }) orelse return error.NoPlacement;
    try near(p.image.width, 554);
    try near(p.image.height, 277);
    try near(p.image.x, -172);
    try near(p.image.y, 10);
    try near(p.clip.x, 10);
    try near(p.clip.width, 190);
}

test "landscape fit and fill use the same oriented page" {
    const page = paperPage(.a5, .landscape);
    const fit = place(page, .{ .width = 100, .height = 200 }, .{}) orelse return error.NoPlacement;
    const fill = place(page, .{ .width = 100, .height = 200 }, .{ .scale = .fill }) orelse return error.NoPlacement;
    try near(fit.image.width, 64);
    try near(fit.image.height, 128);
    try near(fit.image.x, 73);
    try near(fill.image.width, 190);
    try near(fill.image.height, 380);
    try near(fill.image.y, -116);
}

test "100 percent is 96 DPI, with or without centering" {
    const page = paperPage(.letter, .portrait);
    const p = place(page, .{ .width = 960, .height = 480 }, .{ .scale = .actual_96dpi, .center = false }) orelse return error.NoPlacement;
    try near(p.image.width, 254);
    try near(p.image.height, 127);
    try near(p.image.x, 10);
    try near(p.image.y, 10);
    const centered = place(page, .{ .width = 960, .height = 480 }, .{ .scale = .actual_96dpi }) orelse return error.NoPlacement;
    try near(centered.image.x, (215.9 - 254) / 2.0);
}

test "asymmetric margins and top left placement" {
    const p = place(paperPage(.a4, .portrait), .{ .width = 100, .height = 100 }, .{
        .center = false, .margins = .{ .left = 20, .top = 30, .right = 40, .bottom = 50 },
    }) orelse return error.NoPlacement;
    try near(p.clip.width, 150);
    try near(p.clip.height, 217);
    try near(p.image.x, 20);
    try near(p.image.y, 30);
    try near(p.image.height, 150);
}

test "actual caps include physical offsets and non-square DPI" {
    const page = pageFromDevice(sample_caps) orelse return error.NoPage;
    try near(page.width, 210);
    try near(page.height, 297);
    try near(page.printable.x, 5);
    try near(page.printable.y, 7);
    try near(page.printable.width, 200);
    try near(page.printable.height, 280);
    const p = place(page, .{ .width = 100, .height = 100 }, .{ .margins = .{ .left = 0, .top = 0, .right = 0, .bottom = 0 } }) orelse return error.NoPlacement;
    try near(p.clip.x, 5);
    try near(p.clip.y, 7);
    const device_clip = printerTransform(sample_caps).rect(p.clip);
    try near(device_clip.x, 0);
    try near(device_clip.y, 0);
    try near(device_clip.width, 2000);
    try near(device_clip.height, 5600);
}

test "margins are intersected with hardware limits, never added to them" {
    const page = pageFromDevice(sample_caps) orelse return error.NoPage;
    const p = place(page, .{ .width = 100, .height = 200 }, .{
        .margins = .{ .left = 2, .top = 20, .right = 30, .bottom = 2 },
    }) orelse return error.NoPlacement;
    try near(p.clip.x, 5);
    try near(p.clip.y, 20);
    try near(p.clip.right(), 180);
    try near(p.clip.bottom(), 287);
}

test "invalid or exhausted margins and empty images produce no placement" {
    const page = paperPage(.a4, .portrait);
    for ([_]f64{ -1, 210, 1000, std.math.nan(f64), std.math.inf(f64) }) |left| {
        try std.testing.expect(place(page, .{ .width = 1, .height = 1 }, .{ .margins = .{ .left = left } }) == null);
    }
    try std.testing.expect(place(page, .{ .width = 0, .height = 1 }, .{}) == null);
    try std.testing.expect(place(page, .{ .width = 1, .height = 0 }, .{}) == null);
    try std.testing.expect(place(page, .{ .width = 1, .height = 1 }, .{ .margins = .{ .top = 287 } }) == null);
}

test "bad printer caps are rejected and overreported printable area is clamped" {
    var caps = sample_caps;
    caps.dpi_x = 0;
    try std.testing.expect(pageFromDevice(caps) == null);
    caps = sample_caps;
    caps.offset_x = 3000;
    try std.testing.expect(pageFromDevice(caps) == null);
    caps = sample_caps;
    caps.printable_width = 3000;
    const page = pageFromDevice(caps) orelse return error.NoPage;
    try near(page.printable.right(), page.width);
}

test "custom media bounds, orientation and metric versus inch photos" {
    const p = customPage(123.4, 234.5, .landscape) orelse return error.NoPage;
    try near(p.width, 234.5);
    try near(p.height, 123.4);
    try std.testing.expect(customPage(10, 3276.7, .portrait) != null);
    for ([_]f64{ 0, 9.9, 3276.8, std.math.nan(f64), std.math.inf(f64) }) |bad| {
        try std.testing.expect(customPage(bad, 100, .portrait) == null);
        try std.testing.expect(customPage(100, bad, .portrait) == null);
    }
    try near(paperPage(.photo_10x15, .portrait).width, 100);
    try near(paperPage(.inch_4x6, .portrait).width, 101.6);
    try near(paperPage(.photo_20x25, .portrait).height, 250);
    try near(paperPage(.inch_8x10, .portrait).height, 254);
}

test "own percent is relative to 96 DPI and physical dimensions lock aspect" {
    const page = paperPage(.a4, .portrait);
    const image = ImageSize{ .width = 960, .height = 480 };
    const percent = place(page, image, .{ .scale = .percent, .percent = 25 }) orelse return error.NoPlacement;
    try near(percent.image.width, 63.5);
    try near(percent.image.height, 31.75);
    const width = place(page, image, .{ .scale = .width_mm, .physical_mm = 123.4 }) orelse return error.NoPlacement;
    try near(width.image.width, 123.4);
    try near(width.image.height, 61.7);
    const height = place(page, image, .{ .scale = .height_mm, .physical_mm = 42 }) orelse return error.NoPlacement;
    try near(height.image.width, 84);
    try near(height.image.height, 42);
    for ([_]f64{ 0, -1, 1000.1, std.math.inf(f64), std.math.nan(f64) }) |bad| {
        try std.testing.expect(place(page, image, .{ .scale = .percent, .percent = bad }) == null);
    }
    for ([_]f64{ 0, -1, 10000.1, std.math.inf(f64), std.math.nan(f64) }) |bad| {
        try std.testing.expect(place(page, image, .{ .scale = .width_mm, .physical_mm = bad }) == null);
    }
}

test "absolute physical position overrides center, clips edges and rejects no intersection" {
    const page = pageFromDevice(sample_caps) orelse return error.NoPage;
    const image = ImageSize{ .width = 960, .height = 480 };
    const settings = Settings{ .scale = .width_mm, .physical_mm = 100, .position = .{ .x = -20, .y = 280 } };
    const p = place(page, image, settings) orelse return error.NoPlacement;
    try near(p.image.x, -20);
    try near(p.image.y, 280);
    try near(p.clip.x, 10);
    try near(p.clip.bottom(), 287);
    const visible = intersection(p.image, p.clip) orelse return error.NoIntersection;
    try near(visible.width, 70);
    try near(visible.height, 7);
    for ([_]Position{ .{ .x = 210, .y = 10 }, .{ .x = -100, .y = 10 }, .{ .x = 10, .y = 287 }, .{ .x = 10, .y = -50 }, .{ .x = std.math.nan(f64), .y = 0 } }) |bad| {
        var s = settings;
        s.position = bad;
        try std.testing.expect(place(page, image, s) == null);
    }
}

test "drag delta uses page transform and retains a recoverable grab area" {
    const page = pageFromDevice(sample_caps) orelse return error.NoPage;
    const image = ImageSize{ .width = 960, .height = 480 };
    var settings = Settings{ .scale = .width_mm, .physical_mm = 100 };
    const p = place(page, image, settings) orelse return error.NoPlacement;
    const preview = Transform{ .scale_x = 2.5, .scale_y = 2.5, .origin_x = 321, .origin_y = 17 };
    settings.position = dragPosition(p, preview.deltaMM(25, -50));
    const moved = place(page, image, settings) orelse return error.NoPlacement;
    try near(moved.image.x, p.image.x + 10);
    try near(moved.image.y, p.image.y - 20);
    const dc = printerTransform(sample_caps);
    const pi = preview.rect(moved.image);
    const di = dc.rect(moved.image);
    try near((pi.x - preview.origin_x) / preview.scale_x, (di.x + 50) / 10);
    try near((pi.y - preview.origin_y) / preview.scale_y, (di.y + 140) / 20);
    const pc = preview.rect(moved.clip);
    const dc_clip = dc.rect(moved.clip);
    try near((pc.x - preview.origin_x) / preview.scale_x, (dc_clip.x + 50) / 10);
    try near(pc.height / preview.scale_y, dc_clip.height / 20);
    for ([_]Position{ .{ .x = -100000, .y = -100000 }, .{ .x = 100000, .y = 100000 } }) |delta| {
        settings.position = dragPosition(p, delta);
        const clamped = place(page, image, settings) orelse return error.NoPlacement;
        const visible = intersection(clamped.image, clamped.clip) orelse return error.NoIntersection;
        try std.testing.expect(visible.width >= 4.999 and visible.height >= 4.999);
    }
}

test "preview and DC transformations preserve the same physical arrangement" {
    const page = pageFromDevice(sample_caps) orelse return error.NoPage;
    const p = place(page, .{ .width = 1200, .height = 800 }, .{ .scale = .fill }) orelse return error.NoPlacement;
    const preview = (Transform{ .scale_x = 2, .scale_y = 2, .origin_x = 30, .origin_y = 40 }).rect(p.image);
    const printed = printerTransform(sample_caps).rect(p.image);
    try near((preview.x - 30) / 2, (printed.x + 50) / 10);
    try near((preview.y - 40) / 2, (printed.y + 140) / 20);
    try near(preview.width / 2, printed.width / 10);
    try near(preview.height / 2, printed.height / 20);
}

test "stretch covers exactly the printable area, portrait, landscape and odd media" {
    const image = ImageSize{ .width = 1920, .height = 1080 };
    const stretch = Settings{ .scale = .stretch, .margins = .{ .left = 0, .top = 0, .right = 0, .bottom = 0 } };
    for ([_]Orientation{ .portrait, .landscape }) |orientation| {
        for ([_]Page{ paperPage(.a4, orientation), paperPage(.photo_10x15, orientation), paperPage(.legal, orientation), customPage(123.4, 456.7, orientation).?, pageFromDevice(sample_caps).? }) |page| {
            const p = place(page, image, stretch) orelse return error.NoPlacement;
            const printable = intersection(.{ .x = 0, .y = 0, .width = page.width, .height = page.height }, page.printable).?;
            try std.testing.expectEqual(printable, p.image);
            try std.testing.expectEqual(p.clip, p.image);
            // Position is ignored: there is nothing to move.
            var moved = stretch;
            moved.position = .{ .x = 50, .y = 50 };
            try std.testing.expectEqual(p.image, (place(page, image, moved) orelse return error.NoPlacement).image);
        }
    }
    // With margins it is the margin box (intersected with hardware limits).
    const m = place(paperPage(.a4, .landscape), image, .{ .scale = .stretch, .margins = .{ .left = 10, .top = 5, .right = 20, .bottom = 15 } }).?;
    try near(m.image.x, 10);
    try near(m.image.y, 5);
    try near(m.image.width, 297 - 30);
    try near(m.image.height, 210 - 20);
}
