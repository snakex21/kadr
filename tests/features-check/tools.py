"""Native integrated-tool regressions; only a portable tempfile EXE is launched.

From src: python -B ../tests/features-check/tools.py --exe ../tests/Kadr-integrated.exe
No builds, production EXE/INI writes, global input, wallpaper changes or printing.
Assertions use an unshown private desktop. Optional screenshots use another owned
process with no-activate startup/window positioning; black captures are not passes.
All inputs, outputs, diagnostics and screenshots are retained in the printed folder.
"""
import argparse
import ctypes as C
from ctypes import wintypes as W
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import traceback
from types import SimpleNamespace
import uuid

from PIL import Image
import run as native
from edge_cases import set_text, sha256, text
from save_delete import default_no, filename_edit
import languages

ROOT = native.ROOT
U, K = native.U, native.K
B = languages.backend
U.GetClipboardOwner.restype = W.HWND
U.OpenClipboard.argtypes = [W.HWND]
U.SetClipboardData.argtypes = [W.UINT, W.HANDLE]
U.SetClipboardData.restype = W.HANDLE
U.GetClipboardSequenceNumber.restype = W.DWORD
K.GlobalAlloc.argtypes = [W.UINT, C.c_size_t]
K.GlobalAlloc.restype = W.HGLOBAL
K.GlobalFree.argtypes = [W.HGLOBAL]
K.GlobalFree.restype = W.HGLOBAL
U.SystemParametersInfoW.argtypes = [W.UINT, W.UINT, C.c_void_p, W.UINT]
U.SystemParametersInfoW.restype = W.BOOL
U.GetWindowLongW.argtypes = [W.HWND, C.c_int]
U.GetWindowLongW.restype = W.LONG
U.SetWindowLongW.argtypes = [W.HWND, C.c_int, W.LONG]
U.SetWindowLongW.restype = W.LONG
U.SetWindowPos.argtypes = [W.HWND, W.HWND, C.c_int, C.c_int, C.c_int, C.c_int, W.UINT]


def check(value, why):
    if not value:
        raise AssertionError(why)
    return value


def wallpaper_path():
    # Read only. This test never calls SPI_SETDESKWALLPAPER.
    buffer = C.create_unicode_buffer(32768)
    check(U.SystemParametersInfoW(0x73, len(buffer), buffer, 0), 'SPI_GETDESKWALLPAPER')
    return buffer.value


def files(folder):
    return {p.name: {'bytes': p.stat().st_size, 'sha256': sha256(p)}
            for p in sorted(folder.iterdir()) if p.is_file()}


class App:
    """Create/close only our copied executable; enumerate by desktop AND PID."""
    def __init__(self, exe, source, desktop=None, desktop_name=None):
        self.exe, self.source = exe, source
        self.desktop, self.desktop_name = desktop, desktop_name
        self.main = self.process = None

    def __enter__(self):
        info = B.STARTUPINFO()
        info.cb = C.sizeof(info)
        if self.desktop:
            info.lpDesktop = 'winsta0\\' + self.desktop_name
        info.dwFlags, info.wShowWindow = 1, 4  # STARTF_USESHOWWINDOW, SW_SHOWNOACTIVATE
        proc = B.PROCESS_INFORMATION()
        command = C.create_unicode_buffer(subprocess.list2cmdline([str(self.exe), str(self.source)]))
        check(K.CreateProcessW(str(self.exe), command, None, None, False, 0, None,
                               str(self.exe.parent), C.byref(info), C.byref(proc)), 'CreateProcessW')
        self.process, self.pid = proc.hProcess, proc.dwProcessId
        self.proc = SimpleNamespace(pid=self.pid)  # filename_edit's narrow contract
        K.CloseHandle(proc.hThread)
        try:
            self.main = native.wait(lambda: self.find('Kadr.Main'), 'owned main', 25)
            if not self.desktop:
                self.noactivate(self.main)
            self.ready((800, 500))
            return self
        except BaseException:
            self.close()
            raise

    def windows(self):
        return (languages.windows(self.desktop, self.pid) if self.desktop
                else native.windows(self.pid))

    def find(self, classname, fragment=''):
        return next((h for h in self.windows()
                     if native.cls(h) == classname and fragment in text(h)), None)

    def owned(self, hwnd):
        pid = W.DWORD()
        U.GetWindowThreadProcessId(hwnd, C.byref(pid))
        check(hwnd and pid.value == self.pid, ('not an owned HWND', hwnd, pid.value))
        return hwnd

    def control(self, hwnd, ident):
        return self.owned(check(U.GetDlgItem(self.owned(hwnd), ident), ('missing control', ident)))

    def command(self, ident):
        native.send_command(self.owned(self.main), ident)

    def click(self, hwnd, ident):
        check(ident != 6, 'IDYES is forbidden in this test, including cleanup')
        check(U.PostMessageW(self.control(hwnd, ident), native.BM_CLICK, 0, 0), 'BM_CLICK')

    def open(self, command, classname, fragment=''):
        self.command(command)
        hwnd = native.wait(lambda: self.find(classname, fragment), 'owned ' + classname)
        native.wait(lambda: U.GetDlgItem(hwnd, 2), 'Cancel control ready')
        return hwnd

    def closed(self, hwnd):
        native.wait(lambda: not U.IsWindow(hwnd), 'owned dialog closed')

    def view(self):
        return {'title': text(self.main), 'status': text(self.control(self.main, 904))}

    def ready(self, dimensions):
        expected = '{} × {} px'.format(*dimensions)
        native.wait(lambda: self.source.name in text(self.main)
                    and U.IsWindowEnabled(self.main)
                    and expected in text(self.control(self.main, 904)), 'original image ready: ' + expected)
        check(not self.find('#32770'), 'unexpected native dialog')

    def refresh(self):
        self.command(103)  # Fit restores dimension status after informational feedback.
        self.ready((500, 800))

    def noactivate(self, hwnd, width=None, height=None):
        self.owned(hwnd)
        U.SetWindowLongW(hwnd, -20, U.GetWindowLongW(hwnd, -20) | 0x08000000)
        flags = 0x10 | 0x4  # SWP_NOACTIVATE | SWP_NOZORDER
        if width is None:
            flags |= 0x1 | 0x2  # SWP_NOSIZE | SWP_NOMOVE
            width = height = 0
        check(U.SetWindowPos(hwnd, None, 30, 30, width, height, flags), 'no-activate positioning')

    def diagnostics(self):
        return [{'class': native.cls(h), 'title': text(h),
                 'children': [{'id': U.GetDlgCtrlID(x), 'class': native.cls(x), 'text': text(x)}
                              for x in native.windows(self.pid, h)]} for h in self.windows()]

    def close(self):
        if not self.process:
            return
        try:
            # Never acknowledge OK/Apply/Yes during cleanup. Even failure while
            # the wallpaper prompt is open can only receive No, Cancel or Close.
            for h in self.windows():
                if native.cls(h) == '#32770' and U.GetDlgItem(h, 7):
                    self.click(h, 7)
                elif (native.cls(h) in ('#32770', 'KadrExportCopyWindow',
                                       'KadrWallpaperChoiceWindow') and U.GetDlgItem(h, 2)):
                    self.click(h, 2)
            if self.main and U.IsWindow(self.main):
                U.PostMessageW(self.owned(self.main), native.WM_CLOSE, 0, 0)
            if K.WaitForSingleObject(self.process, 3000) != 0:
                K.TerminateProcess(self.process, 98)
                K.WaitForSingleObject(self.process, 3000)
        finally:
            K.CloseHandle(self.process)
            self.process = None

    def __exit__(self, kind, value, tb):
        if kind:
            self.failure_windows = self.diagnostics()
        self.close()


def copy_path(app):
    # Replace clipboard with OUR known sentinel before ever reading it. Do not
    # inspect or save the user's previous clipboard, and do not restore it.
    sentinel = (str(app.source) + ' [owned test sentinel]\0').encode('utf-16-le')
    native.wait(lambda: U.OpenClipboard(app.owned(app.main)), 'OpenClipboard for owned sentinel')
    memory = None
    try:
        check(U.EmptyClipboard(), 'EmptyClipboard for known sentinel')
        memory = check(K.GlobalAlloc(2, len(sentinel)), 'GlobalAlloc')
        pointer = check(K.GlobalLock(memory), 'GlobalLock')
        C.memmove(pointer, sentinel, len(sentinel))
        K.GlobalUnlock(memory)
        check(U.SetClipboardData(13, memory), 'SetClipboardData known sentinel')
        memory = None  # Windows now owns the allocation.
    finally:
        U.CloseClipboard()
        if memory:
            K.GlobalFree(memory)
    sequence = U.GetClipboardSequenceNumber()
    app.command(127)
    # Modal completion may refresh the transient status immediately. Assert the
    # actual clipboard write, restricted to our owner so no user data is read.
    native.wait(lambda: U.GetClipboardSequenceNumber() != sequence
                and U.GetClipboardOwner() == app.main, 'command 127 wrote owned clipboard')
    native.wait(lambda: U.OpenClipboard(app.main), 'OpenClipboard after command 127')
    try:
        check(U.GetClipboardOwner() == app.main, 'clipboard owner must be our test main before reading')
        handle = check(U.GetClipboardData(13), 'CF_UNICODETEXT')
        pointer = check(K.GlobalLock(handle), 'GlobalLock clipboard')
        try:
            raw = C.string_at(pointer, K.GlobalSize(handle))
            actual = raw.decode('utf-16-le').split('\0', 1)[0]
        finally:
            K.GlobalUnlock(handle)
    finally:
        U.CloseClipboard()
    check(actual == str(app.source), ('command 127 full Unicode path', actual, str(app.source)))
    return actual


def select_jpeg(app, dialog):
    combo = app.control(dialog, 101)
    check(U.SendMessageW(combo, 0x146, 0, 0) == 5, 'five export formats')  # CB_GETCOUNT
    check(U.SendMessageW(combo, 0x14E, 1, 0) == 1, 'CB_SETCURSEL JPEG')
    check(U.PostMessageW(dialog, native.WM_COMMAND, 101 | (1 << 16), combo), 'CBN_SELCHANGE')
    native.wait(lambda: U.IsWindowEnabled(app.control(dialog, 102)), 'JPEG quality enabled')


def export_dialog(app):
    dialog = app.open(126, 'KadrExportCopyWindow')
    native.wait(lambda: text(app.control(dialog, 104)) == '800', 'export defaults settled')
    check((text(app.control(dialog, 103)), text(app.control(dialog, 104))) == ('500', '800'),
          'export must use rotated in-memory image, not original file dimensions')
    check(U.SendMessageW(app.control(dialog, 105), 0xF0, 0, 0) == 1, 'aspect lock defaults checked')
    return dialog


def save_dialog(app, dialog):
    app.click(dialog, 1)
    save = native.wait(lambda: app.find('#32770', 'eksportuj nową kopię'), 'native export Save dialog')
    filename_edit(app, save)
    return save


def run_export(app, work, source_hash, record):
    app.command(107)
    app.ready((500, 800))
    dialog = export_dialog(app)
    check(not U.IsWindowEnabled(app.control(dialog, 102)), 'PNG quality initially disabled')
    select_jpeg(app, dialog)
    set_text(app.control(dialog, 102), '75')
    set_text(app.control(dialog, 103), '250')
    native.wait(lambda: text(app.control(dialog, 104)) == '400', 'aspect locked 250 x 400')

    # Reject out-of-range JPEG quality and >64 MP without attempting allocation.
    baseline = files(app.source.parent)
    for quality in ('0', '101'):
        set_text(app.control(dialog, 102), quality)
        app.click(dialog, 106)
        native.wait(lambda: text(app.control(dialog, 107)).startswith('Podaj dodatnie'),
                    'invalid JPEG quality rejected: ' + quality)
    set_text(app.control(dialog, 102), '75')
    set_text(app.control(dialog, 103), '8001')
    app.click(dialog, 106)
    native.wait(lambda: text(app.control(dialog, 107)).startswith('Podaj dodatnie'), '64 MP cap rejected')
    check(files(app.source.parent) == baseline, 'invalid settings created or changed files')
    set_text(app.control(dialog, 103), '250')
    native.wait(lambda: text(app.control(dialog, 104)) == '400', 'valid aspect restored')
    app.click(dialog, 106)
    match = native.wait(lambda: re.fullmatch(r'Rozmiar pliku: ([0-9]+) B', text(app.control(dialog, 107))),
                        'Polish positive byte-size measurement')
    measured = int(match.group(1))
    check(measured > 0, 'measured positive bytes')
    U.SendMessageW(dialog, 0, 0, 0)  # Finish measurement/temporary-file cleanup.
    check(files(app.source.parent) == baseline, 'measurement left a temporary file or changed source')
    destination = work / 'exports' / 'Kopia zażółć — jakość 75.jpg'
    check(not destination.exists(), 'export destination must be new')
    save = save_dialog(app, dialog)
    set_text(filename_edit(app, save), destination)
    app.click(save, 1)
    app.closed(save)
    app.closed(dialog)
    native.wait(destination.exists, 'new JPEG exists')
    with Image.open(destination) as image:
        image.load()
        check(image.format == 'JPEG' and image.size == (250, 400), ('JPEG format/dimensions', image.format, image.size))
        check(any(lo != hi for lo, hi in image.convert('RGB').getextrema()), 'export pixels are not constant')
    check(destination.stat().st_size == measured, 'measured bytes equal actual JPEG bytes')
    check(sha256(app.source) == source_hash, 'source SHA unchanged after export')
    check(copy_path(app) == str(app.source), 'export changed main active path')
    app.refresh()
    record('jpeg_export', {'commands': [107, 126, 127], 'defaults': [500, 800], 'quality': 75,
                           'size': [250, 400], 'measured_bytes': measured, 'output': str(destination),
                           'invalid_quality': [0, 101], 'over_64_mp_rejected': True,
                           'source_sha_unchanged': True, 'main_path_unchanged': True})

    # Same-source rejection occurs BEFORE any overwrite confirmation or write.
    dialog = export_dialog(app)
    save = save_dialog(app, dialog)
    set_text(filename_edit(app, save), app.source)
    app.click(save, 1)
    app.closed(save)
    native.wait(lambda: text(app.control(dialog, 107)).startswith('Eksport tworzy nową kopię.'),
                'same-source export blocked')
    check(not app.find('#32770'), 'same-source must not offer overwrite confirmation')
    check(sha256(app.source) == source_hash, 'same-source rejection changed source')
    cancelled = work / 'exports' / 'ANULOWANA — kopia.png'
    save = save_dialog(app, dialog)
    set_text(filename_edit(app, save), cancelled)
    app.click(save, 2)
    app.closed(save)
    check(U.IsWindow(dialog), 'native Save cancellation must return to Export')
    app.click(dialog, 2)
    app.closed(dialog)
    app.refresh()
    check(not cancelled.exists() and sha256(app.source) == source_hash, 'Cancel changed files')
    check(copy_path(app) == str(app.source), 'Cancel changed active source path')
    app.refresh()
    record('source_rejection_and_cancel', {'same_source_blocked_without_overwrite_prompt': True,
                                          'native_save_cancel': True, 'export_cancel': True,
                                          'source_sha_unchanged': True, 'image_view_ready': app.view()})


def run_wallpaper(app, before, record):
    baseline = files(app.exe.parent)
    dialog = app.open(128, 'KadrWallpaperChoiceWindow')
    combo = app.control(dialog, 101)
    check(U.SendMessageW(combo, 0x146, 0, 0) == 4, 'four wallpaper modes')
    check(U.SendMessageW(combo, 0x147, 0, 0) == 0, 'wallpaper mode defaults to Fit')
    app.click(dialog, 2)
    app.closed(dialog)
    app.refresh()
    check(wallpaper_path() == before and files(app.exe.parent) == baseline, 'wallpaper Cancel changed state')

    dialog = app.open(128, 'KadrWallpaperChoiceWindow')
    app.click(dialog, 1)  # Opens confirmation ONLY; never accept IDYES (6).
    confirm = native.wait(lambda: app.find('#32770', 'potwierdź zmianę tapety'), 'wallpaper confirmation')
    native.wait(lambda: U.GetDlgItem(confirm, 6) and U.GetDlgItem(confirm, 7), 'Yes/No prompt ready')
    default_no(confirm)
    check('Czy na pewno zmienić tapetę' in '\n'.join(text(h) for h in native.windows(app.pid, confirm)),
          'wallpaper confirmation text')
    check(wallpaper_path() == before and files(app.exe.parent) == baseline,
          'wallpaper must not change before explicit confirmation')
    app.click(confirm, 7)
    app.closed(confirm)
    check(U.IsWindow(dialog), 'No must leave wallpaper chooser open')
    app.click(dialog, 2)
    app.closed(dialog)
    app.refresh()
    after = wallpaper_path()
    after_files = files(app.exe.parent)
    check(after == before, 'desktop wallpaper path changed after No')
    check(after_files == baseline, 'portable wallpaper/cache manifest changed after No')
    record('wallpaper_cancel_and_no', {'command': 128, 'default_button': 7, 'chosen_button': 7,
                                      'cancel_before_and_after_no': True,
                                      'wallpaper_before': before, 'wallpaper_after': after,
                                      'cache_manifest_before': baseline, 'cache_manifest_after': after_files,
                                      'no_yes_no_wallpaper_set_no_print': True})


def screenshots(exe, source, work):
    details = {}
    with App(exe, source) as app:
        app.noactivate(app.main, 980, 650)
        app.command(107)
        app.ready((500, 800))
        targets = [('main-compact.png', app.main)]
        # Capture each owned HWND only. PrintWindow is window rendering, not
        # StartDoc/printing; never capture the screen or an existing user window.
        def capture(name, hwnd):
            try:
                app.noactivate(hwnd)
                destination = work / name
                native.capture(app.owned(hwnd), destination)
                with Image.open(destination) as image:
                    extrema = image.convert('RGB').getextrema()
                    check(image.getbbox() is not None and any(lo != hi for lo, hi in extrema),
                          'black/constant PrintWindow capture')
                    details[name] = {'status': 'CAPTURED', 'path': str(destination), 'size': list(image.size),
                                     'nonconstant': True, 'bbox': image.getbbox()}
            except Exception as error:
                details[name] = {'status': 'UNAVAILABLE', 'reason': str(error)}
        for name, hwnd in targets:
            capture(name, hwnd)
        dialog = export_dialog(app)
        app.noactivate(dialog)
        select_jpeg(app, dialog)
        set_text(app.control(dialog, 102), '75')
        set_text(app.control(dialog, 103), '250')
        native.wait(lambda: text(app.control(dialog, 104)) == '400', 'screenshot export dimensions')
        app.click(dialog, 106)
        native.wait(lambda: re.fullmatch(r'Rozmiar pliku: [0-9]+ B', text(app.control(dialog, 107))),
                    'screenshot export measurement')
        capture('export-compact.png', dialog)
        app.click(dialog, 2)
        app.closed(dialog)
    return details


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--exe', type=Path, default=ROOT / 'tests/Kadr-integrated.exe')
    parser.add_argument('--no-screenshots', action='store_true', help='Do not create even owned windows on the normal desktop')
    args = parser.parse_args()
    original_exe = args.exe.resolve()
    check(original_exe == (ROOT / 'tests/Kadr-integrated.exe').resolve() and original_exe.is_file(),
          'Only the known tests/Kadr-integrated.exe input is allowed; never production Kadr.exe')
    fixture = ROOT / 'tests/fixtures/01-krajobraz.png'
    exe_hash, fixture_hash = sha256(original_exe), sha256(fixture)
    work = Path(tempfile.mkdtemp(prefix='kadr-tools-native-'))
    for name in ('portable', 'images', 'exports'):
        (work / name).mkdir()
    exe = work / 'portable/Kadr-tools-owned.exe'
    source = work / 'images/Zażółć gęślą — źródło 01.png'
    shutil.copy2(original_exe, exe)
    shutil.copy2(fixture, source)
    (exe.parent / 'Kadr.ini').write_bytes(b'[General]\r\nLanguage=pl\r\n')
    report = {'status': 'RUNNING', 'evidence': str(work), 'input_exe': str(original_exe),
              'exe_sha256': exe_hash, 'owned_exe': str(exe), 'owned_source': str(source),
              'source_sha256': fixture_hash, 'tests': {},
              'safety': 'Owned HWND messages only; clipboard read only after own write; no Yes, SPI_SET, StartDoc, global keys or original writes.'}
    print('EVIDENCE ' + str(work), flush=True)
    desktop_name = 'KadrToolsTest-' + uuid.uuid4().hex
    desktop = None
    app = None
    before = wallpaper_path()
    report['wallpaper_before'] = before
    def record(name, detail):
        report['tests'][name] = {'status': 'PASS', **detail}
        print(json.dumps({name: report['tests'][name]}, ensure_ascii=True), flush=True)
    try:
        check(sha256(exe) == exe_hash and sha256(source) == fixture_hash, 'disposable copies match inputs')
        desktop = check(U.CreateDesktopW(desktop_name, None, None, 0, 0x01ff, None), 'CreateDesktopW')
        app = App(exe, source, desktop, desktop_name)
        with app:
            path = copy_path(app)
            record('copy_unicode_path', {'command': 127, 'format': 'CF_UNICODETEXT', 'actual': path,
                                         'expected': str(source), 'clipboard_seeded_before_read': True})
            app.command(103)
            app.ready((800, 500))
            run_export(app, work, fixture_hash, record)
            run_wallpaper(app, before, record)
        if args.no_screenshots:
            report['screenshots'] = {'status': 'SKIPPED', 'reason': '--no-screenshots'}
        else:
            try:
                report['screenshots'] = screenshots(exe, source, work)
            except Exception as error:
                report['screenshots'] = {'status': 'UNAVAILABLE', 'reason': str(error)}
        check(wallpaper_path() == before, 'wallpaper unchanged after all processes')
        check(sha256(source) == fixture_hash, 'owned source unchanged at end')
        check(sha256(fixture) == fixture_hash and sha256(original_exe) == exe_hash, 'input fixture/EXE unchanged')
        record('final_integrity', {'fixture_unchanged': True, 'integrated_exe_unchanged': True,
                                   'owned_source_unchanged': True, 'wallpaper_unchanged': True})
        report['status'] = 'PASS'
    except Exception:
        report['status'] = 'FAIL'
        report['error'] = traceback.format_exc()
        if app and hasattr(app, 'failure_windows'):
            report['failure_windows'] = app.failure_windows
        print(report['error'], flush=True)
    finally:
        if desktop:
            U.CloseDesktop(desktop)
        report['wallpaper_after'] = wallpaper_path()
        report['final_owned_source_sha256'] = sha256(source)
        report['final_input_fixture_sha256'] = sha256(fixture)
        report['final_input_exe_sha256'] = sha256(original_exe)
        (work / 'results.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
        print(json.dumps({'status': report['status'], 'results': str(work / 'results.json'),
                          'screenshots': report.get('screenshots', {})}, ensure_ascii=True), flush=True)
    return 0 if report['status'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
