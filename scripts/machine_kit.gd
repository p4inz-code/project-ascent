class_name MachineKit
extends RefCounted
## The discrete parameter grid the generator draws from. Every combination here is probed offline
## (tools/gen_machine_table.gd), so a level roll is table lookups, never sweeps. Adding a value here
## means regenerating the table; tests/test_machine_pieces.gd fails while the table is incomplete.

const SPIKE_WIDTHS := [80.0, 100.0, 120.0, 135.0, 150.0]
const HUMPS := [[110.0, 50.0], [150.0, 70.0], [200.0, 85.0]]
const PIT_WIDTHS := [100.0, 140.0, 170.0, 190.0]
const GAP_WIDTHS := [100.0, 140.0, 150.0, 170.0, 190.0]
const FLAMES := [[140.0, 2.4, 0.8], [200.0, 2.4, 0.8], [140.0, 2.0, 0.8], [200.0, 1.8, 0.7]]
const RSPIKE := [[100.0, 60.0], [130.0, 60.0], [130.0, 90.0], [160.0, 90.0]]
## Belt speeds (px/s, signed: + carries the player right). Against the belt the player nets 320 - speed.
const BELTS := [0.0, 100.0, 160.0, -100.0, -160.0]
## Timed pistons (scrapyard, forge): [width, period, active seconds]. Crush is instant death.
const CRUSHERS := [[110.0, 2.4, 0.8], [110.0, 1.8, 0.8], [130.0, 1.6, 0.8], [90.0, 1.5, 0.8]]
## Hail columns on the deck lane (storm): [width, period, active seconds]. Chip damage.
const HAILS := [[110.0, 2.4, 0.8], [110.0, 1.8, 0.8], [140.0, 1.6, 0.8]]
## Slippery floors under spikes, humps and pits (freezer ice, storm rain-slick).
const SURFACES := ["ice", "slick"]
## Geyser pits (cinder runner): lava gaps with a geyser that erupts on a fixed cycle. [width, margin
## seconds]: margin > 0 means the eruption starts that long AFTER you would cross, < 0 means it ENDS that
## long before you arrive (so a late jump is what gets punished, or an early one).
const GPITS := [[100.0, 0.10], [140.0, 0.10], [170.0, 0.10], [100.0, -0.10], [140.0, -0.10], [170.0, -0.10],
	[140.0, 0.22], [140.0, -0.22]]
const GEYSER_PERIOD := 4.8
const GEYSER_ACTIVE := 1.2
const GEYSER_TELL := 1.0
const TELL := 0.9


static func spikes(lane: String, w: float) -> Dictionary:
	return {"k": "spikes", "lane": lane, "w": w}


static func hump(lane: String, spec: Array) -> Dictionary:
	return {"k": "hump", "lane": lane, "w": spec[0], "h": spec[1]}


static func pit(w: float) -> Dictionary:
	return {"k": "pit", "lane": "L", "w": w}


static func gap(w: float) -> Dictionary:
	return {"k": "gap", "lane": "U", "w": w}


static func flame(spec: Array, phase: float) -> Dictionary:
	return {"k": "flame", "lane": "L", "w": spec[0], "period": spec[1], "active": spec[2], "tell": TELL, "phase": phase}


static func crusher(spec: Array, phase: float) -> Dictionary:
	return {"k": "crusher", "lane": "L", "w": spec[0], "period": spec[1], "active": spec[2], "tell": TELL, "phase": phase}


static func hail(spec: Array, phase: float) -> Dictionary:
	return {"k": "hail", "lane": "U", "w": spec[0], "period": spec[1], "active": spec[2], "tell": TELL, "phase": phase}


## The same piece standing on a slippery floor.
static func on_surface(piece: Dictionary, surface: String) -> Dictionary:
	var p := piece.duplicate()
	p["surface"] = surface
	return p


static func gpit(spec: Array) -> Dictionary:
	return {"k": "gpit", "lane": "L", "w": spec[0], "margin": spec[1], "period": GEYSER_PERIOD,
		"active": GEYSER_ACTIVE, "tell": GEYSER_TELL, "phase": 0.0}


## Set a geyser pit's phase so its eruption sits `margin` seconds off the moment the player crosses it,
## given where the pit is and where (and how fast) the player starts. An auto-running player arrives
## at a known time, so the level is built around it.
static func geyser_phase(piece: Dictionary, x_pit: float, start_x: float, start_offset_s: float) -> float:
	var cross_t := (x_pit + float(piece["w"]) * 0.5 - start_x) / MachineSim.MAX_SPEED + start_offset_s
	var margin: float = float(piece["margin"])
	var active: float = float(piece["active"])
	var period: float = float(piece["period"])
	var start_t := cross_t + margin if margin > 0.0 else cross_t + margin - active
	return fposmod(period - active - start_t, period)


static func jet() -> Dictionary:
	return {"k": "jet", "lane": "L", "w": MachinePieces.JET_W}


static func rspike(spec: Array) -> Dictionary:
	return {"k": "rspike_gap", "lane": "U", "w": spec[0], "len": spec[1]}


## A belt dictionary for the generator, or null for a still floor.
static func belt_of(speed: float) -> Variant:
	if speed == 0.0:
		return null
	return {"dir": 1.0 if speed > 0.0 else -1.0, "speed": absf(speed)}


## Every (piece, belt) combination that must exist in the table. Belts only go under pieces that
## sit on the floor lane and are fair to run on them.
static func all_signatures() -> Array:
	var out: Array = []
	for b in BELTS:
		var belt = belt_of(b)
		for w in SPIKE_WIDTHS:
			out.append({"piece": spikes("L", w), "belt": belt})
		for h in HUMPS:
			out.append({"piece": hump("L", h), "belt": belt})
		for w in PIT_WIDTHS:
			out.append({"piece": pit(w), "belt": belt})
	# Flames never sit on a belt (a belt would carry a waiting player into them).
	for f in FLAMES:
		out.append({"piece": flame(f, 0.0), "belt": null})
	for c in CRUSHERS:
		out.append({"piece": crusher(c, 0.0), "belt": null})
	for sf in SURFACES:
		for w in SPIKE_WIDTHS:
			out.append({"piece": on_surface(spikes("L", w), sf), "belt": null})
		for h in HUMPS:
			out.append({"piece": on_surface(hump("L", h), sf), "belt": null})
		for w in PIT_WIDTHS:
			out.append({"piece": on_surface(pit(w), sf), "belt": null})
	for g in GPITS:
		out.append({"piece": gpit(g), "belt": null})
	out.append({"piece": jet(), "belt": null})
	for w in SPIKE_WIDTHS:
		out.append({"piece": spikes("U", w), "belt": null})
	for h in HUMPS:
		out.append({"piece": hump("U", h), "belt": null})
	for w in GAP_WIDTHS:
		out.append({"piece": gap(w), "belt": null})
	for r in RSPIKE:
		out.append({"piece": rspike(r), "belt": null})
	for hl in HAILS:
		out.append({"piece": hail(hl, 0.0), "belt": null})
	return out
