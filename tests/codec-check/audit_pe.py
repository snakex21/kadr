"""Patch ONLY codec-check test PE declarations, then audit their imports.
No access to Kadr.exe, build.cmd, UI, or other retained test binaries.
XP header/import evidence is not an XP SP3 hardware/runtime certification.
"""
from pathlib import Path
import hashlib
import json
import struct

HERE = Path(__file__).resolve().parent
FORBIDDEN_DLL = ('api-ms-', 'ext-ms-', 'ucrt', 'vcruntime', 'msvcp', 'msvcr')
POST_XP = {
    'GetTickCount64', 'InitializeCriticalSectionEx', 'InitializeSRWLock',
    'AcquireSRWLockExclusive', 'ReleaseSRWLockExclusive', 'AcquireSRWLockShared',
    'ReleaseSRWLockShared', 'WaitOnAddress', 'WakeByAddressSingle',
    'GetFinalPathNameByHandleW', 'GetFileInformationByHandleEx',
    'GetSystemTimePreciseAsFileTime', 'SetThreadErrorMode', 'CancelIoEx',
    'CreateFile2', 'GetDpiForWindow', 'SetProcessDpiAwarenessContext',
    'InitializeConditionVariable', 'SleepConditionVariableCS',
    'K32GetModuleFileNameExW', 'SetFileInformationByHandle',
}
ALLOWED_DLL = {'kernel32.dll', 'ntdll.dll', 'gdiplus.dll', 'user32.dll', 'gdi32.dll', 'ole32.dll'}


def audit(name):
    path = HERE / name
    data = bytearray(path.read_bytes())
    assert data[:2] == b'MZ'
    pe = struct.unpack_from('<I', data, 60)[0]
    assert data[pe:pe+4] == b'PE\x00\x00'
    machine, sections = struct.unpack_from('<HH', data, pe+4)
    optional_size = struct.unpack_from('<H', data, pe+20)[0]
    optional = pe + 24
    assert machine == 0x14c and struct.unpack_from('<H', data, optional)[0] == 0x10b, 'not x86 PE32'
    # Zig 0.11/lld declares subsystem 6.0 despite .xp. This changes headers
    # only; all actual imports are checked below, never removed or rewritten.
    struct.pack_into('<HH', data, optional+40, 5, 1)
    struct.pack_into('<HH', data, optional+48, 5, 1)
    path.write_bytes(data)
    section_table = [struct.unpack_from('<IIII', data, optional+optional_size+i*40+8)
                     for i in range(sections)]

    def offset(rva):
        return next(raw+rva-address for size, address, raw_size, raw in section_table
                    if address <= rva < address + max(size, raw_size))

    def cstring(rva):
        start = offset(rva)
        return data[start:data.index(0, start)].decode('ascii')

    index = offset(struct.unpack_from('<I', data, optional+104)[0])
    imports = {}
    while any(data[index:index+20]):
        original, _, _, dll_name, thunk = struct.unpack_from('<IIIII', data, index)
        dll = cstring(dll_name).lower()
        entry = offset(original or thunk)
        functions = []
        while (value := struct.unpack_from('<I', data, entry)[0]):
            functions.append(f'ordinal:{value & 0xffff}' if value & 0x80000000 else cstring(value+2))
            entry += 4
        imports[dll] = functions
        index += 20
    safe = '-safe' in name
    assert not any(dll.startswith(FORBIDDEN_DLL) for dll in imports), f'{name}: CRT dependency'
    if not safe:
        assert set(imports) <= ALLOWED_DLL, f'{name}: unexpected DLL'
        assert not POST_XP.intersection(f for functions in imports.values() for f in functions), f'{name}: post-XP API'
    result = dict(file=name, sha256=hashlib.sha256(data).hexdigest(), machine='x86',
                  os=[5, 1], subsystem=[5, 1], no_crt=True, xp_import_candidate=not safe, imports=imports)
    print(f'{name}: PASS x86 PE32, OS/subsystem 5.1, no CRT; ' +
          ('host safety check only' if safe else 'known post-XP imports absent'))
    print('  ' + ', '.join(f'{dll}({len(names)})' for dll, names in imports.items()))
    return result


if __name__ == '__main__':
    report = [audit(name) for name in ('codec-check.exe', 'codec-check-safe.exe',
                                     'legacy-check.exe', 'legacy-check-safe.exe')]
    (HERE / 'imports.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print('NOTE: XP SP3/Pentium III runtime still needs testing; import/header checks alone are not proof.')
