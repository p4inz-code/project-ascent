"""Signed release manifests: a genuine staged release verifies; a changed file, an edited manifest, the
wrong key and a missing manifest are each refused (negative controls). Fixtures are TEST-ONLY."""
import json
import os
import shutil
import tempfile

from launcher import signing

FIX = os.path.join(os.path.dirname(__file__), "..", "..", "tests", "fixtures", "integrity")
PUB = json.load(open(os.path.join(FIX, "public.json")))["public_pem"].encode()


def _copy_good(tmp):
    d = os.path.join(tmp, "stage")
    shutil.copytree(os.path.join(FIX, "good"), d)
    return d


def test_genuine_release_verifies():
    with tempfile.TemporaryDirectory() as tmp:
        assert signing.verify_staged(_copy_good(tmp), PUB) == (True, "ok")


def test_changed_file_is_refused():
    with tempfile.TemporaryDirectory() as tmp:
        d = _copy_good(tmp)
        open(os.path.join(d, "a.bin"), "wb").write(b"patched")
        ok, why = signing.verify_staged(d, PUB)
        assert not ok and "a.bin" in why


def test_edited_manifest_is_refused():
    with tempfile.TemporaryDirectory() as tmp:
        d = _copy_good(tmp)
        p = os.path.join(d, "manifest.json")
        open(p, "w").write(open(p).read().replace("9.9.9", "1.0.0"))
        ok, why = signing.verify_staged(d, PUB)
        assert not ok and "signature" in why


def test_wrong_key_is_refused():
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric import rsa
    other = rsa.generate_private_key(public_exponent=65537, key_size=2048).public_key().public_bytes(
        serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo)
    with tempfile.TemporaryDirectory() as tmp:
        ok, why = signing.verify_staged(_copy_good(tmp), other)
        assert not ok and "signature" in why


def test_missing_manifest_is_refused():
    with tempfile.TemporaryDirectory() as tmp:
        d = _copy_good(tmp)
        os.remove(os.path.join(d, "manifest.json.sig"))
        ok, why = signing.verify_staged(d, PUB)
        assert not ok and "no signed manifest" in why
