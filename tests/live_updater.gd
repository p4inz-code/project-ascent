extends SceneTree
## The updater's HTTP behaviour against a fake GitHub (tools/fake_github.py), run by tools/run_updater_live.ps1:
##   godot --headless --path . --script res://tests/live_updater.gd -- PORT
## Not named test_*, because it needs that server and so must stay out of the ordinary suite list.
## Every scenario is a way an update can go wrong (or the way it should go right); the failures must leave no
## staged update and no half-downloaded file behind.

const IDLE := 0
const CHECKING := 1
const UP_TO_DATE := 2
const AVAILABLE := 3
const DOWNLOADING := 4
const READY := 5
const FAILED := 6

var _failures: int = 0
var _u: Node = null
var _base: String = ""
var _progress_events: int = 0
var _ready_auto: int = -1


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _wait(targets: Array, timeout: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not (int(_u.state) in targets):
		if float(Time.get_ticks_msec() - t0) > timeout * 1000.0:
			return false
		await create_timer(0.1).timeout
	return true


func _clean() -> void:
	_u._store = {}
	_u._plan = {}
	_u.latest = ""
	_u.error = ""
	_u.state = IDLE
	_u.received = 0
	_u.total = 0
	var dir := DirAccess.open(_u.UPDATE_DIR)
	if dir != null:
		for f in dir.get_files():
			DirAccess.remove_absolute(_u.UPDATE_DIR.path_join(f))


func _leftovers() -> Array:
	var out: Array = []
	var dir := DirAccess.open(_u.UPDATE_DIR)
	if dir != null:
		for f in dir.get_files():
			out.append(f)
	return out


## One scenario: a manual check, then (when the check found an update) a download.
## Returns [state after check, state after download or -1].
func _scenario(name: String, download: bool = true) -> Array:
	_clean()
	UpdateRules.test_base = _base + name + "/"
	_u.mode = 1
	_u.check_now(true)
	var ok := await _wait([AVAILABLE, UP_TO_DATE, FAILED], 20.0)
	if not ok:
		return [-2, -1]
	var after_check: int = int(_u.state)
	if after_check != AVAILABLE or not download:
		return [after_check, -1]
	_u.download(false)
	ok = await _wait([READY, FAILED], 60.0)
	return [after_check, int(_u.state) if ok else -2]


func _no_trace(label: String) -> void:
	_check(label + ": nothing staged and no file left behind", not _u.has_pending() and _leftovers().is_empty())


func _run() -> void:
	await process_frame   # the autoloads join the tree on the first frame
	var args := OS.get_cmdline_user_args()
	_u = root.get_node_or_null("GameUpdater")
	if args.is_empty() or _u == null:
		print("[FAIL] needs the PORT argument and the GameUpdater autoload")
		quit(2)
		return
	_base = "http://127.0.0.1:%s/s/" % args[0]
	_u.force_supported = true
	_u.progress.connect(func(_r: int, _t: int) -> void: _progress_events += 1)
	_u.ready_to_install.connect(func(_v: String, automatic: bool) -> void: _ready_auto = 1 if automatic else 0)

	var r := await _scenario("good")
	_check("good: found, downloaded and verified", r == [AVAILABLE, READY])
	_check("good: the verified file is staged and matches its checksum", _u.has_pending() and UpdateRules.verify_file(String(_u._store["pending"]["file"]), String(_u._store["pending"]["sha"])))
	_check("good: the version and notes were read", _u.latest == "0.99.0" and "Fake release notes" in _u.notes)
	_check("good: progress was reported", _progress_events > 0)
	_check("good: a redirect to the content host was followed", _u.received > 3000000)
	_check("good: no .part file is left", not _leftovers().any(func(f: String) -> bool: return f.ends_with(".part")))
	_u.helper_root = "user://helper_live"
	var plan: Dictionary = _u.prepare_install()
	_check("good: the installer is taken out of the downloaded zip", bool(plan["ok"]) and FileAccess.file_exists(String(plan["launcher"])))
	_check("good: it is the launcher that was inside the zip (4096 bytes)", FileAccess.open(String(plan["launcher"]), FileAccess.READ).get_length() == 4096)
	_u._cleanup_helper()
	_check("good: the installer is cleaned up afterwards", not FileAccess.file_exists(String(plan["launcher"])))

	r = await _scenario("digest")
	_check("digest: the checksum from the release JSON is used", r == [AVAILABLE, READY])

	r = await _scenario("ratelimit")
	_check("ratelimit: the API refused, the releases page gave the tag, the update still arrived", r == [AVAILABLE, READY])

	r = await _scenario("notnewer", false)
	_check("notnewer: an older release is 'up to date'", r[0] == UP_TO_DATE)

	r = await _scenario("flaky")
	_check("flaky: two server errors are retried, then it works", r == [AVAILABLE, READY])

	r = await _scenario("badsha")
	_check("badsha: a wrong published checksum means the download is thrown away", r == [AVAILABLE, FAILED] and "checksum" in _u.error)
	_no_trace("badsha")

	r = await _scenario("tamper")
	_check("tamper: a changed byte is caught by the checksum", r == [AVAILABLE, FAILED] and "checksum" in _u.error)
	_no_trace("tamper")

	r = await _scenario("truncated")
	_check("truncated: a dropped connection fails after its retries", r == [AVAILABLE, FAILED])
	_no_trace("truncated")

	r = await _scenario("wrongsize")
	_check("wrongsize: a file that is not the size the release says is refused", r == [AVAILABLE, FAILED])
	_no_trace("wrongsize")

	r = await _scenario("evilredirect")
	_check("evilredirect: a redirect to another host is stopped", r == [AVAILABLE, FAILED] and "not allowed" in _u.error)
	_no_trace("evilredirect")

	r = await _scenario("evilurl", false)
	_check("evilurl: a download address off GitHub is refused at the check", r[0] == FAILED)

	r = await _scenario("nosha", false)
	_check("nosha: a release with no checksum is never offered", r[0] == FAILED and "checksum" in _u.error.to_lower())

	r = await _scenario("shaother", false)
	_check("shaother: a checksum for some other file is refused", r[0] == FAILED)

	# --- the three modes and the skip
	_clean()
	UpdateRules.test_base = _base + "good/"
	_u.mode = 1
	_u.check_now(false)
	await _wait([AVAILABLE, FAILED, UP_TO_DATE], 20.0)
	await create_timer(1.5).timeout
	_check("notify mode: it tells the player and downloads nothing by itself", int(_u.state) == AVAILABLE and _leftovers().is_empty())

	_clean()
	_ready_auto = -1
	_u.mode = 0
	_u.check_now(false)
	var done := await _wait([READY, FAILED, UP_TO_DATE], 60.0)
	_check("automatic mode: it downloads and verifies by itself", done and int(_u.state) == READY and _u.has_pending())
	_check("automatic mode: it asks 'restart now / later' (automatic flag set)", _ready_auto == 1)

	# a staged, verified update is recognised by a later check and not downloaded again
	var staged := String(_u._store["pending"]["file"])
	var stamp := FileAccess.get_modified_time(staged)
	await create_timer(1.3).timeout
	_u.state = IDLE
	_u.check_now(false)
	await _wait([READY, AVAILABLE, FAILED, UP_TO_DATE], 20.0)
	_check("a later check finds the staged update and goes straight to ready", int(_u.state) == READY)
	_check("and it is not downloaded a second time", FileAccess.get_modified_time(staged) == stamp and _leftovers().size() == 1)

	_clean()
	_u.mode = 1
	_u.latest = "0.99.0"
	_u.skip_latest()
	_u.state = IDLE
	_u.check_now(false)
	await _wait([AVAILABLE, UP_TO_DATE, FAILED], 20.0)
	_check("skip: a skipped version stays quiet on an automatic check", int(_u.state) == UP_TO_DATE)
	_u.state = IDLE
	_u.check_now(true)
	await _wait([AVAILABLE, UP_TO_DATE, FAILED], 20.0)
	_check("skip: a manual check still shows it", int(_u.state) == AVAILABLE)

	_clean()
	_u.mode = 2
	_u.check_auto_if_due()
	_check("off: no automatic check", int(_u.state) == IDLE)

	_clean()
	UpdateRules.test_base = ""
	print("")
	print("[live_updater] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)
