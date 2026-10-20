class_name MachineBot
extends RefCounted
## A bot that runs a machine in the sim the way a person would: it runs right, and for every
## obstacle on its lane it carries out a PLAN (when to jump, how long to hold, when to start across
## a flame, where to stand in a jet). The nominal plan comes from MachineProbe (found by sweeping the
## real physics); a NOISY bot perturbs every decision with human-sized timing error, so the same
## class gives both the proof ("a perfect run exists") and the odds ("a median person clears it
## about p of the time").
##
## Noise model (see docs/PLAN_v2_big_run_2026-10-20.md, round 8): timing error sigma of 20/40/60 ms
## for an expert/median/novice player, converted to pixels by the ground speed; a small fixed
## perception error on distances.

const SIGMA_EXPERT := 0.020
const SIGMA_MEDIAN := 0.040
const SIGMA_NOVICE := 0.060
const PERCEPTION_PX := 4.0

var sim: MachineSim = null
var world: MachineWorld = null
var events: Array = []          # [{piece, kind, plan, ...}] in route order
var idx: int = 0
var sigma_t: float = 0.0
var rng: RandomNumberGenerator = null
var override_plan: Dictionary = {}   # when set, replaces the plan of every event of kind override_kind
var override_kind: String = ""
var goal_x: float = 0.0
## When true every frame's input is appended to `inputs` as [move, jump_pressed, jump_held], so a run
## can be replayed on the real player (tests/test_machine_replay.gd).
var record_inputs: bool = false
## A fixed timing error added to every decision (seconds): +-2 frames in the robustness test.
var fixed_shift_t: float = 0.0
var inputs: Array = []
var states: Array = []

## Where the bot was hit (for diagnostics and tests).
var hit_log: Array = []
var _last_hits: int = 0
var _phase: int = 0
var _hold_n: int = 0
var _trigger_x: float = 0.0
var _hold_frames: int = 22
var _go_t: float = -1.0
var _decided: bool = false
var _stand_x: float = 0.0
var _prev_jump_held: bool = false
var _done_at_x: float = 0.0


## What a runner on `lane_in` can do in this cell: a list of options, each {lane_out, events}.
## The L lane is blocked by a jet (it carries you up); the U lane can drop through a gap.
static func cell_options(cell: Dictionary, lane_in: String, idx: int) -> Array:
	var l = cell.get("L")
	var u = cell.get("U")
	var belt = cell.get("belt")
	var out: Array = []
	if lane_in == "L":
		if l != null and l["k"] == "jet":
			out.append({"lane_out": "U", "events": [{"kind": "jet", "piece": l, "belt": belt, "cell": idx}]})
		elif l != null and l["k"] != "plain":
			out.append({"lane_out": "L", "events": [{"kind": String(l["k"]), "piece": l, "belt": belt, "cell": idx, "lane": "L"}]})
		else:
			out.append({"lane_out": "L", "events": []})
		return out
	# Upper lane.
	if l != null and l["k"] == "jet":
		# Dropping into the jet column just lifts you back up, so the hole costs nothing.
		out.append({"lane_out": "U", "events": []})
		return out
	if u != null and (u["k"] == "gap" or u["k"] == "rspike_gap"):
		out.append({"lane_out": "U", "events": [{"kind": String(u["k"]), "piece": u, "belt": null, "cell": idx, "lane": "U"}]})
		out.append({"lane_out": "L", "events": [{"kind": "drop", "piece": u, "belt": null, "cell": idx}]})
		return out
	if u != null and (u["k"] == "spikes" or u["k"] == "hump"):
		out.append({"lane_out": "U", "events": [{"kind": String(u["k"]), "piece": u, "belt": null, "cell": idx, "lane": "U"}]})
		return out
	out.append({"lane_out": "U", "events": []})
	return out


## Turn a spec + the lane the runner is in at the END of each cell into the event list.
static func events_for(spec: Dictionary, route: Array, start_lane: String = "L") -> Array:
	var out: Array = []
	var lane := start_lane
	var cells: Array = spec["cells"]
	for i in cells.size():
		var want: String = route[i] if i < route.size() else lane
		var opts := cell_options(cells[i], lane, i)
		var chosen: Dictionary = opts[0]
		for o in opts:
			if String(o["lane_out"]) == want:
				chosen = o
		for e in chosen["events"]:
			out.append(e)
		lane = String(chosen["lane_out"])
	return out


static func ground_sigma_px(sigma_t_s: float, belt_speed: float = 0.0) -> float:
	var v := absf(MachineSim.MAX_SPEED + belt_speed)
	return sqrt(pow(sigma_t_s * v, 2.0) + PERCEPTION_PX * PERCEPTION_PX)


func _init(p_world: MachineWorld, p_events: Array, start: Vector2, p_goal_x: float, p_sigma_t: float = 0.0,
		p_rng: RandomNumberGenerator = null, start_speed: float = MachineSim.MAX_SPEED) -> void:
	world = p_world
	events = p_events
	goal_x = p_goal_x
	sigma_t = p_sigma_t
	rng = p_rng if p_rng != null else RandomNumberGenerator.new()
	sim = MachineSim.new(world, start, start_speed)
	sim.on_floor = true


func _noise(sigma: float) -> float:
	if sigma <= 0.0:
		return 0.0
	return rng.randfn(0.0, sigma)


## Run until the goal, a death or the time limit. Returns {finished, dead, cause, hits, t, x}.
func run(limit_s: float = 120.0) -> Dictionary:
	var steps := int(limit_s / MachineSim.DT)
	for _i in steps:
		_step_once()
		if sim.dead or sim.pos.x >= goal_x:
			break
	return {"finished": (not sim.dead) and sim.pos.x >= goal_x, "dead": sim.dead, "cause": sim.death_cause,
		"hits": sim.chip_hits, "t": sim.t, "x": sim.pos.x}


func _current() -> Dictionary:
	if idx >= events.size():
		return {}
	return events[idx]


func _step_once() -> void:
	# A person who is hit tries the obstacle again: forget the failed attempt and decide afresh.
	if sim.chip_hits != _last_hits:
		_last_hits = sim.chip_hits
		_phase = 0
		_hold_n = 0
		_decided = false
		_go_t = -1.0
		hit_log.append(sim.pos)
	var move := 1.0
	var jp := false
	var jh := false
	var ev := _current()
	if not ev.is_empty():
		var out := _act(ev)
		move = out[0]
		jp = out[1]
		jh = out[2]
	if record_inputs:
		inputs.append([move, jp, jh])
	sim.step(move, jp, jh, false)
	if record_inputs:
		states.append(sim.pos)


## Decide this frame's input for the current event. Returns [move, jump_pressed, jump_held].
func _act(ev: Dictionary) -> Array:
	var kind: String = ev["kind"]
	var piece: Dictionary = ev["piece"]
	var span := MachinePieces.span_of(piece)
	var x := sim.pos.x
	if not _decided:
		_decide(ev)
	match kind:
		"spikes", "hump", "pit", "gap", "rspike_gap":
			return _act_jump(ev, span)
		"flame":
			return _act_flame(ev, span)
		"jet":
			return _act_jet(ev, span)
		"drop", "furnace":
			if x > span[1] + 30.0:
				_next()
			return [1.0, false, false]
	_next()
	return [1.0, false, false]


func _next() -> void:
	# Leaving an upper-lane obstacle while standing on the floor means the bot fell off the deck.
	var ev := _current()
	if not ev.is_empty() and String(ev.get("lane", "")) == "U" and sim.on_floor 			and sim.pos.y + MachineSim.HALF.y > MachinePieces.DECK_Y + 30.0:
		sim.kill("fell off the deck")
	idx += 1
	_phase = 0
	_hold_n = 0
	_decided = false
	_go_t = -1.0


## Make this event's one-off decisions (with the human error baked in).
func _decide(ev: Dictionary) -> void:
	_decided = true
	var kind: String = ev["kind"]
	var plan: Dictionary = override_plan if (not override_plan.is_empty() and override_kind == kind) \
		else MachineProbe.plan_for(ev["piece"], ev.get("belt"))
	var belt = ev.get("belt")
	var bspeed: float = 0.0 if belt == null else float(belt["dir"]) * float(belt["speed"])
	var span := MachinePieces.span_of(ev["piece"])
	match kind:
		"spikes", "hump", "pit", "gap", "rspike_gap":
			# A perfect bot (sigma 0) has no perception error either.
			var sx := 0.0 if sigma_t <= 0.0 else ground_sigma_px(sigma_t, bspeed)
			_trigger_x = span[0] - float(plan["lead"]) + _noise(sx) + fixed_shift_t * (MachineSim.MAX_SPEED + bspeed)
			_hold_frames = maxi(2, int(round(float(plan.get("hold", 30.0)) + _noise(sigma_t * 60.0))))
		"flame":
			_stand_x = span[0] - float(plan.get("stand", 70.0))
			_go_t = float(plan["delta"]) + _noise(sigma_t) + fixed_shift_t
		"jet":
			var jp: Dictionary = ev["piece"]
			_stand_x = float(jp["x"]) + float(jp["w"]) * 0.5 + float(plan.get("offset", 0.0)) \
				+ _noise(sigma_t * MachineSim.MAX_SPEED * 0.8) + fixed_shift_t * MachineSim.MAX_SPEED * 0.8


func _act_jump(ev: Dictionary, span: Array) -> Array:
	var x := sim.pos.x
	match _phase:
		0:
			if x >= _trigger_x:
				_phase = 1
				_hold_n = 1
				return [1.0, true, true]
			return [1.0, false, false]
		1:
			_hold_n += 1
			if _hold_n > _hold_frames:
				_phase = 2
				return [1.0, false, false]
			return [1.0, false, true]
		_:
			if x > span[1] + 40.0 and sim.on_floor:
				_next()
			return [1.0, false, false]


func _act_flame(ev: Dictionary, span: Array) -> Array:
	var piece: Dictionary = ev["piece"]
	var x := sim.pos.x
	if _phase == 0:
		# Walk up to the standing point and stop there.
		var dx := _stand_x - x
		if dx > sim.vel.x * 0.06 + 3.0:
			return [1.0, false, false]
		_phase = 1
		# Next time the flame goes out (the end of an active window) at or after now.
		var period: float = float(piece["period"])
		var ph: float = float(piece["phase"])
		var k: float = ceil((sim.t + ph + 0.15) / period)
		_go_t = k * period - ph + _go_t
		return [0.0, false, false]
	if _phase == 1:
		if sim.t >= _go_t:
			_phase = 2
			return [1.0, false, false]
		return [0.0, false, false]
	if x > span[1] + 30.0:
		_next()
	return [1.0, false, false]


func _act_jet(ev: Dictionary, span: Array) -> Array:
	var piece: Dictionary = ev["piece"]
	var x := sim.pos.x
	var feet := sim.pos.y + MachineSim.HALF.y
	if _phase == 0:
		var dx := _stand_x - x
		var brake := absf(sim.vel.x) * 0.07
		if absf(dx) <= brake + 2.0 and (sim.vel.x * dx >= 0.0):
			_phase = 1
			return [0.0, false, false]
		return [signf(dx), false, false]
	if _phase == 1:
		# Rising in the column: wait until the feet are above the deck, then head right.
		if feet < MachinePieces.DECK_Y - 8.0:
			_phase = 2
			return [1.0, false, false]
		# Keep centred over the jet while it lifts.
		var cdx := _stand_x - x
		return [clampf(cdx / 12.0, -1.0, 1.0), false, false]
	if _phase == 2:
		if sim.on_floor and absf(feet - MachinePieces.DECK_Y) < 3.0 and x > span[1] + 4.0:
			_next()
		return [1.0, false, false]
	_next()
	return [1.0, false, false]
