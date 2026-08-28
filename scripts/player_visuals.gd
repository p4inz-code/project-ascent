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
var _ghosts: Array[Polygon2D] = []
var _ghost_life: PackedFloat32Array = PackedFloat32Array()
var _next_ghost: int = 0


func _ready() -> void:
	_player = get_parent() as Player
	if _player == null:
		push_warning("PlayerVisuals expects to be a child of a Player node.")
		return
	_body = _player.get_node_or_null("Body") as Polygon2D
	if _body == null:
		push_warning("PlayerVisuals could not find the Player's Body polygon.")
		return
	_base_color = _body.color
	_player.landed.connect(_on_landed)
	_build_ghost_pool()


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
	var t := clampf(fall_speed / max_impact_speed, 0.0, 1.0)
	_impact = maxf(_impact, t * squash_amount)


func _physics_process(delta: float) -> void:
	if _body == null:
		return
	var dashing := _player.is_dashing()
	_update_trail(delta, dashing)
	_impact = move_toward(_impact, 0.0, delta / maxf(recover_time, 0.001) * squash_amount)

	# The dash reads as a flash of near-white; everything else is the base blue.
	_body.color = dash_tint if dashing else _base_color

	# In-flight stretch: elongate with vertical speed, but never while dashing
	# (a dash is purely horizontal, and stretching then reads as a glitch).
	var stretch := 0.0
	if not _player.is_on_floor() and not dashing:
		var vy := absf(_player.velocity.y) / maxf(stretch_reference_speed, 1.0)
		stretch = clampf(vy, 0.0, 1.0) * stretch_amount

	# Squash and stretch are opposites on each axis, and area is roughly
	# preserved, so the body never looks like it changed mass.
	var factor := stretch - _impact
	if dashing:
		# A dash gets the inverse: wide and flat, in the direction of travel.
		_body.scale = Vector2(1.0 + stretch_amount, 1.0 - stretch_amount)
	else:
		_body.scale = Vector2(1.0 - factor, 1.0 + factor)


func _update_trail(delta: float, dashing: bool) -> void:
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
	ghost.scale = Vector2(ghost_stretch, 1.0 - stretch_amount)
	ghost.color = Color(dash_tint, ghost_alpha)
	ghost.visible = true
	_ghost_life[_next_ghost] = ghost_fade_time
	_next_ghost = (_next_ghost + 1) % _ghosts.size()


## Clear all transient visual state. Called from the level controller on respawn
## so a new life never starts mid-squash or trailing ghosts from the old one.
func reset_state() -> void:
	_impact = 0.0
	if _body != null:
		_body.scale = Vector2.ONE
		_body.color = _base_color
	for i in _ghosts.size():
		_ghost_life[i] = 0.0
		_ghosts[i].visible = false
