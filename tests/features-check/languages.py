"""Exercise all 30 languages in the real viewer on an unshown private desktop."""
import argparse
import ast
import ctypes as C
from ctypes import wintypes as W
import importlib.util
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
import uuid
import run as native

ROOT = native.ROOT
spec = importlib.util.spec_from_file_location('i18n_native', ROOT / 'tests/i18n-check/run.py')
backend = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backend)
U, K = backend.U, backend.K
CODES = backend.CODES
CALLBACK = C.WINFUNCTYPE(W.BOOL, W.HWND, W.LPARAM)
U.SendMessageW.argtypes = [W.HWND, W.UINT, W.WPARAM, W.LPARAM]
U.SendMessageW.restype = W.LPARAM


def text(hwnd):
    buffer = C.create_unicode_buffer(4096)
    U.SendMessageW(hwnd, 0xD, len(buffer), C.cast(buffer, C.c_void_p).value)
    return buffer.value


def windows(desktop, pid):
    result = []
    def each(hwnd, _):
        owner = W.DWORD()
        U.GetWindowThreadProcessId(hwnd, C.byref(owner))
        if owner.value == pid and U.IsWindowVisible(hwnd):
            result.append(hwnd)
        return True
    callback = CALLBACK(each)
    # An empty newly created desktop can return zero before the first window.
    U.EnumDesktopWindows(desktop, callback, 0)
    return result


class App:
    def __init__(self, exe, image, cwd, desktop, desktop_name):
        self.desktop, self.hwnd = desktop, None
        startup = backend.STARTUPINFO()
        startup.cb = C.sizeof(startup)
        startup.lpDesktop = 'winsta0\\' + desktop_name
        process = backend.PROCESS_INFORMATION()
        command = C.create_unicode_buffer(subprocess.list2cmdline([str(exe), str(image)]))
        assert K.CreateProcessW(str(exe), command, None, None, False, 0, None, str(cwd), C.byref(startup), C.byref(process)), C.WinError()
        self.process, self.pid = process.hProcess, process.dwProcessId
        K.CloseHandle(process.hThread)
        try:
            self.hwnd = native.wait(lambda: next((h for h in windows(desktop, self.pid) if native.cls(h) == 'Kadr.Main'), None), 'main on private desktop')
            native.wait(lambda: image.name in text(self.hwnd), 'image loaded')
        except BaseException:
            self.close()
            raise

    def close(self):
        for h in windows(self.desktop, self.pid):
            if native.cls(h) == '#32770':
                U.PostMessageW(h, 0x10, 0, 0)
        if self.hwnd:
            U.PostMessageW(self.hwnd, 0x10, 0, 0)
        if K.WaitForSingleObject(self.process, 5000) != 0:
            K.TerminateProcess(self.process, 98)
            K.WaitForSingleObject(self.process, 5000)
        K.CloseHandle(self.process)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--exe', type=Path, default=ROOT / 'tests/Kadr-integrated.exe')
    args = parser.parse_args()
    source = args.exe.resolve()
    assert source.is_file()
    work = Path(tempfile.mkdtemp(prefix='kadr-languages-main-'))
    cwd = work / 'unrelated-cwd'
    cwd.mkdir()
    decoy = cwd / 'Kadr.ini'
    decoy.write_bytes(b'[General]\r\nLanguage=xx\r\n')
    original_decoy = decoy.read_bytes()
    image = work / 'image.png'
    shutil.copy2(ROOT / 'tests/fixtures/01-krajobraz.png', image)
    data = (ROOT / 'src/locale_words.zig').read_text(encoding='utf-8')
    def groups(name):
        return [[ast.literal_eval(m.group(0)) for m in re.finditer(r'"(?:\\.|[^"\\])*"', group)] for group in re.findall(r'\.' + name + r' = \.\{(.*?)\},', data, re.S)]
    files, views = groups('f'), groups('v')
    assert len(files) == len(views) == 30
    desktop_name = 'KadrLanguageTest-' + uuid.uuid4().hex
    desktop = U.CreateDesktopW(desktop_name, None, None, 0, 0x01ff, None)
    assert desktop, C.WinError()
    try:
        for index, code in enumerate(CODES):
            folder = work / code
            folder.mkdir()
            exe = folder / 'Kadr.exe'
            shutil.copy2(source, exe)
            ini = folder / 'Kadr.ini'
            ini.write_text('[General]\nLanguage=' + code + '\n', encoding='ascii')
            app = App(exe, image, cwd, desktop, desktop_name)
            try:
                assert text(U.GetDlgItem(app.hwnd, 100)) == files[index][0], (code, 'Open')
                assert text(U.GetDlgItem(app.hwnd, 118)) == files[index][1], (code, 'Save')
                assert text(U.GetDlgItem(app.hwnd, 109)) == files[index][9], (code, 'Print')
                assert text(U.GetDlgItem(app.hwnd, 123)) == views[index][11], (code, 'More')
                if code == 'en':
                    U.PostMessageW(app.hwnd, 0x111, 125, 0)
                    selector = native.wait(lambda: next((h for h in windows(desktop, app.pid) if native.cls(h) == '#32770' and U.GetDlgItem(h, 100)), None), 'language selector in real viewer')
                    listing = U.GetDlgItem(selector, 100)
                    assert U.SendMessageW(listing, 0x18b, 0, 0) == 30  # LB_GETCOUNT
                    U.SendMessageW(listing, 0x186, 21, 0)  # Japanese
                    U.PostMessageW(U.GetDlgItem(selector, 1), 0xf5, 0, 0)
                    message = native.wait(lambda: next((h for h in windows(desktop, app.pid) if native.cls(h) == '#32770' and h != selector), None), 'restart notification')
                    U.PostMessageW(message, 0x10, 0, 0)
                    native.wait(lambda: not U.IsWindow(selector), 'selector closes')
                    assert 'Language=ja' in ini.read_text(encoding='ascii')
                    assert text(U.GetDlgItem(app.hwnd, 100)) == files[index][0], 'language changed before restart'
            finally:
                app.close()
            if code == 'en':
                restarted = App(exe, image, cwd, desktop, desktop_name)
                try:
                    assert text(U.GetDlgItem(restarted.hwnd, 100)) == files[21][0]
                finally:
                    restarted.close()
            print('PASS:', code)
        assert decoy.read_bytes() == original_decoy
    finally:
        U.CloseDesktop(desktop)
    print('PASS: real viewer 30 languages, selector/restart, unrelated CWD untouched (visual rendering checked separately);', work)


if __name__ == '__main__':
    main()
