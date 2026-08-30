class_name BossEntity
extends CharacterBody2D
## Boss entity for the chase sequences.
##
## The boss follows the player from below/behind, maintaining pressure.
## Speed increases as the chase progresses to create escalating tension.
## A warning telegraph plays before the boss becomes visible.

@export var base_speed: float = 170.0
@export var acceleration: float = 400.0
@export var gravity: float = 980.0
@export var chase_speed_increase: float = 8.0
@export var max_speed: float = 320.0
@export var pressure_distance: float = 300.0
@export var catch_up_threshold: float = 500.0
@export var catch_distance: float = 48.0

var _player: Player = null
var _active: bool = false
var _chase_time: float = 0.0
var _boss_body: Polygon2D
var _boss_poly: Polygon2D
var _warning_label: Label = null
var _warning_shown: bool = false
var _fade_tween: Tween = null
var _pulse_tween: Tween = null
var _eye_left: Polygon2D
var _eye_right: Polygon2D
var _shadow: Polygon2D
var _aura: Polygon2D
var _inner_detail: Polygon2D = null
var _eye_glows: Array = []
var _face_dir: float = 1.0  # Track current facing direction

# Stuck detection — if boss hasn't moved X in this time, force a jump
var _last_x: float = 0.0
var _stuck_timer: float = 0.0
const STUCK_TIMEOUT: float = 1.5
const UNSTUCK_JUMP_VELOCITY: float = -580.0


func _ready() -> void:
	# Shadow underneath
	_shadow = Polygon2D.new()
	_shadow.color = Color(0.0, 0.0, 0.0, 0.3)
	_shadow.polygon = PackedVector2Array([
		Vector2(-22, 32), Vector2(22, 32), Vector2(18, 36), Vector2(-18, 36)
	])
	_shadow.z_index = -1
	add_child(_shadow)

	# Main body — imposing dark red silhouette with shoulders
	_boss_body = Polygon2D.new()
	_boss_body.color = Color(0.72, 0.18, 0.22, 1.0)
	_boss_body.polygon = PackedVector2Array([
		Vector2(-28, 30), Vector2(28, 30), Vector2(30, 15),
		Vector2(26, 0), Vector2(20, -15), Vector2(14, -28),
		Vector2(6, -36), Vector2(-6, -36), Vector2(-14, -28),
		Vector2(-20, -15), Vector2(-26, 0), Vector2(-30, 15)
	])
	add_child(_boss_body)

	# Inner detail — darker core
	_inner_detail = Polygon2D.new()
	_inner_detail.color = Color(0.55, 0.12, 0.16, 0.6)
	_inner_detail.polygon = PackedVector2Array([
		Vector2(-18, 25), Vector2(18, 25), Vector2(20, 10),
		Vector2(16, -10), Vector2(10, -22), Vector2(-10, -22),
		Vector2(-16, -10), Vector2(-20, 10)
	])
	add_child(_inner_detail)

	# Glowing eyes — bright yellow-orange menace
	_eye_left = Polygon2D.new()
	_eye_left.color = Color(1.0, 0.85, 0.3, 1.0)
	_eye_left.polygon = PackedVector2Array([
		Vector2(-14, -22), Vector2(-5, -22), Vector2(-5, -15), Vector2(-14, -15)
	])
	add_child(_eye_left)

	_eye_right = Polygon2D.new()
	_eye_right.color = Color(1.0, 0.85, 0.3, 1.0)
	_eye_right.polygon = PackedVector2Array([
		Vector2(5, -22), Vector2(14, -22), Vector2(14, -15), Vector2(5, -15)
	])
	add_child(_eye_right)

	# Eye glow (inner bright core)
	for eye in [_eye_left, _eye_right]:
		var glow = Polygon2D.new()
		glow.color = Color(1.0, 1.0, 0.7, 0.8)
		glow.polygon = PackedVector2Array([
			Vector2(eye.polygon[0].x + 2, eye.polygon[0].y + 2),
			Vector2(eye.polygon[1].x - 2, eye.polygon[1].y + 2),
			Vector2(eye.polygon[2].x - 2, eye.polygon[2].y - 2),
			Vector2(eye.polygon[3].x + 2, eye.polygon[3].y - 2)
		])
		add_child(glow)
		_eye_glows.append(glow)

	# Aura / danger indicator
	_aura = Polygon2D.new()
	_aura.color = Color(1.0, 0.2, 0.2, 0.08)
	_aura.polygon = PackedVector2Array([
		Vector2(-40, 40), Vector2(40, 40), Vector2(44, -40),
		Vector2(30, -48), Vector2(-30, -48), Vector2(-44, -40)
	])
	_aura.z_index = -1
	add_child(_aura)

	# Collision
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 60)
	col.shape = shape
	add_child(col)

	# Own layer, excluding the player's default layer (1) entirely — without
	# this, the boss was physically indistinguishable from a platform. The
	# player could stand on top of it, and move_and_slide() resolving two
	# overlapping CharacterBody2Ds each frame would destabilize the boss —
	# one landing barely nudged it, a second knocked it off a ledge, where
	# its own gravity dropped it out of view. Read as "the boss died," even
	# though nothing here ever kills it; the catch mechanic is a pure
	# distance check in main_scene.gd, entirely unaffected by this layer
	# change. Mask keeps 1 so it still collides with terrain for gravity.
	collision_layer = 4
	collision_mask = 1

	z_index = 3
	visible = false


func activate(start_pos: Vector2, player: Player, speed: float) -> void:
	global_position = start_pos
	_player = player
	base_speed = speed
	_chase_time = 0.0
	_stuck_timer = 0.0
	_last_x = start_pos.x
	_warning_shown = false
	_show_warning()
	await get_tree().create_timer(1.5).timeout
	if not is_instance_valid(self):
		return
	_active = true
	visible = true
	_start_pulse()
	print("[Boss] Activated at %s, speed=%.0f" % [start_pos, speed])


func deactivate() -> void:
	_active = false
	visible = false
	velocity = Vector2.ZERO
	_hide_warning()
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()


func _start_pulse() -> void:
	# Pulsing aura effect during chase
	if _aura == null:
		return
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_aura, "color:a", 0.15, 0.4)
	_pulse_tween.tween_property(_aura, "color:a", 0.05, 0.4)


func _show_warning() -> void:
	if _warning_label != null:
		return
	var gs = get_node_or_null("/root/GameSettings")
	if gs != null and not gs.boss_warnings:
		# Skip warning, just activate directly
		_warning_shown = true
		return
	# Use a CanvasLayer for screen-space positioning
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	canvas.name = "BossWarning"
	add_child(canvas)
	# Red screen flash for dramatic effect
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.1, 0.1, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(flash)
	# Warning label — centered on screen
	_warning_label = Label.new()
	_warning_label.text = "⚠ DANGER APPROACHING ⚠"
	_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_warning_label.add_theme_font_size_override("font_size", 32)
	_warning_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 0.0))
	_warning_label.add_theme_color_override("font_shadow_color", Color(0.6, 0.05, 0.05, 0.8))
	_warning_label.add_theme_constant_override("shadow_offset_y", 2)
	_warning_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(_warning_label)
	# Flash in, hold, then fade everything
	_fade_tween = create_tween()
	_fade_tween.tween_property(flash, "color:a", 0.25, 0.15)
	_fade_tween.tween_property(flash, "color:a", 0.0, 0.3)
	_fade_tween.parallel().tween_property(_warning_label, "modulate:a", 1.0, 0.3)
	_fade_tween.tween_interval(0.8)
	_fade_tween.tween_property(_warning_label, "modulate:a", 0.0, 0.3)
	_fade_tween.tween_callback(func() -> void:
		if flash != null and is_instance_valid(flash):
			flash.queue_free()
			_hide_warning()
	)


func _hide_warning() -> void:
	if _warning_label != null and is_instance_valid(_warning_label):
		# Clean up the entire CanvasLayer parent
		var parent = _warning_label.get_parent()
		_warning_label = null
		if parent != null and is_instance_valid(parent):
			parent.queue_free()
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()


func _physics_process(delta: float) -> void:
	if not _active or _player == null:
		return

	_chase_time += delta
	var current_speed := minf(base_speed + _chase_time * chase_speed_increase, max_speed)

	var dx := _player.global_position.x - global_position.x
	var dy := _player.global_position.y - global_position.y
	var dir_x := signf(dx)
	var dist := absf(dx)

	var speed_scale := 1.0
	if dist > catch_up_threshold:
		speed_scale = 1.4
	elif dist < pressure_distance:
		speed_scale = 0.8

	velocity.x = move_toward(velocity.x, dir_x * current_speed * speed_scale,
		acceleration * delta)

	# Stuck detection — if boss hasn't moved significantly in X, force a jump
	if is_on_floor():
		if absf(global_position.x - _last_x) > 5.0:
			_stuck_timer = 0.0
			_last_x = global_position.x
		else:
			_stuck_timer += delta
			if _stuck_timer > STUCK_TIMEOUT:
				velocity.y = UNSTUCK_JUMP_VELOCITY
				_stuck_timer = 0.0

	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		# Jump whenever the player is above us — much more aggressive than before
		if dy < -60.0:
			velocity.y = -540.0

	move_and_slide()

	# Face the player — flip ALL visual elements consistently
	_face_dir = 1.0 if dx >= 0.0 else -1.0
	_boss_body.scale.x = _face_dir
	if _inner_detail != null:
		_inner_detail.scale.x = _face_dir
	if _eye_left != null:
		_eye_left.scale.x = _face_dir
	if _eye_right != null:
		_eye_right.scale.x = _face_dir
	for glow in _eye_glows:
		if glow != null:
			glow.scale.x = _face_dir


func has_caught_player() -> bool:
	if not _active or _player == null:
		return false
	return global_position.distance_to(_player.global_position) < catch_distance


func is_active() -> bool:
	return _active
