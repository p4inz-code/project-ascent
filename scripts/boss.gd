class_name BossEntity
extends CharacterBody2D
## Boss entity for the Level 5 chase sequence.
##
## The boss follows the player from below/behind, maintaining pressure.
## It does NOT need complex pathfinding — it uses simple direct pursuit
## with platform-aware movement. If it catches the player, the player dies.
##
## Speed increases as the chase progresses to create escalating tension.
## A warning telegraph plays before the boss becomes visible.

@export var base_speed: float = 170.0
@export var acceleration: float = 400.0
@export var gravity: float = 980.0
@export var chase_speed_increase: float = 8.0  # per second of chase
@export var max_speed: float = 320.0
## How close the boss tries to maintain to the player (horizontally).
@export var pressure_distance: float = 300.0
## If the player is further than this, boss speeds up more.
@export var catch_up_threshold: float = 500.0
## Distance at which the boss catches the player (death radius).
@export var catch_distance: float = 48.0

var _player: Player = null
var _active: bool = false
var _chase_time: float = 0.0
var _boss_body: Polygon2D
var _boss_poly: Polygon2D
var _warning_label: Label = null
var _warning_shown: bool = false
var _fade_tween: Tween = null


func _ready() -> void:
	# Create visual representation — large red boss silhouette
	_boss_body = Polygon2D.new()
	_boss_body.color = Color(0.85, 0.25, 0.30, 1.0)
	_boss_body.polygon = PackedVector2Array([
		Vector2(-20, 30), Vector2(20, 30), Vector2(24, 10),
		Vector2(18, -20), Vector2(10, -35), Vector2(-10, -35),
		Vector2(-18, -20), Vector2(-24, 10)
	])
	add_child(_boss_body)

	# Eyes — bright yellow for menace
	_boss_poly = Polygon2D.new()
	_boss_poly.color = Color(1.0, 0.9, 0.4, 1.0)
	_boss_poly.polygon = PackedVector2Array([
		Vector2(-12, -18), Vector2(-4, -18), Vector2(-4, -12), Vector2(-12, -12)
	])
	add_child(_boss_poly)

	var eye2 := Polygon2D.new()
	eye2.color = Color(1.0, 0.9, 0.4, 1.0)
	eye2.polygon = PackedVector2Array([
		Vector2(4, -18), Vector2(12, -18), Vector2(12, -12), Vector2(4, -12)
	])
	add_child(eye2)

	# Collision
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 60)
	col.shape = shape
	add_child(col)

	z_index = 3
	visible = false


func activate(start_pos: Vector2, player: Player, speed: float) -> void:
	global_position = start_pos
	_player = player
	base_speed = speed
	_chase_time = 0.0
	_warning_shown = false
	# Show warning first, then activate after a delay
	_show_warning()
	# Boss appears after warning period
	await get_tree().create_timer(1.5).timeout
	if not is_instance_valid(self):
		return
	_active = true
	visible = true
	print("[Boss] Activated at %s, speed=%.0f" % [start_pos, speed])


func deactivate() -> void:
	_active = false
	visible = false
	velocity = Vector2.ZERO
	_hide_warning()


func _show_warning() -> void:
	# Create warning label at the top of the screen
	if _warning_label != null:
		return
	_warning_label = Label.new()
	_warning_label.text = "⚠ DANGER APPROACHING ⚠"
	_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning_label.add_theme_font_size_override("font_size", 28)
	_warning_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 0.0))
	_warning_label.z_index = 100
	# Position at top center of camera
	_warning_label.position = Vector2(-200, -540)
	_warning_label.size = Vector2(400, 40)
	add_child(_warning_label)
	# Fade in
	_fade_tween = create_tween()
	_fade_tween.tween_property(_warning_label, "modulate:a", 1.0, 0.5)
	_fade_tween.tween_interval(1.0)
	_fade_tween.tween_property(_warning_label, "modulate:a", 0.0, 0.3)
	_fade_tween.tween_callback(_hide_warning)


func _hide_warning() -> void:
	if _warning_label != null and is_instance_valid(_warning_label):
		_warning_label.queue_free()
		_warning_label = null
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()


func _physics_process(delta: float) -> void:
	if not _active or _player == null:
		return

	_chase_time += delta
	# Boss gets faster over time — noticeable but fair
	var current_speed := minf(base_speed + _chase_time * chase_speed_increase, max_speed)

	# Horizontal pursuit: move toward player's X
	var dx := _player.global_position.x - global_position.x
	var dir_x := signf(dx)
	var dist := absf(dx)

	# Speed scaling: if player is far, boss catches up faster
	# If player is close, boss eases off slightly (prevents cheap catches)
	var speed_scale := 1.0
	if dist > catch_up_threshold:
		speed_scale = 1.4
	elif dist < pressure_distance:
		speed_scale = 0.8

	velocity.x = move_toward(velocity.x, dir_x * current_speed * speed_scale,
		acceleration * delta)

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		# Jump if the player is above us and we're on the ground
		# Only jump when somewhat close (prevents wild jumps from far away)
		if _player.global_position.y < global_position.y - 80.0 and dist < 350.0:
			velocity.y = -520.0

	move_and_slide()

	# Face the player
	if _boss_body != null:
		_boss_body.scale.x = 1.0 if dx >= 0.0 else -1.0


## Check if the boss has caught the player.
func has_caught_player() -> bool:
	if not _active or _player == null:
		return false
	return global_position.distance_to(_player.global_position) < catch_distance


func is_active() -> bool:
	return _active
