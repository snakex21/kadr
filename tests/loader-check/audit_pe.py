"""Reuse retained PE auditor, restricting all writes to loader-check binaries."""
from pathlib import Path
import importlib.util
import json
import sys
sys.dont_write_bytecode = True  # do not create caches beside the reused auditor

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('codec_audit', HERE.parent / 'codec-check' / 'audit_pe.py')
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)
audit.HERE = HERE
names = ['loader-check.exe', 'loader-check-safe.exe', 'sampling-safe.exe']
names += [name for name in ('profile-before.exe', 'profile.exe') if (HERE / name).exists()]
results = [audit.audit(name) for name in names]
(HERE / 'imports.json').write_text(json.dumps(results, indent=2) + '\n', encoding='utf-8')
print('Header/import checks are not proof of execution on XP SP3/Pentium III.')
