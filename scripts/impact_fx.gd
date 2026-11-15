# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
class_name ImpactFx
extends Node2D
## Little pixel puffs: dust when you land hard and a burst of shards when you die. Pure decoration (no
## collision, no input), frees itself, and stays off when the player chose reduced motion (the Calm
## preset turns background motion off, which is the switch read here).

enum Kind { DUST, BURST }

const LIFE := 0.45
const PX := 3.0

var kind: int = Kind.DUST
var strength: float = 1.0
var _t: float = 0.0
var _bits: Array = []        # {pos, vel, size, color}


## Spawns an effect under `parent` at a world position; returns null when reduced motion is on.
static func spawn(parent: Node, pos: Vector2, p_kind: int, p_strength: float = 1.0) -> ImpactFx:
	if not enabled(parent):
		return null
	var fx := ImpactFx.new()
	fx.kind = p_kind
	fx.strength = clampf(p_strength, 0.2, 2.0)
	fx.position = pos
	fx.z_index = 20
	parent.add_child(fx)
	return fx


static func enabled(node: Node) -> bool:
	var gs := node.get_node_or_null("/root/GameSettings") if node.is_inside_tree() else null
	return gs == null or bool(gs.get("bg_motion"))


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var n := int(6.0 * strength) if kind == Kind.DUST else int(14.0 * strength)
	for i in n:
		if kind == Kind.DUST:
			var dir := -1.0 if i % 2 == 0 else 1.0
			_bits.append({"pos": Vector2(dir * rng.randf_range(2.0, 10.0), 0.0),
				"vel": Vector2(dir * rng.randf_range(30.0, 90.0) * strength, rng.randf_range(-40.0, -10.0)),
				"size": rng.randi_range(1, 2), "color": Color(0.85, 0.85, 0.9, 0.8)})
		else:
			var a := rng.randf() * TAU
			_bits.append({"pos": Vector2.ZERO, "vel": Vector2(cos(a), sin(a)) * rng.randf_range(80.0, 260.0),
				"size": rng.randi_range(1, 3), "color": Color(0.45, 0.85, 1.0, 0.95) if i % 3 != 0 else Color(1.0, 1.0, 1.0, 0.95)})


func _process(delta: float) -> void:
	_t += delta
	for b in _bits:
		b["pos"] += b["vel"] * delta
		b["vel"].y += (60.0 if kind == Kind.DUST else 520.0) * delta
	queue_redraw()
	if _t >= LIFE:
		queue_free()


func _draw() -> void:
	var a := clampf(1.0 - _t / LIFE, 0.0, 1.0)
	for b in _bits:
		var c: Color = b["color"]
		c.a *= a
		var s: float = PX * float(b["size"])
		draw_rect(Rect2(Vector2(floorf(b["pos"].x / PX) * PX, floorf(b["pos"].y / PX) * PX), Vector2(s, s)), c)
