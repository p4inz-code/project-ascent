extends SceneTree
## Debug-only launch options: --dev-cores=N sets the session core count, never saved.
## Run as: --script res://tests/test_dev_launch.gd -- --dev-cores=99 --dev-level=25

var _failures: int = 0


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await create_timer(1.2).timeout
	var gm: Node = root.get_node("GameManager")
	var args := OS.get_cmdline_user_args()
	if args.has("--dev-cores=99"):
		_check("cores start at 99", gm.save_system.orb_total() == 99)
		_check("the ending would read 'one core short'", EndingScreen.result_for(gm.save_system.orb_total(), 100) == EndingScreen.Result.CLOSE)
	if args.has("--dev-level=25"):
		_check("starts on level 25", gm.current_level == 25)
		_check("earlier levels count as cleared", gm.is_level_completed(24))
	if args.has("--dev-unlocked"):
		_check("dev mode is on", root.get_node("DevConsole").is_unlocked())
	print("[test_dev_launch] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1
