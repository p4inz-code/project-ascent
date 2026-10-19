class_name LevelHint
extends Node2D
## A teaching sign that lives in the world. It fades in as the player comes
## within `radius` and fades back out as they leave, so a verb is taught where
## it is first needed and costs no screen space anywhere else.
##
## Purely visual: no collision, no signals, nothing here can affect play.

@export var text: String = ""
@export var radius: float = 320.0

const FADE_SPEED: float = 5.0

var _label: Label
var _panel: PanelContainer
var _player: Node2D = null


func _ready() -> void:
	z_as_relative = false
	z_index = 3
	_panel = PanelContainer.new()
	_panel.theme = UITheme.build()
	_panel.modulate.a = 0.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.text = text
	_label.add_theme_font_size_override("font_size", UITheme.sz(24))
	_label.add_theme_color_override("font_color", UITheme.AMBER)
	_panel.add_child(_label)
	add_child(_panel)
	# Centre the panel on this node once it has its real size.
	_panel.resized.connect(func(): _panel.position = -_panel.size * 0.5)
	_panel.reset_size()


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
		if _player == null:
			return
	var d := global_position.distance_to(_player.global_position)
	var want := 1.0 if d <= radius else 0.0
	_panel.modulate.a = move_toward(_panel.modulate.a, want, delta * FADE_SPEED)


func _find_player() -> Node2D:
	var level := get_parent()
	while level != null and level.get_node_or_null("Player") == null:
		level = level.get_parent()
	return level.get_node_or_null("Player") as Node2D if level != null else null


## True while the sign is meaningfully visible; read by tests.
func is_shown() -> bool:
	return _panel != null and _panel.modulate.a > 0.5
