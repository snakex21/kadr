"""Runtime probe: hover each toolbar button and report the visible tooltip text."""
import subprocess, sys, time, ctypes
ctypes.windll.user32.SetProcessDPIAware()
from pathlib import Path
import win32gui, win32con, win32api, win32process

root = Path(__file__).resolve().parent.parent
exe = Path(sys.argv[1]) if len(sys.argv) > 1 else root / 'Kadr.exe'
image = sys.argv[2] if len(sys.argv) > 2 else str(next((root / 'tests' / 'fixtures').glob('*.png')))
proc = subprocess.Popen([str(exe), image])
try:
    main = None
    for _ in range(100):
        time.sleep(0.1)
        def cb(h, _):
            global main
            if win32gui.IsWindowVisible(h) and win32process.GetWindowThreadProcessId(h)[1] == proc.pid and win32gui.GetClassName(h) != 'tooltips_class32':
                main = h
        win32gui.EnumWindows(cb, None)
        if main: break
    assert main, 'no window'
    win32gui.SetWindowPos(main, win32con.HWND_TOPMOST, 0, 0, 0, 0, win32con.SWP_NOMOVE | win32con.SWP_NOSIZE)
    try:
        win32gui.SetForegroundWindow(main)
    except Exception:
        pass
    time.sleep(0.8)
    buttons = []
    win32gui.EnumChildWindows(main, lambda h, _: buttons.append(h) if win32gui.GetClassName(h) == 'Button' and win32gui.IsWindowVisible(h) else None, None)
    shown = 0
    for b in buttons:
        l, t, r, btm = win32gui.GetWindowRect(b)
        win32api.SetCursorPos((l + 3, t + 3)); time.sleep(0.05)
        win32api.SetCursorPos(((l + r) // 2, (t + btm) // 2))
        under = win32gui.WindowFromPoint(((l + r) // 2, (t + btm) // 2))
        text = None
        for _ in range(25):
            time.sleep(0.08)
            tips = []
            win32gui.EnumWindows(lambda h, _: tips.append(h) if win32gui.GetClassName(h) == 'tooltips_class32' and win32gui.IsWindowVisible(h) and win32process.GetWindowThreadProcessId(h)[1] == proc.pid else None, None)
            if tips:
                text = win32gui.GetWindowText(tips[0])
                if shown == 0:
                    from PIL import ImageGrab
                    time.sleep(0.4)
                    tl, tt, tr, tb = win32gui.GetWindowRect(tips[0])
                    ImageGrab.grab((tl - 40, tt - 60, tr + 40, tb + 10), all_screens=True).save(root / 'tests' / 'tip_probe.png')
                break
        shown += text is not None
        print(f'{win32gui.GetWindowText(b)!r:32} under_ok={under == b} -> {text!r}')
    print(f'TOOLTIPS {shown}/{len(buttons)}')
    sys.exit(0 if buttons and shown == len(buttons) else 1)
finally:
    proc.kill()
