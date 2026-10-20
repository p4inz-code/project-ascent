class_name MachinePieces
extends RefCounted
## The machine kit: the geometry of every piece, and how a piece becomes a MachineWorld (the sim's
## scene-free world) AND, through MachineRuntime, real nodes. One definition, two consumers, so the
## proof and the game cannot drift apart.
##
## A machine is a start hinge, then CELLS of CELL_W px, then the end tower. Every cell has a
## lower-lane piece (L) on the floor and an upper-lane piece (U) on the deck, plus an optional belt
## under the L piece. The lower lane is the floor; the upper lane is a deck 200 px above it that
## the player reaches with an air jet (the jet cell has a hole in the deck) and leaves by dropping
## through a gap. The lower lane ends in the furnace; the upper lane ends at the tower and the door.
##
## Lane geometry (px, y grows down):  ceiling underside 400 | deck top 600 (30 thick) | floor top 800
## so a full jump (about 101 px) never touches the deck from the floor, and the deck has 200 px of
## headroom up to the ceiling.

const FLOOR_Y := 800.0
const DECK_Y := 600.0
const DECK_THICK := 30.0
const CEIL_Y := 400.0
const FLOOR_THICK := 400.0
const CELL_W := 520.0
const START_X := 700.0

const SPIKE_H := 30.0
const SPIKE_HIT_H := 24.0
const SPIKE_INSET := 4.0
const FLAME_H := 120.0
const JET_W := 100.0
const JET_SPEED := 560.0
const JET_ACCEL := 4200.0
const HOLE_W := 150.0
## The core's nook: a ledge this far above the deck (a full jump rises about 100), this wide.
const NOOK_RISE := 85.0
const NOOK_W := 110.0
const NOOK_THICK := 20.0
## Lava in a pit: the surface sits 12 px under the floor and kills 30 px below that surface.
const GEYSER_H := 260.0
const RUNNER_THICK := 60.0
const PIT_SURFACE := 12.0
const PIT_KILL_DEPTH := 42.0

## Lower-lane kinds, upper-lane kinds.
const LOW_KINDS := ["plain", "spikes", "hump", "pit", "flame", "crusher", "jet", "furnace"]
const UP_KINDS := ["none", "deck", "gap", "rspike_gap", "spikes", "hump", "hail"]
## How slippery each floor surface is: the multiplier on the player's ground accel/decel times.
const ICE_SLIP := 5.5
const SLICK_SLIP := 2.5


## A cell's pieces as a flat list of piece dictionaries. cell = {x, L: {...}, U: {...}, belt: {dir, speed}|null}.
static func cell_pieces(cell: Dictionary) -> Array:
	var out: Array = []
	if cell.has("L") and cell["L"] != null:
		var l: Dictionary = (cell["L"] as Dictionary).duplicate()
		l["lane"] = "L"
		out.append(l)
	if cell.has("U") and cell["U"] != null:
		var u: Dictionary = (cell["U"] as Dictionary).duplicate()
		u["lane"] = "U"
		out.append(u)
	return out


## Every solid of a machine as {rect, kind, belt?}: kind is floor, belt, deck, hump or roof. The sim
## world and the real nodes (MachineRuntime) are both built from this one list, so they agree.
static func solids_of(spec: Dictionary) -> Array:
	var out: Array = []
	var cells: Array = spec["cells"]
	var x_end: float = float(spec["end_x"])
	var runner: bool = String(spec.get("mode", "machine")) == "runner"
	var thick: float = RUNNER_THICK if runner else FLOOR_THICK
	# --- the floor: one long slab, cut open under pits, split where a belt starts or ends ---
	var cuts: Array = []
	for cell in cells:
		for p in cell_pieces(cell):
			if p["lane"] == "L" and (p["k"] == "pit" or p["k"] == "gpit" or p["k"] == "furnace"):
				cuts.append([float(p["x"]), float(p["x"]) + float(p["w"])])
	var floor_spans := _subtract([-400.0, x_end + 600.0], cuts)
	for span in floor_spans:
		# split the span at every belt cell edge it crosses
		var marks: Array = [span[0], span[1]]
		for cell in cells:
			if cell.get("belt") != null or String(cell.get("surface", "")) != "":
				var bx: float = float(cell["x"])
				for m in [bx, bx + CELL_W]:
					if m > span[0] + 0.5 and m < span[1] - 0.5:
						marks.append(m)
		marks.sort()
		for i in marks.size() - 1:
			var x0: float = marks[i]
			var x1: float = marks[i + 1]
			if x1 - x0 < 1.0:
				continue
			var mid := (x0 + x1) * 0.5
			var belt = null
			var surface := ""
			for cell in cells:
				if mid >= float(cell["x"]) and mid < float(cell["x"]) + CELL_W:
					if cell.get("belt") != null:
						belt = cell["belt"]
					surface = String(cell.get("surface", ""))
			var d := {"rect": Rect2(x0, FLOOR_Y, x1 - x0, thick), "kind": "floor"}
			if belt != null:
				d["kind"] = "belt"
				d["belt"] = belt
			elif surface != "":
				d["kind"] = surface       # "ice" or "slick"
			out.append(d)
	if runner:
		# floating tiles over a lava lake: no deck, no roof, nothing but the floor and the hazards
		for cell in cells:
			for p in cell_pieces(cell):
				if p["k"] == "hump":
					out.append({"rect": Rect2(float(p["x"]), FLOOR_Y - float(p["h"]), float(p["w"]), float(p["h"])), "kind": "hump"})
		return out
	# --- the deck: slabs between holes, over every cell that has an upper lane ---
	var deck_spans: Array = []
	var holes: Array = []
	for cell in cells:
		var cx: float = float(cell["x"])
		var u = cell.get("U")
		if u == null or u["k"] == "none":
			continue
		deck_spans.append([cx, cx + CELL_W])
		if u["k"] == "gap" or u["k"] == "rspike_gap":
			holes.append([float(u["x"]), float(u["x"]) + float(u["w"])])
		var l = cell.get("L")
		if l != null and l["k"] == "jet":
			holes.append([float(l["hole_x"]), float(l["hole_x"]) + float(l["hole_w"])])
	for s in _merge_spans(deck_spans):
		for seg in _subtract(s, holes):
			if seg[1] - seg[0] > 1.0:
				out.append({"rect": Rect2(seg[0], DECK_Y, seg[1] - seg[0], DECK_THICK), "kind": "deck"})
	# --- the roof ---
	out.append({"rect": Rect2(START_X - 200.0, CEIL_Y - 200.0, x_end - START_X + 1200.0, 200.0), "kind": "roof"})
	# --- humps ---
	for cell in cells:
		for p in cell_pieces(cell):
			if p["k"] == "hump":
				var base_y := FLOOR_Y if p["lane"] == "L" else DECK_Y
				out.append({"rect": Rect2(float(p["x"]), base_y - float(p["h"]), float(p["w"]), float(p["h"])), "kind": "hump"})
	if spec.has("nook"):
		out.append({"rect": spec["nook"]["rect"], "kind": "nook"})
	return out


## Build the sim world for a spec: {cells: [...], end_x: float, goal: Rect2}.
static func build_world(spec: Dictionary) -> MachineWorld:
	var w := MachineWorld.new()
	for d in solids_of(spec):
		w.add_solid(d["rect"])
		if d["kind"] == "belt":
			var r: Rect2 = d["rect"]
			w.belts.append({"rect": Rect2(r.position.x, FLOOR_Y, r.size.x, 4.0),
				"speed": float(d["belt"]["dir"]) * float(d["belt"]["speed"])})
		elif d["kind"] == "ice" or d["kind"] == "slick":
			var r2: Rect2 = d["rect"]
			w.slips.append({"rect": Rect2(r2.position.x, FLOOR_Y, r2.size.x, 4.0),
				"slip": ICE_SLIP if d["kind"] == "ice" else SLICK_SLIP})
	for cell in spec["cells"]:
		for p in cell_pieces(cell):
			_add_piece(w, p)
	w.kill_y = FLOOR_Y + 700.0
	if String(spec.get("mode", "machine")) == "runner":
		# the lava lake under every tile
		w.hazards.append({"rect": Rect2(-400.0, FLOOR_Y + RUNNER_THICK + 20.0, float(spec["end_x"]) + 1400.0, 500.0),
			"kind": "kill", "period": 0.0, "name": "lava lake"})
	if spec.has("goal"):
		w.goal = spec["goal"]
	w.finalize()
	return w


static func _add_piece(w: MachineWorld, p: Dictionary) -> void:
	if not p.has("x"):
		return      # plain floor, plain deck, "none": nothing to build
	var x: float = float(p["x"])
	var pw: float = float(p.get("w", 0.0))
	var lane: String = p["lane"]
	var base_y: float = FLOOR_Y if lane == "L" else DECK_Y
	match String(p["k"]):
		"spikes":
			w.hazards.append({"rect": Rect2(x + SPIKE_INSET, base_y - SPIKE_HIT_H, pw - SPIKE_INSET * 2.0, SPIKE_HIT_H),
				"kind": "chip", "period": 0.0, "name": "spikes"})
		"hump":
			pass     # a solid: built by solids_of
		"pit":
			# Lava under the open floor: the fall into it is a kill.
			w.hazards.append({"rect": Rect2(x + 4.0, FLOOR_Y + PIT_KILL_DEPTH, pw - 8.0, 270.0), "kind": "kill", "period": 0.0, "name": "lava"})
		"gpit":
			w.hazards.append({"rect": Rect2(x + 4.0, FLOOR_Y + PIT_KILL_DEPTH, pw - 8.0, 270.0), "kind": "kill", "period": 0.0, "name": "lava"})
			# the geyser: a column from the lava up well above any jump, on a fixed cycle
			w.hazards.append({"rect": Rect2(x + 6.0, FLOOR_Y - GEYSER_H, pw - 12.0, GEYSER_H + 40.0), "kind": "chip",
				"period": float(p["period"]), "active": float(p["active"]), "tell": float(p["tell"]),
				"phase": float(p["phase"]), "name": "geyser"})
		"furnace":
			w.hazards.append({"rect": Rect2(x, FLOOR_Y - 20.0, pw, 400.0), "kind": "kill", "period": 0.0, "name": "furnace"})
		"flame":
			w.hazards.append({"rect": Rect2(x + 6.0, FLOOR_Y - FLAME_H, pw - 12.0, FLAME_H), "kind": "chip",
				"period": float(p["period"]), "active": float(p["active"]), "tell": float(p["tell"]),
				"phase": float(p["phase"]), "name": "flame"})
		"jet":
			var top := DECK_Y + 20.0
			w.jets.append({"rect": Rect2(x, top, pw, FLOOR_Y - top), "speed": JET_SPEED, "accel": JET_ACCEL,
				"period": 0.0})
		"crusher":
			# The slam fills the lane from the deck underside to the floor: crush is instant death.
			var top := DECK_Y + DECK_THICK
			w.hazards.append({"rect": Rect2(x + 4.0, top, pw - 8.0, FLOOR_Y - top), "kind": "kill",
				"period": float(p["period"]), "active": float(p["active"]), "tell": float(p["tell"]),
				"phase": float(p["phase"]), "name": "crusher"})
		"hail":
			# A column of hail from the ceiling down to the deck.
			w.hazards.append({"rect": Rect2(x + 6.0, CEIL_Y, pw - 12.0, DECK_Y - CEIL_Y), "kind": "chip",
				"period": float(p["period"]), "active": float(p["active"]), "tell": float(p["tell"]),
				"phase": float(p["phase"]), "name": "hail"})
		"rspike_gap":
			# Spikes hang from the ceiling above the gap.
			w.hazards.append({"rect": Rect2(float(p["sx"]), CEIL_Y, float(p["sw"]), float(p["len"])),
				"kind": "chip", "period": 0.0, "name": "roof spikes"})


static func _merge_spans(spans: Array) -> Array:
	if spans.is_empty():
		return []
	var sorted := spans.duplicate()
	sorted.sort_custom(func(a, b): return a[0] < b[0])
	var out: Array = [[sorted[0][0], sorted[0][1]]]
	for i in range(1, sorted.size()):
		var s = sorted[i]
		if s[0] <= out[-1][1] + 0.5:
			out[-1][1] = maxf(out[-1][1], s[1])
		else:
			out.append([s[0], s[1]])
	return out


static func _subtract(span: Array, holes: Array) -> Array:
	var segs: Array = [[span[0], span[1]]]
	for h in holes:
		var next: Array = []
		for s in segs:
			if h[1] <= s[0] or h[0] >= s[1]:
				next.append(s)
				continue
			if h[0] > s[0]:
				next.append([s[0], h[0]])
			if h[1] < s[1]:
				next.append([h[1], s[1]])
		segs = next
	return segs


## Horizontal extent [x0, x1] a piece occupies (for spacing rules and the bot's look-ahead).
static func span_of(p: Dictionary) -> Array:
	var x: float = float(p["x"])
	match String(p["k"]):
		"jet":
			return [float(p["hole_x"]), float(p["hole_x"]) + float(p["hole_w"])]
		"rspike_gap":
			return [float(p["x"]), float(p["x"]) + float(p["w"])]
	return [x, x + float(p.get("w", 0.0))]
