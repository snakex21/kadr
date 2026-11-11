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
for pattern in [r'\b(?:a|d|e|fixed)\(' + STRING, r'\.source\s*=\s*' + STRING]:
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
