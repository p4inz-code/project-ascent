"""Security guards on the auto-updater.

The updater downloads a ZIP and unpacks an executable the launcher then runs,
which makes it the only genuine attack surface in an otherwise fully offline
game. Each test here is a negative control: it feeds the guard the exact input
it exists to reject, so a guard that silently stops working fails loudly.

All three of these were real holes:
  * the path-traversal check used startswith(), which a SIBLING directory
    slips through
  * checksum verification was conditional on an asset no release published,
    so every update installed unverified
  * the download accepted any scheme, including a plain-http redirect
"""
import os
import tempfile
import zipfile

from launcher import updater


def _zip_with_member(tmp_dir, arcname, payload=b"x"):
    path = os.path.join(tmp_dir, "evil.zip")
    with zipfile.ZipFile(path, "w") as zf:
        zf.writestr(arcname, payload)
    return path


def test_extract_rejects_parent_traversal():
    with tempfile.TemporaryDirectory() as tmp:
        dest = os.path.join(tmp, "staging")
        os.makedirs(dest)
        zip_path = _zip_with_member(tmp, "../escaped.txt")
        assert updater.extract_update(zip_path, dest) is False
        assert not os.path.exists(os.path.join(tmp, "escaped.txt"))


def test_extract_rejects_sibling_prefix_directory():
    """The bug startswith() had: "/staging-evil" starts with "/staging"."""
    with tempfile.TemporaryDirectory() as tmp:
        dest = os.path.join(tmp, "staging")
        os.makedirs(dest)
        # Climbs out of staging and into a sibling sharing its name prefix.
        zip_path = _zip_with_member(tmp, os.path.join("..", "staging-evil", "p.txt"))
        assert updater.extract_update(zip_path, dest) is False
        assert not os.path.exists(os.path.join(tmp, "staging-evil"))


def test_extract_accepts_a_normal_archive():
    """The guard must not be so strict that legitimate updates fail."""
    with tempfile.TemporaryDirectory() as tmp:
        dest = os.path.join(tmp, "staging")
        os.makedirs(dest)
        zip_path = _zip_with_member(tmp, os.path.join("sub", "ok.txt"), b"fine")
        assert updater.extract_update(zip_path, dest) is True
        assert os.path.exists(os.path.join(dest, "sub", "ok.txt"))


def test_download_refuses_non_https():
    with tempfile.TemporaryDirectory() as tmp:
        out = os.path.join(tmp, "out.bin")
        assert updater.download_file("http://example.com/x.zip", out) is False
        assert updater.download_file("ftp://example.com/x.zip", out) is False
        # Nothing may be written when the scheme is refused.
        assert not os.path.exists(out)


def test_checksum_detects_tampering():
    with tempfile.TemporaryDirectory() as tmp:
        f = os.path.join(tmp, "a.bin")
        with open(f, "wb") as fh:
            fh.write(b"original")
        good = updater.calculate_sha256(f)
        assert updater.verify_checksum(f, good) is True

        with open(f, "wb") as fh:
            fh.write(b"tampered")
        assert updater.verify_checksum(f, good) is False


def test_checksum_comparison_is_case_insensitive():
    """Published hashes are sometimes uppercase; that must still verify."""
    with tempfile.TemporaryDirectory() as tmp:
        f = os.path.join(tmp, "a.bin")
        with open(f, "wb") as fh:
            fh.write(b"payload")
        digest = updater.calculate_sha256(f)
        assert updater.verify_checksum(f, digest.upper()) is True
