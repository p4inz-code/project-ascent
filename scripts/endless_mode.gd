# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
class_name EndlessMode
extends RefCounted
## ENDLESS: an unending chain of levels from the campaign. Clear one and the next is drawn; every clear raises the
## streak, the pool of levels widens (up to level 40) and every fifth clear is a boss. Nothing is saved to the
## campaign (no completions, no checkpoints, no cores); only the best streak is kept. Death re-rolls the same
## level like everywhere else, so the streak is about clearing, not about never dying.

const FIRST := 6
const LAST := 40
const BOSSES: Array[int] = [10, 15, 20, 25, 30, 35, 40]
const BOSS_EVERY := 5


## The highest level the pool reaches after `streak` clears.
static func ceiling(streak: int) -> int:
	return clampi(FIRST + 2 * streak, FIRST, LAST)


static func is_boss_slot(streak: int) -> bool:
	return streak % BOSS_EVERY == BOSS_EVERY - 1


static func pool(streak: int) -> Array[int]:
	var out: Array[int] = []
	var top := ceiling(streak)
	if is_boss_slot(streak):
		for b in BOSSES:
			if b <= maxi(top + 5, 10):
				out.append(b)
		return out
	for lv in range(FIRST, top + 1):
		if not (lv in BOSSES):
			out.append(lv)
	return out


## The next level for a streak, never the one just played (unless the pool has only that one).
static func next_level(streak: int, rng: RandomNumberGenerator, previous: int = -1) -> int:
	var p := pool(streak)
	var choices: Array[int] = []
	for lv in p:
		if lv != previous:
			choices.append(lv)
	if choices.is_empty():
		choices = p
	return choices[rng.randi_range(0, choices.size() - 1)]
