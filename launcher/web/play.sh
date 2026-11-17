#!/bin/sh
# Project Ascent web build (macOS / Linux): serve this folder on localhost and open the game in the browser.
# Opening index.html directly does not work: browsers block web games from file://.
cd "$(dirname "$0")" || exit 1
PORT=8060
URL="http://localhost:$PORT/index.html"
if command -v python3 >/dev/null 2>&1; then PY=python3; elif command -v python >/dev/null 2>&1; then PY=python; else
  echo "Python 3 is needed to serve the game locally (macOS: xcode-select --install, Linux: your package manager)."
  exit 1
fi
echo "PROJECT ASCENT is running at $URL - press Ctrl+C here to stop."
( sleep 1; if command -v open >/dev/null 2>&1; then open "$URL"; else xdg-open "$URL" >/dev/null 2>&1; fi ) &
exec "$PY" -m http.server "$PORT" --bind 127.0.0.1
