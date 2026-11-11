# Retained image backend regression harness

Imports the **current** `src/image.zig`, `src/djvu.zig`, and `src/win.zig`; no
snapshots or copies of application source are compiled. It never launches,
changes, or overwrites `Kadr.exe` and has no GUI interaction. Both executables
and their exe-relative DLL copies live in this directory.

## Prerequisites

- Windows; bundled Zig 0.11.0 in `tools/zig-windows-x86_64-0.11.0`.
- Python with Pillow (development fixtures only).
- Common fixtures in `tests/fixtures`; recreate if needed with
  `python tests/generate_fixtures.py`.
- Four supplied DLLs in `deps/djvu` and the locally extracted
  `tools/djvu-extracted/c44.exe` and `doc/djvulibre-book-en.djvu`.

## One-command rerun

From the `Kadr` directory, in cmd.exe:

```bat
tests\image-check\check.cmd
```

The script prepares its own fixtures and DLL copies, rebuilds both executables,
adjusts/audits their PE headers, and runs each with fail-fast exit status.
It leaves the harness and all generated artifacts in place.

## Exact individual commands (working directory: Kadr)

```bat
python tests\image-check\prepare.py
tools\zig-windows-x86_64-0.11.0\zig.exe build-exe tests\image-check\harness.zig --main-pkg-path . -target x86-windows.xp-gnu -mcpu=pentium3 -O ReleaseSmall -fsingle-threaded -fno-stack-check -fno-stack-protector -isystem tools\zig-windows-x86_64-0.11.0\lib\libc\include\any-windows-any -femit-bin=tests\image-check\image-check.exe -lkernel32 -lgdiplus -luser32 -lgdi32 -lole32
tools\zig-windows-x86_64-0.11.0\zig.exe build-exe tests\image-check\harness.zig --main-pkg-path . -target x86-windows.xp-gnu -mcpu=pentium3 -O ReleaseSafe -fsingle-threaded -fno-stack-check -fno-stack-protector -isystem tools\zig-windows-x86_64-0.11.0\lib\libc\include\any-windows-any -femit-bin=tests\image-check\image-check-safe.exe -lkernel32 -lgdiplus -luser32 -lgdi32 -lole32
python tests\image-check\audit_pe.py
tests\image-check\image-check.exe
tests\image-check\image-check-safe.exe
```

Each successful run prints `image: x86 XP harness PASS (76 checks)` and returns
zero. Counts cover missing/malformed files, default/idempotent close state,
PNG/JPEG/BMP/alpha/Unicode, PNG-compressed and classic ICO, GIF frame delays
(including zero and 10 ms), two-page TIFF, the official 57-page DjVu book,
Unicode `.DJV`, page bounds/navigation, rotation, repeated format transitions,
and a generated 12000x100 DjVu rendered at 6000x50. Pixel checks verify RGB32
channel order, top-down rows, and backing-buffer lifetime after rotation.

Zig 0.11 emits a PE subsystem 6.0 header despite the `.xp` target. The audit
script adjusts only these two harness headers to OS/subsystem 5.1. ReleaseSmall
is the XP-target candidate and is checked for CRT and known post-XP imports.
ReleaseSafe is an additional **host-Windows** safety test; Zig diagnostics may
import newer APIs there. Running on host Windows is not proof of XP execution.
