class_name Dart
extends Area2D
## A shooter's projectile. A slash deflects it back along the way it came (see PlayerAttack);
## a deflected dart kills any enemy it meets.

var shooter: Node = null


func _ready() -> void:
	collision_mask = PlayerAttack.SLASH_LAYER | 1
	area_entered.connect(_on_area_entered)


func slash_hit(dir: Vector2, _attacker: Node) -> void:
	if has_meta("deflected") or shooter == null or not shooter.has_method("deflect"):
		return
	shooter.deflect(self, dir)


func _on_area_entered(area: Area2D) -> void:
	if not has_meta("deflected"):
		return
	var enemy := area.get_parent()
	if enemy != null and enemy.is_in_group("enemy") and enemy.has_method("slash_hit"):
		enemy.slash_hit(Vector2.ZERO, null)
