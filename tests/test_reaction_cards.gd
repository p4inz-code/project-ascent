extends SceneTree
## Reaction cards: fourteen original pixel faces, each drawn without error, every tier has cards, clears
## get proud ones, the card never takes input, and the death feedback shows one with each line.

var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _run() -> void:
	_check("there are 14 distinct cards", ReactionCard.ALL_KINDS.size() == 14 and ReactionCard.ALL_KINDS.size() == _unique(ReactionCard.ALL_KINDS))
	var covered := {}
	for tier in range(1, 6):
		for k in ReactionCard.kinds_for(tier, false, false):
			covered[k] = true
			_check_known(k)
	for k in ReactionCard.kinds_for(1, true, false) + ReactionCard.kinds_for(1, true, true):
		covered[k] = true
		_check_known(k)
	_check("every card is used by some tier or clear (%d of 14)" % covered.size(), covered.size() == 14)
	_check("(control) tier 5 never shows the proud clear faces", not ("cool" in ReactionCard.kinds_for(5, false, false)) and not ("crown" in ReactionCard.kinds_for(5, false, false)))
	_check("a boss clear can crown you", "crown" in ReactionCard.kinds_for(1, true, true))
	await physics_frame
	for k in ReactionCard.ALL_KINDS:
		var c := ReactionCard.new()
		c.kind = k
		root.add_child(c)
		for i in 2:
			await process_frame
		_check("card '%s' ignores the mouse and has a size" % k, c.mouse_filter == Control.MOUSE_FILTER_IGNORE and c.size.x > 0.0)
		c.queue_free()
	var df := DeathFeedback.new()
	df.forced_mode = 0
	root.add_child(df)
	await process_frame
	df.level = 12
	df.on_death(8)
	_check("a death shows a card with the line (%s)" % df.last_card, df.last_card != "" and df.last_card in ReactionCard.ALL_KINDS)
	df.on_clear(3, false)
	_check("a clear shows a proud card (%s)" % df.last_card, df.last_card in ["cool", "grin"])
	df.on_clear(3, true)
	_check("a boss clear shows a boss card (%s)" % df.last_card, df.last_card in ["crown", "cool"])
	df.queue_free()
	print("[test_reaction_cards] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _unique(a: Array) -> int:
	var d := {}
	for x in a:
		d[x] = true
	return d.size()


func _check_known(k: String) -> void:
	if not (k in ReactionCard.ALL_KINDS):
		_check("card '%s' is a known kind" % k, false)
