"""The quiet apply step: ProjectAscentLauncher.exe --apply-update ZIP --sha256 HASH --version V --wait-pid PID --restart

The game downloads and checks an update, then hands the verified zip to this step, because a running game cannot
overwrite its own files. It runs with no window, swaps the files, keeps one rollback copy, writes its verdict to
update_result.json next to the game (the game shows it on the next start) and restarts the game.

Hardened on purpose (each rule has a test in launcher/tests/test_apply.py):
  * the zip must match the SHA-256 the game verified, checked again here (fail closed: no hash, no install);
  * only a fixed list of file names is ever extracted, from the zip's top level, and the zip is refused outright
    when it holds anything else (paths, links, unexpected names), is too large, or compresses suspiciously well;
  * version.txt inside the zip must equal the version asked for, and must be newer than the installed one;
  * files are written beside the old ones and swapped in with os.replace, with a marker file while it happens;
    a crash in the middle is repaired from the backup at the next start;
  * after the swap the installed files are hashed against the staged ones; any mismatch rolls everything back.
"""
import argparse
import hashlib
import json
import os
import shutil
import stat
import subprocess
import sys
import time
import zipfile
from typing import List, Optional

from . import updater
from .version import parse_version

RESULT_FILE = "update_result.json"
LOG_FILE = "update_log.txt"
MARKER = ".update_in_progress"
LAUNCHER_EXE = "ProjectAscentLauncher.exe"

# Installed into the game folder. The launcher itself cannot replace the running launcher, so it is skipped.
INSTALL_FILES = (updater.GAME_EXE, updater.GAME_PCK, updater.VERSION_FILE)
# Allowed in the zip and not installed.
IGNORED_FILES = (LAUNCHER_EXE, "README.txt")
ALLOWED_NAMES = INSTALL_FILES + IGNORED_FILES

MAX_MEMBERS = 12
MAX_MEMBER_BYTES = 400 * 1024 * 1024
MAX_TOTAL_BYTES = 600 * 1024 * 1024
MAX_RATIO = 100          # an executable compresses about 2:1; a zip bomb compresses far more
MAX_LOG_BYTES = 200 * 1024


class ApplyError(Exception):
    pass


def is_sha256(text: str) -> bool:
    return isinstance(text, str) and len(text) == 64 and all(c in "0123456789abcdef" for c in text.lower())


def sha256_of(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def log(game_dir: str, message: str) -> None:
    """A small append-only log next to the game, capped so it can never grow without limit."""
    try:
        path = os.path.join(game_dir, LOG_FILE)
        if os.path.exists(path) and os.path.getsize(path) > MAX_LOG_BYTES:
            os.remove(path)
        with open(path, "a", encoding="utf-8") as f:
            f.write(time.strftime("%Y-%m-%d %H:%M:%S ") + message + "\n")
    except OSError:
        pass


def wait_for_exit(pid: Optional[int], timeout: float = 30.0) -> bool:
    """Wait until the game process has ended (so its files are free). True when it is gone."""
    if not pid or pid <= 0:
        return True
    if os.name == "nt":
        import ctypes
        synchronize = 0x00100000
        handle = ctypes.windll.kernel32.OpenProcess(synchronize, False, pid)
        if not handle:
            return True  # already gone
        try:
            return ctypes.windll.kernel32.WaitForSingleObject(handle, int(timeout * 1000)) == 0
        finally:
            ctypes.windll.kernel32.CloseHandle(handle)
    end = time.time() + timeout
    while time.time() < end:
        try:
            os.kill(pid, 0)
        except OSError:
            return True
        time.sleep(0.2)
    return False


def inspect_zip(zip_path: str) -> List[zipfile.ZipInfo]:
    """Refuse any zip that is not exactly a Project Ascent release. Returns the members to install."""
    try:
        zf = zipfile.ZipFile(zip_path, "r")
    except (zipfile.BadZipFile, OSError) as e:
        raise ApplyError("The update file is not a valid zip (%s)." % e)
    with zf:
        infos = zf.infolist()
        if len(infos) == 0 or len(infos) > MAX_MEMBERS:
            raise ApplyError("The update has an unexpected number of files.")
        total = 0
        seen = set()
        for info in infos:
            name = info.filename
            if name not in ALLOWED_NAMES:
                raise ApplyError("The update holds an unexpected file: %r." % name)
            if name in seen:
                raise ApplyError("The update lists a file twice: %r." % name)
            seen.add(name)
            mode = (info.external_attr >> 16) & 0xFFFF
            if mode and stat.S_ISLNK(mode):
                raise ApplyError("The update holds a link, which is never allowed.")
            if info.is_dir():
                raise ApplyError("The update holds a folder, which is never allowed.")
            if info.file_size > MAX_MEMBER_BYTES:
                raise ApplyError("A file in the update is too large.")
            if info.compress_size > 0 and info.file_size / info.compress_size > MAX_RATIO and info.file_size > 1024 * 1024:
                raise ApplyError("A file in the update compresses suspiciously well.")
            total += info.file_size
        if total > MAX_TOTAL_BYTES:
            raise ApplyError("The update is too large.")
        for required in INSTALL_FILES:
            if required not in seen:
                raise ApplyError("The update is missing %s." % required)
        return [i for i in infos if i.filename in INSTALL_FILES]


def extract_members(zip_path: str, members: List[zipfile.ZipInfo], dest_dir: str) -> None:
    """Write only the whitelisted members, by fixed name, streaming (never extractall)."""
    os.makedirs(dest_dir, exist_ok=True)
    with zipfile.ZipFile(zip_path, "r") as zf:
        for info in members:
            target = os.path.join(dest_dir, info.filename)
            written = 0
            with zf.open(info, "r") as src, open(target, "wb") as dst:
                while True:
                    chunk = src.read(1024 * 1024)
                    if not chunk:
                        break
                    written += len(chunk)
                    if written > info.file_size or written > MAX_MEMBER_BYTES:
                        raise ApplyError("A file in the update is larger than it says.")
                    dst.write(chunk)
            if written != info.file_size:
                raise ApplyError("A file in the update is shorter than it says.")


def _replace_with_retry(src: str, dst: str, tries: int = 20) -> None:
    """os.replace, retried: Windows holds the old exe for a moment after the game exits."""
    last: Optional[Exception] = None
    for _ in range(tries):
        try:
            os.replace(src, dst)
            return
        except OSError as e:
            last = e
            time.sleep(0.5)
    raise ApplyError("Could not replace %s (%s)." % (os.path.basename(dst), last))


def repair_if_interrupted(game_dir: str) -> bool:
    """A marker left behind means a swap was cut short (power loss, a crash). Put the backup back."""
    marker = os.path.join(game_dir, MARKER)
    if not os.path.exists(marker):
        return False
    log(game_dir, "found an interrupted update, restoring the backup")
    restored = updater.restore_from_backup(game_dir)
    if restored:
        try:
            os.remove(marker)
        except OSError:
            pass
    return restored


def install(game_dir: str, staged_dir: str) -> None:
    """Swap the staged files in: write beside, then replace. Raises ApplyError on any failure."""
    marker = os.path.join(game_dir, MARKER)
    with open(marker, "w", encoding="ascii") as f:
        f.write("1")
    new_files = []
    try:
        for name in INSTALL_FILES:
            tmp = os.path.join(game_dir, name + ".new")
            shutil.copyfile(os.path.join(staged_dir, name), tmp)
            new_files.append((tmp, os.path.join(game_dir, name)))
        # version.txt last, so a game that reads it never claims a version whose files are not all in place
        ordered = sorted(new_files, key=lambda p: os.path.basename(p[1]) == updater.VERSION_FILE)
        for tmp, dst in ordered:
            _replace_with_retry(tmp, dst)
        for name in INSTALL_FILES:
            if sha256_of(os.path.join(game_dir, name)) != sha256_of(os.path.join(staged_dir, name)):
                raise ApplyError("%s did not match after installing." % name)
    except (OSError, ApplyError):
        for tmp, _ in new_files:
            try:
                os.remove(tmp)
            except OSError:
                pass
        raise
    os.remove(marker)


def write_result(game_dir: str, ok: bool, version: str, message: str) -> None:
    try:
        with open(os.path.join(game_dir, RESULT_FILE), "w", encoding="utf-8") as f:
            json.dump({"ok": ok, "version": version, "message": message}, f)
    except OSError:
        pass


def apply_update(game_dir: str, zip_path: str, sha256: str, version: str, wait_pid: Optional[int] = None,
                 restart: bool = True) -> dict:
    """Run the whole apply. Returns {ok, version, message}. Never raises; the old version is always left working."""
    result = {"ok": False, "version": version, "message": ""}
    staging = os.path.join(game_dir, updater.STAGING_DIR)
    try:
        if not wait_for_exit(wait_pid):
            raise ApplyError("The game did not close in time, so nothing was changed.")
        repair_if_interrupted(game_dir)
        if not is_sha256(sha256):
            raise ApplyError("No checksum was given, so the update was refused.")
        if parse_version(version) is None:
            raise ApplyError("The update has no usable version.")
        installed = updater.get_current_version(game_dir) if os.path.exists(os.path.join(game_dir, updater.VERSION_FILE)) else None
        new = parse_version(version)
        if installed is not None and not (new > installed):
            raise ApplyError("The update is not newer than the installed version.")
        if not os.path.isfile(zip_path):
            raise ApplyError("The update file is missing.")
        if sha256_of(zip_path).lower() != sha256.lower():
            raise ApplyError("The update did not match its checksum, so it was refused.")
        members = inspect_zip(zip_path)
        if os.path.exists(staging):
            shutil.rmtree(staging, ignore_errors=True)
        extract_members(zip_path, members, staging)
        with open(os.path.join(staging, updater.VERSION_FILE), "r", encoding="ascii", errors="replace") as f:
            inside = f.read().strip()
        if parse_version(inside) is None or parse_version(inside) != new:
            raise ApplyError("The version inside the update does not match, so it was refused.")
        if not updater.backup_installation(game_dir):
            raise ApplyError("A backup of the current version could not be made, so nothing was changed.")
        try:
            install(game_dir, staging)
        except ApplyError:
            updater.restore_from_backup(game_dir)
            try:
                os.remove(os.path.join(game_dir, MARKER))
            except OSError:
                pass
            raise
        result["ok"] = True
        result["message"] = "Updated to %s." % version
        log(game_dir, "updated to %s" % version)
    except ApplyError as e:
        result["message"] = str(e) + " Your old version was kept."
        log(game_dir, "failed: %s" % e)
    except Exception as e:  # never leave the player without a game because of an unexpected error
        updater.restore_from_backup(game_dir)
        result["message"] = "The update hit an unexpected problem (%s). Your old version was kept." % type(e).__name__
        log(game_dir, "unexpected: %r" % e)
    finally:
        shutil.rmtree(staging, ignore_errors=True)
    write_result(game_dir, result["ok"], version, result["message"])
    if result["ok"]:
        updater.cleanup_backup(game_dir)
        try:
            os.remove(zip_path)
        except OSError:
            pass
    if restart:
        exe = os.path.join(game_dir, updater.GAME_EXE)
        if os.path.exists(exe):
            try:
                subprocess.Popen([exe], cwd=game_dir)
            except OSError as e:
                log(game_dir, "could not restart the game: %r" % e)
    return result


def game_dir_here() -> str:
    if getattr(sys, "frozen", False):
        return os.path.dirname(sys.executable)
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def run_cli(argv: List[str]) -> int:
    p = argparse.ArgumentParser(prog="ProjectAscentLauncher", add_help=False)
    p.add_argument("--apply-update", dest="zip", required=True)
    p.add_argument("--sha256", default="")
    p.add_argument("--version", default="")
    p.add_argument("--wait-pid", type=int, default=0)
    p.add_argument("--restart", action="store_true")
    args, _ = p.parse_known_args(argv)
    result = apply_update(game_dir_here(), args.zip, args.sha256, args.version, args.wait_pid, args.restart)
    return 0 if result["ok"] else 1
