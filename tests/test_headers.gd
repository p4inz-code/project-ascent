extends SceneTree
## Copyright: every game script carries the copyright and SPDX lines in its first lines, the LICENSE says
## who owns the game and what players may do, and the credits and security text match the 40-level, free game.

var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _run() -> void:
	var missing: Array = []
	var total := 0
	for f in DirAccess.get_files_at("res://scripts"):
		if f.ends_with(".gd"):
			total += 1
			var head := FileAccess.get_file_as_string("res://scripts/" + f).substr(0, 300)
			if not (head.contains("Copyright (c) 2026 Atharva Patil") and head.contains("SPDX-License-Identifier:")):
				missing.append(f)
	_check("all %d scripts carry the copyright and SPDX header (%d without) %s" % [total, missing.size(), str(missing.slice(0, 3))], missing.is_empty() and total > 100)
	_check("(control) the checker can fail: a header-less text is rejected", not "extends Node".contains("Copyright (c) 2026 Atharva Patil"))
	var lic := FileAccess.get_file_as_string("res://LICENSE")
	_check("LICENSE names the owner and says the game is free to play", lic.contains("Atharva Patil") and lic.to_lower().contains("free to play"))
	var credits := FileAccess.get_file_as_string("res://CREDITS.md")
	_check("CREDITS describe the 40-level game", credits.contains("40-level") and not credits.contains("25-level"))
	_check("the DMCA template exists", FileAccess.file_exists("res://docs/DMCA_TEMPLATE.md"))
	print("[test_headers] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)
