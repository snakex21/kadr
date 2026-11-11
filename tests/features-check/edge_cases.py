"""Native failure/cancellation regressions, using only disposable generated copies.

From src: python ../tests/features-check/edge_cases.py
Defaults to tests/Kadr-features.exe, NEVER the production Kadr.exe. No builds,
production switches, fixtures, successful overwrites, or delete operations.
Temporary inputs/evidence are retained and their location is printed.
"""
import argparse
import ctypes as C
from ctypes import wintypes as W
import hashlib
import json
from pathlib import Path
import random
import shutil
import struct
import subprocess
import tempfile
import threading
import time

from PIL import Image, ImageDraw
import run as native

U, K = native.U, native.K
U.GetClipboardSequenceNumber.argtypes = []
U.GetClipboardSequenceNumber.restype = W.DWORD
K.FindFirstChangeNotificationW.argtypes = [W.LPCWSTR, W.BOOL, W.DWORD]
K.FindFirstChangeNotificationW.restype = W.HANDLE
K.FindNextChangeNotification.argtypes = [W.HANDLE]
K.FindNextChangeNotification.restype = W.BOOL
K.FindCloseChangeNotification.argtypes = [W.HANDLE]
K.FindCloseChangeNotification.restype = W.BOOL
K.WaitForSingleObject.argtypes = [W.HANDLE, W.DWORD]
K.WaitForSingleObject.restype = W.DWORD


def text(hwnd):
    buffer = C.create_unicode_buffer(32768)
    U.SendMessageW(hwnd, 0xD, len(buffer), C.cast(buffer, C.c_void_p).value)
    return buffer.value


def set_text(hwnd, value):
    buffer = C.create_unicode_buffer(str(value))
    assert U.SendMessageW(hwnd, 0xC, 0, C.cast(buffer, C.c_void_p).value), 'WM_SETTEXT failed'
    assert text(hwnd) == str(value), ('filename readback', text(hwnd), str(value))


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def manifest(folder):
    return {p.name: sha256(p) for p in folder.iterdir() if p.is_file() and p.suffix != '.log'}


def record(results, name, detail):
    results[name] = {'status': 'PASS', **detail}
    print(json.dumps({name: results[name]}, ensure_ascii=False), flush=True)


class Client:
    def __init__(self, exe, source):
        self.exe, self.source = exe, source
        self.main = None

    def __enter__(self):
        self.log = (self.source.parent / 'client.log').open('wb')
        self.proc = subprocess.Popen([str(self.exe), str(self.source)], cwd=native.ROOT,
                                     stdout=self.log, stderr=subprocess.STDOUT)
        try:
            self.main = native.wait(lambda: next((h for h in native.windows(self.proc.pid)
                                                 if native.cls(h) == 'Kadr.Main'), None), 'test main window', 25)
            native.wait(lambda: self.source.name in native.title(self.main), 'source loaded', 25)
            native.wait(lambda: 'px' in text(U.GetDlgItem(self.main, 904)), 'loaded image status', 25)
            return self
        except BaseException:
            self.__exit__(None, None, None)
            raise

    def __exit__(self, kind, value, traceback):
        if kind:
            print('NATIVE DIAGNOSTICS', json.dumps(self.diagnostics(), ensure_ascii=False), flush=True)
        # Cancel/No before acknowledging errors; never accept an overwrite in cleanup.
        for _ in range(3):
            dialogs = [h for h in native.windows(self.proc.pid) if native.cls(h) == '#32770']
            if not dialogs:
                break
            for h in dialogs:
                for ident in (2, 7, 1):
                    if U.GetDlgItem(h, ident):
                        native.click(h, ident)
                        break
            time.sleep(.1)
        if self.main and U.IsWindow(self.main):
            U.PostMessageW(self.main, native.WM_CLOSE, 0, 0)
        try:
            self.proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait(timeout=5)
        self.log.close()

    def diagnostics(self):
        return {'exit': self.proc.poll(), 'view': self.view() if self.main else None,
                'dialogs': [{'title': native.title(h), 'text': self.message_text(h)}
                            for h in native.windows(self.proc.pid) if native.cls(h) == '#32770'],
                'files': [p.name for p in self.source.parent.iterdir()]}

    def command(self, ident):
        native.send_command(self.main, ident)

    def view(self):
        return {'title': native.title(self.main), 'page': text(U.GetDlgItem(self.main, 902)),
                'status': text(U.GetDlgItem(self.main, 904))}

    def idle(self):
        native.wait(lambda: U.IsWindowEnabled(self.main) and not native.dialog(self.proc.pid),
                    'main window enabled, no modal dialog')

    def reset_status(self):
        self.command(103)  # Fit refreshes the dimension status after clipboard feedback.
        native.wait(lambda: 'px' in self.view()['status'], 'dimension status refreshed')

    def message_text(self, hwnd):
        return '\n'.join(text(x) for x in native.windows(self.proc.pid, hwnd)
                         if native.cls(x) == 'Static')

    def message(self, fragment):
        return next((h for h in native.windows(self.proc.pid)
                     if native.cls(h) == '#32770' and fragment in self.message_text(h)), None)

    def expect_message(self, fragment, timeout=12):
        return native.wait(lambda: self.message(fragment), 'message: ' + fragment, timeout)

    def dismiss(self, hwnd, ident):
        def button_ready():
            button = U.GetDlgItem(hwnd, ident)
            if button:
                return button
            # This host's single-button MessageBox labels IDCANCEL (2) "OK".
            # Only acknowledge that explicit OK button, never a Save/Yes button.
            if ident == 1:
                buttons = [x for x in native.windows(self.proc.pid, hwnd)
                           if native.cls(x) == 'Button' and text(x).replace('&', '').strip().casefold() == 'ok']
                if len(buttons) == 1:
                    return buttons[0]
            return None
        button = native.wait(button_ready, f'dialog button {ident} ready')
        U.PostMessageW(button, native.BM_CLICK, 0, 0)
        native.wait(lambda: not U.IsWindow(hwnd), 'dialog closes')

    def rename_dialog(self):
        self.command(120)  # The same command dispatched by F2.
        return native.wait(lambda: native.dialog(self.proc.pid, 'zmień nazwę'), 'F2 rename dialog')

    def open_save(self):
        self.command(117)
        first = native.wait(lambda: native.dialog(self.proc.pid, 'zapisz kopię') or
                            self.message('Zapisana zostanie tylko'), 'Save As dialog or document warning')
        if 'Zapisana zostanie tylko' in self.message_text(first):
            self.dismiss(first, 1)
        return native.wait(lambda: native.dialog(self.proc.pid, 'zapisz kopię'), 'native Save As dialog')

    def submit_save(self, hwnd, destination):
        # Same cross-process-safe Edit path as run.save_dialog(), without its
        # success-only wait: these cases expect cancellation/rejection/failure.
        def filename_edit():
            for edit in native.windows(self.proc.pid, hwnd):
                if native.cls(edit) != 'Edit':
                    continue
                ancestor = edit
                while ancestor and ancestor != hwnd:
                    if U.GetDlgCtrlID(ancestor) in (1148, 1152):
                        return edit
                    ancestor = U.GetParent(ancestor)
            return None
        edit = native.wait(filename_edit, 'native filename Edit')
        set_text(edit, destination)
        self.dismiss(hwnd, 1)

    def clipboard_image(self):
        sequence = U.GetClipboardSequenceNumber()
        self.command(119)
        native.wait(lambda: U.GetClipboardSequenceNumber() != sequence, 'this copy command updates clipboard')
        native.wait(lambda: U.OpenClipboard(None), 'OpenClipboard')
        try:
            memory = U.GetClipboardData(8)
            assert memory, 'CF_DIB missing'
            address = K.GlobalLock(memory)
            assert address, 'GlobalLock CF_DIB'
            try:
                blob = C.string_at(address, K.GlobalSize(memory))
            finally:
                K.GlobalUnlock(memory)
        finally:
            U.CloseClipboard()
        header, width, height, planes, bits, compression = struct.unpack_from('<IiiHHI', blob)
        assert header >= 40 and width > 0 and height and planes == 1 and bits == 32 and compression == 0
        stride = ((width * bits + 31) // 32) * 4
        pixels = blob[header:header + stride * abs(height)]
        return Image.frombytes('RGB', (width, abs(height)), pixels, 'raw', 'BGRX', stride,
                               -1 if height > 0 else 1)


def document_cases(exe, work, results):
    templates = work / 'templates'
    templates.mkdir()
    first = Image.new('RGB', (137, 91), '#a53020')
    second = Image.new('RGB', (211, 123), '#204cbe')
    draw = ImageDraw.Draw(second)
    draw.rectangle((0, 0, 45, 25), fill='#ffdb24')
    draw.rectangle((130, 73, 210, 122), fill='#10ce60')
    master = templates / 'multipage.tiff'
    first.save(master, save_all=True, append_images=[second], compression='raw')
    expected = second.transpose(Image.Transpose.ROTATE_270)
    master_hash = sha256(master)
    folder = work / 'document'
    folder.mkdir()
    source, occupied = folder / 'source.tiff', folder / 'occupied.tiff'
    shutil.copy2(master, source)
    first.save(occupied, compression='raw')
    overwrite = folder / 'existing.png'
    first.save(overwrite)
    baseline = manifest(folder)

    with Client(exe, source) as app:
        native.wait(lambda: app.view()['page'] == '1 / 2', 'multipage TIFF recognized')
        app.command(113)  # Page Down: select second page through the loader.
        native.wait(lambda: app.view()['page'] == '2 / 2', 'TIFF page 2 selected')
        app.command(107)
        dimensions = f'{expected.width} × {expected.height} px'
        native.wait(lambda: dimensions in app.view()['status'], 'page 2 rotated')
        before_pixels = app.clipboard_image()
        assert before_pixels.size == expected.size and before_pixels.tobytes() == expected.tobytes()
        app.reset_status()
        before = app.view()
        rename = app.rename_dialog()
        set_text(U.GetDlgItem(rename, 2001), occupied.name)
        app.dismiss(rename, 1)
        error = app.expect_message('Nie można zmienić nazwy')
        app.dismiss(error, 1)
        app.idle()
        after = app.view()
        assert after == before, ('rename collision changed page/rotation/status', before, after)
        assert U.IsWindowVisible(U.GetDlgItem(app.main, 902)), 'document page label disappeared'
        after_pixels = app.clipboard_image()
        assert after_pixels.size == expected.size and after_pixels.tobytes() == expected.tobytes(), 'restored page pixels differ'
        assert manifest(folder) == baseline, 'rename collision changed source/target files'
        record(results, 'multipage_rename_collision', {'page': after['page'], 'size': list(after_pixels.size),
               'status_text': after['status'], 'source_target_hashes_unchanged': True,
               'exact_rotated_page_pixels': True})

        app.reset_status()
        before = app.view()
        rename = app.rename_dialog()
        set_text(U.GetDlgItem(rename, 2001), 'cancelled-name.tiff')
        app.dismiss(rename, 2)
        app.idle()
        assert app.view() == before and manifest(folder) == baseline, 'initial rename cancellation changed state/files'
        record(results, 'cancel_initial_rename', {'files_and_view_unchanged': True})

        app.command(117)
        warning = app.expect_message('Zapisana zostanie tylko')
        app.dismiss(warning, 2)
        app.idle()
        assert app.view() == before and manifest(folder) == baseline, 'cancelled document warning changed files/view'
        save = app.open_save()
        app.dismiss(save, 2)
        app.idle()
        assert app.view() == before and manifest(folder) == baseline, 'cancelled Save As dialog changed files/view'
        record(results, 'cancel_initial_save', {'document_warning_and_file_dialog_cancelled': True,
                                                'files_and_view_unchanged': True})

        save = app.open_save()
        app.submit_save(save, overwrite)
        confirm = app.expect_message('Plik docelowy już istnieje')
        assert 'potwierdź nadpisanie' in native.title(confirm), 'expected application overwrite confirmation'
        app.dismiss(confirm, 7)  # IDNO, never consent to replacement.
        app.idle()
        assert app.view() == before and manifest(folder) == baseline, 'Save As overwrite cancellation changed files/view'
        record(results, 'cancel_save_overwrite', {'source_and_existing_target_unchanged': True,
                                                 'page_rotation_status_unchanged': True})

        unsupported = folder / 'unsupported.webp'
        save = app.open_save()
        app.submit_save(save, unsupported)
        error = app.expect_message('Wybierz rozszerzenie PNG, JPG, BMP, TIFF lub GIF')
        app.dismiss(error, 1)
        app.idle()
        assert not unsupported.exists() and manifest(folder) == baseline, 'unsupported format wrote files'
        assert app.view() == before, 'unsupported format changed document view'
        record(results, 'unsupported_save_format', {'destination_not_created': True,
                                                   'source_targets_and_view_unchanged': True})
    assert sha256(master) == master_hash, 'generated master was changed'


class UnverifiedRace(Exception):
    pass


class ReservationWatcher:
    """Arm XP-era directory notifications BEFORE Save; write only after kdr*.tmp appears."""
    def __init__(self, folder, destination, sentinel):
        self.folder, self.destination, self.sentinel = folder, destination, sentinel
        self.stop = threading.Event()
        self.created = threading.Event()
        self.evidence = {}
        self.error = None
        self.notification = K.FindFirstChangeNotificationW(str(folder), False, 1)  # FILE_NOTIFY_CHANGE_FILE_NAME
        assert self.notification not in (None, C.c_void_p(-1).value), 'directory notification failed'
        self.thread = threading.Thread(target=self.watch, name='kadr-temp-reservation', daemon=True)

    def __enter__(self):
        self.thread.start()
        return self

    def __exit__(self, *unused):
        self.stop.set()
        self.thread.join(timeout=2)
        assert not self.thread.is_alive(), 'watcher did not stop'
        K.FindCloseChangeNotification(self.notification)

    def watch(self):
        try:
            while not self.stop.is_set():
                for temporary in self.folder.iterdir():
                    if temporary.name.lower().startswith('kdr') and temporary.suffix.lower() == '.tmp':
                        observed = time.monotonic_ns()
                        try:
                            length = temporary.stat().st_size
                        except FileNotFoundError:
                            continue  # Commit already won; do not claim this race was exercised.
                        with self.destination.open('xb') as file:
                            file.write(self.sentinel)
                        self.evidence = {'reserved_temp': temporary.name, 'temp_bytes_when_seen': length,
                                         'reservation_to_sentinel_ms': (time.monotonic_ns() - observed) / 1_000_000}
                        self.created.set()
                        return
                outcome = K.WaitForSingleObject(self.notification, 5)
                if outcome == 0:
                    assert K.FindNextChangeNotification(self.notification), 'rearming directory notification failed'
                else:
                    assert outcome == 258, ('directory notification wait', outcome)  # WAIT_TIMEOUT
        except BaseException as error:
            self.error = repr(error)


def destination_race(exe, work, results):
    folder = work / 'race'
    folder.mkdir()
    master = work / 'templates' / 'eight-megapixels.bmp'
    # Incompressible 8 MP RGB gives the watcher a real encoding window without
    # suspending/instrumenting Kadr or relying on a hidden application switch.
    image = Image.frombytes('RGB', (4000, 2000), random.Random(0x4b414452).randbytes(4000 * 2000 * 3))
    image.save(master)
    image.close()
    source = folder / 'large-copy.bmp'
    shutil.copy2(master, source)
    source_hash = sha256(source)
    destination = folder / 'appeared-during-encoding.png'
    sentinel = b'KADR EDGE CASE: destination created after temporary reservation; NEVER REPLACE\r\n'
    with Client(exe, source) as app:
        before = app.view()
        save = app.open_save()
        assert not destination.exists() and not list(folder.glob('kdr*.tmp'))
        with ReservationWatcher(folder, destination, sentinel) as watcher:
            app.submit_save(save, destination)
            try:
                error = app.expect_message('Nie można zastąpić pliku docelowego', timeout=30)
            except AssertionError:
                if watcher.created.is_set() and destination.read_bytes() != sentinel:
                    raise AssertionError('REAL BUG: newly created destination sentinel was overwritten')
                if not watcher.created.is_set():
                    raise UnverifiedRace('No sentinel installed before commit: ' + str(watcher.error))
                raise
            assert watcher.created.is_set(), ('save failed without observed reservation', watcher.error)
            assert destination.read_bytes() == sentinel, 'REAL BUG: destination sentinel was modified'
            failure_text = app.message_text(error)
            app.dismiss(error, 1)
            app.idle()
            assert app.view() == before, ('failed Save As changed current image/status', before, app.view())
            assert sha256(source) == source_hash, 'race changed source bitmap'
            assert not list(folder.glob('kdr*.tmp')), 'failed save left its temporary file behind'
            record(results, 'new_destination_during_encoding', {**watcher.evidence,
                   'source_size': [4000, 2000], 'sentinel_unchanged': True,
                   'source_unchanged': True, 'save_failure_dialog': failure_text,
                   'temporary_file_cleaned': True})
    assert sha256(master) == source_hash, 'large generated master was changed'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--exe', type=Path, default=native.ROOT / 'tests' / 'Kadr-features.exe')
    args = parser.parse_args()
    exe = args.exe.resolve()
    assert exe.is_file() and exe != (native.ROOT / 'Kadr.exe').resolve(), 'use an existing test executable, not production Kadr.exe'
    work = Path(tempfile.mkdtemp(prefix='kadr-edge-cases-'))
    results = {'exe': str(exe), 'exe_sha256': sha256(exe), 'work': str(work)}
    print(json.dumps(results, ensure_ascii=False), flush=True)
    try:
        document_cases(exe, work, results)
        destination_race(exe, work, results)
    except UnverifiedRace as error:
        results['new_destination_during_encoding'] = {'status': 'UNVERIFIED', 'reason': str(error)}
        print(json.dumps(results, ensure_ascii=False, indent=2), flush=True)
        return 2
    except BaseException:
        print('FAILED; completed evidence:', json.dumps(results, ensure_ascii=False, indent=2), flush=True)
        raise
    print(json.dumps(results, ensure_ascii=False, indent=2), flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
