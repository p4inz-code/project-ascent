extends SceneTree
## The updater service's decisions (scripts/game_updater.gd), without a network: what it refuses to install,
## when it gives up, what it keeps between runs. The HTTP behaviour is covered by tests/live_updater.gd against a
## fake GitHub (tools/run_updater_live.ps1). Needs APPDATA pointed at a temp folder.

var _failures: int = 0
var _u: Node = null


func _initialize() -> void:
	_run()
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _reset() -> void:
	_u._store = {}
	_u.last_result = {}
	_u.error = ""
	_u.state = 0
	if FileAccess.file_exists(_u.STATE_PATH):
		DirAccess.remove_absolute(_u.STATE_PATH)


func _stage(version: String, content: String, sha_of_content: bool = true) -> String:
	DirAccess.make_dir_recursive_absolute(_u.UPDATE_DIR)
	var path: String = _u.UPDATE_DIR.path_join("test_update_%s.zip" % version)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(content)
	f.close()
	var sha := FileAccess.get_sha256(path) if sha_of_content else "0".repeat(64)
	_u._store["pending"] = {"version": version, "file": path, "sha": sha}
	return path


func _sha_of(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


## A real zip in the update folder, staged as the pending update (its checksum is the zip's own).
func _stage_zip(version: String, files: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(_u.UPDATE_DIR)
	var path: String = _u.UPDATE_DIR.path_join("test_update_%s.zip" % version)
	var z := ZIPPacker.new()
	z.open(ProjectSettings.globalize_path(path))
	for name in files:
		z.start_file(name)
		z.write_file(files[name])
		z.close_file()
	z.close()
	_u._store["pending"] = {"version": version, "file": path, "sha": FileAccess.get_sha256(path)}
	return path


func _run() -> void:
	_u = root.get_node_or_null("GameUpdater")
	_check("the GameUpdater autoload exists", _u != null)
	if _u == null:
		return
	# --- nothing runs by itself in a test run
	_check("control: no network on its own in headless runs", not _u._network_allowed())
	_u.start_background()
	_check("start_background does nothing here", _u._periodic == null and _u.state == 0)
	_u.check_auto_if_due()
	_check("an automatic check does nothing here", _u.state == 0)
	_check("this copy cannot replace itself (editor)", _u.supported_reason() != "")

	# --- the mode is remembered
	_reset()
	_u.set_mode(1)
	_check("the mode is set", _u.mode == 1)
	_u._load_store()
	_check("the mode survives a reload", UpdateRules.clamp_mode(int(_u._store.get("mode", 0))) == 1)
	_u.set_mode(99)
	_check("control: an out-of-range mode is clamped", _u.mode == 2)
	_u.set_mode(0)

	# --- skipping a version
	_reset()
	_u.latest = "0.99.0"
	_u.skip_latest()
	_check("a skipped version is remembered", _u.is_skipped("0.99.0"))
	_check("control: another version is not skipped", not _u.is_skipped("0.99.1"))
	_check("control: an empty version is never skipped", not _u.is_skipped(""))

	# --- what may be installed
	_reset()
	_check("no staged update, nothing to install", not bool(_u.prepare_install()["ok"]) and not _u.has_pending())
	var good := _stage("0.99.0", "pretend zip")
	var plan: Dictionary = _u.prepare_install()
	# a verified, newer file that is not really a zip holding the installer is refused at the very last check
	_check("a verified, newer file with no installer inside is refused", not bool(plan["ok"]) and "installer" in String(plan["reason"]).to_lower())

	# --- the installer is the new launcher taken out of the verified zip
	_u.helper_root = "user://helper_test"
	var launcher_bytes := PackedByteArray()
	launcher_bytes.resize(4096)
	for i in launcher_bytes.size():
		launcher_bytes[i] = (i * 7) % 251
	var zpath := _stage_zip("0.99.0", {"ProjectAscent.exe": PackedByteArray([1, 2, 3]), "ProjectAscent.pck": PackedByteArray([4, 5]),
		"version.txt": "0.99.0".to_utf8_buffer(), "ProjectAscentLauncher.exe": launcher_bytes})
	plan = _u.prepare_install()
	_check("a zip that holds the launcher gives an installer", bool(plan["ok"]))
	var helper_file := String(plan["launcher"])
	_check("the installer is a copy of the zip's launcher, in the helper folder", FileAccess.file_exists(helper_file) and helper_file.ends_with("update_helper/ProjectAscentLauncher.exe") and FileAccess.get_sha256(helper_file) == _sha_of(launcher_bytes))
	var args: PackedStringArray = plan["args"]
	_check("the command names the zip, its checksum, the version, the install folder and a restart", "--apply-update" in args and "--sha256" in args and "--version" in args and "--game-dir" in args and "--restart" in args and "--wait-pid" in args)
	_check("the game folder given is the folder of the running game", args[args.find("--game-dir") + 1] == OS.get_executable_path().get_base_dir())
	_check("cleaning up reports success once the installer is gone", _u._cleanup_helper())
	_check("the installer is removed again afterwards", not FileAccess.file_exists(helper_file))
	_check("and its folder is gone too", not DirAccess.dir_exists_absolute(_u._helper_dir()))
	_check("control: cleaning up when there is nothing to clean up is fine", _u._cleanup_helper())
	_stage_zip("0.99.0", {"ProjectAscent.exe": PackedByteArray([1]), "version.txt": "0.99.0".to_utf8_buffer()})
	_check("control: a zip with no launcher is refused", not bool(_u.prepare_install()["ok"]))
	_stage_zip("0.99.0", {"sub/ProjectAscentLauncher.exe": launcher_bytes, "version.txt": "0.99.0".to_utf8_buffer()})
	_check("control: a launcher in a sub-folder is refused (only the top level counts)", not bool(_u.prepare_install()["ok"]))
	_stage_zip("0.99.0", {"ProjectAscentLauncher.exe": PackedByteArray([1, 2, 3])})
	_check("control: a launcher of a few bytes is refused", not bool(_u.prepare_install()["ok"]))
	DirAccess.remove_absolute(zpath)
	_u.helper_root = ""
	good = _stage("0.99.0", "pretend zip")
	_stage("0.99.0", "pretend zip", false)
	plan = _u.prepare_install()
	_check("control: a staged file that no longer matches its checksum is refused", not bool(plan["ok"]) and "checksum" in String(plan["reason"]))
	_stage("0.0.1", "old")
	plan = _u.prepare_install()
	_check("control: a staged update that is not newer is refused", not bool(plan["ok"]) and "not newer" in String(plan["reason"]))
	# a forged state file must not make the game install, or delete, a file outside the update folder
	for evil in ["user://other/x.zip", "user://update/../x.zip", "C:/Windows/Temp/x.zip", "user://update/sub/x.zip", "user://update/x.exe", "res://x.zip"]:
		_check("control: a staged path of '%s' is refused" % evil, not _u.staged_path_ok(evil))
	_check("a zip directly in the update folder is accepted", _u.staged_path_ok("user://update/Project-Ascent-v0.99.0-Windows.zip"))
	var outside := "user://outside_test.zip"
	var of := FileAccess.open(outside, FileAccess.WRITE)
	of.store_string("not mine to delete")
	of.close()
	_u._store["pending"] = {"version": "0.99.0", "file": outside, "sha": FileAccess.get_sha256(outside)}
	_check("control: a pending update outside the update folder is refused even with a matching checksum", not bool(_u.prepare_install()["ok"]) and "update folder" in String(_u.prepare_install()["reason"]))
	_u._clear_pending()
	_check("control: clearing it never deletes the file outside the update folder", FileAccess.file_exists(outside))
	DirAccess.remove_absolute(outside)
	_u._store["pending"] = {"version": "0.99.0", "file": "user://update/does_not_exist.zip", "sha": "a".repeat(64)}
	_check("control: a staged file that is gone is refused", not bool(_u.prepare_install()["ok"]))
	_u._store["pending"] = {"version": "nightly", "file": good, "sha": FileAccess.get_sha256(good)}
	_check("control: a staged update with no real version is refused", not bool(_u.prepare_install()["ok"]))

	# --- the two-attempt guard and clean-up at start-up
	_reset()
	good = _stage("0.99.0", "pretend zip")
	_u._store["attempts"] = 2
	_check("after two failed attempts the game gives up and starts normally", not _u.apply_pending_on_startup())
	_check("giving up clears the staged update and its file", not _u.has_pending() and not FileAccess.file_exists(good))
	_check("giving up leaves a message for the title screen", not bool(_u.last_result.get("ok", true)) and String(_u.last_result.get("message", "")) != "")
	_reset()
	good = _stage("0.99.0", "pretend zip")
	_u._store["attempts"] = 0
	_check("control: with attempts left it tries, and with no launcher it just fails without quitting", not _u.apply_pending_on_startup())
	_check("a failed try is counted only when the launcher really started", int(_u._store.get("attempts", 0)) == 0)
	_check("and the staged update is kept for the next start", _u.has_pending() and FileAccess.file_exists(good))
	_reset()
	var old := _stage("0.0.1", "already installed")
	_check("a staged update that is already installed is cleaned up", not _u.apply_pending_on_startup() and not _u.has_pending() and not FileAccess.file_exists(old))

	# --- what the launcher reports
	_reset()
	var res_path := "user://updater_result_test.json"
	var f := FileAccess.open(res_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"ok": true, "version": "0.99.0", "message": "Updated to 0.99.0."}))
	f.close()
	good = _stage("0.99.0", "pretend zip")
	_u._read_result_file(res_path)
	_check("a good verdict is read", bool(_u.last_result.get("ok", false)) and _u.last_result.get("version") == "0.99.0")
	_check("the verdict file is deleted after reading", not FileAccess.file_exists(res_path))
	_check("a good verdict clears the staged update", not _u.has_pending() and not FileAccess.file_exists(good))
	f = FileAccess.open(res_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"ok": false, "version": "0.99.0", "message": "Your old version was kept."}))
	f.close()
	good = _stage("0.99.0", "pretend zip")
	_u._read_result_file(res_path)
	_check("control: a failed verdict keeps the staged file for another go", not bool(_u.last_result.get("ok", true)) and _u.has_pending())
	f = FileAccess.open(res_path, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	_u._read_result_file(res_path)
	_check("control: a broken verdict file is ignored without a crash", _u.last_result.is_empty() and not FileAccess.file_exists(res_path))
	_u._read_result_file("user://no_such_verdict.json")
	_check("no verdict file, no verdict", _u.last_result.is_empty())

	# --- a failure is calm and visible
	_reset()
	_u._fail("test failure")
	_check("a failure sets the state and the message", _u.state == 6 and _u.error == "test failure")
	_u._store.clear()
	DirAccess.remove_absolute(good)

	print("")
	print("[test_game_updater] failures=%d" % _failures)
