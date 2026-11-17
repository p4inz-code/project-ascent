"""Package the Godot web export into a player zip that actually works after download.

usage: python tools/package_web.py <build/web dir> <launcher/web dir> <out zip>

- Only the files the page needs (no .import files Godot may have left beside them).
- The local-server launchers from launcher/web: "Play in browser.bat" gets CRLF line endings (cmd.exe) and
  play.sh keeps LF and the executable bit (unix mode 0755 in the zip entry), so it runs on macOS/Linux.
"""
import os, sys, zipfile

web_dir, launch_dir, out = sys.argv[1], sys.argv[2], sys.argv[3]
NEEDED_EXT = {".html", ".js", ".wasm", ".pck", ".png", ".ico", ".json", ".svg", ".webmanifest"}

with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    names = sorted(os.listdir(web_dir))
    if "index.html" not in names or "index.pck" not in names or "index.wasm" not in names:
        sys.exit("web export incomplete: need index.html, index.wasm and index.pck in %s" % web_dir)
    for n in names:
        p = os.path.join(web_dir, n)
        if os.path.isfile(p) and os.path.splitext(n)[1].lower() in NEEDED_EXT:
            z.write(p, n)
    for n in sorted(os.listdir(launch_dir)):
        if n.startswith("."):
            continue      # .gdignore and other markers stay in the repo
        p = os.path.join(launch_dir, n)
        data = open(p, "rb").read()
        info = zipfile.ZipInfo(n)
        info.compress_type = zipfile.ZIP_DEFLATED
        if n.endswith(".bat") or n.endswith(".txt") or n.endswith(".ps1"):
            data = data.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")
            info.external_attr = 0o644 << 16
        elif n.endswith(".sh"):
            data = data.replace(b"\r\n", b"\n")
            info.external_attr = 0o755 << 16
        else:
            info.external_attr = 0o644 << 16
        z.writestr(info, data)
print("ok", out)
