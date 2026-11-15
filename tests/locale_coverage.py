"""Require catalog coverage for application UI literals (not native identifiers)."""
import ast
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
STRING = r'"((?:\\.|[^"\\])*)"'

def decode(value):
    return ast.literal_eval('"' + value + '"')

words = (ROOT / 'src/locale_words.zig').read_text(encoding='utf-8')
polish = words.split('// pl\n', 1)[1].split('// en\n', 1)[0]
known = {decode(m.group(1)) for m in re.finditer(STRING, polish)}
aliases = (ROOT / 'src/locale_aliases.zig').read_text(encoding='utf-8')
for pattern in [r'\b(?:a|d|e|fixed)\(' + STRING, r'\.source\s*=\s*' + STRING, r'\ball\(\.\{\s*' + STRING]:
    known.update(decode(m.group(1)) for m in re.finditer(pattern, aliases))


def test_ranges(text):
    ranges = []
    for match in re.finditer(r'(?m)^test\s+' + STRING + r'\s*\{', text):
        start = match.start()
        i, depth = match.end(), 1
        while depth and i < len(text):
            ch = text[i]
            if text.startswith('//', i):
                i = text.find('\n', i)
                if i < 0:
                    break
                continue
            if ch in ('"', "'"):
                quote = ch
                i += 1
                while i < len(text):
                    if text[i] == '\\':
                        i += 2
                    elif text[i] == quote:
                        i += 1
                        break
                    else:
                        i += 1
                continue
            if ch == '{':
                depth += 1
            elif ch == '}':
                depth -= 1
            i += 1
        ranges.append((start, i))
    return ranges


def technical(value):
    if not value or value in {'STATIC', 'BUTTON', 'EDIT', 'COMBOBOX', 'LISTBOX', 'msctls_trackbar32', 'tooltips_class32', 'open', 'explorer.exe', 'kdr', 'kex', 'Zoom', '1:1', 'PNG', 'JPEG', 'BMP', 'TIFF', 'GIF', 'JPG', 'TGA', 'DJVU', 'WINSPOOL', 'kwp', 'kadr-wallpaper-', 'X:', 'Y:', 'Letter', 'Legal', 'Executive', 'Tabloid', 'mm', 'px', '%'}:
        return True
    if value.startswith('Kadr') and not any(c.isspace() for c in value):
        return True
    if value.startswith('--') or '*.' in value or '\x00' in value:
        return True
    if re.fullmatch(r'\.[a-z0-9]+|[0-9\s.,%×x+:/−-]+|[AB][0-9]+|[0-9]+\s*[x×]\s*[0-9]+ (?:cm|in)|B[45] \(ISO\)', value):
        return True
    if re.fullmatch(r'.*\.(?:bmp|png|jpg|tif|ini)', value, re.I):
        return True
    return value in {'\\/:*?"<>|', '/select,"', ' — Kadr', '-export.', 'png', 'jpg', 'bmp', 'tif', 'gif', '…'}

missing = {}
modules = ['main', 'printing', 'ui', 'file_dialog', 'export_dialog', 'file_tools', 'i18n', 'formats', 'editor']
for name in modules:
    path = ROOT / 'src' / (name + '.zig')
    text = path.read_text(encoding='utf-8')
    tests = test_ranges(text)
    for match in re.finditer(r'(?<![\w.])(?:L|i18n\.utf8)\(' + STRING, text):
        if any(a <= match.start() < b for a, b in tests):
            continue
        value = decode(match.group(1))
        if value in known or technical(value):
            continue
        line = text.count('\n', 0, match.start()) + 1
        missing.setdefault(value, []).append(f'src/{name}.zig:{line}')
if missing:
    for value, locations in missing.items():
        print(repr(value), '|', ', '.join(locations))
    raise SystemExit(f'MISSING: {len(missing)} UI literals')
print(f'PASS: {len(modules)} application modules; {len(known)} catalog sources; no untranslated UI literals')

# --- English fallback check -------------------------------------------------
# Resolve the real catalog (tests/i18n-check/catalog_dump.zig prints every
# entry after comptime aliasing) and fail when a non-PL/EN language shows the
# English text, unless that text is listed here as legitimately identical.
CODES = 'pl en es fr de pt ru uk it nl cs hu ro tr el ar he hi bn ur zh ja ko id vi th fa ta te mr'.split()
# Language-neutral by design: identical in every language.
NEUTRAL = {
    'Ctrl+O · F1', 'GIF', '4 × 6 in', '5 × 7 in', '8 × 10 in',
}
# English text -> languages where the same spelling is the native word.
SAME_WORD = {
    'OK': {'fr', 'de', 'pt', 'it', 'nl', 'cs', 'hu', 'ro', 'el', 'ja', 'id', 'vi'},
    'Format': {'fr', 'de', 'ro', 'id'}, '&Format:': {'fr', 'de', 'ro', 'id'},
    'Pause': {'fr', 'de'}, 'Pause (Space)': {'fr', 'de'},
    'Printer': {'nl', 'id'}, 'Printer:': {'nl', 'id'},
    'Orientation': {'fr'}, 'Orientation:': {'fr'},
    'Portrait': {'fr'}, '3:4 portrait': {'fr'}, 'A4 portrait': {'fr'},
    'Color': {'es'}, 'Color:': {'es'},
    'Position': {'fr', 'de'}, 'Position (mm)': {'fr', 'de'}, 'Position (X/Y, mm):': {'fr', 'de'},
    'Position · X/Y · ±10000 mm': {'fr', 'de'}, '&Position:': {'fr', 'de'},
    'No': {'es', 'it'},
    'Dimensions': {'fr'}, 'Dimensions ≤64 MP · PNG/TIFF α · JPEG RGB': {'fr'},
    'animation': {'fr'}, '    ·    animation': {'fr'},
    'Contrast': {'nl', 'ro'}, 'Saturation': {'fr'},
    'Image': {'fr'}, 'Pen': {'nl'}, 'Rectangle': {'fr'}, 'Rectangle (B)': {'fr'},
    'Text': {'de', 'cs', 'ro'},
}
ZIG = ROOT / 'tools/zig-windows-x86_64-0.11.0/zig.exe'
import json
import subprocess
dump = subprocess.run([str(ZIG), 'run', '../tests/i18n-check/catalog_dump.zig', '--main-pkg-path', '..'],
                      cwd=ROOT / 'src', check=True, capture_output=True)
catalog = json.loads(dump.stdout.decode('utf-8'))
fallbacks = []
used_allowances = set()
for row in catalog:
    source, texts = row[0], row[1:]
    assert len(texts) == len(CODES), source
    english = texts[1]
    if english.startswith('PNG / JPEG / BMP') and '*.png' in english:
        continue  # file-dialog filter: format names and wildcards only
    if english in NEUTRAL:
        if any(t != english for t in texts[1:]):
            fallbacks.append((source, 'neutral entry differs between languages'))
        continue
    for code, text in zip(CODES[2:], texts[2:]):
        if text != english:
            continue
        if code in SAME_WORD.get(english, ()):
            used_allowances.add((english, code))
            continue
        fallbacks.append((source, code))
if fallbacks:
    by_source = {}
    for source, code in fallbacks:
        by_source.setdefault(source, []).append(code)
    for source, codes in by_source.items():
        print(repr(source), '|', ' '.join(codes))
    raise SystemExit(f'ENGLISH FALLBACK: {len(by_source)} catalog entries show English text in other languages')
stale = sorted((t, c) for t, cs in SAME_WORD.items() for c in cs if (t, c) not in used_allowances)
if stale:
    raise SystemExit(f'STALE ALLOWLIST: {stale}')
# A Polish sentence must not resolve to a bare vocabulary word (e.g. a print
# hint showing only "Position"). Whitespace word counts: English is the probe.
collapsed = [row[0] for row in catalog
             if re.search(r'[.?!]$', row[1].strip()) and len(row[1].split()) >= 4 and len(row[2].split()) < 3]
if collapsed:
    for source in collapsed:
        print(repr(source))
    raise SystemExit(f'COLLAPSED: {len(collapsed)} Polish sentences translate to one or two words')
print(f'PASS: {len(catalog)} catalog entries; no English fallback in {len(CODES) - 2} languages '
      f'({len(used_allowances)} allowlisted identical words)')
