"""Measure the print-preview sheet and the photo on it from a screenshot."""
import sys
from PIL import Image
img = Image.open(sys.argv[1]).convert('RGB')
W, H = img.size
px = img.load()
# Sheet: largest pure-white area to the right of the sidebar.
def white(p): return p[0] > 250 and p[1] > 250 and p[2] > 250
xs = [x for x in range(W // 3, W) if sum(white(px[x, y]) for y in range(0, H, 4)) > H // 16]
ys = [y for y in range(H) if sum(white(px[x, y]) for x in range(W // 3, W, 4)) > W // 40]
sx0, sx1, sy0, sy1 = min(xs), max(xs), min(ys), max(ys)
# Photo: non-white, non-light-gray pixels inside the sheet.
ix = [x for x in range(sx0, sx1) if any(max(px[x, y]) < 225 for y in range(sy0 + 3, sy1 - 3, 3))]
iy = [y for y in range(sy0, sy1) if any(max(px[x, y]) < 225 for x in range(sx0 + 3, sx1 - 3, 3))]
ix0, ix1, iy0, iy1 = min(ix), max(ix), min(iy), max(iy)
sw, sh = sx1 - sx0, sy1 - sy0
print(f'sheet {sw}x{sh} at {sx0},{sy0}; photo {ix1-ix0}x{iy1-iy0} at {ix0},{iy0}')
print(f'gaps L {100*(ix0-sx0)/sw:.1f}% R {100*(sx1-ix1)/sw:.1f}% T {100*(iy0-sy0)/sh:.1f}% B {100*(sy1-iy1)/sh:.1f}%; photo covers {100*(ix1-ix0)*(iy1-iy0)/(sw*sh):.1f}% of sheet')
