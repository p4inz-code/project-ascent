# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
class_name PageFx
extends RefCounted
## The shared feel of every menu page: the frame pops in, its rows arrive one after another, and every button
## answers the pointer and the keyboard (a lit edge bar grows in, the face brightens, a press squashes). Nothing
## moves the button itself, so container layouts are never disturbed. One place, so all pages behave alike.
## Tweens process while the tree is paused (menus pause the game). Background motion off keeps pages still:
## only the colour feedback remains.


static func calm(node: Node) -> bool:
	var gs := node.get_node_or_null("/root/GameSettings") if node.is_inside_tree() else null
	return gs != null and not bool(gs.get("bg_motion"))


## Animate a page frame in and make every button under it interactive. Call once the page is built and in the
## tree. `rows`: the container whose children arrive one by one (optional).
static func enter(frame: Control, rows: Node = null) -> void:
	if frame == null or not frame.is_inside_tree():
		return
	watch(frame)
	if calm(frame):
		return
	frame.modulate.a = 0.0
	var t := frame.create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(frame, "modulate:a", 1.0, 0.2)
	if rows == null:
		return
	var i := 0
	for r in rows.get_children():
		var c := r as Control
		if c == null or not c.visible:
			continue
		c.modulate.a = 0.0
		var rt := c.create_tween()
		rt.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		rt.tween_interval(0.06 + 0.05 * float(i))
		rt.tween_property(c, "modulate:a", 1.0, 0.18)
		i += 1


## Make every button under `root_node` interactive, including buttons added later (settings tabs, pause views).
static func watch(root_node: Node) -> void:
	if root_node == null or not root_node.is_inside_tree() or root_node.has_meta("pagefx_watch"):
		return
	root_node.set_meta("pagefx_watch", true)
	for b in root_node.find_children("*", "Button", true, false):
		hoverable(b as Button)
	var tree := root_node.get_tree()
	var on_added := func(n: Node) -> void:
		if n is Button and is_instance_valid(root_node) and root_node.is_ancestor_of(n):
			hoverable.call_deferred(n as Button)
	tree.node_added.connect(on_added)
	root_node.tree_exiting.connect(func() -> void:
		if tree.node_added.is_connected(on_added):
			tree.node_added.disconnect(on_added))


## Pointer and focus feedback for one button.
static func hoverable(b: Button) -> void:
	if b == null or not is_instance_valid(b) or b.has_meta("pagefx"):
		return
	b.set_meta("pagefx", true)
	var bar := ColorRect.new()
	bar.name = "FxBar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.color = UITheme.accent
	bar.position = Vector2.ZERO
	bar.size = Vector2(0, 0)
	b.add_child(bar)
	var show := func(lit: bool) -> void:
		if not is_instance_valid(bar):
			return
		bar.size.y = b.size.y
		b.self_modulate = Color(1.15, 1.15, 1.22) if lit else Color.WHITE
		var target := 6.0 if lit else 0.0
		if calm(b):
			bar.size.x = target
			return
		var t := bar.create_tween()
		t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t.tween_property(bar, "size:x", target, 0.09)
	b.mouse_entered.connect(func() -> void: show.call(true))
	b.focus_entered.connect(func() -> void: show.call(true))
	b.mouse_exited.connect(func() -> void: show.call(b.has_focus()))
	b.focus_exited.connect(func() -> void: show.call(b.is_hovered()))
	b.pressed.connect(func() -> void:
		if calm(b):
			return
		b.pivot_offset = b.size * 0.5
		var t := b.create_tween()
		t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t.tween_property(b, "scale", Vector2(0.97, 0.97), 0.04)
		t.tween_property(b, "scale", Vector2.ONE, 0.08))
