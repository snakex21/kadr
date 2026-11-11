# Native print-options checks (Zig 0.11, Win32 XP x86)

Only `src/printing.zig`, `src/layout.zig` and this new test directory belong to this task. No production EXE build, no fixture changes, no Node, and no print jobs.

## Reproduce

From `src`:

```bat
..\tests\print-options\check.cmd
..\tests\print-options\Kadr-print-options.exe
```

The batch file builds/runs printing tests (including layout), runs standalone layout tests, builds only `tests/print-options/Kadr-print-options.exe`, then audits all three test PEs. `--test-no-exec` plus a separate native invocation avoids Zig 0.11's mixed-separator `BadPathName` launcher issue on this host. `-fsingle-threaded` is mandatory even for the standalone Zig test runner to avoid its SRW-lock imports.

The GUI EXE generates its own colored source in memory and opens **its own** print preview and owner. It scripts native control messages: Advanced expand/collapse, focused-button Enter, native Tab, own percentage, invalid blank percentage disabling Print, comma input, absolute X/Y, page-preview drag, Center, grayscale, Esc and owner restoration. It never invokes the Print command. `--interactive` leaves that dedicated test preview open for inspection; close it with Wróć/Esc afterward. The harness does not enumerate or manipulate existing application windows; its class lookup is process-ID checked.

## Coverage and artifacts

- `results.txt`: printing suite and standalone layout results.
- All 17 paper sizes and both orientations; distinct metric/inch photos; ISO B4/B5; DEVMODE paper codes, DMPAPER_USER tenths-mm bounds, orientation, dmScale=100, dmColor.
- Custom media, 96-DPI percent, aspect-locked physical width/height, signed absolute physical-sheet X/Y, edge clipping/no intersection, drag grab-area recovery.
- Asymmetric physical offsets, non-square printer DPI and common physical placement/clip transforms.
- Real GDI+ ColorMatrix pixel checks on red/green/blue/semitransparent source: equal RGB, expected luminance, alpha over white, color rendering and unchanged source. Both preview and print call the tested renderer.
- Hidden native control exercise includes invalid inputs retaining the last valid placement and disabling Print, custom-media edits, and a simulated driver's substitution of 4x6in for 10x15cm using accepted non-square-DPI caps.
- `imports.json`: x86 headers and imports. `audit.py` adjusts **test binaries only** from Zig's 5.2 subsystem minor to XP 5.1, then checks imports. Added GDI+ image-attribute/ColorMatrix and spooler APIs are XP-era APIs, not Vista APIs.
- `render-regression.txt`: existing unmodified render harness binaries, ReleaseSmall and ReleaseSafe; each passed 49,787 checks. Existing fixtures were read only.
- `preview-compact.png`, `preview-advanced.png`: screenshots of this harness's own preview. Intentional white paper around the image is not stretched away.
- `ui-phrases.txt`: stable production `L("...")` literals, new plus reused, for the coordinator's catalog coverage. No translations or i18n alias were edited here.

## Integration API

`printing.show(owner, Source)` is unchanged; it still clones the source and restores the owner before destroying the preview. Keep `const L = w.L` until the coordinator replaces the alias with i18n.L.

`layout.Paper` preserves its first four tags/order and adds A3/A6/B4/B5/Legal/Executive/Tabloid, more metric photos and distinct inch photos. `paperPage(Paper, Orientation)` remains valid. New `customPage(width_mm,height_mm,orientation)` accepts 10..3276.7 mm before orientation.

`Scale` adds `.percent`, `.width_mm`, `.height_mm`; `Settings` adds `.percent=100`, `.physical_mm=100` and optional `.position: ?Position`. Absolute physical-sheet coordinates override the unchanged legacy `center` behavior. Both physical-size modes always preserve image aspect ratio. `Transform.deltaMM` and `dragPosition` share drag/reference geometry.

## Verification limits

Tests run on the current native Windows host, **not actual XP SP3/Pentium III hardware**. This host had no selected/default printer in the screenshots. No physical jobs, real printer-driver media negotiation, spooler cancellation or hard-copy color/fit were tested. Driver substitutions are covered by deterministic DEVMODE/caps tests and the production path always adopts accepted physical DC caps; real driver coverage still needs an installed printer or a nonphysical test driver.
