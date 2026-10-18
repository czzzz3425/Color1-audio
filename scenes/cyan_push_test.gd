extends Node2D
## 青色推动测试：开局给玩家蓝+绿种子，树变青后可推动到压力板。


func _ready() -> void:
	var player := get_node_or_null("Player")
	if player != null and player.has_method("receive_element"):
		player.call("receive_element", "freeze", 3)
		player.call("receive_element", "grow", 3)
