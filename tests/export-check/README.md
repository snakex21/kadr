# Export / file-tools foundation checks

Scope: `src/output.zig`, new `src/export_dialog.zig`, new `src/file_tools.zig`, and this directory only. No main/UI/printing/layout/i18n/build changes. No production Kadr.exe was built or launched.

## Coordinator APIs

All image operations run on the UI thread, after GdiplusStartup and before GdiplusShutdown. `Image` remains owned by the caller; never copy it by value. A current rotation is already baked into its handle. Pause playback/loading around the modal API (the dialog disables its owner, but a disabled owner can still receive timers).

```zig
// export_dialog.zig
pub fn show(owner: c.HWND, source: *const Image, source_path: [*:0]const u16) bool;

// file_tools.zig
pub fn copyPath(owner: c.HWND, path: [*:0]const u16) bool;
pub fn wallpaper(owner: c.HWND, source: *const Image) bool;
```

- `show`: true only after committing an export copy. False on cancel/failure. PNG/JPEG/BMP/TIFF/GIF, JPEG default **90**, quality 1–100, integer pixel dimensions, aspect lock. JPEG quality is disabled and ignored for other formats. Custom copies are capped at **64,000,000 pixels**. No encoding on edit notifications: only **Sprawdź rozmiar** or final export encodes.
- Native GetSaveFileNameW uses the existing Explorer+hook pattern. The filter is the chosen format; a conflicting extension is rejected. Default: source folder + basename + `-export.ext`. XP GetTempFileNameW limits export paths to MAX_PATH; longer paths get an explicit error, not truncation.
- Same source paths, 8.3 aliases, hard links, and junction aliases are rejected with Save guidance. Existing destinations require explicit **default-No** confirmation. A destination appearing during encoding cannot be replaced unless replacement was authorized. The reserved empty temp is in the target folder and is removed on failure. Size estimation reserves a temp in the source folder, then deletes it.
- `copyPath`: full, unquoted CF_UNICODETEXT with terminating NUL, including non-BMP Unicode. Requires a real owner. GlobalAlloc memory transfers to Windows only on successful SetClipboardData.
- `wallpaper`: separate mode-choice window, then an explicit **default-No** confirmation. Only after Yes may SPI_SETDESKWALLPAPER run. Composites fit/fill/stretch/center onto a white primary-screen-size BMP. No registry writes or Windows 7 WallpaperStyle 6/10. Eight bounded cache names `kadr-wallpaper-0.bmp` … `kadr-wallpaper-7.bmp` are beside the executable. SPI_GETDESKWALLPAPER plus path/file-ID checks skip the active file; it is re-queried before committing a different cache slot. Read-only EXE folders report an error; no AppData fallback. The coordinator's asInvoker manifest is still needed to disable Vista+ UAC virtualization.

Additional testable APIs:

```zig
// output.zig — existing Format, format, snapshot, save, copyClipboard unchanged.
pub const max_export_pixels: u64 = 64_000_000;
pub const ExportOptions = struct { width: u32, height: u32, jpeg_quality: u32 = 90 };
pub fn validExportDimensions(width: u32, height: u32) bool;
pub fn validOptions(source: *const Image, options: ExportOptions) bool;
pub fn aspectDimension(changed: u32, original_changed: u32, original_other: u32) ?u32;
pub fn scaledSnapshot(source: *const Image, width: u32, height: u32) ?Image;
pub fn saveOptions(source: *const Image, path: [*:0]const u16, kind: Format, options: ExportOptions) bool;
// saveOptions has the same PRIVATE-temp target contract as legacy save().
// Legacy save() still uses JPEG quality 92 and does not acquire the new 64 MP cap.

// export_dialog.zig — no UI in these helpers.
pub const CopyError = error{ InvalidPath, SameSource, InvalidOptions, WrongExtension, TargetExists, ReserveFailed, EncodeFailed, CommitFailed };
pub fn saveCopy(source: *const Image, source_path: [*:0]const u16, target_path: [*:0]const u16, kind: output.Format, options: output.ExportOptions, replace_authorized: bool) CopyError!void;
pub fn sameFile(a: [*:0]const u16, b: [*:0]const u16) bool;
pub fn defaultPath(source_path: [*:0]const u16, kind: output.Format, buffer: []u16) ?[:0]const u16;
pub fn positiveInteger(text: []const u16) ?u32;
// saveCopy's replacement flag is a caller contract, not a way to obtain consent.

// file_tools.zig — compositor/cache helpers NEVER change desktop settings.
pub const WallpaperMode = enum { fit, fill, stretch, center };
pub fn writeWallpaper(source: *const Image, target: [*:0]const u16, screen_width: u32, screen_height: u32, mode: WallpaperMode) bool;
pub fn wallpaperCachePath(buffer: []u16, active: [*:0]const u16, slot: u8) ?[:0]const u16;
// writeWallpaper writes only the caller's explicit private target; caller handles
// replacement. wallpaperCachePath is path-only, no file/OS side effects.
```

PNG/TIFF preserve alpha. JPEG flattens a private bitmap over white. All resizing uses fresh GDI+-owned storage and mirrored sampling edges, never an Image value copy. Exported images contain only the visible frame/page and no source metadata.

## Reproduce

Run `tests\export-check\check.cmd`. Builds from `src` with the repository Zig **0.11.0**, `x86-windows.xp-gnu`, Pentium III, existing Win32/GDI+ libraries. Builds **only dedicated test executables**. Python and the already-installed Pillow are needed for the native control/pixel checks. No Node, no physical input injection, no print jobs.

`audit_pe.py --fix` applies the same Zig/lld XP PE-header correction as the existing build, but ONLY to this directory's three fixed test binary names. It then checks x86, OS/subsystem 5.1, DLL/import denylists, and writes `imports.json`. This is not proof of runtime compatibility with XP.

The clipboard unit test publishes and then clears a generated Unicode test path using an owned hidden test window. It does not preserve pre-existing clipboard contents. Native tests generate all their own files under `generated/`; they never modify repository fixtures or launch production windows. Screenshots use PrintWindow on the test's own dialog only.

## Verified results (2026-11-07)

`check.cmd` passed:

- **11/11 Zig tests**, including all **4 existing output tests** and 7 additional tests: strict validation/overflow/64 MP bound; aspect arithmetic; up/down scaling and baked rotation; private ownership and unchanged pixels; alpha PNG/TIFF round-trips; JPEG white flattening; quality-dependent bytes; legacy quality 92 byte equality; safe new-copy creation; source hard-link rejection; unauthorized replacement rejection; failed read-only-target commit and temp cleanup; actual Unicode CF_UNICODETEXT; wallpaper fit/fill/center/stretch BMP pixels; unchanged source/alpha; bounded EXE-dir cache paths and active-slot exclusion.
- Generated JPEG: quality 5 = **852 bytes**, quality 100 = **17,702 bytes**, legacy/explicit quality 92 = **8,215 identical bytes**.
- **4/4 native scenario groups**, in `native-results.json`: invalid and over-limit input cannot enter Save; aspect lock; JPEG enable/disable/default; no files created by editing; explicit byte measurement; Save cancellation; whole-dialog cancellation; actual PNG save with alpha and current rotation; source-path rejection; existing target default No and explicit Yes; a real destination-creation race during **24 MP** encoding rejects the non-replacing rename and removes its temp. Source file hashes remain unchanged, including while a source is loaded from disk; owners are re-enabled.
- PNG size estimate exactly matched the native saved copy: **190 bytes**, 16×24 pixels.
- ReleaseSafe unit/native harness and ReleaseSmall native harness compiled. Native scenarios ran against ReleaseSafe. Header/import audit passed for all three: x86, OS/subsystem **5.1**; 100 / 73 / 94 imports for dialog / dialog-small / unit respectively.
- Screenshots: `export-dialog.png`, `save-dialog.png`.

**Not verified:** execution on a real Windows XP machine; production integration (owned by coordinator); actual SPI_SETDESKWALLPAPER success/failure, wallpaper mode dialog interaction, or read-only-EXE-folder OS behavior. Tests deliberately NEVER call wallpaper() or SPI_SETDESKWALLPAPER, so the real desktop was not changed. Wallpaper OS/cache safety is additionally source-reviewed, not an OS-setting test. The asInvoker manifest remains the coordinator's integration responsibility.
