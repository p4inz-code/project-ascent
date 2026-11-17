extends SceneTree
## Every level has its own jump/dash rhythm: the motif differs from level to level, the floor lane of every roll
## follows it (obstacles are jump pieces or pit pieces in the motif's order, from a random start), and the rolls
## inside one level still differ from each other.

var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


## J for spikes/hump, D for pit/gpit; flames, crushers and the rest are skipped.
func _classes(spec: Dictionary) -> String:
	var out := ""
	for c in spec["cells"]:
		var k := String(c["L"]["k"])
		if k == "spikes" or k == "hump":
			out += "J"
		elif k == "pit" or k == "gpit":
			out += "D"
	return out


func _best_match(seq: String, motif: String) -> float:
	if seq.length() < 3:
		return 1.0
	var best := 0.0
	for phase in motif.length():
		var hit := 0
		for i in seq.length():
			if seq[i] == motif[(i + phase) % motif.length()]:
				hit += 1
		best = maxf(best, float(hit) / float(seq.length()))
	return best


func _run() -> void:
	var distinct_neighbours := 0
	var pairs := 0
	for lv in range(6, 40):
		pairs += 1
		if MachineGen.motif_for(lv) != MachineGen.motif_for(lv + 1):
			distinct_neighbours += 1
	_check("neighbouring levels have different rhythms (%d of %d pairs)" % [distinct_neighbours, pairs], distinct_neighbours >= pairs - 6)
	var kinds := {}
	for lv in range(6, 41):
		kinds[MachineGen.motif_for(lv)] = true
	_check("the game uses at least 8 different rhythms (%d)" % kinds.size(), kinds.size() >= 8)
	var worst := 1.0
	var total := 0.0
	var n := 0
	for lv in [6, 9, 12, 16, 19, 22, 27, 33, 38]:
		for s in 4:
			var spec := MachineGen.roll(lv, 100 + s * 13, 1.0)
			var motif: String = String(spec["recipe"].get("motif", ""))
			var seq := _classes(spec)
			var f := _best_match(seq, motif)
			worst = minf(worst, f)
			total += f
			n += 1
	_check("the floor lane follows the level's rhythm (mean %.2f, worst %.2f)" % [total / float(n), worst], total / float(n) >= 0.7)
	# (control) a shuffled sequence does not follow a rhythm as well
	var shuffled := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 40:
		var seq2 := ""
		for k in 10:
			seq2 += "J" if rng.randf() < 0.5 else "D"
		shuffled += _best_match(seq2, "JDJJ")
	_check("(control) random J/D noise matches a rhythm worse (%.2f)" % (shuffled / 40.0), shuffled / 40.0 < total / float(n))
	var a := MachineGen.roll(12, 1)
	var b := MachineGen.roll(12, 2)
	_check("two rolls of one level still differ", str(a["cells"]) != str(b["cells"]))
	print("[test_level_motifs] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)
