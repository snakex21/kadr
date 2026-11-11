# Native retained raster / interactive-quality handoff

Implementation: **`src/render.zig` only**. The render task does not edit main,
UI, Win32 bindings, loader, build.cmd or Kadr.exe. Main integration is owned
separately and may proceed concurrently. This directory is a retained native
harness, not a replacement application.

## Exact public contract

```zig
pub const Renderer = struct { // default .{}
    pub fn draw(self: *Renderer, target: w.c.HDC, source: *w.GpImage,
        iw: u32, ih: u32, x: f32, y: f32, dw: f32, dh: f32,
        clip: w.c.RECT, interactive: bool) void;
    pub fn setPreview(self: *Renderer, preview: ?*w.GpImage,
        width: u32, height: u32) void;
    pub fn invalidate(self: *Renderer) void;
    pub fn deinit(self: *Renderer) void;
};
```

- One UI thread owns each renderer. Start GDI+ before drawing; deinit before
  GDI+ shutdown. Do not copy a live renderer (it owns native handles).
- Call `invalidate()` on new image, rotate, page and GIF frame, **before** the
  old source is replaced/disposed or mutated. Source identity and dimensions
  are also checked, but cannot detect same-pointer frame mutations/reuse.
- `setPreview` attaches a **borrowed**, already prepared GDI+ image. The renderer
  never disposes it or prepares previews on the UI thread. The caller detaches
  with `setPreview(null, 0, 0)` before freeing/replacing it. Zero dimensions also
  detach. `invalidate()` retains the attachment (caller rotates both images);
  `deinit()` forgets it without disposal. Default null preserves the old path.
- Only interactive cache misses / direct crops sample the preview, using its
  own dimensions while retaining the original source identity and destination
  geometry. Preview-built pixels are always low quality, so idle redraws the
  **original** with HQ even at identical geometry. Valid original HQ rasters
  still win during interaction. Changing preview discards low-quality cache,
  but preserves a valid original HQ cache.
- An attached preview also opts into **transient StretchBlt zoom proxies**.
  If source identity/dimensions match, changing interactive geometry stretches
  the existing bounded raster instead of rebuilding it. DIB/DC/storage and real
  cache dimensions/quality remain unchanged; pan phase is mapped across the
  whole image under the canvas/DC clip. No new renderer bitmap, graphics object
  or full-source resampling per step. COLORONCOLOR is intentionally fast; the
  baked checker can temporarily scale. Target DC state is restored. Idle must
  rebuild from the original at the actual destination size, restoring 16px
  checker cells. Stretch failure falls through to the existing rendering path.
  Proxies are restricted to cache-eligible destination geometry (<=8192 edges,
  <=8M pixels); larger zooms use the visible source crop, not an enormous GDI
  whole-image stretch. Without a preview the previous non-pixel-art path and
  HQ behavior are unchanged.
- **Automatic pixel-art policy:** original source long edge <=64 pixels and
  both destination axes >=4x use nearest-neighbor, interactive **and idle**.
  They bypass filtered previews/proxies and are final quality without another
  idle resample. Cached nearest uses half-pixel sampling; oversized/failed-cache
  tiny draws read and paint only visible original source pixel cells, at most
  64x64 tested cells, without a raster allocation. This avoids GDI+ quantizing
  very narrow fractional crops to empty at extreme zoom. Alpha is composited
  over the original 16px checker; source RGBA remains untouched.
- **Geometry safety contract:** `render.max_geometry == 8_388_608` device pixels.
  `abs(x)`, `abs(y)`, positive `dw` and `dh` must each be <=this cap (also finite).
  Larger/invalid inputs are a no-op, never silently rescaled. Main can cap
  uniform zoom at `max_geometry / max(iw, ih)` and keep pan origins within the
  cap. Integer endpoints remain within +/-2^24, preserving f32 integer pixel
  precision; internal source-crop math is f64. This does not relax the raster
  budget. 60000% means scale **600**, well within this cap for tiny sources.
- Cache key: source pointer, source dimensions and rounded destination width /
  height. Destination origin and dimensions snap to nearest device pixel.
  Clip and pan position are deliberately not part of the key.
- Interactive misses use GDI+ Bilinear (3); idle uses HighQualityBicubic (7).
  An idle draw upgrades a low-quality cache in the **same DIB/DC**. An existing
  high-quality cache remains usable during gestures. Valid cache repaint/pan
  at unchanged geometry only clips and BitBlts: no allocations, no GDI+
  graphics, no resampling.
- One top-down 32-bit BI_RGB DIB plus one memory DC, only when both rounded
  edges are <=8192 and area <=8,000,000 pixels. Maximum raster is **32,000,000
  bytes (30.52 MiB)**; 1600x1000 uses **6,400,000 bytes (6.10 MiB)**. GDI+ / source
  decoding may use its own temporary memory; this is a retained-raster limit,
  not a total-process limit. Old DIB is released before size/source replacement.
- Every raster starts with an opaque 16px checkerboard (235/210), anchored to
  image origin, then GDI+ composites the original image onto it. BitBlt is
  opaque: no AlphaBlend/PARGB conversion or source mutation. Fully transparent
  and half-transparent RGBA retain their intended appearance.
- No giant zoom bitmap: oversize or cache-creation failure draws a checker
  only in the visible image rectangle, then maps that visible destination
  rectangle back to a **source crop** (tiny nearest instead paints visible
  source cells as described above). Work is bounded by the canvas/DC clip,
  not by the full zoomed image. Bilinear interactive, bicubic idle.
- The passed canvas clip and the target HDC rectangular clip are intersected.
  Outside the image/clip is untouched; the caller fills the dark viewport.
  A complex DC clip is respected by BitBlt/GDI; direct GDI+ uses its bounding
  rectangle, so pass an actual rectangular dirty/canvas clip as in main.
- Cache/DC/bitmap failures release partial resources and attempt direct draw.
  Total GDI+/DC failure can naturally prevent drawing; draw never destroys or
  modifies the original image. Invalidate/deinit are idempotent.

## Reproduce (development Windows host)

```bat
tests\render-check\check.cmd
```

Zig 0.11.0 bundled in `tools`, Python + Pillow (development fixtures only).
No download or installed CRT is needed by the native executable. All drawing,
comparison, timing, handle measurements and failure exercise run in Zig with
Win32/GDI+, not Python. Fixture generation creates a nonuniform 4000x3000 RGB
PNG with gradients/detail/diagonals and a 96x64 straight-RGBA PNG with hidden
transparent RGB, half-green and opaque blue.

The script builds both native harnesses using:

```text
zig build-exe tests/render-check/harness.zig --main-pkg-path .
  -target x86-windows.xp-gnu -mcpu=pentium3 -fsingle-threaded
  -fno-stack-check -fno-stack-protector
  -Itools/zig-windows-x86_64-0.11.0/lib/libc/include/any-windows-any
  -lkernel32 -lgdiplus -luser32 -lgdi32 -lpsapi
  -O ReleaseSmall -femit-bin=tests/render-check/render-check.exe
```

The second build substitutes ReleaseSafe / render-check-safe.exe. The auditor
reuses the retained codec PE parser, but patches **only render harness** OS /
subsystem declarations to 5.1 (Zig 0.11 otherwise emits 6.0). `imports.json`
records x86 PE32, hashes, no-CRT and known-post-XP-import checks. PSAPI is used
only by the harness's XP-compatible process-memory counters, not the renderer.
ReleaseSafe is an extra host safety check, **not** an XP compatibility claim.
No actual XP SP3 / Pentium III machine was exercised. These are actual host
Windows 10 measurements, not XP performance guarantees.

## Evidence and checks

`results.txt` retains the latest actual measurements for **both** builds.
60 panning iterations follow warmup at 12MP -> 1600x1000, with a 1280x800
viewport. Each frame calls GdiFlush, so cached timing includes completed GDI
work, not just queued commands. Baseline calls the unchanged original
`w.imageRectClipped` (HQ bicubic per paint); it does not include main's old
checker drawing, viewport clearing, window/UI dispatch or presentation. Initial
cache build and settle latency are reported separately; the speedup applies
only to warm retained pans, **not** first paint, new zoom sizes or GIF frames.
Without an attached preview, interactive bilinear still incurs full-source
GDI+ conversion/resampling on a miss. With a preview, a new native benchmark
measures **12 changing zoom sizes** from 700x525 to 1415x1061, comparing the
12MP original against a 1600x1200 GDI+-created 32-bit ARGB preview. Every step
is a real size/cache miss and includes allocation, checker fill and GdiFlush.
That preview baseline is deliberately invalidated each step to measure the
previous cache-miss behavior. A third renderer retains its initial 650x488
raster as a StretchBlt proxy throughout the same sequence. Another 60 zoom+pan
pairs measure mean/max proxy latency and exact bitmap/DC/storage stability,
GDI counts and private bytes. Idle then rebuilds original HQ at 1415x1061 and
compares pixels to the original helper (max observed channel error 2/255).
Preview preparation is timed separately, outside the gesture (loader-owned
work). The borrowed preview consumes 7,680,000 bytes in its owner, in addition
to the unchanged renderer raster budget; the renderer does not allocate or own
that source image. See `results.txt` for mean/max step timings and speedup.

Native coverage:

- exact cache bitmap/DC/storage retained across 60 pans, including HQ reuse
  while interactive; no GDI growth or private-byte growth in the warm loop;
- >20,000 sampled interior pixels compared to the old HQ path (observed exact
  RGB match); edge pixels omitted because baked checker intentionally replaces
  the old dark-edge background;
- genuinely different bilinear/bicubic output, idle upgrade in the same
  DIB/DC, rounded-dimension reuse/change and HQ reference comparison;
- transparent checker spacing/phase during pan, 50% alpha compositing,
  opaque pixels, unchanged source RGBA, canvas/image exterior sentinels;
- cached **and direct** HDC dirty clipping, nonzero clip origins, same-pointer
  frame invalidation, real rotation/dimension change, invalid/offscreen inputs;
- exact 8M pixel budget, first-over-budget rejection, 8192 / 8193 edge boundary,
  release of old cache on oversized zoom, 200000x150000 (30 billion destination
  pixels) zoom cropped to 270x185 with zero retained raster;
- cropped HQ and alpha output compared against full-image reference (observed
  max channel error 1/255, allowed 2). Cropped bilinear has GDI+ fixed-point
  phase differences near sharp lines (observed max 12/255, allowed 16 **only**
  for this fast interactive comparison); settled output uses tighter HQ check;
- preview-enabled proxy geometry changes and 60 zoom+pan pairs with no raster
  replacement; clipping/DC-mode restoration; original HQ proxy reuse; idle
  restoring real size and 16px checker; oversized zoom returning to crop path;
- 1x1 / 2x3 / 8x8 pixel art at 4x / 32x / 600x, all visible block pixels and
  cropped image edges exact in both interactive/idle modes, every source cell
  panned through view at 60000%, no black/empty/edge-bleed/axis-flip output;
  huge opaque/alpha 1x1 at the geometry cap, safe rejection beyond it; a native
  60-pan tiny direct-crop timing with zero raster/GDI growth;
- 100 source-replacement / quality-upgrade / invalidate / repeated-deinit
  cycles: exact GDI + native handle stability and bounded private memory;
- borrowed preview sampling/alpha and own-dimension source crops, original
  cache key, exact same-geometry original HQ upgrade, HQ reuse while interactive,
  preview replace/detach/invalid dimensions, invalidate retaining attachment,
  deinit not disposing it, unchanged source pixels and oversize/HQ fallback;
- **real GDI quota exhaustion**, leaving one object slot: memory DC creation
  succeeds, DIB creation fails, partial cache is released, direct fallback still
  produces correct source pixels, then all GDI resources return to baseline.

`protected.json` snapshots read-only inputs. Kadr.exe/UI/win/build hashes must
remain unchanged across a run. A concurrent integration-owner change to main
is reported separately rather than treated as a render failure. The harness
never writes any of these inputs; it never runs the app build/header fixer.

For a short proxy/tiny-only native smoke test, set `KADR_RENDER_FOCUSED=1`
before check.cmd; its output explicitly marks the full benchmark skipped.
Unset that variable for full verification and retained performance results.

## Deliberately unchanged: settled fit quality

Idle non-pixel-art draws still use the original, not preview HQ. The original
HQ settle latency is reported separately; this patch does not hide or remove
that synchronous cost. A future **explicit opt-in** preview-quality fit mode
could avoid it when both destination edges are <=preview edges, but would
change settled pixels (two resampling stages and worker-preview quality).
It needs a caller-visible fidelity policy and image-quality evidence first.
Original 1:1 views, detailed zoom and printing must remain original-source.
Source loading / worker preview preparation are outside this render-only task.
