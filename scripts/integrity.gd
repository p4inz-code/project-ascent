# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
class_name Integrity
extends RefCounted
## Authenticity check for a release folder. A release ships `manifest.json` (version and the SHA-256 and size
## of every file) plus `manifest.json.sig` (RSA-SHA256 signature of the manifest, made offline with
## tools/release_sign.py). check() verifies the signature with the PUBLIC key baked into the game, then
## hashes each listed file. Dev builds (no manifest) report "unsigned" and nothing happens; a release whose
## files or manifest were changed reports "modified" and the game shows a plain notice naming the
## official download page. It protects players from malware repacks; see docs/PLAN_protection_and_updates.md.

const PUBLIC_KEY_PATH := "res://assets/release_public.pem"
const OFFICIAL_URL := "https://github.com/p4inz-code/project-ascent/releases"

## check(): {"state": "unsigned"|"ok"|"modified"|"bad_signature"|"no_key", "bad": Array[String], "version": String}


static func check(dir: String, public_pem: String = "") -> Dictionary:
	if dir == "":
		return {"state": "unsigned", "bad": [], "version": ""}
	var manifest_path := dir.path_join("manifest.json")
	var sig_path := manifest_path + ".sig"
	if not FileAccess.file_exists(manifest_path) or not FileAccess.file_exists(sig_path):
		return {"state": "unsigned", "bad": [], "version": ""}
	var pem := public_pem
	if pem == "" and FileAccess.file_exists(PUBLIC_KEY_PATH):
		pem = FileAccess.get_file_as_string(PUBLIC_KEY_PATH)
	if pem == "":
		return {"state": "no_key", "bad": [], "version": ""}
	var raw := FileAccess.get_file_as_bytes(manifest_path)
	var sig := _b64url_decode(FileAccess.get_file_as_string(sig_path).strip_edges())
	var key := CryptoKey.new()
	if sig.is_empty() or key.load_from_string(pem, true) != OK:
		return {"state": "bad_signature", "bad": [], "version": ""}
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(raw)
	if not Crypto.new().verify(HashingContext.HASH_SHA256, ctx.finish(), sig, key):
		return {"state": "bad_signature", "bad": [], "version": ""}
	var parsed = JSON.parse_string(raw.get_string_from_utf8())
	if not (parsed is Dictionary):
		return {"state": "bad_signature", "bad": [], "version": ""}
	var bad: Array = []
	for f in parsed.get("files", []):
		var p: String = dir.path_join(String(f["path"]))
		if not FileAccess.file_exists(p) or FileAccess.get_sha256(p) != String(f["sha256"]):
			bad.append(String(f["path"]))
	return {"state": "modified" if not bad.is_empty() else "ok", "bad": bad, "version": String(parsed.get("version", ""))}


## The folder the game runs from (next to the exe); empty in the editor.
static func release_dir() -> String:
	if OS.has_feature("editor"):
		return ""
	return OS.get_executable_path().get_base_dir()


static func notice_text(result: Dictionary) -> String:
	match String(result.get("state", "")):
		"modified", "bad_signature":
			return "THIS COPY WAS CHANGED AFTER RELEASE. GET THE REAL GAME FROM %s" % OFFICIAL_URL.trim_prefix("https://").to_upper()
	return ""


static func _b64url_decode(s: String) -> PackedByteArray:
	var rx := RegEx.new()
	rx.compile("^[A-Za-z0-9_-]+$")
	if rx.search(s) == null:
		return PackedByteArray()
	var t := s.replace("-", "+").replace("_", "/")
	while t.length() % 4 != 0:
		t += "="
	return Marshalls.base64_to_raw(t)
