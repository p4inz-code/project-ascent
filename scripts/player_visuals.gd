class_name PlayerVisuals
extends Node2D
## Non-authoritative visual feedback for the player: squash on landing, stretch
## in flight, and a trail of afterimages while dashing.
##
## Deliberately separate from `scripts/player.gd`: nothing here may affect
## physics. It only scales the *visual* `Body` polygon (never the
## `CollisionShape2D`) and reads the controller through its public
## `is_dashing()` / `landed` API, so a bug in here can make the game look wrong
## but never make it play wrong.
##
## The ghost trail uses a fixed pre-allocated pool rather than instancing nodes
## per frame, which keeps the "node count is flat during play" property the
## performance audit relies on (see docs/ARCHITECTURE.md → Performance).

## Fall speed (px/s) that produces the full squash. Slower landings scale down.
@export var max_impact_speed: float = 700.0
## How far the body squashes at full impact (0.25 = 25% shorter, 25% wider).
@export_range(0.0, 0.6) var squash_amount: float = 0.26
## Seconds to recover from a squash or stretch back to neutral.
@export var recover_time: float = 0.13
## Vertical speed at which the in-flight stretch reaches its maximum.
@export var stretch_reference_speed: float = 800.0
## How far the body stretches at that speed.
@export_range(0.0, 0.4) var stretch_amount: float = 0.14
## Afterimages in the dash trail. Fixed pool: raise for a longer trail.
@export var ghost_count: int = 8
## Seconds each afterimage takes to fade out.
@export var ghost_fade_time: float = 0.26
## Starting opacity of an afterimage.
@export_range(0.0, 1.0) var ghost_alpha: float = 0.62
## Horizontal smear applied to each afterimage. A dash only covers ~90 px, so
## eight un-stretched 28 px images sit almost on top of each other and read as
## nothing; widening them joins the trail into one streak.
@export_range(1.0, 3.0) var ghost_stretch: float = 1.6
## Body colour while dashing. The dash is the most powerful verb in the moveset
## and previously had no visual signature at all — the player just moved faster.
@export var dash_tint: Color = Color(0.86, 0.96, 1.0, 1.0)

## Absolute draw layer for the afterimages: above the terrain (z 0), below the
## player (z 2, set on the player scene root). Kept as a constant so the two
## halves of that contract are findable from one place.
const GHOST_Z: int = 1

var _player: Player
var _body: Polygon2D
## The Body polygon's authored colour, restored when a dash ends.
var _base_color: Color = Color.WHITE
## Extra squash applied on top of the flight stretch, decaying to zero.
var _impact: float = 0.0
## Camera shake helper, attached in _attach_camera_shake().
var _shake: CameraShake = null
var _scarf: Polygon2D = null
var _chest: Polygon2D = null
var _scarf_sway: float = 0.0
var _scarf_lift: float = 0.0
var _ghosts: Array[Polygon2D] = []
var _ghost_life: PackedFloat32Array = PackedFloat32Array()
var _next_ghost: int = 0
## Advances while the character is running on the ground, driving the step bob.
## Scalar; irrelevant (and frozen) on the ground or in the air.
var _walk_phase: float = 0.0

## Small forward lean (degrees) applied while running, so the character tips
## into its motion instead of gliding stiffly.
@export var run_lean_deg: float = 4.0
## Slight forward lean (degrees) applied while falling fast, reading as body
## committed to the descent.
@export var fall_lean_deg: float = 3.0
## How wide (x) and short (y) the character reads while wall sliding, relative
## to neutral. A wide, pressed look that reads "gripping the wall".
@export var wall_width: float = 1.28
@export var wall_height: float = 0.62


func _ready() -> void:
	_player = get_parent() as Player
	if _player == null:
		push_warning("PlayerVisuals expects to be a child of a Player node.")
		return
	_body = _player.get_node_or_null("Body") as Polygon2D
	if _body == null:
		push_warning("PlayerVisuals could not find the Player's Body polygon.")
		return
	_apply_player_color()
	_build_character_detail()
	_base_color = _body.color
	_player.landed.connect(_on_landed)
	_build_ghost_pool()
	_attach_camera_shake()


## Give the player a CameraShake sibling, created here rather than authored
## into player.tscn so the scene file stays untouched and any Player instance
## (including the ones headless tests spawn bare) picks it up automatically.
func _attach_camera_shake() -> void:
	if _player.get_node_or_null("CameraShake") != null:
		return
	var shake := CameraShake.new()
	shake.name = "CameraShake"
	# Deferred: this runs from PlayerVisuals._ready(), which happens while the
	# Player is still setting up its own children, and a direct add_child()
	# there fails outright ("parent node is busy setting up children") —
	# leaving the shake node never attached and the whole effect silently
	# dead. Caught by the boot test printing that error.
	_player.add_child.call_deferred(shake)
	_shake = shake


## Recolour the body from the player's chosen palette entry. Runs before
## _base_color is captured so the dash-tint restore, the afterimage pool and
## every other consumer all inherit the chosen colour rather than the
## scene-authored blue.
func _apply_player_color() -> void:
	var gs := get_node_or_null("/root/GameSettings")
	if gs == null or not gs.has_method("get_player_color"):
		return
	var visor := _body.get_node_or_null("Visor") as Polygon2D
	_body.color = gs.get_player_color()
	if visor != null:
		# Keep the visor reading as a bright highlight against whatever body
		# colour was picked, instead of a fixed near-white that vanishes on
		# the paler palette entries.
		visor.color = gs.get_player_color().lightened(0.75)



## Extra silhouette detail: a trailing scarf and a chest accent.
##
## Built here rather than in player.tscn so it inherits whatever palette
## colour the player picked, and so the scarf can react to motion — a static
## polygon in the scene could do neither. Purely cosmetic: nothing in here
## touches the collider or the controller.
func _build_character_detail() -> void:
	if _player.get_node_or_null("Scarf") != null:
		return

	# Scarf sits behind the body so it reads as trailing from the shoulders.
	_scarf = Polygon2D.new()
	_scarf.name = "Scarf"
	_scarf.z_index = -1
	_scarf.color = _body.color.darkened(0.25)
	_player.add_child.call_deferred(_scarf)

	# A brighter chest plate breaks up the flat body colour and gives the
	# character a readable "front", which is what makes facing legible at a
	# glance during fast movement.
	var chest := Polygon2D.new()
	chest.name = "Chest"
	chest.polygon = PackedVector2Array([
		Vector2(-8, -8), Vector2(9, -8), Vector2(6, 3), Vector2(-6, 3)])
	chest.color = _body.color.lightened(0.22)
	_body.add_child.call_deferred(chest)
	_chest = chest


## Sweep the scarf opposite to travel, with a little lag, so it reads as cloth
## rather than a rigid attachment.
func _update_scarf(delta: float) -> void:
	if _scarf == null or not is_instance_valid(_scarf):
		return
	var target := -_player.velocity.x * 0.028
	target = clampf(target, -26.0, 26.0)
	# Lift when falling, so a long drop does not leave it lying flat.
	var lift: float = clampf(-_player.velocity.y * 0.012, -10.0, 12.0)
	_scarf_sway = lerpf(_scarf_sway, target, clampf(delta * 9.0, 0.0, 1.0))
	_scarf_lift = lerpf(_scarf_lift, lift, clampf(delta * 7.0, 0.0, 1.0))
	# Anchored behind the shoulders and trailing AWAY from the body, with a
	# resting offset so it is visible at a standstill rather than only at speed.
	var back := -float(_player.facing())
	var tip := Vector2(back * 16.0 + _scarf_sway, -4.0 + _scarf_lift)
	_scarf.polygon = PackedVector2Array([
		Vector2(back * 4.0, -14.0), Vector2(back * 2.0, -6.0),
		tip + Vector2(0.0, 7.0), tip, tip + Vector2(back * 3.0, -4.0)])
	_scarf.color = Color(_base_color.r, _base_color.g, _base_color.b, 0.85).darkened(0.3)


## Pre-allocate the afterimages once. They are `top_level` so they stay where
## they were stamped instead of riding along with the moving player.
##
## Depth needs absolute z: a *relative* -1 would put the ghosts behind the
## backdrop's ridge polygons (which fill the lower screen at z 0) and they would
## never be seen. Absolute 1 sits above the terrain and below the player, whose
## scene root is pinned to z 2.
func _build_ghost_pool() -> void:
	_ghost_life.resize(ghost_count)
	for i in ghost_count:
		var ghost := Polygon2D.new()
		ghost.polygon = _body.polygon
		ghost.color = _body.color
		ghost.top_level = true
		ghost.visible = false
		ghost.z_as_relative = false
		ghost.z_index = GHOST_Z
		add_child(ghost)
		_ghosts.append(ghost)
		_ghost_life[i] = 0.0


func _on_landed(fall_speed: float) -> void:
	var t := clampf(fall_speed / maxf(max_impact_speed, 1.0), 0.0, 1.0)
	_impact = maxf(_impact, t * squash_amount)
	# Only a genuinely hard landing shakes — every routine hop doing it would
	# make the whole game feel loose.
	if _shake != null and t > 0.55:
		_shake.add_trauma(t * 0.35)


## True while the player is actually descending against a wall — the same
## airborne + on-wall + falling + pressing-toward-the-wall conditions the
## controller uses to clamp the slide (see Player._is_wall_slide_active()).
## Without the direction check, this pose showed "gripping the wall" any time
## the player merely touched a wall while falling, even moving away from it
## or holding no input, while the actual slide clamp — which only engages
## while pressing in — left them falling at full speed underneath the pose.
func _is_wall_sliding() -> bool:
	if _player.is_on_floor() or _player.is_dashing():
		return false
	if not _player.is_on_wall_only():
		return false
	if _player.velocity.y <= 0.0:
		return false
	var direction := Input.get_axis("move_left", "move_right")
	return not is_zero_approx(direction) \
		and signi(direction) == -signi(_player.get_wall_normal().x)


func _physics_process(delta: float) -> void:
	if _body == null:
		return
	var dashing := _player.is_dashing()
	_update_trail(delta, dashing)
	_update_scarf(delta)
	_impact = move_toward(_impact, 0.0, delta / maxf(recover_time, 0.001) * squash_amount)

	# The dash reads as a flash of near-white; everything else is the base blue.
	_body.color = dash_tint if dashing else _base_color

	var grounded := _player.is_on_floor()
	var vy := _player.velocity.y
	var hspeed := absf(_player.velocity.x)
	var moving := grounded and hspeed > 20.0

	# In-flight stretch: elongate with vertical speed, but never while dashing
	# (a dash is purely horizontal, and stretching then reads as a glitch).
	var stretch := 0.0
	if not grounded and not dashing:
		stretch = clampf(absf(vy) / maxf(stretch_reference_speed, 1.0), 0.0, 1.0) * stretch_amount

	# Squash and stretch are opposites on each axis so the body never looks like
	# it changed mass. Direction is applied on x so the character faces the way
	# it is moving.
	var factor := stretch - _impact
	var sx: float
	var sy: float
	if dashing:
		# A dash gets the inverse: wide and flat, in the direction of travel.
		sx = 1.0 + stretch_amount
		sy = 1.0 - stretch_amount
	else:
		sx = 1.0 - factor
		sy = 1.0 + factor

	# --- Pose: which way the body leans and how much it bobs. ---
	_body.rotation = 0.0
	_body.position.y = 0.0
	if _player.is_spinning():
		# A full rotation over the flourish window, in the direction the
		# player is facing — takes priority over the falling lean below
		# since it's a deliberate, brief flourish, not a default pose.
		_body.rotation = TAU * _player.spin_progress() * float(_player.facing())
	elif _is_wall_sliding():
		# Pressed flat against the wall: wide and short, reads as sliding down.
		sx = wall_width
		sy = wall_height
	elif grounded and not dashing:
		if moving:
			# Running: a readable step bob plus a forward lean into the motion.
			_walk_phase += delta * (7.0 + hspeed * 0.03)
			_body.rotation = deg_to_rad(run_lean_deg)
			_body.position.y = sin(_walk_phase) * 3.0
		else:
			# Idle: a slow breathing rise and fall, no static freeze.
			_walk_phase = 0.0
			var breath := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.0035)
			_body.position.y = lerpf(1.6, -1.2, breath)
	elif not grounded and vy > 0.0:
		# Falling: commit to the descent with a slight forward lean.
		_walk_phase = 0.0
		_body.rotation = deg_to_rad(fall_lean_deg)

	# Facing: x-scale is signed by the movement direction so every part (body
	# and visor) mirrors in place.
	_body.scale = Vector2(sx * float(_player.facing()), sy)


func _update_trail(delta: float, dashing: bool) -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs != null and not gs.afterimages:
		# Clear all ghosts when afterimages are disabled
		for i in _ghosts.size():
			if _ghost_life[i] > 0.0:
				_ghost_life[i] = 0.0
				_ghosts[i].visible = false
		return
	# Stamp every frame the dash is active, so a 0.14 s dash lays down roughly
	# eight images — one per pool slot.
	if dashing:
		_stamp_ghost()

	for i in _ghosts.size():
		if _ghost_life[i] <= 0.0:
			continue
		_ghost_life[i] = maxf(_ghost_life[i] - delta, 0.0)
		var ghost := _ghosts[i]
		var t := _ghost_life[i] / maxf(ghost_fade_time, 0.001)
		ghost.color.a = t * ghost_alpha
		ghost.visible = _ghost_life[i] > 0.0


func _stamp_ghost() -> void:
	if _ghosts.is_empty():
		return
	var ghost := _ghosts[_next_ghost]
	ghost.global_position = _player.global_position
	# Body.scale.x is signed by facing() so the polygon (authored facing one
	# way) mirrors correctly; the ghosts copy that same polygon but were
	# never given the same sign, so every afterimage read as facing the
	# original art direction regardless of which way the dash actually went.
	ghost.scale = Vector2(ghost_stretch * float(_player.facing()), 1.0 - stretch_amount)
	ghost.color = Color(dash_tint, ghost_alpha)
	ghost.visible = true
	_ghost_life[_next_ghost] = ghost_fade_time
	_next_ghost = (_next_ghost + 1) % _ghosts.size()


## Clear all transient visual state. Called from the level controller on respawn
## so a new life never starts mid-squash, leaning, bobbing, or trailing ghosts
## from the old one.
func reset_state() -> void:
	_impact = 0.0
	_walk_phase = 0.0
	if _body != null:
		_body.scale = Vector2.ONE
		_body.rotation = 0.0
		_body.position = Vector2.ZERO
		_body.color = _base_color
	for i in _ghosts.size():
		_ghost_life[i] = 0.0
		_ghosts[i].visible = false
