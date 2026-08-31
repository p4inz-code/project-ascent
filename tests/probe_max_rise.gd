extends SceneTree
## Measure the player's REAL maximum clearable rise, so the rhythm linter's
## thresholds are grounded in physics rather than guessed from the
## `jump_height` export (which describes an ideal apex, not a landable step).
##
## Builds a two-platform test rig and sweeps the target's height, trying each
## rise with a running jump and with a dash-jump, exactly as the reachability
## suite drives the controller.

var GAP: float = 150.0   # swept by _run(); real levels range ~50-350px
const RUNUP: float = 300.0

var _player: CharacterBody2D
var _from: StaticBody2D
var _to: StaticBody2D


func _initialize() -> void:
	_run()


func _make_platform(pos: Vector2, size: Vector2) -> StaticBody2D:
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

	_from = _make_platform(Vector2(0, 400), Vector2(600, 40))
	_to = _make_platform(Vector2(0, 0), Vector2(200, 40))

	_player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	root.add_child(_player)
	await physics_frame

	# Max clearable rise depends on the GAP: a short hop spends most of the jump
	# arc going up, a long one spends it going across. A single-gap threshold
	# wrongly flagged real levels' 95px-gap steps, so sweep the envelope.
	print("[probe] gap_px,max_rise_px")
	for gap in [60, 100, 150, 200, 250, 300]:
		GAP = float(gap)
		var best := await _search(false)
		print("[probe] %d,%.0f" % [gap, best])
	quit(0)


## Highest rise still landable, to 2px. Monotonic assumption stated above.
func _search(use_dash: bool) -> float:
	var lo := 30.0   # known-good
	var hi := 260.0  # known-impossible
	for _i in 8:
		var mid := (lo + hi) * 0.5
		if await _try(mid, use_dash):
			lo = mid
		else:
			hi = mid
	return lo


func _try(rise: float, use_dash: bool) -> bool:
	var from_top := 400.0 - 20.0
	# Target platform sits `rise` above the source's top surface.
	# _from spans -300..300, so the target's left edge sits exactly GAP past 300.
	_to.position = Vector2(300.0 + GAP + 100.0, from_top - rise + 20.0)
	var to_top := _to.position.y - 20.0

	_player.global_position = Vector2(300.0 - RUNUP, from_top - 30.0)
	_player.velocity = Vector2.ZERO
	_player.reset_state()
	Input.action_release("jump")
	Input.action_release("dash")
	Input.action_release("move_right")
	for _i in 12:
		await physics_frame

	Input.action_press("move_right", 1.0)
	# Run until actually at the platform's edge, rather than for a fixed number
	# of frames — the previous fixed count left the player stranded mid-platform,
	# so every attempt failed for lack of run-up and the search reported its
	# lower bound as the answer.
	for _i in 90:
		await physics_frame
		if _player.global_position.x >= 300.0 - 34.0:
			break

	Input.action_press("jump", 1.0)
	var dashed := false
	var landed := false
	for _i in 110:
		await physics_frame
		if use_dash and not dashed and _player.velocity.y < -40.0:
			Input.action_press("dash", 1.0)
			dashed = true
			await physics_frame
			Input.action_release("dash")
		var feet: float = _player.global_position.y + 26.0
		if _player.is_on_floor() and absf(feet - to_top) < 10.0 \
				and _player.global_position.x > _to.position.x - 110.0:
			landed = true
			break
		if feet > from_top + 200.0:
			break

	Input.action_release("jump")
	Input.action_release("move_right")
	return landed
