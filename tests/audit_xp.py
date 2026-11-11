"""Audit PE loader-level XP requirements. Does not replace an XP runtime test."""
from pathlib import Path
import argparse
import pefile

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--exe', type=Path, default=root / 'Kadr.exe')
args = parser.parse_args()
paths = [args.exe.resolve(), *sorted((root / 'deps').rglob('*.dll'))]
forbidden_dlls = ('api-ms-', 'ext-ms-', 'ucrtbase', 'vcruntime140', 'msvcp140')
forbidden_apis = {
    'GetTickCount64', 'InitializeCriticalSectionEx', 'InitializeSRWLock',
    'AcquireSRWLockExclusive', 'ReleaseSRWLockExclusive', 'WaitOnAddress',
    'WakeByAddressSingle', 'GetFinalPathNameByHandleW', 'GetFileInformationByHandleEx',
    'GetSystemTimePreciseAsFileTime', 'SetThreadErrorMode', 'CancelIoEx',
    'CreateFile2', 'GetDpiForWindow', 'SetProcessDpiAwarenessContext',
    'InitializeConditionVariable', 'SleepConditionVariableCS',
}
errors = []
for path in paths:
    p = pefile.PE(str(path))
    version = (p.OPTIONAL_HEADER.MajorSubsystemVersion, p.OPTIONAL_HEADER.MinorSubsystemVersion)
    os_version = (p.OPTIONAL_HEADER.MajorOperatingSystemVersion, p.OPTIONAL_HEADER.MinorOperatingSystemVersion)
    if p.FILE_HEADER.Machine != 0x14c:
        errors.append(f'{path.name}: not x86')
    if version > (5, 1) or os_version > (5, 1):
        errors.append(f'{path.name}: loader version newer than XP: {version}/{os_version}')
    imports = []
    for desc in getattr(p, 'DIRECTORY_ENTRY_IMPORT', []):
        dll = desc.dll.decode('ascii')
        if dll.lower().startswith(forbidden_dlls):
            errors.append(f'{path.name}: incompatible DLL {dll}')
        names = [s.name.decode('ascii') for s in desc.imports if s.name]
        bad = forbidden_apis.intersection(names)
        if bad:
            errors.append(f'{path.name}: incompatible APIs: {sorted(bad)}')
        imports.append(f'{dll}({len(names)})')
    print(f'{path.relative_to(root)}: x86, subsystem {version}, OS {os_version}, ' + ', '.join(imports))
print('NOTE: denylist/import/header audit, not proof of full XP compatibility; XP SP3 runtime test still required.')
if errors:
    raise SystemExit('\n'.join(errors))
print('PASS: x86 PE headers and known post-XP API/DLL checks')
