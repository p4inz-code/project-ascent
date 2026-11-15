"""Add the copyright + SPDX header to every game script that lacks it (idempotent)."""
import glob
import os

HEADER = ("# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. All rights reserved. See LICENSE.\n"
          "# SPDX-License-Identifier: LicenseRef-ProjectAscent-FreeToPlay\n")
MARK = "SPDX-License-Identifier: LicenseRef-ProjectAscent-FreeToPlay"
n = 0
for path in sorted(glob.glob("scripts/*.gd")):
    raw = open(path, "rb").read()
    text = raw.decode("utf-8")
    if MARK in text[:400]:
        continue
    crlf = "\r\n" in text
    head = HEADER.replace("\n", "\r\n") if crlf else HEADER
    open(path, "wb").write((head + text).encode("utf-8"))
    n += 1
print("headers added:", n)
