#!/usr/bin/env python3
"""A fake GitHub for testing the game's updater: python tools/fake_github.py PORT

Serves, for each scenario NAME under http://127.0.0.1:PORT/s/NAME/ :
  api/latest                      the release JSON (what api.github.com/.../releases/latest returns)
  releases/latest                 a redirect to releases/tag/<tag> (the rate-limit fallback)
  download/<tag>/<asset>[.sha256] the update zip and its checksum
  cdn/<asset>                     where a download redirects to (stands in for objects.githubusercontent.com)
  /_hits                          how many times each kind of request was made (JSON)
Scenarios: good digest ratelimit notnewer badsha tamper truncated flaky evilredirect evilurl nosha shaother
wrongsize. Every one is a way an update can go wrong, or the way it should go right.
"""
import hashlib
import io
import json
import sys
import threading
import time
import zipfile
from collections import defaultdict
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

TAG = "v0.99.0"
VERSION = "0.99.0"
ASSET = "Project-Ascent-%s-Windows.zip" % TAG


def _blob(seed: str, size: int) -> bytes:
    out = bytearray()
    i = 0
    while len(out) < size:
        out += hashlib.sha256(("%s-%d" % (seed, i)).encode()).digest()
        i += 1
    return bytes(out[:size])


def make_zip() -> bytes:
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_STORED) as zf:
        zf.writestr("ProjectAscent.exe", _blob("exe", 3 * 1024 * 1024))
        zf.writestr("ProjectAscent.pck", _blob("pck", 512 * 1024))
        zf.writestr("version.txt", VERSION)
    return buf.getvalue()


ZIP = make_zip()
SHA = hashlib.sha256(ZIP).hexdigest()
HITS = defaultdict(int)
LOCK = threading.Lock()


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):
        pass

    def _send(self, code, body=b"", ctype="application/json", extra=None):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        if body:
            self.wfile.write(body)
        self.close_connection = True

    def _redirect(self, location):
        self._send(302, b"", "text/plain", {"Location": location})

    def _serve_zip(self, sc, kind):
        with LOCK:
            HITS[sc + ":" + kind] += 1
            n = HITS[sc + ":" + kind]
        data = ZIP
        if sc == "flaky" and n <= 2:
            return self._send(503, b"busy", "text/plain")
        if sc == "tamper":
            data = bytearray(ZIP)
            data[len(data) // 2] ^= 0xFF
            data = bytes(data)
        self.send_response(200)
        self.send_header("Content-Type", "application/zip")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Connection", "close")
        self.end_headers()
        limit = len(data) // 2 if sc == "truncated" else len(data)
        sent = 0
        while sent < limit:
            chunk = data[sent:min(limit, sent + 65536)]
            self.wfile.write(chunk)
            sent += len(chunk)
            time.sleep(0.004)   # slow enough for a progress bar to move
        self.close_connection = True   # for "truncated" this drops the connection short of Content-Length

    def do_GET(self):
        path = self.path.split("?")[0].strip("/")
        parts = path.split("/")
        if parts[0] == "_hits":
            with LOCK:
                return self._send(200, json.dumps(HITS).encode())
        if parts[0] != "s" or len(parts) < 3:
            return self._send(404, b"no", "text/plain")
        sc = parts[1]
        rest = "/".join(parts[2:])
        host = self.headers.get("Host", "127.0.0.1")
        base = "http://%s/s/%s/" % (host, sc)
        with LOCK:
            HITS[sc + ":" + rest.split("/")[0]] += 1
        if rest == "api/latest":
            if sc == "ratelimit":
                return self._send(403, json.dumps({"message": "API rate limit exceeded"}).encode())
            tag = "v0.0.1" if sc == "notnewer" else TAG
            name = ASSET if tag == TAG else "Project-Ascent-%s-Windows.zip" % tag
            url = "https://evil.example/x.zip" if sc == "evilurl" else base + "download/%s/%s" % (tag, name)
            size = len(ZIP) + 1000 if sc == "wrongsize" else len(ZIP)
            asset = {"name": name, "browser_download_url": url, "size": size}
            assets = [asset]
            if sc == "digest":
                asset["digest"] = "sha256:" + SHA
            elif sc != "nosha":
                assets.append({"name": name + ".sha256", "browser_download_url": url + ".sha256", "size": 100})
            return self._send(200, json.dumps({"tag_name": tag, "body": "Fake release notes.", "assets": assets}).encode())
        if rest == "releases/latest":
            return self._redirect(base + "releases/tag/" + TAG)
        if rest.startswith("download/") and rest.endswith(".sha256"):
            if sc == "badsha":
                return self._send(200, ("0" * 64 + "  " + ASSET + "\n").encode(), "text/plain")
            if sc == "shaother":
                return self._send(200, (SHA + "  some-other-file.zip\n").encode(), "text/plain")
            return self._send(200, (SHA + "  " + ASSET + "\n").encode(), "text/plain")
        if rest.startswith("download/"):
            if sc == "evilredirect":
                return self._redirect("https://evil.example/x.zip")
            if sc in ("good", "ratelimit", "digest", "badsha", "shaother"):
                return self._redirect(base + "cdn/" + ASSET)
            return self._serve_zip(sc, "download")
        if rest.startswith("cdn/"):
            return self._serve_zip(sc, "cdn")
        return self._send(404, b"no", "text/plain")


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    srv = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    print("fake github on %d  zip %d bytes  sha %s" % (port, len(ZIP), SHA), flush=True)
    srv.serve_forever()


if __name__ == "__main__":
    main()
