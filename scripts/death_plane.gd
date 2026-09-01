class_name DeathPlane
extends Node2D
## The floor of the world: a full-width lethal surface under every level.
##
## Before this, falling off the route was dead time. The player was already out
## of the run but kept falling until they crossed `kill_depth`, which on the
## taller levels is over a second of watching nothing happen. In a game built
## entirely on instant retries, that was the worst-feeling second in it.
##
## The fix is a FLOOR, not a shorter timer. You fall, you hit something, you
## die, you are back — and what you hit belongs to the act you are in, so the
## bottom of the world is scenery rather than an invisible cutoff:
##
##   ACT I    ground   a plain miss, no drama
##   ACT II   water    the first act where falling has texture
##   ACT III  ice      reads colder without needing new mechanics
##   ACT IV   lava     the stakes become visible
##   ACT V    lava     the whole floor is hostile
##
## Water here is LETHAL, exactly like lava. Swimmable water is a different
## feature that will live inside levels, not underneath them: the surface at
## the bottom of the world exists to end a run quickly, and something you can
## survive in cannot do that job.
##
## `kill_depth` stays as the backstop for anything that gets past this.

enum Kind { GROUND, WATER, ICE, LAVA }

@export var kind: Kind = Kind.GROUND
@export var width: float = 8000.0
@export var height: float = 420.0

## Emitted the instant the player touches the surface. main_scene.gd routes
## this into the same respawn path as every other hazard.
signal player_hit

var _sensor: Area2D
var _time: float = 0.0
var _triggered: bool = false
var _crest: Polygon2D
var _crest_points: PackedVector2Array


## Palette per kind: [body, crest]. Chosen to sit under the act's own palette
## without competing with the platforms, which are the thing that must read.
const PALETTE: Dictionary = {
	Kind.GROUND: [Color(0.10, 0.09, 0.11), Color(0.28, 0.26, 0.30)],
	Kind.WATER:  [Color(0.05, 0.14, 0.26), Color(0.30, 0.62, 0.88)],
	Kind.ICE:    [Color(0.09, 0.17, 0.24), Color(0.62, 0.86, 0.95)],
	Kind.LAVA:   [Color(0.30, 0.06, 0.03), Color(1.00, 0.48, 0.14)],
}


## Which surface belongs to a level, by act.
static func kind_for_level(level_num: int) -> Kind:
	if level_num <= 5:
		return Kind.GROUND
	if level_num <= 10:
		return Kind.WATER
	if level_num <= 15:
		return Kind.ICE
	return Kind.LAVA


func _ready() -> void:
	z_index = -2  # behind terrain, like the backdrop
	_build_visual()

	_sensor = Area2D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	# Only the top band is lethal. The body below it is decoration, and a
	# hitbox filling the whole polygon would kill a player who is already dead
	# a second time on the way through.
	rect.size = Vector2(width, 24.0)
	shape.shape = rect
	shape.position = Vector2(0.0, 12.0)
	_sensor.add_child(shape)
	_sensor.body_entered.connect(_on_body_entered)
	add_child(_sensor)


func _build_visual() -> void:
	var body: Color = PALETTE[kind][0]
	var crest: Color = PALETTE[kind][1]
	var hw := width * 0.5

	var fill := Polygon2D.new()
	fill.polygon = PackedVector2Array([
		Vector2(-hw, 0.0), Vector2(hw, 0.0),
		Vector2(hw, height), Vector2(-hw, height),
	])
	fill.color = body
	add_child(fill)

	# A lit crest along the top edge, for the same reason platforms have one:
	# it is the line the player reads. Here it says "this is the bottom, and
	# touching it ends the run".
	_crest_points = PackedVector2Array()
	var steps := 64
	for i in steps + 1:
		var x := -hw + width * float(i) / float(steps)
		_crest_points.append(Vector2(x, 0.0))
	_crest = Polygon2D.new()
	_crest.color = crest
	add_child(_crest)
	_refresh_crest(0.0)


## Water, ice and lava all breathe; ground does not. A moving surface reads as
## a place rather than a boundary, which is the whole reason to theme it.
func _refresh_crest(t: float) -> void:
	var pts := PackedVector2Array()
	var amp := 0.0
	var speed := 0.0
	match kind:
		Kind.WATER: amp = 7.0; speed = 1.6
		Kind.ICE:   amp = 3.0; speed = 0.7
		Kind.LAVA:  amp = 9.0; speed = 1.1
		_:          amp = 0.0; speed = 0.0
	var thickness := 7.0
	for p in _crest_points:
		var y := sin(p.x * 0.006 + t * speed) * amp
		pts.append(Vector2(p.x, y))
	# Close the strip back along the bottom.
	for i in range(_crest_points.size() - 1, -1, -1):
		var p: Vector2 = _crest_points[i]
		var y := sin(p.x * 0.006 + t * speed) * amp
		pts.append(Vector2(p.x, y + thickness))
	_crest.polygon = pts


func _process(delta: float) -> void:
	if kind == Kind.GROUND:
		return
	_time += delta
	_refresh_crest(_time)


func _on_body_entered(body: Node2D) -> void:
	# Same retrigger guard as lava.gd: terrain is rebuilt once per level load,
	# not per respawn, so without this the plane would go harmless after the
	# first hit for the rest of the attempt.
	if _triggered or not (body is Player):
		return
	_triggered = true
	player_hit.emit()
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(self):
		_triggered = false
