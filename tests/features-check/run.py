"""Exercise native Kadr commands on disposable copies, never fixture originals.
Run from any directory: python tests/features-check/run.py [--save-only] [--exe PATH]
"""
import argparse
import ctypes as C
from ctypes import wintypes as W
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import time
import uuid
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
U, K = C.windll.user32, C.windll.kernel32
U.SendMessageW.argtypes = [W.HWND, W.UINT, W.WPARAM, W.LPARAM]
U.SendMessageW.restype = W.LPARAM
U.PostMessageW.argtypes = [W.HWND, W.UINT, W.WPARAM, W.LPARAM]
U.GetDlgItem.argtypes = [W.HWND, C.c_int]
U.GetDlgItem.restype = W.HWND
U.GetWindow.argtypes = [W.HWND, W.UINT]
U.GetWindow.restype = W.HWND
U.GetParent.argtypes = [W.HWND]
U.GetParent.restype = W.HWND
U.GetClipboardData.argtypes = [W.UINT]
U.GetClipboardData.restype = W.HANDLE
K.GlobalLock.argtypes = [W.HGLOBAL]
K.GlobalLock.restype = C.c_void_p
K.GlobalUnlock.argtypes = [W.HGLOBAL]
K.GlobalSize.argtypes = [W.HGLOBAL]
K.GlobalSize.restype = C.c_size_t
U.GetDC.argtypes = [W.HWND]
U.GetDC.restype = W.HDC
U.ReleaseDC.argtypes = [W.HWND, W.HDC]
U.PrintWindow.argtypes = [W.HWND, W.HDC, W.UINT]
CALLBACK = C.WINFUNCTYPE(W.BOOL, W.HWND, W.LPARAM)
WM_COMMAND, WM_CLOSE, BM_CLICK = 0x111, 0x10, 0xF5
results = {}


def title(hwnd):
    buf = C.create_unicode_buffer(32768)
    U.GetWindowTextW(hwnd, buf, len(buf))
    return buf.value


def cls(hwnd):
    buf = C.create_unicode_buffer(256)
    U.GetClassNameW(hwnd, buf, len(buf))
    return buf.value


def windows(pid=None, parent=None, visible=True):
    found = []
    def each(hwnd, _):
        owner = W.DWORD()
        U.GetWindowThreadProcessId(hwnd, C.byref(owner))
        if (pid is None or owner.value == pid) and (not visible or U.IsWindowVisible(hwnd)):
            found.append(hwnd)
        return True
    cb = CALLBACK(each)
    if parent is None:
        U.EnumWindows(cb, 0)
    else:
        U.EnumChildWindows(parent, cb, 0)
    return found


def wait(test, why, timeout=12):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        value = test()
        if value:
            return value
        time.sleep(.05)
    raise AssertionError('timeout: ' + why)


def send_command(main, ident):
    assert U.PostMessageW(main, WM_COMMAND, ident, 0)


def dialog(pid, contains=None):
    return next((h for h in windows(pid) if cls(h) == '#32770' and (contains is None or contains in title(h))), None)


def click(hwnd, ident):
    button = U.GetDlgItem(hwnd, ident)
    assert button, (title(hwnd), ident)
    U.PostMessageW(button, BM_CLICK, 0, 0)


def save_dialog(pid, destination):
    h = wait(lambda: dialog(pid, 'zapisz kopię'), 'save file dialog')
    # CDM_* messages are above WM_USER: their pointer arguments are NOT
    # marshalled between this Python process and the application's process.
    # Use the filename Edit instead; Explorer dialogs put it under cmb13
    # (1148), while older dialogs use edt1 (1152). GetWindowText cannot read
    # another process's Edit contents, but WM_GETTEXT/WM_SETTEXT can.
    def filename_edit():
        for edit in windows(pid, h):
            if cls(edit) != 'Edit':
                continue
            ancestor = edit
            while ancestor and ancestor != h:
                if U.GetDlgCtrlID(ancestor) in (1148, 1152):
                    return edit
                ancestor = U.GetParent(ancestor)
        return None

    edit = wait(filename_edit, 'native filename Edit (cmb13/edt1)')
    filename = C.create_unicode_buffer(str(destination))
    assert U.SendMessageW(edit, 0xC, 0, C.cast(filename, C.c_void_p).value), 'WM_SETTEXT failed'
    value = C.create_unicode_buffer(32768)
    U.SendMessageW(edit, 0xD, len(value), C.cast(value, C.c_void_p).value)
    assert str(destination) == value.value, ('native filename Edit', value.value)
    click(h, 1)
    wait(lambda: not U.IsWindow(h), 'save dialog closes')
    try:
        wait(destination.exists, 'saved image exists')
    except AssertionError:
        print('SAVE DIAGNOSTICS', [(title(d), [(cls(x), U.GetDlgCtrlID(x), title(x)) for x in windows(pid, d)]) for d in windows(pid) if cls(d) == '#32770'])
        print('DESTINATION DIRECTORY', [p.name for p in destination.parent.iterdir()])
        print('PROCESS WINDOWS', [(cls(x), title(x), [(U.GetDlgCtrlID(y), title(y)) for y in windows(pid, x) if U.GetDlgCtrlID(y) == 904]) for x in windows(pid)])
        raise


def clipboard_dib():
    wait(lambda: U.OpenClipboard(None), 'OpenClipboard')
    try:
        h = U.GetClipboardData(8)
        assert h, 'CF_DIB missing'
        p = K.GlobalLock(h)
        assert p
        try:
            blob = C.string_at(p, K.GlobalSize(h))
        finally:
            K.GlobalUnlock(h)
        size, width, height, planes, bits = struct.unpack_from('<IiiHH', blob)
        assert size >= 40 and planes == 1 and bits in (24, 32)
        return width, abs(height), bits
    finally:
        U.CloseClipboard()


def image_pixels(path, expected):
    with Image.open(path) as im:
        im.load()
        assert im.size == expected.size, (im.size, expected.size)
        assert im.convert('RGB').tobytes() == expected.convert('RGB').tobytes(), 'orientation/pixels differ'
        return im.size


def capture(hwnd, destination):
    g = C.windll.gdi32
    g.CreateCompatibleDC.argtypes = [W.HDC]
    g.CreateCompatibleDC.restype = W.HDC
    g.CreateCompatibleBitmap.argtypes = [W.HDC, C.c_int, C.c_int]
    g.CreateCompatibleBitmap.restype = W.HBITMAP
    g.SelectObject.argtypes = [W.HDC, W.HGDIOBJ]
    g.SelectObject.restype = W.HGDIOBJ
    g.GetDIBits.argtypes = [W.HDC, W.HBITMAP, W.UINT, W.UINT, C.c_void_p, C.c_void_p, W.UINT]
    g.DeleteObject.argtypes = [W.HGDIOBJ]
    g.DeleteDC.argtypes = [W.HDC]
    rect = W.RECT()
    U.GetWindowRect(hwnd, C.byref(rect))
    width, height = rect.right - rect.left, rect.bottom - rect.top
    dc = U.GetDC(hwnd)
    mem = g.CreateCompatibleDC(dc)
    bitmap = g.CreateCompatibleBitmap(dc, width, height)
    old = g.SelectObject(mem, bitmap)
    try:
        assert U.PrintWindow(hwnd, mem, 0)
        g.SelectObject(mem, old)
        info = C.create_string_buffer(struct.pack('<IiiHHIIiiII', 40, width, -height, 1, 32, 0, width * height * 4, 0, 0, 0, 0))
        pixels = C.create_string_buffer(width * height * 4)
        assert g.GetDIBits(mem, bitmap, 0, height, pixels, info, 0) == height
        Image.frombytes('RGB', (width, height), pixels.raw, 'raw', 'BGRX').save(destination)
    finally:
        g.SelectObject(mem, old)
        g.DeleteObject(bitmap)
        g.DeleteDC(mem)
        U.ReleaseDC(hwnd, dc)


def run():
    parser = argparse.ArgumentParser()
    parser.add_argument('--save-only', action='store_true')
    parser.add_argument('--exe', type=Path, default=ROOT / 'Kadr.exe')
    args = parser.parse_args()
    unique = 'kadr-' + uuid.uuid4().hex[:8]
    work = Path(tempfile.mkdtemp(prefix=unique + '-'))
    source = work / (unique + '-01.png')
    next_file = work / (unique + '-02.jpg')
    shutil.copy2(ROOT / 'tests/fixtures/01-krajobraz.png', source)
    shutil.copy2(ROOT / 'tests/fixtures/02-zdjecie.jpg', next_file)
    fixture_hash = hashlib.sha256((ROOT / 'tests/fixtures/01-krajobraz.png').read_bytes()).hexdigest()
    source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
    with Image.open(source) as im:
        expected = im.transpose(Image.Transpose.ROTATE_270).copy()
    proc = subprocess.Popen([str(args.exe.resolve()), str(source)], cwd=ROOT)
    main = None
    try:
        main = wait(lambda: next((h for h in windows(proc.pid) if cls(h) == 'Kadr.Main'), None), 'main window of test process')
        wait(lambda: source.name in title(main), 'image loaded')
        time.sleep(.6)
        send_command(main, 107)
        time.sleep(.2)
        send_command(main, 119)
        time.sleep(.2)
        dib = clipboard_dib()
        assert dib[:2] == expected.size, dib
        results['clipboard'] = {'size': dib[:2], 'bits': dib[2]}
        exported = work / (unique + '-export.png')
        send_command(main, 117)
        save_dialog(proc.pid, exported)
        image_pixels(exported, expected)
        assert hashlib.sha256(source.read_bytes()).hexdigest() == source_hash, 'Save As modified original'
        results['save_as'] = 'PASS: rotated pixels; source unchanged'
        send_command(main, 118)
        confirm = wait(lambda: dialog(proc.pid, 'zapisz obrót'), 'rotation overwrite confirmation')
        click(confirm, 6)
        wait(lambda: not U.IsWindow(confirm), 'overwrite confirmation closes')
        def saved_rotation():
            try:
                with Image.open(source) as im:
                    return im.size == expected.size
            except (PermissionError, OSError):
                return False
        wait(saved_rotation, 'rotated original saved')
        image_pixels(source, expected)
        time.sleep(.6)
        results['save_rotation'] = 'PASS: rotated dimensions and exact PNG pixels'
        if not args.save_only:
            send_command(main, 120)
            rename = wait(lambda: dialog(proc.pid, 'zmień nazwę'), 'rename dialog')
            edit = U.GetDlgItem(rename, 2001)
            assert edit
            renamed = work / (unique + '-renamed.png')
            value = C.create_unicode_buffer(renamed.name)
            assert U.SendMessageW(edit, 0xC, 0, C.cast(value, C.c_void_p).value)
            click(rename, 1)
            wait(renamed.exists, 'renamed file exists')
            wait(lambda: renamed.name in title(main), 'renamed title')
            assert not source.exists()
            image_pixels(renamed, expected)
            results['rename'] = 'PASS: disk file, title, image pixels'
            send_command(main, 122)
            folder_window = wait(lambda: next((h for h in windows() if cls(h) == 'CabinetWClass' and work.name in title(h)), None), 'Explorer selected-file folder window', 20)
            results['folder'] = 'PASS: Explorer shows ' + title(folder_window)
            U.PostMessageW(folder_window, WM_CLOSE, 0, 0)
            time.sleep(.2)
            candidates = sorted([p for p in work.iterdir() if p.suffix in ('.png', '.jpg')], key=lambda p: str(p).lower())
            index = candidates.index(renamed)
            following = candidates[index + 1] if index + 1 < len(candidates) else candidates[index - 1]
            send_command(main, 121)
            confirm = wait(lambda: dialog(proc.pid, 'Kosza'), 'cancel recycle confirmation')
            click(confirm, 7)  # No must leave the file untouched.
            wait(lambda: not U.IsWindow(confirm), 'cancel recycle closes')
            assert renamed.exists()
            send_command(main, 121)
            confirm = wait(lambda: dialog(proc.pid, 'Kosza'), 'recycle confirmation')
            click(confirm, 6)
            wait(lambda: not renamed.exists(), 'file moved out of folder')
            wait(lambda: following.name in title(main), 'expected next/previous image shown')
            assert 'Kadr' in title(main) and not title(main).startswith('Kadr —'), title(main)
            # Shell API recycling can be disabled by system settings. Confirm actual contents.
            ps = "$n='" + renamed.name + "'; $items=(New-Object -ComObject Shell.Application).NameSpace(10).Items(); @($items | Where-Object { $_.Name -eq $n -or $_.Name -eq [IO.Path]::GetFileNameWithoutExtension($n) }).Count"
            count = subprocess.check_output(['powershell', '-NoProfile', '-Command', ps], text=True).strip()
            assert int(count) >= 1, 'file not found in Windows Recycle Bin: ' + count
            results['recycle'] = 'PASS: file in Recycle Bin; navigated to ' + title(main)
            capture(main, OUT / 'toolbar.png')
            # Smallest supported outer size; check controls for overlap.
            U.SetWindowPos(main, None, 0, 0, 800, 620, 0x16)
            time.sleep(.3)
            controls = [U.GetDlgItem(main, x) for x in [100, 101, 102, 103, 104, 105, 901, 116, 106, 107, 118, 109, 108, 114, 110, 123]]
            boxes = []
            for h in controls:
                assert h and U.IsWindowVisible(h), 'missing compact toolbar control'
                r = W.RECT()
                U.GetWindowRect(h, C.byref(r))
                boxes.append((r.left, r.top, r.right, r.bottom))
            for a, b in zip(boxes, boxes[1:]):
                assert a[2] <= b[0], ('toolbar overlap', a, b)
            capture(main, OUT / 'toolbar-800.png')
            results['toolbar'] = 'PASS: no overlap at 800px; screenshots saved'
        assert hashlib.sha256((ROOT / 'tests/fixtures/01-krajobraz.png').read_bytes()).hexdigest() == fixture_hash
        results['fixtures'] = 'PASS: fixture original unchanged'
        results['work'] = str(work)
        print(json.dumps(results, ensure_ascii=False, indent=2))
        (OUT / 'result.json').write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
    finally:
        if main and U.IsWindow(main):
            # Close only windows owned by the test process, never pre-existing Kadr windows.
            for h in windows(proc.pid):
                if cls(h) == '#32770':
                    U.PostMessageW(h, WM_CLOSE, 0, 0)
            U.PostMessageW(main, WM_CLOSE, 0, 0)
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=5)


if __name__ == '__main__':
    run()
