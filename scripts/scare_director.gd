class_name ScareDirector
extends CanvasLayer
## Harmless jump scares for machine levels. They follow the player's mistakes (a chip hit, a fall
## off the deck) and sometimes fire in a safe place as a feint. Every scare is CUED first, never
## fires near a precision section, never hides what is ahead (the face sits in a corner, the vignette
## is faint), and respects Spooky effects (FULL / REDUCED / OFF). See ScareRules for the limits.

signal cue_started(kind: String)
signal scared(kind: String)
signal cancelled(kind: String)

const KINDS := ["vent_face", "roar", "shadow"]
const FLASH_TINT := Color(0.62, 0.42, 1.0)

var rules: ScareRules = null
var machine: MachineRuntime = null
var player: Player = null
## Tests force the setting without GameSettings.
var forced_setting: int = -1
var history: Array = []     # [{kind, t}] for tests and telemetry

var _cue_left: float = 0.0
var _pending: String = ""
var _pending_trigger: String = ""
var _vignette: TextureRect
var _face: Control
var _shadow: ColorRect
var _was_on_deck: bool = false
var _feint_timer: float = 0.0
var _clock: float = 0.0


func _ready() -> void:
	layer = 90
	rules = ScareRules.new()
	_build()
	_refresh_mode()


func attach(p_machine: MachineRuntime, p_player: Player) -> void:
	machine = p_machine
	player = p_player
	if player != null and not player.damaged.is_connected(_on_damaged):
		player.damaged.connect(_on_damaged)
	if rules == null:
		rules = ScareRules.new()
	rules.on_level_start()


func _build() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(FLASH_TINT, 0.0))
	grad.set_color(1, Color(FLASH_TINT, 1.0))
	grad.offsets = PackedFloat32Array([0.55, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 1.0)
	tex.width = 256
	tex.height = 144
	_vignette = TextureRect.new()
	_vignette.texture = tex
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate.a = 0.0
	add_child(_vignette)
	_shadow = ColorRect.new()
	_shadow.color = Color(0.02, 0.0, 0.05, 0.9)
	_shadow.offset_top = 0.0
	_shadow.offset_bottom = 70.0
	_shadow.offset_left = -400.0
	_shadow.offset_right = -100.0
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow.modulate.a = 0.0
	add_child(_shadow)
	_face = _make_face()
	_face.modulate.a = 0.0
	add_child(_face)


## A pixel face with a wide grin, drawn in code (original art): dark head, two bright eyes.
func _make_face() -> Control:
	var face := Control.new()
	face.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	face.offset_left = -230.0
	face.offset_right = -30.0
	face.offset_top = 110.0
	face.offset_bottom = 310.0
	face.pivot_offset = Vector2(100.0, 100.0)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.draw.connect(func() -> void:
		var px := 10.0
		var dark := Color(0.04, 0.02, 0.08)
		var bright := Color(0.85, 0.8, 1.0)
		var rows: Array = [
			"..XXXXXXXXXX..",
			".XXXXXXXXXXXX.",
			"XXXXXXXXXXXXXX",
			"XXXEEXXXXEEXXX",
			"XXXEEXXXXEEXXX",
			"XXXXXXXXXXXXXX",
			"XXXXXXXXXXXXXX",
			"XXTXTXTXTXTXXX",
			"XXXTTTTTTTTXXX",
			".XXXXXXXXXXXX.",
			"..XXXXXXXXXX..",
		]
		for y in rows.size():
			var row: String = rows[y]
			for x in row.length():
				var ch := row[x]
				var r := Rect2(float(x) * px + 10.0, float(y) * px + 30.0, px, px)
				if ch == "X":
					face.draw_rect(r, dark)
				elif ch == "E" or ch == "T":
					face.draw_rect(r, bright))
	return face


func _setting() -> int:
	if forced_setting >= 0:
		return forced_setting
	var gs := get_node_or_null("/root/GameSettings")
	var s := 0
	var reduce := false
	if gs != null:
		s = int(gs.get_reg("gp_spooky"))
		reduce = not bool(gs.death_flash)
	return ScareRules.effective_mode(s, reduce)


func _refresh_mode() -> void:
	if rules != null:
		rules.mode = _setting()


func _physics_process(delta: float) -> void:
	_clock += delta
	if rules == null:
		return
	rules.tick(delta)
	_refresh_mode()
	if _cue_left > 0.0:
		_cue_left -= delta
		if _cue_left <= 0.0:
			_pop()
		return
	if player == null or not is_instance_valid(player):
		return
	# A fall from the deck to the floor lane is a mistake worth a scare.
	var feet := player.global_position.y + MachineSim.HALF.y
	var on_deck := player.is_on_floor() and absf(feet - MachinePieces.DECK_Y) < 6.0
	var on_floor_lane := player.is_on_floor() and absf(feet - MachinePieces.FLOOR_Y) < 6.0
	if _was_on_deck and on_floor_lane and machine != null and not machine.spec.is_empty():
		_try("mistake")
	if player.is_on_floor():
		_was_on_deck = on_deck
	# A feint now and then in a calm place.
	_feint_timer += delta
	if _feint_timer >= 5.0:
		_feint_timer = 0.0
		_try("feint")


func on_respawn() -> void:
	if rules != null:
		rules.on_respawn()
	_cancel_effects()
	_cue_left = 0.0
	_pending = ""
	_was_on_deck = false


func _on_damaged(_hp: int) -> void:
	_try("mistake")


func precision_near() -> bool:
	if machine == null or player == null or machine.spec.is_empty():
		return false
	var x := player.global_position.x
	for cell in machine.spec["cells"]:
		if absf(float(cell["x"]) + 260.0 - x) > 900.0:
			continue
		for p in MachinePieces.cell_pieces(cell):
			if not p.has("x") or String(p["k"]) in ["plain", "deck", "none"]:
				continue
			var span := MachinePieces.span_of(p)
			if span[1] > x - 120.0 and span[0] < x + 460.0:
				return true
	return false


func _try(trigger: String) -> void:
	if rules == null or _cue_left > 0.0:
		return
	if not rules.may_fire(trigger, precision_near()):
		return
	fire(trigger)


## Start a scare now (rules already checked, or forced by a test).
func fire(trigger: String, kind: String = "") -> void:
	_pending_trigger = trigger
	_pending = kind if kind != "" else KINDS[rules.rng.randi_range(0, KINDS.size() - 1)]
	_cue_left = ScareRules.CUE_TIME
	cue_started.emit(_pending)
	# The cue: a low hiss and a faint violet breath at the edge of the screen.
	SfxHub.play(get_tree(), "vent")
	_pulse(_vignette, 0.10, 0.12, 0.30)


func _pop() -> void:
	var kind := _pending
	_pending = ""
	# The player walked into something hard during the cue: let it go unseen.
	if _pending_trigger != "forced" and precision_near():
		cancelled.emit(kind)
		return
	var mode := rules.mode
	if mode == ScareRules.Mode.OFF:
		cancelled.emit(kind)
		return
	rules.fired()
	history.append({"kind": kind, "t": _clock})
	var soft := mode == ScareRules.Mode.REDUCED
	var audio := get_tree().get_first_node_in_group("level_audio")
	if audio != null and audio.has_method("play_scare"):
		audio.play_scare(soft)
	match kind:
		"vent_face":
			_show_face(soft)
		"roar":
			if not soft:
				_pulse(_vignette, ScareRules.FLASH_MAX_ALPHA, 0.08, 0.35)
				_shake()
			else:
				_pulse(_vignette, 0.12, 0.15, 0.4)
		"shadow":
			_run_shadow(soft)
	scared.emit(kind)


func _pulse(node: CanvasItem, peak: float, rise: float, fall: float) -> void:
	var t := create_tween()
	t.tween_property(node, "modulate:a", peak, rise)
	t.tween_property(node, "modulate:a", 0.0, fall)


func _show_face(soft: bool) -> void:
	_face.queue_redraw()
	_face.scale = Vector2.ONE if soft else Vector2(0.7, 0.7)
	var t := create_tween()
	t.tween_property(_face, "modulate:a", 1.0, 0.18 if soft else 0.06)
	if not soft:
		t.parallel().tween_property(_face, "scale", Vector2.ONE, 0.12)
	t.tween_interval(0.45)
	t.tween_property(_face, "modulate:a", 0.0, 0.3)


func _run_shadow(soft: bool) -> void:
	var vw := get_viewport().get_visible_rect().size.x
	_shadow.offset_left = -400.0
	_shadow.offset_right = -100.0
	_shadow.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_shadow, "modulate:a", 0.5 if soft else 0.9, 0.15)
	t.parallel().tween_property(_shadow, "offset_left", vw + 100.0, 0.7)
	t.parallel().tween_property(_shadow, "offset_right", vw + 400.0, 0.7)
	t.tween_property(_shadow, "modulate:a", 0.0, 0.1)


func _shake() -> void:
	if player == null:
		return
	var shake := player.get_node_or_null("CameraShake")
	if shake != null and shake.has_method("add_trauma"):
		shake.add_trauma(0.25)


func _cancel_effects() -> void:
	for n in [_vignette, _face, _shadow]:
		if n != null:
			(n as CanvasItem).modulate.a = 0.0
