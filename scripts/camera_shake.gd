class_name CameraShake
extends Node
## Trauma-based camera shake for the player's Camera2D.
##
## Added this phase because the `screen_shake` setting had shipped since v0.5
## with nothing reading it — the toggle existed in the pause menu and in
## settings.json, but no code anywhere shook anything. Rather than delete the
## setting, this makes it real, and gives the new Screen Shake intensity dial
## something to scale.
##
## Trauma-based rather than a fixed timed wobble: `add_trauma()` accumulates,
## and the offset uses trauma squared so small bumps stay subtle while a
## death reads as a real hit. Decays continuously, so overlapping events
## blend instead of restarting each other.

## Largest offset in pixels at full trauma.
##
## Raised from 22 to 64 after measurement: a death peaked at 7.4px on a 1080p
## screen, which is a rounding error rather than an impact, and the effect was
## reported as doing nothing at all. Because the offset scales with trauma
## SQUARED, a death (trauma 0.85) measures ~27px of actual peak displacement
## while the small landing bumps stay subtle. The headline number looks large
## because the noise function rarely drives both axes to their extremes at
## once — measured peak is roughly a quarter of max_offset.
@export var max_offset: float = 110.0
## Largest rotation in radians at full trauma. Deliberately small — a
## precision platformer must never lose the reading of "is that platform
## level", so this is a hint of roll, not a tilt.
@export var max_roll: float = 0.055
## Trauma lost per second. Raised alongside max_offset so the bigger throw
## still settles fast — a shake that lingers would fight the next attempt in a
## game where retries are near-instant.
@export var decay: float = 2.0
## Noise sampling rate. Higher is buzzier, lower is a slower sway.
@export var frequency: float = 24.0

var _camera: Camera2D = null
var _trauma: float = 0.0
var _time: float = 0.0
var _settings: Node = null
var _noise_seed: float = 0.0


func _ready() -> void:
	# Must keep ticking while the tree is paused so a shake in progress when
	# the player opens the pause menu settles rather than freezing mid-offset.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_settings = get_node_or_null("/root/GameSettings")
	_camera = get_parent().get_node_or_null("Camera2D") as Camera2D
	# Vary the noise phase per instance so a restart doesn't reproduce the
	# exact same shake pattern. Deterministic sources only — Time is fine
	# here because nothing about the shake is gameplay-affecting.
	_noise_seed = float(Time.get_ticks_msec() % 10000) * 0.001


## Add trauma in 0..1. Callers pass intent ("this was a death") and let the
## intensity setting scale it, rather than each caller doing that maths.
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	if _camera == null:
		return
	if _trauma <= 0.0:
		# Only clear once, rather than fighting anything else that might want
		# to own the camera offset while no shake is active.
		if _camera.offset != Vector2.ZERO or _camera.rotation != 0.0:
			_camera.offset = Vector2.ZERO
			_camera.rotation = 0.0
		return

	_time += delta * frequency
	_trauma = maxf(_trauma - decay * delta, 0.0)

	var scale_factor := _intensity()
	if scale_factor <= 0.0:
		_camera.offset = Vector2.ZERO
		_camera.rotation = 0.0
		return

	# Squared trauma: gentle events stay gentle, big ones bite.
	var shake := _trauma * _trauma * scale_factor
	_camera.offset = Vector2(
		_noise(0.0) * max_offset * shake,
		_noise(37.0) * max_offset * shake)
	_camera.rotation = _noise(71.0) * max_roll * shake


## Cheap deterministic 1D value noise. A full FastNoiseLite instance is more
## than this needs, and sin-based pseudo-noise reads as a regular wobble
## rather than a shake.
func _noise(offset: float) -> float:
	var t := _time + offset + _noise_seed
	var i := floorf(t)
	var f := t - i
	# Smoothstep between two hashed values.
	var a := _hash(i)
	var b := _hash(i + 1.0)
	return lerpf(a, b, f * f * (3.0 - 2.0 * f))


func _hash(n: float) -> float:
	var x := sin(n * 127.1) * 43758.5453
	return (x - floorf(x)) * 2.0 - 1.0


## Combined on/off toggle and intensity dial. The old boolean still wins when
## it is off, so an existing settings.json that disabled shake stays disabled
## after this update rather than surprising the player with a new effect.
func _intensity() -> float:
	if _settings == null:
		return 1.0
	if "screen_shake" in _settings and not _settings.screen_shake:
		return 0.0
	if "shake_intensity" in _settings:
		return clampf(_settings.shake_intensity, 0.0, 1.0)
	return 1.0
