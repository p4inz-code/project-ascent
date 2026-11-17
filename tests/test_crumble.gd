extends SceneTree
## A crumble tile must give way under a player who is standing on it however
## they got there (landing, or already touching it), then reform.

var _failures: int = 0


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await physics_frame
	await _case("landing on it", true)
	await _case("already standing on it when it appears", false)
	print("[test_crumble] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


func _case(name: String, drop_in: bool) -> void:
	var tile := CrumblePlatform.new()
	tile.size = Vector2(200, 32)
	tile.position = Vector2(0, 400)
	root.add_child(tile)
	var player: Player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	# Standing: feet on the top face (y = 400 - 16). Dropping: from well above.
	player.global_position = Vector2(0, (300.0 if drop_in else 400.0 - 16.0 - 26.0))
	await _step(10)
	var shape: CollisionShape2D = tile._shape
	_check("%s: solid while you first stand on it" % name, not shape.disabled)
	await _step(int(tile.crumble_delay * 60.0) + 20)
	_check("%s: it gives way" % name, shape.disabled)
	await _step(int(tile.respawn_delay * 60.0) + 40)
	_check("%s: it reforms" % name, not shape.disabled)
	player.queue_free()
	tile.queue_free()
	await _step(2)
