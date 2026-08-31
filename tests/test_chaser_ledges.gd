extends SceneTree
## Regression gate for the last remaining cause of "enemies falling".
##
## Three earlier fixes attacked this bug and none of them ended it:
##   1. Giving chasers their own collision layer (player could no longer knock
##      them off by standing on them).
##   2. Narrowing the mask so a chaser's own movement didn't treat the player
##      as ground.
##   3. A recovery teleport for anything that fell 400px below the player.
##
## The actual remaining cause was simpler than all three: nothing ever checked
## whether there was GROUND AHEAD. A chaser tracking the player sideways walked
## straight off the edge, and the recovery only caught it after a long visible
## fall — so the bug still looked exactly like a bug.
##
## This suite builds an explicit cliff and asserts a chaser holds the edge.

var _failures: int = 0


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await _run()
	print("[test_chaser_ledges] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _platform(pos: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	col.shape = rect
	body.add_child(col)
	# Layers 1+2, matching platform.gd — chasers mask against layer 2 only.
	body.collision_layer = 3
	body.position = pos
	root.add_child(body)
	return body


func _run() -> void:
	await physics_frame
	await _check_holds_edge()
	await _check_jumps_crossable_gap()


## A chaser chasing a player across a bottomless drop must stop at the lip.
func _check_holds_edge() -> void:
	var ground := _platform(Vector2(0, 400), Vector2(600, 40))
	var player: Player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	# Player parked far beyond the cliff, so the chaser is pulled toward the void.
	player.global_position = Vector2(1400, 380)

	var minion := MinionEntity.new()
	root.add_child(minion)
	await physics_frame
	minion.activate(Vector2(0, 340), player, 200.0)

	var lowest := minion.global_position.y
	for _i in 180:
		await physics_frame
		lowest = maxf(lowest, minion.global_position.y)

	# Ground top is y=380; falling off means dropping well past it.
	_check("minion holds the ledge instead of walking into the void (max y=%.0f, ground=380)"
		% lowest, lowest < 460.0)

	minion.queue_free()
	player.queue_free()
	ground.queue_free()
	await physics_frame


## But a gap it can actually clear should still be jumped, or the chase stops
## being a threat the moment the player crosses anything.
func _check_jumps_crossable_gap() -> void:
	var a := _platform(Vector2(0, 400), Vector2(600, 40))
	var b := _platform(Vector2(480, 400), Vector2(300, 40))

	var player: Player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	player.global_position = Vector2(500, 340)

	var minion := MinionEntity.new()
	root.add_child(minion)
	await physics_frame
	minion.activate(Vector2(0, 340), player, 200.0)

	var crossed := false
	for _i in 240:
		await physics_frame
		if minion.global_position.x > 360.0 and minion.global_position.y < 420.0:
			crossed = true
			break

	_check("minion jumps a gap it can actually clear (x=%.0f)" % minion.global_position.x,
		crossed)

	minion.queue_free()
	player.queue_free()
	a.queue_free()
	b.queue_free()
	await physics_frame
