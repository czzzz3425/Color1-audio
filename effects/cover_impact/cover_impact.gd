class_name CoverImpact
extends Node2D
## 子弹撞到墙/掩体时的短促火花，提供“这一发被挡住了”的明确反馈。

var life := 0.16
var _age := 0.0
var _dir := Vector2.RIGHT


func setup(dir: Vector2) -> void:
	var d := dir.normalized()
	_dir = d if d != Vector2.ZERO else Vector2.RIGHT
	queue_redraw()


func _ready() -> void:
	z_index = 6
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := clampf(_age / maxf(life, 0.01), 0.0, 1.0)
	var fade := 1.0 - k
	var base := (-_dir).angle()
	for i in 5:
		var a := base + float(i - 2) * 0.34
		var length := (14.0 + float(i) * 5.0) * (0.55 + 0.45 * fade)
		var c := Color(1.0, 0.86, 0.45, fade)
		draw_line(Vector2.ZERO, Vector2.from_angle(a) * length, c, 3.0 * fade, true)
	draw_circle(Vector2.ZERO, 2.0 + 10.0 * fade, Color(1.0, 0.95, 0.75, 0.35 * fade))
