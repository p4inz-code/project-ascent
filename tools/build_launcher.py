"""Build ProjectAscentLauncher.exe using PyInstaller."""

import subprocess
import sys
import os

def build_launcher():
    """Build the launcher as a standalone Windows executable."""
    print("Building ProjectAscentLauncher.exe...")
    
    # PyInstaller command
    cmd = [
        sys.executable, "-m", "PyInstaller",
        "--onefile",           # Single EXE file
        "--windowed",          # No console window
        "--name", "ProjectAscentLauncher",
        "--clean",             # Clean build cache
        "--noconfirm",         # Overwrite without asking
        "launcher/__main__.py"  # Entry point
    ]
    
    print(f"Running: {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    if result.returncode != 0:
        print(f"Build failed:\n{result.stderr}")
        return False
    
    # Check if EXE was created
    exe_path = "dist/ProjectAscentLauncher.exe"
    if os.path.exists(exe_path):
        size_mb = os.path.getsize(exe_path) / (1024 * 1024)
        print(f"Success! Created {exe_path} ({size_mb:.1f} MB)")
        return True
    else:
        print("Build completed but EXE not found")
        return False

if __name__ == "__main__":
    success = build_launcher()
    sys.exit(0 if success else 1)
