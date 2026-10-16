extends Control
## 屏幕空间的小彩铅，笔尖对应实际点击位置。

var point := Vector2.ZERO
var tint := Color("545b48")
var strength := 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	# 短小的彩铅轮廓，左下笔尖就是实际点击位置。
	var side := Vector2(2.0, 2.0)
	var tip := point
	var wood := point + Vector2(5, -5)
	var end := point + Vector2(18, -18)
	draw_colored_polygon(PackedVector2Array([tip, wood - side, wood + side]), Color("9b8665") * Color(1, 1, 1, strength))
	draw_colored_polygon(PackedVector2Array([wood - side, end - side, end + side, wood + side]), Color("81906d") * Color(1, 1, 1, strength))
	draw_line(wood - side, end - side, Color(tint, strength), 1.0, true)
	draw_line(wood + side, end + side, Color(tint, strength), 1.0, true)
	draw_line(tip, tip + Vector2(2, -2), Color(tint, strength), 1.5, true)
