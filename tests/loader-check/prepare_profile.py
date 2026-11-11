"""Actual 12 MP JPEG/PNG fixture files; Pillow is development-only, no download."""
from pathlib import Path
from PIL import Image
HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
FIX = HERE / 'fixtures'
FIX.mkdir(exist_ok=True)
jpeg, png = FIX / 'photo-12mp.jpg', FIX / 'photo-12mp.png'
if not jpeg.exists() or not png.exists():
    with Image.open(ROOT / 'tests' / 'fixtures' / '02-zdjecie.jpg') as original:
        image = original.convert('RGB').resize((4000, 3000), Image.Resampling.LANCZOS)
        image.save(jpeg, 'JPEG', quality=92, subsampling=2)
        image.save(png, 'PNG', compress_level=3)
print(f'12 MP benchmark JPEG: {jpeg.stat().st_size} bytes; PNG: {png.stat().st_size} bytes')
