# Retained native codec checks (Zig 0.11 / Windows)

Run from the repo root:

```bat
tests\codec-check\check.cmd
```

The script never builds, overwrites, patches or launches `Kadr.exe`. It generates
small fixtures (Python + Pillow, development only), compiles the **current**
`src/image.zig`/`src/codecs.zig`/`src/formats.zig`, and compiles the unchanged
`tests/image-check/harness.zig` into **new** binaries in this directory. The
legacy harness and its original binaries are retained, not replaced. DjVu DLLs
are copied from the existing `deps/djvu` solely for the legacy harness.

Both harnesses run as x86/Pentium III in ReleaseSmall and ReleaseSafe. Test
executables and all their generated artifacts stay here. `audit_pe.py` applies
the existing Zig 0.11 XP header workaround **only to these four executables**,
then checks x86 PE32, no CRT, and ReleaseSmall DLL/API imports. Exact imports and
binary SHA-256s are retained in `imports.json`. ReleaseSafe is a host-Windows
memory/safety check, not an XP import-compatibility claim. Actual XP SP3/Pentium
III execution is not available here and remains required.

## Implemented and fixture-tested subsets

- **TGA / TARGA:** raw and RLE, 8/16-bit palette indices with 15/16/24/32-bit
  palette entries, 15/16/24/32-bit truecolor, 8-bit gray and 16-bit gray+alpha.
  All four origins work; attribute-zero alpha is treated as opaque. No
  interleaving; TGA 2.0 metadata/color-correction is ignored.
- **PCX:** raw/RLE, 8-bit indexed (256-color tail palette), 24-bit three-plane
  RGB, 1/2/4-bit packed/planar indexed up to 16 colors (header palette), and
  linear 8-bit gray with palette-info 2 when no tail palette exists. No DCX,
  CMYK or four-plane 32-bit mode. Runs cannot cross a scanline.
- **PSD:** version 1 merged composite, 8-bit RGB/RGBA or gray/gray+alpha, raw or
  PackBits. At most one extra channel, used as alpha. No PSB, 16/32-bit, ZIP,
  CMYK/Lab/indexed, layer rendering, ICC management or embedded previews.
- **PNM / PBM / PGM / PPM:** P1-P6, ASCII/binary, comments in headers/ASCII data,
  packed PBM rows, MAXVAL 1..65535 with correctly scaled big-endian 16-bit
  samples. First image only; concatenated images are not exposed as pages.
  Binary separator accepts one whitespace or CRLF and never swallows raster
  whitespace or `#` as a comment.
- **QOI:** all opcodes, RGB/RGBA, both colorspace values, alpha, wrapping deltas,
  index/run packets, checked end marker. Colorspace is not color-managed.
- **Existing GDI+ aliases:** JFIF/JIF/JPE, BMP file content named DIB; actually
  loaded in the harness. Existing PNG/JPEG/BMP/GIF/TIFF/ICO/DjVu behavior is
  covered by the original 76-check harness. Existing WMF/EMF remain GDI+ paths.
- **JPEG/JFIF EXIF orientation:** all eight mappings, both EXIF byte orders,
  invalid value ignored, uppercase JFIF alias. Display-only, no file writes.

WebP is **not implemented**: the required `web_download` tool was unavailable,
so current upstream libwebp sources could not be downloaded/verified. No WebP,
HEIC, AVIF, RAW or PDF support is advertised. See `deps/codecs/README.md`.

## Bounds and ownership

New decoders accept at most 128 MiB encoded input, 32768 pixels on either side,
and 40,000,000 total pixels (160 MB BGRA). PCX additionally needs at most
4 * 65535 row bytes. Input/output allocations have independent limits and all
size arithmetic is checked/bounded before use; no CPU SIMD assumptions or CRT.
`CreateFileW` retains Unicode support, only XP-era file APIs are used, and the
GDI+ Scan0 buffer stays alive until the image is disposed, including rotations.
Existing GDI+/DjVu paths retain their previous separate bounds/behavior.

34 positive fixtures, 27 malformed/unsupported/oversized fixtures, JPEG aliases
and EXIF samples are retained in `fixtures/`. Checks include exact native BGRA
and GDI+ ARGB pixels/alpha, origin/rotation, public Image defaults/navigation,
out-of-memory and partial PCX allocation cleanup, every truncated prefix of
five canonical streams, invalid dimensions/packets/section lengths, Unicode
paths, grouped dialog filters, the 128 MiB file boundary, repeat loads and
steady-state process handles. A tracking allocator verifies no direct decoder
allocation leaks. The decoder is bounded, not a security sandbox; color profile
management and metadata preservation are outside this display-only subset.

## Main integration (no UI edits made by codec worker)

```zig
const formats = @import("formats.zig");
// dialog.lpstrFilter = formats.filter;
// folder navigation: formats.supported(path_slice)
```

`filter` is `[*:0]const u16`, has double-NUL termination and grouped choices
starting with **Wszystkie obsługiwane obrazy**. `summary` is UTF-8 help text.
No additional build flags or DLLs are needed. Keep the application's existing
`-target x86-windows.xp-gnu -mcpu=pentium3`, no-CRT flags, GDI+ libraries and XP
header correction. The main worker owns UI/help/build integration and the
whole-application audit.
