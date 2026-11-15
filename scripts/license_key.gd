# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. All rights reserved. See LICENSE.
# SPDX-License-Identifier: LicenseRef-ProjectAscent-FreeToPlay
class_name LicenseKey
extends RefCounted
## Offline verification of a Project Ascent license key (see tools/license_tool.py for the format).
##
## A key is "PA1." + base64url(payload JSON) + "." + base64url(RSA-SHA256 signature of the payload bytes).
## The game holds only the PUBLIC key, so a key cannot be forged without the private key, and the check
## needs no network. This is one layer of the protection plan in docs/PLAN_protection_and_updates.md:
## it proves a key is genuine; it cannot, on its own, stop someone sharing a genuine key or patching
## the check out of the binary (see the plan for the other layers).

const PREFIX := "PA1"
const PUBLIC_KEY_PATH := "res://assets/license_public.pem"

## verify(): {"ok": bool, "reason": "ok"|"format"|"signature"|"payload"|"expired"|"no_key", "payload": Dictionary}


static func verify(token: String, public_pem: String = "", now_unix: int = -1) -> Dictionary:
	var pem := public_pem
	if pem == "":
		pem = _read_public_key()
	if pem == "":
		return {"ok": false, "reason": "no_key", "payload": {}}
	var parts := token.strip_edges().split(".")
	if parts.size() != 3 or parts[0] != PREFIX:
		return {"ok": false, "reason": "format", "payload": {}}
	var raw := _b64url_decode(parts[1])
	var sig := _b64url_decode(parts[2])
	if raw.is_empty() or sig.is_empty():
		return {"ok": false, "reason": "format", "payload": {}}
	var key := CryptoKey.new()
	if key.load_from_string(pem, true) != OK:
		return {"ok": false, "reason": "no_key", "payload": {}}
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(raw)
	var digest := ctx.finish()
	var crypto := Crypto.new()
	if not crypto.verify(HashingContext.HASH_SHA256, digest, sig, key):
		return {"ok": false, "reason": "signature", "payload": {}}
	var parsed = JSON.parse_string(raw.get_string_from_utf8())
	if not (parsed is Dictionary):
		return {"ok": false, "reason": "payload", "payload": {}}
	var payload: Dictionary = parsed
	var now := now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	var exp := int(payload.get("exp", 0))
	if exp > 0 and exp < now:
		return {"ok": false, "reason": "expired", "payload": payload}
	return {"ok": true, "reason": "ok", "payload": payload}


static func _read_public_key() -> String:
	if not FileAccess.file_exists(PUBLIC_KEY_PATH):
		return ""
	var f := FileAccess.open(PUBLIC_KEY_PATH, FileAccess.READ)
	return f.get_as_text() if f != null else ""


static func _b64url_decode(s: String) -> PackedByteArray:
	var rx := RegEx.new()
	rx.compile("^[A-Za-z0-9_-]+$")
	if rx.search(s) == null:
		return PackedByteArray()
	var t := s.replace("-", "+").replace("_", "/")
	while t.length() % 4 != 0:
		t += "="
	return Marshalls.base64_to_raw(t)
