"""Deterministic, tiny codec fixtures. Python/Pillow is build-time test tooling only.
Handwritten streams exercise each supported subset; Pillow supplies independent
TGA/PCX encoders. Never touches Kadr.exe or the retained image-check harness.
"""
from pathlib import Path
import struct
from io import BytesIO
from PIL import Image

HERE = Path(__file__).resolve().parent
FIX = HERE / 'fixtures'
FIX.mkdir(exist_ok=True)
cases, bad = [], []
W, H = 3, 2
RGBA = [(255, 0, 0, 255), (0, 255, 0, 128), (0, 0, 255, 0),
        (12, 34, 56, 255), (12, 34, 56, 255), (240, 230, 220, 64)]
RGB = [(*p[:3], 255) for p in RGBA]
GRAY = [0, 40, 128, 255, 200, 73]
ALPHA = [255, 128, 0, 254, 64, 255]


def add(name, kind, data, pixels, w=W, h=H, strict=False):
    (FIX / name).write_bytes(data)
    cases.append((name, kind, pixels, w, h, strict))
    return data


def reject(name, data):
    (FIX / name).write_bytes(data)
    bad.append(name)


def argb(p):
    r, g, b, a = p
    return (a << 24) | (r << 16) | (g << 8) | b


def tga_header(kind, depth, desc, first=0, entries=0, palette_depth=0):
    return struct.pack('<BBBHHBHHHHBB', 0, bool(entries), kind, first, entries,
                       palette_depth, 0, 0, W, H, depth, desc)


# Independent encoder fixtures: bottom-left origin, raw and RLE RGBA.
im = Image.new('RGBA', (W, H))
im.putdata(RGBA)
for name, compression in [('pillow-raw.tga', None), ('pillow-rle.tga', 'tga_rle')]:
    im.save(FIX / name, compression=compression)
    add(name, 'tga', (FIX / name).read_bytes(), RGBA)
raw_tga = add('right-origin.tga', 'tga', tga_header(2, 24, 0x30) +
              bytes(c for y in range(H) for p in RGB[y*W:(y+1)*W][::-1]
                    for c in p[2::-1]), RGB, strict=True)
gray_alpha = [(v, v, v, a) for v, a in zip(GRAY, ALPHA)]
add('gray-alpha.tga', 'tga', tga_header(11, 16, 0x28) + bytes([5]) +
    bytes(c for v, a in zip(GRAY, ALPHA) for c in (v, a)), gray_alpha)
add('palette-alpha.tga', 'tga', tga_header(1, 8, 0x28, 5, 6, 32) +
    bytes(c for p in RGBA for c in (p[2], p[1], p[0], p[3])) + bytes(range(5, 11)), RGBA)
add('palette16.tga', 'tga', tga_header(9, 16, 0x20, 300, 6, 24) +
    bytes(c for p in RGB for c in p[2::-1]) + bytes([5]) +
    struct.pack('<6H', *range(300, 306)), RGB)
words = [(p[0] >> 3) << 10 | (p[1] >> 3) << 5 | (p[2] >> 3) |
         (0x8000 if p[3] >= 128 else 0) for p in RGBA]
quantized = [tuple(((v >> s) & 31) * 8 + ((v >> s) & 31) // 4
                   for s in (10, 5, 0)) + (255 if v & 0x8000 else 0,) for v in words]
add('rgb555-alpha.tga', 'tga', tga_header(2, 16, 0x21) + struct.pack('<6H', *words), quantized)
# RLE repeat packet as well as raw packets; attribute-zero 32-bit is opaque.
repeat_rgb = [(12, 34, 56, 255)] * 6
add('run-opaque.tga', 'tga', tga_header(10, 32, 0x20) + bytes([0x85, 56, 34, 12, 0]), repeat_rgb)
add('gray8.tga', 'tga', tga_header(3, 8, 0x20) + bytes(GRAY), [(v, v, v, 255) for v in GRAY])
reject('truncated.tga', raw_tga[:-1])
reject('packet-overrun.tga', tga_header(10, 24, 0x20) + bytes([0xff, 1, 2, 3]))
reject('palette-index.tga', tga_header(1, 8, 0x20, 1, 1, 24) + bytes([1, 2, 3, 0]))
big = bytearray(raw_tga)
struct.pack_into('<H', big, 12, 65535)
reject('oversize.tga', big)

# PCX, independent Pillow encoders plus packed/planar low-bit fixtures.
im.convert('RGB').save(FIX / 'pillow-rgb.pcx')
rgb_pcx = add('pillow-rgb.pcx', 'pcx', (FIX / 'pillow-rgb.pcx').read_bytes(), RGB, strict=True)
palette = bytes(c for p in RGB for c in p[:3]) + bytes(768 - 18)
indexed = Image.new('P', (W, H))
indexed.putpalette(palette)
indexed.putdata(range(6))
indexed.save(FIX / 'pillow-indexed.pcx')
add('pillow-indexed.pcx', 'pcx', (FIX / 'pillow-indexed.pcx').read_bytes(), RGB)


def pcx_header(bits, planes, row_bytes, gray=False):
    h = bytearray(128)
    h[:4] = bytes([10, 5, 1, bits])
    struct.pack_into('<4H', h, 4, 0, 0, W-1, H-1)
    h[16:64] = palette[:48]
    h[65] = planes
    struct.pack_into('<HH', h, 66, row_bytes, 2 if gray else 1)
    return h


def pcx_pack(data):
    out = bytearray()
    i = 0
    while i < len(data):
        run = 1
        while run < 63 and i + run < len(data) and data[i+run] == data[i]:
            run += 1
        if run > 1 or data[i] >= 192:
            out.extend((192 | run, data[i]))
        else:
            out.append(data[i])
        i += run
    return out


for bits, planes in [(1, 4), (2, 2), (4, 1)]:
    body = bytearray()
    row_bytes = 2
    for y in range(H):
        row = bytearray(row_bytes * planes)
        for plane in range(planes):
            for x in range(W):
                value = ((y * W + x) >> (plane * bits)) & ((1 << bits) - 1)
                row[plane * row_bytes + x*bits//8] |= value << (8-bits-(x*bits % 8))
        body.extend(pcx_pack(row))
    add(f'packed-{bits}x{planes}.pcx', 'pcx', pcx_header(bits, planes, row_bytes) + body, RGB)
add('gray.pcx', 'pcx', pcx_header(8, 1, 4, gray=True) +
    b''.join(pcx_pack(bytes(GRAY[y*W:(y+1)*W]) + b'\x00') for y in range(H)),
    [(v, v, v, 255) for v in GRAY])
reject('truncated.pcx', rgb_pcx[:-1])
reject('run-overrun.pcx', pcx_header(8, 3, 4) + bytes([0xff, 0]))
reject('run-zero.pcx', pcx_header(8, 3, 4) + bytes([0xc0, 0]))
big = bytearray(rgb_pcx)
struct.pack_into('<H', big, 8, 65535)
reject('oversize.pcx', big)

# PSD v1 8-bit merged composites, raw and PackBits RGB/gray with/without alpha.
def packbits(row):
    out = bytearray([128])  # also exercises the legal no-op opcode
    pos = 0
    while pos < len(row):
        run = 1
        while pos + run < len(row) and row[pos+run] == row[pos] and run < 128:
            run += 1
        if run > 1:
            out.extend((257-run, row[pos]))
            pos += run
        else:
            out.extend((0, row[pos]))
            pos += 1
    return out


def psd(channels, gray, compression):
    h = b'8BPS' + struct.pack('>H6xHIIHH', 1, len(channels), H, W, 8, 1 if gray else 3)
    h += bytes(12) + struct.pack('>H', compression)
    if compression == 0:
        return h + bytes(v for plane in channels for v in plane)
    rows = [packbits(plane[y*W:(y+1)*W]) for plane in channels for y in range(H)]
    return h + struct.pack('>' + 'H' * len(rows), *map(len, rows)) + b''.join(rows)


raw_psd = None
for compression in (0, 1):
    rgb_channels = [[p[c] for p in RGBA] for c in range(3)]
    for alpha in (False, True):
        suffix = 'rgba' if alpha else 'rgb'
        data = psd(rgb_channels + ([ALPHA] if alpha else []), False, compression)
        expected = [(*p[:3], ALPHA[i] if alpha else 255) for i, p in enumerate(RGBA)]
        add(f'{suffix}-{compression}.psd', 'psd', data, expected, strict=(compression == 1 and alpha))
        if compression == 1 and alpha:
            raw_psd = data
        data = psd([GRAY] + ([ALPHA] if alpha else []), True, compression)
        add(f'gray{"a" if alpha else ""}-{compression}.psd', 'psd', data,
            [(v, v, v, ALPHA[i] if alpha else 255) for i, v in enumerate(GRAY)])
reject('truncated.psd', raw_psd[:-1])
big = bytearray(raw_psd)
struct.pack_into('>I', big, 18, 70000)
reject('oversize.psd', big)
broken = bytearray(raw_psd)
struct.pack_into('>I', broken, 26, 0xffffffff)
reject('section-length.psd', broken)
broken = bytearray(raw_psd)
broken[40 + 4 * H * 2] = 3  # first PackBits row claims four literals for width 3
reject('row-overrun.psd', broken)
broken = bytearray(raw_psd)
struct.pack_into('>H', broken, 22, 16)
reject('unsupported-depth.psd', broken)
broken = bytearray(raw_psd)
struct.pack_into('>H', broken, 38, 2)
reject('unsupported-zip.psd', broken)

# P1..P6, comments, non-255 MAXVAL, 16-bit big endian, raster whitespace/#.
bw = [0, 1, 0, 1, 1, 0]
add('ascii.pbm', 'pnm', b'P1\n# comment\n3 2\n0 1 # middle\n0 1 1 0\n',
    [(255*(1-v),)*3 + (255,) for v in bw])
values = [0, 1, 500, 1000, 900, 333]
scaled = [(v*255 + 500)//1000 for v in values]
add('ascii.pgm', 'pnm', b'P2\n3 2\n1000\n' + ' '.join(map(str, values)).encode(),
    [(v, v, v, 255) for v in scaled])
add('ascii.ppm', 'pnm', b'P3\n3 2\n65535\n' +
    ' '.join(str(v*257) for p in RGB for v in p[:3]).encode(), RGB)
add('binary.pbm', 'pnm', b'P4\n3 2\n\x40\xc0',
    [(255*(1-v),)*3 + (255,) for v in bw])
whitespace = [35, 10, 32, 0, 255, 128]
add('binary.pgm', 'pnm', b'P5\r\n3 2\r\n255\r\n' + bytes(whitespace),
    [(v, v, v, 255) for v in whitespace])
add('binary16.pgm', 'pnm', b'P5\n3 2\n1000\n' + struct.pack('>6H', *values),
    [(v, v, v, 255) for v in scaled])
binary_pnm = add('binary.ppm', 'pnm', b'P6\n# header comment\n3 2\n255\n' +
                 bytes(v for p in RGB for v in p[:3]), RGB, strict=True)
add('binary16.pnm', 'pnm', b'P6\n3 2\n65535\n' +
    struct.pack('>18H', *(v*257 for p in RGB for v in p[:3])), RGB)
reject('truncated.ppm', binary_pnm[:-1])
reject('oversize.ppm', b'P6\n4294967295 2\n255\n')
reject('integer-overflow.pgm', b'P2\n4294967296 1\n255\n0')
reject('sample-range.pgm', b'P2\n1 1\n255\n256')
reject('sample16-range.pgm', b'P5\n1 1\n1000\n\xff\xff')
reject('maxval-zero.pgm', b'P2\n1 1\n0\n0')
reject('maxval-range.pgm', b'P2\n1 1\n65536\n0')
reject('no-separator.pgm', b'P5\n1 1\n255#\x00')

# Every QOI opcode, modulo-256 diff, alpha, index, maximum run and end marker.
end = bytes(7) + b'\x01'
qoi_pixels = [(0, 0, 0, 0), (255, 0, 0, 255), (0, 1, 1, 255), (18, 21, 23, 255),
              (12, 34, 56, 128), (12, 34, 56, 128), (12, 34, 56, 128), (255, 0, 0, 255), (1, 2, 3, 255)]
qoi = add('opcodes.qoi', 'qoi', b'qoif' + struct.pack('>IIBB', 9, 1, 4, 0) +
          b'\x00\xff\xff\x00\x00\xff\x7f\xb4\x6a\xff\x0c\x22\x38\x80\xc1\x32\xfe\x01\x02\x03' + end,
          qoi_pixels, 9, 1, strict=True)
add('zażółć-漢字.QOI', 'qoi', qoi, qoi_pixels, 9, 1)
add('long-run.qoi', 'qoi', b'qoif' + struct.pack('>IIBB', 63, 1, 3, 1) + b'\xfd\xfe\x01\x02\x03' + end,
    [(0, 0, 0, 255)] * 62 + [(1, 2, 3, 255)], 63, 1)
reject('truncated.qoi', qoi[:-1])
reject('oversize.qoi', b'qoif' + struct.pack('>IIBB', 0xffffffff, 1, 4, 0) + end)
reject('run-overrun.qoi', b'qoif' + struct.pack('>IIBB', 1, 1, 4, 0) + b'\xc1' + end)
broken = bytearray(qoi)
broken[13] = 2
reject('colorspace.qoi', broken)
broken = bytearray(qoi)
broken[-1] = 0
reject('end-marker.qoi', broken)

# EXIF orientations: identical JPEG entropy data with little/big endian APP1.
buffer = BytesIO()
im.convert('RGB').save(buffer, format='JPEG', quality=100, subsampling=0)
jpeg_base = buffer.getvalue()
(FIX / 'exif-base.jpg').write_bytes(jpeg_base)
for orientation in range(1, 10):
    endian = '<' if orientation % 2 else '>'
    tiff = (b'II' if endian == '<' else b'MM') + struct.pack(endian + 'HI', 42, 8)
    tiff += struct.pack(endian + 'HHHIH2xI', 1, 0x0112, 3, 1, orientation, 0)
    exif = b'Exif\x00\x00' + tiff
    data = jpeg_base[:2] + b'\xff\xe1' + struct.pack('>H', len(exif) + 2) + exif + jpeg_base[2:]
    (FIX / f'exif-{orientation}.jpg').write_bytes(data)
    if orientation == 6:
        (FIX / 'exif-alias.JFIF').write_bytes(data)

# Alias fixtures exercise system GDI+ without relying on extension sniffing in UI.
photo = Image.new('RGB', (W, H), (220, 30, 20))
photo.save(FIX / 'alias.jfif', format='JPEG', quality=100, subsampling=0)
(FIX / 'alias.jif').write_bytes((FIX / 'alias.jfif').read_bytes())
(FIX / 'alias.jpe').write_bytes((FIX / 'alias.jfif').read_bytes())
photo.save(FIX / 'alias.dib', format='BMP')

lines = ['// Generated by prepare.py; test data, not application code.',
         'const w = @import("../../src/win.zig");', 'const formats = @import("../../src/formats.zig");',
         'pub const Case = struct { path: [*:0]const u16, codec: formats.Codec, width: u32, height: u32, pixels: []const u32, strict: bool };',
         'pub const good = [_]Case{']
for name, kind, pixels, w, h, strict in cases:
    path = 'tests/codec-check/fixtures/' + name
    colors = ', '.join(f'0x{argb(p):08x}' for p in pixels)
    lines.append(f'    .{{ .path = w.L("{path}"), .codec = .{kind}, .width = {w}, .height = {h}, .pixels = &.{{ {colors} }}, .strict = {str(strict).lower()} }},')
lines.extend(['};', 'pub const bad = [_][*:0]const u16{'])
for name in bad:
    lines.append(f'    w.L("tests/codec-check/fixtures/{name}"),')
lines.append('};\n')
(HERE / 'cases.zig').write_text('\n'.join(lines), encoding='utf-8')
print(f'Prepared {len(cases)} positive native fixtures, {len(bad)} negative fixtures, 4 GDI aliases')
