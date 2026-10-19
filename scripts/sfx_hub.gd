class_name SfxHub
extends RefCounted
## One call for "play this effect" from anything that is not the level controller: finds the
## level's audio node and asks it. Silent (and harmless) when there is none, as in tests.

static func play(tree: SceneTree, effect: String) -> void:
	if tree == null:
		return
	var audio := tree.get_first_node_in_group("level_audio")
	if audio == null:
		return
	var method := "play_" + effect
	if audio.has_method(method):
		audio.call(method)
