"""Audit ONLY test PEs; fix Zig's test PE subsystem minor to XP 5.1.
No production binaries, fixture files or existing app windows are accessed.
This is an import/header check, not an actual Windows XP runtime claim.
"""
from pathlib import Path
import json
import pefile

HERE = Path(__file__).resolve().parent
FORBIDDEN = {'GetTickCount64', 'InitializeCriticalSectionEx', 'InitializeSRWLock',
             'AcquireSRWLockExclusive', 'ReleaseSRWLockExclusive', 'WaitOnAddress',
             'GetDpiForWindow', 'SetProcessDpiAwarenessContext', 'CreateFile2',
             'CancelIoEx', 'GetSystemTimePreciseAsFileTime', 'SetThreadErrorMode',
             'GetFinalPathNameByHandleW', 'GetFileInformationByHandleEx'}
ALLOWED = {'kernel32.dll', 'user32.dll', 'gdi32.dll', 'gdiplus.dll', 'winspool.drv',
           'comdlg32.dll', 'comctl32.dll', 'msvcrt.dll', 'ntdll.dll'}
results = []
for name in ('printing-tests.exe', 'layout-tests.exe', 'Kadr-print-options.exe'):
    path = HERE / name
    p = pefile.PE(str(path))
    assert p.FILE_HEADER.Machine == 0x14C, name
    # Zig 0.11 emits 5.2 for this target; XP's loader requires <= 5.1.
    for field in ('MajorOperatingSystemVersion', 'MajorSubsystemVersion'):
        setattr(p.OPTIONAL_HEADER, field, 5)
    for field in ('MinorOperatingSystemVersion', 'MinorSubsystemVersion'):
        setattr(p.OPTIONAL_HEADER, field, 1)
    data = p.write()
    p.close()  # Release pefile's read-only mmap before overwriting on Windows.
    path.write_bytes(data)
    p = pefile.PE(str(path))
    imports = {}
    for desc in getattr(p, 'DIRECTORY_ENTRY_IMPORT', []):
        dll = desc.dll.decode('ascii').lower()
        assert dll in ALLOWED, (name, dll)
        names = [s.name.decode('ascii') for s in desc.imports if s.name]
        assert not FORBIDDEN.intersection(names), (name, FORBIDDEN.intersection(names))
        imports[dll] = names
    results.append({'file': name, 'machine': 'x86', 'subsystem': '5.1', 'os': '5.1', 'imports': imports})
    print(f'PASS: {name}: x86, XP 5.1 headers, no known post-XP imports')
    p.close()
(HERE / 'imports.json').write_text(json.dumps(results, indent=2) + '\n', encoding='utf-8')
print('NOTE: native Windows host checks; actual XP SP3 runtime not verified.')
