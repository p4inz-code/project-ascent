class_name AudioFx
extends RefCounted
## Audio buses and effects driven by GameSettings, kept apart from the per-level
## GameAudio node so they work on the title screen and in menus too.
##
##   Buses       Master > Music, SFX, UI (menu clicks and cues)
##   Room echo   a reverb on the SFX bus (0 = dry)
##   Night mode  a compressor on Master: loud bits quieter, quiet bits clearer
##   Muffle      a low-pass on Master, switched on while the pause menu is open
##
## Every function is safe to call repeatedly: effects are found by type, added
## once, and only ever toggled or retuned afterwards.

const UI_BUS := "UI"
const MUFFLE_CUTOFF := 1400.0


static func ensure_bus(bus_name: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		return idx
	AudioServer.add_bus()
	idx = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")
	return idx


static func ensure_buses() -> void:
	ensure_bus("Music")
	ensure_bus("SFX")
	ensure_bus(UI_BUS)


## Index of the first effect of this class on a bus, adding one if missing.
static func _effect(bus: int, cls: String, factory: Callable) -> int:
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i).get_class() == cls:
			return i
	AudioServer.add_bus_effect(bus, factory.call())
	return AudioServer.get_bus_effect_count(bus) - 1


static func apply(settings: Node) -> void:
	if settings == null:
		return
	ensure_buses()
	var ui := AudioServer.get_bus_index(UI_BUS)
	AudioServer.set_bus_volume_db(ui, linear_to_db(clampf(float(settings.ui_volume), 0.0001, 1.0)))
	AudioServer.set_bus_mute(ui, float(settings.ui_volume) <= 0.001)

	# Room echo on SFX.
	var sfx := AudioServer.get_bus_index("SFX")
	var rv := _effect(sfx, "AudioEffectReverb", func():
		var r := AudioEffectReverb.new()
		r.room_size = 0.55
		r.damping = 0.45
		r.dry = 1.0
		return r)
	var reverb := AudioServer.get_bus_effect(sfx, rv) as AudioEffectReverb
	reverb.wet = clampf(float(settings.audio_room_echo), 0.0, 1.0) * 0.5
	AudioServer.set_bus_effect_enabled(sfx, rv, float(settings.audio_room_echo) > 0.01)

	# Night mode: compress the dynamic range on the master bus.
	var comp_i := _effect(0, "AudioEffectCompressor", func():
		var c := AudioEffectCompressor.new()
		c.threshold = -20.0
		c.ratio = 4.0
		c.gain = 4.0
		return c)
	AudioServer.set_bus_effect_enabled(0, comp_i, bool(settings.audio_night_mode))

	# The muffle filter exists disabled; set_paused_muffle() flips it.
	_effect(0, "AudioEffectLowPassFilter", func():
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = MUFFLE_CUTOFF
		return lp)
	set_muffled(false)


## Switch the pause-menu muffle on or off.
static func set_muffled(on: bool) -> void:
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectLowPassFilter:
			AudioServer.set_bus_effect_enabled(0, i, on)


static func is_muffled() -> bool:
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectLowPassFilter:
			return AudioServer.is_bus_effect_enabled(0, i)
	return false
