# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
class_name CoreSpawner
extends RefCounted
## Builds one optional core (orb) for a level, marked as taken when the save already has it. Every level
## from 5 to 40 carries SaveSystem.ORBS_PER_LEVEL of them (3 per level, 108 in the game, 100 to open the gate).


static func add(parent: Node, level: int, index: int, pos: Vector2, on_orb: Callable,
		drift: Vector2 = Vector2.ZERO, period: float = 2.6, phase: float = 0.0) -> Orb:
	var orb := Orb.new()
	orb.drift = drift
	orb.drift_period = period
	orb.drift_phase = phase
	orb.kind = Orb.Kind.OPTIONAL
	orb.level_num = level
	orb.index = index
	orb.position = pos
	if on_orb.is_valid():
		orb.collected.connect(on_orb)
	var gm := parent.get_node_or_null("/root/GameManager")
	if gm != null and gm.save_system != null and gm.save_system.has_orb(level, index):
		orb.mark_already_taken()
	parent.add_child(orb)
	return orb
