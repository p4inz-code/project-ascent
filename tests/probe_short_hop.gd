extends SceneTree
## Can the real controller land a SHORT hop onto a narrow step?
##
## The reachability suite reports every inserted stepping platform as
## UNREACHABLE — all of them gaps of 27-45px with rises of 33-44px. That is
## geometry a player hops up without thinking, so before either "fixing" the
## levels or loosening the gate, establish which one is actually wrong.
##
## Drives the exact failing shape (gap 30, rise 44, 90px-wide target) two ways:
##   * holding run the whole time, which is what the reachability suite does
##   * releasing run once over the target, which is what a player does
##
## If the first fails and the second succeeds, the geometry is fine and the
## validator simply lacks the ability to throttle for a short hop.

const GAP: float = 30.0
const RISE: float = 44.0
const TARGET_W: float = 90.0


func _initialize() -> void:
	_run()


func _platform(pos: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	col.shape = rect
	body.add_child(col)
	body.collision_layer = 3
	body.position = pos
	root.add_child(body)
	return body


func _run() -> void:
	await physics_frame
	var from := _platform(Vector2(0, 400), Vector2(600, 40))
	var from_top := 380.0
	var to_top := from_top - RISE
	var to_x := 300.0 + GAP + TARGET_W / 2.0
	var to := _platform(Vector2(to_x, to_top + 11.0), Vector2(TARGET_W, 22.0))

	var player: Player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	await physics_frame

	var held := await _try(player, to_x, to_top, true)
	var throttled := await _try(player, to_x, to_top, false)

	print("[hop] gap=%.0f rise=%.0f target_w=%.0f" % [GAP, RISE, TARGET_W])
	print("[hop] holding run the whole time  (validator's strategy) : %s"
		% ("LANDS" if held else "MISSES"))
	print("[hop] releasing run over the step (a player's strategy)  : %s"
		% ("LANDS" if throttled else "MISSES"))
	quit(0)


func _try(player: Player, to_x: float, to_top: float, hold: bool) -> bool:
	player.global_position = Vector2(300.0 - 200.0, 380.0 - 30.0)
	player.velocity = Vector2.ZERO
	player.reset_state()
	Input.action_release("jump")
	Input.action_release("move_right")
	for _i in 12:
		await physics_frame

	Input.action_press("move_right", 1.0)
	for _i in 60:
		await physics_frame
		if player.global_position.x >= 300.0 - 34.0:
			break
	Input.action_press("jump", 1.0)

	var landed := false
	for _i in 90:
		await physics_frame
		# A player eases off once they are over the landing spot; the
		# reachability suite never does, which is the difference under test.
		if not hold and player.global_position.x >= to_x - TARGET_W * 0.25:
			Input.action_release("move_right")
		var feet: float = player.global_position.y + 26.0
		if player.is_on_floor() and absf(feet - to_top) < 10.0 \
				and absf(player.global_position.x - to_x) < TARGET_W:
			landed = true
			break
		if feet > 380.0 + 200.0:
			break

	Input.action_release("jump")
	Input.action_release("move_right")
	return landed
