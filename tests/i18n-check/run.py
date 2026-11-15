"""Build/run isolated i18n checks: python tests/i18n-check/run.py
Requires Windows, bundled Zig 0.11.0 and Python pefile. No production EXE/INI is
run or changed. GUI tests use an unshown private desktop, never physical input.
"""
from pathlib import Path
import configparser
import csv
import ctypes as C
from ctypes import wintypes as W
import hashlib
import json
import msvcrt
import os
import shutil
import struct
import subprocess
import tempfile
import time
import uuid
import xml.etree.ElementTree as ET
import pefile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SRC = ROOT / 'src'
ZIG = ROOT / 'tools/zig-windows-x86_64-0.11.0/zig.exe'
CODES = 'pl en es fr de pt ru uk it nl cs hu ro tr el ar he hi bn ur zh ja ko id vi th fa ta te mr'.split()
PRIMARY = [0x15, 9, 10, 12, 7, 0x16, 0x19, 0x22, 0x10, 0x13, 5, 14, 0x18, 0x1f, 8, 1, 13, 0x39, 0x45, 0x20, 4, 0x11, 0x12, 0x21, 0x2a, 0x1e, 0x29, 0x49, 0x4a, 0x4e]
NAMES = ['Polski', 'English', 'Español', 'Français', 'Deutsch', 'Português', 'Русский', 'Українська', 'Italiano', 'Nederlands', 'Čeština', 'Magyar', 'Română', 'Türkçe', 'Ελληνικά', 'العربية', 'עברית', 'हिन्दी', 'বাংলা', 'اردو', '中文', '日本語', '한국어', 'Bahasa Indonesia', 'Tiếng Việt', 'ไทย', 'فارسی', 'தமிழ்', 'తెలుగు', 'मराठी']
FONTS = { 'ja': 'MS UI Gothic', 'zh': 'SimSun', 'ko': 'Gulim', 'hi': 'Mangal', 'mr': 'Mangal', 'bn': 'Vrinda', 'ta': 'Latha', 'te': 'Gautami' }
RESULT = {}
U, K, A = C.windll.user32, C.windll.kernel32, C.windll.advapi32
U.SendMessageW.argtypes = [W.HWND, W.UINT, W.WPARAM, W.LPARAM]
U.SendMessageW.restype = W.LPARAM
U.PostMessageW.argtypes = [W.HWND, W.UINT, W.WPARAM, W.LPARAM]
U.GetDlgItem.argtypes = [W.HWND, C.c_int]
U.GetDlgItem.restype = W.HWND
U.IsWindow.argtypes = [W.HWND]
U.GetClassNameW.argtypes = [W.HWND, W.LPWSTR, C.c_int]
U.GetWindowThreadProcessId.argtypes = [W.HWND, C.POINTER(W.DWORD)]
U.GetWindowTextW.argtypes = [W.HWND, W.LPWSTR, C.c_int]
U.CreateDesktopW.argtypes = [W.LPCWSTR, W.LPCWSTR, C.c_void_p, W.DWORD, W.DWORD, C.c_void_p]
U.CreateDesktopW.restype = W.HANDLE
U.CloseDesktop.argtypes = [W.HANDLE]
CALLBACK = C.WINFUNCTYPE(W.BOOL, W.HWND, W.LPARAM)
U.EnumDesktopWindows.argtypes = [W.HANDLE, CALLBACK, W.LPARAM]
K.SetFileAttributesW.argtypes = [W.LPCWSTR, W.DWORD]
K.CloseHandle.argtypes = [W.HANDLE]
A.OpenProcessToken.argtypes = [W.HANDLE, W.DWORD, C.POINTER(W.HANDLE)]
A.GetTokenInformation.argtypes = [W.HANDLE, C.c_int, C.c_void_p, W.DWORD, C.POINTER(W.DWORD)]


class STARTUPINFO(C.Structure):
    _fields_ = [('cb', W.DWORD), ('lpReserved', W.LPWSTR), ('lpDesktop', W.LPWSTR), ('lpTitle', W.LPWSTR), ('dwX', W.DWORD), ('dwY', W.DWORD), ('dwXSize', W.DWORD), ('dwYSize', W.DWORD), ('dwXCountChars', W.DWORD), ('dwYCountChars', W.DWORD), ('dwFillAttribute', W.DWORD), ('dwFlags', W.DWORD), ('wShowWindow', W.WORD), ('cbReserved2', W.WORD), ('lpReserved2', C.c_void_p), ('hStdInput', W.HANDLE), ('hStdOutput', W.HANDLE), ('hStdError', W.HANDLE)]


class PROCESS_INFORMATION(C.Structure):
    _fields_ = [('hProcess', W.HANDLE), ('hThread', W.HANDLE), ('dwProcessId', W.DWORD), ('dwThreadId', W.DWORD)]


K.CreateProcessW.argtypes = [W.LPCWSTR, W.LPWSTR, C.c_void_p, C.c_void_p, W.BOOL, W.DWORD, C.c_void_p, W.LPCWSTR, C.POINTER(STARTUPINFO), C.POINTER(PROCESS_INFORMATION)]
K.GetExitCodeProcess.argtypes = [W.HANDLE, C.POINTER(W.DWORD)]
K.WaitForSingleObject.argtypes = [W.HANDLE, W.DWORD]
K.TerminateProcess.argtypes = [W.HANDLE, W.UINT]


class DesktopProcess:
    """subprocess.STARTUPINFO does not pass lpDesktop to CreateProcess.
    Use the native structure so the selector never appears on the user desktop.
    """
    def __init__(self, exe, cwd, desktop_name):
        self.files = [open(os.devnull, 'rb'), tempfile.TemporaryFile(), tempfile.TemporaryFile()]
        handles = [msvcrt.get_osfhandle(f.fileno()) for f in self.files]
        info = STARTUPINFO()
        info.cb = C.sizeof(info)
        info.lpDesktop = 'winsta0\\' + desktop_name
        info.dwFlags = 0x100  # STARTF_USESTDHANDLES
        info.hStdInput, info.hStdOutput, info.hStdError = handles
        process = PROCESS_INFORMATION()
        args = C.create_unicode_buffer(subprocess.list2cmdline([str(exe), '--choose']))
        try:
            for handle in handles:
                os.set_handle_inheritable(handle, True)
            assert K.CreateProcessW(str(exe), args, None, None, True, 0, None, str(cwd), C.byref(info), C.byref(process)), C.WinError()
        finally:
            for handle in handles:
                os.set_handle_inheritable(handle, False)
        self._handle, self.pid, self.returncode = process.hProcess, process.dwProcessId, None
        K.CloseHandle(process.hThread)

    def poll(self):
        code = W.DWORD()
        assert K.GetExitCodeProcess(self._handle, C.byref(code))
        self.returncode = None if code.value == 259 else code.value
        return self.returncode

    def communicate(self, timeout):
        assert K.WaitForSingleObject(self._handle, int(timeout * 1000)) == 0, 'probe did not exit after closing selector'
        self.poll()
        for file in self.files[1:]:
            file.seek(0)
        return tuple(file.read() for file in self.files[1:])

    def kill(self):
        assert K.TerminateProcess(self._handle, 1)

    def close(self):
        K.CloseHandle(self._handle)
        for file in self.files:
            file.close()


def command(args, cwd=SRC, **kw):
    return subprocess.run([str(x) for x in args], cwd=cwd, check=True, **kw)


def xp_headers(path):
    # Same build-time correction as tools/fix_xp_header.zig, only our test EXEs.
    with path.open('r+b') as file:
        file.seek(0x3c)
        pe = struct.unpack('<I', file.read(4))[0]
        for offset in (40, 48):
            file.seek(pe + 24 + offset)
            file.write(struct.pack('<HH', 5, 1))
        file.seek(pe + 24 + 64)
        file.write(bytes(4))


def build():
    common = ['--main-pkg-path', '..', '-I../tools/zig-windows-x86_64-0.11.0/lib/libc/include/any-windows-any', '-target', 'x86-windows.xp-gnu', '-mcpu=pentium3', '-fsingle-threaded', '-fno-stack-check', '-fno-stack-protector', '-lkernel32', '-luser32', '-lgdi32']
    command([ZIG, 'test', '../tests/i18n-check/unit.zig', *common, '-O', 'ReleaseSafe', '--test-no-exec', '-femit-bin=../tests/i18n-check/unit.exe'])
    command([HERE / 'unit.exe'], cwd=HERE)
    for name in ('probe', 'app'):
        command([ZIG, 'build-exe', f'../tests/i18n-check/{name}.zig', '../assets/kadr-res.o', *common, '-O', 'ReleaseSmall', '-fstrip', '--subsystem', 'windows', f'-femit-bin=../tests/i18n-check/{name}.exe'])
        xp_headers(HERE / f'{name}.exe')
    RESULT['unit_tests'] = 3


def audit(path):
    p = pefile.PE(str(path))
    assert p.FILE_HEADER.Machine == 0x14c
    h = p.OPTIONAL_HEADER
    assert (h.MajorOperatingSystemVersion, h.MinorOperatingSystemVersion) == (5, 1)
    assert (h.MajorSubsystemVersion, h.MinorSubsystemVersion) == (5, 1)
    assert h.DATA_DIRECTORY[9].VirtualAddress == 0, 'TLS unexpectedly added'
    # Deliberately exhaustive for this module, not just a modern-API denylist.
    # HeapAlloc/GetProcessHeap: L() widens each UTF-8 catalog text once (XP-safe).
    allowed = {
        'KERNEL32.dll': set('CloseHandle CreateFileW ExitProcess GetCommandLineW GetCurrentProcess GetCurrentProcessId GetCurrentThreadId GetLastError GetModuleFileNameW GetModuleHandleW GetPrivateProfileStringW GetProcessHeap GetStdHandle GetSystemTimeAsFileTime GetTickCount GetUserDefaultUILanguage HeapAlloc QueryPerformanceCounter WriteFile WritePrivateProfileStringW'.split()),
        'USER32.dll': set('CreateWindowExW DialogBoxIndirectParamW DrawFocusRect DrawTextW EndDialog FillRect GetSysColor GetSysColorBrush GetWindowLongW MapDialogRect MessageBoxW SendMessageW SetWindowLongW SetWindowTextW'.split()),
        'GDI32.dll': set('CreateFontW DeleteObject SelectObject SetBkMode SetTextColor'.split()),
    }
    imports = {}
    for desc in p.DIRECTORY_ENTRY_IMPORT:
        dll = desc.dll.decode('ascii')
        names = {item.name.decode('ascii') for item in desc.imports}
        assert dll.upper() in {x.upper() for x in allowed}, (path, dll)
        permitted = next(v for k, v in allowed.items() if k.upper() == dll.upper())
        assert names <= permitted, (path, dll, sorted(names - permitted))
        imports[dll] = sorted(names)
    assert not getattr(p, 'DIRECTORY_ENTRY_DELAY_IMPORT', []), 'unexpected delay imports'
    resource = next(e for e in p.DIRECTORY_ENTRY_RESOURCE.entries if e.id == 24)
    ident = next(e for e in resource.directory.entries if e.id == 1)
    data = ident.directory.entries[0].data.struct
    manifest = p.get_data(data.OffsetToData, data.Size)
    xml = ET.fromstring(manifest)
    level = xml.find('.//{urn:schemas-microsoft-com:asm.v3}requestedExecutionLevel')
    assert level is not None and level.attrib == {'level': 'asInvoker', 'uiAccess': 'false'}
    assert manifest == (ROOT / 'assets/kadr.manifest').read_bytes()
    p.close()
    return {'x86': True, 'xp_headers': True, 'tls': False, 'crt': False, 'asInvoker': True, 'imports': imports}


def decode_wide(value):
    return b''.join(struct.pack('<H', int(value[n:n+4], 16)) for n in range(0, len(value), 4)).decode('utf-16-le')


def parse(stdout):
    data = dict(line.split('=', 1) for line in stdout.decode('utf-8').splitlines())
    for name in ('path', 'font', 'open', 'class', 'filter'):
        data[name] = decode_wide(data[name])
        assert data['sentinel_' + name] == '0'
    assert data['class'] == 'Kadr.PrintPreview.1'
    assert data['filter'] == 'Obrazy\0*.png\0\0'
    assert data['catalog_valid'] == '1'
    assert data['open'] == data['open_utf8']
    return data


def run(exe, cwd):
    result = command([exe], cwd=cwd, capture_output=True, timeout=20)
    return parse(result.stdout)


def ini(path, code):
    path.write_text('[General]\r\nLanguage=' + code + '\r\n', encoding='utf-16')


def saved(path):
    raw = path.read_bytes()
    text = raw.decode('utf-16') if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else raw.decode('ascii')
    parser = configparser.ConfigParser()
    parser.read_string(text)
    return parser['General']['Language']


def check(data, code, path, error=False):
    assert data['code'] == code, data
    assert int(data['index']) == CODES.index(code)
    assert bool(int(data['rtl'])) == (code in ('ar', 'he', 'ur', 'fa'))
    assert data['font'] == FONTS.get(code, 'Tahoma')
    assert bool(int(data['error'])) == error, data
    assert Path(data['path']) == path, data


def windows(desktop, pid):
    found = []
    def each(hwnd, _):
        owner = W.DWORD()
        U.GetWindowThreadProcessId(hwnd, C.byref(owner))
        if owner.value == pid:
            name = C.create_unicode_buffer(256)
            U.GetClassNameW(hwnd, name, len(name))
            if name.value == '#32770':
                found.append(hwnd)
        return True
    # An as-yet empty desktop can return zero while the child is starting.
    U.EnumDesktopWindows(desktop, CALLBACK(each), 0)
    return found


def wait(process, test, why):
    until = time.monotonic() + 15
    while time.monotonic() < until:
        value = test()
        if value:
            return value
        if process.poll() is not None:
            raise AssertionError(f'probe exited {process.returncode} while waiting: {why}')
        time.sleep(.03)
    raise AssertionError('timeout: ' + why)


def selector(exe, cwd, path, desktop, desktop_name, mode):
    ini(path, 'en')
    if mode == 'readonly':
        assert K.SetFileAttributesW(str(path), 1)
    process = DesktopProcess(exe, cwd, desktop_name)
    try:
        dlg = wait(process, lambda: next((h for h in windows(desktop, process.pid) if U.GetDlgItem(h, 100)), None), 'language selector')
        token = W.HANDLE()
        assert A.OpenProcessToken(W.HANDLE(int(process._handle)), 8, C.byref(token))
        try:
            enabled, size = W.DWORD(), W.DWORD()
            if A.GetTokenInformation(token, 24, C.byref(enabled), C.sizeof(enabled), C.byref(size)):
                assert enabled.value == 0, 'UAC virtualization must be disabled'
                RESULT['runtime_token_virtualization_disabled'] = True
            else:
                RESULT['runtime_token_virtualization_disabled'] = 'unavailable on this OS (XP has no UAC)'
        finally:
            K.CloseHandle(token)
        listing = U.GetDlgItem(dlg, 100)
        assert U.SendMessageW(listing, 0x18b, 0, 0) == 30  # LB_GETCOUNT
        assert U.SendMessageW(listing, 0x188, 0, 0) == 1  # LB_GETCURSEL
        for index, native in enumerate(NAMES):
            label = C.create_unicode_buffer(128)
            assert U.SendMessageW(listing, 0x189, index, C.addressof(label)) == len(native)
            assert label.value == native
        U.SendMessageW(listing, 0x186, CODES.index('ja'), 0)  # LB_SETCURSEL
        if mode in ('cancel', 'close'):
            assert U.PostMessageW(dlg, 0x10 if mode == 'close' else 0x111, 2 if mode == 'cancel' else 0, 0)
        else:
            assert U.PostMessageW(dlg, 0x111, 1, 0)
            message = wait(process, lambda: next((h for h in windows(desktop, process.pid) if h != dlg), None), 'save/restart message')
            assert saved(path) == ('en' if mode == 'readonly' else 'ja')
            # A single-button MB_OK can use IDCANCEL internally on newer Windows.
            button = wait(process, lambda: U.GetDlgItem(message, 1) or U.GetDlgItem(message, 2), 'message OK button')
            assert U.PostMessageW(button, 0xf5, 0, 0)  # BM_CLICK, no physical input
            if mode == 'readonly':
                wait(process, lambda: not U.IsWindow(message), 'error message dismissed')
                assert U.PostMessageW(dlg, 0x111, 2, 0)
        stdout, stderr = process.communicate(timeout=15)
        assert process.returncode == 0, stderr
        check(parse(stdout), 'en', path, error=(mode == 'readonly'))
        assert saved(path) == ('ja' if mode == 'save' else 'en')
    finally:
        if process.poll() is None:
            process.kill()
            process.communicate(timeout=10)
        process.close()
        K.SetFileAttributesW(str(path), 0x80)
    if mode == 'save':
        check(run(exe, cwd), 'ja', path)


def runtime():
    os_language = K.GetUserDefaultUILanguage() & 0x3ff
    detected = CODES[PRIMARY.index(os_language)] if os_language in PRIMARY else 'en'
    with tempfile.TemporaryDirectory(prefix='Kadr-i18n-') as temp:
        temp = Path(temp)
        directory = temp / 'portable-測試-русский'
        directory.mkdir()
        exe = directory / 'i18n-probe.exe'
        shutil.copy2(HERE / 'probe.exe', exe)
        path = directory / 'Kadr.ini'
        cwd = temp / 'unrelated-cwd'
        cwd.mkdir()
        decoy = cwd / 'Kadr.ini'
        ini(decoy, 'ja' if detected != 'ja' else 'pl')
        decoy_hash = hashlib.sha256(decoy.read_bytes()).hexdigest()
        first = run(exe, cwd)
        check(first, detected, path)
        assert saved(path) == detected
        check(run(exe, temp), detected, path)
        RESULT['detected_code'] = detected
        RESULT['catalog_entries'] = int(first['catalog_entries'])
        RESULT['first_start_persist_restart_unicode_path_cwd'] = True
        for code in CODES:
            ini(path, code)
            check(run(exe, cwd), code, path)
            assert saved(path) == code
        RESULT['selected_catalog_and_metadata_languages'] = 30
        for invalid in ('', 'xx', 'eng', 'pt-BR', 'x' * 100, '日本語'):
            ini(path, invalid)
            check(run(exe, cwd), detected, path)
            assert saved(path) == detected
        path.write_text('[Other]\nValue=1\n', encoding='ascii')
        check(run(exe, cwd), detected, path)
        assert saved(path) == detected
        ini(path, 'PT')
        check(run(exe, cwd), 'pt', path)
        assert saved(path) == 'pt'
        RESULT['invalid_absent_code_repaired_case_canonicalized'] = True
        ini(path, 'de')
        try:
            assert K.SetFileAttributesW(str(path), 1)
            check(run(exe, cwd), 'de', path, error=True)
            assert saved(path) == 'de'
        finally:
            K.SetFileAttributesW(str(path), 0x80)
        RESULT['readonly_ini_error'] = True
        # Deny only writes to this disposable directory, leaving WRITE_DAC and
        # read/execute intact. Restore its ACL even if the test fails.
        path.unlink()
        who = command(['whoami', '/user', '/fo', 'csv', '/nh'], cwd=HERE, capture_output=True).stdout.decode('utf-8').strip()
        sid = next(csv.reader([who]))[-1]
        try:
            command(['icacls', directory, '/deny', f'*{sid}:(WD,AD,WEA,WA)'], cwd=HERE, capture_output=True)
            check(run(exe, cwd), detected, path, error=True)
            assert not path.exists(), 'read-only directory must not create a redirected local INI'
            RESULT['readonly_directory_error_no_fallback'] = True
        finally:
            command(['icacls', directory, '/remove:d', '*' + sid], cwd=HERE, capture_output=True)
        desktop_name = 'Kadr-i18n-' + uuid.uuid4().hex
        desktop = U.CreateDesktopW(desktop_name, None, None, 0, 0x10000000, None)
        assert desktop, 'cannot create private GUI test desktop'
        try:
            for mode in ('save', 'cancel', 'close', 'readonly'):
                selector(exe, cwd, path, desktop, desktop_name, mode)
            RESULT['selector_private_desktop_save_restart_cancel_close_error'] = True
        finally:
            assert U.CloseDesktop(desktop)
        assert hashlib.sha256(decoy.read_bytes()).hexdigest() == decoy_hash
        RESULT['cwd_ini_untouched'] = True


def main():
    build()
    for name in ('app', 'probe'):
        RESULT[name + '_audit'] = audit(HERE / f'{name}.exe')
    runtime()
    RESULT['missing_checks'] = ['Actual Windows XP SP3 runtime/font-pack rendering', 'Final coordinator-integrated Kadr.exe import audit']
    (HERE / 'result.json').write_text(json.dumps(RESULT, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print(json.dumps(RESULT, indent=2, ensure_ascii=True))
    print('PASS: i18n unit, portable configuration, 30-language UTF16/catalog, native selector and PE/manifest checks')


if __name__ == '__main__':
    main()
