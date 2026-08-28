#!/usr/bin/env python3
"""Static file server for the exported Godot HTML5 build (dev/playtest only).

Godot web builds need two things a naive file server often gets wrong:
  * the ``.wasm`` MIME type must be ``application/wasm`` or the browser refuses
    to stream-compile the module;
  * cross-origin isolation headers (COOP/COEP) must be present so that a build
    exported *with* thread support can allocate a SharedArrayBuffer. Our preset
    is single-threaded so these are not strictly required, but sending them is
    harmless (all assets are same-origin) and keeps the workflow correct if
    threads are enabled later.

This is a local development convenience only — it is never shipped and adds no
runtime backend to the game itself. Run via ``tools/serve_web.py [port]`` or the
``web`` entry in ``.claude/launch.json``.
"""

import http.server
import socketserver
import sys
from pathlib import Path

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8060
ROOT = Path(__file__).resolve().parent.parent / "build" / "web"


class GodotWebHandler(http.server.SimpleHTTPRequestHandler):
	extensions_map = {
		**http.server.SimpleHTTPRequestHandler.extensions_map,
		".wasm": "application/wasm",
		".js": "text/javascript",
		".pck": "application/octet-stream",
	}

	def __init__(self, *args, **kwargs):
		super().__init__(*args, directory=str(ROOT), **kwargs)

	def end_headers(self):
		# Cross-origin isolation (needed for threaded builds; harmless otherwise).
		self.send_header("Cross-Origin-Opener-Policy", "same-origin")
		self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
		# Always re-fetch during development so a fresh export is picked up.
		self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
		super().end_headers()

	def log_message(self, fmt, *args):
		sys.stderr.write("[serve_web] " + (fmt % args) + "\n")


def main() -> int:
	if not (ROOT / "index.html").exists():
		sys.stderr.write(
			"[serve_web] no build found at %s\n"
			"[serve_web] export first: Godot --headless --path <proj> "
			"--export-debug \"Web\" build/web/index.html\n" % ROOT
		)
		return 1
	socketserver.TCPServer.allow_reuse_address = True
	with socketserver.TCPServer(("127.0.0.1", PORT), GodotWebHandler) as httpd:
		sys.stderr.write("[serve_web] serving %s at http://127.0.0.1:%d\n" % (ROOT, PORT))
		httpd.serve_forever()
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
