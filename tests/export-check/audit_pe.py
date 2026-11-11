"""Bounded PE import/header check for the dedicated export test binaries."""
import json
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parent

def audit(path):
    data = path.read_bytes()
    pe = struct.unpack_from('<I', data, 0x3c)[0]
    assert data[pe:pe+4] == b'PE\0\0'
    machine, sections = struct.unpack_from('<HH', data, pe+4)
    assert machine == 0x14c, hex(machine)
    optional = pe+24
    assert struct.unpack_from('<H', data, optional)[0] == 0x10b
    optional_size = struct.unpack_from('<H', data, pe+20)[0]
    section_table = optional+optional_size
    ranges = []
    for i in range(sections):
        s = section_table+i*40
        size, va, raw_size, raw = struct.unpack_from('<IIII', data, s+8)
        ranges.append((va, max(size, raw_size), raw))
    def off(rva):
        for va, size, raw in ranges:
            if va <= rva < va+size:
                return raw+rva-va
        raise ValueError(hex(rva))
    def z(offset):
        return data[offset:data.index(b'\0', offset)].decode('ascii')
    rva, _ = struct.unpack_from('<II', data, optional+104)
    imports = {}
    cursor = off(rva)
    while True:
        lookup, _, _, name, first = struct.unpack_from('<IIIII', data, cursor)
        if not any((lookup, name, first)):
            break
        dll = z(off(name)).lower()
        names = []
        thunk = off(lookup or first)
        while True:
            value = struct.unpack_from('<I', data, thunk)[0]
            if not value:
                break
            names.append('#'+str(value & 0xffff) if value & 0x80000000 else z(off(value)+2))
            thunk += 4
        imports[dll] = sorted(names)
        cursor += 20
    assert struct.unpack_from('<HH', data, optional+40) <= (5, 1)
    assert struct.unpack_from('<HH', data, optional+48) <= (5, 1)
    forbidden = {'InitializeSRWLock', 'AcquireSRWLockExclusive', 'ReleaseSRWLockExclusive', 'WakeByAddressSingle', 'CancelIoEx', 'InitializeConditionVariable', 'SleepConditionVariableCS', 'GetTickCount64', 'InitializeCriticalSectionEx', 'GetFileInformationByHandleEx', 'GetFinalPathNameByHandleW', 'SetProcessDPIAware', 'SetThreadErrorMode', 'GetSystemTimePreciseAsFileTime', 'CreateFile2', 'WaitOnAddress', 'GetDpiForWindow', 'SetThreadDpiAwarenessContext'}
    assert not any(n in forbidden for names in imports.values() for n in names)
    assert not any(dll.startswith(('api-ms-', 'ext-ms-')) for dll in imports)
    return {'machine':'x86', 'os_version':list(struct.unpack_from('<HH', data, optional+40)), 'subsystem_version':list(struct.unpack_from('<HH', data, optional+48)), 'imports':imports}

names = ('dialog.exe', 'dialog-small.exe', 'unit.exe')
if '--fix' in sys.argv:
    # Zig 0.11/lld declares PE version 6.0 even for .xp. Like the existing
    # production build fix, correct ONLY our three dedicated test binaries.
    for name in names:
        path = ROOT / name
        data = bytearray(path.read_bytes())
        pe = struct.unpack_from('<I', data, 0x3c)[0]
        assert data[pe:pe+4] == b'PE\0\0'
        assert struct.unpack_from('<H', data, pe+4)[0] == 0x14c
        struct.pack_into('<HH', data, pe+24+40, 5, 1)
        struct.pack_into('<HH', data, pe+24+48, 5, 1)
        struct.pack_into('<I', data, pe+24+64, 0)
        path.write_bytes(data)
result = {name: audit(ROOT / name) for name in names}
(ROOT / 'imports.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
for name, info in result.items():
    print(name, info['machine'], 'OS', info['os_version'], 'subsystem', info['subsystem_version'], 'imports', sum(map(len, info['imports'].values())))
