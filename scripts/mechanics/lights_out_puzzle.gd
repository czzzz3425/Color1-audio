class_name LightsOutPuzzle
extends Node2D
## Lights Out 管理器：8 根灯柱围成一圈，点亮一根会翻转左右邻居，目标是全亮。

const LightSwitchScript := preload("res://scripts/mechanics/light_switch.gd")

signal solved

## 初始点亮的灯柱索引（按 children 顺序，默认交替亮 0/2/4/6）。
@export var initial_lit: Array[int] = [0, 2, 4, 6]
## 全亮后要打开的门（RoomDoor 等有 open() 方法的节点路径）。
@export var door_path: NodePath

var _switches: Array = []


func _ready() -> void:
	add_to_group("lights_out_puzzle")
	for child in get_children():
		if child.get_script() == LightSwitchScript:
			_switches.append(child)
	for i in _switches.size():
		_switches[i].set_lit(initial_lit.has(i))


## 某根机关被点亮：翻转左右邻居，然后检查是否全亮。
func on_switch_pressed(sw: Node) -> void:
	var idx := _switches.find(sw)
	if idx < 0:
		return
	var n := _switches.size()
	if n == 0:
		return
	_flip((idx - 1 + n) % n)
	_flip((idx + 1) % n)
	_check_solved()


func _flip(i: int) -> void:
	_switches[i].set_lit(not _switches[i].is_lit())


func _check_solved() -> void:
	for s in _switches:
		if not s.is_lit():
			return
	solved.emit()
	print("[LightsOut] solved!")
	if door_path != NodePath(""):
		var door := get_node_or_null(door_path)
		if door != null and door.has_method("open"):
			door.call("open")
