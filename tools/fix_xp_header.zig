//! Build-time PE header correction: Zig 0.11/lld defaults to 6.0 even for .xp.
//! Only changes loader declarations. Import compatibility is audited separately.
const std = @import("std");
pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);
    var file = try std.fs.cwd().openFile(if (args.len > 1) args[1] else "Kadr.exe", .{ .mode = .read_write });
    defer file.close();
    var dos: [64]u8 = undefined;
    if (try file.preadAll(&dos, 0) != dos.len or !std.mem.eql(u8, dos[0..2], "MZ")) return error.InvalidPE;
    const offset = std.mem.readIntLittle(u32, dos[60..64]);
    var nt: [26]u8 = undefined;
    if (try file.preadAll(&nt, offset) != nt.len or !std.mem.eql(u8, nt[0..4], "PE\x00\x00")) return error.InvalidPE;
    if (std.mem.readIntLittle(u16, nt[4..6]) != 0x14c or std.mem.readIntLittle(u16, nt[24..26]) != 0x10b) return error.NotX86PE32;
    const xp = [_]u8{ 5, 0, 1, 0 };
    try file.pwriteAll(&xp, offset + 24 + 40); // Major/MinorOperatingSystemVersion
    try file.pwriteAll(&xp, offset + 24 + 48); // Major/MinorSubsystemVersion
    try file.pwriteAll(&.{ 0, 0, 0, 0 }, offset + 24 + 64); // No stale checksum
    std.debug.print("PE: x86, OS 5.1, subsystem 5.1 (XP); imports require a separate audit.\n", .{});
}
