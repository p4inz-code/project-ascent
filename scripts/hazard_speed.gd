class_name HazardSpeed
extends RefCounted
## The opt-in assist that slows every timed hazard (gates, vents, pendulums, blades, darts).
## One static number, set by GameSettings whenever the setting changes, read by each hazard
## when it advances its own clock. Slower never shortens a safe window: every phase gets
## longer in seconds, so the doctrine "each timed hazard has a guaranteed safe window" only
## gets easier to meet.

const NAMES: Array[String] = ["NORMAL", "SLOWER", "SLOWEST"]
const FACTORS: Array[float] = [1.0, 0.8, 0.65]

static var scale: float = 1.0


static func set_index(i: int) -> void:
	scale = FACTORS[clampi(i, 0, FACTORS.size() - 1)]
