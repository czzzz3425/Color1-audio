class_name SniperSight
extends Node2D
## 狙击瞄准镜：细亮核心线 + 外层辉光 + 流动虚线 + 末端十字准星。
## 用射线把瞄准线截断在墙体前，避免“穿墙瞄准”误导玩家。

var color := Color(0.45, 0.75, 1.0, 0.9)
var max_length := 4000.0
var glow_width := 22.0
var core_width := 4.0

var _dir := Vector2.RIGHT
var _length := 0.0
var _locked := false
var _t := 0.0
var _refresh_cd := 0.0


func configure(c: Color, length: float) -> void:
	color = c
	max_length = length


func show_sight(dir: Vector2, length: float = -1.0) -> void:
	var d := dir.normalized()
	_dir = d if d != Vector2.ZERO else Vector2.RIGHT
	if length > 0.0:
		max_length = length
	rotation = _dir.angle()
	visible = true
	_update_length()
	queue_redraw()


func hide_sight() -> void:
	visible = false
	_locked = false
	queue_redraw()


func set_locked(value: bool) -> void:
	if _locked != value:
		_locked = value
		queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_refresh_cd -= delta
	if _refresh_cd <= 0.0:
		_refresh_cd = 0.05
		_update_length()
	queue_redraw()


func _update_length() -> void:
	var from := global_position
	var to := from + _dir * max_length
	var query := PhysicsRayQueryParameters2D.create(from, to, 2)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	_length = max_length if hit.is_empty() else from.distance_to(hit["position"])


func _draw() -> void:
	if _length <= 1.0:
		return
	var pulse := 0.65 + 0.35 * sin(_t * 8.0)
	var glow := Color(color.r, color.g, color.b, 0.16 * pulse)
	var core := Color(0.95, 0.98, 1.0, 0.95) if _locked else Color(color.r, color.g, color.b, 0.95)
	draw_line(Vector2.ZERO, Vector2(_length, 0), glow, glow_width)
	draw_line(Vector2.ZERO, Vector2(_length, 0), core, core_width)

	var dash_step := 92.0
	var dash_len := 44.0
	var x := fmod(_t * 300.0, dash_step)
	while x < _length:
		var x2 := minf(x + dash_len, _length)
		draw_line(Vector2(x, 0), Vector2(x2, 0), Color(1.0, 1.0, 1.0, 0.55 * pulse), 2.0)
		x += dash_step

	var tip := Vector2(_length, 0)
	var ring := Color(color.r, color.g, color.b, 0.9)
	draw_arc(tip, 18.0, 0.0, TAU, 32, ring, 2.0, true)
	draw_line(tip + Vector2(-30, 0), tip + Vector2(-11, 0), ring, 2.0, true)
	draw_line(tip + Vector2(11, 0), tip + Vector2(30, 0), ring, 2.0, true)
	draw_line(tip + Vector2(0, -30), tip + Vector2(0, -11), ring, 2.0, true)
	draw_line(tip + Vector2(0, 11), tip + Vector2(0, 30), ring, 2.0, true)
	if _locked:
		draw_circle(tip, 6.0, Color(1.0, 1.0, 1.0, 0.95))
