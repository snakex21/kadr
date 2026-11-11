"""Development-only Pillow fixtures; native Zig/GDI+ does all drawing/timing."""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
FIX = HERE / 'fixtures'
FIX.mkdir(exist_ok=True)
base = bytearray()
for y in range(384):
    for x in range(512):
        base.extend(((x * 3 + y * 5) % 256, (x ^ y) % 256, (x * 7 - y * 3) % 256))
photo = Image.frombytes('RGB', (512, 384), bytes(base)).resize((4000, 3000), Image.Resampling.BICUBIC)
draw = ImageDraw.Draw(photo)
for x in range(0, 4000, 113):
    draw.line((x, 0, 3999 - x, 2999), fill=(240, 50, 80), width=3)
photo.save(FIX / '12mp.png')
alpha = Image.new('RGBA', (96, 64), (255, 0, 255, 0))
alpha.paste((0, 255, 0, 128), (32, 0, 64, 64))
alpha.paste((20, 40, 230, 255), (64, 0, 96, 64))
alpha.save(FIX / 'alpha.png')
# Snapshot protected files BEFORE any harness compilation/header adjustment.
protected = ['Kadr.exe', 'src/main.zig', 'src/ui.zig', 'src/win.zig', 'build.cmd']
(HERE / 'protected.json').write_text(json.dumps({p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest()
                                               for p in protected}, indent=2) + '\n')
print('Prepared 4000x3000 RGB + 96x64 RGBA PNG; snapshotted protected files.')
