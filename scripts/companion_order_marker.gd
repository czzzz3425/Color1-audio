extends Node2D
## 实际目标旁的铅笔标记；工作中为实色，预存的下一步为浅色。
var target: WeakRef
var tint := Color("657853")
var queued := false
var _time := 0.0

func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 4095

func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target.get_ref()) or not target.get_ref().is_inside_tree():
		queue_free()
		return
	_time += delta
	global_position = target.get_ref().global_position
	queue_redraw()

func _draw() -> void:
	var color := Color(tint, 0.4 if queued else 0.75)
	var radius := 55.0 + sin(_time * 2.5) * 3.0
	for offset in [0.0, PI]:
		draw_arc(Vector2.ZERO, radius, offset - 0.55, offset + 0.55, 10, color, 5.0, true)
	draw_line(Vector2(-12, -radius - 10), Vector2(0, -radius - 22), color, 4.0, true)
	draw_line(Vector2(0, -radius - 22), Vector2(16, -radius - 8), color, 4.0, true)
