#!/usr/bin/env python3
"""Capture a tour of all 25 levels from the current build and encode it to one
MP4, for clipping/sharing. Unlike tools/audit_playthrough.py, this captures
only the game window's own bounds (not the full monitor) — that script's
full-screen capture is exactly the privacy/quality issue this project's own
audit flagged.

For each level: writes the save file directly to checkpoint that level (so
we always see every level regardless of whether the dumb autopilot can beat
it — an honest full-game tour, not a speedrun), launches the built EXE,
drives a simple autopilot (hold right, tap jump, occasional dash), captures
frames of the game window only, then moves on.

Usage:
    python tools/record_playthrough.py [--seconds-per-level 10] [--fps 15]

Requires ffmpeg on PATH (already present on this machine via WinGet).
"""
import argparse
import ctypes
import json
import os
import subprocess
import sys
import time

try:
    import mss
    import mss.tools
    import pydirectinput
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "mss", "pydirectinput"])
    import mss
    import mss.tools
    import pydirectinput

pydirectinput.FAILSAFE = False

ROOT = os.path.join(os.path.dirname(__file__), "..")
EXE = os.path.join(ROOT, "build", "windows", "ProjectAscent.exe")
SAVE_PATH = os.path.expanduser("~/AppData/Roaming/Godot/app_userdata/Project Ascent/save_data.json")
FRAMES_DIR = os.path.join(os.environ.get("TEMP", "."), "claude", "ascent_playthrough_frames")
OUT_VIDEO = os.path.join(ROOT, "docs", "media", "playthrough_all_levels.mp4")
TOTAL_LEVELS = 25

user32 = ctypes.windll.user32


class RECT(ctypes.Structure):
    _fields_ = [("left", ctypes.c_long), ("top", ctypes.c_long),
                ("right", ctypes.c_long), ("bottom", ctypes.c_long)]


def kill_game():
    subprocess.run(["taskkill", "/f", "/im", "ProjectAscent.exe"], capture_output=True)
    time.sleep(0.6)


def write_checkpoint(level: int):
    os.makedirs(os.path.dirname(SAVE_PATH), exist_ok=True)
    data = {
        "version": 1,
        "checkpoint_level": level,
        "levels_completed": list(range(1, level)),
        "total_attempts": 0,
        "total_completions": max(0, level - 1),
    }
    with open(SAVE_PATH, "w") as f:
        json.dump(data, f)


def find_game_hwnd():
    result = {"hwnd": 0}

    @ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)
    def callback(hwnd, _lparam):
        length = user32.GetWindowTextLengthW(hwnd)
        if length == 0 or not user32.IsWindowVisible(hwnd):
            return True
        buf = ctypes.create_unicode_buffer(length + 1)
        user32.GetWindowTextW(hwnd, buf, length + 1)
        if buf.value == "Project Ascent":
            result["hwnd"] = hwnd
            return False
        return True

    user32.EnumWindows(callback, 0)
    return result["hwnd"]


def window_rect(hwnd):
    r = RECT()
    user32.GetClientRect(hwnd, ctypes.byref(r))
    pt = ctypes.wintypes.POINT(0, 0) if hasattr(ctypes, "wintypes") else None
    # Translate client-area (0,0) to screen coordinates.
    from ctypes import wintypes
    pt = wintypes.POINT(0, 0)
    user32.ClientToScreen(hwnd, ctypes.byref(pt))
    return {"left": pt.x, "top": pt.y, "width": r.right - r.left, "height": r.bottom - r.top}


def wait_for_window(timeout=10.0):
    start = time.time()
    while time.time() - start < timeout:
        hwnd = find_game_hwnd()
        if hwnd:
            return hwnd
        time.sleep(0.1)
    return 0


def record_level(level: int, seconds: float, fps: int, frame_index_start: int) -> int:
    kill_game()
    write_checkpoint(level)
    subprocess.Popen([EXE], cwd=os.path.dirname(EXE))
    hwnd = wait_for_window()
    if not hwnd:
        print(f"  L{level}: window never appeared, skipping")
        return frame_index_start
    user32.SetForegroundWindow(hwnd)
    time.sleep(1.5)  # let the level-card fade-in finish

    pydirectinput.keyDown("right")
    frame_idx = frame_index_start
    interval = 1.0 / fps
    last_jump = 0.0
    last_dash = 0.0
    t0 = time.time()
    with mss.mss() as sct:
        while time.time() - t0 < seconds:
            loop_start = time.time()
            elapsed = loop_start - t0
            if elapsed - last_jump > 0.7:
                pydirectinput.press("space")
                last_jump = elapsed
            if elapsed - last_dash > 2.5:
                pydirectinput.press("shift")
                last_dash = elapsed
            rect = window_rect(hwnd)
            if rect["width"] > 0 and rect["height"] > 0:
                img = sct.grab(rect)
                path = os.path.join(FRAMES_DIR, f"frame_{frame_idx:06d}.png")
                mss.tools.to_png(img.rgb, img.size, output=path)
                frame_idx += 1
            sleep_left = interval - (time.time() - loop_start)
            if sleep_left > 0:
                time.sleep(sleep_left)
    pydirectinput.keyUp("right")
    print(f"  L{level}: captured {frame_idx - frame_index_start} frames")
    return frame_idx


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seconds-per-level", type=float, default=10.0)
    ap.add_argument("--fps", type=int, default=15)
    ap.add_argument("--levels", type=str, default=f"1-{TOTAL_LEVELS}")
    args = ap.parse_args()

    lo, hi = (int(x) for x in args.levels.split("-"))

    if not os.path.exists(EXE):
        print(f"EXE not found: {EXE}. Run tools/build_release.ps1 (or a plain "
              f"--export-release \"Windows Desktop\") first.")
        sys.exit(1)

    os.makedirs(FRAMES_DIR, exist_ok=True)
    for f in os.listdir(FRAMES_DIR):
        os.remove(os.path.join(FRAMES_DIR, f))

    frame_idx = 0
    print(f"Recording levels {lo}-{hi}, {args.seconds_per_level}s each at {args.fps} fps...")
    for level in range(lo, hi + 1):
        frame_idx = record_level(level, args.seconds_per_level, args.fps, frame_idx)
    kill_game()

    if frame_idx == 0:
        print("No frames captured; not encoding.")
        sys.exit(1)

    os.makedirs(os.path.dirname(OUT_VIDEO), exist_ok=True)
    print(f"Encoding {frame_idx} frames to {OUT_VIDEO} ...")
    subprocess.check_call([
        "ffmpeg", "-y", "-framerate", str(args.fps),
        "-i", os.path.join(FRAMES_DIR, "frame_%06d.png"),
        "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18",
        OUT_VIDEO,
    ])
    print(f"Done: {OUT_VIDEO}")


if __name__ == "__main__":
    main()
