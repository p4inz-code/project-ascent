"""Core update checking, downloading, and verification logic."""

import hashlib
import json
import os
import shutil
import tempfile
import urllib.request
import urllib.error
from dataclasses import dataclass
from typing import Optional

from .version import Version, parse_version, read_version_from_file, write_version_to_file

GITHUB_REPO = "p4inz-code/project-ascent"
GITHUB_API_URL = f"https://api.github.com/repos/{GITHUB_REPO}/releases/latest"

GAME_EXE = "ProjectAscent.exe"
GAME_PCK = "ProjectAscent.pck"
VERSION_FILE = "version.txt"
BACKUP_DIR = ".update_backup"
STAGING_DIR = ".update_staging"


@dataclass
class ReleaseInfo:
    version: Version
    tag: str
    download_url: str
    sha256: Optional[str]
    size: Optional[int]
    published_at: str
    body: str


@dataclass
class UpdateResult:
    success: bool
    message: str
    old_version: Optional[Version] = None
    new_version: Optional[Version] = None


class UpdateError(Exception):
    pass

class NetworkError(UpdateError):
    pass

class VerificationError(UpdateError):
    pass

class InstallationError(UpdateError):
    pass


def get_game_directory() -> str:
    return os.path.dirname(os.path.abspath(__file__))


def get_current_version(game_dir: str) -> Optional[Version]:
    version_path = os.path.join(game_dir, VERSION_FILE)
    return read_version_from_file(version_path)


def check_for_update(current_version: Optional[Version], timeout: int = 10) -> Optional[ReleaseInfo]:
    try:
        req = urllib.request.Request(
            GITHUB_API_URL,
            headers={
                "Accept": "application/vnd.github.v3+json",
                "User-Agent": "ProjectAscent-Updater/0.1.0"
            }
        )
        with urllib.request.urlopen(req, timeout=timeout) as response:
            data = json.loads(response.read().decode("utf-8"))
    except urllib.error.URLError as e:
        raise NetworkError(f"Failed to check for updates: {e}")
    except json.JSONDecodeError as e:
        raise UpdateError(f"Malformed GitHub response: {e}")

    tag = data.get("tag_name", "")
    release_version = parse_version(tag)
    if release_version is None:
        raise UpdateError(f"Invalid version tag: {tag}")

    if current_version is not None and release_version <= current_version:
        return None

    download_url = None
    sha256 = None
    size = None
    for asset in data.get("assets", []):
        name = asset.get("name", "")
        if name.endswith("-Windows.zip"):
            download_url = asset.get("browser_download_url")
            size = asset.get("size")
            break

    if download_url is None:
        raise UpdateError("No Windows release asset found")

    for asset in data.get("assets", []):
        name = asset.get("name", "")
        if name.endswith("-Windows.zip.sha256"):
            try:
                sha256_req = urllib.request.Request(
                    asset.get("browser_download_url"),
                    headers={"User-Agent": "ProjectAscent-Updater/0.1.0"}
                )
                with urllib.request.urlopen(sha256_req, timeout=timeout) as resp:
                    sha256_content = resp.read().decode("utf-8").strip()
                    sha256 = sha256_content.split()[0] if sha256_content else None
            except Exception:
                pass
            break

    return ReleaseInfo(
        version=release_version,
        tag=tag,
        download_url=download_url,
        sha256=sha256,
        size=size,
        published_at=data.get("published_at", ""),
        body=data.get("body", "")
    )


def download_file(url: str, dest_path: str, timeout: int = 60) -> bool:
    try:
        req = urllib.request.Request(
            url,
            headers={"User-Agent": "ProjectAscent-Updater/0.1.0"}
        )
        with urllib.request.urlopen(req, timeout=timeout) as response:
            with open(dest_path, "wb") as f:
                shutil.copyfileobj(response, f)
        return True
    except Exception:
        return False


def calculate_sha256(file_path: str) -> str:
    sha256_hash = hashlib.sha256()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            sha256_hash.update(chunk)
    return sha256_hash.hexdigest()


def verify_checksum(file_path: str, expected_sha256: str) -> bool:
    actual_sha256 = calculate_sha256(file_path)
    return actual_sha256.lower() == expected_sha256.lower()


def backup_installation(game_dir: str) -> bool:
    backup_path = os.path.join(game_dir, BACKUP_DIR)
    if os.path.exists(backup_path):
        try:
            shutil.rmtree(backup_path)
        except Exception:
            return False
    try:
        os.makedirs(backup_path, exist_ok=True)
        for filename in [GAME_EXE, GAME_PCK, VERSION_FILE]:
            src = os.path.join(game_dir, filename)
            if os.path.exists(src):
                shutil.copy2(src, os.path.join(backup_path, filename))
        return True
    except Exception:
        return False


def restore_from_backup(game_dir: str) -> bool:
    backup_path = os.path.join(game_dir, BACKUP_DIR)
    if not os.path.exists(backup_path):
        return False
    try:
        for filename in [GAME_EXE, GAME_PCK, VERSION_FILE]:
            src = os.path.join(backup_path, filename)
            if os.path.exists(src):
                shutil.copy2(src, os.path.join(game_dir, filename))
        return True
    except Exception:
        return False


def cleanup_backup(game_dir: str) -> None:
    backup_path = os.path.join(game_dir, BACKUP_DIR)
    if os.path.exists(backup_path):
        try:
            shutil.rmtree(backup_path)
        except Exception:
            pass


def extract_update(zip_path: str, dest_dir: str) -> bool:
    import zipfile
    try:
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            zip_ref.extractall(dest_dir)
        return True
    except Exception:
        return False


def install_update(game_dir: str, staging_dir: str) -> bool:
    try:
        for filename in [GAME_EXE, GAME_PCK, VERSION_FILE]:
            src = os.path.join(staging_dir, filename)
            if os.path.exists(src):
                shutil.copy2(src, os.path.join(game_dir, filename))
        return True
    except Exception:
        return False


def perform_update(game_dir: str, release: ReleaseInfo,
                   progress_callback=None) -> UpdateResult:
    old_version = get_current_version(game_dir)

    def report(message: str):
        if progress_callback:
            progress_callback(message)

    try:
        report("Creating backup...")
        if not backup_installation(game_dir):
            return UpdateResult(success=False, message="Failed to create backup", old_version=old_version)

        report("Downloading update...")
        with tempfile.TemporaryDirectory() as temp_dir:
            zip_path = os.path.join(temp_dir, f"update-{release.version}.zip")
            if not download_file(release.download_url, zip_path):
                report("Download failed, restoring backup...")
                restore_from_backup(game_dir)
                cleanup_backup(game_dir)
                return UpdateResult(success=False, message="Failed to download update", old_version=old_version)

            if release.sha256:
                report("Verifying checksum...")
                if not verify_checksum(zip_path, release.sha256):
                    report("Checksum mismatch, restoring backup...")
                    restore_from_backup(game_dir)
                    cleanup_backup(game_dir)
                    return UpdateResult(success=False, message="Checksum verification failed", old_version=old_version)

            report("Extracting update...")
            staging_dir = os.path.join(game_dir, STAGING_DIR)
            if os.path.exists(staging_dir):
                shutil.rmtree(staging_dir)
            if not extract_update(zip_path, staging_dir):
                report("Extraction failed, restoring backup...")
                restore_from_backup(game_dir)
                cleanup_backup(game_dir)
                return UpdateResult(success=False, message="Extraction failed", old_version=old_version)

        report("Installing update...")
        if not install_update(game_dir, staging_dir):
            report("Installation failed, restoring backup...")
            restore_from_backup(game_dir)
            cleanup_backup(game_dir)
            return UpdateResult(success=False, message="Failed to install update", old_version=old_version)

        report("Verifying installation...")
        new_version = get_current_version(game_dir)
        if new_version is None or new_version != release.version:
            report("Verification failed, restoring backup...")
            restore_from_backup(game_dir)
            cleanup_backup(game_dir)
            return UpdateResult(success=False, message="Installation verification failed", old_version=old_version)

        report("Cleaning up...")
        cleanup_backup(game_dir)
        if os.path.exists(staging_dir):
            try:
                shutil.rmtree(staging_dir)
            except Exception:
                pass

        report("Update complete!")
        return UpdateResult(
            success=True,
            message="Update installed successfully",
            old_version=old_version,
            new_version=new_version
        )

    except Exception as e:
        report(f"Unexpected error: {e}")
        try:
            restore_from_backup(game_dir)
            cleanup_backup(game_dir)
        except Exception:
            pass
        return UpdateResult(
            success=False,
            message=f"Unexpected error during update: {e}",
            old_version=old_version
        )
