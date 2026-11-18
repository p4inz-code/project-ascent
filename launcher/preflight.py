"""Before the launcher starts the game it looks at the game file, so a problem is explained in plain words instead of
a bare Windows error such as "[WinError 216] This version of %1 is not compatible with the version of Windows you're
running". The cases it names, in the order a player is likely to meet them:
  * the file is missing (the launcher was moved out of the game folder)
  * the file is far too small or is not a Windows program at all (a download or unzip that was cut short, or damaged)
  * the file is built for another processor than this PC's
  * this PC runs 32-bit Windows (the game is 64-bit and needs Windows 10 or 11, 64-bit)
Windows runs programs of this kind on ARM PCs through its own emulation, so an ARM PC is allowed through.
"""
import os
import platform
import struct
from typing import Optional

RELEASES_URL = "https://github.com/p4inz-code/project-ascent/releases/latest"
ITCH_URL = "https://p4inz-code.itch.io/project-ascent"

MACHINE_AMD64 = 0x8664
MACHINE_X86 = 0x14C
MACHINE_ARM64 = 0xAA64

# The real game is about 100 MB; anything under this is not the game.
MIN_GAME_BYTES = 5 * 1024 * 1024


def pe_machine(path: str) -> Optional[int]:
    """The processor type a Windows program was built for, or None when the file is not a Windows program."""
    try:
        with open(path, "rb") as f:
            head = f.read(64)
            if len(head) < 64 or head[:2] != b"MZ":
                return None
            offset = struct.unpack("<I", head[0x3C:0x40])[0]
            f.seek(offset)
            sig = f.read(6)
            if len(sig) < 6 or sig[:4] != b"PE\0\0":
                return None
            return struct.unpack("<H", sig[4:6])[0]
    except (OSError, struct.error):
        return None


def host_machine() -> str:
    """'AMD64', 'ARM64' or 'x86' for the Windows this launcher runs on (the real processor, even when this
    launcher itself is a 32-bit program on 64-bit Windows)."""
    arch = os.environ.get("PROCESSOR_ARCHITEW6432") or os.environ.get("PROCESSOR_ARCHITECTURE") or platform.machine()
    arch = arch.upper()
    if arch in ("AMD64", "X86_64"):
        return "AMD64"
    if arch in ("ARM64", "AARCH64"):
        return "ARM64"
    if arch in ("X86", "I386", "I686"):
        return "x86"
    return arch


def check_game_file(path: str, host: Optional[str] = None) -> Optional[str]:
    """None when the game file looks runnable here; otherwise a short explanation in plain words."""
    name = os.path.basename(path)
    folder = os.path.dirname(path)
    if not os.path.isfile(path):
        return ("Could not find %s next to the launcher.\n\nKeep the launcher in the game folder, with all the files "
                "from the zip (%s)." % (name, folder))
    size = os.path.getsize(path)
    machine = pe_machine(path)
    if machine is None or size < MIN_GAME_BYTES:
        return ("%s is damaged: it is %s and does not look like the game. The download or the unzip was probably cut "
                "short.\n\nDownload the game again, unzip every file, and run the launcher from there:\n%s\nor play in "
                "your browser:\n%s" % (name, _size_text(size), RELEASES_URL, ITCH_URL))
    host = host or host_machine()
    if machine == MACHINE_AMD64 and host == "x86":
        return ("This PC runs 32-bit Windows, and Project Ascent needs 64-bit Windows 10 or 11.\n\nYou can still play "
                "in your browser:\n%s" % ITCH_URL)
    if machine != MACHINE_AMD64:
        return ("%s was built for a different kind of processor than this game's Windows version expects.\n\nDownload "
                "the Windows zip again from:\n%s" % (name, RELEASES_URL))
    return None


def explain_launch_error(error: OSError) -> str:
    """Plain words for the errors Windows gives when it will not start a program."""
    code = getattr(error, "winerror", None)
    if code in (193, 216):
        return ("Windows would not start the game file (error %d). Either the file is damaged, or this PC cannot run "
                "64-bit programs.\n\nDownload the game again from:\n%s\nor play in your browser:\n%s"
                % (code, RELEASES_URL, ITCH_URL))
    if code == 5:
        return ("Windows refused to start the game (access denied). An antivirus program may have blocked "
                "ProjectAscent.exe: allow it, or unzip the game to a folder such as your Documents.")
    return "Failed to launch the game: %s" % error


def _size_text(size: int) -> str:
    if size < 1024:
        return "only %d bytes" % size
    if size < 1024 * 1024:
        return "only %d KB" % (size // 1024)
    return "%.1f MB" % (size / 1048576.0)
