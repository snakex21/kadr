# Single-worker loader handoff

Source: `src/loader.zig` only. This task does not edit main, image, DjVu, Win32
bindings, build.cmd, or Kadr.exe. The retained harness is here, not a replacement
for either earlier harness.

## Exact UI contract

```zig
pub const result_message = c.WM_APP + 10;
pub const Result = struct {
    image: Image,
    path: [32768]u16, // owned, NUL-terminated, max 32767 UTF-16 code units
    success: bool,
    token: u32,      // nonzero accepted-request generation, wrapping
    requested_page: u32 = 0, // zero-based; actual selection is image.page
    preview: Image = .{}, // optional owned raster; software buffer or GDI fallback
};
pub fn init(hwnd: c.HWND) bool;
pub fn request(path: [*:0]const u16) bool; // page zero
pub fn requestPage(path: [*:0]const u16, page: u32) bool;
pub fn take() ?*Result;
pub fn release(result: *Result) void;
pub fn shutdown() void;
```

- All lifecycle/control calls (`init/request/take/shutdown`) run on one UI
  thread. One loader instance per process; duplicate init is rejected. Reinit
  after shutdown is supported. GDI+ must already be started.
- `request` copies the path into an OS-heap node and never waits for decoding.
  False (uninitialized, empty/overlong path, OOM) leaves the prior generation
  and request intact. There is one active job and at most one pending job;
  newer requests replace pending nodes. No unbounded work queue.
- `requestPage` shares the identical queue/generation but calls Image.setPage
  on the worker after loading. Page indices are zero-based. Invalid/unrenderable
  pages fall back to the loaded first page if it remains valid; image.page is
  authoritative and requested_page records the original request. If loading or
  page rollback leaves no valid image, success is false. `request(path)` is the
  backward-compatible `requestPage(path, 0)` wrapper.
- Keep the current UI image while loading. A failed decode is a normal result
  with `success=false`, a default/closed image, the copied path and its token.
- `WM_APP+10` is just an asynchronous wakeup, with the completed token in
  WPARAM, LPARAM zero. **Do not treat a message as a result pointer.** Old
  messages can find `take()==null`; `take` never returns a stale generation.
- The UI owns a taken node. On success, close the prior UI image, move
  `result.image` into the current image, then **set `result.image = .{}` before
  `release(result)`**. Move/reset `result.preview` the same way if retaining it;
  release closes both images. Copy the result path before release if UI needs it.
- Optional preview: for successful nonanimated originals above 2,000,000 pixels,
  the worker resamples the full already-oriented/selected image, never an EXIF
  thumbnail. Fresh native BGRA backing is sampled directly; otherwise a bitmap
  is locked read-only as ARGB (signed stride supported). Software bilinear uses
  1/256-pixel centers and premultiplied-alpha interpolation; RGB tolerance is
  2/255 against an independent float reference, alpha checked exactly. Preview
  owns a page-allocated buffer in Image._pixels, retained for Scan0 and freed by
  Image.close. Max long edge 1600, nearest-integer aspect, never upscaled.
  Metafiles are identified before LockBits (some GDI+ versions otherwise crash);
  unsupported/failed views retain the prior GDI+ bilinear/SourceCopy fallback.
  Fallback bitmap storage remains GDI+-owned. Source views are limited to 80 MP /
  320 MB, previews to 1600*1600*4 bytes, axis workspace to 19.2 KiB.
  The original is not mutated. Preview creation is best effort and never fails
  the original load. Stale work can skip preview creation; stale nodes free both.
  Main may use preview for interactive display only, original for HQ/printing.
  Preview is a static raster: after rotating/changing the current original, main
  must rotate or invalidate its preview accordingly. Borrowed access by another
  rendering worker must finish before either owned image is closed.
- `release` frees both owned images and heap node; never release twice or touch
  the node afterward. A taken node can survive loader shutdown but still must
  be released before GDI+ shutdown.
- `shutdown` signals and joins the active decoder, discards loader-owned
  active/pending/ready nodes, then closes event/thread/critical-section resources.
  It never calls TerminateThread or interrupts a codec. Call it before destroying
  the notification HWND and before GDI+ shutdown. It is idempotent.
- Shutdown can wait for the active Image.load / file IO / native codec. Existing
  DjVu wait loops have their own timeouts, but this is **not** a hard wall-clock
  deadline for every legacy GDI+ decoder. Pagination and rendering remain UI
  responsibilities. Page navigation can use requestPage to move both file
  loading and page selection off the UI; it reloads the document per request.
- A full window message queue can make PostMessage fail: the latest result
  remains available through `take()`/polling and is still cleaned by shutdown.

## Synchronization / -fsingle-threaded

No new build flags or libraries: keep existing kernel32/user32/ole32/GDI+,
`-target x86-windows.xp-gnu -mcpu=pentium3 -fsingle-threaded` and XP header fix.

The loader uses CreateThread, an auto-reset Event, native critical sections and
PostMessageW. No std.Thread, Zig atomic operation, TLS or CRT is used. Result
nodes are allocated directly with the serialized process HeapAlloc/HeapFree;
there is never a 64 KiB node value on a stack. Shared generation/pending/ready/
stop state is under a critical section. HWND/event are initialized before
CreateThread and unchanged until after join. Native COM MTA startup/teardown is
worker-local, including the ICO IStream fallback.

Inspected Zig 0.11 `std/heap/PageAllocator.zig`: Windows alloc/free take the
VirtualAlloc/VirtualFree branches (lines 22-31, 103-104); they do not use the
non-Windows shared mmap hint or atomics. Distinct transferred images' allocator
calls therefore do not require changing `-fsingle-threaded`.

**All new Image.load calls must use this worker.** `djvu.zig`'s mutable API cache
is initialized only there. Despite its old UI-thread comment, the cache becomes
read-only after first success and each published Document carries its API
pointer. UI navigation/close operates on a different, exclusively transferred
Document while the worker loads its own context/document. Never render, select
frames/pages, rotate or close the same Image concurrently on both threads.

## Reproduce and evidence

```bat
tests\loader-check\check.cmd
```

Python standard library only, no downloads. Fixtures: Unicode RGBA QOI, malformed
QOI, and an actually decoded 4000x3000 (12 MP) QOI. Existing application fixtures
provide PNG-backed ICO and Unicode DjVu, with existing DjVu DLLs copied locally.

Both ReleaseSmall and ReleaseSafe are checked by the retained harness. Covered:

- actual HWND/PostMessage dispatch, init/null/duplicate/reinit/shutdown;
- copied Unicode path, max/overlong/empty paths, failure completions;
- image move/reset/release and keeping the old current image;
- stale completed results, 1000 pending replacements and latest token/path;
- UI message dispatch plus old-image use during actual 12 MP decode;
- taken ICO after worker COM teardown;
- worker-only first DjVu cache initialization plus UI navigation/close of a
  different transferred document;
- requestPage DjVu indices 2 and 56 in the 57-page book, Unicode page paths,
  TIFF second page, invalid-page first-page fallback, malformed paged load,
  latest-wins across page requests and backward-compatible page-zero requests;
- independent preview transfer, landscape/portrait aspect, full-source pixel/
  alpha checks, unchanged original, exact 2 MP threshold and large-animation skip;
- actual mixed-color/mixed-alpha QOI and PNG sampling (direct/locked paths),
  EMF drawing fallback, negative-stride/address-bound unit checks and 4096
  randomized samples checked against independent premultiplied float math;
- 32 repeated lifecycle/queue/preview/active-shutdown rounds, GDI/native counts and
  occupied process-heap measurements (less than one Result node's growth).

Recent checks: 2468 checks each in ReleaseSmall/ReleaseSafe plus two sampling
unit tests (including 4096 randomized alpha cases). GDI resources 3 -> 3 and
native handles 134 -> 134 in both configurations. These are host checks, not
an XP hardware/performance guarantee.

Run `tests\\loader-check\\measure.cmd` for sequential before/after JPEG, PNG
and QOI 12 MP timing. `profile-before.exe` retains the pre-software GDI+ path;
current `profile.exe` is rebuilt from current loader source. Iteration 0 warms
each file; means use iterations 1..3. Raw CSVs, summary JSON and import/hash
reports are retained here. The optional root.loaderProfile hook/QPC calls are
compiled out of normal app builds. Stage 'load' includes Image.load/setPage;
GDI+ can defer actual decode into DrawImage (before) or LockBits (after), so
'access' after includes deferred decode/conversion, not just pointer lookup.

`audit_pe.py` reuses the retained codec auditor but writes only the loader test
binaries. Their XP 5.1 PE declarations, hashes and exact imports are retained in
`imports.json`. ReleaseSmall passed x86 PE32/no-CRT/known-post-XP-import checks:
kernel32, user32, GDI+, ole32 only. ReleaseSafe is an additional host safety
check, not an XP import-compatibility claim. Actual XP SP3/Pentium III runtime
has not been exercised. Kadr.exe is never built, launched, patched or overwritten.
