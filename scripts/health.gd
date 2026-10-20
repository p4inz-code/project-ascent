class_name Health
extends RefCounted
## The suit-energy cells. Pure state with no scene dependencies, so the rules can be tested
## without a player: 3 cells, a hit takes one, a hit grants about a second of invulnerability,
## and cells come back all at once (respawn, or a core).
##
## Chip hazards (enemies, spikes, blades, shooters, steam) take one cell. Instant hazards
## (lava, acid, crush, void, black hole, drowning) never touch this: they kill outright.

const MAX_HP := 3
const INVULN_TIME := 1.0

var hp: int = MAX_HP
var max_hp: int = MAX_HP
## Seconds of invulnerability left after a hit.
var invuln: float = 0.0


func tick(delta: float) -> void:
	invuln = maxf(invuln - delta, 0.0)


func is_invulnerable() -> bool:
	return invuln > 0.0


## Take one chip hit. Returns "ignored" while invulnerable, "hurt" when cells remain,
## "dead" when the last cell went.
func take_hit() -> String:
	if invuln > 0.0 or hp <= 0:
		return "ignored"
	hp -= 1
	if hp <= 0:
		return "dead"
	invuln = INVULN_TIME
	return "hurt"


## Full heal. Returns true when something was actually healed (nothing happens at full HP).
func heal_full() -> bool:
	if hp >= max_hp:
		return false
	hp = max_hp
	return true


## A new life: full cells, no leftover invulnerability.
func reset() -> void:
	hp = max_hp
	invuln = 0.0
