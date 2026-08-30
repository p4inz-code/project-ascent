#!/usr/bin/env python3
"""Capture boss screenshots using mss + pydirectinput for reliable game input."""
import json
import os
import subprocess
import time
import sys

try:
    import mss
    import mss.tools
except ImportError:
    print("Installing mss...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "mss"])
    import mss
    import mss.tools

try:
    import pydirectinput
except ImportError:
    print("Installing pydirectinput...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pydirectinput"])
    import pydirectinput
import ctypes

pydirectinput.FAILSAFE = False  # Don't raise on corner

# Win32 API for window management
user32 = ctypes.windll.user32
def set_foreground(hwnd):
    user32.SetForegroundWindow(hwnd)
def find_game_hwnd():
    import subprocess
    r = subprocess.run(["powershell", "-Command",
        "(Get-Process -Name ProjectAscent -ErrorAction SilentlyContinue).MainWindowHandle"],
        capture_output=True, text=True)
    try:
        return int(r.stdout.strip())
    except:
        return 0

SAVE_PATH = os.path.expanduser(
    "~/AppData/Roaming/Godot/app_userdata/Project Ascent/save_data.json")
GAME_EXE = os.path.join(os.path.dirname(__file__), "..", "build", "windows",
                         "ProjectAscent.exe")
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "docs", "media", "boss")

BOSS_LEVELS = {
    5:  list(range(1, 5)),
    10: list(range(1, 10)),
    15: list(range(1, 15)),
    20: list(range(1, 20)),
    25: list(range(1, 25)),
}


def kill_game():
    subprocess.run(["taskkill", "/f", "/im", "ProjectAscent.exe"],
                   capture_output=True)
    time.sleep(1)


def set_save(level, completed):
    os.makedirs(os.path.dirname(SAVE_PATH), exist_ok=True)
    data = {
        "checkpoint_level": level,
        "levels_completed": completed,
        "total_attempts": 0,
        "total_completions": len(completed),
        "version": 1
    }
    with open(SAVE_PATH, "w") as f:
        json.dump(data, f, indent=2)
    print(f"  Save: checkpoint={level}")


def capture_screen(sct, path, hwnd=0):
    """Capture the game window or primary monitor."""
    if hwnd:
        import struct
        buf = ctypes.create_string_buffer(16)
        user32.GetWindowRect(hwnd, buf)
        left, top, right, bottom = struct.unpack('iiii', buf.raw)
        if right <= left or bottom <= top:
            monitor = sct.monitors[1]
        else:
            monitor = {"top": top, "left": left,
                       "width": right - left, "height": bottom - top}
    else:
        monitor = sct.monitors[1]
    img = sct.grab(monitor)
    raw = mss.tools.to_png(img.rgb, img.size)
    with open(path, "wb") as f:
        f.write(raw)
    return len(raw)


def wait_for_window(timeout=15):
    """Wait for the game process to appear."""
    for _ in range(timeout * 10):
        result = subprocess.run(
            ["tasklist", "/fi", "imagename eq ProjectAscent.exe"],
            capture_output=True, text=True)
        if "ProjectAscent.exe" in result.stdout:
            return True
        time.sleep(0.1)
    return False


def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    for level in [5, 10, 15, 20, 25]:
        completed = BOSS_LEVELS[level]
        print(f"\n{'='*50}")
        print(f"BOSS L{level}")
        print(f"{'='*50}")

        kill_game()
        set_save(level, completed)

        # Launch game
        print("  Launching...")
        subprocess.Popen([os.path.abspath(GAME_EXE)],
                         cwd=os.path.dirname(os.path.abspath(GAME_EXE)))
        
        if not wait_for_window():
            print("  ERROR: Game didn't start")
            continue
        print("  Game running")
        time.sleep(4)  # Wait for full boot

        # Focus game window and start
        print("  Starting game...")
        pydirectinput.press("enter")
        time.sleep(3)

        # Move player right to reach boss trigger
        print("  Moving right...")
        pydirectinput.keyDown("d")
        time.sleep(3)
        pydirectinput.keyUp("d")

        # Jump occasionally while moving
        for i in range(5):
            pydirectinput.press("space")
            time.sleep(0.3)

        # Wait for boss chase
        time.sleep(3)
        print("  Boss should be active")

        # Find and focus game window
        hwnd = find_game_hwnd()
        if hwnd:
            set_foreground(hwnd)
            time.sleep(0.3)

        # Capture 5 screenshots (full screen, game should be focused)
        with mss.mss() as sct:
            for i in range(1, 6):
                fname = f"boss_l{level:02d}_{i}.png"
                path = os.path.join(OUT_DIR, fname)
                if hwnd:
                    set_foreground(hwnd)
                    time.sleep(0.1)
                # Always capture primary monitor
                monitor = sct.monitors[1]
                img = sct.grab(monitor)
                raw = mss.tools.to_png(img.rgb, img.size)
                with open(path, "wb") as f:
                    f.write(raw)
                size = len(raw)
                print(f"  {fname} ({size // 1024} KB)")
                if i < 5:
                    time.sleep(2)

        kill_game()
        print(f"  Done L{level}")

    print(f"\n{'='*50}")
    print("ALL DONE")
    for f in sorted(os.listdir(OUT_DIR)):
        if f.endswith(".png"):
            size = os.path.getsize(os.path.join(OUT_DIR, f))
            print(f"  {f} ({size // 1024} KB)")


if __name__ == "__main__":
    main()
