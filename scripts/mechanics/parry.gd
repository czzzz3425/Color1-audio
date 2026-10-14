class_name Parry
extends Node2D
## 弹反组件：挂在任意 Node2D（通常是玩家）上。按下弹反键后开启一个短促的「弹反窗口」，
## 窗口内进入 parry_radius 的来袭子弹会被反弹。
##
## 依赖倒置：本组件只管「时机 + 范围 + 广播」，具体反弹交给子弹自己完成。
## 任何子弹只要满足下面契约即可被弹反（无需改本组件）：
##   · 加入组 "parryable_projectile"；
##   · 实现 can_parry() -> bool 与 parry(deflect_dir: Vector2, parrier: Node) -> bool。
## 项目内的 ParryProjectile 即满足该契约，可直接使用。
##
## 公共 API（外部可调用：接 HUD / 手柄 / AI）：
##   try_parry() -> bool        尝试开启弹反窗口；成功 true，冷却中 / 已在窗口 false
##   can_parry() -> bool        当前是否可发起弹反
##   is_parrying() -> bool      弹反窗口是否开启
##   cooldown_ratio() -> float  冷却进度 0（就绪）~ 1（刚触发）
## 信号：
##   parry_started / parry_ended
##   parry_succeeded(projectile, direction)
##   state_changed(parrying: bool, cooldown_ratio: float)   # 给 HUD 画冷却条 / 图标

signal parry_started
signal parry_ended
signal parry_succeeded(projectile: Node, direction: Vector2)
signal state_changed(parrying: bool, cooldown_ratio: float)

const Timing := preload("res://scripts/mechanics/parry_timing.gd")

@export_group("输入")
## 触发弹反的输入动作名。auto_register_input 为真且该动作不存在时自动创建。
@export var input_action := "parry"
## 是否自动注册输入动作（不存在时）。默认注册：J / K / 鼠标中键。
@export var auto_register_input := true
## 是否自己读取输入触发。false 时只由外部调用 try_parry()。
@export var read_input := true

@export_group("时序")
## 弹反窗口时长（秒）：窗口内进入范围的子弹被反弹。
@export_range(0.02, 2.0, 0.01) var parry_window := 0.18
## 弹反结束后的冷却时长（秒）。
@export_range(0.0, 4.0, 0.01) var parry_cooldown := 0.4

@export_group("判定")
## 弹反范围（世界像素，以组件全局位置为圆心）。
@export_range(8.0, 1024.0, 1.0) var parry_radius := 160.0
## 单次开窗最多反弹的子弹数（0 = 不限）。
@export_range(0, 64, 1) var max_parries_per_window := 0

var _timing: Timing
var _parries_this_window := 0
var _last_active := false
var _last_ratio := -1.0


func _ready() -> void:
	if auto_register_input:
		_ensure_input_action()
	add_to_group("parry")
	_timing = Timing.new(parry_window, parry_cooldown)
	_timing.window_opened.connect(_on_window_opened)
	_timing.window_closed.connect(_on_window_closed)


func _physics_process(delta: float) -> void:
	if read_input and InputMap.has_action(input_action) and Input.is_action_just_pressed(input_action):
		try_parry()
	_timing.advance(delta)
	if _timing.is_active():
		_scan()
	_emit_state()


## 尝试发起弹反。成功开启窗口返回 true。
func try_parry() -> bool:
	if not _timing.start():
		return false
	_parries_this_window = 0
	_scan()
	return true


func can_parry() -> bool:
	return _timing.can_start()


func is_parrying() -> bool:
	return _timing.is_active()


func cooldown_ratio() -> float:
	return _timing.cooldown_ratio()


func _on_window_opened() -> void:
	parry_started.emit()


func _on_window_closed() -> void:
	parry_ended.emit()


## 扫描范围内可弹反的子弹并反弹。
func _scan() -> void:
	var origin := global_position
	for p in get_tree().get_nodes_in_group("parryable_projectile"):
		if not is_instance_valid(p) or not (p is Node2D):
			continue
		if not GameState.is_in_current_scene(p):
			continue
		if not p.has_method("can_parry") or not bool(p.call("can_parry")):
			continue
		if max_parries_per_window > 0 and _parries_this_window >= max_parries_per_window:
			break
		if origin.distance_to((p as Node2D).global_position) > parry_radius:
			continue
		var dir := origin.direction_to((p as Node2D).global_position)
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		if p.has_method("parry"):
			p.call("parry", dir, get_parent())
			_parries_this_window += 1
			parry_succeeded.emit(p, dir)


## 状态变化时才发信号（供 HUD 画冷却）。
func _emit_state() -> void:
	var active := _timing.is_active()
	var ratio := _timing.cooldown_ratio()
	if active == _last_active and absf(ratio - _last_ratio) < 0.01:
		return
	_last_active = active
	_last_ratio = ratio
	state_changed.emit(active, ratio)


func _ensure_input_action() -> void:
	if InputMap.has_action(input_action):
		return
	InputMap.add_action(input_action)
	for k in [KEY_J, KEY_K]:
		var key := InputEventKey.new()
		key.physical_keycode = k
		InputMap.action_add_event(input_action, key)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_MIDDLE
	mouse.pressed = true
	InputMap.action_add_event(input_action, mouse)
