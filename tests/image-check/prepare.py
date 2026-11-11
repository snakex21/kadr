"""Create only this harness's fixtures and exe-relative DLL copies.

Run from any directory. Python + Pillow and the checked-in/extracted local
DjVuLibre tools are development prerequisites, not application dependencies.
"""
from pathlib import Path
import shutil
import subprocess

from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent


def main():
    required = (
        "01-krajobraz.png", "02-zdjecie.jpg", "03-obraz.bmp", "04-strony.tiff",
        "05-animacja.gif", "06-przezroczystosc.png", "07-ikona.ico",
        "08-zażółć-gęślą.png", "broken.png",
    )
    missing = [name for name in required if not (ROOT / "tests/fixtures" / name).is_file()]
    if missing:
        raise SystemExit("Missing common fixtures; run python tests/generate_fixtures.py first: " + ", ".join(missing))

    dll_dir = HERE / "deps/djvu"
    dll_dir.mkdir(parents=True, exist_ok=True)
    for name in ("msvcr100.dll", "msvcp100.dll", "libjpeg.dll", "libdjvulibre.dll"):
        shutil.copy2(ROOT / "deps/djvu" / name, dll_dir / name)

    book = ROOT / "tools/djvu-extracted/doc/djvulibre-book-en.djvu"
    shutil.copy2(book, HERE / "book.djvu")
    shutil.copy2(book, HERE / "książka.DJV")
    Image.new("RGBA", (32, 32), (255, 0, 0, 255)).save(
        HERE / "classic.ico", bitmap_format="bmp", sizes=[(32, 32)])
    frames = [Image.new("RGB", (8, 8), color) for color in ("red", "green", "blue")]
    frames[0].save(HERE / "short-delays.gif", save_all=True,
                   append_images=frames[1:], duration=[0, 10, 240], loop=0, disposal=2)
    (HERE / "large.ppm").write_bytes(
        b"P6\n12000 100\n255\n" + b"\xff\x00\x00" * (12000 * 50)
        + b"\x00\x00\xff" * (12000 * 50))
    subprocess.run([str(ROOT / "tools/djvu-extracted/c44.exe"),
                    str(HERE / "large.ppm"), str(HERE / "large.djvu")],
                   cwd=ROOT, check=True)
    print("Image harness fixtures and local DLL copies ready:", HERE)


if __name__ == "__main__":
    main()
