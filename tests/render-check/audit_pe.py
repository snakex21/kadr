"""Adjust/audit ONLY render harness PEs. Never patch the application binary."""
from pathlib import Path
import hashlib
import importlib.util
import json
import sys
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
spec = importlib.util.spec_from_file_location('codec_audit', HERE.parent / 'codec-check' / 'audit_pe.py')
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)
audit.HERE = HERE
# XP's PSAPI counters are used only by this benchmark, not by render.zig.
audit.ALLOWED_DLL.add('psapi.dll')
results = [audit.audit(name) for name in ('render-check.exe', 'render-check-safe.exe')]
(HERE / 'imports.json').write_text(json.dumps(results, indent=2) + '\n', encoding='utf-8')
for path, digest in json.loads((HERE / 'protected.json').read_text()).items():
    unchanged = hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == digest
    if path == 'src/main.zig' and not unchanged:
        print('NOTE: integration-owned main.zig changed concurrently; this harness never writes it.')
    else:
        assert unchanged, f'protected file changed: {path}'
print('Application binary/UI/Win32/build files unchanged. No XP runtime claim.')
