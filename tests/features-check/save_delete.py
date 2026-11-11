"""Native Save/Delete regressions on generated tempfile copies only.

From src: python ../tests/features-check/save_delete.py
Defaults to tests/Kadr-save-delete.exe; refuses production Kadr.exe. No builds,
printing, fixture mutations, global keyboard injection, or production test switches.
Evidence and generated masters/copies are retained under the printed temp folder.
run.py remains the ordinary Delete/actual-Recycle-Bin regression.
"""
import argparse
import ctypes as C
from ctypes import wintypes as W
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

from PIL import Image
import run as native
from edge_cases import Client, manifest, record, set_text, sha256, text

U, K = native.U, native.K
U.GetWindowThreadProcessId.argtypes = [W.HWND, C.POINTER(W.DWORD)]
U.GetWindowThreadProcessId.restype = W.DWORD
U.AttachThreadInput.argtypes = [W.DWORD, W.DWORD, W.BOOL]
U.AttachThreadInput.restype = W.BOOL
U.SetFocus.argtypes = [W.HWND]
U.SetFocus.restype = W.HWND
U.GetKeyboardState.argtypes = [C.POINTER(C.c_ubyte)]
U.SetKeyboardState.argtypes = [C.POINTER(C.c_ubyte)]
K.GetCurrentThreadId.restype = W.DWORD
K.CreateFileW.argtypes = [W.LPCWSTR, W.DWORD, W.DWORD, C.c_void_p,
                          W.DWORD, W.DWORD, W.HANDLE]
K.CreateFileW.restype = W.HANDLE
K.CloseHandle.argtypes = [W.HANDLE]
K.GetFileAttributesW.argtypes = [W.LPCWSTR]
K.GetFileAttributesW.restype = W.DWORD
K.SetFileAttributesW.argtypes = [W.LPCWSTR, W.DWORD]


def filename_edit(app, hwnd):
    # WM_GETTEXT is marshalled across processes, unlike pointer-based CDM_*.
    # Explorer's real filename Edit is nested under cmb13 (1148), not the
    # Save-in combo, search box, or an arbitrary first Edit.
    def find():
        for edit in native.windows(app.proc.pid, hwnd):
            if native.cls(edit) != 'Edit':
                continue
            ancestor = edit
            while ancestor and ancestor != hwnd:
                if U.GetDlgCtrlID(ancestor) in (1148, 1152):
                    return edit
                ancestor = U.GetParent(ancestor)
        return None
    return native.wait(find, 'native filename Edit under cmb13/edt1')


def default_no(hwnd):
    native.wait(lambda: U.GetDlgItem(hwnd, 7), 'No button ready')
    ident = U.SendMessageW(hwnd, 0x400, 0, 0) & 0xffff  # DM_GETDEFID
    assert ident == 7, ('confirmation must default to No', native.title(hwnd), ident)


def no_dialog(app):
    assert not native.dialog(app.proc.pid), app.diagnostics()


def ready(app, source, count):
    native.wait(lambda: source.name in native.title(app.main)
                and text(U.GetDlgItem(app.main, 900)) == count
                and 'px' in text(U.GetDlgItem(app.main, 904))
                and 'Wczytywanie' not in text(U.GetDlgItem(app.main, 904)),
                'loaded image and settled folder: ' + source.name)
    no_dialog(app)


def key(app, vk, *, ctrl=False, shift=False, focus=None, until=None):
    # Attach only Python's input queue and THIS disposable test process. Set
    # queue-local modifier state, never SendInput/keybd_event or user-window keys.
    own = K.GetCurrentThreadId()
    target = U.GetWindowThreadProcessId(app.main, None)
    old = (C.c_ubyte * 256)()
    assert U.GetKeyboardState(old)
    assert U.AttachThreadInput(own, target, True), C.get_last_error()
    try:
        U.SetFocus(focus or app.main)
        state = (C.c_ubyte * 256)()
        if ctrl:
            state[0x11] = state[0xA2] = 0x80
        if shift:
            state[0x10] = state[0xA0] = 0x80
        assert U.SetKeyboardState(state)
        assert U.PostMessageW(focus or app.main, 0x100, vk, 1)
        if until:
            return native.wait(until, 'targeted keyboard action')
        time.sleep(.3)
    finally:
        assert U.SetKeyboardState((C.c_ubyte * 256)())
        assert U.AttachThreadInput(own, target, False)
        assert U.SetKeyboardState(old)


def recycled_count(path):
    # The basename contains the tempfile's unique token. Never empty/modify Bin.
    name = path.name.replace("'", "''")
    ps = ("$n='" + name + "'; $items=(New-Object -ComObject Shell.Application)"
          ".NameSpace(10).Items(); @($items | Where-Object { $_.Name -eq $n -or "
          "$_.Name -eq [IO.Path]::GetFileNameWithoutExtension($n) }).Count")
    value = subprocess.check_output(['powershell', '-NoProfile', '-Command', ps],
                                    text=True, timeout=30).strip()
    return int(value)


def copy_case(work, case, master, name):
    folder = work / case
    folder.mkdir(exist_ok=True)
    source = folder / name
    shutil.copy2(master, source)
    return source


def static_save(exe, work, master, results):
    source = copy_case(work, 'static', master, work.name + '-01-źródło.PNG')
    following = source.parent / (work.name + '-02.png')
    shutil.copy2(master, following)
    baseline = manifest(source.parent)
    with Image.open(source) as im:
        expected = im.transpose(Image.Transpose.ROTATE_270).copy()
    with Client(exe, source) as app:
        ready(app, source, '1 / 2')
        assert U.GetDlgItem(app.main, 118), 'toolbar must bind Save/current ID 118'
        assert not U.GetDlgItem(app.main, 117), 'Save As ID 117 must not be toolbar Save'
        app.command(107)
        native.wait(lambda: '6 × 9 px' in app.view()['status'], 'rotated view')

        # The native default, not a guessed label, must retain filename/case.
        save = app.open_save()  # Public WM_COMMAND 117 is still Save As.
        edit = filename_edit(app, save)
        default = text(edit)
        assert Path(default).name == source.name, ('default filename', default, source.name)
        save_in = text(U.GetDlgItem(save, 1137))
        assert save_in == source.parent.name, ('native initial directory', save_in, str(source.parent))
        # Submit the untouched default. Its uniquely named existing file must
        # trigger overwrite confirmation; a wrong directory would create a copy.
        app.dismiss(save, 1)
        confirm = app.expect_message('Plik docelowy już istnieje')
        default_no(confirm)
        app.dismiss(confirm, 7)
        assert manifest(source.parent) == baseline
        record(results, 'save_as_native_default', {'WM_GETTEXT_filename': default,
               'save_in': save_in, 'default_resolves_to_existing_original': True})

        save = app.open_save()
        app.dismiss(save, 2)
        assert manifest(source.parent) == baseline
        record(results, 'save_as_cancel', {'original_and_directory_unchanged': True})

        exported = source.parent / 'zz-fresh-export.png'
        save = app.open_save()
        app.submit_save(save, exported)
        native.wait(exported.exists, 'fresh Save As export')
        native.image_pixels(exported, expected)
        assert sha256(source) == baseline[source.name]
        record(results, 'save_as_fresh', {'exact_rotated_PNG_pixels': True,
                                        'original_unchanged': True, 'command': 117})

        app.command(118)
        confirm = app.expect_message('Nadpisać plik')
        default_no(confirm)
        warning = app.message_text(confirm)
        assert 'metadane' in warning and 'JPEG' in warning
        app.dismiss(confirm, 7)
        assert sha256(source) == baseline[source.name]
        assert '6 × 9 px' in app.view()['status']
        record(results, 'direct_overwrite_no', {'default_No': True,
               'metadata_JPEG_warning': True, 'original_and_rotation_preserved': True})

        confirm = key(app, ord('S'), ctrl=True,
                      until=lambda: app.message('Nadpisać plik'))
        default_no(confirm)
        app.dismiss(confirm, 7)
        save = key(app, ord('S'), ctrl=True, shift=True,
                   until=lambda: native.dialog(app.proc.pid, 'zapisz kopię'))
        assert Path(text(filename_edit(app, save))).name == source.name
        app.dismiss(save, 2)
        record(results, 'save_shortcuts', {'Ctrl_S': 118, 'Ctrl_Shift_S': 117})

        # Zoom edit retains Delete and Ctrl+S instead of invoking photo actions.
        zoom = U.GetDlgItem(app.main, 901)
        for shift in (False, True):
            set_text(zoom, '100%')
            key(app, ord('S'), ctrl=True, shift=shift, focus=zoom)
            no_dialog(app)
            assert text(zoom) == '100%'
            U.SendMessageW(zoom, 0xB1, 0, 1)  # EM_SETSEL: select first digit.
            key(app, 0x2E, shift=shift, focus=zoom,
                until=lambda: text(zoom) == '00%')
            no_dialog(app)
        key(app, 0x1B, focus=zoom)  # Escape cancels invalid edit, focus returns.
        assert sha256(source) == baseline[source.name]
        record(results, 'zoom_edit_shortcuts', {'Delete_ShiftDelete_edit_only': True,
                                              'CtrlS_CtrlShiftS_not_consumed': True})

        app.command(118)
        confirm = app.expect_message('Nadpisać plik')
        app.dismiss(confirm, 6)
        ready(app, source, '1 / 3')
        native.image_pixels(source, expected)
        assert {p.name for p in source.parent.iterdir()} == set(baseline) | {'zz-fresh-export.png', 'client.log'}
        record(results, 'direct_save_118', {'same_filename_and_folder': True,
               'exact_PNG_pixels': True, 'no_suffixed_copy_or_temporary_file': True})

        saved_hash = sha256(source)
        app.command(118)
        native.wait(lambda: 'Brak zmian' in app.view()['status'], 'Save with no changes')
        no_dialog(app)
        assert sha256(source) == saved_hash
        record(results, 'save_no_changes', {'no_op': True})

        app.command(107)
        save = app.open_save()
        app.submit_save(save, source)
        confirm = app.expect_message('Plik docelowy już istnieje')
        default_no(confirm)
        app.dismiss(confirm, 6)
        ready(app, source, '1 / 3')
        expected = expected.transpose(Image.Transpose.ROTATE_270)
        native.image_pixels(source, expected)
        record(results, 'save_as_same_path', {'released_GDI_source_lock': True,
                                            'exact_PNG_pixels': True})


def locked_save(exe, work, master, results):
    source = copy_case(work, 'locked', master, 'locked.png')
    original = sha256(source)
    with Image.open(source) as im:
        expected = im.transpose(Image.Transpose.ROTATE_270).copy()
    with Client(exe, source) as app:
        ready(app, source, '1 / 1')
        app.command(107)
        # External reader shares reads/writes, but deliberately NOT deletion.
        handle = K.CreateFileW(str(source), 0x80000000, 3, None, 3, 0, None)
        assert handle not in (None, C.c_void_p(-1).value), C.get_last_error()
        try:
            app.command(118)
            app.dismiss(app.expect_message('Nadpisać plik'), 6)
            error = app.expect_message('Nie można zastąpić pliku docelowego')
            app.dismiss(error, 1)
            assert sha256(source) == original
            assert '6 × 9 px' in app.view()['status']
            assert not list(source.parent.glob('*.tmp'))
        finally:
            K.CloseHandle(handle)
        app.command(118)
        app.dismiss(app.expect_message('Nadpisać plik'), 6)
        ready(app, source, '1 / 1')
        native.image_pixels(source, expected)
        record(results, 'same_path_after_lock_release', {'locked_failure_preserves_source': True,
               'unsaved_rotation_retained': True, 'retry_exact_PNG_pixels': True})


def protected_source(exe, work, master, results, kind):
    source = copy_case(work, kind, master, 'original' + master.suffix)
    original = sha256(source)
    with Image.open(source) as im:
        expected = im.convert('RGB').transpose(Image.Transpose.ROTATE_270)
    with Client(exe, source) as app:
        ready(app, source, '1 / 1')
        if kind == 'animated':
            app.command(108)  # Long frame delays ensure frame 0; pause it.
        app.command(107)
        app.command(118)
        guidance = app.expect_message('nie może być nadpisany pojedynczym obrazem')
        warning = app.message_text(guidance)
        assert 'Ctrl+Shift+S' in warning and 'PNG' in warning
        app.dismiss(guidance, 1)
        assert sha256(source) == original

        save = app.open_save()
        assert Path(text(filename_edit(app, save))).name == source.name
        app.submit_save(save, source)
        fragment = 'Wybierz rozszerzenie PNG' if kind == 'unencodable' else 'Nie nadpisuj animacji'
        app.dismiss(app.expect_message(fragment), 1)
        assert sha256(source) == original

        exported = source.parent / 'supported-export.png'
        save = app.open_save()
        app.submit_save(save, exported)
        native.wait(exported.exists, 'protected source exports to new supported path')
        native.image_pixels(exported, expected)
        assert sha256(source) == original
        record(results, kind + '_save_protection', {'Save118_blocks_flat_overwrite': True,
               'SaveAs117_blocks_same_path': True, 'supported_PNG_export_exact': True,
               'original_unchanged': True})


def permanent_delete(exe, work, master, results):
    source = copy_case(work, 'permanent', master, work.name + '-02-delete.png')
    previous = source.parent / (work.name + '-01.png')
    following = source.parent / (work.name + '-03.png')
    for path in (previous, following):
        shutil.copy2(master, path)
    before = recycled_count(source)
    original = sha256(source)
    with Client(exe, source) as app:
        ready(app, source, '2 / 3')
        app.command(124)
        confirm = app.expect_message('Trwale usunąć ten plik?')
        warning = app.message_text(confirm)
        assert source.name in warning and 'NIE trafi do Kosza' in warning and 'nie można cofnąć' in warning
        default_no(confirm)
        app.dismiss(confirm, 7)
        assert sha256(source) == original
        ready(app, source, '2 / 3')
        record(results, 'permanent_delete_no', {'filename_and_irreversible_warning': True,
               'default_No': True, 'file_and_neighbor_selection_unchanged': True})

        confirm = key(app, 0x2E, shift=True,
                      until=lambda: app.message('Trwale usunąć ten plik?'))
        default_no(confirm)
        app.dismiss(confirm, 7)
        confirm = key(app, 0x2E, until=lambda: app.message('Przenieść ten plik do Kosza?'))
        default_no(confirm)
        app.dismiss(confirm, 7)
        assert sha256(source) == original
        record(results, 'delete_shortcuts', {'ShiftDelete': 124, 'Delete': 121})

        app.command(124)
        app.dismiss(app.expect_message('Trwale usunąć ten plik?'), 6)
        native.wait(lambda: not source.exists(), 'permanently deleted generated copy')
        ready(app, following, '2 / 2')
        after = recycled_count(source)
        assert after == before == 0, ('permanent deletion must bypass Recycle Bin', before, after)
        record(results, 'permanent_delete_yes', {'removed_copy': True,
               'not_in_Recycle_Bin': True, 'opened_expected_next': following.name})

        app.command(124)
        app.dismiss(app.expect_message('Trwale usunąć ten plik?'), 6)
        native.wait(lambda: not following.exists(), 'last entry deleted')
        ready(app, previous, '1 / 1')
        record(results, 'delete_last_opens_previous', {'expected_previous': previous.name})
        app.command(124)
        app.dismiss(app.expect_message('Trwale usunąć ten plik?'), 6)
        native.wait(lambda: not previous.exists() and text(U.GetDlgItem(app.main, 900)) == '0 / 0',
                    'last remaining image deleted: empty state')
        assert not U.IsWindowEnabled(U.GetDlgItem(app.main, 101))
        assert not U.IsWindowEnabled(U.GetDlgItem(app.main, 102))
        no_dialog(app)
        record(results, 'delete_only_image_empty', {'counter': '0 / 0', 'navigation_disabled': True})


def readonly_document_delete(exe, work, master, results):
    source = copy_case(work, 'readonly-document', master, 'readonly.tiff')
    original = sha256(source)
    with Client(exe, source) as app:
        ready(app, source, '1 / 1')
        app.command(113)
        native.wait(lambda: app.view()['page'] == '2 / 2', 'second TIFF page')
        app.command(107)
        native.wait(lambda: '6 × 9 px' in app.view()['status'], 'rotated TIFF page')
        before = app.view()
        attrs = K.GetFileAttributesW(str(source))
        assert attrs != 0xffffffff
        assert K.SetFileAttributesW(str(source), attrs | 1)
        try:
            app.command(124)
            app.dismiss(app.expect_message('Trwale usunąć ten plik?'), 6)
            error = app.expect_message('Nie udało się trwale usunąć pliku')
            app.dismiss(error, 1)
            assert sha256(source) == original
            assert K.GetFileAttributesW(str(source)) & 1, 'application must not force read-only attributes'
            assert app.view() == before, ('document/page/rotation recovery', before, app.view())
        finally:
            assert K.SetFileAttributesW(str(source), attrs)
        app.command(124)
        app.dismiss(app.expect_message('Trwale usunąć ten plik?'), 6)
        native.wait(lambda: not source.exists() and text(U.GetDlgItem(app.main, 900)) == '0 / 0',
                    'document deleted after explicit test-only attribute release')
        record(results, 'permanent_delete_readonly_document', {'readonly_not_forced': True,
               'failure_preserves_original_page_rotation': True, 'retry_after_release': True})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--exe', type=Path, default=native.ROOT / 'tests/Kadr-save-delete.exe')
    args = parser.parse_args()
    exe = args.exe.resolve()
    assert exe.is_file() and exe.name.casefold() != 'kadr.exe', 'use the disposable test EXE, never production Kadr.exe'
    work = Path(tempfile.mkdtemp(prefix='kadr-save-delete-'))
    print('TEMP EVIDENCE:', work, flush=True)
    masters = work / 'masters'
    masters.mkdir()
    first = Image.new('RGB', (9, 6))
    first.putdata([((x * 29 + y * 7) % 256, (y * 43 + x * 3) % 256, (x * 17 + y * 31) % 256)
                   for y in range(6) for x in range(9)])
    second = first.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    png, gif, tiff, ppm = [masters / ('master' + ext) for ext in ('.png', '.gif', '.tiff', '.ppm')]
    first.save(png)
    first.save(gif, save_all=True, append_images=[second], duration=10000, loop=0)
    first.save(tiff, save_all=True, append_images=[second], compression='raw')
    first.save(ppm)
    originals = manifest(masters)
    results = {}
    try:
        static_save(exe, work, png, results)
        locked_save(exe, work, png, results)
        for kind, master in [('animated', gif), ('multipage', tiff), ('unencodable', ppm)]:
            protected_source(exe, work, master, results, kind)
        permanent_delete(exe, work, png, results)
        readonly_document_delete(exe, work, tiff, results)
        assert manifest(masters) == originals, 'generated masters must not be modified'
        record(results, 'masters', {'all_generated_originals_unchanged': True})
        print(f'PASS: {len(results)}/{len(results)} save/delete native regressions', flush=True)
    finally:
        (work / 'result.json').write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')


if __name__ == '__main__':
    main()
