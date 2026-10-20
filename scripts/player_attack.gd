class_name PlayerAttack
extends Node2D
## M1: a melee slash toward the cursor. Mouse button, the L key (aims along the held direction,
## else the way the player faces) or the right trigger (aims with the right stick, else the left).
##
## The slash is a short arc in front of the player. Anything in the "slashable" physics layer inside
## it gets slash_hit(direction, player): small enemies die, darts are deflected, switches flip,
## chase minions are stunned. A downward slash that connects with something marked "pogo" (spikes,
## enemies) bounces the player up and gives the dash back.

signal slashed(direction: Vector2)
signal connected(count: int)

## Physics layer bit (value 8) that everything slashable lives on.
const SLASH_LAYER := 8
const COOLDOWN := 0.30
const REACH := 84.0
const HALF_ARC_DEG := 62.0
const POGO_VELOCITY := -470.0
const SHOW_TIME := 0.16

## Tests and bots set this to aim without a device; zero means use the real inputs.
var aim_override: Vector2 = Vector2.ZERO
## Seconds until the next slash is allowed.
var cooldown_left: float = 0.0
## Total slashes and connected hits since the node was created (tests read these).
var swings: int = 0
var hits_total: int = 0

var _player: Player = null
var _last_source: String = "key"
var _dir: Vector2 = Vector2.RIGHT
var _show_t: float = 0.0
var _hit_flash: float = 0.0


func _ready() -> void:
	_player = get_parent() as Player
	z_index = 6
	top_level = false


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("attack"):
		return
	if event is InputEventMouseButton:
		_last_source = "mouse"
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_last_source = "pad"
	else:
		_last_source = "key"


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	if _show_t > 0.0:
		_show_t = maxf(_show_t - delta, 0.0)
		_hit_flash = maxf(_hit_flash - delta, 0.0)
		queue_redraw()
	if _player == null or _player.input_locked:
		return
	if Input.is_action_just_pressed("attack"):
		try_slash()


## Where the slash would go right now.
func aim_direction() -> Vector2:
	if aim_override != Vector2.ZERO:
		return aim_override.normalized()
	var facing := Vector2(float(_player.facing()) if _player != null else 1.0, 0.0)
	match _last_source:
		"mouse":
			var to_mouse := get_global_mouse_position() - global_position
			if to_mouse.length() > 6.0:
				return to_mouse.normalized()
			return facing
		"pad":
			var right := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
			if right.length() > 0.35:
				return right.normalized()
			var left := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
			if left.length() > 0.35:
				return left.normalized()
			return facing
	# Keyboard: the held direction (arrows/WASD sideways, Down = S/Ctrl/Down, Up = Up arrow).
	var held := Vector2(Input.get_axis("move_left", "move_right"), 0.0)
	if Input.is_action_pressed("slide"):
		held.y += 1.0
	if Input.is_action_pressed("look_up"):
		held.y -= 1.0
	if held == Vector2.ZERO:
		return facing
	return held.normalized()


## Start a slash if the cooldown allows. Returns true when one was thrown.
func try_slash() -> bool:
	if cooldown_left > 0.0 or _player == null:
		return false
	_dir = aim_direction()
	cooldown_left = COOLDOWN
	swings += 1
	_show_t = SHOW_TIME
	_hit_flash = 0.0
	queue_redraw()
	slashed.emit(_dir)
	SfxHub.play(get_tree(), "slash")
	_player.attacked.emit(_dir)
	var count := _strike(_dir)
	if count > 0:
		hits_total += count
		_hit_flash = SHOW_TIME
		connected.emit(count)
	return true


## Hit everything in the arc. Returns how many targets reacted.
func _strike(dir: Vector2) -> int:
	if not is_inside_tree():
		return 0
	var space := get_world_2d().direct_space_state
	var circle := CircleShape2D.new()
	circle.radius = REACH * 0.55
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = circle
	q.transform = Transform2D(0.0, global_position + dir * REACH * 0.5)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.collision_mask = SLASH_LAYER
	var count := 0
	var pogo := false
	var seen: Array = []
	for r in space.intersect_shape(q, 16):
		var target: Object = r["collider"]
		if target == null or target in seen:
			continue
		seen.append(target)
		var node := target as Node2D
		if node == null:
			continue
		var to := node.global_position - global_position
		if to.length() > REACH + 20.0:
			continue
		# Inside the arc, with a generous allowance for targets that overlap the player.
		if to.length() > 28.0 and rad_to_deg(absf(dir.angle_to(to))) > HALF_ARC_DEG:
			continue
		var handler: Object = node if node.has_method("slash_hit") else node.get_parent()
		if handler != null and handler.has_method("slash_hit"):
			handler.slash_hit(dir, _player)
			count += 1
		if node.has_meta("pogo") or (node.get_parent() != null and node.get_parent().has_meta("pogo")):
			pogo = true
	if pogo and dir.y > 0.55 and not _player.is_on_floor():
		_player.apply_external_launch(POGO_VELOCITY)
		_player.refresh_air_moves()
	if count > 0:
		SfxHub.play(get_tree(), "hit")
		var shake := _player.get_node_or_null("CameraShake")
		if shake != null and shake.has_method("add_trauma"):
			shake.add_trauma(0.18)
	return count


func _draw() -> void:
	if _show_t <= 0.0:
		return
	var f := _show_t / SHOW_TIME
	var base := _dir.angle()
	var half := deg_to_rad(HALF_ARC_DEG)
	var hot := _hit_flash > 0.0
	var rim := Color(1.0, 0.92, 0.55, 0.95 * f) if hot else Color(0.55, 1.0, 0.95, 0.9 * f)
	var fill := Color(1.0, 0.85, 0.4, 0.28 * f) if hot else Color(0.4, 0.95, 1.0, 0.24 * f)
	var steps := 10
	var outer_r := REACH * (0.78 + 0.22 * (1.0 - f))
	var wedge := PackedVector2Array([Vector2.ZERO])
	var rim_pts := PackedVector2Array()
	for i in steps + 1:
		var a := base - half + (half * 2.0) * float(i) / float(steps)
		var pt := Vector2.from_angle(a) * outer_r
		wedge.append(pt)
		rim_pts.append(pt)
	draw_colored_polygon(wedge, fill)
	draw_polyline(rim_pts, rim, 6.0 * f + 2.0, false)
	var inner := PackedVector2Array()
	for i in steps + 1:
		var a := base - half * 0.8 + (half * 1.6) * float(i) / float(steps)
		inner.append(Vector2.from_angle(a) * (outer_r * 0.7))
	draw_polyline(inner, Color(1, 1, 1, 0.6 * f), 2.0, false)
