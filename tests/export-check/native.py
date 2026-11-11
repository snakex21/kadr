"""Own-process native-control tests. No keyboard/mouse injection, no wallpaper SET.
Creates only generated copies under this directory. Requires installed Pillow.
"""
import ctypes as C
from ctypes import wintypes as W
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time
from PIL import Image

ROOT = Path(__file__).resolve().parent
U = C.WinDLL('user32', use_last_error=True)
G = C.WinDLL('gdi32', use_last_error=True)
ENUM = C.WINFUNCTYPE(W.BOOL, W.HWND, W.LPARAM)
U.EnumWindows.argtypes = [ENUM, W.LPARAM]
U.EnumChildWindows.argtypes = [W.HWND, ENUM, W.LPARAM]
U.GetWindowThreadProcessId.argtypes = [W.HWND, C.POINTER(W.DWORD)]
U.GetClassNameW.argtypes = [W.HWND, W.LPWSTR, C.c_int]
U.GetWindowTextW.argtypes = [W.HWND, W.LPWSTR, C.c_int]
U.GetDlgItem.argtypes = [W.HWND, C.c_int]
U.GetDlgItem.restype = W.HWND
U.GetDlgCtrlID.argtypes = [W.HWND]
U.GetParent.argtypes = [W.HWND]
U.GetParent.restype = W.HWND
U.SendMessageW.argtypes = [W.HWND, W.UINT, W.WPARAM, W.LPARAM]
U.SendMessageW.restype = W.LPARAM
U.PostMessageW.argtypes = [W.HWND, W.UINT, W.WPARAM, W.LPARAM]
U.SetWindowTextW.argtypes = [W.HWND, W.LPCWSTR]
U.IsWindowEnabled.argtypes = [W.HWND]
U.IsWindow.argtypes = [W.HWND]
U.IsWindowVisible.argtypes = [W.HWND]
U.GetWindowRect.argtypes = [W.HWND, C.POINTER(W.RECT)]
U.GetWindowDC.argtypes = [W.HWND]
U.GetWindowDC.restype = W.HDC
U.ReleaseDC.argtypes = [W.HWND, W.HDC]
U.PrintWindow.argtypes = [W.HWND, W.HDC, W.UINT]
G.CreateCompatibleDC.argtypes = [W.HDC]
G.CreateCompatibleDC.restype = W.HDC
G.CreateCompatibleBitmap.argtypes = [W.HDC, C.c_int, C.c_int]
G.CreateCompatibleBitmap.restype = W.HBITMAP
G.SelectObject.argtypes = [W.HDC, W.HGDIOBJ]
G.SelectObject.restype = W.HGDIOBJ
G.DeleteObject.argtypes = [W.HGDIOBJ]
G.DeleteDC.argtypes = [W.HDC]
G.GetDIBits.argtypes = [W.HDC, W.HBITMAP, W.UINT, W.UINT, W.LPVOID, W.LPVOID, W.UINT]


def wait(fn, label, timeout=12):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        value = fn()
        if value:
            return value
        time.sleep(.015)
    raise AssertionError('Timeout: ' + label)


def text(hwnd):
    b = C.create_unicode_buffer(4096)
    # WM_GETTEXT is system-marshalled across processes, unlike GetWindowTextW
    # (which returns only cached captions for another process's edit controls).
    U.SendMessageW(hwnd, 0xD, len(b), C.addressof(b))
    return b.value


def cls(hwnd):
    b = C.create_unicode_buffer(128)
    U.GetClassNameW(hwnd, b, len(b))
    return b.value


def windows(pid, parent=None):
    found = []
    @ENUM
    def visit(h, _):
        p = W.DWORD()
        U.GetWindowThreadProcessId(h, C.byref(p))
        if p.value == pid:
            found.append(h)
        return True
    if parent:
        U.EnumChildWindows(parent, visit, 0)
    else:
        U.EnumWindows(visit, 0)
    return found


def control(h, ident):
    return U.GetDlgItem(h, ident)


def post(h, ident):
    assert U.PostMessageW(h, 0x111, ident, 0)


def set_text(h, value):
    # SetWindowTextW on another process changes only its cached window caption.
    # Marshal WM_SETTEXT so the real Edit receives it and emits EN_CHANGE.
    b = C.create_unicode_buffer(value)
    assert h and U.SendMessageW(h, 0xC, 0, C.addressof(b))
    assert text(h) == value


def screenshot(h, name):
    r = W.RECT()
    assert U.GetWindowRect(h, C.byref(r))
    width, height = r.right-r.left, r.bottom-r.top
    screen = U.GetWindowDC(h)
    dc = G.CreateCompatibleDC(screen)
    bitmap = G.CreateCompatibleBitmap(screen, width, height)
    old = G.SelectObject(dc, bitmap)
    try:
        assert U.PrintWindow(h, dc, 0)
        G.SelectObject(dc, old)
        header = C.create_string_buffer(40)
        # BITMAPINFOHEADER: top-down 32-bit RGB.
        import struct
        struct.pack_into('<IiiHHIIiiII', header, 0, 40, width, -height, 1, 32, 0, width*height*4, 0, 0, 0, 0)
        pixels = C.create_string_buffer(width*height*4)
        assert G.GetDIBits(dc, bitmap, 0, height, pixels, header, 0) == height
        Image.frombuffer('RGB', (width, height), pixels.raw, 'raw', 'BGRX', 0, 1).save(ROOT / name)
    finally:
        G.SelectObject(dc, old)
        G.DeleteObject(bitmap)
        G.DeleteDC(dc)
        U.ReleaseDC(h, screen)


class Client:
    def __init__(self, number):
        self.folder = ROOT / 'generated' / str(number)
        self.folder.mkdir(parents=True, exist_ok=True)
        # Only delete this test's previously generated files, never fixtures.
        for p in self.folder.iterdir():
            assert p.is_file()
            p.unlink()
        self.source = self.folder / 'Zażółć gęślą — źródło.png'
        self.log = open(self.folder / 'test.log', 'wb')
        self.proc = subprocess.Popen([str(ROOT / 'dialog.exe'), str(self.source)], cwd=ROOT, stdout=self.log, stderr=self.log)
        self.h = wait(lambda: next((h for h in windows(self.proc.pid) if cls(h) == 'KadrExportCopyWindow' and U.IsWindowVisible(h)), None), 'export dialog')
        self.before = hashlib.sha256(self.source.read_bytes()).hexdigest()
    def common(self):
        return next((h for h in windows(self.proc.pid) if cls(h) == '#32770' and U.IsWindowVisible(h) and 'eksportuj nową kopię' in text(h)), None)
    def message(self):
        return next((h for h in windows(self.proc.pid) if cls(h) == '#32770' and 'zastąpienie' in text(h)), None)
    def filename(self, h):
        for edit in windows(self.proc.pid, h):
            if cls(edit).lower() != 'edit':
                continue
            ancestor = edit
            while ancestor and ancestor != h:
                if U.GetDlgCtrlID(ancestor) in (1148, 1152):
                    return edit
                ancestor = U.GetParent(ancestor)
        return None
    def save_dialog(self):
        post(self.h, 1)
        h = wait(self.common, 'XP Explorer save dialog')
        edit = wait(lambda: self.filename(h), 'filename edit')
        wait(lambda: text(edit), 'initialized default filename')
        return h, edit
    def submit(self, target):
        h, edit = self.save_dialog()
        set_text(edit, str(target))
        post(h, 1)
    def unchanged(self):
        assert hashlib.sha256(self.source.read_bytes()).hexdigest() == self.before
        assert not list(self.folder.glob('*.tmp'))
    def finish(self, saved):
        self.proc.wait(timeout=12)
        self.log.close()
        assert self.proc.returncode == 0
        log = (self.folder / 'test.log').read_text(errors='replace')
        assert 'saved=' + str(saved).lower() in log, log
        assert 'source=8x12, owner_enabled=1' in log, log
        self.unchanged()
    def cancel(self):
        post(self.h, 2)
        self.finish(False)
    def abort(self):
        if self.proc.poll() is None:
            self.proc.terminate()
            self.proc.wait(timeout=5)
        self.log.close()


results = []
clients = []
try:
    x = Client(1); clients.append(x)
    screenshot(x.h, 'export-dialog.png')
    assert text(control(x.h, 103)) == '8' and text(control(x.h, 104)) == '12', [(U.GetDlgCtrlID(h), cls(h), text(h)) for h in windows(x.proc.pid, x.h)]
    assert not U.IsWindowEnabled(control(x.h, 102))
    assert text(control(x.h, 102)) == '90'
    baseline = set(x.folder.iterdir())
    for invalid in ('0', '-1', '1.5', 'NaN', 'Inf', '4294967296', '9999999999999999999999999999999', '8000000'):
        set_text(control(x.h, 103), invalid)
        U.SendMessageW(x.h, 0x111, 1, 0)
        assert 'Podaj dodatnie' in text(control(x.h, 107)), invalid
        assert not x.common()
        assert set(x.folder.iterdir()) == baseline
    set_text(control(x.h, 103), '16')
    assert text(control(x.h, 104)) == '24'
    set_text(control(x.h, 104), '6')
    assert text(control(x.h, 103)) == '4'
    U.SendMessageW(control(x.h, 105), 0xF1, 0, 0)  # BM_SETCHECK unchecked
    set_text(control(x.h, 103), '10')
    set_text(control(x.h, 104), '7')
    assert text(control(x.h, 103)) == '10' and text(control(x.h, 104)) == '7'
    U.SendMessageW(control(x.h, 105), 0xF1, 1, 0)
    U.SendMessageW(x.h, 0x111, 105, 0)
    assert text(control(x.h, 104)) == '15'
    U.SendMessageW(control(x.h, 101), 0x14E, 1, 0)  # CB_SETCURSEL JPEG
    U.SendMessageW(x.h, 0x111, 101 | (1 << 16), 0)
    assert U.IsWindowEnabled(control(x.h, 102))
    set_text(control(x.h, 102), '101')
    U.SendMessageW(x.h, 0x111, 106, 0)
    assert 'Podaj dodatnie' in text(control(x.h, 107))
    U.SendMessageW(control(x.h, 101), 0x14E, 0, 0)
    U.SendMessageW(x.h, 0x111, 101 | (1 << 16), 0)
    assert not U.IsWindowEnabled(control(x.h, 102))
    # Disabled JPEG quality must not block a PNG export.
    set_text(control(x.h, 103), '16')
    U.SendMessageW(x.h, 0x111, 106, 0)
    status = text(control(x.h, 107))
    match = re.fullmatch(r'Rozmiar pliku: ([1-9]\d*) B', status)
    assert match, status
    measured = int(match.group(1))
    assert set(x.folder.iterdir()) == baseline
    x.unchanged()
    h, edit = x.save_dialog()
    assert Path(text(edit)).name == x.source.stem + '-export.png', text(edit)
    screenshot(h, 'save-dialog.png')
    post(h, 2)
    wait(lambda: not x.common(), 'cancel save dialog')
    assert U.IsWindow(x.h)
    x.cancel()
    results.append({'case': 'invalid inputs, aspect lock, JPEG enable, explicit size, native save cancellation, whole dialog cancellation', 'passed': True, 'measured_bytes': measured})

    x = Client(2); clients.append(x)
    set_text(control(x.h, 103), '16')
    U.SendMessageW(x.h, 0x111, 106, 0)
    match = re.fullmatch(r'Rozmiar pliku: ([1-9]\d*) B', text(control(x.h, 107)))
    assert match, text(control(x.h, 107))
    measured = int(match.group(1))
    target = x.folder / 'nowa kopia.png'
    x.submit(target)
    x.finish(True)
    assert target.stat().st_size == measured
    with Image.open(target) as image:
        assert image.size == (16, 24)
        assert image.convert('RGBA').getpixel((8, 2)) == (0, 0, 255, 128)
        assert image.convert('RGBA').getpixel((8, 21)) == (255, 0, 0, 255)
    results.append({'case': 'new PNG via native save dialog: alpha, baked rotation, aspect dimensions and exact measured bytes', 'passed': True, 'bytes': measured})

    x = Client(3); clients.append(x)
    x.submit(x.source)
    wait(lambda: 'Aby zmienić oryginał' in text(control(x.h, 107)), 'same source rejected')
    x.unchanged()
    target = x.folder / 'istniejąca.png'
    target.write_bytes(b'generated destination must remain intact after No')
    old = target.read_bytes()
    x.submit(target)
    confirm = wait(x.message, 'replace confirmation')
    assert U.SendMessageW(confirm, 0x400, 0, 0) & 0xffff == 7, 'replace must default No'
    post(confirm, 7)
    wait(lambda: not x.message(), 'replace No')
    assert target.read_bytes() == old
    x.submit(target)
    confirm = wait(x.message, 'replace confirmation again')
    post(confirm, 6)
    x.finish(True)
    with Image.open(target) as image:
        assert image.size == (8, 12)
    results.append({'case': 'source rejection; existing target default-No and explicit Yes', 'passed': True})

    x = Client(4); clients.append(x)
    set_text(control(x.h, 103), '4000')  # 24 MP; enough encoding time for a real race.
    assert text(control(x.h, 104)) == '6000'
    target = x.folder / 'race.png'
    x.submit(target)
    deadline = time.monotonic() + 15
    appeared = False
    while time.monotonic() < deadline:
        if list(x.folder.glob('*.tmp')):
            with target.open('xb') as f:
                f.write(b'created during encoding; must never be replaced')
            appeared = True
            break
        time.sleep(.001)
    assert appeared, 'could not observe reserved encode temp'
    wait(lambda: 'Nie zapisano kopii' in text(control(x.h, 107)), 'non-replacing commit rejected race', timeout=30)
    assert target.read_bytes() == b'created during encoding; must never be replaced'
    x.unchanged()
    x.cancel()
    results.append({'case': 'destination appeared during real 24 MP encoding: non-replacing commit and temp cleanup', 'passed': True})
finally:
    for x in clients:
        x.abort()
    (ROOT / 'native-results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({'native_groups_passed': len(results), 'results': results}, ensure_ascii=False, indent=2))
