"""Small deterministic loader fixtures; no downloads and no app build/write."""
from pathlib import Path
import shutil
import struct
import zlib

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
FIX = HERE / 'fixtures'
FIX.mkdir(exist_ok=True)
end = bytes(7) + b'\x01'
small = b'qoif' + struct.pack('>IIBB', 2, 1, 4, 0)
small += b'\xff\xff\x00\x00\xff\xff\x00\xff\x00\x80' + end
(FIX / 'zażółć-漢字.QOI').write_bytes(small)
(FIX / 'broken.qoi').write_bytes(b'not a QOI file')
def solid_pixels(color, count):
    runs, remainder = divmod(count - 1, 62)
    data = b'\xff' + bytes(color) + b'\xfd' * runs
    if remainder:
        data += bytes([0xc0 | (remainder - 1)])
    return data

big = b'qoif' + struct.pack('>IIBB', 4000, 3000, 4, 0)
big += solid_pixels((255, 0, 0, 255), 4000 * 1500)
big += solid_pixels((0, 0, 255, 128), 4000 * 1500)
(FIX / 'large.qoi').write_bytes(big + end)
for name, width, height in [('portrait.qoi', 1001, 2001), ('threshold.qoi', 2000, 1000)]:
    data = b'qoif' + struct.pack('>IIBB', width, height, 4, 0)
    (FIX / name).write_bytes(data + solid_pixels((255, 0, 0, 255), width * height) + end)
# Valid GIF with small frame rectangles on a >2 MP logical screen, to verify
# animation is excluded even when it meets the preview size threshold.
animated = bytearray((ROOT / 'tests' / 'fixtures' / '05-animacja.gif').read_bytes())
struct.pack_into('<HH', animated, 6, 2000, 1200)
(FIX / 'large-animated.gif').write_bytes(animated)
# >2 MP alternating mixed-alpha pixels, shared by direct QOI and locked PNG.
colors = [(255, 0, 0, 255), (0, 255, 0, 0), (11, 23, 197, 128), (255, 255, 255, 255)]
width, height = 2001, 1001
rgba_rows = [((bytes(a) + bytes(b)) * (width // 2) + bytes(a)) for a, b in (colors[:2], colors[2:])]
qoi_rows = [((b'\xff' + bytes(a) + b'\xff' + bytes(b)) * (width // 2) + b'\xff' + bytes(a)) for a, b in (colors[:2], colors[2:])]
(FIX / 'mixed.qoi').write_bytes(b'qoif' + struct.pack('>IIBB', width, height, 4, 0) + (qoi_rows[0] + qoi_rows[1]) * (height // 2) + qoi_rows[0] + end)
def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
raw = (b'\x00' + rgba_rows[0] + b'\x00' + rgba_rows[1]) * (height // 2) + b'\x00' + rgba_rows[0]
(FIX / 'mixed.png').write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 1)) + chunk(b'IEND', b''))
shutil.copytree(ROOT / 'deps' / 'djvu', HERE / 'deps' / 'djvu', dirs_exist_ok=True)
print('Prepared Unicode + malformed + 12 MP QOI fixtures and existing DjVu test DLLs')
