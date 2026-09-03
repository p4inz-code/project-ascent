extends SceneTree
## Level rhythm gate — the check that makes the Level 9 / Level 10 class of bug
## unshippable.
##
## WHY THIS EXISTS, and why test_all_levels_reachable.gd is not enough:
##
## The reachability suite drives the real controller and asks "did the player
## end up on the next platform?". It passed Level 10 — whose final jump is a
## 180px rise against a 96px jump apex — because the validator wall-jumps off
## the *face of the target platform* to scrape onto its top. That is a legal
## move, so the suite is not lying about physics. It is answering a different
## question than the one that matters: it proves a frame-perfect bot can reach
## a ledge, not that a human can play it.
##
## Both Level 9 and Level 10 shipped impossible-feeling final jumps that the
## reachability gate waved through, and both were found by a person playing the
## game. This suite closes that gap by checking *design* rather than physics:
##
##   1. No step may demand more rise than a jump can actually deliver.
##   2. No step may wildly break the rhythm its own level spent the whole
##      level establishing — the signature both bugs shared.
##
## Run:
##   Godot --headless --path <project> --script res://tests/test_level_rhythm.gd

## Player jump apex, from player.gd's `jump_height` export. A single jump
## cannot out-climb this, so any required rise above it is impossible without
## a wall or a launcher — neither of which a plain gap provides.
const JUMP_APEX: float = 96.0

## Measured plain-jump envelope: max landable rise at a given horizontal gap.
##
## From tests/probe_max_rise.gd, which binary-searches the real controller:
##
##     gap  60px -> 100px rise      gap 150px ->  79px rise
##     gap 100px -> 100px rise      gap 200px+ -> plain jump runs out of
##                                                horizontal reach entirely
##
## A single fixed ceiling was wrong: a short hop spends most of the jump arc
## climbing, a long one spends it travelling. Using one number flagged Level 4's
## legitimate 95px-gap/80px-rise steps as broken.
##
## Past PLAIN_JUMP_MAX_GAP the step needs a dash, and dash trades height for
## distance. This suite does not model that -- test_all_levels_reachable.gd
## drives a real dash and is the authority there. So the envelope rule below
## only applies to gaps a plain jump could actually span; the rhythm rule
## still applies to every step.
const ENVELOPE: Array = [
	{"gap":  60.0, "rise": 100.0},
	{"gap": 100.0, "rise": 100.0},
	{"gap": 150.0, "rise":  79.0},
	{"gap": 180.0, "rise":  60.0},
]
const PLAIN_JUMP_MAX_GAP: float = 180.0
## Tolerance so a step sitting exactly on the measured boundary is not flagged
## over sub-pixel noise in the binary search.
const RISE_TOLERANCE: float = 2.0

## A step may not demand more than this multiple of its own level's median
## rise. This is the rhythm half of the check — Level 10's last jump was 4.5x
## its level's median, which is what made it read as "unjumpable" even though
## the level had taught a comfortable 40px step six times in a row.
const RHYTHM_FACTOR: float = 2.5

## Levels with fewer scored steps than this have no meaningful median to
## compare against, so the rhythm rule is skipped for them (the absolute
## MAX_RISE rule still applies).
const MIN_STEPS_FOR_RHYTHM: int = 4

var _failures: int = 0
var _warnings: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	for level_num in range(1, LevelData.TOTAL_LEVELS + 1):
		_check_level(level_num)
	print("")
	print("[test_level_rhythm] warnings=%d failures=%d" % [_warnings, _failures])
	quit(1 if _failures > 0 else 0)


## Landable route in build order, excluding boundary walls and decoys — same
## exclusion rule test_all_levels_reachable.gd uses, so both suites reason
## about the same sequence of platforms. Without the Decoy exclusion, a decoy
## sitting off to the side of the real route reads as the "next" step in
## build order and gets judged as an impossible jump it was never meant to be.
func _route(def) -> Array:
	var out: Array = []
	for p in def.platforms:
		var name := String(p.name)
		if name.contains("Wall") or name.contains("Decoy"):
			continue
		out.append(p)
	return out


## Linear interpolation across the measured envelope points above.
func _max_rise_for_gap(gap: float) -> float:
	if gap <= ENVELOPE[0]["gap"]:
		return ENVELOPE[0]["rise"]
	for i in range(ENVELOPE.size() - 1):
		var lo: Dictionary = ENVELOPE[i]
		var hi: Dictionary = ENVELOPE[i + 1]
		if gap <= hi["gap"]:
			var t: float = (gap - lo["gap"]) / (hi["gap"] - lo["gap"])
			return lerpf(lo["rise"], hi["rise"], t)
	return ENVELOPE[ENVELOPE.size() - 1]["rise"]


func _check_level(level_num: int) -> void:
	var def = LevelData.get_level(level_num)
	if def == null:
		print("[FAIL] Level %d — LevelData.get_level() returned null (script failed to compile?)" % level_num)
		_failures += 1
		return
	var route := _route(def)
	if route.size() < 2:
		return

	# Collect every step's rise and gap first, so the median is known before
	# any single step is judged against it.
	var steps: Array = []
	for i in range(route.size() - 1):
		var a = route[i]
		var b = route[i + 1]
		var a_top: float = a.position.y - a.size.y * 0.5
		var b_top: float = b.position.y - b.size.y * 0.5
		var rise: float = a_top - b_top          # positive = climbing
		var gap: float = (b.position.x - b.size.x * 0.5) - (a.position.x + a.size.x * 0.5)
		steps.append({"from": a.name, "to": b.name, "rise": rise, "gap": gap})

	var rises: Array = []
	for s in steps:
		if s["rise"] > 0.0:
			rises.append(s["rise"])
	rises.sort()
	var median: float = 0.0
	if rises.size() > 0:
		median = rises[rises.size() / 2]

	var level_bad := false
	for s in steps:
		var rise: float = s["rise"]
		if rise <= 0.0:
			continue  # level or descending step — never a climb problem

		# ── Rule 1: outside the measured plain-jump envelope ─────────
		var gap: float = s["gap"]
		if gap <= PLAIN_JUMP_MAX_GAP:
			var allowed := _max_rise_for_gap(gap)
			if rise > allowed + RISE_TOLERANCE:
				print("[FAIL] L%d %s -> %s: rise=%.0fpx over a %.0fpx gap exceeds the measured %.0fpx limit"
					% [level_num, s["from"], s["to"], rise, gap, allowed])
				_failures += 1
				level_bad = true
				continue

		# ── Rule 2: breaks the level's own established rhythm ────────
		if rises.size() >= MIN_STEPS_FOR_RHYTHM and median > 0.0 \
				and rise > median * RHYTHM_FACTOR:
			print("[WARN] L%d %s -> %s: rise=%.0fpx is %.1fx this level's median rise (%.0fpx)"
				% [level_num, s["from"], s["to"], rise, rise / median, median])
			_warnings += 1
			level_bad = true

	if not level_bad:
		print("[PASS] Level %d — %d steps, median rise %.0fpx, none out of rhythm"
			% [level_num, steps.size(), median])
