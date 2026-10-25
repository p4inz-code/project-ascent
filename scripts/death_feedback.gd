class_name DeathFeedback
extends Node
## PIP's reaction to deaths (STRONG mode) and to clears. Nothing here blocks or delays a retry: it only
## draws, in the corner, while the player is already back in control (respawn stays instant).
##
## STRONG: escalating roasts (see TauntLines: five tiers by deaths this level, harsher sooner on hard
## levels, tier 5 climbs forever), built so the long sufferers get flexed on ("everyone else quit before
## this") and a clear gets a loud celebration. WEAK: no taunts, no brag lines, nothing. Language BLEEPED
## stars out the swearing. Lines never repeat within 20 deaths and never come closer than 4 s.

const MIN_GAP_MS := 4000
const REPEAT_MEMORY := 20
const T1_CHANCE := 0.34

var level: int = 1
## What killed the player ("spikes", "fall", "lava", "fire", "crusher", "chase", "enemy", "ice"), or "".
var cause: String = ""
## Progress at death in percent, or -1.
var progress_pct: float = -1.0
## Where the player died (world x), to notice dying in the same spot again and again.
var death_x: float = 0.0

var last_line: String = ""
var lines_shown: int = 0

var _layer: CanvasLayer
var _label: Label
var _rng := RandomNumberGenerator.new()
var _tween: Tween = null
var _recent: Array = []
var _last_ms: int = -100000
var _last_x: float = -1e9
var _same_spot_run: int = 0
## Tests set this to bypass the 4 s gap and GameSettings.
var forced_mode: int = -1
var forced_language: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_layer = CanvasLayer.new()
	_layer.layer = 130
	add_child(_layer)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.anchor_left = 0.5
	_label.anchor_right = 0.5
	_label.offset_left = -330
	_label.offset_right = 330
	_label.offset_top = 96
	_label.add_theme_font_size_override("font_size", UITheme.sz(22))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.modulate.a = 0.0
	_layer.add_child(_label)


func _mode() -> int:
	if forced_mode >= 0:
		return forced_mode
	var gs := get_node_or_null("/root/GameSettings")
	return int(gs.get_reg("gp_mode")) if gs != null else 0


func _bleeped() -> bool:
	if forced_language >= 0:
		return forced_language == 1
	var gs := get_node_or_null("/root/GameSettings")
	return gs != null and int(gs.get_reg("gp_language")) == 1


## Called on every death. `attempts` is the death count for this level session. Returns at once.
func on_death(attempts: int) -> void:
	if _mode() != 0:
		return
	# the same spot again and again
	if absf(death_x - _last_x) < 220.0:
		_same_spot_run += 1
	else:
		_same_spot_run = 0
	_last_x = death_x
	var now := Time.get_ticks_msec()
	if forced_mode < 0 and now - _last_ms < MIN_GAP_MS:
		return
	var tier := TauntLines.tier_for(attempts, level)
	if tier == 1 and _rng.randf() > T1_CHANCE and attempts > 1:
		return
	var pool := TauntLines.pool_for(tier, cause, progress_pct, _same_spot_run >= 2)
	# no repeats within the last 20 lines
	# (a pool smaller than 20 lines can only avoid repeats for pool-size-minus-one deaths)
	var window := mini(REPEAT_MEMORY, pool.size() - 1)
	var recent_window: Array = _recent.slice(maxi(0, _recent.size() - window)) if window > 0 else []
	var fresh: Array = []
	for l in pool:
		if not (l in recent_window):
			fresh.append(l)
	if fresh.is_empty():
		fresh = pool
	var raw: String = fresh[_rng.randi_range(0, fresh.size() - 1)]
	_recent.append(raw)
	while _recent.size() > REPEAT_MEMORY:
		_recent.pop_front()
	_show(TauntLines.fill(raw, attempts, progress_pct), _tier_color(tier), 1.2 + 0.2 * float(tier))
	_last_ms = now


## A clear is the ego payoff: shown big, gold, a little longer.
func on_clear(attempts: int, boss: bool) -> void:
	if _mode() != 0:
		return
	var line := TauntLines.clear_line(attempts, level, boss)
	_show(TauntLines.fill(line, attempts, -1.0), Color(1.0, 0.86, 0.38), 3.0)
	_same_spot_run = 0
	_last_x = -1e9


func _tier_color(tier: int) -> Color:
	match tier:
		1:
			return Color(0.75, 0.78, 0.85)
		2:
			return Color(0.85, 0.80, 0.60)
		3:
			return Color(0.95, 0.72, 0.45)
		4:
			return Color(1.0, 0.60, 0.40)
		_:
			return Color(1.0, 0.50, 0.35)


func _show(text: String, color: Color, hold: float) -> void:
	if _bleeped():
		text = TauntLines.bleep(text)
	last_line = text
	lines_shown += 1
	_label.text = text
	_label.add_theme_color_override("font_color", color)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_label.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_label, "modulate:a", 1.0, 0.12)
	_tween.tween_interval(hold)
	_tween.tween_property(_label, "modulate:a", 0.0, 0.45)


## Clear on level change so a line does not linger into a new level.
func clear() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_label.modulate.a = 0.0
	_same_spot_run = 0
	_last_x = -1e9
	_recent.clear()
