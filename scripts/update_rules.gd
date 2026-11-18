# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
class_name UpdateRules
extends RefCounted
## The pure rules of the self-updater (no network, no files): which versions are newer, which addresses it may
## talk to, how a GitHub release is read, how a checksum file is parsed. Kept apart from the service
## (game_updater.gd) so every rule can be tested with a negative control.
##
## The model is the owner's Kinoz updater: only this project's own GitHub repository, only HTTPS, only a file
## whose SHA-256 matches the checksum published with the release, nothing sent about the player.

const REPO := "p4inz-code/project-ascent"
const API_LATEST := "https://api.github.com/repos/p4inz-code/project-ascent/releases/latest"
const PAGE_LATEST := "https://github.com/p4inz-code/project-ascent/releases/latest"
const MAX_DOWNLOAD_BYTES := 400 * 1024 * 1024
const MAX_REDIRECTS := 5

## Development only: an extra base address (a local test server) that counts as allowed. It is honoured in
## debug builds only, so a released game can never be pointed anywhere else.
static var test_base: String = ""


## "v0.17.0" or "0.17.0" -> [0, 17, 0]. Anything else -> [] (not a version).
static func parse_version(text: String) -> Array:
	var t := text.strip_edges()
	if t.begins_with("v") or t.begins_with("V"):
		t = t.substr(1)
	var parts := t.split(".")
	if parts.size() < 2 or parts.size() > 4:
		return []
	var out: Array = []
	for p in parts:
		if p.is_empty() or not p.is_valid_int() or p.begins_with("-") or p.begins_with("+"):
			return []
		out.append(int(p))
	return out


## True only when both are real versions and the candidate is higher. A game with no version file (a dev run)
## is never told to update.
static func is_newer(candidate: String, installed: String) -> bool:
	var a := parse_version(candidate)
	var b := parse_version(installed)
	if a.is_empty() or b.is_empty():
		return false
	var n := maxi(a.size(), b.size())
	for i in n:
		var x: int = a[i] if i < a.size() else 0
		var y: int = b[i] if i < b.size() else 0
		if x != y:
			return x > y
	return false


static func _host(url: String) -> String:
	if not url.begins_with("https://"):
		return ""
	var rest := url.substr(8)
	var end := rest.find("/")
	var host := rest if end < 0 else rest.substr(0, end)
	if host.is_empty() or host.contains("@") or host.contains(":"):
		return ""
	return host.to_lower()


static func _is_test_url(url: String) -> bool:
	return test_base != "" and OS.is_debug_build() and url.begins_with(test_base)


## A URL that is plain: no spaces or control characters, and a path with no dot-segments, backslashes or
## encoded dots or slashes that a server might resolve to somewhere other than what the prefix check saw.
## (The query part may hold anything: GitHub's signed download links are full of %-codes.)
static func _plain(url: String) -> bool:
	for c in url:
		if c.unicode_at(0) <= 32 or c.unicode_at(0) == 127 or c == "\\":
			return false
	var path := url
	for stop in ["?", "#"]:
		var i := path.find(stop)
		if i >= 0:
			path = path.substr(0, i)
	var lower := path.to_lower()
	for bad in ["/../", "/./", "%2e", "%2f", "%5c"]:
		if lower.contains(bad):
			return false
	return not (lower.ends_with("/..") or lower.ends_with("/."))


## A request the game itself starts: only this project's own pages on GitHub.
static func url_allowed(url: String) -> bool:
	if _is_test_url(url):
		return true
	if not _plain(url):
		return false
	var h := _host(url)
	if h == "api.github.com":
		return url.begins_with("https://api.github.com/repos/" + REPO + "/")
	if h == "github.com":
		return url.begins_with("https://github.com/" + REPO + "/")
	return false


## Where a redirect may lead: https on github.com or GitHub's content hosts, nowhere else.
static func redirect_allowed(url: String) -> bool:
	if _is_test_url(url):
		return true
	if not _plain(url):
		return false
	var h := _host(url)
	return h == "github.com" or h == "githubusercontent.com" or h.ends_with(".githubusercontent.com")


## ".../releases/tag/v1.2.3" -> "v1.2.3"; anything else (or a tag that is not a version) -> "".
static func tag_from_location(url: String) -> String:
	var marker := "/releases/tag/"
	var i := url.find(marker)
	if i < 0:
		return ""
	var tag := url.substr(i + marker.length())
	for stop in ["?", "#", "/"]:
		var j := tag.find(stop)
		if j >= 0:
			tag = tag.substr(0, j)
	return tag if not parse_version(tag).is_empty() else ""


## This system's download name for a version. Only Windows installs itself; the other systems use the page.
static func asset_name_for(version: String) -> String:
	return "Project-Ascent-v%s-Windows.zip" % version.trim_prefix("v").trim_prefix("V")


static func asset_url_for(tag: String) -> String:
	return "https://github.com/%s/releases/download/%s/%s" % [REPO, tag, asset_name_for(tag)]


static func is_sha256(text: String) -> bool:
	if text.length() != 64:
		return false
	for c in text.to_lower():
		if not "0123456789abcdef".contains(c):
			return false
	return true


## A checksum file holds "hash  name" or "hash *name" or just the hash. When a name is present it must be the
## file we asked for, so a checksum for some other file can never be used.
static func parse_sha(text: String, asset_name: String) -> String:
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line.is_empty():
			continue
		var fields := line.split(" ", false)
		var hash := String(fields[0]).to_lower()
		if not is_sha256(hash):
			continue
		if fields.size() == 1:
			return hash
		var name := String(fields[fields.size() - 1]).trim_prefix("*")
		if name == asset_name:
			return hash
	return ""


## Read a GitHub release (the parsed JSON of /releases/latest). Returns {ok, reason, tag, version, newer,
## notes, asset, url, size, sha, sha_url}. `sha` comes from the release's own digest when it has one,
## otherwise `sha_url` names the published .sha256 file that must be fetched next.
static func pick_assets(release: Dictionary, installed: String) -> Dictionary:
	var out := {"ok": false, "reason": "", "tag": "", "version": "", "newer": false, "notes": "", "asset": "",
		"url": "", "size": 0, "sha": "", "sha_url": ""}
	var tag := String(release.get("tag_name", ""))
	if parse_version(tag).is_empty():
		out["reason"] = "The release has no usable version tag."
		return out
	out["tag"] = tag
	out["version"] = tag.trim_prefix("v").trim_prefix("V")
	out["notes"] = String(release.get("body", "")).left(2000)
	out["newer"] = is_newer(tag, installed)
	var want := asset_name_for(tag)
	out["asset"] = want
	var assets = release.get("assets", [])
	if not (assets is Array):
		out["reason"] = "The release lists no files."
		return out
	var found: Dictionary = {}
	var sha_asset: Dictionary = {}
	for a in assets:
		if a is Dictionary:
			var n := String(a.get("name", ""))
			if n == want:
				found = a
			elif n == want + ".sha256":
				sha_asset = a
	if found.is_empty():
		out["reason"] = "No download for this system in the release."
		return out
	var url := String(found.get("browser_download_url", ""))
	if not url_allowed(url):
		out["reason"] = "The download address is not on this project's GitHub page."
		return out
	var size := int(found.get("size", 0))
	if size <= 0 or size > MAX_DOWNLOAD_BYTES:
		out["reason"] = "The download has an unusable size."
		return out
	out["url"] = url
	out["size"] = size
	var digest := String(found.get("digest", ""))
	if digest.begins_with("sha256:") and is_sha256(digest.substr(7)):
		out["sha"] = digest.substr(7).to_lower()
	elif not sha_asset.is_empty():
		var sha_url := String(sha_asset.get("browser_download_url", ""))
		if url_allowed(sha_url):
			out["sha_url"] = sha_url
	if out["sha"] == "" and out["sha_url"] == "":
		out["reason"] = "No checksum is published with this release."
		return out
	out["ok"] = true
	return out


## Only dropped connections and server errors are worth another try; a refusal or a bad file is not.
static func should_retry(http_code: int, result: int, tries: int) -> bool:
	if tries >= 3:
		return false
	if http_code >= 500:
		return true
	return result in [HTTPRequest.RESULT_CONNECTION_ERROR, HTTPRequest.RESULT_CANT_CONNECT,
		HTTPRequest.RESULT_NO_RESPONSE, HTTPRequest.RESULT_TIMEOUT]


## A failed check is retried after 1 hour, then 6 hours.
static func retry_delay(failures: int) -> float:
	return 3600.0 if failures <= 1 else 21600.0


static func verify_file(path: String, expected_sha: String) -> bool:
	if not is_sha256(expected_sha) or not FileAccess.file_exists(path):
		return false
	return FileAccess.get_sha256(path).to_lower() == expected_sha.to_lower()


const MODE_NAMES: Array[String] = ["AUTOMATIC", "NOTIFY ME", "OFF"]


static func clamp_mode(m: int) -> int:
	return clampi(m, 0, MODE_NAMES.size() - 1)
