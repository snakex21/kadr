"""Editor integration on generated copies, exclusively on an unshown private desktop.
No global input, clipboard, wallpaper, printer, production INI or production EXE writes.
"""
import argparse
import ast
import ctypes as C
from ctypes import wintypes as W
import json
from pathlib import Path
import re
import shutil
import sys
import tempfile
import time
import uuid
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/features-check'))
import run as native
import languages
from tools import App, check, text
from edge_cases import set_text, sha256
from save_delete import filename_edit, default_no
U, K, B = native.U, native.K, languages.backend
OUT = Path(__file__).resolve().parent


def click(app, h, ident):
    # Yes is permitted ONLY for saving our generated temporary source file.
    native.wait(lambda: U.GetDlgItem(app.owned(h), ident), 'button ready: ' + str(ident))
    native.click(app.owned(h), ident)


def editor(app):
    h = app.open(129, 'KadrEditorWindow')
    native.wait(lambda: text(app.control(h, 222)), 'editor initialized')
    check(not U.IsWindowEnabled(app.main), 'editor must disable owner')
    return h


def numbers(app, h):
    return tuple(int(text(app.control(h, i))) for i in range(220, 224))


def crop(app, h, values):
    for ident, value in zip(range(220, 224), values):
        set_text(app.control(h, ident), str(value))
    click(app, h, 205)


def slider(app, h, ident, value):
    U.SendMessageW(app.control(h, ident), 0x405, 1, 100 + value)  # TBM_SETPOS
    U.SendMessageW(app.owned(h), 0x114, 0, app.control(h, ident))
    time.sleep(.15)


def prompt(app, fragment='niezapisane'):
    return native.wait(lambda: app.find('#32770', fragment), 'owned prompt ' + fragment)


def guard(app):
    h = prompt(app)
    check(U.SendMessageW(h, 0x400, 0, 0) & 0xffff == 2, 'discard must default to Cancel')
    click(app, h, 2)
    app.closed(h)
    check(U.IsWindow(app.main), 'cancelled discard closed owner')


def save_copy(app, path):
    app.command(117)
    h = prompt(app, 'zapisz kopię')
    set_text(filename_edit(app, h), str(path))
    click(app, h, 1)
    app.closed(h)
    native.wait(path.exists, 'saved edited copy')
    # Wait for rename/flush rather than opening an in-progress temporary file.
    time.sleep(.15)


def drop(app, path):
    encoded = (str(path) + '\0\0').encode('utf-16-le')
    blob = (20).to_bytes(4, 'little') + bytes(12) + (1).to_bytes(4, 'little') + encoded
    memory = K.GlobalAlloc(0x42, len(blob))
    check(memory, 'drop allocation')
    pointer = K.GlobalLock(memory)
    C.memmove(pointer, blob, len(blob))
    K.GlobalUnlock(memory)
    check(U.PostMessageW(app.owned(app.main), 0x233, memory, 0), 'owned drop')
    # DragFinish in the receiver owns/frees this handle.


def expected_color(pixel, brightness=0, contrast=0, saturation=0, gray=False):
    r, g, b, *alpha = pixel
    factor = 1 + contrast * (.03 if contrast >= 0 else .01)
    rgb = [(v - 127.5) * factor + 127.5 + brightness * 2.55 for v in (r, g, b)]
    lum = rgb[0] * .299 + rgb[1] * .587 + rgb[2] * .114
    sat = 0 if gray else 1 + saturation * .01
    rgb = [max(0, min(255, int(lum + (v - lum) * sat + .5))) for v in rgb]
    return tuple(rgb + (alpha or [255]))


def pixels_match(path, expected, settings=None):
    with Image.open(path) as im:
        actual = im.convert('RGBA')
    expected = expected.convert('RGBA')
    check(actual.size == expected.size, ('dimensions', actual.size, expected.size))
    for index, (got, original) in enumerate(zip(actual.getdata(), expected.getdata())):
        want = expected_color(original, **settings) if settings else original
        check(all(abs(a-b) <= 1 for a, b in zip(got, want)), ('pixel', index, got, want))


def exercise(exe, source, master, desktop, name, results):
    baseline = sha256(source)
    following = source.parent / '02-next.png'
    master.save(following)
    with App(exe, source, desktop, name) as app:
        native.wait(lambda: text(app.control(app.main, 900)) == '1 / 2', 'folder ready')
        h = editor(app)
        check(numbers(app, h) == (0, 0, 800, 500), 'initial dimensions')
        click(app, h, 201)
        native.wait(lambda: numbers(app, h) == (0, 0, 500, 800), 'rotate left')
        slider(app, h, 210, 35)
        click(app, h, 207)
        click(app, h, 2)
        app.closed(h)
        app.ready((800, 500))
        check(sha256(source) == baseline, 'Cancel modified source')
        results.append('Cancel: raster, source hash and owner unchanged')

        h = editor(app)
        crop(app, h, (790, 0, 30, 10))
        native.wait(lambda: 'obszar' in text(app.control(h, 230)), 'invalid crop rejected')
        check(numbers(app, h) == (790, 0, 30, 10), 'invalid crop silently changed')
        click(app, h, 202)
        slider(app, h, 211, -30)
        click(app, h, 206)
        native.wait(lambda: numbers(app, h) == (0, 0, 800, 500), 'Reset geometry')
        for ident in (210, 211, 212):
            check(U.SendMessageW(app.control(h, ident), 0x400, 0, 0) == 100, 'Reset slider')
        check(U.SendMessageW(app.control(h, 207), 0xf0, 0, 0) == 0, 'Reset grayscale')
        click(app, h, 1)
        app.closed(h)
        app.ready((800, 500))
        results.append('Reset: original dimensions, all corrections neutral; invalid crop rejected')

        h = editor(app)
        # Exercise actual preview drag handlers, including release and clamping.
        preview = app.control(h, 200)
        def pos(x, y): return (y << 16) | x
        U.SendMessageW(preview, 0x201, 1, pos(60, 60))
        U.SendMessageW(preview, 0x200, 1, pos(300, 210))
        U.SendMessageW(preview, 0x202, 0, pos(300, 210))
        check(0 < numbers(app, h)[2] < 800, ('drag crop', numbers(app, h)))
        crop(app, h, (11, 7, 200, 100))
        native.wait(lambda: numbers(app, h) == (0, 0, 200, 100), 'exact crop')
        click(app, h, 201)
        native.wait(lambda: numbers(app, h) == (0, 0, 100, 200), 'left crop rotation')
        click(app, h, 203)
        click(app, h, 204)
        slider(app, h, 210, 20)
        slider(app, h, 211, 25)
        slider(app, h, 212, -40)
        click(app, h, 207)
        # Owned-window capture only; never capture the screen/user windows.
        time.sleep(.2)
        native.capture(h, OUT / 'editor-preview.png')
        click(app, h, 1)
        app.closed(h)
        app.ready((100, 200))
        check(sha256(source) == baseline, 'Apply modified original file')
        results.append('Apply: crop/rotate/flips/adjustments baked in memory; original file unchanged')
        expected = master.crop((11, 7, 211, 107)).transpose(Image.Transpose.ROTATE_90).transpose(Image.Transpose.FLIP_LEFT_RIGHT).transpose(Image.Transpose.FLIP_TOP_BOTTOM)
        settings = dict(brightness=20, contrast=25, saturation=-40, gray=True)
        copy = source.parent / 'edited-copy.png'
        save_copy(app, copy)
        pixels_match(copy, expected, settings)
        check(sha256(source) == baseline, 'Save As modified original')
        results.append('Save As: all pixels match crop/transform/color reference; source unchanged')

        U.PostMessageW(app.main, native.WM_CLOSE, 0, 0)
        guard(app)
        app.command(102)
        guard(app)
        drop(app, following)
        guard(app)
        app.command(100)
        h = prompt(app, 'otwórz')
        set_text(filename_edit(app, h), str(following))
        click(app, h, 1)
        app.closed(h)
        guard(app)
        app.ready((100, 200))
        results.append('Unsaved guards: Close, Next, Drop and Open default to Cancel and preserve edits')
        app.command(118)
        h = prompt(app, 'zapisz zmiany')
        default_no(h)
        click(app, h, 6)  # only this generated tempfile source
        app.closed(h)
        app.ready((100, 200))
        native.wait(lambda: sha256(source) != baseline, 'in-place commit')
        pixels_match(source, expected, settings)
        app.command(118)
        native.wait(lambda: 'Brak zmian' in text(app.control(app.main, 904)), 'dirty state cleared')
        check(not app.find('#32770'), 'unchanged save prompts')
        results.append('Save: editor-only changes (rotations==0) save in place; No default; dirty clears')


def animation(exe, folder, desktop, name, results):
    source = folder / 'animated.gif'
    frames = [Image.new('RGB', (800, 500), color) for color in ('red', 'blue')]
    frames[0].save(source, save_all=True, append_images=frames[1:], duration=100, loop=0)
    before = sha256(source)
    with App(exe, source, desktop, name) as app:
        app.command(129)
        h = prompt(app, 'edycja')
        click(app, h, 1)
        h = native.wait(lambda: app.find('KadrEditorWindow'), 'animation editor')
        native.wait(lambda: text(app.control(h, 222)), 'animation controls ready')
        click(app, h, 203)
        click(app, h, 1)
        app.closed(h)
        app.command(118)
        h = prompt(app, 'Kadr')
        check('nie może być nadpisany' in ''.join(text(x) for x in native.windows(app.pid, h)), 'flattened animation overwrite protection')
        U.PostMessageW(app.owned(h), native.WM_CLOSE, 0, 0)
        app.closed(h)
        check(sha256(source) == before, 'animated source modified')
        with Image.open(source) as im: check(im.n_frames == 2, 'lost animation frames')
        U.PostMessageW(app.main, native.WM_CLOSE, 0, 0)
        h = prompt(app)
        click(app, h, 1)  # discard memory only, source remains untouched
    results.append('Animation: current frame edit warns; flattened result cannot overwrite original GIF')


def colors(exe, folder, master, desktop, name, results):
    source = folder / 'colors.png'
    master.save(source)
    before = sha256(source)
    with App(exe, source, desktop, name) as app:
        h = editor(app)
        crop(app, h, (20, 20, 64, 32))
        native.wait(lambda: numbers(app, h) == (0, 0, 64, 32), 'color crop')
        click(app, h, 202)
        native.wait(lambda: numbers(app, h) == (0, 0, 32, 64), 'right rotation')
        slider(app, h, 210, -15)
        slider(app, h, 211, -20)
        slider(app, h, 212, 75)
        click(app, h, 1)
        app.closed(h)
        target = folder / 'colors-result.png'
        save_copy(app, target)
        expected = master.crop((20, 20, 84, 52)).transpose(Image.Transpose.ROTATE_270)
        pixels_match(target, expected, dict(brightness=-15, contrast=-20, saturation=75))
        check(sha256(source) == before, 'color source changed')
        export = app.open(126, 'KadrExportCopyWindow')
        native.wait(lambda: text(app.control(export, 103)) == '32', 'edited export dimensions')
        check(text(app.control(export, 104)) == '64', 'edited export height')
        set_text(app.control(export, 103), '16')
        native.wait(lambda: text(app.control(export, 104)) == '32', 'edited export aspect lock')
        click(app, export, 106)
        native.wait(lambda: ' B' in text(app.control(export, 107)), 'edited export size measured')
        measured = int(re.search(r'([0-9]+) B', text(app.control(export, 107))).group(1))
        destination = folder / 'edited-export.png'
        click(app, export, 1)
        save = prompt(app, 'eksportuj nową kopię')
        set_text(filename_edit(app, save), str(destination))
        click(app, save, 1)
        app.closed(save)
        app.closed(export)
        native.wait(destination.exists, 'edited export exists')
        with Image.open(destination) as im: check(im.size == (16, 32), 'edited export raster size')
        check(destination.stat().st_size == measured, 'edited export measured bytes')
        check(sha256(source) == before, 'edited export changed source')
        results.append('Export: edited pixels/dimensions, aspect lock, size measurement and new PNG verified')
        U.PostMessageW(app.main, native.WM_CLOSE, 0, 0)
        h = prompt(app)
        click(app, h, 1)
    results.append('Color: right rotation, negative brightness/contrast and positive saturation match every pixel')


def visual(exe, source):
    # This separate owned window is non-activating, never a user window.
    with App(exe, source) as app:
        h = editor(app)
        app.noactivate(h)
        time.sleep(.2)
        native.capture(h, OUT / 'editor-visual.png')
        native.capture(app.main, OUT / 'main-visual.png')
        with Image.open(OUT / 'editor-visual.png') as im:
            check(any(lo != hi for lo, hi in im.convert('RGB').getextrema()), 'constant visual capture')
        click(app, h, 2)
        app.closed(h)
        preview = app.open(109, 'Kadr.PrintPreview.1')
        app.noactivate(preview)
        time.sleep(.2)
        native.capture(preview, OUT / 'print-visual.png')
        app.click(preview, 2)
        app.closed(preview)
    print('PASS: owned-window visual captures, no printing/global input')


def all_languages(exe, image, desktop, name, results):
    data = (ROOT / 'src/locale_editor.zig').read_text(encoding='utf-8')
    packs = [[ast.literal_eval(m.group(0)) for m in re.finditer(r'"(?:\\.|[^"\\])*"', row)] for row in re.findall(r'^    \.\{ (.*?) \},$', data, re.M)]
    check(len(packs) == 30, 'editor language table')
    for index, code in enumerate(languages.CODES):
        (exe.parent / 'Kadr.ini').write_text('[General]\nLanguage=' + code + '\n', encoding='ascii')
        with App(exe, image, desktop, name) as app:
            h = editor(app)
            check(text(h).lower() == ('Kadr — ' + packs[index][0]).lower(), (code, 'caption', text(h)))
            # Labels and info text, not just catalog existence.
            values = [text(x) for x in native.windows(app.pid, h)]
            for value in packs[index][:9]:
                check(value in values or value == packs[index][0] and value in values, (code, 'missing text', value))
            click(app, h, 2)
            app.closed(h)
    results.append('30 languages: editor caption, labels, corrections and hints verified in native windows')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--exe', type=Path, default=ROOT / 'tests/Kadr-editor.exe')
    parser.add_argument('--languages', action='store_true')
    parser.add_argument('--visual', action='store_true')
    args = parser.parse_args()
    work = Path(tempfile.mkdtemp(prefix='kadr-editor-'))
    binary = work / 'bin'
    binary.mkdir()
    exe = binary / 'Kadr.exe'
    shutil.copy2(args.exe.resolve(), exe)
    # Optional codecs stay beside this private portable EXE.
    shutil.copytree(ROOT / 'deps', binary / 'deps')
    (binary / 'Kadr.ini').write_text('[General]\nLanguage=pl\n', encoding='ascii')
    pictures = work / 'pictures'
    pictures.mkdir()
    source = pictures / '01-source.png'
    master = Image.new('RGBA', (800, 500))
    draw = ImageDraw.Draw(master)
    for x in range(800): draw.line((x, 0, x, 499), fill=(x % 256, (x*3) % 256, (x*7) % 256, 255))
    draw.rectangle((0, 0, 39, 29), fill=(230, 20, 80, 255))
    master.save(source)
    if args.visual:
        visual(exe, source)
        return
    name = 'KadrEditor-' + uuid.uuid4().hex
    desktop = U.CreateDesktopW(name, None, None, 0, 0x1ff, None)
    check(desktop, 'private desktop')
    results = []
    try:
        exercise(exe, source, master, desktop, name, results)
        animation(exe, pictures, desktop, name, results)
        colors(exe, pictures, master, desktop, name, results)
        if args.languages:
            original = pictures / 'language.png'
            master.save(original)
            all_languages(exe, original, desktop, name, results)
    finally:
        U.CloseDesktop(desktop)
        evidence = {'results': results, 'work': str(work), 'production_untouched': True}
        (OUT / 'results.json').write_text(json.dumps(evidence, indent=2, ensure_ascii=False), encoding='utf-8')
        print(json.dumps(evidence, indent=2, ensure_ascii=False))
    print('PASS: native editor, saves, guards; private desktop only')

if __name__ == '__main__':
    main()
