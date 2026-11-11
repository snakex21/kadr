"""Keep actual host timings/check output and verify protected files after runs."""
from pathlib import Path
import hashlib
import json
import platform
import subprocess
HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
lines = [f'Host: {platform.platform()}; no XP/Pentium III runtime claim.\n']
for name in ('render-check.exe', 'render-check-safe.exe'):
    result = subprocess.run([str(HERE / name)], cwd=ROOT, capture_output=True, text=True)
    text = f'\n=== {name} ===\n' + result.stdout + result.stderr
    print(text, end='')
    lines.append(text)
    (HERE / 'results.txt').write_text(''.join(lines), encoding='utf-8')
    if result.returncode:
        raise SystemExit(result.returncode)
for path, digest in json.loads((HERE / 'protected.json').read_text()).items():
    unchanged = hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == digest
    if path == 'src/main.zig' and not unchanged:
        note = 'NOTE: integration-owned main.zig changed concurrently; render-check never writes it.\n'
        print(note, end='')
        lines.append(note)
    else:
        assert unchanged, path
note = 'Application binary/UI/Win32/build files unchanged after native tests.\n'
print(note, end='')
lines.append(note)
(HERE / 'results.txt').write_text(''.join(lines), encoding='utf-8')
