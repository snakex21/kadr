//! Bounded, dependency-free raster decoders. No file IO, CRT or SIMD required.
//! Output is top-down, straight-alpha BGRA for GDI+ PixelFormat32bppARGB.
const std = @import("std");
const Allocator = std.mem.Allocator;
const Codec = @import("formats.zig").Codec;
pub const max_file_bytes = 128 * 1024 * 1024;
pub const max_pixels = 40_000_000;
pub const max_side = 32768;
pub const Error = error{ InvalidData, Unsupported, TooLarge, OutOfMemory };

pub const Raster = struct {
    allocator: Allocator,
    pixels: []u8,
    width: u32,
    height: u32,

    fn init(allocator: Allocator, width: u32, height: u32) Error!Raster {
        if (width == 0 or height == 0) return error.InvalidData;
        if (width > max_side or height > max_side or @as(u64, width) * height > max_pixels) return error.TooLarge;
        const pixels = try allocator.alloc(u8, @as(usize, width) * height * 4);
        @memset(pixels, 255);
        return .{ .allocator = allocator, .pixels = pixels, .width = width, .height = height };
    }
    pub fn deinit(self: *Raster) void {
        self.allocator.free(self.pixels);
        self.* = undefined;
    }
    fn put(self: *Raster, index: usize, bgra: [4]u8) void {
        @memcpy(self.pixels[index * 4 ..][0..4], &bgra);
    }
    fn sample(self: *Raster, index: usize, channel: usize, gray: bool, value: u8) void {
        const pixel = self.pixels[index * 4 ..][0..4];
        if (gray and channel == 0) {
            @memset(pixel[0..3], value);
        } else {
            pixel[if (gray or channel == 3) 3 else 2 - channel] = value;
        }
    }
};

const Reader = struct {
    data: []const u8,
    pos: usize = 0,
    fn take(self: *Reader, count: usize) Error![]const u8 {
        if (count > self.data.len - self.pos) return error.InvalidData;
        const result = self.data[self.pos..][0..count];
        self.pos += count;
        return result;
    }
    fn byte(self: *Reader) Error!u8 { return (try self.take(1))[0]; }
    fn le16(self: *Reader) Error!u16 { return std.mem.readIntLittle(u16, (try self.take(2))[0..2]); }
    fn be16(self: *Reader) Error!u16 { return std.mem.readIntBig(u16, (try self.take(2))[0..2]); }
    fn be32(self: *Reader) Error!u32 { return std.mem.readIntBig(u32, (try self.take(4))[0..4]); }
};

pub fn decode(allocator: Allocator, codec: Codec, data: []const u8) Error!Raster {
    if (data.len > max_file_bytes) return error.TooLarge;
    return switch (codec) {
        .qoi => qoi(allocator, data),
        .pnm => pnm(allocator, data),
        .tga => tga(allocator, data),
        .pcx => pcx(allocator, data),
        .psd => psd(allocator, data),
    };
}

fn qoi(allocator: Allocator, data: []const u8) Error!Raster {
    var r = Reader{ .data = data };
    if (!std.mem.eql(u8, try r.take(4), "qoif")) return error.InvalidData;
    const width = try r.be32();
    const height = try r.be32();
    const channels = try r.byte();
    if ((channels != 3 and channels != 4) or try r.byte() > 1) return error.InvalidData;
    var out = try Raster.init(allocator, width, height);
    errdefer out.deinit();
    var index = [_][4]u8{.{ 0, 0, 0, 0 }} ** 64;
    var pixel = [4]u8{ 0, 0, 0, 255 }; // RGBA, as used by the QOI hash.
    var i: usize = 0;
    const count = out.pixels.len / 4;
    while (i < count) {
        const tag = try r.byte();
        var run: usize = 1;
        if (tag == 0xfe) {
            @memcpy(pixel[0..3], try r.take(3));
        } else if (tag == 0xff) {
            @memcpy(&pixel, try r.take(4));
        } else switch (tag >> 6) {
            0 => pixel = index[tag & 63],
            1 => {
                pixel[0] +%= ((tag >> 4) & 3) -% 2;
                pixel[1] +%= ((tag >> 2) & 3) -% 2;
                pixel[2] +%= (tag & 3) -% 2;
            },
            2 => {
                const extra = try r.byte();
                const green = (tag & 63) -% 32;
                pixel[0] +%= green +% ((extra >> 4) -% 8);
                pixel[1] +%= green;
                pixel[2] +%= green +% ((extra & 15) -% 8);
            },
            3 => run = @as(usize, tag & 63) + 1,
            else => unreachable,
        }
        if (run > count - i) return error.InvalidData;
        const hash = (@as(u32, pixel[0]) * 3 + @as(u32, pixel[1]) * 5 + @as(u32, pixel[2]) * 7 + @as(u32, pixel[3]) * 11) % 64;
        index[hash] = pixel;
        for (0..run) |_| {
            out.put(i, .{ pixel[2], pixel[1], pixel[0], pixel[3] });
            i += 1;
        }
    }
    if (!std.mem.eql(u8, try r.take(8), "\x00\x00\x00\x00\x00\x00\x00\x01") or r.pos != data.len) return error.InvalidData;
    return out;
}

fn skipSpace(r: *Reader) void {
    while (r.pos < r.data.len) {
        const b = r.data[r.pos];
        if (std.ascii.isWhitespace(b)) {
            r.pos += 1;
        } else if (b == '#') {
            while (r.pos < r.data.len and r.data[r.pos] != '\n' and r.data[r.pos] != '\r') r.pos += 1;
        } else break;
    }
}
fn number(r: *Reader) Error!u32 {
    skipSpace(r);
    var value: u32 = 0;
    var digits: usize = 0;
    while (r.pos < r.data.len) {
        const b = r.data[r.pos];
        if (!std.ascii.isDigit(b)) {
            if (!std.ascii.isWhitespace(b) and b != '#') return error.InvalidData;
            break;
        }
        digits += 1;
        if (digits > 10) return error.InvalidData;
        value = std.math.mul(u32, value, 10) catch return error.InvalidData;
        value = std.math.add(u32, value, b - '0') catch return error.InvalidData;
        r.pos += 1;
    }
    if (digits == 0) return error.InvalidData;
    return value;
}
fn scale(value: u32, maximum: u32) Error!u8 {
    if (value > maximum) return error.InvalidData;
    return @intCast((value * 255 + maximum / 2) / maximum);
}
fn pnm(allocator: Allocator, data: []const u8) Error!Raster {
    var r = Reader{ .data = data };
    const magic = try r.take(2);
    if (magic[0] != 'P' or magic[1] < '1' or magic[1] > '6') return error.Unsupported;
    if (r.pos == data.len or !std.ascii.isWhitespace(data[r.pos])) return error.InvalidData;
    const kind = magic[1] - '0';
    const width = try number(&r);
    const height = try number(&r);
    const maximum = if (kind == 1 or kind == 4) 1 else try number(&r);
    if (maximum == 0 or maximum > 65535) return error.InvalidData;
    if (kind >= 4) {
        // Exactly the raster separator, NOT skipSpace: a pixel can be '#', LF,
        // or space. Accept the customary CRLF header separator as one unit.
        const separator = try r.byte();
        if (!std.ascii.isWhitespace(separator)) return error.InvalidData;
        if (separator == '\r' and r.pos < data.len and data[r.pos] == '\n') r.pos += 1;
    }
    var out = try Raster.init(allocator, width, height);
    errdefer out.deinit();
    if (kind == 4) {
        const row_bytes = (@as(usize, width) + 7) / 8;
        const bitmap = try r.take(row_bytes * height);
        for (0..height) |y| {
            for (0..width) |x| {
                const bit: u3 = @intCast(7 - (x & 7));
                const gray: u8 = if ((bitmap[y * row_bytes + x / 8] >> bit) & 1 == 0) 255 else 0;
                out.put(y * width + x, .{ gray, gray, gray, 255 });
            }
        }
    } else {
        const rgb = kind == 3 or kind == 6;
        for (0..out.pixels.len / 4) |i| {
            var color = [4]u8{ 0, 0, 0, 255 };
            const components: usize = if (rgb) 3 else 1;
            for (0..components) |c| {
                const value: u32 = if (kind < 4) try number(&r) else if (maximum > 255) try r.be16() else try r.byte();
                const sample = if (kind == 1) @as(u8, if (value == 0) 255 else if (value == 1) 0 else return error.InvalidData) else try scale(value, maximum);
                if (rgb) color[2 - c] = sample else @memset(color[0..3], sample);
            }
            out.put(i, color);
        }
    }
    // PNM can concatenate images; only the first image is presented, not pages.
    return out;
}

fn colorTga(r: *Reader, depth: u8, alpha_bits: u8) Error![4]u8 {
    if (depth == 15 or depth == 16) {
        const value = try r.le16();
        const b: u8 = @intCast(value & 31);
        const g: u8 = @intCast((value >> 5) & 31);
        const red: u8 = @intCast((value >> 10) & 31);
        return .{ (b << 3) | (b >> 2), (g << 3) | (g >> 2), (red << 3) | (red >> 2), if (depth == 16 and alpha_bits == 1 and value & 0x8000 == 0) 0 else 255 };
    }
    if (depth != 24 and depth != 32) return error.Unsupported;
    const bgr = try r.take(3);
    const alpha = if (depth == 32) try r.byte() else 255;
    return .{ bgr[0], bgr[1], bgr[2], if (alpha_bits == 8) alpha else 255 };
}
const TgaPixel = struct {
    kind: u8,
    depth: u8,
    alpha_bits: u8,
    palette: []const u8,
    first: u16,
    entries: u16,
    palette_depth: u8,
    fn read(self: TgaPixel, r: *Reader) Error![4]u8 {
        if (self.kind == 1) {
            const index: u32 = if (self.depth == 8) try r.byte() else try r.le16();
            if (index < self.first or index - self.first >= self.entries) return error.InvalidData;
            var entry = Reader{ .data = self.palette, .pos = (index - self.first) * ((@as(usize, self.palette_depth) + 7) / 8) };
            return colorTga(&entry, self.palette_depth, self.alpha_bits);
        }
        if (self.kind == 3) {
            const gray = try r.byte();
            const alpha = if (self.depth == 16) try r.byte() else 255;
            return .{ gray, gray, gray, if (self.alpha_bits == 8) alpha else 255 };
        }
        return colorTga(r, self.depth, self.alpha_bits);
    }
};
fn tga(allocator: Allocator, data: []const u8) Error!Raster {
    var r = Reader{ .data = data };
    const h = try r.take(18);
    const compressed = h[2] >= 9 and h[2] <= 11;
    const kind = if (compressed) h[2] - 8 else h[2];
    if (kind < 1 or kind > 3 or h[1] > 1 or h[17] & 0xc0 != 0) return error.Unsupported;
    const depth = h[16];
    const alpha_bits = h[17] & 15;
    if (kind == 1 and (h[1] != 1 or (depth != 8 and depth != 16))) return error.Unsupported;
    if (kind == 2 and depth != 15 and depth != 16 and depth != 24 and depth != 32) return error.Unsupported;
    if (kind == 3 and depth != 8 and depth != 16) return error.Unsupported;
    const color_depth = if (kind == 1) h[7] else depth;
    const valid_alpha = alpha_bits == 0 or (alpha_bits == 1 and color_depth == 16 and kind != 3) or (alpha_bits == 8 and (color_depth == 32 or (kind == 3 and depth == 16)));
    if (!valid_alpha) return error.Unsupported;
    _ = try r.take(h[0]);
    const entries = std.mem.readIntLittle(u16, h[5..7]);
    const first = std.mem.readIntLittle(u16, h[3..5]);
    var palette: []const u8 = &.{};
    if (h[1] == 1) {
        if (entries == 0 or @as(u32, first) + entries > 65536) return error.InvalidData;
        if (h[7] != 15 and h[7] != 16 and h[7] != 24 and h[7] != 32) return error.Unsupported;
        palette = try r.take(@as(usize, entries) * ((@as(usize, h[7]) + 7) / 8));
    }
    const pixel_reader = TgaPixel{ .kind = kind, .depth = depth, .alpha_bits = alpha_bits, .palette = palette, .first = first, .entries = entries, .palette_depth = h[7] };
    var out = try Raster.init(allocator, std.mem.readIntLittle(u16, h[12..14]), std.mem.readIntLittle(u16, h[14..16]));
    errdefer out.deinit();
    var i: usize = 0;
    const count = out.pixels.len / 4;
    while (i < count) {
        const tag: u8 = if (compressed) try r.byte() else 0;
        const run: usize = @as(usize, tag & 127) + 1;
        if (run > count - i) return error.InvalidData;
        const repeated = if (tag & 128 != 0) try pixel_reader.read(&r) else [4]u8{ 0, 0, 0, 0 };
        for (0..run) |_| {
            const pixel = if (tag & 128 != 0) repeated else try pixel_reader.read(&r);
            const row = i / out.width;
            const column = i % out.width;
            const y = if (h[17] & 0x20 != 0) row else out.height - 1 - row;
            const x = if (h[17] & 0x10 == 0) column else out.width - 1 - column;
            out.put(y * out.width + x, pixel);
            i += 1;
        }
    }
    return out; // TGA 2.0 footer/extension metadata is intentionally ignored.
}

fn pcx(allocator: Allocator, data: []const u8) Error!Raster {
    var r = Reader{ .data = data };
    const h = try r.take(128);
    if (h[0] != 10 or h[1] > 5 or h[2] > 1) return error.Unsupported;
    const bits = h[3];
    const planes = h[65];
    if (!((bits == 8 and (planes == 1 or planes == 3)) or ((bits == 1 or bits == 2 or bits == 4) and planes > 0 and @as(u16, planes) * bits <= 4))) return error.Unsupported;
    const xmin = std.mem.readIntLittle(u16, h[4..6]);
    const ymin = std.mem.readIntLittle(u16, h[6..8]);
    const xmax = std.mem.readIntLittle(u16, h[8..10]);
    const ymax = std.mem.readIntLittle(u16, h[10..12]);
    if (xmax < xmin or ymax < ymin) return error.InvalidData;
    const width = @as(u32, xmax) - xmin + 1;
    const height = @as(u32, ymax) - ymin + 1;
    const row_bytes: usize = std.mem.readIntLittle(u16, h[66..68]);
    if (row_bytes < (@as(usize, width) * bits + 7) / 8) return error.InvalidData;
    var palette: []const u8 = h[16..64];
    var grayscale = false;
    if (bits == 8 and planes == 1) {
        if (data.len >= 128 + 769 and data[data.len - 769] == 12) {
            palette = data[data.len - 768 ..];
            r.data = data[0 .. data.len - 769];
        } else if (std.mem.readIntLittle(u16, h[68..70]) == 2) {
            grayscale = true;
        } else return error.InvalidData;
    }
    var out = try Raster.init(allocator, width, height);
    errdefer out.deinit();
    const row = try allocator.alloc(u8, row_bytes * planes);
    defer allocator.free(row);
    for (0..height) |y| {
        var pos: usize = 0;
        while (pos < row.len) {
            const tag = try r.byte();
            const run: usize = if (h[2] == 1 and tag & 0xc0 == 0xc0) tag & 63 else 1;
            if (run == 0 or run > row.len - pos) return error.InvalidData;
            const value = if (h[2] == 1 and tag & 0xc0 == 0xc0) try r.byte() else tag;
            @memset(row[pos..][0..run], value);
            pos += run;
        }
        for (0..width) |x| {
            var color = [4]u8{ 0, 0, 0, 255 };
            if (bits == 8 and planes == 3) {
                color = .{ row[2 * row_bytes + x], row[row_bytes + x], row[x], 255 };
            } else {
                var index: u8 = 0;
                if (bits == 8) {
                    index = row[x];
                } else {
                    for (0..planes) |plane| {
                        const shift: u3 = @intCast(8 - bits - ((x * bits) & 7));
                        const mask: u8 = (@as(u8, 1) << @as(u3, @intCast(bits))) - 1;
                        index |= ((row[plane * row_bytes + (x * bits) / 8] >> shift) & mask) << @as(u3, @intCast(plane * bits));
                    }
                }
                if (grayscale) {
                    @memset(color[0..3], index);
                } else {
                    const offset = @as(usize, index) * 3;
                    color = .{ palette[offset + 2], palette[offset + 1], palette[offset], 255 };
                }
            }
            out.put(y * width + x, color);
        }
    }
    return out;
}

fn psd(allocator: Allocator, data: []const u8) Error!Raster {
    var r = Reader{ .data = data };
    if (!std.mem.eql(u8, try r.take(4), "8BPS") or try r.be16() != 1) return error.Unsupported;
    for (try r.take(6)) |b| { if (b != 0) return error.InvalidData; }
    const channels = try r.be16();
    const height = try r.be32();
    const width = try r.be32();
    if (try r.be16() != 8) return error.Unsupported;
    const mode = try r.be16();
    const gray = mode == 1;
    if (!((gray and (channels == 1 or channels == 2)) or (mode == 3 and (channels == 3 or channels == 4)))) return error.Unsupported;
    // Color-mode data, image resources and layer/mask data are bounded slices.
    // Only the merged composite is decoded; layers/profiles are not interpreted.
    for (0..3) |_| { _ = try r.take(try r.be32()); }
    const compression = try r.be16();
    if (compression > 1) return error.Unsupported;
    var out = try Raster.init(allocator, width, height);
    errdefer out.deinit();
    if (compression == 0) {
        for (0..channels) |channel| {
            const plane = try r.take(@as(usize, width) * height);
            for (plane, 0..) |value, i| out.sample(i, channel, gray, value);
        }
    } else {
        const sizes = try r.take(@as(usize, channels) * height * 2);
        for (0..channels) |channel| {
            for (0..height) |y| {
                const table = (channel * height + y) * 2;
                var row = Reader{ .data = try r.take(std.mem.readIntBig(u16, sizes[table..][0..2])) };
                var x: usize = 0;
                while (row.pos < row.data.len) {
                    const tag = try row.byte();
                    if (tag == 128) continue; // PackBits no-op.
                    const count: usize = if (tag < 128) @as(usize, tag) + 1 else 257 - @as(usize, tag);
                    if (count > width - x) return error.InvalidData;
                    if (tag < 128) {
                        for (try row.take(count)) |value| {
                            out.sample(y * width + x, channel, gray, value);
                            x += 1;
                        }
                    } else {
                        const value = try row.byte();
                        for (0..count) |_| {
                            out.sample(y * width + x, channel, gray, value);
                            x += 1;
                        }
                    }
                }
                if (x != width) return error.InvalidData;
            }
        }
    }
    return out;
}
