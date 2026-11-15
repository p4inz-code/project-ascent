#!/usr/bin/env python
"""Project Ascent release signing (RSA-2048, PKCS#1 v1.5, SHA-256). There are NO player keys: the game is free.
This only signs RELEASES so players can tell they have the real files (see docs/PLAN_protection_and_updates.md).

The PRIVATE key never goes in the repository. Keep it offline. The PUBLIC key (assets/release_public.pem) is
baked into the game and the launcher.

  python tools/release_sign.py keygen --private C:\secret\ascent_release_private.pem --public assets/release_public.pem
  python tools/release_sign.py make-manifest --private ... --dir build/windows --version 1.0.0   (manifest.json + .sig)
  python tools/release_sign.py sign-manifest --private ... manifest.json                         (writes manifest.json.sig)
  python tools/release_sign.py verify-manifest --public assets/release_public.pem manifest.json
"""
import argparse
import base64
import json
import os
import sys

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa

def b64e(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).decode().rstrip("=")


def b64d(s: str) -> bytes:
    return base64.urlsafe_b64decode(s + "=" * (-len(s) % 4))


def load_private(path):
    with open(path, "rb") as f:
        return serialization.load_pem_private_key(f.read(), password=None)


def load_public(path):
    with open(path, "rb") as f:
        return serialization.load_pem_public_key(f.read())


def sign(private, data: bytes) -> bytes:
    return private.sign(data, padding.PKCS1v15(), hashes.SHA256())


def verify_sig(public, data: bytes, sig: bytes) -> bool:
    try:
        public.verify(sig, data, padding.PKCS1v15(), hashes.SHA256())
        return True
    except Exception:
        return False


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    k = sub.add_parser("keygen")
    k.add_argument("--private", required=True)
    k.add_argument("--public", required=True)
    s = sub.add_parser("sign-manifest")
    s.add_argument("--private", required=True)
    s.add_argument("file")
    mm = sub.add_parser("make-manifest")
    mm.add_argument("--private", required=True)
    mm.add_argument("--dir", required=True)
    mm.add_argument("--version", required=True)
    mm.add_argument("--exclude", nargs="*", default=["manifest.json", "manifest.json.sig"])
    vm = sub.add_parser("verify-manifest")
    vm.add_argument("--public", required=True)
    vm.add_argument("file")
    a = ap.parse_args()

    if a.cmd == "keygen":
        if os.path.exists(a.private):
            sys.exit("refusing to overwrite an existing private key: " + a.private)
        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        with open(a.private, "wb") as f:
            f.write(key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                                      serialization.NoEncryption()))
        with open(a.public, "wb") as f:
            f.write(key.public_key().public_bytes(serialization.Encoding.PEM,
                                                  serialization.PublicFormat.SubjectPublicKeyInfo))
        print("wrote", a.private, "(KEEP OFFLINE, never commit) and", a.public)
    elif a.cmd == "sign-manifest":
        data = open(a.file, "rb").read()
        open(a.file + ".sig", "w").write(b64e(sign(load_private(a.private), data)))
        print("wrote", a.file + ".sig")
    elif a.cmd == "make-manifest":
        import hashlib
        files = []
        for root_dir, _dirs, names in os.walk(a.dir):
            for n in sorted(names):
                full = os.path.join(root_dir, n)
                rel = os.path.relpath(full, a.dir).replace("\\", "/")
                if rel in a.exclude:
                    continue
                data = open(full, "rb").read()
                files.append({"path": rel, "sha256": hashlib.sha256(data).hexdigest(), "size": len(data)})
        files.sort(key=lambda f: f["path"])
        out = os.path.join(a.dir, "manifest.json")
        with open(out, "w", newline="\n") as mf:
            mf.write(json.dumps({"version": a.version, "files": files}, indent=1))
        with open(out + ".sig", "w", newline="\n") as sf:
            sf.write(b64e(sign(load_private(a.private), open(out, "rb").read())))
        print("wrote", out, "with", len(files), "files and its signature")
    elif a.cmd == "verify-manifest":
        data = open(a.file, "rb").read()
        sig = b64d(open(a.file + ".sig").read().strip())
        ok = verify_sig(load_public(a.public), data, sig)
        print(ok)
        sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
