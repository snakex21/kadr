//! One extension registry for file dialogs, folder navigation and native codecs.
//! This is an extension filter, not a promise that every variant will decode.
const std = @import("std");

pub const Codec = enum { tga, pcx, psd, pnm, qoi };
const native = .{
    .{ ".tga", Codec.tga }, .{ ".targa", Codec.tga },
    .{ ".pcx", Codec.pcx }, .{ ".psd", Codec.psd },
    .{ ".pbm", Codec.pnm }, .{ ".pgm", Codec.pnm },
    .{ ".ppm", Codec.pnm }, .{ ".pnm", Codec.pnm },
    .{ ".qoi", Codec.qoi },
};
const system = .{ ".png", ".jpg", ".jpeg", ".jpe", ".jfif", ".jif", ".bmp", ".dib", ".gif", ".tif", ".tiff", ".ico", ".wmf", ".emf", ".djvu", ".djv" };

pub fn hasExtension(path: []const u16, extension: []const u8) bool {
    if (path.len < extension.len) return false;
    for (path[path.len - extension.len ..], extension) |wide, ascii| {
        if (wide > 127 or std.ascii.toLower(@as(u8, @intCast(wide))) != ascii) return false;
    }
    return true;
}

pub fn codec(path: []const u16) ?Codec {
    inline for (native) |entry| {
        if (hasExtension(path, entry[0])) return entry[1];
    }
    return null;
}

pub fn supported(path: []const u16) bool {
    if (codec(path) != null) return true;
    inline for (system) |extension| {
        if (hasExtension(path, extension)) return true;
    }
    return false;
}

// OPENFILENAMEW: label NUL patterns NUL label NUL patterns NUL NUL.
// Keep the all-files option: GDI+ also sniffs ordinary images with other names.
pub const filter: [*:0]const u16 = blk: {
    @setEvalBranchQuota(30000);
    break :blk std.unicode.utf8ToUtf16LeStringLiteral(
        "Wszystkie obsługiwane obrazy\x00" ++
        "*.png;*.jpg;*.jpeg;*.jpe;*.jfif;*.jif;*.bmp;*.dib;*.gif;*.tif;*.tiff;*.djvu;*.djv;*.ico;*.wmf;*.emf;*.tga;*.targa;*.pcx;*.psd;*.pbm;*.pgm;*.ppm;*.pnm;*.qoi\x00" ++
        "JPEG / JFIF (*.jpg;*.jpeg;*.jpe;*.jfif;*.jif)\x00*.jpg;*.jpeg;*.jpe;*.jfif;*.jif\x00" ++
        "PNG (*.png)\x00*.png\x00" ++
        "Bitmapy BMP / DIB (*.bmp;*.dib)\x00*.bmp;*.dib\x00" ++
        "GIF (*.gif)\x00*.gif\x00" ++
        "TIFF (*.tif;*.tiff)\x00*.tif;*.tiff\x00" ++
        "DjVu (*.djvu;*.djv)\x00*.djvu;*.djv\x00" ++
        "Ikony ICO (*.ico)\x00*.ico\x00" ++
        "Metapliki WMF / EMF (*.wmf;*.emf)\x00*.wmf;*.emf\x00" ++
        "Targa (*.tga;*.targa)\x00*.tga;*.targa\x00" ++
        "PCX (*.pcx)\x00*.pcx\x00" ++
        "PSD - scalony obraz (*.psd)\x00*.psd\x00" ++
        "PNM / PBM / PGM / PPM (*.pnm;*.pbm;*.pgm;*.ppm)\x00*.pnm;*.pbm;*.pgm;*.ppm\x00" ++
        "QOI (*.qoi)\x00*.qoi\x00" ++
        "Wszystkie pliki\x00*.*\x00",
    );
};
pub fn localizedFilter() [*:0]const u16 {
    return @import("i18n.zig").L("Filtr obrazów").ptr;
}
pub const summary = "PNG, JPEG/JFIF, BMP, GIF, TIFF, DjVu, ICO, WMF/EMF, TGA, PCX, PSD, PBM/PGM/PPM/PNM, QOI";
