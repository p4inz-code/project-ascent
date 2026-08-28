"""Tests for update checking and verification logic."""

import hashlib
import os
import tempfile
import shutil
import pytest

from launcher.version import parse_version
from launcher.updater import (
    calculate_sha256, verify_checksum, backup_installation,
    restore_from_backup, cleanup_backup, extract_update,
    install_update, get_current_version,
    GAME_EXE, GAME_PCK, VERSION_FILE, BACKUP_DIR, STAGING_DIR
)


class TestChecksumVerification:
    def test_calculate_sha256(self):
        with tempfile.NamedTemporaryFile(delete=False) as f:
            f.write(b"test content")
            path = f.name
        try:
            sha = calculate_sha256(path)
            assert len(sha) == 64
            assert sha == hashlib.sha256(b"test content").hexdigest()
        finally:
            os.unlink(path)

    def test_verify_match(self):
        with tempfile.NamedTemporaryFile(delete=False) as f:
            f.write(b"test content")
            path = f.name
        try:
            expected = hashlib.sha256(b"test content").hexdigest()
            assert verify_checksum(path, expected) is True
        finally:
            os.unlink(path)

    def test_verify_mismatch(self):
        with tempfile.NamedTemporaryFile(delete=False) as f:
            f.write(b"test content")
            path = f.name
        try:
            assert verify_checksum(path, "0" * 64) is False
        finally:
            os.unlink(path)

    def test_verify_case_insensitive(self):
        with tempfile.NamedTemporaryFile(delete=False) as f:
            f.write(b"test content")
            path = f.name
        try:
            expected = hashlib.sha256(b"test content").hexdigest().upper()
            assert verify_checksum(path, expected) is True
        finally:
            os.unlink(path)


class TestBackupAndRestore:
    def setup_method(self):
        self.d = tempfile.mkdtemp()

    def teardown_method(self):
        shutil.rmtree(self.d)

    def test_backup_creates_dir(self):
        for fn in [GAME_EXE, GAME_PCK, VERSION_FILE]:
            open(os.path.join(self.d, fn), "w").write(f"content {fn}")
        assert backup_installation(self.d) is True
        assert os.path.exists(os.path.join(self.d, BACKUP_DIR))

    def test_backup_copies_files(self):
        for fn in [GAME_EXE, GAME_PCK, VERSION_FILE]:
            open(os.path.join(self.d, fn), "w").write(f"original {fn}")
        assert backup_installation(self.d) is True
        for fn in [GAME_EXE, GAME_PCK, VERSION_FILE]:
            assert open(os.path.join(self.d, BACKUP_DIR, fn)).read() == f"original {fn}"

    def test_backup_handles_missing(self):
        open(os.path.join(self.d, GAME_EXE), "w").write("exe")
        assert backup_installation(self.d) is True

    def test_restore(self):
        for fn in [GAME_EXE, GAME_PCK, VERSION_FILE]:
            open(os.path.join(self.d, fn), "w").write(f"original {fn}")
        assert backup_installation(self.d) is True
        for fn in [GAME_EXE, GAME_PCK, VERSION_FILE]:
            open(os.path.join(self.d, fn), "w").write(f"modified {fn}")
        assert restore_from_backup(self.d) is True
        for fn in [GAME_EXE, GAME_PCK, VERSION_FILE]:
            assert open(os.path.join(self.d, fn)).read() == f"original {fn}"

    def test_restore_without_backup(self):
        assert restore_from_backup(self.d) is False

    def test_cleanup(self):
        bp = os.path.join(self.d, BACKUP_DIR)
        os.makedirs(bp)
        open(os.path.join(bp, "test.txt"), "w").write("x")
        assert os.path.exists(bp)
        cleanup_backup(self.d)
        assert not os.path.exists(bp)


class TestExtraction:
    def setup_method(self):
        self.d = tempfile.mkdtemp()

    def teardown_method(self):
        shutil.rmtree(self.d)

    def test_extract_valid_zip(self):
        import zipfile
        zp = os.path.join(self.d, "test.zip")
        with zipfile.ZipFile(zp, "w") as zf:
            zf.writestr("a.txt", "hello")
        dest = os.path.join(self.d, "out")
        assert extract_update(zp, dest) is True
        assert os.path.exists(os.path.join(dest, "a.txt"))

    def test_extract_invalid(self):
        zp = os.path.join(self.d, "bad.zip")
        open(zp, "w").write("not zip")
        assert extract_update(zp, os.path.join(self.d, "out")) is False

    def test_extract_nonexistent(self):
        assert extract_update("/nonexistent/file.zip", os.path.join(self.d, "out")) is False


class TestInstallation:
    def setup_method(self):
        self.d = tempfile.mkdtemp()

    def teardown_method(self):
        shutil.rmtree(self.d)

    def test_install(self):
        sd = os.path.join(self.d, STAGING_DIR)
        os.makedirs(sd)
        for fn in [GAME_EXE, GAME_PCK, VERSION_FILE]:
            open(os.path.join(sd, fn), "w").write(f"updated {fn}")
        for fn in [GAME_EXE, GAME_PCK, VERSION_FILE]:
            open(os.path.join(self.d, fn), "w").write(f"original {fn}")
        assert install_update(self.d, sd) is True
        for fn in [GAME_EXE, GAME_PCK, VERSION_FILE]:
            assert open(os.path.join(self.d, fn)).read() == f"updated {fn}"

    def test_install_partial(self):
        sd = os.path.join(self.d, STAGING_DIR)
        os.makedirs(sd)
        open(os.path.join(sd, GAME_EXE), "w").write("updated exe")
        for fn in [GAME_EXE, GAME_PCK, VERSION_FILE]:
            open(os.path.join(self.d, fn), "w").write(f"original {fn}")
        assert install_update(self.d, sd) is True
        assert open(os.path.join(self.d, GAME_EXE)).read() == "updated exe"
        assert open(os.path.join(self.d, GAME_PCK)).read() == "original ProjectAscent.pck"


class TestVersionReading:
    def setup_method(self):
        self.d = tempfile.mkdtemp()

    def teardown_method(self):
        shutil.rmtree(self.d)

    def test_get_version(self):
        open(os.path.join(self.d, VERSION_FILE), "w").write("0.2.0")
        v = get_current_version(self.d)
        assert v is not None and v == parse_version("0.2.0")

    def test_get_version_missing(self):
        assert get_current_version(self.d) is None

    def test_get_version_invalid(self):
        open(os.path.join(self.d, VERSION_FILE), "w").write("not-version")
        assert get_current_version(self.d) is None
