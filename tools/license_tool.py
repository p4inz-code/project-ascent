#!/usr/bin/env python
"""Project Ascent license and update-manifest tool (RSA-2048, PKCS#1 v1.5, SHA-256).

The PRIVATE key never goes in the repository. Keep it offline (a password manager or an encrypted
drive) and sign keys and update manifests with it on your own machine or on the licence server.
The PUBLIC key is baked into the game and the launcher.

  python tools/license_tool.py keygen   --private C:\\secret\\ascent_private.pem --public assets/license_public.pem
  python tools/license_tool.py make-key --private C:\\secret\\ascent_private.pem --edition full --count 5
  python tools/license_tool.py make-key --private ... --edition tester --days 14 --id yt-reviewer-1
  python tools/license_tool.py verify   --public assets/license_public.pem PA1.xxxx.yyyy
  python tools/license_tool.py make-manifest --private ... --dir build/windows --version 1.0.0   (manifest.json + .sig)
  python tools/license_tool.py sign-manifest --private ... manifest.json      (writes manifest.json.sig)
  python tools/license_tool.py verify-manifest --public ... manifest.json

Token layout: "PA1." + base64url(payload JSON) + "." + base64url(signature over the payload bytes).
Payload: {"v": 1, "id": random id, "ed": "full"|"tester"|"press", "iat": unix time, "exp": unix time or 0}.
"""
import argparse
import base64
import json
import os
import secrets
import sys
import time

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa

PREFIX = "PA1"


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


def make_token(private, edition: str, days: int = 0, key_id: str = "") -> str:
    now = int(time.time())
    payload = {"v": 1, "id": key_id or secrets.token_hex(6), "ed": edition, "iat": now,
               "exp": now + days * 86400 if days > 0 else 0}
    raw = json.dumps(payload, separators=(",", ":"), sort_keys=True).encode()
    return "%s.%s.%s" % (PREFIX, b64e(raw), b64e(sign(private, raw)))


def check_token(public, token: str):
    parts = token.strip().split(".")
    if len(parts) != 3 or parts[0] != PREFIX:
        return False, "format", {}
    try:
        raw, sig = b64d(parts[1]), b64d(parts[2])
    except Exception:
        return False, "format", {}
    if not verify_sig(public, raw, sig):
        return False, "signature", {}
    try:
        payload = json.loads(raw)
    except Exception:
        return False, "payload", {}
    if payload.get("exp", 0) and payload["exp"] < time.time():
        return False, "expired", payload
    return True, "ok", payload


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    k = sub.add_parser("keygen")
    k.add_argument("--private", required=True)
    k.add_argument("--public", required=True)
    m = sub.add_parser("make-key")
    m.add_argument("--private", required=True)
    m.add_argument("--edition", default="full")
    m.add_argument("--count", type=int, default=1)
    m.add_argument("--days", type=int, default=0)
    m.add_argument("--id", default="")
    v = sub.add_parser("verify")
    v.add_argument("--public", required=True)
    v.add_argument("token")
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
    elif a.cmd == "make-key":
        priv = load_private(a.private)
        for _ in range(a.count):
            print(make_token(priv, a.edition, a.days, a.id))
    elif a.cmd == "verify":
        ok, why, payload = check_token(load_public(a.public), a.token)
        print(ok, why, json.dumps(payload))
        sys.exit(0 if ok else 1)
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
        open(out, "w").write(json.dumps({"version": a.version, "files": files}, indent=1))
        open(out + ".sig", "w").write(b64e(sign(load_private(a.private), open(out, "rb").read())))
        print("wrote", out, "with", len(files), "files and its signature")
    elif a.cmd == "verify-manifest":
        data = open(a.file, "rb").read()
        sig = b64d(open(a.file + ".sig").read().strip())
        ok = verify_sig(load_public(a.public), data, sig)
        print(ok)
        sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
