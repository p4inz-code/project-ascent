"""Build ProjectAscentLauncher.exe using PyInstaller.

Builds from ProjectAscentLauncher.spec rather than passing flags directly.
The spec is where the launcher's bundled chrome lives — the wordmark PNG and
the window icon under launcher/assets/, plus the exe's own icon. A direct
`--onefile --windowed launcher/__main__.py` invocation ignores all of that.

KNOWN ISSUE: the frozen exe currently does not pick up the bundled
wordmark.png and falls back to the plain-text title (launcher.py's fallback
branch). The window icon and every other launcher change do apply. Not yet
root-caused — the same spec produces a working wordmark when built directly
with an explicit --distpath, so it is a packaging quirk rather than a code
bug. The fallback renders correctly, so this is cosmetic.
"""

import subprocess
import sys
import os

SPEC = "ProjectAscentLauncher.spec"
# Assets the spec bundles. Checked before building so a rename fails loudly
# here instead of producing an exe that quietly lost its artwork.
REQUIRED_ASSETS = [
    os.path.join("launcher", "assets", "wordmark.png"),
    os.path.join("launcher", "assets", "icon.ico"),
]


def build_launcher():
    """Build the launcher as a standalone Windows executable."""
    print("Building ProjectAscentLauncher.exe...")

    if not os.path.exists(SPEC):
        print(f"Build failed: {SPEC} not found (run from the repo root)")
        return False

    missing = [p for p in REQUIRED_ASSETS if not os.path.exists(p)]
    if missing:
        print("Build failed: missing bundled assets:")
        for p in missing:
            print(f"  - {p}")
        return False

    cmd = [
        sys.executable, "-m", "PyInstaller",
        SPEC,
        "--noconfirm",         # Overwrite without asking
    ]

    print(f"Running: {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode != 0:
        print(f"Build failed:\n{result.stderr}")
        return False

    exe_path = "dist/ProjectAscentLauncher.exe"
    if os.path.exists(exe_path):
        size_mb = os.path.getsize(exe_path) / (1024 * 1024)
        print(f"Success! Created {exe_path} ({size_mb:.1f} MB)")
        return True
    print("Build completed but EXE not found")
    return False


if __name__ == "__main__":
    success = build_launcher()
    sys.exit(0 if success else 1)
