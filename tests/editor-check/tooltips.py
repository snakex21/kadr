"""Count registered toolbar/print tooltips in an owned private-desktop process.
TTM_GETTOOLCOUNT carries no pointers, so it is safe across processes."""
import argparse
import shutil
import sys
import tempfile
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/features-check'))
import run as native
import languages
from tools import App, check, text
from PIL import Image

U = native.U


def tips(app):
    found = []
    def each(hwnd, _):
        pid = native.W.DWORD() if hasattr(native, 'W') else None
        return True
    import ctypes as C
    from ctypes import wintypes as W
    CALLBACK = C.WINFUNCTYPE(W.BOOL, W.HWND, W.LPARAM)
    def visit(hwnd, _):
        owner = W.DWORD()
        U.GetWindowThreadProcessId(hwnd, C.byref(owner))
        if owner.value == app.pid and native.cls(hwnd) == 'tooltips_class32':
            found.append(hwnd)
        return True
    U.EnumDesktopWindows(app.desktop, CALLBACK(visit), 0)
    return [(h, U.SendMessageW(h, 0x40D, 0, 0)) for h in found]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--exe', type=Path, default=ROOT / 'tests/Kadr-editor.exe')
    parser.add_argument('--minimum', type=int, default=1)
    args = parser.parse_args()
    work = Path(tempfile.mkdtemp(prefix='kadr-tooltips-'))
    exe = work / 'Kadr.exe'
    shutil.copy2(args.exe.resolve(), exe)
    (work / 'Kadr.ini').write_text('[General]\nLanguage=pl\n', encoding='ascii')
    source = work / 'photo.png'
    Image.new('RGB', (800, 500), 'teal').save(source)
    name = 'KadrTips-' + uuid.uuid4().hex
    desktop = U.CreateDesktopW(name, None, None, 0, 0x1ff, None)
    check(desktop, 'desktop')
    try:
        with App(exe, source, desktop, name) as app:
            main_tips = tips(app)
            print('main tooltip windows/counts:', [n for _, n in main_tips])
            check(max([n for _, n in main_tips] or [0]) >= args.minimum, ('main toolbar tooltips missing', main_tips))
            preview = app.open(109, 'Kadr.PrintPreview.1')
            counts = [n for _, n in tips(app)]
            print('with print preview:', counts)
            check(sum(counts) - sum(n for _, n in main_tips) >= 1, 'print preview tooltips missing')
            app.click(preview, 2)
            app.closed(preview)
    finally:
        U.CloseDesktop(desktop)
    print('PASS: tooltips registered')


if __name__ == '__main__':
    main()
