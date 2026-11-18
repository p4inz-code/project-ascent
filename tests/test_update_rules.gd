extends SceneTree
## The self-updater's rules (scripts/update_rules.gd). Every rule has a negative control: the thing it must
## refuse. These are the checks that keep a bad update from ever being installed.

var _failures: int = 0


func _initialize() -> void:
	_run()
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


const GOOD_SHA := "a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90"


func _release(tag: String, with_digest: bool, with_sha_asset: bool, url_base: String = "https://github.com/p4inz-code/project-ascent/releases/download/") -> Dictionary:
	var name := UpdateRules.asset_name_for(tag)
	var assets: Array = [{"name": name, "browser_download_url": url_base + tag + "/" + name, "size": 54000000}]
	if with_digest:
		assets[0]["digest"] = "sha256:" + GOOD_SHA
	if with_sha_asset:
		assets.append({"name": name + ".sha256", "browser_download_url": url_base + tag + "/" + name + ".sha256", "size": 100})
	return {"tag_name": tag, "body": "notes", "assets": assets}


func _run() -> void:
	# --- versions
	_check("v0.17.0 parses", UpdateRules.parse_version("v0.17.0") == [0, 17, 0])
	_check("0.18 parses (two parts)", UpdateRules.parse_version("0.18") == [0, 18])
	_check("control: garbage is not a version", UpdateRules.parse_version("latest").is_empty())
	_check("control: a negative part is refused", UpdateRules.parse_version("1.-2.0").is_empty())
	_check("control: one part is refused", UpdateRules.parse_version("7").is_empty())
	_check("control: an empty part is refused", UpdateRules.parse_version("1..2").is_empty())
	_check("0.18.0 is newer than 0.17.0", UpdateRules.is_newer("v0.18.0", "0.17.0"))
	_check("0.99.0 is newer than 0.18.0", UpdateRules.is_newer("0.99.0", "0.18.0"))
	_check("1.0.0 is newer than 0.99.9", UpdateRules.is_newer("1.0.0", "0.99.9"))
	_check("0.17.10 is newer than 0.17.9 (numbers, not text)", UpdateRules.is_newer("0.17.10", "0.17.9"))
	_check("control: the same version is not newer", not UpdateRules.is_newer("0.17.0", "v0.17.0"))
	_check("control: an older version is not newer", not UpdateRules.is_newer("0.16.1", "0.17.0"))
	_check("control: a missing local version never nags a dev run", not UpdateRules.is_newer("9.9.9", ""))
	_check("control: a bad tag is never newer", not UpdateRules.is_newer("nightly", "0.17.0"))
	_check("1.0 equals 1.0.0", not UpdateRules.is_newer("1.0", "1.0.0") and not UpdateRules.is_newer("1.0.0", "1.0"))

	# --- addresses
	_check("the release API for this repo is allowed", UpdateRules.url_allowed(UpdateRules.API_LATEST))
	_check("the release page of this repo is allowed", UpdateRules.url_allowed(UpdateRules.PAGE_LATEST))
	_check("a release download of this repo is allowed", UpdateRules.url_allowed(UpdateRules.asset_url_for("v0.18.0")))
	_check("control: plain http is refused", not UpdateRules.url_allowed("http://github.com/p4inz-code/project-ascent/releases/latest"))
	_check("control: another repository is refused", not UpdateRules.url_allowed("https://github.com/someone/else/releases/download/v1/x.zip"))
	_check("control: another host is refused", not UpdateRules.url_allowed("https://evil.example/p4inz-code/project-ascent/x.zip"))
	_check("control: a look-alike host is refused", not UpdateRules.url_allowed("https://github.com.evil.example/p4inz-code/project-ascent/x"))
	_check("control: userinfo tricks are refused", not UpdateRules.url_allowed("https://github.com@evil.example/p4inz-code/project-ascent/x"))
	_check("control: a port is refused", not UpdateRules.url_allowed("https://github.com:8443/p4inz-code/project-ascent/x"))
	_check("control: the API of another repo is refused", not UpdateRules.url_allowed("https://api.github.com/repos/someone/else/releases/latest"))
	_check("a redirect to GitHub's content host is allowed", UpdateRules.redirect_allowed("https://objects.githubusercontent.com/abc/def?x=1"))
	_check("a redirect to release-assets is allowed", UpdateRules.redirect_allowed("https://release-assets.githubusercontent.com/x"))
	_check("a redirect within github.com is allowed", UpdateRules.redirect_allowed("https://github.com/p4inz-code/project-ascent/releases/tag/v0.18.0"))
	_check("control: a redirect to another host is refused", not UpdateRules.redirect_allowed("https://evil.example/x.zip"))
	_check("control: a redirect to a look-alike content host is refused", not UpdateRules.redirect_allowed("https://evilgithubusercontent.com/x"))
	_check("control: a redirect to plain http is refused", not UpdateRules.redirect_allowed("http://objects.githubusercontent.com/x"))
	# dot-segments and encodings that a server might resolve past the prefix check
	_check("control: a dot-dot path under the right prefix is refused", not UpdateRules.url_allowed("https://github.com/p4inz-code/project-ascent/../../evil/repo/releases/download/v1/x.zip"))
	_check("control: an encoded dot-dot is refused", not UpdateRules.url_allowed("https://github.com/p4inz-code/project-ascent/%2e%2e/%2E%2e/evil/x.zip"))
	_check("control: a single-dot segment is refused", not UpdateRules.url_allowed("https://github.com/p4inz-code/project-ascent/./releases/latest"))
	_check("control: an encoded slash in the path is refused", not UpdateRules.url_allowed("https://github.com/p4inz-code/project-ascent/releases%2f..%2fx"))
	_check("control: a backslash is refused", not UpdateRules.url_allowed("https://github.com/p4inz-code/project-ascent/releases\\latest"))
	_check("control: a space or newline is refused", not UpdateRules.url_allowed("https://github.com/p4inz-code/project-ascent/a b") and not UpdateRules.url_allowed("https://github.com/p4inz-code/project-ascent/a\nb"))
	_check("control: a trailing dot-dot is refused", not UpdateRules.url_allowed("https://github.com/p4inz-code/project-ascent/.."))
	_check("a signed download link with %-codes in its query is still allowed", UpdateRules.redirect_allowed("https://release-assets.githubusercontent.com/github-production-release-asset/1/2?sp=r&rscd=attachment%3B%20filename%3Dx.zip&rsct=application%2Foctet-stream"))
	_check("control: a dot-dot in a redirect path is refused", not UpdateRules.redirect_allowed("https://github.com/p4inz-code/project-ascent/../../evil"))
	# the development override must stay off unless a test sets it, and never matches a lookalike
	_check("control: the test base is off by default", UpdateRules.test_base == "" and not UpdateRules.url_allowed("http://127.0.0.1:8765/api/latest"))

	# --- tags from the releases/latest redirect
	_check("tag from a release redirect", UpdateRules.tag_from_location("https://github.com/p4inz-code/project-ascent/releases/tag/v0.18.0") == "v0.18.0")
	_check("tag ignores a query string", UpdateRules.tag_from_location("https://github.com/p4inz-code/project-ascent/releases/tag/v1.0.0?x=1") == "v1.0.0")
	_check("control: a non-release location gives no tag", UpdateRules.tag_from_location("https://github.com/p4inz-code/project-ascent/issues/3") == "")
	_check("control: a tag that is not a version gives none", UpdateRules.tag_from_location("https://github.com/p4inz-code/project-ascent/releases/tag/nightly") == "")

	# --- checksum files
	var an := UpdateRules.asset_name_for("v0.18.0")
	_check("the asset name", an == "Project-Ascent-v0.18.0-Windows.zip")
	_check("a bare hash is read", UpdateRules.parse_sha(GOOD_SHA + "\n", an) == GOOD_SHA)
	_check("'hash  name' is read", UpdateRules.parse_sha(GOOD_SHA.to_upper() + "  " + an, an) == GOOD_SHA)
	_check("'hash *name' is read", UpdateRules.parse_sha(GOOD_SHA + " *" + an, an) == GOOD_SHA)
	_check("control: a checksum for another file is refused", UpdateRules.parse_sha(GOOD_SHA + "  other.zip", an) == "")
	_check("control: a short hash is refused", UpdateRules.parse_sha("abc123  " + an, an) == "")
	_check("control: a non-hex hash is refused", UpdateRules.parse_sha("z".repeat(64) + "  " + an, an) == "")
	_check("control: an empty file gives nothing", UpdateRules.parse_sha("", an) == "")

	# --- reading a release
	var ok := UpdateRules.pick_assets(_release("v0.18.0", true, false), "0.17.0")
	_check("a release with a digest is usable and newer", ok["ok"] and ok["newer"] and ok["sha"] == GOOD_SHA and ok["version"] == "0.18.0")
	var ok2 := UpdateRules.pick_assets(_release("v0.18.0", false, true), "0.17.0")
	_check("a release with a .sha256 file points at it", ok2["ok"] and ok2["sha"] == "" and String(ok2["sha_url"]).ends_with(".sha256"))
	var same := UpdateRules.pick_assets(_release("v0.17.0", true, false), "0.17.0")
	_check("control: the same version is not newer", same["ok"] and not same["newer"])
	var nosha := UpdateRules.pick_assets(_release("v0.18.0", false, false), "0.17.0")
	_check("control: no checksum published means no update", not nosha["ok"])
	var wrongurl := UpdateRules.pick_assets(_release("v0.18.0", true, false, "https://evil.example/dl/"), "0.17.0")
	_check("control: a download from another host is refused", not wrongurl["ok"])
	var badtag := UpdateRules.pick_assets({"tag_name": "nightly", "assets": []}, "0.17.0")
	_check("control: a release without a version tag is refused", not badtag["ok"])
	var noasset := UpdateRules.pick_assets({"tag_name": "v0.18.0", "assets": [{"name": "Project-Ascent-v0.18.0-Linux.zip", "browser_download_url": "https://github.com/p4inz-code/project-ascent/releases/download/v0.18.0/x", "size": 5}]}, "0.17.0")
	_check("control: a release with no Windows file is refused", not noasset["ok"])
	var rel_big := _release("v0.18.0", true, false)
	rel_big["assets"][0]["size"] = UpdateRules.MAX_DOWNLOAD_BYTES + 1
	_check("control: an absurd size is refused", not UpdateRules.pick_assets(rel_big, "0.17.0")["ok"])
	var rel_zero := _release("v0.18.0", true, false)
	rel_zero["assets"][0]["size"] = 0
	_check("control: a zero size is refused", not UpdateRules.pick_assets(rel_zero, "0.17.0")["ok"])
	var rel_badsha := _release("v0.18.0", true, false)
	rel_badsha["assets"][0]["digest"] = "sha256:nothex"
	_check("control: a broken digest and no .sha256 file is refused", not UpdateRules.pick_assets(rel_badsha, "0.17.0")["ok"])

	# --- retries and backoff
	_check("a dropped connection is retried", UpdateRules.should_retry(0, HTTPRequest.RESULT_CONNECTION_ERROR, 0))
	_check("a server error is retried", UpdateRules.should_retry(503, HTTPRequest.RESULT_SUCCESS, 1))
	_check("control: a 404 is not retried", not UpdateRules.should_retry(404, HTTPRequest.RESULT_SUCCESS, 0))
	_check("control: three tries are the limit", not UpdateRules.should_retry(503, HTTPRequest.RESULT_SUCCESS, 3))
	_check("backoff is 1 hour and then 6 hours", UpdateRules.retry_delay(1) == 3600.0 and UpdateRules.retry_delay(2) == 21600.0 and UpdateRules.retry_delay(9) == 21600.0)

	# --- file checks
	var dir := OS.get_environment("TEMP") if OS.get_environment("TEMP") != "" else "/tmp"
	var path := dir.path_join("ascent_update_rules_test.bin")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("a pretend update")
	f.close()
	var real := FileAccess.get_sha256(path)
	_check("a file with the right checksum verifies", UpdateRules.verify_file(path, real))
	_check("the checksum compares case-insensitively", UpdateRules.verify_file(path, real.to_upper()))
	_check("control: a file with the wrong checksum is refused", not UpdateRules.verify_file(path, GOOD_SHA))
	_check("control: a missing file is refused", not UpdateRules.verify_file(dir.path_join("ascent_no_such_file.bin"), real))
	_check("control: a malformed checksum is refused", not UpdateRules.verify_file(path, "xyz"))
	DirAccess.remove_absolute(path)
	_check("modes clamp", UpdateRules.clamp_mode(-4) == 0 and UpdateRules.clamp_mode(1) == 1 and UpdateRules.clamp_mode(77) == 2)

	print("")
	print("[test_update_rules] failures=%d" % _failures)
