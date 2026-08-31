extends SceneTree
## Gates the hidden developer console.
##
## Two things must hold, and they pull against each other:
##   1. It must be genuinely unreachable by accident. A player mashing keys,
##      or playing normally for hours, must never trip it.
##   2. When it IS unlocked, the skip log must actually record skips — that
##      log is the whole reason the feature exists, since it turns a tester
##      giving up into difficulty data.
##
## This suite deliberately does NOT hardcode the unlock sequence. It reads it
## from the console's own constant, so the secret lives in exactly one file and
## a reader of the tests learns nothing they could use.

var _failures: int = 0


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await _run()
	print("[test_dev_console] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


func _press(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await physics_frame
	var up := InputEventKey.new()
	up.keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await physics_frame


func _run() -> void:
	await physics_frame
	await physics_frame
	var dev := root.get_node_or_null("DevConsole")
	if dev == null:
		_check("DevConsole autoload present", false)
		return

	_check("console starts LOCKED", not dev.is_unlocked())

	# Hammer plausible player input. None of this may unlock anything.
	for code in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_SHIFT, KEY_R,
			KEY_ESCAPE, KEY_TAB, KEY_E, KEY_G, KEY_LEFT, KEY_RIGHT]:
		await _press(code)
	_check("ordinary gameplay keys never unlock it", not dev.is_unlocked())

	# A correct PREFIX followed by a wrong key must not unlock either.
	var seq: Array = dev.SEQUENCE
	for i in range(seq.size() - 1):
		await _press(seq[i])
	await _press(KEY_Z)
	_check("a near-miss sequence does not unlock", not dev.is_unlocked())

	# The real sequence, read from the console itself so the secret stays in
	# exactly one file.
	for code in seq:
		await _press(code)
	_check("the full sequence unlocks the console", dev.is_unlocked())

	# Skipping must advance the level AND write a log line.
	var gm := root.get_node_or_null("GameManager")
	if gm != null:
		var log_path: String = dev.LOG_PATH
		var before := ""
		if FileAccess.file_exists(log_path):
			var rf := FileAccess.open(log_path, FileAccess.READ)
			if rf != null:
				before = rf.get_as_text()
				rf.close()

		gm.current_level = 3
		await _step(2)
		dev._skip_level(1)
		await _step(4)
		_check("skip advances the current level (now %d)" % gm.current_level,
			gm.current_level == 4)

		var after := ""
		if FileAccess.file_exists(log_path):
			var rf2 := FileAccess.open(log_path, FileAccess.READ)
			if rf2 != null:
				after = rf2.get_as_text()
				rf2.close()
		_check("the skip is written to the log (this is the point of the feature)",
			after.length() > before.length() and after.contains("L3 -> L4"))

		dev._unlock_all()
		await _step(2)
		_check("unlock-all marks every level complete",
			gm.is_level_completed(LevelData.TOTAL_LEVELS))
	else:
		_check("GameManager present for skip checks", false)
