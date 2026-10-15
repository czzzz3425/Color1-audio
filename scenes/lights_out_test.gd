extends Node2D
## Lights Out 测试场景控制器：开局给玩家 10 颗红种子，方便直接测试点灯。


func _ready() -> void:
	var player := get_node_or_null("Player")
	if player != null and player.has_method("receive_element"):
		player.call("receive_element", "burn", 10)
