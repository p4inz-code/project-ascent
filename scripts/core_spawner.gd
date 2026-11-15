# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. All rights reserved. See LICENSE.
# SPDX-License-Identifier: LicenseRef-ProjectAscent-FreeToPlay
class_name CoreSpawner
extends RefCounted
## Builds one optional core (orb) for a level, marked as taken when the save already has it. Every level
## from 5 to 40 carries SaveSystem.ORBS_PER_LEVEL of them (3 per level, 108 in the game, 100 to open the gate).


static func add(parent: Node, level: int, index: int, pos: Vector2, on_orb: Callable) -> Orb:
	var orb := Orb.new()
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
