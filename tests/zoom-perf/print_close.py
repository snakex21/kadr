"""Open and close Kadr's print preview; report whether another app's window
briefly became the foreground window (visible as a flash/blink).

Usage: python tests/zoom-perf/print_close.py <image> [rounds]
"""
import ctypes
import ctypes.wintypes as wt
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
user32 = ctypes.windll.user32
WM_COMMAND, WM_CLOSE = 0x0111, 0x0010
PRINT_ID = 109

def windows_of(pid, cls):
    found = []
    proto = ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)
    def each(h, _):
        owner = wt.DWORD()
        user32.GetWindowThreadProcessId(h, ctypes.byref(owner))
        name = ctypes.create_unicode_buffer(64)
        user32.GetClassNameW(h, name, 64)
        if owner.value == pid and name.value == cls:
            found.append(h)
        return True
    user32.EnumWindows(proto(each), 0)
    return found

def wait_for(pid, cls, timeout=5.0):
    end = time.perf_counter() + timeout
    while time.perf_counter() < end:
        found = windows_of(pid, cls)
        if found:
            return found[0]
        time.sleep(0.02)
    return 0

kernel32 = ctypes.windll.kernel32

def bring_to_front(hwnd):
    """Foreground via thread-input attach (no synthetic keyboard/mouse input)."""
    fg = user32.GetForegroundWindow()
    mine = kernel32.GetCurrentThreadId()
    other = user32.GetWindowThreadProcessId(fg, None) if fg else 0
    if other and other != mine:
        user32.AttachThreadInput(mine, other, True)
    user32.SetForegroundWindow(hwnd)
    if other and other != mine:
        user32.AttachThreadInput(mine, other, False)
    return user32.GetForegroundWindow() == hwnd

def main():
    image = sys.argv[1]
    rounds = int(sys.argv[2]) if len(sys.argv) > 2 else 5
    proc = subprocess.Popen([str(ROOT / 'Kadr.exe'), image])
    try:
        main_hwnd = wait_for(proc.pid, 'Kadr.Main')
        if not main_hwnd:
            raise SystemExit('Kadr window not found')
        time.sleep(1.5)
        foreign_total = 0
        for i in range(rounds):
            foreground = bring_to_front(main_hwnd)
            user32.PostMessageW(main_hwnd, WM_COMMAND, PRINT_ID, 0)
            preview = wait_for(proc.pid, 'Kadr.PrintPreview.1')
            if not preview:
                raise SystemExit('print preview did not open')
            time.sleep(0.8)
            user32.PostMessageW(preview, WM_CLOSE, 0, 0)
            seen = []
            # Cause of the flash: preview destroyed while its owner is still
            # disabled. Record the owner's state at the last moment the
            # preview existed (works even without foreground rights).
            owner_enabled_before_destroy = None
            end = time.perf_counter() + 0.6
            while time.perf_counter() < end:
                enabled = bool(user32.IsWindowEnabled(main_hwnd))
                alive = bool(user32.IsWindow(preview))
                if alive:
                    owner_enabled_before_destroy = enabled
                fg = user32.GetForegroundWindow()
                if not seen or seen[-1] != fg:
                    seen.append(fg)
            foreign = [h for h in seen if h not in (main_hwnd, preview, 0)]
            foreign_total += len(foreign)
            final = user32.GetForegroundWindow()
            print(f'round {i + 1}: Kadr was foreground before: {foreground}; foreground sequence {[hex(h) for h in seen]}; '
                  f'foreign activations {len(foreign)}; final is Kadr: {final == main_hwnd}; '
                  f'owner enabled while preview still existed: {owner_enabled_before_destroy}')
            time.sleep(0.3)
        print(f'TOTAL foreign activations: {foreign_total} in {rounds} rounds')
    finally:
        main_hwnd = wait_for(proc.pid, 'Kadr.Main', 1)
        if main_hwnd:
            user32.PostMessageW(main_hwnd, WM_CLOSE, 0, 0)
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc.kill()

main()
