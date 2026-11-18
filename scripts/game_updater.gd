# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
extends Node
## Self-update from GitHub Releases, inside the game: one click (or none, in Automatic mode), then "Restart".
## Autoload name: GameUpdater. The rules live in update_rules.gd; this is the part that talks and waits.
##
## Safe by design (the owner's Kinoz model):
##  - it only talks to this project's own pages on github.com / api.github.com, over HTTPS, and a redirect may
##    only lead to GitHub's own hosts;
##  - it only installs a file whose SHA-256 matches the checksum published with the release, checked again
##    right before installing;
##  - it sends nothing about the player: a plain GET with a generic User-Agent;
##  - when something fails the message stays in the game, with a way to try again.
##
## How it feels:
##  - Automatic (default): check once a day (and every 6 hours while the game stays open), download in the
##    background, verify, then ask "Restart now / Later". "Later" keeps the verified file and applies it the
##    next time the game starts.
##  - Notify me: check and tell the player; downloading waits for a click on "Update".
##  - Off: never contacts the network by itself. "Check for updates" on the About page still works.
## Windows hands the swap to the launcher (a running game cannot overwrite itself). The launcher keeps one
## rollback copy and restarts the game. macOS and Linux get the notice and the release page. The browser build
## updates itself and never shows any of this.
##
## Nothing here runs in headless tests, in the editor or in the web build.

signal state_changed
signal progress(received: int, total: int)
signal update_found(version: String)
signal ready_to_install(version: String, automatic: bool)

enum State { IDLE, CHECKING, UP_TO_DATE, AVAILABLE, DOWNLOADING, READY, FAILED }

const STATE_PATH := "user://updater.json"
const UPDATE_DIR := "user://update"
const LAUNCHER_EXE := "ProjectAscentLauncher.exe"
const HELPER_DIR := "update_helper"
const RESULT_FILE := "update_result.json"
const CHECK_EVERY := 86400.0
const OPEN_CHECK_EVERY := 21600.0
const MAX_APPLY_ATTEMPTS := 2

var state: int = State.IDLE
var mode: int = 0
var latest: String = ""
var notes: String = ""
var error: String = ""
var received: int = 0
var total: int = 0
## What the launcher reported after the last apply (empty when there was none): {ok, version, message}.
var last_result: Dictionary = {}
## Tests only: pretend this copy can replace itself.
var force_supported: bool = false
## Tests only: where the installer is unpacked (default: next to the game).
var helper_root: String = ""

var _http: HTTPRequest = null
var _kind: String = ""
var _plan: Dictionary = {}
var _store: Dictionary = {}
var _redirects: int = 0
var _manual: bool = false
var _dl_tries: int = 0
var _fails: int = 0
var _dl_path: String = ""
var _since_emit: float = 0.0
var _retry: Timer = null
var _periodic: Timer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	_load_store()
	mode = UpdateRules.clamp_mode(int(_store.get("mode", 0)))
	_read_result_file()
	if _network_allowed():
		_cleanup_helper()
	if _network_allowed() and supported_reason() == "":
		if apply_pending_on_startup():
			return


## The running version (res://version.txt, written by the release script), "" for a dev run.
static func current() -> String:
	return AboutPage.read_version()


## No network on its own in headless runs (tests), in the editor, or in the browser build.
func _network_allowed() -> bool:
	if force_supported:
		return true
	return DisplayServer.get_name() != "headless" and not OS.has_feature("web") and not OS.has_feature("editor")


## "" when this copy can replace itself; otherwise a short reason for the About page.
func supported_reason() -> String:
	if force_supported:
		return ""
	if OS.has_feature("web"):
		return "The browser version updates itself."
	if OS.get_name() != "Windows":
		return "On this system, updates come from the release page."
	if OS.has_feature("editor"):
		return "Running from the editor."
	if not _writable(OS.get_executable_path().get_base_dir()):
		return "This folder is read-only."
	return ""


func _writable(dir: String) -> bool:
	var p := dir.path_join(".ascent_write_test")
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return false
	f.close()
	DirAccess.remove_absolute(p)
	return true


func can_install() -> bool:
	return supported_reason() == "" and not _plan.is_empty() and bool(_plan.get("ok", false))


# ── settings and state file ─────────────────────────────────────────

func set_mode(m: int) -> void:
	mode = UpdateRules.clamp_mode(m)
	_store["mode"] = mode
	_save_store()
	if mode == 2 and _periodic != null:
		_periodic.stop()
	elif _periodic != null and _periodic.is_stopped():
		_periodic.start(OPEN_CHECK_EVERY)


## A corrupt or hand-edited file must never crash anything: parse quietly, accept only a dictionary.
static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK or not (j.data is Dictionary):
		return {}
	return j.data


func _load_store() -> void:
	_store = _read_json(STATE_PATH)


func _save_store() -> void:
	var f := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_store))
		f.close()


func is_skipped(version: String) -> bool:
	return String(_store.get("skipped", "")) == version and version != ""


func skip_latest() -> void:
	if latest != "":
		_store["skipped"] = latest
		_save_store()
	_set_state(State.UP_TO_DATE)


func _record_check() -> void:
	_store["last_check"] = Time.get_unix_time_from_system()
	_save_store()


## The launcher writes its verdict next to the game after an apply; read it once, then forget it.
func _read_result_file(path: String = "") -> void:
	last_result = {}
	if path == "":
		path = OS.get_executable_path().get_base_dir().path_join(RESULT_FILE)
	if not FileAccess.file_exists(path):
		return
	var data := _read_json(path)
	DirAccess.remove_absolute(path)
	if not data.is_empty():
		last_result = data
		if bool(data.get("ok", false)):
			_clear_pending()
			_store["attempts"] = 0
			_save_store()
		print("[Updater] launcher result: %s" % JSON.stringify(data))


# ── checking ────────────────────────────────────────────────────────

func _api_url() -> String:
	if UpdateRules.test_base != "" and OS.is_debug_build():
		return UpdateRules.test_base + "api/latest"
	return UpdateRules.API_LATEST


func _page_url() -> String:
	if UpdateRules.test_base != "" and OS.is_debug_build():
		return UpdateRules.test_base + "releases/latest"
	return UpdateRules.PAGE_LATEST


## First check now if one is due, then one every 6 hours while the game stays open. Called by the title menu.
func start_background() -> void:
	if not _network_allowed() or mode == 2 or _periodic != null:
		return
	_periodic = Timer.new()
	_periodic.one_shot = false
	_periodic.wait_time = OPEN_CHECK_EVERY
	_periodic.timeout.connect(check_auto_if_due)
	add_child(_periodic)
	_periodic.start()
	check_auto_if_due()


func check_auto_if_due() -> void:
	if mode == 2 or not _network_allowed():
		return
	var last := float(_store.get("last_check", 0.0))
	if Time.get_unix_time_from_system() - last >= CHECK_EVERY - 60.0 or last <= 0.0:
		check_now(false)


func check_now(manual: bool) -> void:
	if state == State.CHECKING or state == State.DOWNLOADING:
		return
	_manual = manual
	_plan = {}
	error = ""
	_redirects = 0
	if _retry != null:
		_retry.stop()
	_set_state(State.CHECKING)
	_request("check", _api_url())


func _request(kind: String, url: String, file: String = "") -> void:
	if _http != null:
		_http.cancel_request()
		_http.queue_free()
	_http = HTTPRequest.new()
	_http.max_redirects = 0
	_http.use_threads = true
	_http.timeout = 900.0 if kind == "download" else 30.0
	_http.accept_gzip = kind != "download"
	if file != "":
		_http.download_file = file
	add_child(_http)
	_http.request_completed.connect(_on_done)
	_kind = kind
	var headers := PackedStringArray(["User-Agent: ProjectAscent/" + (current() if current() != "" else "dev"),
		"Accept: " + ("application/vnd.github+json" if kind == "check" else "*/*")])
	var err := _http.request(url, headers)
	if err != OK:
		_fail("Could not start the request (error %d)." % err)


func _on_done(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	# max_redirects is 0 on purpose, so that every redirect passes through our own host check. The engine then
	# reports a redirect as "redirect limit reached" with the headers intact: that is a redirect, not a failure.
	var is_redirect := code >= 300 and code < 400 \
		and (result == HTTPRequest.RESULT_SUCCESS or result == HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED)
	if result != HTTPRequest.RESULT_SUCCESS and not is_redirect:
		_net_fail(code, result)
		return
	if _kind == "redirect":
		_on_page_redirect(code, headers)
		return
	if is_redirect:
		_follow(headers)
		return
	match _kind:
		"check":
			if code == 200:
				var rel = JSON.parse_string(body.get_string_from_utf8())
				if rel is Dictionary:
					_on_release(rel)
				else:
					_fail("GitHub's answer could not be read.")
			elif code == 403 or code == 429:
				# the API's rate limit: read the newest tag from the plain releases page instead
				_redirects = 0
				_request("redirect", _page_url())
			else:
				_fail("GitHub answered with error %d." % code)
		"sha":
			if code != 200:
				_fail("The checksum file could not be fetched (error %d)." % code)
				return
			var sha := UpdateRules.parse_sha(body.get_string_from_utf8(), String(_plan.get("asset", "")))
			if sha == "":
				_fail("The published checksum could not be used, so the update was not offered.")
				return
			_plan["sha"] = sha
			_available()
		"download":
			if code != 200:
				if UpdateRules.should_retry(code, result, _dl_tries):
					_retry_download()
				else:
					_discard_part()
					_fail("The download failed (error %d)." % code)
				return
			_finish_download()


## A redirect from the downloads host: only to GitHub's own hosts, a few hops at most.
func _follow(headers: PackedStringArray) -> void:
	var loc := ""
	for h in headers:
		if h.to_lower().begins_with("location:"):
			loc = h.substr(9).strip_edges()
	if loc.begins_with("/"):
		loc = "https://github.com" + loc
	_redirects += 1
	if loc == "" or _redirects > UpdateRules.MAX_REDIRECTS:
		_discard_part()
		_fail("Too many redirects.")
		return
	if not UpdateRules.redirect_allowed(loc):
		_discard_part()
		_fail("The download was redirected somewhere that is not allowed, so it was stopped.")
		return
	_request(_kind, loc, _dl_path if _kind == "download" else "")


func _on_page_redirect(code: int, headers: PackedStringArray) -> void:
	var loc := ""
	for h in headers:
		if h.to_lower().begins_with("location:"):
			loc = h.substr(9).strip_edges()
	var tag := UpdateRules.tag_from_location(loc)
	if code < 300 or code >= 400 or tag == "":
		_fail("The newest version could not be read from the releases page.")
		return
	var rel := {"tag_name": tag, "body": "", "assets": []}
	var plan := {"ok": false, "tag": tag, "version": tag.trim_prefix("v"), "newer": UpdateRules.is_newer(tag, current()),
		"notes": "", "asset": UpdateRules.asset_name_for(tag), "url": UpdateRules.asset_url_for(tag), "size": 0,
		"sha": "", "sha_url": UpdateRules.asset_url_for(tag) + ".sha256"}
	if UpdateRules.test_base != "" and OS.is_debug_build():
		plan["url"] = UpdateRules.test_base + "download/" + tag + "/" + String(plan["asset"])
		plan["sha_url"] = String(plan["url"]) + ".sha256"
	_plan = plan
	if not bool(plan["newer"]):
		_record_check()
		_set_state(State.UP_TO_DATE)
		return
	_plan["ok"] = true
	_redirects = 0
	_request("sha", String(plan["sha_url"]))


func _on_release(rel: Dictionary) -> void:
	_plan = UpdateRules.pick_assets(rel, current())
	if not bool(_plan.get("newer", false)):
		_record_check()
		_set_state(State.UP_TO_DATE)
		return
	if not bool(_plan.get("ok", false)):
		_fail(String(_plan.get("reason", "The release could not be used.")))
		return
	if String(_plan.get("sha", "")) == "":
		_redirects = 0
		_request("sha", String(_plan["sha_url"]))
		return
	_available()


func _available() -> void:
	latest = String(_plan.get("version", ""))
	notes = String(_plan.get("notes", ""))
	total = int(_plan.get("size", 0))
	_record_check()
	_fails = 0
	# Already downloaded and verified (a later check, or "Later" earlier this session): do not fetch it again.
	if has_pending() and pending_version() == latest:
		var p: Dictionary = _store["pending"]
		if staged_path_ok(String(p.get("file", ""))) and UpdateRules.verify_file(String(p["file"]), String(p.get("sha", ""))):
			received = total
			_set_state(State.READY)
			return
	if not _manual and is_skipped(latest):
		_set_state(State.UP_TO_DATE)
		return
	_set_state(State.AVAILABLE)
	update_found.emit(latest)
	if mode == 0 and not _manual and supported_reason() == "":
		download(true)


# ── downloading ─────────────────────────────────────────────────────

func download(automatic: bool = false) -> void:
	if state != State.AVAILABLE or not can_install():
		return
	DirAccess.make_dir_recursive_absolute(UPDATE_DIR)
	_dl_path = UPDATE_DIR.path_join(String(_plan["asset"]) + ".part")
	_discard_part()
	received = 0
	total = int(_plan.get("size", 0))
	_dl_tries = 0
	_redirects = 0
	_manual = not automatic
	_set_state(State.DOWNLOADING)
	set_process(true)
	_request("download", String(_plan["url"]), _dl_path)


func _retry_download() -> void:
	_dl_tries += 1
	print("[Updater] download dropped, retry %d" % _dl_tries)
	_discard_part()
	await get_tree().create_timer(3.0).timeout
	if state == State.DOWNLOADING:
		_redirects = 0
		_request("download", String(_plan["url"]), _dl_path)


func _process(delta: float) -> void:
	if state != State.DOWNLOADING or _http == null:
		return
	received = _http.get_downloaded_bytes()
	var body := _http.get_body_size()
	if body > 0:
		total = body
	if received > UpdateRules.MAX_DOWNLOAD_BYTES:
		_http.cancel_request()
		_discard_part()
		_fail("The download was larger than expected, so it was stopped.")
		return
	_since_emit += delta
	if _since_emit >= 0.15:
		_since_emit = 0.0
		progress.emit(received, total)


func _finish_download() -> void:
	set_process(false)
	var expected := int(_plan.get("size", 0))
	var size := 0
	var f := FileAccess.open(_dl_path, FileAccess.READ)
	if f != null:
		size = f.get_length()
		f.close()
	if expected > 0 and size != expected:
		_discard_part()
		_fail("The download was incomplete, so it was thrown away.")
		return
	if not UpdateRules.verify_file(_dl_path, String(_plan.get("sha", ""))):
		_discard_part()
		_fail("The download did not match its checksum, so it was thrown away.")
		return
	var final_path := _dl_path.trim_suffix(".part")
	DirAccess.remove_absolute(final_path)
	if DirAccess.rename_absolute(_dl_path, final_path) != OK:
		_fail("The verified update could not be saved.")
		return
	_store["pending"] = {"version": String(_plan["version"]), "file": final_path, "sha": String(_plan["sha"])}
	_store["attempts"] = 0
	_save_store()
	received = size
	total = size
	progress.emit(received, total)
	_set_state(State.READY)
	ready_to_install.emit(latest, not _manual)


func _discard_part() -> void:
	if _dl_path != "" and FileAccess.file_exists(_dl_path):
		DirAccess.remove_absolute(_dl_path)


# ── failures ────────────────────────────────────────────────────────

func _net_fail(code: int, result: int) -> void:
	if _kind == "download" and UpdateRules.should_retry(code, result, _dl_tries):
		_retry_download()
		return
	if _kind == "download":
		_discard_part()
	_fail("The connection failed (error %d)." % result)


func _fail(message: String) -> void:
	set_process(false)
	error = message
	_fails += 1
	print("[Updater] failed: %s" % message)
	_set_state(State.FAILED)
	if not _manual and _kind != "download" and mode != 2 and _network_allowed():
		if _retry == null:
			_retry = Timer.new()
			_retry.one_shot = true
			_retry.timeout.connect(func() -> void: check_now(false))
			add_child(_retry)
		_retry.start(UpdateRules.retry_delay(_fails))


func _set_state(s: int) -> void:
	state = s
	state_changed.emit()


# ── installing ──────────────────────────────────────────────────────

func has_pending() -> bool:
	var p = _store.get("pending", {})
	return p is Dictionary and not p.is_empty()


func pending_version() -> String:
	var p = _store.get("pending", {})
	return String(p.get("version", "")) if p is Dictionary else ""


## Only a zip directly inside the update folder is ever installed or deleted, whatever the state file says.
static func staged_path_ok(path: String) -> bool:
	return path.begins_with(UPDATE_DIR + "/") and path.ends_with(".zip") and not path.contains("..") \
		and path.get_base_dir() == UPDATE_DIR


func _clear_pending() -> void:
	var p = _store.get("pending", {})
	if p is Dictionary and p.has("file") and staged_path_ok(String(p["file"])) and FileAccess.file_exists(String(p["file"])):
		DirAccess.remove_absolute(String(p["file"]))
	_store.erase("pending")
	_save_store()


## Check the staged file once more and work out the launcher command. Nothing is started here.
func prepare_install() -> Dictionary:
	var out := {"ok": false, "reason": "", "launcher": "", "args": PackedStringArray(), "version": ""}
	if not has_pending():
		out["reason"] = "There is no staged update."
		return out
	var p: Dictionary = _store["pending"]
	var version := String(p.get("version", ""))
	var file := String(p.get("file", ""))
	if not UpdateRules.is_newer(version, current()):
		out["reason"] = "The staged update is not newer than this version."
		return out
	if not staged_path_ok(file):
		out["reason"] = "The staged update is not in the update folder."
		return out
	if not UpdateRules.verify_file(file, String(p.get("sha", ""))):
		out["reason"] = "The staged update no longer matches its checksum."
		return out
	var helper := _extract_helper(file)
	if helper == "":
		out["reason"] = "The update holds no installer, so it was not applied."
		return out
	out["ok"] = true
	out["version"] = version
	out["launcher"] = ProjectSettings.globalize_path(helper)
	out["args"] = PackedStringArray(["--apply-update", ProjectSettings.globalize_path(file), "--sha256",
		String(p.get("sha", "")), "--version", version, "--wait-pid", str(OS.get_process_id()), "--restart",
		"--game-dir", OS.get_executable_path().get_base_dir()])
	return out


func _helper_dir() -> String:
	return (helper_root if helper_root != "" else OS.get_executable_path().get_base_dir()).path_join(HELPER_DIR)


## The installer is the NEW launcher, taken out of the verified zip, so it works whatever launcher is installed
## (the 0.17 launcher cannot apply updates) and it also brings the installed launcher up to date. It runs from a
## folder next to the game, not from AppData, where antivirus treats unsigned programs as suspicious.
func _extract_helper(zip_path: String) -> String:
	var reader := ZIPReader.new()
	if reader.open(ProjectSettings.globalize_path(zip_path)) != OK:
		return ""
	if not Array(reader.get_files()).has(LAUNCHER_EXE):
		reader.close()
		return ""
	var bytes := reader.read_file(LAUNCHER_EXE)
	reader.close()
	if bytes.size() < 1024 or bytes.size() > 100 * 1024 * 1024:
		return ""
	var dir := _helper_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var target := dir.path_join(LAUNCHER_EXE)
	var f := FileAccess.open(target, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_buffer(bytes)
	f.close()
	return target


## The installer is only needed while an update is being applied; remove it the next time the game starts.
func _cleanup_helper() -> void:
	var dir := _helper_dir()
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


## "Restart now": hand the verified file to the launcher and close. False (and a message) when it cannot.
func install_and_quit() -> bool:
	var plan := prepare_install()
	if not bool(plan["ok"]):
		error = String(plan["reason"])
		_set_state(State.FAILED)
		return false
	_store["attempts"] = int(_store.get("attempts", 0)) + 1
	_save_store()
	var pid := OS.create_process(String(plan["launcher"]), plan["args"])
	if pid <= 0:
		error = "The launcher could not be started."
		_set_state(State.FAILED)
		return false
	print("[Updater] applying %s through the launcher" % String(plan["version"]))
	get_tree().quit()
	return true


## At start-up, before any window: a verified update left by "Later" is applied now. It gives up after two
## attempts so a broken update can never trap the player in a loop.
func apply_pending_on_startup() -> bool:
	if not has_pending():
		return false
	var version := pending_version()
	if not UpdateRules.is_newer(version, current()):
		_clear_pending()
		return false
	if int(_store.get("attempts", 0)) >= MAX_APPLY_ATTEMPTS:
		print("[Updater] gave up applying %s after %d attempts" % [version, MAX_APPLY_ATTEMPTS])
		_clear_pending()
		_store["attempts"] = 0
		_save_store()
		last_result = {"ok": false, "version": version, "message": "The update could not be applied, so the game keeps running as it was."}
		return false
	return install_and_quit()
