# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
class_name StormEvents
extends Node2D
## The storm over levels 16-19, kept fair by WHERE it acts: lightning only walks the calm cells (the hinges every
## six cells and the last three), where the machine asks for no waiting. A mark is drawn on the floor under you,
## pulses for TELL seconds, then lightning drops there. Keep moving and it never touches you; stand still on a
## calm cell and it costs one cell (a chip). Outside the calm cells nothing happens, so the proven odds of the
## timed pieces are untouched. At most two marks are alive at once.

signal chip(source_x: float)

const TELL := 1.25
const EVERY := 1.4
const ACTIVE := 0.22
const HALF_W := 44.0
const MAX_MARKS := 2

var player: Player = null
var calm_ranges: Array = []       # [x0, x1] pairs
var chips: int = 0
var marks_made: int = 0
var _marks: Array = []
var _since: float = 0.0
var _flash: float = 0.0


## The calm x ranges of a rolled machine: cells 0, every hinge cell, and the last three.
static func calm_ranges_of(spec: Dictionary) -> Array:
	var out: Array = []
	var cells: Array = spec.get("cells", [])
	var n := cells.size()
	for i in n:
		if i == 0 or i >= n - 3 or i % MachineGen.HINGE_EVERY == 0:
			var x: float = float(cells[i]["x"])
			out.append([x, x + MachinePieces.CELL_W])
	return out


static func applies_to(level: int) -> bool:
	return level >= 16 and level <= 19


func in_calm(x: float) -> bool:
	for r in calm_ranges:
		if x >= float(r[0]) and x <= float(r[1]):
			return true
	return false


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_flash = maxf(_flash - delta, 0.0)
	var px := player.global_position.x
	if in_calm(px) and _marks.size() < MAX_MARKS:
		_since += delta
		if _since >= EVERY:
			_since = 0.0
			_marks.append({"x": px, "age": 0.0, "hit": false})
			marks_made += 1
	var keep: Array = []
	for m in _marks:
		m["age"] = float(m["age"]) + delta
		var age: float = m["age"]
		if age >= TELL and age < TELL + ACTIVE and not bool(m["hit"]):
			_flash = 0.1
			var under := absf(px - float(m["x"])) < HALF_W + 14.0
			var py := player.global_position.y
			var on_floor_lane := absf(py - (MachinePieces.FLOOR_Y - 26.0)) < 90.0
			var on_deck_lane := absf(py - (MachinePieces.DECK_Y - 26.0)) < 90.0
			if under and (on_floor_lane or on_deck_lane):
				m["hit"] = true
				chips += 1
				chip.emit(float(m["x"]))
		if age < TELL + ACTIVE + 0.2:
			keep.append(m)
	_marks = keep
	queue_redraw()


func _draw() -> void:
	for m in _marks:
		var age: float = m["age"]
		var x: float = m["x"]
		if age < TELL:
			var f := age / TELL
			draw_arc(Vector2(x, MachinePieces.FLOOR_Y - 2.0), HALF_W * (1.3 - 0.3 * f), 0.0, TAU, 28, Color(0.8, 0.9, 1.0, 0.25 + 0.45 * f), 4.0)
		elif age < TELL + ACTIVE:
			draw_rect(Rect2(x - HALF_W, MachinePieces.CEIL_Y - 300.0, HALF_W * 2.0, MachinePieces.FLOOR_Y - MachinePieces.CEIL_Y + 300.0), Color(0.92, 0.95, 1.0, 0.9))
