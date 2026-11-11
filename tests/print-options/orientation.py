"""Real viewer auto-orientation checks. No Print/StartDoc or physical input."""
import argparse
import ctypes as C
import json
from pathlib import Path
import re
import shutil
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/features-check'))
import tools as helper
from PIL import Image

U, native = helper.U, helper.native


def selection(app, hwnd, ident):
    return U.SendMessageW(app.control(hwnd, ident), 0x147, 0, 0)


def select(app, hwnd, ident, index):
    control = app.control(hwnd, ident)
    U.SendMessageW(control, 0x14e, index, 0)
    U.SendMessageW(app.owned(hwnd), 0x111, ident | (1 << 16), control)


def dimensions(app, hwnd):
    text = helper.text(app.control(hwnd, 109))
    values = re.findall(r'[0-9]+(?:[.,][0-9]+)?', text)
    assert len(values) == 4, text
    return [float(v.replace(',', '.')) for v in values]


def capture(app, hwnd, target):
    app.noactivate(hwnd)
    native.capture(hwnd, target)
    with Image.open(target) as image:
        assert any(lo != hi for lo, hi in image.convert('RGB').getextrema()), 'black/constant capture'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--exe', type=Path, default=ROOT / 'tests/Kadr-auto-orientation.exe')
    args = parser.parse_args()
    source_exe = args.exe.resolve()
    assert source_exe.parent == ROOT / 'tests' and source_exe.is_file(), 'test EXE only'
    work = Path(tempfile.mkdtemp(prefix='kadr-auto-orientation-'))
    exe = work / 'Kadr-preview-owned.exe'
    shutil.copy2(source_exe, exe)
    (work / 'Kadr.ini').write_text('[General]\nLanguage=pl\n', encoding='ascii')
    photo = work / 'landscape.png'
    shutil.copy2(ROOT / 'tests/fixtures/01-krajobraz.png', photo)
    source_hash = helper.sha256(photo)
    results = {}
    with helper.App(exe, photo) as app:
        preview = app.open(109, 'Kadr.PrintPreview.1')
        native.wait(lambda: selection(app, preview, 101) == 1, 'landscape selected automatically')
        landscape = dimensions(app, preview)
        assert landscape[0] > landscape[1] and landscape[2] > landscape[3], landscape
        capture(app, preview, work / 'automatic-landscape.png')
        select(app, preview, 100, 1)  # A5, auto mode still active.
        assert selection(app, preview, 101) == 1
        assert dimensions(app, preview)[0] > dimensions(app, preview)[1]
        select(app, preview, 101, 0)  # Explicit portrait overrides auto.
        select(app, preview, 100, 0)  # Back to A4 must retain portrait.
        assert selection(app, preview, 101) == 0
        portrait = dimensions(app, preview)
        assert portrait[0] < portrait[1], portrait
        assert landscape[2] * landscape[3] > portrait[2] * portrait[3] * 1.5, (landscape, portrait)
        capture(app, preview, work / 'manual-portrait.png')
        app.click(preview, 2)
        app.closed(preview)
        app.ready((800, 500))
        results['landscape_and_manual'] = {'automatic_mm': landscape, 'manual_mm': portrait,
                                           'area_gain': landscape[2] * landscape[3] / (portrait[2] * portrait[3]),
                                           'paper_change_keeps_auto': True, 'manual_survives_paper_change': True}
        preview = app.open(109, 'Kadr.PrintPreview.1')
        native.wait(lambda: selection(app, preview, 101) == 1, 'new preview restores automatic choice')
        app.click(preview, 2)
        app.closed(preview)
        app.command(107)
        app.ready((500, 800))
        preview = app.open(109, 'Kadr.PrintPreview.1')
        native.wait(lambda: selection(app, preview, 101) == 0, 'rotated image automatically portrait')
        rotated = dimensions(app, preview)
        assert rotated[0] < rotated[1] and rotated[2] < rotated[3], rotated
        capture(app, preview, work / 'automatic-after-rotation.png')
        app.click(preview, 2)
        app.closed(preview)
        app.ready((500, 800))
        results['rotation_and_reopen'] = {'rotated_mm': rotated, 'auto_restored_on_reopen': True,
                                          'owner_restored': True}
    assert helper.sha256(photo) == source_hash
    results['safety'] = {'source_unchanged': True, 'no_Print_StartDoc_or_global_input': True}
    (work / 'results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(results, ensure_ascii=False, indent=2))
    print('PASS: real viewer automatic orientation/manual override/rotation; evidence:', work)


if __name__ == '__main__':
    main()
