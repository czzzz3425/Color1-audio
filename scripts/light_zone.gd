class_name LightZone
extends Area2D
## 亮区触发：玩家进入时把暗房遮罩缓慢淡出（全亮），离开时缓慢淡入（全黑）。
## 放在暗房内部某个「应该变亮」的区域即可。

@export var fade_time := 0.6

var _overlay: DarknessOverlay
var _tween: Tween


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1   # 只检测玩家
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_set_darkness(0.0)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_set_darkness(1.0)


func _set_darkness(target: float) -> void:
	if _overlay == null or not is_instance_valid(_overlay):
		_overlay = get_tree().get_first_node_in_group("darkness") as DarknessOverlay
	if _overlay == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_overlay, "darkness", target, fade_time)
