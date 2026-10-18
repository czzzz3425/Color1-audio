class_name LightSwitch
extends Node2D
## Lights Out 机关（单根灯柱）：可被玩家左键赋予「红」点亮，右键吸收红熄灭并返还。
## 点亮一根时通知父级 LightsOutPuzzle 翻转左右邻居。

const Rules := preload("res://scripts/element/element_rules.gd")

@export var lit_color := Color(1.0, 0.85, 0.3)

var _lit := false
var _puzzle: Node

@onready var visual: Sprite2D = $Visual


func _ready() -> void:
	add_to_group("colorable")
	_puzzle = get_parent()
	_refresh()


func is_lit() -> bool:
	return _lit


func set_lit(lit: bool) -> void:
	_lit = lit
	_refresh()


func _refresh() -> void:
	if visual != null:
		visual.self_modulate = lit_color if _lit else Color.WHITE


# —— colorable 契约 ——
func apply_color(_c: Color, color_name: String = "", _from_pos: Vector2 = Vector2.INF) -> bool:
	if Rules.element_for_color_name(color_name) != "burn":
		return false
	if _lit:
		return false   # 已亮：重复赋予不消耗红
	_lit = true
	_refresh()
	if _puzzle != null and _puzzle.has_method("on_switch_pressed"):
		_puzzle.call("on_switch_pressed", self)
	return true


func absorb_color() -> Dictionary:
	if not _lit:
		return {"element": "", "color": Color.WHITE, "color_name": ""}
	_lit = false
	_refresh()
	# 熄灭同样触发左右邻居翻转（经典 Lights Out：亮↔灭都算「按下」）。
	if _puzzle != null and _puzzle.has_method("on_switch_pressed"):
		_puzzle.call("on_switch_pressed", self)
	var cfg := Rules.config("burn")
	return {
		"element": "burn",
		"color": cfg.get("color", Color.WHITE),
		"color_name": cfg.get("color_name", ""),
		"amount": 1,
	}


func has_color() -> bool:
	return _lit


func contains_point(world_pos: Vector2) -> bool:
	if visual != null:
		return visual.get_rect().has_point(visual.to_local(world_pos))
	return global_position.distance_to(world_pos) <= 48.0
