"""Adjust only harness PE headers to XP 5.1 and audit their imports.

Zig 0.11 emits subsystem 6.0 even for x86-windows.xp-gnu. ReleaseSmall is
our XP candidate. ReleaseSafe is an additional host-Windows safety check:
Zig's diagnostic machinery may import post-XP APIs in that configuration.
"""
from pathlib import Path
import struct

HERE = Path(__file__).resolve().parent


def audit(filename):
    path = HERE / filename
    data = bytearray(path.read_bytes())
    pe = struct.unpack_from("<I", data, 0x3c)[0]
    machine, section_count = struct.unpack_from("<HH", data, pe + 4)
    optional_size = struct.unpack_from("<H", data, pe + 20)[0]
    optional = pe + 24
    before = struct.unpack_from("<HH", data, optional + 48)
    struct.pack_into("<HH", data, optional + 40, 5, 1)
    struct.pack_into("<HH", data, optional + 48, 5, 1)
    path.write_bytes(data)
    sections = [struct.unpack_from("<IIII", data, optional + optional_size + i * 40 + 8)
                for i in range(section_count)]

    def offset(rva):
        return next(raw + rva - address for size, address, raw_size, raw in sections
                    if address <= rva < address + max(size, raw_size))

    index = offset(struct.unpack_from("<I", data, optional + 104)[0])
    dlls, functions = [], []
    while any(data[index:index + 20]):
        original, _, _, name, thunk = struct.unpack_from("<IIIII", data, index)
        start = offset(name)
        dlls.append(data[start:data.index(0, start)].decode())
        entry = offset(original or thunk)
        while (value := struct.unpack_from("<I", data, entry)[0]):
            if not value & 0x80000000:
                start = offset(value) + 2
                functions.append(data[start:data.index(0, start)].decode())
            entry += 4
        index += 20

    assert machine == 0x14c, "not x86"
    assert not any("msvcr" in dll.lower() or "ucrt" in dll.lower() or "msvcp" in dll.lower()
                   for dll in dlls), "executable imports a CRT"
    post_xp = {"AcquireSRWLockExclusive", "ReleaseSRWLockExclusive", "GetTickCount64",
               "GetFinalPathNameByHandleW", "InitializeCriticalSectionEx", "K32GetModuleFileNameExW"}
    if filename == "image-check.exe":
        assert not post_xp.intersection(functions), "post-XP import in ReleaseSmall"
        assert {dll.lower() for dll in dlls} <= {"kernel32.dll", "gdiplus.dll", "user32.dll", "ole32.dll", "ntdll.dll"}
        print(filename, "PASS: x86, PE OS/subsystem 5.1, no CRT or listed post-XP imports")
    else:
        print(filename, "PASS: x86, no CRT; host-Windows safety build, not an XP compatibility claim")
    print("  subsystem:", before, "-> (5, 1); DLLs:", ", ".join(dlls))
    print("  imports:", ", ".join(functions))


if __name__ == "__main__":
    for executable in ("image-check.exe", "image-check-safe.exe"):
        audit(executable)
