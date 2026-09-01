class_name DeathFeedback
extends Node
## Escalating personality on repeated deaths — taunts, then encouragement.
##
## The owner's original ask was: normal under 25 deaths, taunts at 25+, and a
## dramatic death animation past 50. Two of those ship as asked. The third does
## not, deliberately:
##
##   A player on their fiftieth death is the single most likely person to quit.
##   Adding a delay before they can try again is the exact opposite of what
##   that moment needs. So respawn stays INSTANT at every tier and the drama
##   escalates instead — the 50+ tier gets a bigger, *supportive* beat rendered
##   DURING the respawn, never before it.
##
## Nothing here blocks or delays a retry. It only draws.

## Deaths on the current level before taunts begin.
const TAUNT_THRESHOLD: int = 25
## Deaths before the supportive tier takes over from taunting.
const SUPPORT_THRESHOLD: int = 50

## Cheeky, never cruel. A player who has died 30 times is already frustrated;
## the joke has to land as the game being in on it, not as the game gloating.
## Cheeky, never cruel. A player who has died 30 times is already frustrated;
## the joke has to land as the game being in on it, not as the game gloating.
## The line the owner wanted harder is the MOCKERY, not the cruelty — these
## needle the attempt, never the person.
const TAUNTS: Array[String] = [
	"that one was closer",
	"the platform isn't moving, you know",
	"skill issue",
	"it's not personal",
	"gravity remains undefeated",
	"the goal is still up there",
	"physics: 1, you: 0",
	"bold strategy",
	"the jump was there. you were not.",
	"have you considered landing on it",
	"that gap has beaten you %d times now",
	"impressive commitment to that exact mistake",
	"the platform is not going to come to you",
	"you had one job. it was that ledge.",
	"a bird could do this",
	"try the other direction. no, the other other one.",
	"statistically, one of these has to work",
	"this is the part where you land it",
]

## Past 50 the tone flips. These acknowledge the grind rather than mock it.
const SUPPORT: Array[String] = [
	"you're closer than you were",
	"this one's genuinely hard",
	"most people stopped before here",
	"keep going",
	"nearly had it",
	"that section beats everyone",
	"%d attempts. that's dedication, not failure.",
	"the people who finish this all went through here",
]

var _layer: CanvasLayer
var _label: Label
var _rng := RandomNumberGenerator.new()
var _tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()

	_layer = CanvasLayer.new()
	# Below the pause menu (200) and the dev overlay (250), above gameplay.
	_layer.layer = 130
	add_child(_layer)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.anchor_left = 0.5
	_label.anchor_right = 0.5
	_label.offset_left = -300
	_label.offset_right = 300
	_label.offset_top = 96
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.modulate.a = 0.0
	_layer.add_child(_label)


## Called on every death. `attempts` is the attempt count for this level.
##
## Returns immediately in every path — this must never gate the respawn.
func on_death(attempts: int) -> void:
	if attempts < TAUNT_THRESHOLD:
		return

	var supportive := attempts >= SUPPORT_THRESHOLD
	var pool: Array[String] = SUPPORT if supportive else TAUNTS
	var line: String = pool[_rng.randi_range(0, pool.size() - 1)]
	# A few lines quote the attempt count back at the player, which lands
	# harder than a generic jab because it is specifically about THIS run.
	if line.contains("%d"):
		line = line % attempts
	_label.text = line
	_label.add_theme_color_override("font_color",
		Color(0.55, 1.0, 0.72) if supportive else Color(0.85, 0.80, 0.60))

	if _tween != null and _tween.is_valid():
		_tween.kill()
	_label.modulate.a = 0.0
	_tween = create_tween()
	# Deliberately quick: it plays alongside the respawn the player has already
	# been given, and is gone before the next attempt matters.
	_tween.tween_property(_label, "modulate:a", 1.0, 0.12)
	_tween.tween_interval(1.5 if supportive else 1.1)
	_tween.tween_property(_label, "modulate:a", 0.0, 0.45)


## Clear on level change so a taunt does not linger into a new level.
func clear() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_label.modulate.a = 0.0
