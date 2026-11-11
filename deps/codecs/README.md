# Native raster codecs (Kadr v0.2)

No third-party codec library or DLL was added. `src/codecs.zig` is native project
code, distributed with Kadr under GPL-3.0-or-later (see the repository's
`LICENSE`). All corresponding source is in `src/codecs.zig`,
`src/formats.zig`, and the integration in `src/image.zig`.

The implementation does not copy stb_image, libwebp, or the QOI reference C
implementation; those libraries' licenses are not dependencies of this change.
The QOI file-format description/reference is https://qoiformat.org/ and the
Netpbm format descriptions are https://netpbm.sourceforge.net/doc/ . These are
format references, not downloaded/vendored dependencies or a claim about a
current library release.

**WebP is not implemented or advertised.** The requested `web_download` tool
was unavailable to this worker. No network download by script/curl was used,
no old unverified decoder was substituted, and a current libwebp release could
not be verified. A future WebP integration needs verified upstream sources
from https://chromium.googlesource.com/webm/libwebp plus its licenses, bounded
allocation, smoke fixtures, and a separate XP import audit.

## Integration

- No additional linker flags, `-lc`, C files, static libraries or DLLs.
- Keep the existing Zig 0.11 x86 XP/Pentium III flags and GDI+/kernel32 linkage.
- Compile `src/image.zig` as before; it imports the codec and formats modules.
- Main's file dialog can assign `formats.filter` directly to `lpstrFilter`.
  `formats.supported(path: []const u16) bool` is the common navigation predicate.
- Continue the existing XP PE-header correction and whole-application audit.
  The new test audit modifies only binaries in `tests/codec-check/`.

See `tests/codec-check/README.md` for supported subsets, limits and checks.
