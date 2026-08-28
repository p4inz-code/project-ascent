extends SceneTree
## Shared harness for the headless regression suites. Each suite extends this
## file, overrides `_run()` (a coroutine of `_check(...)` assertions) and
## `_suite_name()`, and uses the common helpers plus the loaded `_main`/`_player`.
##
## Keeps the SceneTree + physics-coroutine boilerplate (scene load, input
## synthesis, frame stepping, pass/fail tally, exit code) in one place instead
## of copy-pasted across every test file. Run a suite with:
##   Godot --headless --path <project> --script res://tests/<suite>.gd
## Exit code 0 = all checks passed, 1 = a check failed.

var _main: Node
var _player: CharacterBody2D
var _failures: int = 0


func _initialize() -> void:
	_boot()


## Load the real main scene, hand off to the suite's checks, then report + exit.
func _boot() -> void:
	_main = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await physics_frame
	_player = _main.get_node("Player")
	await _run()
	print("[%s] failures=%d" % [_suite_name(), _failures])
	quit(1 if _failures > 0 else 0)


## Overridden by each suite: the actual checks (a coroutine awaiting physics_frame).
func _run() -> void:
	pass


## Overridden by each suite: label for the summary line.
func _suite_name() -> String:
	return "test"


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


## Synthesize a real device-0 key event by physical keycode (layout-independent),
## so tests exercise the same InputMap path the game uses.
func _press_key(physical: int, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = physical
	e.pressed = pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _step(frames: int) -> void:
	for _i in frames:
		await physics_frame
