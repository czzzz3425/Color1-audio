class_name Checkpoint
extends Area2D
## 存档点：玩家进入触发区，即把「当前场景 + 本节点位置」写入存档。
## 死亡后复活会优先回到最近的存档点；主菜单「继续游戏」也从这里进入。

@export var checkpoint_id: String = ""


func _ready() -> void:
	add_to_group("checkpoint")
	collision_layer = 0
	collision_mask = 1   # 只检测玩家（层 1）
	body_entered.connect(_on_body_entered)
	# 占位色块只在编辑器里可见，游戏运行时隐藏。
	var visual := get_node_or_null("Visual")
	if visual != null:
		visual.visible = false


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_activate()


func _activate() -> void:
	GameState.set_checkpoint(SceneManager.current_room_scene, global_position)
	GameState.notice.emit("已记录存档点")
