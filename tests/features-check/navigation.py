"""Navigation regressions on generated temporary images; never modifies fixtures."""
import argparse
import subprocess
import tempfile
import time
from pathlib import Path
from PIL import Image
import run as r

U = r.U


def image(path, color):
    Image.new('RGB', (32, 24), color).save(path)


class Viewer:
    def __init__(self, exe, path):
        self.exe, self.path = exe, path
        self.proc = self.hwnd = None

    def __enter__(self):
        self.proc = subprocess.Popen([str(self.exe), str(self.path)], cwd=r.ROOT)
        self.hwnd = r.wait(lambda: next((h for h in r.windows(self.proc.pid) if r.cls(h) == 'Kadr.Main'), None), 'owned Kadr window')
        return self

    def __exit__(self, *_):
        for h in r.windows(self.proc.pid):
            if r.cls(h) == '#32770':
                U.PostMessageW(h, r.WM_CLOSE, 0, 0)
        U.PostMessageW(self.hwnd, r.WM_CLOSE, 0, 0)
        try:
            self.proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait(timeout=5)

    def no_dialog(self):
        boxes = [h for h in r.windows(self.proc.pid) if r.cls(h) == '#32770']
        assert not boxes, [(r.title(h), [r.title(x) for x in r.windows(self.proc.pid, h)]) for h in boxes]

    def text(self, ident):
        return r.title(U.GetDlgItem(self.hwnd, ident))

    def ready(self, name, counter):
        def complete():
            self.no_dialog()
            return name in r.title(self.hwnd) and self.text(900) == counter and 'Wczytywanie' not in self.text(904)
        r.wait(complete, name + ' / ' + counter)
        time.sleep(.1)
        self.no_dialog()

    def arrows(self, previous, following):
        assert bool(U.IsWindowEnabled(U.GetDlgItem(self.hwnd, 101))) == previous, ('previous', self.text(900))
        assert bool(U.IsWindowEnabled(U.GetDlgItem(self.hwnd, 102))) == following, ('next', self.text(900))

    def command(self, ident, count=1):
        for _ in range(count):
            r.send_command(self.hwnd, ident)

    def key(self, key, count=1):
        for _ in range(count):
            U.PostMessageW(self.hwnd, 0x100, key, 0)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--exe', type=Path, default=r.ROOT / 'Kadr.exe')
    args = parser.parse_args()
    exe = args.exe.resolve()
    work = Path(tempfile.mkdtemp(prefix='kadr-navigation-'))

    single = work / 'single'
    single.mkdir()
    image(single / '01.png', 'red')
    with Viewer(exe, single / '01.png') as v:
        v.ready('01.png', '1 / 1')
        v.arrows(False, False)
        v.command(101, 20)
        v.command(102, 20)
        v.key(0x25, 20)
        v.key(0x27, 20)
        v.ready('01.png', '1 / 1')
        v.arrows(False, False)
    print('PASS: single image, both disabled arrows, repeated commands and keys')

    healthy = work / 'healthy'
    healthy.mkdir()
    for n, color in enumerate(['red', 'green', 'blue'], 1):
        image(healthy / f'{n:02}.png', color)
    with Viewer(exe, healthy / '01.png') as v:
        v.ready('01.png', '1 / 3')
        v.arrows(False, True)
        v.command(101, 20)
        v.key(0x25, 20)
        v.ready('01.png', '1 / 3')
        v.command(102)
        v.ready('02.png', '2 / 3')
        v.arrows(True, True)
        v.command(102)
        v.ready('03.png', '3 / 3')
        v.arrows(True, False)
        v.command(102, 20)
        v.key(0x27, 20)
        v.ready('03.png', '3 / 3')
        v.command(101, 40)
        v.ready('01.png', '1 / 3')
        v.arrows(False, True)
        v.command(102, 40)
        v.ready('03.png', '3 / 3')
        v.arrows(True, False)
        v.command(114)
        r.wait(lambda: 'pokaz' in v.text(904), 'slideshow started')
        r.wait(lambda: 'pokaz' not in v.text(904), 'slideshow stops at last file', 7)
        v.ready('03.png', '3 / 3')
    print('PASS: first/middle/last, no wrapping, 40 rapid requests each way, slideshow end')

    mixed = work / 'mixed'
    mixed.mkdir()
    for name in ['00-broken.png', '02-broken.png', '05-broken.png']:
        (mixed / name).write_bytes(b'not an image')
    image(mixed / '01.png', 'red')
    image(mixed / '03.png', 'blue')
    image(mixed / '04-missing.png', 'green')
    with Viewer(exe, mixed / '01.png') as v:
        v.ready('01.png', '2 / 6')
        v.command(101)
        v.ready('01.png', '1 / 5')
        v.arrows(False, True)
        (mixed / '04-missing.png').rename(mixed / '04-missing.saved')
        v.command(102)
        v.ready('03.png', '2 / 4')
        v.command(102)
        v.ready('03.png', '2 / 2')
        v.arrows(True, False)
        v.command(101)
        v.ready('01.png', '1 / 2')
        v.arrows(False, True)
        v.command(102)
        v.ready('03.png', '2 / 2')
        v.arrows(True, False)
    print('PASS: corrupt first/middle/last and disappeared file skipped; counter and arrows corrected')

    with Viewer(exe, mixed / '00-broken.png') as v:
        box = r.wait(lambda: r.dialog(v.proc.pid), 'explicit bad-open error')
        text = '\n'.join(r.title(h) for h in r.windows(v.proc.pid, box))
        assert 'Nie udało się otworzyć' in text, text
        U.PostMessageW(box, r.WM_CLOSE, 0, 0)
        r.wait(lambda: not U.IsWindow(box), 'explicit error dismissed')
    print('PASS: explicit bad-file open still reports a real error')
    print('PASS: navigation suite; disposable inputs retained at', work)


if __name__ == '__main__':
    main()
