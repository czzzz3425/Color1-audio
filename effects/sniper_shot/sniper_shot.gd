class_name SniperShot
extends Node2D
## 狙击开火瞬间的枪口光束 + 光斑，快速淡出后自毁。

var color := Color(0.45, 0.75, 1.0, 1.0)
var length := 1800.0
var life := 0.14

var _age := 0.0


func setup(dir: Vector2, c: Color, beam_length: float) -> void:
	var d := dir.normalized()
	rotation = (d if d != Vector2.ZERO else Vector2.RIGHT).angle()
	color = c
	length = beam_length
	queue_redraw()


func _ready() -> void:
	z_index = 4
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	var k := clampf(_age / maxf(life, 0.01), 0.0, 1.0)
	modulate.a = 1.0 - k
	if _age >= life:
		queue_free()


func _draw() -> void:
	var k := clampf(_age / maxf(life, 0.01), 0.0, 1.0)
	var glow := Color(color.r, color.g, color.b, 0.4 * (1.0 - k))
	var core := Color(1.0, 1.0, 1.0, 0.95 * (1.0 - k))
	draw_line(Vector2.ZERO, Vector2(length, 0), glow, 18.0, true)
	draw_line(Vector2.ZERO, Vector2(length * (0.35 + 0.65 * (1.0 - k)), 0), core, 5.0, true)
	draw_circle(Vector2.ZERO, 18.0 + 34.0 * k, Color(color.r, color.g, color.b, 0.5 * (1.0 - k)))
	draw_circle(Vector2.ZERO, 8.0, Color(1.0, 1.0, 1.0, 0.9 * (1.0 - k)))
