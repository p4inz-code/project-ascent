class_name SpikeRow
extends Area2D
## A row of metal spikes: floor spikes point up from `base_y`, roof spikes hang down from the
## ceiling. Touching them costs one cell (chip damage, never instant death). The hit box is a touch
## smaller than the picture: a graze is not a hit. The numbers match MachinePieces so the simulator
## and the game agree.

signal player_hit

@export var width: float = 120.0
## Visible height of the teeth.
@export var tooth_height: float = MachinePieces.SPIKE_H
## Hit box height (floor spikes). A roof row uses `hang` for both.
@export var hit_height: float = MachinePieces.SPIKE_HIT_H
@export var hang: bool = false
@export var color: Color = Color(0.78, 0.80, 0.88)
@export var tip_color: Color = Color(1.0, 0.32, 0.25)

var _shape: CollisionShape2D


func _ready() -> void:
	# On the slash layer so a downward slash on spikes bounces the player (a pogo).
	collision_layer = PlayerAttack.SLASH_LAYER
	set_meta("pogo", true)
	collision_mask = 1
	_build()
	body_entered.connect(_on_body_entered)
	add_to_group("spikes")


func _build() -> void:
	var dir := 1.0 if hang else -1.0     # teeth grow downward for roof spikes, upward for floor spikes
	var teeth := maxi(2, int(round(width / 26.0)))
	var tw := width / float(teeth)
	var base := Polygon2D.new()
	base.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(width, 0), Vector2(width, -dir * 4.0), Vector2(0, -dir * 4.0)])
	base.color = Color(0.22, 0.24, 0.30)
	add_child(base)
	for i in teeth:
		var x0 := tw * float(i)
		var tooth := Polygon2D.new()
		tooth.polygon = PackedVector2Array([
			Vector2(x0, 0), Vector2(x0 + tw, 0), Vector2(x0 + tw * 0.5, dir * tooth_height)])
		tooth.color = color
		add_child(tooth)
		var tip := Polygon2D.new()
		tip.polygon = PackedVector2Array([
			Vector2(x0 + tw * 0.25, dir * tooth_height * 0.55), Vector2(x0 + tw * 0.75, dir * tooth_height * 0.55),
			Vector2(x0 + tw * 0.5, dir * tooth_height)])
		tip.color = tip_color
		add_child(tip)
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var h := tooth_height if hang else hit_height
	rect.size = Vector2(width - MachinePieces.SPIKE_INSET * 2.0, h)
	_shape.shape = rect
	_shape.position = Vector2(width * 0.5, dir * h * 0.5)
	add_child(_shape)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_hit.emit()


## Overlap is checked every frame too: a player standing in the spikes after the invulnerable second
## ends must be hit again (body_entered only fires on entry).
func _physics_process(_delta: float) -> void:
	for b in get_overlapping_bodies():
		if b is Player:
			player_hit.emit()
			return
