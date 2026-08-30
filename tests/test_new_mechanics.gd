extends SceneTree
## Dedicated regression probe for the three Phase 4 mechanics — Lava,
## Pendulum, OneWayPlatform — added straight under the tree root rather than
## through a full level load, so this suite verifies just the mechanic itself
## in isolation before any real level relies on it. Matches the project's
## standing discipline of a dedicated headless probe for every new mechanic
## (spin, conveyor, spinning blade all got one before being placed in a
## level).
##
## Run with:
##   Godot --headless --path <project> --script res://tests/test_new_mechanics.gd

var _failures: int = 0
var _player: Player


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await _run()
	print("[test_new_mechanics] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(frames: int) -> void:
	for _i in frames:
		await physics_frame


func _spawn_player(pos: Vector2) -> Player:
	var p: Player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	root.add_child(p)
	p.global_position = pos
	return p


func _run() -> void:
	await _check_lava()
	await _check_one_way_platform()
	await _check_pendulum()


func _check_lava() -> void:
	var lava := Lava.new()
	lava.position = Vector2(0.0, 500.0)
	lava.size = Vector2(160.0, 40.0)
	root.add_child(lava)
	await _step(2)

	# Boxed in an array: a bare local captured by a lambda is not reliably
	# mutated back out in GDScript, but a reference type (Array) is.
	var hit := [false]
	lava.player_hit.connect(func(): hit[0] = true)

	_player = _spawn_player(Vector2(0.0, 490.0))
	await _step(10)

	_check("Lava fires player_hit when the player touches it", hit[0])

	_player.queue_free()
	lava.queue_free()
	await _step(2)


func _check_one_way_platform() -> void:
	var plat := OneWayPlatform.new()
	plat.position = Vector2(300.0, 500.0)
	plat.size = Vector2(140.0, 20.0)
	root.add_child(plat)
	await _step(2)

	# Rising from below must pass straight through. player.gd's own
	# _physics_process re-derives velocity.y from gravity every frame, so a
	# raw `.velocity = ...` assignment here gets overwritten before the next
	# physics step; apply_external_launch() is the actual API for injecting
	# a vertical kick that survives (same one bounce pads/spin use).
	_player = _spawn_player(Vector2(300.0, 700.0))
	_player.apply_external_launch(-900.0)
	await _step(40)
	var passed_through := _player.global_position.y < 470.0
	_check("OneWayPlatform lets the player rise through from below", passed_through)
	_player.queue_free()
	await _step(2)

	# Landing from above must hold.
	_player = _spawn_player(Vector2(300.0, 400.0))
	await _step(40)
	var landed := absf(_player.global_position.y - 480.0) < 20.0 and _player.is_on_floor()
	_check("OneWayPlatform holds the player when landed on from above", landed)

	_player.queue_free()
	plat.queue_free()
	await _step(2)


func _check_pendulum() -> void:
	var pend := Pendulum.new()
	pend.position = Vector2(600.0, 200.0)
	pend.arm_length = 220.0
	pend.max_angle_deg = 55.0
	pend.swing_speed = 1.6
	root.add_child(pend)
	await _step(2)

	var bob_positions: Array[Vector2] = []
	for _i in 90:
		await physics_frame
		bob_positions.append(pend.global_position + pend._bob.position)

	var min_x := bob_positions[0].x
	var max_x := bob_positions[0].x
	for pos in bob_positions:
		min_x = minf(min_x, pos.x)
		max_x = maxf(max_x, pos.x)
	var swing_width := max_x - min_x
	# sin(55deg) * 220 ~= 180px half-width, so a full swing should cover a
	# meaningful fraction of ~360px — loose bound, just proving it actually moves.
	_check("Pendulum bob swings through a real arc (width=%.0fpx)" % swing_width,
		swing_width > 100.0)

	var hit := [false]
	pend.player_hit.connect(func(): hit[0] = true)
	# Spawn at the bob's CURRENT live position (it has been swinging for the
	# 90 frames above, so it is no longer at its angle=0 rest position) and
	# hold it there — the point is to prove the sensor detects an overlapping
	# body, not to also validate the player's own gravity/movement.
	var bob_world := pend.global_position + pend._bob.position
	_player = _spawn_player(bob_world)
	for _i in 30:
		_player.global_position = bob_world
		await physics_frame
	_check("Pendulum fires player_hit when the bob sweeps through the player", hit[0])

	_player.queue_free()
	pend.queue_free()
	await _step(2)
