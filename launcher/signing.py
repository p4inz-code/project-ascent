"""Signed release manifests (RSA-2048, PKCS#1 v1.5, SHA-256), made by tools/license_tool.py make-manifest.

A release folder carries manifest.json (version and the SHA-256 of every game file) and manifest.json.sig.
The launcher bundles the PUBLIC key (launcher/assets/license_public.pem). When that key is present, an
update is only installed if its staged files match a manifest signed by the matching private key, so a
tampered download or a hijacked host cannot push code onto a player's machine. With no key bundled (dev
builds) the check is skipped and the existing SHA-256 download check still applies.
"""
import base64
import hashlib
import json
import os

MANIFEST = "manifest.json"
SIG = "manifest.json.sig"
KEY_NAME = "license_public.pem"


def _b64d(s: str) -> bytes:
    s = s.strip()
    return base64.urlsafe_b64decode(s + "=" * (-len(s) % 4))


def bundled_key_path(base_dir: str) -> str:
    return os.path.join(base_dir, "assets", KEY_NAME)


def verify_staged(staging_dir: str, public_pem: bytes):
    """Returns (ok, reason). ok only when the manifest signature is valid and every listed file matches."""
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import padding

    mpath = os.path.join(staging_dir, MANIFEST)
    spath = os.path.join(staging_dir, SIG)
    if not (os.path.exists(mpath) and os.path.exists(spath)):
        return False, "release has no signed manifest"
    data = open(mpath, "rb").read()
    try:
        key = serialization.load_pem_public_key(public_pem)
        key.verify(_b64d(open(spath).read()), data, padding.PKCS1v15(), hashes.SHA256())
    except Exception:
        return False, "manifest signature is not valid"
    try:
        manifest = json.loads(data)
    except Exception:
        return False, "manifest is not readable"
    for f in manifest.get("files", []):
        p = os.path.join(staging_dir, f["path"])
        if not os.path.exists(p):
            return False, "missing file %s" % f["path"]
        if hashlib.sha256(open(p, "rb").read()).hexdigest() != f["sha256"]:
            return False, "file %s was changed" % f["path"]
    return True, "ok"
