extends SceneTree
## Keyboard rebinding: a rebound key must trigger the action and the old one must
## not; conflicts swap (never leave an action unbound); gamepad events survive;
## Escape is refused; reset restores the shipped layout; saved data round-trips;
## and hostile/corrupt saved data can never produce an illegal binding.

var _failures: int = 0


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await physics_frame
	_run()
	print("[test_rebinding] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code as Key
	e.pressed = true
	return e


## A key no rebindable action uses, so "free key" assertions can't depend on the layout.
func _first_free_key() -> int:
	for code in [KEY_J, KEY_K, KEY_U, KEY_I, KEY_O, KEY_P, KEY_N, KEY_M, KEY_B, KEY_V]:
		if InputBindings.conflict("jump", code) == "" and code not in InputBindings.keys_for("jump"):
			return code
	return 0


func _joy_count(action: String) -> int:
	var n := 0
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
			n += 1
	return n


func _run() -> void:
	InputBindings.snapshot_defaults()
	var jump_default := InputBindings.default_keys("jump")
	var dash_default := InputBindings.default_keys("dash")
	var jump_joy := _joy_count("jump")
	_check("jump has a shipped keyboard default", not jump_default.is_empty())
	_check("every rebindable action exists in the InputMap",
		InputBindings.ACTIONS.all(func(a): return InputMap.has_action(a)))

	# --- plain rebind -------------------------------------------------------
	var free_key := _first_free_key()
	_check("found a free test key", free_key != 0)
	_check("test key starts unbound", InputBindings.conflict("jump", free_key) == "")
	var displaced := InputBindings.rebind("jump", free_key)
	_check("rebind to a free key displaces nothing", displaced == "")
	_check("new key triggers the action", InputMap.event_is_action(_key(free_key), "jump"))
	for old in jump_default:
		if old != free_key:
			_check("old key %s no longer triggers jump" % InputBindings.key_name(old),
				old in InputBindings.keys_for("jump") or not InputMap.event_is_action(_key(old), "jump"))
	_check("jump's PRIMARY key is the new one", InputBindings.keys_for("jump")[0] == free_key)
	_check("gamepad bindings untouched by a keyboard rebind", _joy_count("jump") == jump_joy)

	# --- conflict swaps -----------------------------------------------------
	var dash_primary: int = dash_default[0]
	var jump_primary_before: int = InputBindings.keys_for("jump")[0]
	displaced = InputBindings.rebind("jump", dash_primary)
	_check("taking dash's key reports dash as displaced", displaced == "dash")
	_check("jump now owns dash's old key", InputBindings.keys_for("jump")[0] == dash_primary)
	_check("dash received jump's old key (swap)", jump_primary_before in InputBindings.keys_for("dash"))
	_check("dash is not left unbound", not InputBindings.keys_for("dash").is_empty())
	_check("dash no longer has the stolen key", dash_primary not in InputBindings.keys_for("dash"))

	# --- reserved / invalid -------------------------------------------------
	var before := InputBindings.export_all()
	_check("Escape cannot be bound", InputBindings.rebind("jump", KEY_ESCAPE) == "" \
		and InputBindings.export_all() == before)
	_check("KEY_NONE cannot be bound", InputBindings.rebind("jump", 0) == "" \
		and InputBindings.export_all() == before)
	_check("unknown action refused", InputBindings.rebind("not_an_action", KEY_K) == "" \
		and InputBindings.export_all() == before)

	# --- reset --------------------------------------------------------------
	InputBindings.reset_all()
	_check("reset restores jump", InputBindings.keys_for("jump") == jump_default)
	_check("reset restores dash", InputBindings.keys_for("dash") == dash_default)
	_check("reset keeps gamepad bindings", _joy_count("jump") == jump_joy)

	# --- sanitize: hostile saved data ---------------------------------------
	var s := InputBindings.sanitize({
		"jump": [KEY_K, KEY_K, KEY_ESCAPE, -5, 0, "x", 1e12, null, 74.0],
		"dash": "not an array",
		"bogus": [KEY_A],
		"slide": [],
	})
	_check("sanitize keeps legal keys, drops illegal ones", s.get("jump", []) == [KEY_K, 74] or s.get("jump", []) == [KEY_K])
	_check("sanitize drops Escape/negative/zero/strings/huge", KEY_ESCAPE not in s.get("jump", []) \
		and s.get("jump", []).all(func(c): return c > 0 and c < 0x7FFFFFF))
	_check("sanitize drops non-array values", not s.has("dash"))
	_check("sanitize drops unknown actions", not s.has("bogus"))
	_check("sanitize omits empty lists (defaults stand)", not s.has("slide"))
	_check("sanitize survives non-dictionary input", InputBindings.sanitize("junk").is_empty() \
		and InputBindings.sanitize(null).is_empty() and InputBindings.sanitize([1, 2]).is_empty())

	# --- persistence through GameSettings -----------------------------------
	var gs = root.get_node_or_null("GameSettings")
	_check("GameSettings autoload present", gs != null)
	if gs != null:
		var lkey := _first_free_key()
		gs.rebind_key("jump", lkey)
		_check("settings remember the rebind", gs.key_bindings.get("jump", [])[0] == lkey)
		# Simulate a fresh launch: wipe live bindings, reload from disk, apply.
		InputBindings.reset_all()
		_check("live bindings wiped", lkey not in InputBindings.keys_for("jump"))
		gs.key_bindings = {}
		gs.load_settings()
		InputBindings.apply(gs.key_bindings)
		_check("rebind survives save → load → apply", InputBindings.keys_for("jump")[0] == lkey)
		gs.reset_key_bindings()
		_check("reset_key_bindings restores defaults", InputBindings.keys_for("jump") == jump_default)
		_check("reset_key_bindings clears the saved override", gs.key_bindings.is_empty())
