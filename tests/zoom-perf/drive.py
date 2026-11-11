"""Drive the real Kadr.exe window with posted mouse messages and report paint timings.

Usage: python tests/zoom-perf/drive.py <image> [label]
Kadr is started with --profile-view and prints one KADR_FRAME line per paint.
"""
import ctypes
import ctypes.wintypes as wt
import subprocess
import sys
import threading
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
user32 = ctypes.windll.user32
WM_MOUSEWHEEL, WM_MOUSEMOVE, WM_LBUTTONDOWN, WM_LBUTTONUP, WM_CLOSE = 0x020A, 0x0200, 0x0201, 0x0202, 0x0010
MK_LBUTTON = 1

def lparam(x, y):
    return (y & 0xFFFF) << 16 | (x & 0xFFFF)

def main():
    image = sys.argv[1]
    label = sys.argv[2] if len(sys.argv) > 2 else Path(image).name
    proc = subprocess.Popen([str(ROOT / 'Kadr.exe'), '--profile-view', image], stdout=subprocess.PIPE, text=True)
    frames = []  # (wall time, paint_ms, input_ms, interactive, zoom)
    def reader():
        for line in proc.stdout:
            if line.startswith('KADR_FRAME'):
                f = dict(p.split('=') for p in line.split()[1:])
                frames.append((time.perf_counter(), float(f['paint_ms']), float(f['input_ms']), f['interactive'] == '1', float(f['zoom'])))
    threading.Thread(target=reader, daemon=True).start()
    hwnd = 0
    # Only this process's window: another running Kadr must not receive input.
    found = []
    proto = ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)
    def each(h, _):
        pid = wt.DWORD()
        user32.GetWindowThreadProcessId(h, ctypes.byref(pid))
        name = ctypes.create_unicode_buffer(64)
        user32.GetClassNameW(h, name, 64)
        if pid.value == proc.pid and name.value == 'Kadr.Main':
            found.append(h)
        return True
    callback = proto(each)
    for _ in range(100):
        user32.EnumWindows(callback, 0)
        if found:
            hwnd = found[0]
            break
        time.sleep(0.05)
    if not hwnd:
        raise SystemExit('Kadr window not found')
    time.sleep(2.0)  # load + settle
    rect = wt.RECT()
    user32.GetClientRect(hwnd, ctypes.byref(rect))
    cx, cy = rect.right // 2, (148 + rect.bottom - 64) // 2
    point = wt.POINT(cx, cy)
    user32.ClientToScreen(hwnd, ctypes.byref(point))
    phases = {}
    inputs = []
    def post(msg, wp, lp):
        inputs.append(time.perf_counter())
        user32.PostMessageW(hwnd, msg, wp, lp)
    def phase(name, action):
        start = time.perf_counter()
        action()
        last = inputs[-1]
        time.sleep(0.6)  # allow animation + settle
        phases[name] = (start, time.perf_counter(), last)
    def wheel():
        for _ in range(14):  # quick wheel spin, ~60 Hz notches
            post(WM_MOUSEWHEEL, (120 << 16), lparam(point.x, point.y))
            time.sleep(1 / 60)
    def drag():
        x, y = cx, cy
        post(WM_LBUTTONDOWN, MK_LBUTTON, lparam(x, y))
        for i in range(150):  # 125 Hz mouse, 1.2 s drag
            x += -6 if (i // 50) % 2 == 0 else 6
            y += -2 if i % 3 == 0 else 0
            post(WM_MOUSEMOVE, MK_LBUTTON, lparam(x, y))
            time.sleep(0.008)
        post(WM_LBUTTONUP, 0, lparam(x, y))
    def unwheel():
        for _ in range(6):
            post(WM_MOUSEWHEEL, ((-120 & 0xFFFF) << 16), lparam(point.x, point.y))
            time.sleep(1 / 60)
    phase('zoom in (14 notches)', wheel)
    phase('drag at close zoom (150 moves)', drag)
    phase('zoom out (6 notches)', unwheel)
    phase('drag after zoom out', drag)
    user32.PostMessageW(hwnd, WM_CLOSE, 0, 0)
    proc.wait(timeout=10)
    print(f'== {label}')
    for name, (start, end, last) in phases.items():
        sel = [f for f in frames if start <= f[0] <= end]
        if not sel:
            print(f'  {name}: no frames'); continue
        inter = [f for f in sel if f[3]]
        idle = [f for f in sel if not f[3]]
        paints = sorted(f[1] for f in inter) or [0]
        lat = sorted(f[2] for f in inter if f[2] >= 0) or [0]
        active = [f for f in inter if f[0] <= last + 0.001]
        gaps = [b[0] - a[0] for a, b in zip(active, active[1:])]
        final = sel[-1][4]
        reached = next((f[0] for f in sel if abs(f[4] - final) <= final * 1e-4), sel[-1][0])
        p95 = lambda v: v[min(len(v) - 1, int(len(v) * 0.95))]
        print(f'  {name}: {len(inter)} interactive frames, paint avg {sum(paints)/len(paints):.2f} ms p95 {p95(paints):.2f} max {paints[-1]:.2f}; '
              f'input->frame avg {sum(lat)/len(lat):.1f} ms max {lat[-1]:.1f}; longest gap while input {max(gaps, default=0)*1000:.0f} ms; '
              f'last input->final zoom shown {max(0, reached - last)*1000:.0f} ms; '
              f'settle paints {", ".join(f"{f[1]:.1f}" for f in idle) or "-"} ms; final zoom {final:.3f}')

main()
