extends SceneTree
## Boot smoke test: instantiates the REAL entry point (res://scenes/game_scene.tscn,
## the project's run/main_scene), not a level scene directly.
##
## Every other suite extends test_base.gd, which loads res://scenes/main_scene.tscn
## straight into the tree — a real level, but not the game. That gap let a script
## compile failure in a dependency of game_scene.gd (scripts/floating_particles.gd
## calling a nonexistent Godot class) ship silently: all five suites reported
## 262/262 PASS while the actual shipped build could not start.
##
## This suite closes that gap. It does not re-check gameplay physics (test_level.gd
## already owns that) — it only asserts that the entry point itself composes
## correctly: no failed loads, the level container gets a real level, the pause
## menu and GameManager wire up, and the per-level backdrop (including the
## FloatingParticles nodes that caused the regression) instantiates cleanly.
##
## Run: Godot --headless --path <project> --script res://tests/test_boot.gd
## Exit code 0 = all checks passed, 1 = a check failed.

var _failures: int = 0
var _game: Node = null


func _initialize() -> void:
	_boot()


func _boot() -> void:
	var scene := load("res://scenes/game_scene.tscn") as PackedScene
	_check("game_scene.tscn loads (no failed script compilation)", scene != null)
	if scene == null:
		_finish()
		return

	_game = scene.instantiate()
	_check("game_scene.tscn instantiates", _game != null)
	if _game == null:
		_finish()
		return

	root.add_child(_game)
	# _load_current_level() awaits a process_frame before adding the level child.
	await process_frame
	await process_frame
	await physics_frame

	_check_level_container()
	_check_pause_menu()
	_check_game_manager_wiring()
	_check_backdrop_particles()

	_finish()


func _check_level_container() -> void:
	var container := _game.get_node_or_null("LevelContainer")
	_check("LevelContainer exists", container != null)
	if container == null:
		return
	var loaded := container.get_child_count() > 0
	_check("a level actually loaded into LevelContainer", loaded)
	if not loaded:
		return
	var level := container.get_child(0)
	_check("loaded level has a Player", level.get_node_or_null("Player") != null)
	_check("loaded level has a Goal", level.get_node_or_null("Goal") != null)
	_check("loaded level has a Hud", level.get_node_or_null("Hud") != null)


func _check_pause_menu() -> void:
	var pause := _game.get_node_or_null("PauseMenu")
	_check("PauseMenu instantiated under the entry point", pause != null)


func _check_game_manager_wiring() -> void:
	var gm := _game.get_node_or_null("/root/GameManager")
	_check("GameManager autoload is reachable", gm != null)
	if gm != null:
		_check("GameManager has a pause_menu reference wired", gm.get("pause_menu") != null)


## The regression that motivated this whole suite: FloatingParticles nodes live
## on the per-level Backdrop, wired by scripts/game_scene.gd's palette pass. If
## the script fails to run (parse error, wrong MultiMesh API), this either
## throws mid-boot or leaves the node with no multimesh at all.
func _check_backdrop_particles() -> void:
	var container := _game.get_node_or_null("LevelContainer")
	if container == null or container.get_child_count() == 0:
		_check("backdrop particles present (skipped: no level)", false)
		return
	var backdrop := container.get_child(0).get_node_or_null("Backdrop")
	_check("level has a Backdrop", backdrop != null)
	if backdrop == null:
		return
	var found_one := false
	for name in ["Particles1", "Particles2"]:
		var p := backdrop.get_node_or_null(name)
		if p == null:
			continue
		found_one = true
		_check("%s has a valid multimesh" % name, p.multimesh != null and p.multimesh.instance_count > 0)
	_check("at least one FloatingParticles node exists on the backdrop", found_one)


func _finish() -> void:
	print("[test_boot] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1
