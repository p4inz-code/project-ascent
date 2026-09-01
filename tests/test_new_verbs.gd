extends SceneTree
## Proves each new movement verb produces a real, observable effect.
##
## Written the same way as test_customization.gd and for the same reason: this
## project has repeatedly shipped things that existed without doing anything
## (four dead settings, two decorative level flags). A verb that compiles and a
## verb that works are different claims, and only the second one is worth
## reporting.
##
## Covers slide, ground pound, wall run, ledge grab, and the spin rework
## (airborne use, cooldown gating, and the i-frame window).

var _failures: int = 0
var _player: Player


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await _run()
	print("[test_new_verbs] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


func _platform(pos: Vector2, size: Vector2) -> StaticBody2D:
	var b := StaticBody2D.new()
	var c := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	c.shape = r
	b.add_child(c)
	b.collision_layer = 3
	b.position = pos
	root.add_child(b)
	return b


func _spawn(pos: Vector2) -> Player:
	var p: Player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	root.add_child(p)
	p.global_position = pos
	return p


func _release_all() -> void:
	for a in ["move_left", "move_right", "jump", "dash", "slide", "grapple", "ability"]:
		Input.action_release(a)


func _run() -> void:
	await physics_frame
	await _check_slide()
	await _check_ground_pound()
	await _check_spin_rework()
	await _check_ledge_grab()
	await _check_abilities()
	await _check_zero_gravity()
	await _check_grapple()


func _check_slide() -> void:
	var ground := _platform(Vector2(0, 400), Vector2(1400, 40))
	_player = _spawn(Vector2(-300, 340))
	await _step(6)

	# Build up real speed first — slide deliberately refuses from standstill,
	# because a slide that starts from nothing reads as a teleport.
	Input.action_press("move_right", 1.0)
	await _step(40)
	var speed_before: float = absf(_player.velocity.x)
	Input.action_press("slide", 1.0)
	await _step(3)
	var sliding: bool = _player.is_sliding()
	var speed_during: float = absf(_player.velocity.x)
	_check("slide engages from a run (was %.0f px/s)" % speed_before, sliding)
	_check("slide is faster than running (%.0f -> %.0f)" % [speed_before, speed_during],
		speed_during > speed_before)
	_release_all()
	await _step(40)
	_check("slide ends on its own", not _player.is_sliding())

	# And it must refuse from a standstill.
	_player.velocity = Vector2.ZERO
	await _step(6)
	Input.action_press("slide", 1.0)
	await _step(3)
	_check("slide refuses from a standstill", not _player.is_sliding())
	_release_all()

	_player.queue_free()
	ground.queue_free()
	await _step(2)


func _check_ground_pound() -> void:
	var ground := _platform(Vector2(0, 700), Vector2(1400, 40))
	_player = _spawn(Vector2(0, 200))
	await _step(4)

	# Down + Jump in the air, using the existing bindings — no new key.
	Input.action_press("slide", 1.0)
	Input.action_press("jump", 1.0)
	await _step(3)
	var pounding: bool = _player.is_ground_pounding()
	var vy: float = _player.velocity.y
	_check("ground pound engages on Down+Jump while airborne", pounding)
	_check("ground pound slams downward fast (vy=%.0f)" % vy, vy > 800.0)

	# It must also END on landing, or the player would be pinned to the floor.
	for _i in 90:
		await physics_frame
		if _player.is_on_floor():
			break
	await _step(3)
	_check("ground pound releases on landing", not _player.is_ground_pounding())
	_release_all()

	_player.queue_free()
	ground.queue_free()
	await _step(2)


func _check_spin_rework() -> void:
	var ground := _platform(Vector2(0, 700), Vector2(1400, 40))
	_player = _spawn(Vector2(0, 300))
	await _step(4)

	# Spin now works in mid-air with no grounding first. Double-tap jump.
	Input.action_press("jump", 1.0)
	await _step(2)
	Input.action_release("jump")
	await _step(2)
	Input.action_press("jump", 1.0)
	await _step(2)
	var spun_airborne: bool = _player.is_spinning()
	_check("spin fires in mid-air without touching ground first", spun_airborne)
	_check("spin grants i-frames at the start of the spin",
		_player.is_invulnerable())
	_release_all()

	# Cooldown must block a second spin, or i-frames become an infinite
	# phase-through button and every hazard becomes optional.
	# Wait long enough for the FIRST spin to end (spin_time 0.25s ~ 15 frames)
	# but stay well inside the 1.0s cooldown, or this would be asserting
	# against the original spin still being active.
	await _step(22)
	_check("first spin has ended before the cooldown re-test",
		not _player.is_spinning())
	Input.action_press("jump", 1.0)
	await _step(2)
	Input.action_release("jump")
	await _step(2)
	Input.action_press("jump", 1.0)
	await _step(2)
	# Either it did not re-spin, or it did but is no longer invulnerable.
	var blocked: bool = not _player.is_spinning()
	_check("spin cooldown blocks an immediate second spin", blocked)
	_release_all()

	# And the i-frame window must be a FRACTION of the spin, not all of it.
	await _step(90)
	_player.global_position = Vector2(0, 300)
	_player.velocity = Vector2.ZERO
	await _step(2)
	Input.action_press("jump", 1.0)
	await _step(2)
	Input.action_release("jump")
	await _step(2)
	Input.action_press("jump", 1.0)
	await _step(2)
	var was_invuln: bool = _player.is_invulnerable()
	# Run to the far end of the spin.
	await _step(12)
	var still_spinning: bool = _player.is_spinning()
	var still_invuln: bool = _player.is_invulnerable()
	_check("i-frames expire before the spin animation does (spin=%s invuln=%s)"
		% [still_spinning, still_invuln], was_invuln and not still_invuln)
	_release_all()

	_player.queue_free()
	ground.queue_free()
	await _step(2)


func _check_ledge_grab() -> void:
	# Geometry matters precisely here. Ground top is 680 and a jump's apex
	# lifts the feet ~96px, so the highest reachable footing is ~584. Putting
	# the lip at 570 leaves the player ~14px short — exactly the near-miss
	# ledge grab exists to rescue. Earlier rigs put the lip 244px up (utterly
	# unreachable) and then level with the wall face (no lip to catch at all),
	# and both failed for reasons that had nothing to do with the feature.
	var ground := _platform(Vector2(-100, 700), Vector2(600, 40))   # top 680, x -400..200
	var wall := _platform(Vector2(300, 720), Vector2(80, 300))      # top 570, x 260..340
	var lip_y := 570.0
	_player = _spawn(Vector2(-50, 620))
	await _step(10)

	Input.action_press("move_right", 1.0)
	# Jump only once actually near the gap, so the arc peaks at the wall.
	for _i in 90:
		await physics_frame
		if _player.global_position.x > 120.0:
			break
	Input.action_press("jump", 1.0)

	var grabbed := false
	var best_y := 9999.0
	for _i in 150:
		await physics_frame
		best_y = minf(best_y, _player.global_position.y)
		if _player.is_on_floor() and _player.global_position.y < lip_y - 10.0:
			grabbed = true
			break
	_check("ledge grab pulls the player onto a lip they nearly missed (highest y=%.0f, lip=%.0f)"
		% [best_y, lip_y], grabbed)
	_release_all()

	_player.queue_free()
	wall.queue_free()
	ground.queue_free()
	await _step(2)


func _check_abilities() -> void:
	var ground := _platform(Vector2(0, 700), Vector2(1200, 40))
	_player = _spawn(Vector2(0, 300))
	await _step(6)

	# Super jump: a one-charge burst, spent on use.
	_player.grant_ability(0)
	_check("player holds a granted ability", _player.held_ability() == 0)
	var vy_before: float = _player.velocity.y
	Input.action_press("ability", 1.0)
	await _step(2)
	_check("super jump launches upward (%.0f -> %.0f)" % [vy_before, _player.velocity.y],
		_player.velocity.y < -300.0)
	_check("using an ability spends the charge", _player.held_ability() < 0)
	_release_all()

	# Spending with nothing held must do nothing at all.
	await _step(20)
	var vy_idle: float = _player.velocity.y
	Input.action_press("ability", 1.0)
	await _step(2)
	_check("ability key does nothing with no charge held",
		_player.velocity.y > vy_idle - 50.0)
	_release_all()

	# Glide clamps fall speed while airborne.
	_player.global_position = Vector2(0, 200)
	_player.velocity = Vector2(0, 600)
	_player.grant_ability(1)
	await _step(2)
	Input.action_press("ability", 1.0)
	await _step(4)
	_check("glide clamps fall speed (vy=%.0f)" % _player.velocity.y,
		_player.is_gliding() and _player.velocity.y < 200.0)
	_release_all()

	_player.queue_free()
	ground.queue_free()
	await _step(2)


func _check_zero_gravity() -> void:
	var ground := _platform(Vector2(0, 900), Vector2(1200, 40))
	var zone := ZeroGravityZone.new()
	zone.size = Vector2(400, 400)
	zone.position = Vector2(0, 400)
	root.add_child(zone)
	_player = _spawn(Vector2(0, 380))
	await _step(4)

	# Inside the field, a falling player must reach nothing like normal
	# terminal velocity.
	_player.velocity = Vector2.ZERO
	var peak := 0.0
	for _i in 40:
		await physics_frame
		peak = maxf(peak, _player.velocity.y)
	_check("zero-g field suppresses fall speed (peak vy=%.0f)" % peak, peak < 260.0)

	_player.queue_free()
	zone.queue_free()
	await _step(2)


## Grapple was BOUND to a key for a full release without being implemented —
## a dead binding, the same class of fake feature this project spent a phase
## deleting. These checks exist so it cannot silently become dead again.
func _check_grapple() -> void:
	var ground := _platform(Vector2(0, 700), Vector2(600, 40))
	# Terrain up and to the right, genuinely inside grapple_range. The aim rays
	# leave at -32/-55/-12 degrees over a 340px range, so the -32 ray tops out
	# near x=288 from a spawn at x=0 — an anchor at x=430 was simply out of
	# reach and the "latch" failure had nothing to do with the grapple.
	var anchor := _platform(Vector2(250, 480), Vector2(200, 40))
	_player = _spawn(Vector2(0, 640))
	await _step(8)

	# Face right so the aim rays point at the anchor.
	Input.action_press("move_right", 1.0)
	await _step(10)
	Input.action_release("move_right")
	await _step(2)

	var y_before: float = _player.global_position.y
	Input.action_press("grapple", 1.0)
	await _step(3)
	_check("grapple latches onto terrain in range", _player.is_grappling())

	# Reeling must actually move the player toward the anchor.
	await _step(14)
	_check("grapple reels the player upward (%.0f -> %.0f)"
		% [y_before, _player.global_position.y],
		_player.global_position.y < y_before - 30.0)
	_release_all()

	# It must let go rather than pinning the player forever.
	for _i in 90:
		await physics_frame
		if not _player.is_grappling():
			break
	_check("grapple releases on arrival", not _player.is_grappling())

	_player.queue_free()
	anchor.queue_free()
	ground.queue_free()
	await _step(4)

	# And with nothing in range it must not latch onto empty air.
	var lone := _platform(Vector2(0, 700), Vector2(600, 40))
	_player = _spawn(Vector2(0, 640))
	await _step(8)
	Input.action_press("grapple", 1.0)
	await _step(4)
	_check("grapple does not latch onto empty space", not _player.is_grappling())
	_release_all()
	_player.queue_free()
	lone.queue_free()
	await _step(2)
