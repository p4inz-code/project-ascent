# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
class_name EndlessMode
extends RefCounted
## ENDLESS: one unending run of MIXED stages. A stage is not a campaign level: it is a fresh machine whose
## sections are drawn from every biome in the game (four different biomes per stage, each with its own pieces,
## floor, colours and surface), rolled new on every death like every machine. Clear one and the next is drawn;
## every clear raises the count and the difficulty (the stage borrows the odds curve of a deeper campaign slot).
## Nothing is saved to the campaign (no completions, no checkpoints, no cores); only the best count is kept.
##
## Under the hood a stage still uses a campaign machine slot (the "base" level) for its length, kind and odds.
## The base is never shown to the player and never one of the special formats (bosses, the tower, the runner).

const FIRST := 6
const LAST := 39
## Kept for callers and tests: ENDLESS no longer has boss stages.
const BOSSES: Array[int] = [10, 15, 20, 25, 30, 35, 40]
const BIOMES: Array[String] = ["cinder", "scrapyard", "freezer", "storm", "forge", "underworks", "rift", "core"]
const SECTIONS := 4


## The deepest base slot the pool reaches after `streak` clears.
static func ceiling(streak: int) -> int:
	return clampi(FIRST + 2 * streak, FIRST, LAST)


## Base slots a stage may borrow at this streak: ordinary machine levels only.
static func pool(streak: int) -> Array[int]:
	var out: Array[int] = []
	var top := ceiling(streak)
	for lv in range(FIRST, top + 1):
		if lv % 5 != 0:
			out.append(lv)
	return out


## The base slot of the next stage, never the one just played (unless the pool has only that one).
static func next_level(streak: int, rng: RandomNumberGenerator, previous: int = -1) -> int:
	var p := pool(streak)
	var choices: Array[int] = []
	for lv in p:
		if lv != previous:
			choices.append(lv)
	if choices.is_empty():
		choices = p
	return choices[rng.randi_range(0, choices.size() - 1)]


## The biomes of a stage's sections: SECTIONS different biomes in a random order.
static func mix(rng: RandomNumberGenerator) -> Array:
	var left: Array = BIOMES.duplicate()
	var out: Array = []
	for i in SECTIONS:
		var k := rng.randi_range(0, left.size() - 1)
		out.append(left[k])
		left.remove_at(k)
	return out
