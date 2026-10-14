class_name ParryTiming
extends RefCounted
## 弹反时序状态机（纯逻辑，可单测）：管理「弹反窗口」与「冷却」。
## Parry 节点负责输入 / 范围 / 广播，把时序判定委托给本类，便于独立测试与复用。
##
## 用法：
##   var t := ParryTiming.new(0.18, 0.4)
##   t.start()          # 开窗；冷却中/已开窗返回 false
##   t.advance(delta)   # 每帧推进
##   t.is_active()      # 窗口是否生效
##   t.can_start()      # 现在能否再次开窗
##   t.cooldown_ratio() # 0（就绪）~ 1（刚触发），供 HUD 画冷却条

signal window_opened
signal window_closed

## 窗口时长（秒）。
var window_duration: float = 0.18
## 窗口结束后的冷却时长（秒）。
var cooldown_duration: float = 0.4

var _window_left := 0.0
var _cooldown_left := 0.0


func _init(window: float = 0.18, cooldown: float = 0.4) -> void:
	window_duration = maxf(0.0, window)
	cooldown_duration = maxf(0.0, cooldown)


## 开启弹反窗口。成功返回 true；冷却中或窗口已开返回 false。
func start() -> bool:
	if not can_start():
		return false
	_window_left = window_duration
	_cooldown_left = window_duration + cooldown_duration
	window_opened.emit()
	return true


## 推进时间。
func advance(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)
	if _window_left > 0.0:
		_window_left = maxf(0.0, _window_left - delta)
		if _window_left <= 0.0:
			window_closed.emit()


## 弹反窗口是否生效。
func is_active() -> bool:
	return _window_left > 0.0


## 现在能否再次发起弹反（不在窗口内、不在冷却中）。
func can_start() -> bool:
	return _window_left <= 0.0 and _cooldown_left <= 0.0


## 冷却进度：0 = 就绪，1 = 刚触发。
func cooldown_ratio() -> float:
	var total := window_duration + cooldown_duration
	if total <= 0.0:
		return 0.0
	return clampf(_cooldown_left / total, 0.0, 1.0)


## 立刻结束窗口与冷却（切场景 / 复活时用）。
func reset() -> void:
	if _window_left > 0.0:
		_window_left = 0.0
		window_closed.emit()
	_cooldown_left = 0.0
