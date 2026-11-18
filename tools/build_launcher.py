"""Build ProjectAscentLauncher.exe using PyInstaller.

Builds from ProjectAscentLauncher.spec rather than passing flags directly.
The spec is where the launcher's bundled chrome lives — the wordmark PNG and
the window icon under launcher/assets/, plus the exe's own icon. A direct
`--onefile --windowed launcher/__main__.py` invocation ignores all of that.

The logo bug (the frozen exe fell back to plain text) was the spec: `datas=[]`
bundled nothing. The spec now lists every asset, and this script checks the
built exe's archive contains them, so it cannot silently regress.
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
        # the artwork must really be inside the exe (the old bug: it was not)
        with open(exe_path, "rb") as f:
            blob = f.read()
        lost = [name for name in ("wordmark.png", "studio.png", "rocket.png", "icon.ico")
                if (b"assets/" + name.encode()) not in blob and (b"assets\\" + name.encode()) not in blob]
        if lost:
            print("Build failed: the exe does not contain its artwork:", ", ".join(lost))
            return False
        return True
    print("Build completed but EXE not found")
    return False


if __name__ == "__main__":
    success = build_launcher()
    sys.exit(0 if success else 1)
