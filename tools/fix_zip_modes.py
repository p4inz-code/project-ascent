"""Give the macOS and Linux release zips real Unix permissions.

Windows' Compress-Archive (and .NET's ZipArchive) record no Unix permissions, so after unzipping on Linux the game
binary is not executable and the player has to run `chmod +x` first. This rewrites each zip with the Unix mode set on
every entry: 755 for the game binary (the .x86_64 file, anything under *.app/Contents/MacOS/, shell scripts and
folders), 644 for everything else.

usage: python tools/fix_zip_modes.py dist/Project-Ascent-v0.18.0-Linux.zip dist/Project-Ascent-v0.18.0-macOS.zip
"""
import os
import sys
import zipfile


def is_executable(name: str) -> bool:
    base = name.rsplit("/", 1)[-1]
    return (base.endswith(".x86_64") or base.endswith(".sh") or base.endswith(".command")
            or "/Contents/MacOS/" in name or base == "ProjectAscent")


def fix(path: str) -> int:
    tmp = path + ".tmp"
    changed = 0
    with zipfile.ZipFile(path) as src, zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as dst:
        for info in src.infolist():
            zi = zipfile.ZipInfo(info.filename, info.date_time)
            zi.create_system = 3          # Unix: the mode in external_attr is honoured by unzip
            zi.compress_type = zipfile.ZIP_DEFLATED
            if info.is_dir():
                zi.external_attr = (0o040755 << 16) | 0x10
                dst.writestr(zi, b"")
                continue
            mode = 0o755 if is_executable(info.filename) else 0o644
            zi.external_attr = (0o100000 | mode) << 16
            if mode == 0o755:
                changed += 1
            dst.writestr(zi, src.read(info.filename))
    os.replace(tmp, path)
    return changed


if __name__ == "__main__":
    for p in sys.argv[1:]:
        if not os.path.exists(p):
            sys.exit("missing zip: %s" % p)
        print("%s: %d executable entr%s" % (os.path.basename(p), n := fix(p), "y" if n == 1 else "ies"))
