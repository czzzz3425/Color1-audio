class_name RangeIndicator
extends Node2D
## 玩家「工作圈」可视化：以玩家为圆心、interact_range 为半径的 q 版虚线圆。
## 平时隐藏；当鼠标移到工作圈外时才「啵」地弹出来提示（scale 回弹 + 淡入），
## 鼠标回到圈内又缩回去。纯 _draw 绘制，无需贴图素材。

## 半径由 Player 的 interact_range 驱动（_setup_range_indicator 同步），不在 Inspector 手调。
var radius := 1024.0
## 工作圈是否启用（由 Player 同步：跟班已招募才为 true）。未启用时不显示。
var active := false

## 虚线主色（柔和暖黄，q 版提示感，醒目但不刺眼）。
@export var ring_color := Color(1.0, 0.86, 0.4, 0.85)
## 圆内淡填充。
@export var fill_color := Color(1.0, 0.9, 0.55, 0.08)
## 虚线粗细（像素）。
@export var dash_width := 4.0
## 虚线段数（越多越密）。
@export var dash_count := 48
## 每段实线占比（0~1）。调小（如 0.25）会变成一串圆点，更 q 版。
@export var dash_ratio := 0.5
## 虚线旋转速度（弧度/秒）。
@export var spin_speed := 0.6
## 弹出动画时长（秒）。
@export var pop_duration := 0.28

var _spin := 0.0
var _t := 0.0
var _shown := false
var _pop_tween: Tween


func _ready() -> void:
	show_behind_parent = true
	modulate.a = 0.0            # 初始隐藏，鼠标出圈才弹出
	scale = Vector2(0.6, 0.6)


func _process(delta: float) -> void:
	_spin += delta * spin_speed
	_t += delta
	if not active:
		# 跟班未招募：玩家还没有交互能力，工作圈不该出现。
		if _shown:
			_pop_out()
		return
	var beyond := global_position.distance_to(get_global_mouse_position()) > radius
	if beyond != _shown:
		if beyond:
			_pop_in()
		else:
			_pop_out()
	if _shown:
		queue_redraw()


## 弹出：scale 0.6→1.0 带 TRANS_BACK 回弹（q 弹），同时淡入。
func _pop_in() -> void:
	_shown = true
	if _pop_tween and _pop_tween.is_valid():
		_pop_tween.kill()
	_pop_tween = create_tween()
	_pop_tween.set_parallel(true)
	_pop_tween.tween_property(self, "scale", Vector2.ONE, pop_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pop_tween.tween_property(self, "modulate:a", 1.0, pop_duration * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 缩回：轻微缩小 + 淡出。
func _pop_out() -> void:
	_shown = false
	if _pop_tween and _pop_tween.is_valid():
		_pop_tween.kill()
	_pop_tween = create_tween()
	_pop_tween.set_parallel(true)
	_pop_tween.tween_property(self, "scale", Vector2(0.85, 0.85), pop_duration * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_pop_tween.tween_property(self, "modulate:a", 0.0, pop_duration * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _draw() -> void:
	# 呼吸：透明度在 0.75~1.0 之间轻微起伏。
	var breathe := 0.75 + 0.25 * (0.5 + 0.5 * sin(_t * 2.0))
	var rc := Color(ring_color.r, ring_color.g, ring_color.b, ring_color.a * breathe)
	draw_circle(Vector2.ZERO, radius, fill_color)
	var step := TAU / float(dash_count)
	var dash_angle := step * dash_ratio
	for i in range(dash_count):
		var a0 := step * float(i) + _spin
		draw_arc(Vector2.ZERO, radius, a0, a0 + dash_angle, 6, rc, dash_width, true)
