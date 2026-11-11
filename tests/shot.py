"""Screenshot helper: open Kadr with an image, press a shortcut, capture the new window."""
import subprocess, sys, time, ctypes
ctypes.windll.user32.SetProcessDPIAware()
from pathlib import Path
import win32gui, win32con, win32api, win32process
from PIL import ImageGrab

root = Path(__file__).resolve().parent.parent
exe, image, key, out = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
proc = subprocess.Popen([exe, image])

def windows():
    found = []
    win32gui.EnumWindows(lambda h, _: found.append(h) if win32gui.IsWindowVisible(h) and win32process.GetWindowThreadProcessId(h)[1] == proc.pid and win32gui.GetClassName(h) != 'tooltips_class32' and win32gui.GetWindowText(h) else None, None)
    return found
try:
    for _ in range(100):
        time.sleep(0.1)
        if windows(): break
    main = windows()[0]
    win32gui.SetWindowPos(main, win32con.HWND_TOPMOST, 60, 40, 1200, 820, 0)
    time.sleep(1.2)
    if key != 'none':
        win32gui.PostMessage(main, win32con.WM_KEYDOWN, win32con.VK_CONTROL, 0)
        win32api.keybd_event(win32con.VK_CONTROL, 0, 0, 0)
        win32gui.PostMessage(main, win32con.WM_KEYDOWN, ord(key), 0)
        time.sleep(0.05)
        win32api.keybd_event(win32con.VK_CONTROL, 0, win32con.KEYEVENTF_KEYUP, 0)
        for _ in range(60):
            time.sleep(0.1)
            others = [h for h in windows() if h != main]
            if others: break
        target = others[0]
        win32gui.SetWindowPos(target, win32con.HWND_TOPMOST, 0, 0, 0, 0, win32con.SWP_NOMOVE | win32con.SWP_NOSIZE)
    else:
        target = main
    time.sleep(1.5)
    ImageGrab.grab(win32gui.GetWindowRect(target), all_screens=True).save(out)
    print('saved', out, win32gui.GetWindowText(target), win32gui.GetWindowRect(target))
finally:
    proc.kill()
